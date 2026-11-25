// Edge Function « live-egress-webhook » : voir logic.ts pour le contrat. Déployée avec --no-verify-jwt (la preuve d'origine est la signature LiveKit).
// À déclarer dans LiveKit (webhook) : https://<projet>.supabase.co/functions/v1/live-egress-webhook.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { processEgressWebhook } from "./logic.ts";

Deno.serve(async (req) => {
  const json = (b: unknown, status: number) => new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const raw = await req.text();
  const out = await processEgressWebhook(raw, req.headers.get("Authorization"), {
    env: (n) => Deno.env.get(n),
    event: async (egressId, status, path, durationSec, error) => {
      const { data, error: e } = await admin.rpc("live_recording_egress_event", { p_egress: egressId, p_status: status, p_path: path, p_duration: durationSec, p_error: error });
      return { data, error: e?.message ?? null };
    },
  });
  return json(out.body, out.status);
});
