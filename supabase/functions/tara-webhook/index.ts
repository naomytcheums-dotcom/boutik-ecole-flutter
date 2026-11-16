// Edge Function « tara-webhook » : réception des notifications de paiement Tara Money (Dikalo).
// Déployer avec --no-verify-jwt ; l'authenticité repose sur le secret TARA_WEBHOOK_SECRET (paramètre `s` de l'URL transmise
// à Tara par `tara-pay`, comparé en temps constant). Idempotent : une transaction déjà confirmée n'est jamais retraitée.
// Une confirmation exige : secret valide, référence connue, statut de succès explicite, montant (s'il est fourni) >= montant attendu.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function same(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("TARA_WEBHOOK_SECRET");
  if (!secret) return new Response("not_configured", { status: 503 });
  const given = new URL(req.url).searchParams.get("s") ?? req.headers.get("x-webhook-secret") ?? "";
  if (!same(given, secret)) return new Response("forbidden", { status: 403 });
  if (req.method !== "POST") return new Response("ok");

  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return new Response("bad_request", { status: 400 }); }
  const reference = String(b.productId ?? b.product_id ?? b.reference ?? "");
  const raw = String(b.status ?? b.state ?? "").toLowerCase();
  const success = ["success", "successful", "completed", "complete", "paid", "confirmed"].includes(raw);
  const failure = ["failed", "failure", "cancelled", "canceled", "rejected", "expired"].includes(raw);
  if (!reference || (!success && !failure)) return new Response("ignored");

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: tx } = await admin.from("payment_transactions").select("*").eq("reference", reference).eq("provider", "tara").maybeSingle();
  if (!tx) return new Response("unknown_reference");
  if (tx.status === "confirmed") return new Response("already_done"); // idempotence : pas de double traitement

  if (success) {
    const paid = b.amount ?? b.productPrice ?? b.price;
    const providerId = String(b.transactionId ?? b.transaction_id ?? b.id ?? "");
    if (paid !== undefined && !(Number(paid) >= tx.amount)) {
      await admin.from("payment_transactions").update({ status: "failed", note: "Montant reçu insuffisant" }).eq("id", tx.id).neq("status", "confirmed");
      await admin.from("payment_messages").insert({ transaction_id: tx.id, sender: "system", body: "Montant reçu inférieur au montant attendu : paiement non validé." });
      return new Response("mismatch");
    }
    // Sans montant dans la notification, seule la référence de transaction enregistrée au lancement du paiement prouve qu'il s'agit du bon débit ;
    // à défaut, rien n'est confirmé automatiquement : la finance vérifie.
    if (paid === undefined && !(tx.provider_ref && providerId && providerId === tx.provider_ref)) {
      await admin.from("payment_messages").insert({ transaction_id: tx.id, sender: "system", body: "Paiement signalé par le fournisseur sans montant vérifiable : la finance le contrôle avant validation." });
      const { data: staff } = await admin.from("profiles").select("id").in("role", ["finance", "admin"]).eq("suspended", false);
      for (const s of staff ?? []) {
        await admin.rpc("notify_user", { p_user: s.id, p_kind: "payment_review", p_title: "Paiement Tara à vérifier", p_body: `Référence ${reference} : confirmation reçue sans montant vérifiable.`, p_data: { transaction: tx.id } });
      }
      return new Response("needs_review");
    }
    const up = await admin.from("payment_transactions").update({ status: "confirmed", decided_at: new Date().toISOString(), note: "Confirmé par Tara Money" })
      .eq("id", tx.id).in("status", ["pending", "failed"]).select("id");
    if (up.data?.length) await admin.from("payment_messages").insert({ transaction_id: tx.id, sender: "system", body: "Paiement confirmé. Merci !" });
    return new Response("confirmed");
  }
  await admin.from("payment_transactions").update({ status: "failed", decided_at: new Date().toISOString(), note: "Refusé ou expiré chez Tara Money" })
    .eq("id", tx.id).in("status", ["pending", "created"]);
  await admin.from("payment_messages").insert({ transaction_id: tx.id, sender: "system", body: "Paiement non abouti. Vous pouvez réessayer." });
  return new Response("failed");
});
