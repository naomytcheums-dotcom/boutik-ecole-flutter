// Facebook : Pages uniquement (l'API officielle ne publie pas sur les profils personnels). Revue d'application Meta requise.
import { fetchJson, form } from "../core.ts";
import { arr, GRAPH, Provider, str } from "./types.ts";

const g = (p: string) => `https://graph.facebook.com/${GRAPH}${p}`;

export const facebook: Provider = {
  id: "facebook", kind: "oauth2", env: "FACEBOOK", pkce: false,
  authorizeUrl: `https://www.facebook.com/${GRAPH}/dialog/oauth`,
  tokenUrl: g("/oauth/access_token"),
  scopes: ["public_profile", "pages_show_list", "pages_read_engagement", "pages_manage_posts"],
  scopeSeparator: ",",
  minIntervalSec: 900, maxText: 5000,
  // Jeton de courte durée -> jeton de longue durée (60 jours) ; les jetons de Page qui en dérivent n'expirent pas.
  afterToken: async (t, c) => {
    const d = await fetchJson(g("/oauth/access_token?" + form({ grant_type: "fb_exchange_token", client_id: c.id, client_secret: c.secret, fb_exchange_token: t.access })));
    return { ...t, access: str(d.access_token), expiresIn: Number(d.expires_in) || undefined };
  },
  revokeUrl: (t) => ({ url: g(`/me/permissions?access_token=${encodeURIComponent(t)}`), init: { method: "DELETE" } }),
  profile: async (t) => {
    const me = await fetchJson(g(`/me?fields=id,name,link&access_token=${encodeURIComponent(t.access)}`));
    const pages = await fetchJson(g(`/me/accounts?fields=id,name,link,access_token&limit=50&access_token=${encodeURIComponent(t.access)}`));
    const tokens: Record<string, string> = {};
    const accounts = arr(pages.data).map((p) => {
      tokens[str(p.id)] = str(p.access_token);
      return { externalId: str(p.id), kind: "page", name: str(p.name), url: str(p.link) || undefined, publish: true };
    });
    return { externalId: str(me.id), displayName: str(me.name), profileUrl: str(me.link) || undefined, accounts, extra: { pageTokens: tokens } };
  },
  importItems: async (c) => {
    const items = [];
    const pt = (c.extra.pageTokens ?? {}) as Record<string, string>;
    for (const a of c.accounts) {
      const tok = pt[a.externalId];
      if (!tok) continue;
      const d = await fetchJson(g(`/${a.externalId}/posts?fields=id,message,permalink_url,created_time,full_picture&limit=25&access_token=${encodeURIComponent(tok)}`));
      for (const p of arr(d.data)) {
        items.push({
          externalId: str(p.id), kind: "post", title: str(p.message).slice(0, 120) || `Publication de ${a.name}`, body: str(p.message) || undefined,
          url: str(p.permalink_url) || undefined, mediaUrl: str(p.full_picture) || undefined, publishedAt: str(p.created_time) || undefined,
        });
      }
    }
    return { items };
  },
  publish: async (c) => {
    const page = c.account?.externalId;
    const tok = ((c.extra.pageTokens ?? {}) as Record<string, string>)[page ?? ""];
    if (!page || !tok) throw new Error("Choisissez une Page Facebook que vous administrez.");
    const body: Record<string, string> = { message: c.text, access_token: tok };
    if (c.linkUrl) body.link = c.linkUrl;
    const d = await fetchJson(g(`/${page}/feed`), { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: form(body) });
    return { externalId: str(d.id), url: `https://www.facebook.com/${str(d.id)}` };
  },
};
