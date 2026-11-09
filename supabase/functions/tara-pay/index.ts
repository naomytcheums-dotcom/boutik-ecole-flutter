// Edge Function « tara-pay » : démarre un paiement Mobile Money via Tara Money (Dikalo).
// Distincte de Notch Pay (fonctions `pay` / `notchpay-*`). Aucune clé dans le code : variables d'environnement
// (Supabase > Edge Functions > Secrets) : TARA_API_KEY, TARA_BUSINESS_ID, TARA_WEBHOOK_SECRET. Optionnel : TARA_API_URL.
// Le paiement n'est JAMAIS confirmé ici : seul `tara-webhook` (secret vérifié) fait passer une transaction à « confirmed ».
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: u } = await asUser.auth.getUser();
  if (!u?.user) return json({ error: "unauthorized", message: "Connexion requise." }, 401);
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
