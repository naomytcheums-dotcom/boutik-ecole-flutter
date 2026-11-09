// Instagram (API Instagram avec connexion Instagram) : comptes professionnels uniquement ; toute publication exige un média.
import { fetchJson, form } from "../core.ts";
import { arr, GRAPH, get, Provider, str } from "./types.ts";

const ig = (p: string) => `https://graph.instagram.com/${GRAPH}${p}`;
const hdr = (t: string) => ({ Authorization: `Bearer ${t}`, "Content-Type": "application/x-www-form-urlencoded" });

export const instagram: Provider = {
  id: "instagram", kind: "oauth2", env: "INSTAGRAM", pkce: false,
  authorizeUrl: "https://www.instagram.com/oauth/authorize",
  tokenUrl: "https://api.instagram.com/oauth/access_token",
  scopes: ["instagram_business_basic", "instagram_business_content_publish"],
  scopeSeparator: ",",
  minIntervalSec: 900, maxText: 2200,
  // Jeton d'1 h -> jeton de 60 jours.
  afterToken: async (t, c) => {
    const d = await fetchJson("https://graph.instagram.com/access_token?" + form({ grant_type: "ig_exchange_token", client_secret: c.secret, access_token: t.access }));
    return { ...t, access: str(d.access_token), expiresIn: Number(d.expires_in) || undefined };
  },
  // Rafraîchissement possible entre 24 h et 60 jours après l'émission du jeton.
  refresh: async (t) => {
    const d = await fetchJson("https://graph.instagram.com/refresh_access_token?" + form({ grant_type: "ig_refresh_token", access_token: t.access }));
    return { access: str(d.access_token), expiresIn: Number(d.expires_in) || undefined, raw: {} };
  },
  profile: async (t) => {
    const me = await fetchJson(ig(`/me?fields=user_id,username,account_type&access_token=${encodeURIComponent(t.access)}`));
    const id = str(me.user_id ?? me.id);
    const url = `https://www.instagram.com/${str(me.username)}/`;
    return { externalId: id, displayName: "@" + str(me.username), profileUrl: url, accounts: [{ externalId: id, kind: "account", name: "@" + str(me.username), url, publish: true }] };
  },
  importItems: async (c) => {
    const d = await get(ig("/me/media?fields=id,caption,media_type,permalink,media_url,thumbnail_url,timestamp&limit=25"), c.token);
    return {
      items: arr(d.data).map((m) => ({
        externalId: str(m.id), kind: str(m.media_type).toLowerCase() === "video" ? "video" : "post", title: str(m.caption).slice(0, 120) || "Publication Instagram",
        body: str(m.caption) || undefined, url: str(m.permalink) || undefined, mediaUrl: str(m.thumbnail_url || m.media_url) || undefined, publishedAt: str(m.timestamp) || undefined,
      })),
    };
  },
  publish: async (c) => {
    if (!c.mediaUrl) throw new Error("Instagram exige une image ou une vidéo : ajoutez un média ou copiez la légende.");
    const video = /\.(mp4|mov)(\?|$)/i.test(c.mediaUrl);
    const created = await fetchJson(ig(`/${c.externalId}/media`), { method: "POST", headers: hdr(c.token), body: form(video ? { media_type: "REELS", video_url: c.mediaUrl, caption: c.text } : { image_url: c.mediaUrl, caption: c.text }) });
    const pub = await fetchJson(ig(`/${c.externalId}/media_publish`), { method: "POST", headers: hdr(c.token), body: form({ creation_id: str(created.id) }) });
    const m = await get(ig(`/${str(pub.id)}?fields=permalink`), c.token).catch(() => ({} as Record<string, unknown>));
    return { externalId: str(pub.id), url: str(m.permalink) || undefined };
  },
};
