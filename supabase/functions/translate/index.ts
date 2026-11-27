// Edge Function « translate » : traduit un message d'une conversation dont l'appelant est participant (CDC 11).
// Secrets de fonction : voir logic.ts (TRANSLATE_API_URL, TRANSLATE_API_KEY, TRANSLATE_PROVIDER_CODE, ...). Le fournisseur doit AUSSI être actif dans le registre ai_providers
// (activation administrateur + 2FA, après un test d'intégration réussi). Sans l'un ou l'autre : HTTP 503 + code « not_configured », jamais un texte simulé.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadConfig, processTranslate } from "./logic.ts";
import { callerResult } from "../_shared/core.ts";

const ORIGINS = ["https://boutik-ecole.vercel.app", "http://localhost:8766", "http://localhost:8080"];

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") ?? "";
  const cors = {
    "Access-Control-Allow-Origin": ORIGINS.includes(origin) ? origin : ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
  const json = (b: unknown, status: number) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const cfg = loadConfig((n) => Deno.env.get(n));
  let body: unknown = {};
  try { body = await req.json(); } catch { if (cfg) return json({ error: "bad_request", code: "bad_request" }, 400); }

  const url = Deno.env.get("SUPABASE_URL")!;
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  // Identité, session ouverte et compte non suspendu vérifiés (voir _shared/session.ts) ; sans fournisseur configuré, processTranslate répond « non configuré » avant toute lecture.
  const caller = cfg ? await callerResult(req) : null;
  if (caller && !caller.ok && caller.body.code !== "unauthorized") return json(caller.body, caller.status);
  const userId = caller?.ok ? caller.uid : null;
  const admin = cfg ? createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!) : null;

  const out = await processTranslate(body, {
    cfg,
    userId,
    fetchFn: fetch,
    requestTranslation: async (messageId, target) => {
      const { data, error } = await asUser.rpc("translate_request", { p_message: messageId, p_target: target });
      return { data, error };
    },
    storeTranslation: async (a) => {
      const { error } = await admin!.rpc("translate_store", { p_user: a.user, p_message: a.message, p_target: a.target, p_source: a.source, p_provider: a.provider, p_text: a.text });
      return { data: null, error };
    },
  });
  return json(out.body, out.status);
});
