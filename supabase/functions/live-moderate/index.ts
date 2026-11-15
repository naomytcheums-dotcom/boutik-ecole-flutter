// Edge Function « live-moderate » : modération réelle d'une salle LiveKit par l'hôte du live (ou l'administration / le support).
//   POST {live_id, user_id, action: "kick" | "ban" | "mute"}
//   kick : retire le participant de la salle (il peut revenir, sauf s'il est banni) ;
//   ban  : enregistre le bannissement (live_bans) puis le retire de la salle ;
//   mute : coupe ses pistes audio publiées.
// Sans secrets LIVEKIT_* : 503 « not_configured ». Participant absent de la salle (déjà parti) : 404 « not_in_room ».
import { adminClient, callerOf, cors, jsonResponse } from "../_shared/core.ts";
import { livekitAdminToken } from "../live-token/index.ts";

const ACTIONS = new Set(["kick", "ban", "mute"]);
const UUID = /^[0-9a-f-]{36}$/i;

class TwirpError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}

async function twirp(base: string, token: string, method: string, body: Record<string, unknown>): Promise<Record<string, unknown>> {
  let res: Response;
  try {
    res = await fetch(`${base}/twirp/livekit.RoomService/${method}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
    });
  } catch {
    throw new TwirpError(502, "unreachable", "Serveur vidéo injoignable");
  }
  const text = await res.text();
  let json: Record<string, unknown> = {};
  try { json = text ? JSON.parse(text) : {}; } catch { /* réponse non JSON */ }
  if (!res.ok) throw new TwirpError(res.status, String(json.code ?? "error"), String(json.msg ?? json.message ?? `HTTP ${res.status}`));
  return json;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
  const uid = await callerOf(req);
  if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }
  const liveId = String(body.live_id ?? ""), target = String(body.user_id ?? ""), action = String(body.action ?? "");
  if (!UUID.test(liveId) || !UUID.test(target) || !ACTIONS.has(action)) return jsonResponse(req, { error: "bad_request", message: "Demande invalide." }, 400);

  const url = Deno.env.get("LIVEKIT_URL"), key = Deno.env.get("LIVEKIT_API_KEY"), secret = Deno.env.get("LIVEKIT_API_SECRET");
  if (!url || !key || !secret) return jsonResponse(req, { error: "not_configured", message: "La diffusion en direct n'est pas encore activée sur ce serveur." }, 503);

  const admin = adminClient();
  const { data: live } = await admin.from("lives").select("id,host_id,room_name").eq("id", liveId).maybeSingle();
  if (!live) return jsonResponse(req, { error: "not_found", message: "Live introuvable." }, 404);
  const { data: me } = await admin.from("profiles").select("role,suspended").eq("id", uid).maybeSingle();
  if (!me || me.suspended) return jsonResponse(req, { error: "forbidden", message: "Action non autorisée." }, 403);
  const isStaff = me.role === "admin" || me.role === "support";
  if (live.host_id !== uid && !isStaff) return jsonResponse(req, { error: "forbidden", message: "Seul l'hôte du live peut modérer." }, 403);
  if (target === live.host_id || target === uid) return jsonResponse(req, { error: "bad_request", message: "L'hôte du live ne peut pas être modéré." }, 400);

  if (action === "ban") {
    const { error } = await admin.from("live_bans").upsert({ live_id: liveId, user_id: target, by_user: uid }, { onConflict: "live_id,user_id", ignoreDuplicates: true });
    if (error) return jsonResponse(req, { error: "db", message: "Le bannissement n'a pas pu être enregistré." }, 500);
    await admin.from("live_viewers").update({ left_at: new Date().toISOString() }).eq("live_id", liveId).eq("user_id", target).is("left_at", null);
  }

  const base = url.replace(/^wss:/i, "https:").replace(/^ws:/i, "http:").replace(/\/+$/, "");
  const adminToken = await livekitAdminToken(key, secret, live.room_name);
  try {
    if (action === "mute") {
      const info = await twirp(base, adminToken, "GetParticipant", { room: live.room_name, identity: target });
      const tracks = Array.isArray(info.tracks) ? info.tracks as Array<Record<string, unknown>> : [];
      const audio = tracks.filter((t) => t.type === "AUDIO" || t.type === 0);
      for (const t of audio) await twirp(base, adminToken, "MutePublishedTrack", { room: live.room_name, identity: target, track_sid: t.sid, muted: true });
      return jsonResponse(req, { ok: true, action, muted: audio.length });
    }
    await twirp(base, adminToken, "RemoveParticipant", { room: live.room_name, identity: target });
    return jsonResponse(req, { ok: true, action, removed: true });
  } catch (e) {
    const err = e as TwirpError;
    if (err.status === 404 || err.code === "not_found") {
      return jsonResponse(req, { error: "not_in_room", banned: action === "ban", message: "Ce participant a déjà quitté le direct." }, 404);
    }
    return jsonResponse(req, { error: "livekit", banned: action === "ban", message: "Le serveur vidéo n'a pas confirmé l'action. Réessayez." }, 502);
  }
});
