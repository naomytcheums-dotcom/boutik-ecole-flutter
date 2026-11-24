// Logique pure de la fonction « translate » (aucune dépendance Deno ni réseau implicite : testable par Node avec un faux fournisseur local).
// Connecteur HTTP générique : le fournisseur se règle par des SECRETS de fonction (aucune clé ni adresse dans le dépôt) :
//   TRANSLATE_API_URL (obligatoire, https ; http seulement pour localhost / 127.0.0.1), TRANSLATE_API_KEY (obligatoire), TRANSLATE_PROVIDER_CODE (code du registre ai_providers, obligatoire),
//   TRANSLATE_AUTH_HEADER (défaut « Authorization »), TRANSLATE_AUTH_SCHEME (défaut « Bearer » ; vide = clé seule),
//   TRANSLATE_FIELD_TEXT / TRANSLATE_FIELD_TARGET / TRANSLATE_FIELD_SOURCE (défauts « text », « target », « source »),
//   TRANSLATE_RESULT_PATH (défaut « translation ») et TRANSLATE_SOURCE_PATH (défaut « detected_source ») : chemins pointés dans la réponse JSON.
// Sans configuration : réponse 503 + code « not_configured ». Jamais de texte simulé.

export interface ProviderConfig {
  url: string;
  key: string;
  providerCode: string;
  authHeader: string;
  authScheme: string;
  fieldText: string;
  fieldTarget: string;
  fieldSource: string;
  resultPath: string;
  sourcePath: string;
}

export type Env = (name: string) => string | undefined;

const LANG = /^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$/;

export function validLang(v: unknown): v is string {
  return typeof v === "string" && LANG.test(v);
}

function allowedUrl(raw: string): boolean {
  try {
    const u = new URL(raw);
    if (u.protocol === "https:") return true;
    return u.protocol === "http:" && (u.hostname === "localhost" || u.hostname === "127.0.0.1" || u.hostname === "[::1]");
  } catch {
    return false;
  }
}

/** Configuration du connecteur, ou null si un secret obligatoire manque ou si l'adresse n'est pas acceptable. */
export function loadConfig(env: Env): ProviderConfig | null {
  const url = (env("TRANSLATE_API_URL") ?? "").trim();
  const key = (env("TRANSLATE_API_KEY") ?? "").trim();
  const providerCode = (env("TRANSLATE_PROVIDER_CODE") ?? "").trim().toLowerCase();
  if (!url || !key || !/^[a-z0-9_]{2,40}$/.test(providerCode) || !allowedUrl(url)) return null;
  const or = (name: string, d: string) => (env(name) ?? "").trim() || d;
  const scheme = env("TRANSLATE_AUTH_SCHEME");
  return {
    url,
    key,
    providerCode,
    authHeader: or("TRANSLATE_AUTH_HEADER", "Authorization"),
    authScheme: scheme === undefined ? "Bearer" : scheme.trim(),
    fieldText: or("TRANSLATE_FIELD_TEXT", "text"),
    fieldTarget: or("TRANSLATE_FIELD_TARGET", "target"),
    fieldSource: or("TRANSLATE_FIELD_SOURCE", "source"),
    resultPath: or("TRANSLATE_RESULT_PATH", "translation"),
    sourcePath: or("TRANSLATE_SOURCE_PATH", "detected_source"),
  };
}

export function readPath(obj: unknown, path: string): unknown {
  let cur: any = obj;
  for (const part of path.split(".")) {
    if (cur === null || typeof cur !== "object") return undefined;
    cur = Array.isArray(cur) && /^\d+$/.test(part) ? cur[Number(part)] : cur[part];
  }
  return cur;
}

export function buildRequest(cfg: ProviderConfig, text: string, target: string, source?: string | null): { url: string; init: RequestInit } {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json" };
  headers[cfg.authHeader] = cfg.authScheme ? `${cfg.authScheme} ${cfg.key}` : cfg.key;
  const body: Record<string, string> = { [cfg.fieldText]: text, [cfg.fieldTarget]: target };
  if (source) body[cfg.fieldSource] = source;
  return { url: cfg.url, init: { method: "POST", headers, body: JSON.stringify(body) } };
}

export type Translated = { ok: true; text: string; source: string | null } | { ok: false; reason: "http" | "invalid" | "timeout" | "network" };

