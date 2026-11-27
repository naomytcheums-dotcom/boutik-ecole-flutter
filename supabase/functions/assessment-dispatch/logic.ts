// Logique de la fonction Edge « assessment-dispatch » (évaluations de compétences par des fournisseurs externes). Testable avec Node contre un FAUX fournisseur local.
// Trois actions :
//  - POST ?action=dispatch (clé de service ou clé interne de la planification) : réclame les demandes en attente (fournisseurs ACTIFS ET CONFIGURÉS seulement), appelle l'adaptateur, enregistre acceptation ou échec.
//  - POST ?action=health (mêmes droits) : vérifie la PRÉSENCE des trois secrets de chaque fournisseur enregistré, SANS appeler le fournisseur, et écrit le rapport (booléens, jamais de valeur) par assessment_provider_health_report.
//  - POST ?provider=<code> (rappel du fournisseur, signature HMAC-SHA256 obligatoire) : valide strictement le résultat puis l'enregistre par assessment_dispatch_result.
// Configuration par fournisseur (secrets de fonction, jamais dans Git) : ASSESSMENT_<CODE>_BASE_URL, ASSESSMENT_<CODE>_API_KEY, ASSESSMENT_<CODE>_WEBHOOK_SECRET (CODE en majuscules) ;
// optionnel : ASSESSMENT_<CODE>_REQUIRE_TIMESTAMP=1 impose l'en-tête x-timestamp sur les rappels.
// Un fournisseur est « configuré » seulement avec les TROIS secrets : sans secret de rappel, un résultat ne pourrait pas être authentifié et l'envoi consommerait un crédit pour rien.
// Sans configuration : rien n'est envoyé, rien n'est compté, aucun résultat n'est simulé (réponse « not_configured »).
// Contrat « adaptateur générique » (premier adaptateur ; un fournisseur au format différent aura son propre adaptateur ajouté dans ADAPTERS) :
//   envoi    : POST {BASE_URL}/assessments  Authorization: Bearer <API_KEY>  corps {reference, family, mode, callback_url}  réponse {external_ref, candidate_url?}
//   rappel   : corps {reference, external_ref?, status: "completed"|"failed", competences[], criteria[], evidence[], details{}, limits, recommendations[], detail?}
//              en-tête x-signature: sha256=<hex HMAC-SHA256 du corps brut> ; en-tête OPTIONNEL x-timestamp (secondes Unix) : s'il est présent il doit être à ±5 minutes
//              ET la signature couvre alors « <x-timestamp>.<corps brut> » (sinon l'horodatage ne protégerait de rien).
// Aucune donnée personnelle du candidat n'est envoyée : seulement la référence de la demande, la famille et le mode.
// Contrat complet : docs/transformation/H13_CONTRAT_FOURNISSEUR_EVALUATION.md

export type ProviderConfig = { code: string; baseUrl: string; apiKey: string; webhookSecret: string | null };
export type Env = (name: string) => string | undefined;

const CODE_RE = /^[a-z0-9_]{2,40}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function loadProviderConfig(code: string, env: Env): ProviderConfig | null {
  if (!CODE_RE.test(code)) return null;
  const k = `ASSESSMENT_${code.toUpperCase()}_`;
  const baseUrl = (env(k + "BASE_URL") ?? "").trim().replace(/\/+$/, "");
  const apiKey = (env(k + "API_KEY") ?? "").trim();
  if (!/^https?:\/\/[^\s]+$/.test(baseUrl) || !apiKey) return null;
  return { code, baseUrl, apiKey, webhookSecret: (env(k + "WEBHOOK_SECRET") ?? "").trim() || null };
}

// Présence des trois secrets (booléens seulement : une valeur n'est jamais renvoyée). L'URL de base doit être http(s) ; configured = les trois présents.
export type ConfigPresence = { base_url: boolean; api_key: boolean; webhook_secret: boolean };
export function configPresence(code: string, env: Env): ConfigPresence {
  if (!CODE_RE.test(code)) return { base_url: false, api_key: false, webhook_secret: false };
  const k = `ASSESSMENT_${code.toUpperCase()}_`;
  return {
    base_url: /^https?:\/\/[^\s]+$/.test((env(k + "BASE_URL") ?? "").trim()),
    api_key: (env(k + "API_KEY") ?? "").trim().length > 0,
    webhook_secret: (env(k + "WEBHOOK_SECRET") ?? "").trim().length > 0,
  };
}
export const isFullyConfigured = (p: ConfigPresence) => p.base_url && p.api_key && p.webhook_secret;

export type ClaimedRequest = { request_id: string; provider: string; family: string; mode: string; attempt: number };

export type DispatchDeps = {
  env: Env;
  fetchFn: typeof fetch;
  callbackUrl: string;
  listActiveProviders: () => Promise<string[]>;
  claim: (providers: string[], limit: number) => Promise<ClaimedRequest[]>;
  accepted: (requestId: string, externalRef: string, candidateUrl: string | null) => Promise<void>;
  failed: (requestId: string, http: number | null, detail: string) => Promise<void>;
};

