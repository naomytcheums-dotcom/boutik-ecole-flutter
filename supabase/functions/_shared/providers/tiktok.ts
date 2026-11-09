// TikTok : Login Kit + Display API (lecture des vidéos). La publication (Content Posting API) exige un audit TikTok : non proposée.
import { fetchJson, form } from "../core.ts";
import { arr, Provider, str } from "./types.ts";

export const tiktok: Provider = {
  id: "tiktok", kind: "oauth2", env: "TIKTOK", pkce: true,
  authorizeUrl: "https://www.tiktok.com/v2/auth/authorize/",
  tokenUrl: "https://open.tiktokapis.com/v2/oauth/token/",
  scopes: ["user.info.basic", "video.list"], scopeSeparator: ",",
  clientIdParam: "client_key", tokenAuth: "body", minIntervalSec: 1800,
  refresh: async (t, c) => {
    if (!t.refresh) return null;
    const d = await fetchJson("https://open.tiktokapis.com/v2/oauth/token/", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form({ client_key: c.id, client_secret: c.secret, grant_type: "refresh_token", refresh_token: t.refresh }),
    });
    return { access: str(d.access_token), refresh: str(d.refresh_token) || t.refresh, expiresIn: Number(d.expires_in) || undefined, raw: {} };
  },
  profile: async (t) => {
    const d = await fetchJson("https://open.tiktokapis.com/v2/user/info/?fields=open_id,display_name,profile_deep_link", { headers: { Authorization: `Bearer ${t.access}` } });
    const u = ((d.data as Record<string, unknown>)?.user ?? {}) as Record<string, unknown>;
    return { externalId: str(u.open_id || t.raw.open_id), displayName: str(u.display_name) || "Compte TikTok", profileUrl: str(u.profile_deep_link) || undefined };
  },
  importItems: async (c) => {
    const d = await fetchJson("https://open.tiktokapis.com/v2/video/list/?fields=id,title,video_description,share_url,cover_image_url,create_time", {
      method: "POST", headers: { Authorization: `Bearer ${c.token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ max_count: 20, ...(c.cursor ? { cursor: Number(c.cursor) } : {}) }),
    });
    const data = (d.data ?? {}) as Record<string, unknown>;
    return {
      items: arr(data.videos).map((v) => ({
        externalId: str(v.id), kind: "video", title: str(v.title || v.video_description).slice(0, 120) || "Vidéo TikTok", body: str(v.video_description) || undefined,
        url: str(v.share_url) || undefined, mediaUrl: str(v.cover_image_url) || undefined,
        publishedAt: v.create_time ? new Date(Number(v.create_time) * 1000).toISOString() : undefined,
      })),
    };
  },
};
