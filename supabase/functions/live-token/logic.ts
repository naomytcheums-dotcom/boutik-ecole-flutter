// Logique pure de la fonction Edge « live-token » (jetons LiveKit et décision d'accès), testable avec Node sans serveur ni secret réel.
// Les lectures en base restent dans index.ts ; ici : qui reçoit quel jeton, avec quels droits et quelle durée.

const b64url = (data: Uint8Array | string) => {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

/** JWT HS256 au format attendu par LiveKit (iss = clé d'API, sub = identité, claim « video » = droits). */
export async function livekitToken(apiKey: string, apiSecret: string, identity: string, name: string, room: string, canPublish: boolean, ttlSec = 7200): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: apiKey, sub: identity, name, nbf: now - 5, iat: now, exp: now + ttlSec,
    video: { room, roomJoin: true, canPublish, canSubscribe: true, canPublishData: canPublish },
  }));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(apiSecret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${header}.${payload}`)));
  return `${header}.${payload}.${b64url(sig)}`;
}

/** JWT d'administration de salle (appels serveur à serveur vers l'API LiveKit : retirer un participant, couper une piste). Valable 60 s. */
export async function livekitAdminToken(apiKey: string, apiSecret: string, room: string, ttlSec = 60): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ iss: apiKey, sub: "boutik-moderation", nbf: now - 5, iat: now, exp: now + ttlSec, video: { roomAdmin: true, room } }));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(apiSecret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${header}.${payload}`)));
  return `${header}.${payload}.${b64url(sig)}`;
}

export type AccessFacts = {
  uid: string;
  live: { host_id: string; status: string; room_name: string } | null;
  banned: boolean;
  suspended: boolean;
  access: { allowed?: boolean; reason?: string; message?: string } | null;
  accessError: boolean;
  coApproved: boolean;
};
export type Refusal = { status: number; body: Record<string, unknown> };
export type Grant = { grant: { role: "host" | "cohost" | "viewer"; canPublish: boolean; ttlSec: number } };

/** Même ordre de contrôles qu'avant l'extraction : introuvable, non en direct, banni, terminé (hôte), suspendu, règle d'accès unique (refus si la lecture échoue), puis droits de publication. */
export function liveTokenDecision(f: AccessFacts): Refusal | Grant {
  const live = f.live;
  if (!live || live.status === "cancelled") return { status: 404, body: { error: "not_found", message: "Live introuvable." } };
  const isHost = live.host_id === f.uid;
  if (!isHost) {
    if (live.status !== "live") return { status: 409, body: { error: "not_live", message: "Ce live n'est pas en direct." } };
    if (f.banned) return { status: 403, body: { error: "banned", message: "Vous ne pouvez pas rejoindre ce live." } };
  } else if (live.status === "ended") {
    return { status: 409, body: { error: "ended", message: "Ce live est terminé." } };
  }
  if (f.suspended) return { status: 403, body: { error: "suspended", message: "Votre compte est suspendu : le direct est inaccessible." } };
  if (!isHost) {
    if (f.accessError || !f.access) return { status: 503, body: { error: "access_check_failed", message: "Impossible de vérifier votre accès à ce live pour le moment." } };
    if (f.access.allowed !== true) return { status: 403, body: { error: String(f.access.reason ?? "forbidden"), message: String(f.access.message || "Vous ne pouvez pas rejoindre ce live.") } };
  }
  const isCo = !isHost && f.coApproved;
  return { grant: { role: isHost ? "host" : isCo ? "cohost" : "viewer", canPublish: isHost || isCo, ttlSec: isHost ? 7200 : 3600 } };
}
