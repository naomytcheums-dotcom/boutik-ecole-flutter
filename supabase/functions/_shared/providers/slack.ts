// Slack : OAuth v2 (jeton de bot). Slack n'accepte pas PKCE pour l'échange du code : le secret serveur est utilisé.
import { fetchJson, form } from "../core.ts";
import { arr, Provider, str } from "./types.ts";

const call = async (method: string, token: string, body?: Record<string, string>) => {
  const d = await fetchJson(`https://slack.com/api/${method}`, { method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/x-www-form-urlencoded" }, body: form(body ?? {}) });
  if (d.ok !== true) throw new Error(`Slack : ${str(d.error)}`);
  return d;
};

export const slack: Provider = {
  id: "slack", kind: "oauth2", env: "SLACK", pkce: false,
  authorizeUrl: "https://slack.com/oauth/v2/authorize",
  tokenUrl: "https://slack.com/api/oauth.v2.access",
  scopes: ["chat:write", "chat:write.public", "channels:read"], scopeSeparator: ",",
  tokenAuth: "body", maxText: 3000,
  revokeUrl: (t) => ({ url: "https://slack.com/api/auth.revoke", init: { method: "POST", headers: { Authorization: `Bearer ${t}` } } }),
  profile: async (t) => {
    const team = (t.raw.team ?? {}) as Record<string, unknown>;
    const ch = await call("conversations.list", t.access, { types: "public_channel", exclude_archived: "true", limit: "200" });
    const accounts = arr(ch.channels).map((c) => ({ externalId: str(c.id), kind: "channel", name: "#" + str(c.name), publish: false }));
    return { externalId: str(team.id), displayName: str(team.name) || "Espace Slack", accounts };
  },
  publish: async (c) => {
    if (!c.account) throw new Error("Choisissez un canal Slack.");
    const d = await call("chat.postMessage", c.token, { channel: c.account.externalId, text: c.text, unfurl_links: "true" });
    const ts = str(d.ts);
    return { externalId: ts, url: undefined };
  },
};
