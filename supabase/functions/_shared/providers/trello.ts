// Trello : OAuth 1.0a officiel (Trello n'offre pas OAuth 2.0), signature HMAC-SHA1 faite côté serveur uniquement.
import { fetchJson, hmacBase64, randomToken } from "../core.ts";
import { arr, Provider, str } from "./types.ts";

export const TRELLO = {
  requestToken: "https://trello.com/1/OAuthGetRequestToken",
  authorize: "https://trello.com/1/OAuthAuthorizeToken",
  accessToken: "https://trello.com/1/OAuthGetAccessToken",
};

const pct = (s: string) => encodeURIComponent(s).replace(/[!'()*]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());

/** En-tête Authorization OAuth 1.0a (RFC 5849) signé en HMAC-SHA1. */
export async function oauth1Header(method: string, url: string, consumer: { key: string; secret: string }, token?: { key: string; secret: string },
  extra: Record<string, string> = {}): Promise<string> {
  const p: Record<string, string> = {
    oauth_consumer_key: consumer.key, oauth_nonce: randomToken(12), oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(Math.floor(Date.now() / 1000)), oauth_version: "1.0", ...extra,
  };
  if (token) p.oauth_token = token.key;
  const u = new URL(url);
  const all: [string, string][] = [...Object.entries(p), ...u.searchParams.entries()];
  const norm = all.map(([k, v]) => [pct(k), pct(v)] as [string, string]).sort((a, b) => (a[0] === b[0] ? (a[1] < b[1] ? -1 : 1) : a[0] < b[0] ? -1 : 1)).map(([k, v]) => `${k}=${v}`).join("&");
  const base = [method.toUpperCase(), pct(u.origin + u.pathname), pct(norm)].join("&");
  p.oauth_signature = await hmacBase64(`${pct(consumer.secret)}&${pct(token?.secret ?? "")}`, base, "SHA-1");
  return "OAuth " + Object.entries(p).map(([k, v]) => `${pct(k)}="${pct(v)}"`).join(", ");
}

const rest = (path: string, key: string, token: string) => `https://api.trello.com/1${path}${path.includes("?") ? "&" : "?"}key=${encodeURIComponent(key)}&token=${encodeURIComponent(token)}`;

export const trello: Provider = {
  id: "trello", kind: "oauth1a", env: "TRELLO",
  authorizeUrl: TRELLO.authorize, tokenUrl: TRELLO.accessToken, pkce: false,
  scopes: ["read"], minIntervalSec: 900,
  // `t.access` = jeton ; la clé d'application est lue dans l'environnement au moment de l'appel.
  profile: async (t) => {
    const key = Deno.env.get("TRELLO_CLIENT_ID") ?? "";
    const me = await fetchJson(rest("/members/me?fields=id,fullName,url", key, t.access));
    const boards = arr(await fetchJson(rest("/members/me/boards?filter=open&fields=id,name,url", key, t.access)) as unknown);
    return { externalId: str(me.id), displayName: str(me.fullName), profileUrl: str(me.url) || undefined, accounts: boards.map((b) => ({ externalId: str(b.id), kind: "board", name: str(b.name), url: str(b.url) || undefined })) };
  },
  importItems: async (c) => {
    const key = Deno.env.get("TRELLO_CLIENT_ID") ?? "";
    const list = await fetchJson(rest("/members/me/boards?filter=open&fields=id,name,url,desc,dateLastActivity", key, c.token) ) as unknown;
    return { items: arr(list).map((b) => ({ externalId: str(b.id), kind: "board", title: str(b.name), body: str(b.desc) || undefined, url: str(b.url) || undefined, publishedAt: str(b.dateLastActivity) || undefined })) };
  },
  revokeUrl: (t) => ({ url: rest(`/tokens/${encodeURIComponent(t)}`, Deno.env.get("TRELLO_CLIENT_ID") ?? "", t), init: { method: "DELETE" } }),
};
