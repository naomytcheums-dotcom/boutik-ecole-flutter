// Edge Function « assessment-dispatch » : voir logic.ts pour le contrat. Déployée avec --no-verify-jwt : l'action « dispatch » exige la clé de service,
// le rappel des fournisseurs exige une signature HMAC. Sans configuration d'un fournisseur actif : « not_configured », rien de simulé.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { processCallback, processDispatch, safeEqual } from "./logic.ts";

Deno.serve(async (req) => {
  const json = (b: unknown, status: number) => new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = new URL(req.url);
  const supa = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supa, serviceKey);
  const env = (n: string) => Deno.env.get(n);

  const provider = url.searchParams.get("provider");
  if (provider) {
    const raw = await req.text();
    const out = await processCallback(provider, raw, req.headers.get("x-signature"), {
      env,
      providerActive: async (code) => {
        const { data } = await admin.from("assessment_providers").select("status").eq("code", code).maybeSingle();
        return data?.status === "actif";
      },
      result: async (a) => {
        const { data, error } = await admin.rpc("assessment_dispatch_result", { p_request: a.request, p_provider: a.provider, p_external_ref: a.externalRef, p_competences: a.competences, p_criteria: a.criteria, p_evidence: a.evidence, p_details: a.details, p_limits: a.limits, p_recommendations: a.recommendations });
        return { data, error: error?.message ?? null };
      },
      providerFailed: async (request, prov, detail) => {
        const { data, error } = await admin.rpc("assessment_dispatch_provider_failed", { p_request: request, p_provider: prov, p_detail: detail });
        return { data, error: error?.message ?? null };
      },
    });
    return json(out.body, out.status);
  }

  if (url.searchParams.get("action") !== "dispatch") return json({ error: "bad_request" }, 400);
  const bearer = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!bearer || !safeEqual(bearer, serviceKey)) return json({ error: "unauthorized" }, 401);
  const out = await processDispatch({
    env,
    fetchFn: fetch,
    callbackUrl: `${supa}/functions/v1/assessment-dispatch`,
    listActiveProviders: async () => {
      const { data } = await admin.from("assessment_providers").select("code").eq("status", "actif");
      return (data ?? []).map((r: { code: string }) => r.code);
    },
    claim: async (providers, limit) => {
      const { data, error } = await admin.rpc("assessment_dispatch_claim", { p_limit: limit, p_providers: providers });
      if (error) throw new Error(error.message);
      return (data ?? []) as never;
    },
    accepted: async (id, ref, candidateUrl) => { await admin.rpc("assessment_dispatch_accepted", { p_request: id, p_external_ref: ref, p_candidate_url: candidateUrl }); },
    failed: async (id, http, detail) => { await admin.rpc("assessment_dispatch_failed", { p_request: id, p_http: http, p_detail: detail }); },
  });
  return json(out.body, out.status);
});