/** Appelle le fournisseur. Une réponse vide ou non textuelle n'est jamais présentée comme une traduction. */
export async function translateWith(cfg: ProviderConfig, text: string, target: string, fetchFn: typeof fetch, timeoutMs = 15000): Promise<Translated> {
  const { url, init } = buildRequest(cfg, text, target);
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    const r = await fetchFn(url, { ...init, signal: ctl.signal });
    if (!r.ok) return { ok: false, reason: "http" };
    let json: unknown;
    try { json = await r.json(); } catch { return { ok: false, reason: "invalid" }; }
    const out = readPath(json, cfg.resultPath);
    if (typeof out !== "string" || out.trim().length === 0) return { ok: false, reason: "invalid" };
    const src = readPath(json, cfg.sourcePath);
    return { ok: true, text: out.trim().slice(0, 12000), source: typeof src === "string" && validLang(src.toLowerCase()) ? src.toLowerCase() : null };
  } catch (e) {
    return { ok: false, reason: (e as Error)?.name === "AbortError" ? "timeout" : "network" };
  } finally {
    clearTimeout(timer);
  }
}

type RpcResult = { data: any; error: { message?: string } | null };

export interface Deps {
  cfg: ProviderConfig | null;
  userId: string | null;
  fetchFn: typeof fetch;
  requestTranslation(messageId: number, target: string): Promise<RpcResult>;
  storeTranslation(a: { user: string; message: number; target: string; source: string | null; provider: string; text: string }): Promise<RpcResult>;
}

export interface Out { status: number; body: Record<string, unknown> }

const NOT_CONFIGURED: Out = {
  status: 503,
  body: { error: "not_configured", code: "not_configured", message: "La traduction n’est pas configurée pour le moment. Aucun texte n’est inventé." },
};

/** Orchestration complète : configuration -> authentification -> droit sur le message (RPC) -> fournisseur -> cache. */
export async function processTranslate(body: unknown, d: Deps): Promise<Out> {
  if (!d.cfg) return NOT_CONFIGURED;
  const b = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  // Sonde d'état : aucun appel au fournisseur, aucun quota.
  if (b.status === true) return { status: 200, body: { enabled: true } };
  if (!d.userId) return { status: 401, body: { error: "unauthorized", code: "unauthorized", message: "Connexion requise." } };
  const messageId = typeof b.message_id === "number" ? b.message_id : Number.NaN;
  const target = typeof b.target_lang === "string" ? b.target_lang.trim().toLowerCase() : "";
  if (!Number.isSafeInteger(messageId) || messageId <= 0 || !validLang(target)) {
    return { status: 400, body: { error: "bad_request", code: "bad_request", message: "Message ou langue invalide." } };
  }
  const req = await d.requestTranslation(messageId, target);
  if (req.error) {
    const m = String(req.error.message ?? "");
    if (/Message introuvable/i.test(m)) return { status: 404, body: { error: "not_found", code: "not_found", message: "Message introuvable." } };
    if (/Langue cible invalide/i.test(m)) return { status: 400, body: { error: "bad_request", code: "bad_request", message: "Langue invalide." } };
    return { status: 502, body: { error: "server_error", code: "server_error", message: "La traduction est momentanément indisponible." } };
  }
  const r = req.data ?? {};
  if (r.status === "translated" && typeof r.text === "string") {
    return { status: 200, body: { status: "translated", text: r.text, source_lang: r.source_lang ?? null, target_lang: r.target_lang ?? target, cached: true } };
  }
  // Pas de fournisseur actif dans le registre, ou secrets de la fonction pointant vers un autre fournisseur : jamais de texte.
  if (r.status !== "pending" || r.provider !== d.cfg.providerCode || typeof r.text !== "string") return NOT_CONFIGURED;
  const t = await translateWith(d.cfg, r.text, target, d.fetchFn);
  if (!t.ok) {
    return { status: 502, body: { error: "provider_error", code: "provider_error", message: "Le service de traduction est momentanément indisponible. Réessayez plus tard." } };
  }
  const st = await d.storeTranslation({ user: d.userId, message: messageId, target, source: t.source, provider: d.cfg.providerCode, text: t.text });
  if (st.error) return { status: 502, body: { error: "server_error", code: "server_error", message: "La traduction n’a pas pu être enregistrée. Réessayez." } };
  return { status: 200, body: { status: "translated", text: t.text, source_lang: t.source, target_lang: target, cached: false } };
}
