// Discord : OAuth 2.0 + PKCE. La publication passe par le webhook de salon que l'utilisateur autorise (portée officielle webhook.incoming) ;
// l'URL du webhook est un secret : chiffrée, jamais renvoyée au client.
import { fetchJson } from "../core.ts";
import { get, Provider, str } from "./types.ts";

export const discord: Provider = {
  id: "discord", kind: "oauth2", env: "DISCORD", pkce: true,
  authorizeUrl: "https://discord.com/oauth2/authorize",
  tokenUrl: "https://discord.com/api/oauth2/token",
  scopes: ["identify", "webhook.incoming"],
  tokenAuth: "body", maxText: 2000,
  revokeUrl: (t, c) => ({ url: "https://discord.com/api/oauth2/token/revoke", init: { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ client_id: c.id, client_secret: c.secret, token: t }).toString() } }),
  profile: async (t) => {
    const u = await get("https://discord.com/api/users/@me", t.access);
    const wh = (t.raw.webhook ?? null) as Record<string, unknown> | null;
    const accounts = [];
    const extra: Record<string, unknown> = {};
    if (wh && wh.id) {
      accounts.push({ externalId: str(wh.id), kind: "webhook", name: `${str(wh.name) || "Webhook"} (salon)`, publish: true });
      extra.webhooks = { [str(wh.id)]: { url: str(wh.url), guild: str(wh.guild_id), channel: str(wh.channel_id) } };
    }
    return { externalId: str(u.id), displayName: str(u.global_name || u.username) || "Compte Discord", accounts, extra };
  },
  publish: async (c) => {
    const hook = ((c.extra.webhooks ?? {}) as Record<string, { url: string; guild: string; channel: string }>)[c.account?.externalId ?? ""];
    if (!hook?.url) throw new Error("Aucun salon autorisé : reconnectez Discord et choisissez un salon.");
    // allowed_mentions vide : un texte publié ne peut pas déclencher @everyone ni mentionner des membres.
    const d = await fetchJson(`${hook.url}?wait=true`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ content: c.text, allowed_mentions: { parse: [] } }) });
    return { externalId: str(d.id), url: `https://discord.com/channels/${hook.guild}/${hook.channel}/${str(d.id)}` };
  },
};
