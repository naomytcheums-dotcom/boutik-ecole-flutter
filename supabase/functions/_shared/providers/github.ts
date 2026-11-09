// GitHub : OAuth App (+ PKCE), lecture du profil et des dépôts PUBLICS pour le portfolio. Aucune portée « repo ».
import { arr, get, Provider, str } from "./types.ts";

const H = { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "boutik-ecole" };

export const github: Provider = {
  id: "github", kind: "oauth2", env: "GITHUB", pkce: true,
  authorizeUrl: "https://github.com/login/oauth/authorize",
  tokenUrl: "https://github.com/login/oauth/access_token",
  scopes: ["read:user"], scopeSeparator: " ",
  tokenAuth: "body", minIntervalSec: 900,
  // Révocation de l'autorisation de l'application (DELETE /applications/{client_id}/grant, authentification Basic de l'application).
  revokeUrl: (t, c) => ({ url: `https://api.github.com/applications/${c.id}/grant`, init: { method: "DELETE", headers: { Authorization: "Basic " + btoa(`${c.id}:${c.secret}`), ...H, "Content-Type": "application/json" }, body: JSON.stringify({ access_token: t }) } }),
  profile: async (t) => {
    const u = await get("https://api.github.com/user", t.access, H);
    return { externalId: str(u.id), displayName: str(u.login), profileUrl: str(u.html_url) || undefined };
  },
  importItems: async (c) => {
    const d = await fetch("https://api.github.com/user/repos?visibility=public&affiliation=owner&sort=pushed&per_page=50", { headers: { Authorization: `Bearer ${c.token}`, ...H } });
    const list = arr(await d.json().catch(() => []));
    return {
      items: list.filter((r) => !r.fork).map((r) => ({
        externalId: str(r.id), kind: "repo", title: str(r.name), body: [str(r.description), r.language ? `Langage : ${str(r.language)}` : "", `★ ${str(r.stargazers_count)}`].filter(Boolean).join(" · "),
        url: str(r.html_url) || undefined, publishedAt: str(r.pushed_at) || undefined,
      })),
    };
  },
};
