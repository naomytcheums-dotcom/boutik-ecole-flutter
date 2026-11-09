// Connecteurs Microsoft (Graph) : OneDrive et Teams, deux connecteurs indépendants sur une même application Microsoft Entra.
import { arr, get, Provider, str } from "./types.ts";

const base = {
  kind: "oauth2" as const, env: "MICROSOFT", pkce: true,
  authorizeUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
  tokenUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
  tokenAuth: "body" as const,
  extraAuthParams: { response_mode: "query" },
};
const G = "https://graph.microsoft.com/v1.0";

const profile: Provider["profile"] = async (t) => {
  const me = await get(`${G}/me`, t.access);
  return { externalId: str(me.id), displayName: str(me.displayName || me.userPrincipalName) || "Compte Microsoft" };
};

export const onedrive: Provider = {
  ...base, id: "onedrive", scopes: ["offline_access", "User.Read", "Files.Read"], minIntervalSec: 900, profile,
  importItems: async (c) => {
    const d = await get(`${G}/me/drive/root/children?$top=50&$orderby=${encodeURIComponent("lastModifiedDateTime desc")}`, c.token);
    return { items: arr(d.value).map((f) => ({ externalId: str(f.id), kind: f.folder ? "folder" : "file", title: str(f.name), url: str(f.webUrl) || undefined, publishedAt: str(f.lastModifiedDateTime) || undefined })) };
  },
};

// Teams : l'envoi dans un canal (ChannelMessage.Send) exige le consentement d'un administrateur du locataire.
export const teams: Provider = {
  ...base, id: "teams", scopes: ["offline_access", "User.Read", "Team.ReadBasic.All", "Channel.ReadBasic.All", "ChannelMessage.Send"], maxText: 4000,
  profile: async (t) => {
    const p = await profile(t);
    const accounts = [];
    const teamsList = arr((await get(`${G}/me/joinedTeams`, t.access)).value).slice(0, 10);
    for (const tm of teamsList) {
      const ch = arr((await get(`${G}/teams/${str(tm.id)}/channels`, t.access)).value).slice(0, 20);
      for (const c of ch) accounts.push({ externalId: `${str(tm.id)}/${str(c.id)}`, kind: "channel", name: `${str(tm.displayName)} · ${str(c.displayName)}`, url: str(c.webUrl) || undefined, publish: false });
    }
    return { ...p, accounts };
  },
  publish: async (c) => {
    const [team, channel] = (c.account?.externalId ?? "").split("/");
    if (!team || !channel) throw new Error("Choisissez un canal Teams.");
    const res = await fetch(`${G}/teams/${team}/channels/${channel}/messages`, {
      method: "POST", headers: { Authorization: `Bearer ${c.token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ body: { contentType: "text", content: c.text } }),
    });
    const d = await res.json().catch(() => ({})) as Record<string, unknown>;
    if (!res.ok) throw new Error(`Teams a refusé le message (${res.status}) : consentement administrateur requis ?`);
    return { externalId: str(d.id), url: str(d.webUrl) || undefined };
  },
};
