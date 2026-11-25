// Logique de la fonction Edge « live-record » : démarrage et arrêt de l'enregistrement d'un live (LiveKit Room Composite Egress). Testable avec Node contre un FAUX serveur LiveKit.
//   POST {live_id, action: "start" | "stop"}  (jeton Supabase de l'hôte ou d'un co-hôte approuvé)
// Le serveur CONFIRME avant tout démarrage (RPC live_recording_start_check : live en cours, hôte/co-hôte, enregistrement demandé par l'hôte, consentement de chaque co-hôte).
// Configuration (secrets de fonction, jamais dans Git) : LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET + stockage S3 compatible (Supabase Storage S3) :
//   LIVEKIT_EGRESS_S3_ENDPOINT, LIVEKIT_EGRESS_S3_ACCESS_KEY, LIVEKIT_EGRESS_S3_SECRET, LIVEKIT_EGRESS_S3_BUCKET (défaut « live-replays »), LIVEKIT_EGRESS_S3_REGION (défaut « us-east-1 »).
// Sans configuration : « not_configured » (503), aucun enregistrement n'est simulé. Le fichier livré est signalé par le webhook (fonction « live-egress-webhook »).

export type Env = (name: string) => string | undefined;
export type Outcome = { status: number; body: Record<string, unknown> };

