// LinkedIn : connexion (OpenID) + publication « Share on LinkedIn » (w_member_social).
// Lecture des publications : Community Management API, sur approbation LinkedIn -> import non proposé.
import { get, Provider, str } from "./types.ts";

const VERSION = Deno.env.get("LINKEDIN_VERSION") ?? "202510";

/** Le champ « commentary » réserve ces caractères : échappés pour qu'un texte libre ne soit pas interprété comme du balisage. */
export const liEscape = (s: string) => s.replace(/([\\|{}@\[\]()<>#*_~])/g, "\\$1");

export const linkedin: Provider = {
  id: "linkedin", kind: "oauth2", env: "LINKEDIN", pkce: false,
  authorizeUrl: "https://www.linkedin.com/oauth/v2/authorization",
  tokenUrl: "https://www.linkedin.com/oauth/v2/accessToken",
  scopes: ["openid", "profile", "email", "w_member_social"],
  tokenAuth: "body", minIntervalSec: 3600, maxText: 3000,
  profile: async (t) => {
    const u = await get("https://api.linkedin.com/v2/userinfo", t.access);
    return { externalId: str(u.sub), displayName: str(u.name) || "Compte LinkedIn", accounts: [{ externalId: str(u.sub), kind: "member", name: str(u.name), publish: true }] };
  },
  publish: async (c) => {
    const res = await fetch("https://api.linkedin.com/rest/posts", {
      method: "POST",
      headers: { Authorization: `Bearer ${c.token}`, "Content-Type": "application/json", "LinkedIn-Version": VERSION, "X-Restli-Protocol-Version": "2.0.0" },
      body: JSON.stringify({
        author: `urn:li:person:${c.externalId}`, commentary: liEscape(c.text), visibility: "PUBLIC",
        distribution: { feedDistribution: "MAIN_FEED", targetEntities: [], thirdPartyDistributionChannels: [] },
        lifecycleState: "PUBLISHED", isReshareDisabledByAuthor: false,
      }),
    });
    await res.body?.cancel();
    if (res.status !== 201) throw new Error(`LinkedIn a refusé la publication (${res.status}).`);
    const urn = res.headers.get("x-restli-id") ?? "";
    return { externalId: urn, url: urn ? `https://www.linkedin.com/feed/update/${urn}` : undefined };
  },
};
