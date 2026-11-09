// Moteur commun des connecteurs : autorisation (OAuth 2.0 + PKCE, OAuth 1.0a pour Trello), rafraîchissement, synchronisation, publication, révocation.
// Toutes les opérations utilisent la clé de service ; l'appelant a été authentifié et la propriété des lignes est revérifiée ici.
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  APP_ORIGIN, encryptionConfigured, fetchJson, form, open, pkcePair, ProviderError, randomToken, redirectUri, seal,
} from "./core.ts";
import { adaptText } from "./adapt.ts";
import { configured, creds, PROVIDERS } from "./providers/index.ts";
import { oauth1Header, TRELLO } from "./providers/trello.ts";
import { Provider, TokenSet } from "./providers/types.ts";

const DEFAULT_INTERVAL = 900; // 15 min entre deux lectures d'un même compte, sauf règle plus stricte du fournisseur

type Admin = SupabaseClient;

// ---------------------------------------------------------------- autorisation
export async function startAuthorization(admin: Admin, userId: string, providerId: string, returnTo?: string): Promise<{ url: string }> {
  const p = PROVIDERS[providerId];
  if (!p) throw new ProviderError(400, "Fournisseur inconnu ou sans autorisation en ligne.");
  if (!encryptionConfigured()) throw new ProviderError(503, "Le chiffrement des jetons n'est pas encore configuré (INTEGRATIONS_ENC_KEY).");
  if (!configured(p)) throw new ProviderError(503, `${p.id} : l'application développeur n'est pas encore enregistrée (identifiants manquants).`);
  const c = creds(p);
  const state = randomToken(24);
  await admin.from("integration_oauth_states").delete().lt("expires_at", new Date().toISOString());
  const ret = returnTo && returnTo.startsWith(APP_ORIGIN + "/") ? returnTo : `${APP_ORIGIN}/s/P5`;

  if (p.kind === "oauth1a") {
    const cb = `${redirectUri()}?state=${state}`;
    const hdr = await oauth1Header("POST", TRELLO.requestToken, { key: c.id, secret: c.secret }, undefined, { oauth_callback: cb });
    const res = await fetch(TRELLO.requestToken, { method: "POST", headers: { Authorization: hdr } });
    const body = new URLSearchParams(await res.text());
    const tok = body.get("oauth_token"), sec = body.get("oauth_token_secret");
    if (!res.ok || !tok || !sec) throw new ProviderError(502, "Trello a refusé la demande d'autorisation.");
    await admin.from("integration_oauth_states").insert({ state, user_id: userId, provider: p.id, extra_enc: await seal(sec), return_to: ret });
    const url = `${TRELLO.authorize}?` + form({ oauth_token: tok, name: "Boutik-École", scope: p.scopes.join(","), expiration: "never" });
    return { url };
  }

  const pk = p.pkce ? await pkcePair() : null;
  await admin.from("integration_oauth_states").insert({ state, user_id: userId, provider: p.id, verifier_enc: pk ? await seal(pk.verifier) : null, return_to: ret });
  const q: Record<string, string> = {
    [p.clientIdParam ?? "client_id"]: c.id, redirect_uri: redirectUri(), response_type: "code", state, ...(p.extraAuthParams ?? {}),
  };
  if (p.scopes.length) q.scope = p.scopes.join(p.scopeSeparator ?? " ");
  if (pk) { q.code_challenge = pk.challenge; q.code_challenge_method = "S256"; }
  return { url: `${p.authorizeUrl}?${form(q)}` };
}

async function exchangeCode(p: Provider, code: string, verifier: string | null): Promise<TokenSet> {
  const c = creds(p);
  const params: Record<string, string> = { grant_type: "authorization_code", code, redirect_uri: redirectUri() };
  const headers: Record<string, string> = { Accept: "application/json" };
  if (p.tokenAuth === "basic") headers.Authorization = "Basic " + btoa(`${c.id}:${c.secret}`);
  else { params[p.clientIdParam ?? "client_id"] = c.id; params.client_secret = c.secret; }
  if (verifier) params.code_verifier = verifier;
  const json = p.tokenBody === "json";
  headers["Content-Type"] = json ? "application/json" : "application/x-www-form-urlencoded";
  const d = await fetchJson(p.tokenUrl, { method: "POST", headers, body: json ? JSON.stringify(params) : form(params) });
  return toTokenSet(d, p);
}

