// Logique de la fonction Edge « live-egress-webhook » : réception des événements d'enregistrement (egress) de LiveKit. Testable avec Node (faux émetteur signé, aucun serveur réel).
// LiveKit signe chaque webhook : en-tête Authorization = JWT HS256 (clé LIVEKIT_API_KEY / LIVEKIT_API_SECRET) dont la revendication « sha256 » est l'empreinte SHA-256 (base64) du corps.
// Une signature absente ou fausse est refusée (401) avant toute lecture du corps. Sans configuration : 503 « not_configured ».
// Événements pris en compte : egress_started / egress_updated / egress_ended. Le fichier livré (egressInfo.fileResults[0] ou .file) et sa durée sont transmis à live_recording_egress_event,
// qui revérifie les consentements et pose « prêt » ; une durée ou un fichier absents donnent « échec », jamais une valeur inventée.

export type Env = (name: string) => string | undefined;
export type Outcome = { status: number; body: Record<string, unknown> };

const enc = new TextEncoder();
const b64urlDecode = (s: string): Uint8Array => {
  const p = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
  return Uint8Array.from(atob(p), (c) => c.charCodeAt(0));
};
const b64 = (b: ArrayBuffer): string => { let s = ""; for (const x of new Uint8Array(b)) s += String.fromCharCode(x); return btoa(s); };

export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

/** Vérifie le jeton du webhook LiveKit : signature HS256, émetteur, expiration et empreinte du corps. */
export async function verifyWebhook(raw: string, authHeader: string | null, apiKey: string, apiSecret: string, nowSec = Math.floor(Date.now() / 1000)): Promise<boolean> {
  try {
    const token = (authHeader ?? "").replace(/^Bearer\s+/i, "").trim();
    const parts = token.split(".");
    if (parts.length !== 3) return false;
    const header = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
    if (header.alg !== "HS256") return false;
    const key = await crypto.subtle.importKey("raw", enc.encode(apiSecret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const expected = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(`${parts[0]}.${parts[1]}`)));
    const got = b64urlDecode(parts[2]);
    if (got.length !== expected.length || !safeEqual(String.fromCharCode(...got), String.fromCharCode(...expected))) return false;
    const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
    if (claims.iss !== apiKey) return false;
    if (typeof claims.exp === "number" && claims.exp < nowSec) return false;
    if (typeof claims.nbf === "number" && claims.nbf > nowSec + 60) return false;
    const digest = b64(await crypto.subtle.digest("SHA-256", enc.encode(raw)));
    return typeof claims.sha256 === "string" && safeEqual(claims.sha256, digest);
  } catch {
    return false;
  }
}

export type EgressDeps = {
  env: Env;
  event: (egressId: string, status: "active" | "complete" | "failed", path: string | null, durationSec: number | null, error: string | null) => Promise<{ data: unknown; error: string | null }>;
};

const NAMES: Record<string, string> = { "0": "STARTING", "1": "ACTIVE", "2": "ENDING", "3": "COMPLETE", "4": "FAILED", "5": "ABORTED", "6": "LIMIT_REACHED" };

function statusOf(v: unknown): string {
  const s = String(v ?? "").toUpperCase();
  return NAMES[s] ?? s.replace(/^EGRESS_/, "");
}

// Durées LiveKit en nanosecondes (entier 64 bits sérialisé en chaîne) ; arrondi à la seconde.
function secondsOf(ns: unknown): number | null {
  const n = Number(String(ns ?? ""));
  return Number.isFinite(n) && n > 0 ? Math.round(n / 1e9) : null;
}

export async function processEgressWebhook(raw: string, authHeader: string | null, deps: EgressDeps): Promise<Outcome> {
  const apiKey = (deps.env("LIVEKIT_API_KEY") ?? "").trim(), apiSecret = (deps.env("LIVEKIT_API_SECRET") ?? "").trim();
  if (!apiKey || !apiSecret) return { status: 503, body: { error: "not_configured", code: "not_configured" } };
  if (!(await verifyWebhook(raw, authHeader, apiKey, apiSecret))) return { status: 401, body: { error: "bad_signature", code: "bad_signature" } };
  if (raw.length > 200_000) return { status: 413, body: { error: "too_large", code: "too_large" } };
  let b: any;
  try { b = JSON.parse(raw); } catch { return { status: 400, body: { error: "bad_request", code: "bad_json" } }; }
  const ev = String(b?.event ?? "");
  if (!ev.startsWith("egress_")) return { status: 200, body: { ok: true, ignored: ev || "unknown" } };
  const info = b?.egressInfo ?? b?.egress_info;
  const egressId = String(info?.egressId ?? info?.egress_id ?? "");
  if (!egressId || egressId.length > 200) return { status: 400, body: { error: "bad_request", code: "bad_egress" } };
  const st = statusOf(info?.status);
  let status: "active" | "complete" | "failed" | null = null;
  let path: string | null = null, duration: number | null = null, error: string | null = null;
  const file = (Array.isArray(info?.fileResults ?? info?.file_results) ? (info.fileResults ?? info.file_results)[0] : null) ?? info?.file ?? null;
  if (st === "ACTIVE" || st === "STARTING") status = "active";
  else if (st === "COMPLETE" || st === "LIMIT_REACHED") {
    status = "complete";
    path = typeof file?.filename === "string" ? file.filename : null;
    duration = secondsOf(file?.duration);
    if (st === "LIMIT_REACHED" && (!path || !duration)) { status = "failed"; error = "limite de l'enregistreur atteinte sans fichier exploitable"; }
  } else if (st === "FAILED" || st === "ABORTED") {
    status = "failed";
    error = typeof info?.error === "string" && info.error.trim() ? info.error.slice(0, 300) : st === "ABORTED" ? "enregistrement interrompu" : "échec de l'enregistreur";
  }
  if (!status) return { status: 200, body: { ok: true, ignored: st || "status" } };
  const r = await deps.event(egressId, status, path, duration, error);
  if (r.error) return { status: 500, body: { error: "rpc_failed", code: "rpc_failed" } };
  return { status: 200, body: { ok: true, result: r.data } };
}
