// Edge Function « tara-pay » : démarre un paiement Mobile Money via Tara Money (Dikalo).
// Distincte de Notch Pay (fonctions `pay` / `notchpay-*`). Aucune clé dans le code : variables d'environnement
// (Supabase > Edge Functions > Secrets) : TARA_API_KEY, TARA_BUSINESS_ID, TARA_WEBHOOK_SECRET. Optionnel : TARA_API_URL.
// Le paiement n'est JAMAIS confirmé ici : seul `tara-webhook` (secret vérifié) fait passer une transaction à « confirmed ».
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callerResult } from "../_shared/core.ts";

const TARA = Deno.env.get("TARA_API_URL") ?? "https://www.dklo.co/api/tara/mobilepay";
const ORIGINS = ["https://boutik-ecole.vercel.app", "http://localhost:8766", "http://localhost:8080"];
const NETWORKS = ["MTN", "ORANGE"];

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") ?? "";
  const cors = {
    "Access-Control-Allow-Origin": ORIGINS.includes(origin) ? origin : ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
  const json = (b: unknown, status = 200) =>
    new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const apiKey = Deno.env.get("TARA_API_KEY");
  const businessId = Deno.env.get("TARA_BUSINESS_ID");
  const secret = Deno.env.get("TARA_WEBHOOK_SECRET");
  if (!apiKey || !businessId || !secret) {
    return json({ error: "not_configured", message: "Le paiement Tara Money n'est pas encore configuré." }, 503);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const c = await callerResult(req);
  if (!c.ok) return json(c.body, c.status);
  const u = { user: { id: c.uid } };
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "bad_request" }, 400); }
  const reference = String(body.reference ?? "");
  const network = String(body.network ?? "").toUpperCase();
  const phone = String(body.phone ?? "").replace(/\D/g, "");
  if (!NETWORKS.includes(network)) return json({ error: "bad_network", message: "Réseau inconnu (MTN ou ORANGE)." }, 400);
  if (!/^2376\d{8}$/.test(phone)) return json({ error: "bad_phone", message: "Numéro attendu : 2376XXXXXXXX." }, 400);

  // Le montant vient TOUJOURS de la base, jamais du client.
  const { data: tx } = await admin.from("payment_transactions").select("*").eq("reference", reference).eq("payer_id", u.user.id).maybeSingle();
  if (!tx) return json({ error: "not_found", message: "Paiement introuvable." }, 404);
  // Seuls les paiements dont l'effet est géré à la confirmation (forfait d'organisation, récompense de défi, inscription à un événement payant) passent par Tara.
  // Une commande ou une contribution doit suivre son propre circuit : sinon la confirmation n'aurait aucun effet.
  const subject = String(tx.subject ?? "");
  const eventId = /^evt:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i.exec(subject)?.[1];
  // Forfait d'organisation : « cplan:<code>[:<propriétaire>] » (ancien sujet « plan:… » accepté tant qu'aucune offre premium n'est liée au paiement).
  const planMatch = tx.kind === "subscription" ? /^(c?plan):([a-z0-9_]{2,30})(?::([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}))?$/i.exec(subject) : null;
  const supported = !!planMatch || (tx.kind === "event" && (subject.startsWith("prize:") || !!eventId));
  if (!supported) return json({ error: "unsupported_kind", message: "Ce paiement ne peut pas être réglé par Tara Money." }, 400);
  if (planMatch) {
    // Le débit n'est lancé que pour un forfait d'organisation réel, demandé par le propriétaire, un administrateur ou la finance d'une fiche APPROUVÉE,
    // au prix de la base : sinon le paiement serait confirmé sans activer aucun forfait.
    const { data: plan } = await admin.from("company_plans").select("code, price_fcfa").eq("code", planMatch[2].toLowerCase()).maybeSingle();
    if (!plan) return json({ error: "unsupported_kind", message: "Ce forfait ne peut pas être réglé par Tara Money." }, 400);
    if (planMatch[1].toLowerCase() === "plan") {
      const { data: premium } = await admin.from("subscriptions").select("id").eq("payment_id", tx.id).maybeSingle();
      if (premium) return json({ error: "unsupported_kind", message: "Cette offre premium se règle par paiement manuel." }, 400);
    }
    const owner = (planMatch[3] ?? u.user.id).toLowerCase();
    const { data: fiche } = await admin.from("company_profiles").select("status").eq("owner_id", owner).maybeSingle();
    if (fiche?.status !== "approved") return json({ error: "company_not_approved", message: "Faites d'abord vérifier votre organisation : le forfait ne peut pas être payé avant la vérification." }, 403);
    let allowed = owner === u.user.id;
    if (!allowed) {
      const { data: member } = await admin.from("company_members").select("role").eq("owner_id", owner).eq("user_id", u.user.id).eq("status", "active").maybeSingle();
      allowed = !!member && ["admin", "finance"].includes(member.role);
    }
    if (!allowed) return json({ error: "forbidden", message: "Seuls le propriétaire, un administrateur ou la finance de l'organisation peuvent payer son forfait." }, 403);
    if (Number(tx.amount) < Number(plan.price_fcfa)) return json({ error: "amount_mismatch", message: "Le montant de cette transaction ne couvre pas le prix du forfait." }, 400);
  }
  if (eventId && tx.status !== "confirmed" && tx.status !== "pending") {
    // Le débit n'est lancé que pour une réservation de place encore active (30 minutes), liée à cette transaction.
    const { data: hold } = await admin.from("event_registrations").select("event_id").eq("event_id", eventId).eq("user_id", u.user.id)
      .eq("payment_id", tx.id).eq("status", "pending_payment").gt("hold_expires_at", new Date().toISOString()).maybeSingle();
    if (!hold) return json({ error: "hold_expired", message: "Votre réservation a expiré. Relancez l'inscription à l'événement." }, 409);
  }
  if (tx.status === "confirmed") return json({ status: "confirmed", reference });
  if (!["created", "failed"].includes(tx.status)) return json({ status: tx.status, reference, message: "Paiement déjà en cours." }); // pas de double débit

  // Passage atomique created/failed -> pending : une seule requête simultanée démarre le débit.
  const lock = await admin.from("payment_transactions").update({ status: "pending", provider: "tara", declared_at: new Date().toISOString() })
    .eq("id", tx.id).in("status", ["created", "failed"]).select("id");
  if (!lock.data?.length) return json({ status: "pending", reference, message: "Paiement déjà en cours." });

  const hook = `${url}/functions/v1/tara-webhook?s=${encodeURIComponent(secret)}`;
  let res: Response;
  try {
    res = await fetch(TARA, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ apiKey, businessId, productId: reference, productName: tx.subject || "Boutik-École", network, productPrice: tx.amount, phoneNumber: phone, webHookUrl: hook }),
    });
  } catch {
    await admin.from("payment_transactions").update({ status: "failed", note: "Fournisseur injoignable" }).eq("id", tx.id);
    return json({ status: "failed", reference, message: "Tara Money est injoignable, réessayez." }, 502);
  }
  const d = await res.json().catch(() => ({}));
  if (!res.ok) {
    await admin.from("payment_transactions").update({ status: "failed", note: "Refus du fournisseur" }).eq("id", tx.id);
    console.error("tara refus", res.status);
    return json({ status: "failed", reference, message: "Le fournisseur a refusé le paiement." }, 502);
  }
  const pref = String((d as Record<string, unknown>).transactionId ?? (d as Record<string, unknown>).id ?? "").slice(0, 80);
  if (pref) await admin.from("payment_transactions").update({ provider_ref: pref }).eq("id", tx.id);
  await admin.from("payment_messages").insert({ transaction_id: tx.id, sender: "system", body: "Validez le paiement sur votre téléphone (code secret Mobile Money)." });
  return json({ status: "pending", reference });
});
