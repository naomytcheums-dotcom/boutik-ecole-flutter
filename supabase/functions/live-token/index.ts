// Edge Function « live-token » : émet le jeton d'accès à la salle LiveKit d'un live.
//   POST {live_id}  -> { url, token, role: "host" | "viewer", room }
// Sécurité : l'appelant doit être connecté (jeton Supabase). L'hôte reçoit le droit de publier (caméra, micro) ; les spectateurs
// ne peuvent que regarder, et seulement tant que le live est « en direct » et qu'ils n'en sont pas bannis. Les comptes suspendus sont refusés.
// Le jeton de l'hôte dure 2 h, celui des spectateurs et invités 1 h (un bannissement est de toute façon appliqué par « live-moderate »).
// Secrets à fournir (Supabase > Edge Functions > Secrets) : LIVEKIT_URL (wss://…), LIVEKIT_API_KEY, LIVEKIT_API_SECRET.
// Sans ces secrets : réponse 503 « not_configured » (aucun jeton inventé).
import { adminClient, callerOf, cors, jsonResponse } from "../_shared/core.ts";
import { liveTokenDecision, livekitAdminToken, livekitToken } from "./logic.ts";

// Réexporté : "live-moderate" et le test Deno importent ces fonctions depuis ce module.
export { livekitAdminToken, livekitToken };

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
    const isHost = live?.host_id === uid;
    const { data: prof } = await admin.from("profiles").select("name,suspended").eq("id", uid).maybeSingle();
    // Lectures nécessaires à la décision (ordre des contrôles : voir liveTokenDecision) ; une erreur de lecture de la règle d'accès refuse l'accès (jamais d'ouverture par défaut).
    let banned = false, access: { allowed?: boolean; reason?: string; message?: string } | null = null, accessError = false, coApproved = false;
    if (live && !isHost && live.status === "live") {
      const { data: ban } = await admin.from("live_bans").select("user_id").eq("live_id", liveId).eq("user_id", uid).maybeSingle();
      banned = !!ban;
      if (!banned && !prof?.suspended) {
        // Règle d'accès unique (migration 20261126041000) : live privé sans invitation, billet manquant, banni… ; l'hôte et l'administrateur gardent l'accès.
        const { data: acc, error: accErr } = await admin.rpc("live_access_for", { p_live: liveId, p_user: uid });
        access = acc ?? null;
        accessError = !!accErr;
        // Invité accepté par l'hôte (co-diffusion) : il peut publier sa caméra et son micro.
        const { data: co } = await admin.from("live_cohosts").select("status").eq("live_id", liveId).eq("user_id", uid).maybeSingle();
        coApproved = co?.status === "approved";
      }
    }
    const d = liveTokenDecision({ uid, live: live ?? null, banned, suspended: !!prof?.suspended, access, accessError, coApproved });
    if ("status" in d) return jsonResponse(req, d.body, d.status);
    const token = await livekitToken(key, secret, uid, String(prof?.name ?? "Membre"), live!.room_name, d.grant.canPublish, d.grant.ttlSec);
    return jsonResponse(req, { url, token, role: d.grant.role, room: live!.room_name });
  });
}