function toTokenSet(d: Record<string, unknown>, p: Provider): TokenSet {
  const access = String(d.access_token ?? "");
  if (!access) throw new ProviderError(502, "Le fournisseur n'a pas renvoyé de jeton.");
  const scope = typeof d.scope === "string" ? d.scope.split(/[ ,]+/).filter(Boolean) : Array.isArray(d.scope) ? d.scope.map(String) : undefined;
  return { access, refresh: d.refresh_token ? String(d.refresh_token) : undefined, expiresIn: Number(d.expires_in) || undefined, scopes: scope ?? p.scopes, raw: d };
}

/** Retour du fournisseur : crée ou met à jour la connexion. Renvoie l'adresse de retour dans l'application. */
export async function completeAuthorization(admin: Admin, params: URLSearchParams): Promise<string> {
  const state = params.get("state") ?? "";
  const { data: st } = await admin.from("integration_oauth_states").select("*").eq("state", state).maybeSingle();
  const fail = (ret: string, why: string, prov = "") => `${ret}?connexion=erreur&p=${encodeURIComponent(prov)}&m=${encodeURIComponent(why)}`;
  if (!st) return fail(`${APP_ORIGIN}/s/P5`, "Demande expirée ou inconnue : recommencez la connexion.");
  await admin.from("integration_oauth_states").delete().eq("state", state); // usage unique
  const ret = String(st.return_to ?? `${APP_ORIGIN}/s/P5`).split("?")[0];
  if (new Date(st.expires_at).getTime() < Date.now()) return fail(ret, "Demande expirée : recommencez la connexion.", st.provider);
  const p = PROVIDERS[st.provider as string];
  if (!p) return fail(ret, "Fournisseur inconnu.");
  if (params.get("error") || params.get("denied")) return fail(ret, "Autorisation refusée : aucune connexion créée.", p.id);

  try {
    let t: TokenSet;
    if (p.kind === "oauth1a") {
      const c = creds(p);
      const reqTok = params.get("oauth_token") ?? "", verifier = params.get("oauth_verifier") ?? "";
      const sec = await open(String(st.extra_enc));
      const hdr = await oauth1Header("POST", TRELLO.accessToken, { key: c.id, secret: c.secret }, { key: reqTok, secret: sec }, { oauth_verifier: verifier });
      const res = await fetch(TRELLO.accessToken, { method: "POST", headers: { Authorization: hdr } });
      const body = new URLSearchParams(await res.text());
      if (!res.ok || !body.get("oauth_token")) throw new ProviderError(502, "Trello a refusé l'échange du jeton.");
      t = { access: body.get("oauth_token")!, scopes: p.scopes, raw: {} };
    } else {
      const code = params.get("code");
      if (!code) throw new ProviderError(400, "Code d'autorisation absent.");
      t = await exchangeCode(p, code, st.verifier_enc ? await open(String(st.verifier_enc)) : null);
      if (p.afterToken) t = await p.afterToken(t, creds(p));
    }
    const prof = await p.profile(t);
    const connId = await persistConnection(admin, st.user_id as string, p, t, prof);
    void connId;
    return `${ret}?connexion=ok&p=${p.id}`;
  } catch (e) {
    // Aucune donnée du fournisseur dans le message : seulement notre texte.
    return fail(ret, e instanceof ProviderError || e instanceof Error ? e.message.slice(0, 160) : "Connexion impossible.", p.id);
  }
}

