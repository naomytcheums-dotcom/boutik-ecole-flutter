// Edge Function « live-record » : voir logic.ts pour le contrat. Appelée par l'application (jeton Supabase de l'hôte ou d'un co-hôte).
// Sans secrets LIVEKIT_* et S3 : 503 « not_configured », aucun enregistrement simulé.
import { adminClient, callerOf, cors, jsonResponse } from "../_shared/core.ts";
import { processRecord } from "./logic.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
  const uid = await callerOf(req);
  if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
  let body: unknown;
  try { body = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }
  const admin = adminClient();
  const out = await processRecord(body, {
    env: (n) => Deno.env.get(n),
    fetchFn: fetch,
    userId: uid,
    startCheck: async (live, user) => { const { data, error } = await admin.rpc("live_recording_start_check", { p_live: live, p_user: user }); return error ? null : data; },
    stopCheck: async (live, user) => { const { data, error } = await admin.rpc("live_recording_stop_check", { p_live: live, p_user: user }); return error ? null : data; },
    claim: async (rec) => { const { data } = await admin.rpc("live_recording_egress_claim", { p_recording: rec }); return data === true; },
    started: async (rec, egress) => { await admin.rpc("live_recording_egress_started", { p_recording: rec, p_egress: egress }); },
    stopping: async (rec) => { await admin.rpc("live_recording_egress_stopping", { p_recording: rec }); },
    failed: async (rec, detail) => { await admin.rpc("live_recording_egress_failed", { p_recording: rec, p_error: detail }); },
  });
  return jsonResponse(req, out.body, out.status);
});