export type RecorderConfig = {
  httpUrl: string; apiKey: string; apiSecret: string;
  s3: { endpoint: string; accessKey: string; secret: string; bucket: string; region: string };
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function loadRecorderConfig(env: Env): RecorderConfig | null {
  const url = (env("LIVEKIT_URL") ?? "").trim().replace(/\/+$/, "");
  const apiKey = (env("LIVEKIT_API_KEY") ?? "").trim();
  const apiSecret = (env("LIVEKIT_API_SECRET") ?? "").trim();
  const endpoint = (env("LIVEKIT_EGRESS_S3_ENDPOINT") ?? "").trim().replace(/\/+$/, "");
  const accessKey = (env("LIVEKIT_EGRESS_S3_ACCESS_KEY") ?? "").trim();
  const secret = (env("LIVEKIT_EGRESS_S3_SECRET") ?? "").trim();
  if (!/^(wss?|https?):\/\/[^\s]+$/.test(url) || !apiKey || !apiSecret || !/^https?:\/\/[^\s]+$/.test(endpoint) || !accessKey || !secret) return null;
  return {
    httpUrl: url.replace(/^wss:/, "https:").replace(/^ws:/, "http:"), apiKey, apiSecret,
    s3: { endpoint, accessKey, secret, bucket: (env("LIVEKIT_EGRESS_S3_BUCKET") ?? "").trim() || "live-replays", region: (env("LIVEKIT_EGRESS_S3_REGION") ?? "").trim() || "us-east-1" },
  };
}

const b64url = (data: Uint8Array | string) => {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

/** JWT HS256 serveur à serveur pour l'API Egress de LiveKit (droit « roomRecord »), valable 60 s. */
export async function egressToken(apiKey: string, apiSecret: string, ttlSec = 60): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ iss: apiKey, sub: "boutik-record", nbf: now - 5, iat: now, exp: now + ttlSec, video: { roomRecord: true } }));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(apiSecret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${header}.${payload}`)));
  return `${header}.${payload}.${b64url(sig)}`;
}

export type CheckResult = { ok: boolean; reason?: string; message?: string; recording_id?: string; room_name?: string; egress_id?: string };

export type RecordDeps = {
  env: Env;
  fetchFn: typeof fetch;
  userId: string;
  startCheck: (liveId: string, userId: string) => Promise<CheckResult | null>;
  stopCheck: (liveId: string, userId: string) => Promise<CheckResult | null>;
  claim: (recordingId: string) => Promise<boolean>;
  started: (recordingId: string, egressId: string) => Promise<void>;
  stopping: (recordingId: string) => Promise<void>;
  failed: (recordingId: string, detail: string) => Promise<void>;
};

const REASON_STATUS: Record<string, number> = {
  introuvable: 404, non_autorise: 403, aucun_enregistrement_en_cours: 409, non_configure: 503,
};

async function twirp(cfg: RecorderConfig, fetchFn: typeof fetch, method: string, body: Record<string, unknown>): Promise<{ ok: true; json: any } | { ok: false; detail: string }> {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 15000);
  try {
    const res = await fetchFn(`${cfg.httpUrl}/twirp/livekit.Egress/${method}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${await egressToken(cfg.apiKey, cfg.apiSecret)}` },
      body: JSON.stringify(body),
      signal: ctl.signal,
    });
    const text = await res.text();
    let json: any = null;
    try { json = text ? JSON.parse(text) : {}; } catch { /* corps illisible */ }
    if (!res.ok) return { ok: false, detail: `LiveKit HTTP ${res.status}${typeof json?.code === "string" ? " " + json.code : ""}` };
    return { ok: true, json: json ?? {} };
  } catch (e) {
    return { ok: false, detail: e instanceof Error && e.name === "AbortError" ? "délai dépassé" : "serveur vidéo injoignable" };
  } finally { clearTimeout(t); }
}

export async function processRecord(raw: unknown, deps: RecordDeps): Promise<Outcome> {
  const b = (typeof raw === "object" && raw !== null ? raw : {}) as Record<string, unknown>;
  const liveId = String(b.live_id ?? ""), action = String(b.action ?? "");
  if (!UUID_RE.test(liveId) || (action !== "start" && action !== "stop")) return { status: 400, body: { error: "bad_request", message: "Demande invalide." } };
  const cfg = loadRecorderConfig(deps.env);
  if (!cfg) return { status: 503, body: { error: "not_configured", message: "L'enregistrement des lives n'est pas encore configuré sur ce serveur : aucun replay ne sera créé." } };

  if (action === "start") {
    const chk = await deps.startCheck(liveId, deps.userId);
    if (!chk) return { status: 503, body: { error: "check_failed", message: "Impossible de vérifier l'enregistrement pour le moment." } };
    if (!chk.ok) return { status: REASON_STATUS[chk.reason ?? ""] ?? 409, body: { error: chk.reason ?? "refused", message: chk.message ?? "Démarrage refusé." } };
    const recordingId = String(chk.recording_id), room = String(chk.room_name ?? "");
    if (!UUID_RE.test(recordingId) || !room) return { status: 503, body: { error: "check_failed", message: "Réponse de vérification invalide." } };
    if (!(await deps.claim(recordingId))) return { status: 409, body: { error: "deja_demarre", message: "L'enregistrement est déjà en cours de démarrage." } };
    const out = await twirp(cfg, deps.fetchFn, "StartRoomCompositeEgress", {
      room_name: room, layout: "speaker",
      file_outputs: [{ filepath: `${liveId}/${recordingId}.mp4`, s3: { access_key: cfg.s3.accessKey, secret: cfg.s3.secret, region: cfg.s3.region, endpoint: cfg.s3.endpoint, bucket: cfg.s3.bucket, force_path_style: true } }],
    });
    const egressId = out.ok && typeof out.json?.egress_id === "string" ? out.json.egress_id : out.ok && typeof out.json?.egressId === "string" ? out.json.egressId : "";
    if (!out.ok || !egressId) {
      await deps.failed(recordingId, out.ok ? "réponse de LiveKit sans identifiant d'egress" : out.detail);
      return { status: 502, body: { error: "recorder_failed", message: "Le serveur d'enregistrement n'a pas démarré l'enregistrement." } };
    }
    await deps.started(recordingId, egressId);
    return { status: 200, body: { ok: true, state: "recording" } };
  }

  const chk = await deps.stopCheck(liveId, deps.userId);
  if (!chk) return { status: 503, body: { error: "check_failed", message: "Impossible de vérifier l'enregistrement pour le moment." } };
  if (!chk.ok) return { status: REASON_STATUS[chk.reason ?? ""] ?? 409, body: { error: chk.reason ?? "refused", message: chk.message ?? "Arrêt refusé." } };
  const out = await twirp(cfg, deps.fetchFn, "StopEgress", { egress_id: String(chk.egress_id) });
  if (!out.ok) return { status: 502, body: { error: "recorder_failed", message: "Le serveur d'enregistrement n'a pas confirmé l'arrêt." } };
  await deps.stopping(String(chk.recording_id));
  return { status: 200, body: { ok: true, state: "processing" } };
}
