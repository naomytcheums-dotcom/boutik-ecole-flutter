// Edge Function « live-token » : émet le jeton d'accès à la salle LiveKit d'un live.
//   POST {live_id}  -> { url, token, role: "host" | "viewer", room }
// Sécurité : l'appelant doit être connecté (jeton Supabase). L'hôte reçoit le droit de publier (caméra, micro) ; les spectateurs
// ne peuvent que regarder, et seulement tant que le live est « en direct » et qu'ils n'en sont pas bannis. Le jeton dure 2 h.
// Secrets à fournir (Supabase > Edge Functions > Secrets) : LIVEKIT_URL (wss://…), LIVEKIT_API_KEY, LIVEKIT_API_SECRET.
// Sans ces secrets : réponse 503 « not_configured » (aucun jeton inventé).
import { adminClient, callerOf, cors, jsonResponse } from "../_shared/core.ts";

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

if (import.meta.main) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
    if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
    const uid = await callerOf(req);
    if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }
    const liveId = String(body.live_id ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(liveId)) return jsonResponse(req, { error: "bad_request", message: "Live invalide." }, 400);

    const url = Deno.env.get("LIVEKIT_URL"), key = Deno.env.get("LIVEKIT_API_KEY"), secret = Deno.env.get("LIVEKIT_API_SECRET");
    if (!url || !key || !secret) return jsonResponse(req, { error: "not_configured", message: "La diffusion en direct n'est pas encore activée sur ce serveur." }, 503);

    const admin = adminClient();
    const { data: live } = await admin.from("lives").select("id,host_id,status,room_name").eq("id", liveId).maybeSingle();
    if (!live || live.status === "cancelled") return jsonResponse(req, { error: "not_found", message: "Live introuvable." }, 404);
    const isHost = live.host_id === uid;
    if (!isHost) {
      if (live.status !== "live") return jsonResponse(req, { error: "not_live", message: "Ce live n'est pas en direct." }, 409);
      const { data: ban } = await admin.from("live_bans").select("user_id").eq("live_id", liveId).eq("user_id", uid).maybeSingle();
      if (ban) return jsonResponse(req, { error: "banned", message: "Vous ne pouvez pas rejoindre ce live." }, 403);
    } else if (live.status === "ended") {
      return jsonResponse(req, { error: "ended", message: "Ce live est terminé." }, 409);
    }
    const { data: prof } = await admin.from("profiles").select("name").eq("id", uid).maybeSingle();
    const token = await livekitToken(key, secret, uid, String(prof?.name ?? "Membre"), live.room_name, isHost);
    return jsonResponse(req, { url, token, role: isHost ? "host" : "viewer", room: live.room_name });
  });
}