async function persistConnection(admin: Admin, userId: string, p: Provider, t: TokenSet, prof: Awaited<ReturnType<Provider["profile"]>>): Promise<string> {
  const expires = t.expiresIn ? new Date(Date.now() + t.expiresIn * 1000).toISOString() : null;
  const { data: conn, error } = await admin.from("integration_connections").upsert({
    user_id: userId, provider: p.id, external_id: prof.externalId, display_name: prof.displayName, profile_url: prof.profileUrl ?? null,
    status: "connected", last_error: null, connected_at: new Date().toISOString(), expires_at: expires,
  }, { onConflict: "user_id,provider,external_id" }).select("id").single();
  if (error || !conn) throw new Error("Enregistrement de la connexion impossible.");

  const { data: old } = await admin.from("integration_tokens").select("refresh_enc,extra_enc").eq("connection_id", conn.id).maybeSingle();
  let extra: Record<string, unknown> = {};
  if (old?.extra_enc) { try { extra = JSON.parse(await open(old.extra_enc)); } catch { extra = {}; } }
  for (const [k, v] of Object.entries(prof.extra ?? {})) {
    extra[k] = v && typeof v === "object" && !Array.isArray(v) && extra[k] && typeof extra[k] === "object" ? { ...(extra[k] as object), ...(v as object) } : v;
  }
  await admin.from("integration_tokens").upsert({
    connection_id: conn.id,
    access_enc: await seal(t.access),
    refresh_enc: t.refresh ? await seal(t.refresh) : (old?.refresh_enc ?? null),
    extra_enc: Object.keys(extra).length ? await seal(JSON.stringify(extra)) : null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "connection_id" });

  // Permissions réellement accordées.
  await admin.from("integration_permissions").delete().eq("connection_id", conn.id);
  const scopes = [...new Set(t.scopes ?? p.scopes)];
  if (scopes.length) await admin.from("integration_permissions").insert(scopes.map((scope) => ({ connection_id: conn.id, user_id: userId, scope })));

  // Comptes externes : les nouveaux sont ajoutés, les existants gardent le choix « publier » de l'utilisateur.
  const { data: have } = await admin.from("integration_accounts").select("external_id").eq("connection_id", conn.id);
  const known = new Set((have ?? []).map((a: { external_id: string }) => a.external_id));
  for (const a of prof.accounts ?? []) {
    if (known.has(a.externalId)) await admin.from("integration_accounts").update({ name: a.name, url: a.url ?? null }).eq("connection_id", conn.id).eq("external_id", a.externalId);
    else await admin.from("integration_accounts").insert({ connection_id: conn.id, user_id: userId, provider: p.id, external_id: a.externalId, kind: a.kind, name: a.name, url: a.url ?? null, publish_enabled: a.publish ?? false });
  }
  return conn.id as string;
}

// ---------------------------------------------------------------- jetons
export interface Live { access: string; extra: Record<string, unknown> }