export type Outcome = { status: number; body: Record<string, unknown> };

async function withTimeout(fetchFn: typeof fetch, url: string, init: RequestInit, ms: number): Promise<Response> {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try { return await fetchFn(url, { ...init, signal: ctl.signal }); } finally { clearTimeout(t); }
}

type SendResult = { ok: true; externalRef: string; candidateUrl: string | null } | { ok: false; http: number | null; detail: string };

// Adaptateur générique : renvoie la référence du fournisseur ou une erreur lisible. Ne lève jamais.
export async function genericSend(cfg: ProviderConfig, r: ClaimedRequest, callbackUrl: string, fetchFn: typeof fetch): Promise<SendResult> {
  try {
    const res = await withTimeout(fetchFn, `${cfg.baseUrl}/assessments`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${cfg.apiKey}` },
      body: JSON.stringify({ reference: r.request_id, family: r.family, mode: r.mode, callback_url: callbackUrl }),
    }, 15000);
    const text = await res.text();
    if (!res.ok) return { ok: false, http: res.status, detail: `HTTP ${res.status}` };
    let j: any = null;
    try { j = JSON.parse(text); } catch { /* corps illisible */ }
    const ref = typeof j?.external_ref === "string" ? j.external_ref.trim() : "";
    if (!ref) return { ok: false, http: res.status, detail: "réponse sans external_ref" };
    const url = typeof j?.candidate_url === "string" && /^https:\/\/[^\s]{4,255}$/.test(j.candidate_url) ? j.candidate_url : null;
    return { ok: true, externalRef: ref.slice(0, 200), candidateUrl: url };
  } catch (e) {
    return { ok: false, http: null, detail: e instanceof Error && e.name === "AbortError" ? "délai dépassé" : "fournisseur injoignable" };
  }
}

export const ADAPTERS: Record<string, typeof genericSend> = {};

export async function processDispatch(deps: DispatchDeps, limit = 10): Promise<Outcome> {
  const active = await deps.listActiveProviders();
  if (active.length === 0) return { status: 200, body: { ok: true, dispatched: 0, note: "no_active_provider" } };
  const configured = active.filter((c) => isFullyConfigured(configPresence(c, deps.env)));
  if (configured.length === 0) return { status: 503, body: { error: "not_configured", code: "not_configured", active_providers: active.length } };
  const claimed = await deps.claim(configured, limit);
  let accepted = 0, failed = 0;
  for (const r of claimed) {
    const cfg = loadProviderConfig(r.provider, deps.env)!;
    const send = ADAPTERS[r.provider] ?? genericSend;
    const cb = deps.callbackUrl + (deps.callbackUrl.includes("?") ? "&" : "?") + "provider=" + encodeURIComponent(r.provider);
    const out = await send(cfg, r, cb, deps.fetchFn);
    if (out.ok) { await deps.accepted(r.request_id, out.externalRef, out.candidateUrl); accepted++; }
    else { await deps.failed(r.request_id, out.http, out.detail); failed++; }
  }
  return { status: 200, body: { ok: true, claimed: claimed.length, accepted, failed } };
}

// ------------------------------------------------------------ santé : configuration seulement, aucun appel au fournisseur
export type HealthDeps = {
  env: Env;
  listProviders: () => Promise<{ code: string; status: string }[]>;
  report: (rows: { provider: string; base_url: boolean; api_key: boolean; webhook_secret: boolean }[]) => Promise<{ error: string | null }>;
};

export async function processHealth(deps: HealthDeps): Promise<Outcome> {
  const providers = await deps.listProviders();
  const rows = providers.map((p) => ({ provider: p.code, ...configPresence(p.code, deps.env) }));
  if (rows.length > 0) {
    const w = await deps.report(rows);
    if (w.error) return { status: 500, body: { error: "report_failed", code: "report_failed" } };
  }
  const active = providers.filter((p) => p.status === "actif");
  const ready = active.filter((p) => isFullyConfigured(configPresence(p.code, deps.env))).length;
  return { status: 200, body: { ok: true, providers: providers.length, active: active.length, active_configured: ready, active_not_configured: active.length - ready } };
}

// Appelant autorisé : clé de service (en-tête Authorization) ou clé interne de la planification (en-tête x-dispatch-key, vérifiée par la base).
export async function isAuthorizedCaller(a: { bearer: string; serviceKey: string; dispatchKey: string; checkDispatchKey: (key: string) => Promise<boolean> }): Promise<boolean> {
  if (a.bearer && a.serviceKey && safeEqual(a.bearer, a.serviceKey)) return true;
  return a.dispatchKey !== "" && (await a.checkDispatchKey(a.dispatchKey)) === true;
}

// ------------------------------------------------------------ rappel du fournisseur
export async function hmacHex(secret: string, raw: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

export type CallbackDeps = {
  env: Env;
  now?: () => number;
  providerActive: (code: string) => Promise<boolean>;
  result: (a: { request: string; provider: string; externalRef: string | null; competences: unknown[]; criteria: unknown[]; evidence: unknown[]; details: Record<string, unknown>; limits: string; recommendations: unknown[] }) => Promise<{ data: any; error: string | null }>;
  providerFailed: (request: string, provider: string, detail: string) => Promise<{ data: any; error: string | null }>;
};

const isObj = (x: unknown): x is Record<string, unknown> => typeof x === "object" && x !== null && !Array.isArray(x);

export const TIMESTAMP_TOLERANCE_SECONDS = 300;

// Horodatage optionnel du rappel : secondes Unix (ou millisecondes) ; hors de ±5 minutes -> rejeté.
export function parseTimestamp(raw: string): number | null {
  if (!/^\d{10}(\d{3})?$/.test(raw.trim())) return null;
  const n = Number(raw.trim());
  return raw.trim().length === 13 ? Math.floor(n / 1000) : n;
}

export async function processCallback(providerCode: string, raw: string, signature: string | null, deps: CallbackDeps, timestamp: string | null = null): Promise<Outcome> {
  const cfg = loadProviderConfig(providerCode, deps.env);
  if (!cfg || !cfg.webhookSecret) return { status: 503, body: { error: "not_configured", code: "not_configured" } };
  const ts = timestamp !== null && timestamp.trim() !== "" ? timestamp : null;
  const requireTs = ["1", "true"].includes((deps.env(`ASSESSMENT_${providerCode.toUpperCase()}_REQUIRE_TIMESTAMP`) ?? "").trim().toLowerCase());
  if (ts === null && requireTs) return { status: 401, body: { error: "timestamp_required", code: "timestamp_required" } };
  // Avec horodatage, la signature couvre « <horodatage>.<corps> » : un message capturé ne peut pas être rejoué avec un horodatage neuf.
  const expected = "sha256=" + (await hmacHex(cfg.webhookSecret, ts === null ? raw : `${ts.trim()}.${raw}`));
  if (!signature || !safeEqual(signature.trim().toLowerCase(), expected)) return { status: 401, body: { error: "bad_signature", code: "bad_signature" } };
  if (ts !== null) {
    const sec = parseTimestamp(ts);
    const now = (deps.now ?? (() => Date.now()))() / 1000;
    if (sec === null || Math.abs(now - sec) > TIMESTAMP_TOLERANCE_SECONDS) return { status: 401, body: { error: "stale_timestamp", code: "stale_timestamp" } };
  }
  if (raw.length > 200_000) return { status: 413, body: { error: "too_large", code: "too_large" } };
  if (!(await deps.providerActive(providerCode))) return { status: 409, body: { error: "provider_not_active", code: "provider_not_active" } };
  let b: any;
  try { b = JSON.parse(raw); } catch { return { status: 400, body: { error: "bad_request", code: "bad_json" } }; }
  if (!isObj(b) || typeof b.reference !== "string" || !UUID_RE.test(b.reference)) return { status: 400, body: { error: "bad_request", code: "bad_reference" } };
  const externalRef = typeof b.external_ref === "string" && b.external_ref.trim() ? b.external_ref.trim().slice(0, 200) : null;
  if (b.status === "failed") {
    const r = await deps.providerFailed(b.reference, providerCode, typeof b.detail === "string" ? b.detail.slice(0, 300) : "échec signalé");
    return r.error ? { status: 422, body: { error: "rejected", code: "rejected" } } : { status: 200, body: { ok: true, status: "failed" } };
  }
  if (b.status !== "completed") return { status: 400, body: { error: "bad_request", code: "bad_status" } };
  // Rien n'est complété ni deviné : chaque rubrique doit venir du fournisseur ; les limites sont obligatoires.
  if (!Array.isArray(b.competences) || b.competences.length === 0 || b.competences.length > 50) return { status: 400, body: { error: "bad_request", code: "bad_competences" } };
  if (!Array.isArray(b.criteria) || b.criteria.length > 200) return { status: 400, body: { error: "bad_request", code: "bad_criteria" } };
  const evidence = b.evidence ?? [], recs = b.recommendations ?? [], details = b.details ?? {};
  if (!Array.isArray(evidence) || evidence.length > 200 || !Array.isArray(recs) || recs.length > 50 || !isObj(details)) return { status: 400, body: { error: "bad_request", code: "bad_shape" } };
  if (typeof b.limits !== "string" || b.limits.trim().length === 0 || b.limits.length > 2000) return { status: 400, body: { error: "bad_request", code: "missing_limits" } };
  const r = await deps.result({ request: b.reference, provider: providerCode, externalRef, competences: b.competences, criteria: b.criteria, evidence, details, limits: b.limits.trim(), recommendations: recs });
  if (r.error) return { status: 422, body: { error: "rejected", code: "rejected" } };
  if (r.data?.ok === false) return { status: r.data.reason === "result_rejected" ? 422 : 409, body: { error: String(r.data.reason ?? "rejected"), code: String(r.data.reason ?? "rejected") } };
  return { status: 200, body: { ok: true, duplicate: r.data?.duplicate === true } };
}
