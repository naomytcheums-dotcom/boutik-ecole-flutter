// Dropbox : OAuth 2.0 + PKCE, jeton de rafraîchissement (token_access_type=offline), lecture des métadonnées.
import { fetchJson } from "../core.ts";
import { arr, Provider, str } from "./types.ts";

const api = (t: string) => ({ Authorization: `Bearer ${t}`, "Content-Type": "application/json" });

export const dropbox: Provider = {
  id: "dropbox", kind: "oauth2", env: "DROPBOX", pkce: true,
  authorizeUrl: "https://www.dropbox.com/oauth2/authorize",
  tokenUrl: "https://api.dropboxapi.com/oauth2/token",
  scopes: ["account_info.read", "files.metadata.read"],
  extraAuthParams: { token_access_type: "offline" },
  tokenAuth: "body", minIntervalSec: 900,
  revokeUrl: (t) => ({ url: "https://api.dropboxapi.com/2/auth/token/revoke", init: { method: "POST", headers: { Authorization: `Bearer ${t}` } } }),
  profile: async (t) => {
    const d = await fetchJson("https://api.dropboxapi.com/2/users/get_current_account", { method: "POST", headers: { Authorization: `Bearer ${t.access}` } });
    const n = (d.name ?? {}) as Record<string, unknown>;
    return { externalId: str(d.account_id), displayName: str(n.display_name || d.email) || "Compte Dropbox" };
  },
  // Synchronisation incrémentale : le curseur de list_folder évite de relire tout le dossier (quota).
  importItems: async (c) => {
    const first = !c.cursor;
    const d = await fetchJson(first ? "https://api.dropboxapi.com/2/files/list_folder" : "https://api.dropboxapi.com/2/files/list_folder/continue", {
      method: "POST", headers: api(c.token), body: JSON.stringify(first ? { path: "", limit: 50, recursive: false } : { cursor: c.cursor }),
    });
    return {
      cursor: str(d.cursor) || c.cursor,
      items: arr(d.entries).filter((e) => e[".tag"] !== "deleted").map((e) => ({
        externalId: str(e.id), kind: e[".tag"] === "folder" ? "folder" : "file", title: str(e.name), publishedAt: str(e.server_modified) || undefined,
      })),
    };
  },
};
