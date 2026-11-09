// Notion : intégration publique (OAuth 2.0, échange du code avec authentification Basic, jeton sans expiration).
// L'API ne voit que les pages que l'utilisateur partage lors de l'autorisation.
import { fetchJson } from "../core.ts";
import { arr, Provider, str } from "./types.ts";

const V = "2022-06-28";
const hdr = (t: string) => ({ Authorization: `Bearer ${t}`, "Notion-Version": V, "Content-Type": "application/json" });

function titleOf(p: Record<string, unknown>): string {
  const props = (p.properties ?? {}) as Record<string, Record<string, unknown>>;
  for (const v of Object.values(props)) {
    if (v.type === "title") return arr(v.title).map((x) => str(x.plain_text)).join("") || "Sans titre";
  }
  return "Sans titre";
}

async function pages(token: string) {
  const d = await fetchJson("https://api.notion.com/v1/search", {
    method: "POST", headers: hdr(token),
    body: JSON.stringify({ filter: { property: "object", value: "page" }, sort: { direction: "descending", timestamp: "last_edited_time" }, page_size: 25 }),
  });
  return arr(d.results);
}

export const notion: Provider = {
  id: "notion", kind: "oauth2", env: "NOTION", pkce: false,
  authorizeUrl: "https://api.notion.com/v1/oauth/authorize",
  tokenUrl: "https://api.notion.com/v1/oauth/token",
  scopes: [], extraAuthParams: { owner: "user" },
  tokenAuth: "basic", tokenBody: "json", minIntervalSec: 900, maxText: 1900,
  profile: async (t) => {
    const ps = await pages(t.access);
    return {
      externalId: str(t.raw.workspace_id || t.raw.bot_id), displayName: str(t.raw.workspace_name) || "Espace Notion",
      accounts: ps.map((p) => ({ externalId: str(p.id), kind: "page", name: titleOf(p), url: str(p.url) || undefined, publish: false })),
    };
  },
  importItems: async (c) => ({
    items: (await pages(c.token)).map((p) => ({ externalId: str(p.id), kind: "page", title: titleOf(p), url: str(p.url) || undefined, publishedAt: str(p.last_edited_time) || undefined })),
  }),
  // « Publier » = créer une sous-page sous la page partagée choisie.
  publish: async (c) => {
    if (!c.account) throw new Error("Choisissez une page Notion partagée.");
    const chunks = c.text.match(/[\s\S]{1,1900}/g) ?? [c.text];
    const d = await fetchJson("https://api.notion.com/v1/pages", {
      method: "POST", headers: hdr(c.token),
      body: JSON.stringify({
        parent: { page_id: c.account.externalId },
        properties: { title: { title: [{ text: { content: (c.title || c.text.split("\n")[0]).slice(0, 100) } }] } },
        children: chunks.slice(0, 90).map((t) => ({ object: "block", type: "paragraph", paragraph: { rich_text: [{ type: "text", text: { content: t } }] } })),
      }),
    });
    return { externalId: str(d.id), url: str(d.url) || undefined };
  },
};
