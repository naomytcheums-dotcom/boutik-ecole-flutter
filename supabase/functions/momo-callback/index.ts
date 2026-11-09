// Edge Function « momo-callback » : rappel serveur de MTN MoMo (résultat d'un transfert).
// Déployer avec --no-verify-jwt. Les rappels MTN ne sont pas signés : l'authenticité repose sur (1) le secret MTN_MOMO_CALLBACK_SECRET dans l'URL
// transmise à MTN, comparé en temps constant, et (2) une RELECTURE de l'état chez MTN avec l'identifiant de la demande : le corps du rappel
// n'est jamais cru tel quel. Idempotent : seule une transaction « pending » peut changer d'état.
import { adminClient, sameString } from "../_shared/core.ts";
import { mtnConfigured, mtnStatus } from "../_shared/mtn.ts";

Deno.serve(async (req) => {
  const secret = Deno.env.get("MTN_MOMO_CALLBACK_SECRET");
  if (!secret || !mtnConfigured()) return new Response("not_configured", { status: 503 });
  if (!sameString(new URL(req.url).searchParams.get("s") ?? "", secret)) return new Response("forbidden", { status: 403 });
  if (req.method !== "POST" && req.method !== "PUT") return new Response("ok");

  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return new Response("bad_request", { status: 400 }); }
  const reference = String(b.externalId ?? "");
  if (!reference) return new Response("ignored");

  const admin = adminClient();
  const { data: tx } = await admin.from("momo_transactions").select("*").eq("reference", reference).eq("operator", "MTN").maybeSingle();
  if (!tx || !tx.provider_ref) return new Response("unknown_reference");
  if (tx.status !== "pending") return new Response("already_done"); // idempotence : un rappel rejoué ne change rien

  let s;
  try { s = await mtnStatus(tx.provider_ref); } catch { return new Response("verify_failed", { status: 502 }); } // MTN réessaiera
  if (s.status === "PENDING") return new Response("still_pending");
  await admin.from("momo_transactions").update({
    status: s.status === "SUCCESSFUL" ? "confirmed" : "failed",
    failure_reason: s.status === "FAILED" ? (s.reason ?? "Échec chez l'opérateur") : null,
    decided_at: new Date().toISOString(),
  }).eq("id", tx.id).eq("status", "pending");
  return new Response(s.status === "SUCCESSFUL" ? "confirmed" : "failed");
});