/** Jeton d'accès valide : rafraîchi si proche de l'expiration ; si le rafraîchissement échoue, la connexion passe à « expired » (reconnexion demandée). */
export async function liveToken(admin: Admin, conn: Record<string, unknown>): Promise<Live> {
  const p = PROVIDERS[conn.provider as string];
  const { data: tk } = await admin.from("integration_tokens").select("*").eq("connection_id", conn.id).maybeSingle();
  if (!p || !tk) throw new ProviderError(401, "Connexion sans jeton : reconnectez ce compte.", undefined, true);
  let access = await open(tk.access_enc);
  const refresh = tk.refresh_enc ? await open(tk.refresh_enc) : undefined;
  const extra = tk.extra_enc ? JSON.parse(await open(tk.extra_enc)) as Record<string, unknown> : {};
  const exp = conn.expires_at ? new Date(String(conn.expires_at)).getTime() : null;
  if (exp !== null && exp - Date.now() < 120_000) {
    try {
      const c = creds(p);
      let next: TokenSet | null = null;
      if (p.refresh) next = await p.refresh({ access, refresh }, c);
      else if (refresh) {
        const params: Record<string, string> = { grant_type: "refresh_token", refresh_token: refresh };
        const headers: Record<string, string> = { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" };
        if (p.tokenAuth === "basic") headers.Authorization = "Basic " + btoa(`${c.id}:${c.secret}`);
        else { params[p.clientIdParam ?? "client_id"] = c.id; params.client_secret = c.secret; }
        next = toTokenSet(await fetchJson(p.tokenUrl, { method: "POST", headers, body: form(params) }), p);
      }
      if (!next) throw new ProviderError(401, "expired", undefined, true);
      access = next.access;
      const expires = next.expiresIn ? new Date(Date.now() + next.expiresIn * 1000).toISOString() : null;
      await admin.from("integration_tokens").update({ access_enc: await seal(next.access), ...(next.refresh ? { refresh_enc: await seal(next.refresh) } : {}), updated_at: new Date().toISOString() }).eq("connection_id", conn.id);
      await admin.from("integration_connections").update({ expires_at: expires, status: "connected", last_error: null }).eq("id", conn.id);
    } catch (e) {
      await admin.from("integration_connections").update({ status: "expired", last_error: "Autorisation expirée : reconnectez ce compte." }).eq("id", conn.id);
      throw new ProviderError(401, "Autorisation expirée : reconnectez ce compte.", undefined, e instanceof ProviderError ? e.authFailure || true : true);
    }
  }
  return { access, extra };
}

// ---------------------------------------------------------------- synchronisation
export interface SyncResult { status: "ok" | "partial" | "error" | "throttled" | "unsupported"; imported: number; skipped: number; message?: string; retryAt?: string }

export async function syncConnection(admin: Admin, connId: string, userId: string | null, trigger: "manual" | "webhook" | "schedule" | "connect"): Promise<SyncResult> {
  const { data: conn } = await admin.from("integration_connections").select("*").eq("id", connId).maybeSingle();
  if (!conn || (userId && conn.user_id !== userId)) return { status: "error", imported: 0, skipped: 0, message: "Connexion introuvable." };
  const p = PROVIDERS[conn.provider];
  if (!p?.importItems) return { status: "unsupported", imported: 0, skipped: 0, message: "Ce fournisseur ne propose pas d'import." };
  if (conn.status !== "connected") return { status: "error", imported: 0, skipped: 0, message: conn.status === "expired" ? "Autorisation expirée : reconnectez ce compte." : "Connexion inactive." };
  const now = Date.now();
  if (conn.next_sync_at && new Date(conn.next_sync_at).getTime() > now && trigger !== "webhook") {
    await admin.from("integration_sync_logs").insert({ connection_id: connId, user_id: conn.user_id, provider: conn.provider, trigger, status: "throttled", message: "Quota : synchronisation trop rapprochée.", finished_at: new Date().toISOString() });
    return { status: "throttled", imported: 0, skipped: 0, message: "Synchronisation trop rapprochée, réessayez plus tard.", retryAt: conn.next_sync_at };
  }
  const interval = (p.minIntervalSec ?? DEFAULT_INTERVAL) * 1000;
  const log = async (r: SyncResult) => { await admin.from("integration_sync_logs").insert({ connection_id: connId, user_id: conn.user_id, provider: conn.provider, trigger, status: r.status === "unsupported" ? "error" : r.status, imported: r.imported, skipped: r.skipped, message: r.message ?? null, finished_at: new Date().toISOString() }); };
  try {
    const live = await liveToken(admin, conn);
    const { data: accs } = await admin.from("integration_accounts").select("id,external_id,name").eq("connection_id", connId);
    const out = await p.importItems({ token: live.access, cursor: conn.sync_cursor ?? undefined, extra: live.extra, externalId: conn.external_id, accounts: (accs ?? []).map((a: { id: string; external_id: string; name: string }) => ({ id: a.id, externalId: a.external_id, name: a.name })) });
    const ids = out.items.map((i) => i.externalId);
    const { data: have } = ids.length ? await admin.from("integration_imported_items").select("external_id").eq("connection_id", connId).in("external_id", ids) : { data: [] };
    const known = new Set((have ?? []).map((h: { external_id: string }) => h.external_id));
    const fresh = out.items.filter((i) => !known.has(i.externalId));
    if (fresh.length) {
      await admin.from("integration_imported_items").upsert(fresh.map((i) => ({
        connection_id: connId, user_id: conn.user_id, provider: conn.provider, external_id: i.externalId, kind: i.kind, title: i.title.slice(0, 300), body: i.body?.slice(0, 5000) ?? null,
        url: i.url ?? null, media_url: i.mediaUrl ?? null, published_at: i.publishedAt ?? null,
      })), { onConflict: "connection_id,external_id", ignoreDuplicates: true });
    }
    await admin.from("integration_connections").update({ last_sync_at: new Date().toISOString(), next_sync_at: new Date(now + interval).toISOString(), sync_cursor: out.cursor ?? conn.sync_cursor, last_error: null }).eq("id", connId);
    const r: SyncResult = { status: "ok", imported: fresh.length, skipped: out.items.length - fresh.length };
    await log(r);
    return r;
  } catch (e) {
    const pe = e instanceof ProviderError ? e : null;
    if (pe && (pe.status === 429 || pe.retryAfterSec)) {
      const at = new Date(now + (pe.retryAfterSec ?? 900) * 1000).toISOString();
      await admin.from("integration_connections").update({ next_sync_at: at }).eq("id", connId);
      const r: SyncResult = { status: "throttled", imported: 0, skipped: 0, message: "Limite de requêtes atteinte chez le fournisseur.", retryAt: at };
      await log(r);
      return r;
    }
    if (pe?.authFailure) await admin.from("integration_connections").update({ status: "expired", last_error: "Autorisation expirée : reconnectez ce compte." }).eq("id", connId);
    const msg = (e instanceof Error ? e.message : "Erreur de synchronisation").slice(0, 200);
    await admin.from("integration_connections").update({ last_error: msg }).eq("id", connId);
    const r: SyncResult = { status: "error", imported: 0, skipped: 0, message: msg };
    await log(r);
    return r;
  }
}

// ---------------------------------------------------------------- déconnexion
export async function disconnect(admin: Admin, userId: string, connId: string, purge: boolean): Promise<{ revokedAtProvider: boolean }> {
  const { data: conn } = await admin.from("integration_connections").select("*").eq("id", connId).eq("user_id", userId).maybeSingle();
  if (!conn) throw new ProviderError(404, "Connexion introuvable.");
  const p = PROVIDERS[conn.provider];
  let revoked = false;
  if (p?.revokeUrl && encryptionConfigured()) {
    try {
      const { data: tk } = await admin.from("integration_tokens").select("access_enc").eq("connection_id", connId).maybeSingle();
      if (tk) {
        const r = p.revokeUrl(await open(tk.access_enc), creds(p));
        if (r) { const res = await fetch(r.url, r.init); await res.body?.cancel(); revoked = res.ok; }
      }
    } catch { revoked = false; }
  }
  await admin.from("integration_tokens").delete().eq("connection_id", connId); // dans tous les cas, nos copies du jeton disparaissent
  if (purge) {
    await admin.from("integration_connections").delete().eq("id", connId);
  } else {
    await admin.from("integration_accounts").update({ publish_enabled: false }).eq("connection_id", connId);
    await admin.from("integration_connections").update({ status: "revoked", expires_at: null, next_sync_at: null, last_error: null }).eq("id", connId);
  }
  return { revokedAtProvider: revoked };
}

// ---------------------------------------------------------------- publication
export interface TargetIn { connection_id: string; account_id?: string }
export interface TargetOut { target_id: string; provider: string; status: string; adapted_text: string; result_url?: string; error?: string; note?: string }

export async function publishAll(admin: Admin, userId: string, input: { content: string; link_url?: string; media_url?: string; title?: string; idempotency_key: string; targets: TargetIn[] }): Promise<{ publication_id: string; results: TargetOut[] }> {
  const content = input.content.trim();
  if (!content || content.length > 5000) throw new ProviderError(400, "Le texte doit contenir de 1 à 5000 caractères.");
  if (!input.targets?.length) throw new ProviderError(400, "Choisissez au moins une destination.");
  if (!input.idempotency_key || input.idempotency_key.length < 8) throw new ProviderError(400, "Clé d'unicité manquante.");
  for (const u of [input.link_url, input.media_url]) if (u && !/^https:\/\/\S{3,500}$/.test(u)) throw new ProviderError(400, "Les liens doivent commencer par https://");

  // Anti-doublon : la même clé d'unicité retrouve la publication existante sans rien renvoyer.
  let pub = (await admin.from("integration_publications").select("id").eq("user_id", userId).eq("idempotency_key", input.idempotency_key).maybeSingle()).data;
  if (!pub) {
    const ins = await admin.from("integration_publications").insert({ user_id: userId, content, link_url: input.link_url ?? null, media_url: input.media_url ?? null, idempotency_key: input.idempotency_key }).select("id").single();
    if (ins.error || !ins.data) throw new ProviderError(500, "Publication non enregistrée.");
    pub = ins.data;
  }
  const results: TargetOut[] = [];
  for (const t of input.targets.slice(0, 12)) {
    const { data: conn } = await admin.from("integration_connections").select("*").eq("id", t.connection_id).eq("user_id", userId).maybeSingle();
    if (!conn) continue;
    const p = PROVIDERS[conn.provider];
    const { data: acc } = t.account_id ? await admin.from("integration_accounts").select("*").eq("id", t.account_id).eq("connection_id", conn.id).maybeSingle() : { data: null };
    const ad = adaptText(conn.provider, content, input.link_url);
    // Une ligne par (publication, connexion, compte) : un second appel ne renvoie jamais une cible déjà envoyée.
    const q = admin.from("integration_publication_targets").select("*").eq("publication_id", pub.id).eq("connection_id", conn.id);
    let row = (await (t.account_id ? q.eq("account_id", t.account_id) : q.is("account_id", null)).maybeSingle()).data;
    if (!row) {
      row = (await admin.from("integration_publication_targets").insert({ publication_id: pub.id, user_id: userId, connection_id: conn.id, account_id: t.account_id ?? null, provider: conn.provider, adapted_text: ad.text }).select("*").single()).data;
    }
    if (!row) continue;
    if (row.status === "sent") { results.push({ target_id: row.id, provider: conn.provider, status: "sent", adapted_text: row.adapted_text, result_url: row.result_url ?? undefined }); continue; }
    const fail = async (status: "failed" | "unsupported", msg: string) => {
      await admin.from("integration_publication_targets").update({ status, error: msg }).eq("id", row!.id);
      results.push({ target_id: row!.id, provider: conn.provider, status, adapted_text: ad.text, error: msg });
    };
    if (!p?.publish) { await fail("unsupported", "Ce fournisseur n'autorise pas la publication par l'API officielle."); continue; }
    if (conn.status !== "connected") { await fail("failed", "Autorisation expirée : reconnectez ce compte."); continue; }
    try {
      const live = await liveToken(admin, conn);
      const r = await p.publish({ token: live.access, extra: live.extra, externalId: conn.external_id, account: acc ? { externalId: acc.external_id, name: acc.name } : undefined, text: ad.text, linkUrl: ad.link, mediaUrl: input.media_url, title: input.title });
      await admin.from("integration_publication_targets").update({ status: "sent", result_url: r.url ?? null, external_id: r.externalId ?? null, error: null, sent_at: new Date().toISOString() }).eq("id", row.id);
      results.push({ target_id: row.id, provider: conn.provider, status: "sent", adapted_text: ad.text, result_url: r.url, note: ad.note });
    } catch (e) {
      await fail("failed", (e instanceof Error ? e.message : "Échec de l'envoi").slice(0, 200));
    }
  }
  return { publication_id: pub.id as string, results };
}

export { configured, PROVIDERS };
