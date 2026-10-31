// Edge Function « pay » : paiement Mobile Money (Orange Money / MTN MoMo) via Notch Pay.
// Secret requis (Supabase > Edge Functions > Secrets) : NOTCHPAY_KEY (clé publique pk_test_… en sandbox, pk_live_… en production).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTCH = Deno.env.get("NOTCHPAY_API") ?? "https://api.notchpay.co"; // surchargeable uniquement pour les tests locaux
const ORIGINS = ["https://boutik-ecole.vercel.app", "http://localhost:8766", "http://localhost:8080"];

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
  const key = Deno.env.get("NOTCHPAY_KEY");
  if (!key) return json({ error: "not_configured", message: "Le paiement n'est pas encore configuré (clé Notch Pay manquante)." }, 503);

  const url = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: authHeader } } });
  const { data: u } = await asUser.auth.getUser();
  if (!u?.user) return json({ error: "unauthorized", message: "Connexion requise." }, 401);
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  let body: Record<string, any>;
  try { body = await req.json(); } catch { return json({ error: "bad_request" }, 400); }
  const number = String(body.order_number ?? "");
  const { data: order } = await admin.from("orders").select("*").eq("number", number).eq("buyer_id", u.user.id).maybeSingle();
  if (!order) return json({ error: "order_not_found", message: "Commande introuvable." }, 404);
  const expected = order.subtotal + order.fee;

  const headers = { Authorization: key, "Content-Type": "application/json", Accept: "application/json" };
  const cancelled = order.cancelled === true || order.cancelled_at != null;

  // Relecture d'un paiement chez le fournisseur ; un montant absent ou illisible n'est JAMAIS considéré comme suffisant.
  const readTx = async (ref: string) => {
    const r = await fetch(`${NOTCH}/payments/${encodeURIComponent(ref)}`, { headers });
    const d = await r.json().catch(() => ({}));
    return { ok: r.ok, tx: (d?.transaction ?? d?.payment ?? {}) as Record<string, unknown> };
  };
  const confirmIfComplete = async (ref: string, tx: Record<string, unknown>) => {
    const amount = Number(tx.amount);
    const badRef = tx.reference && tx.reference !== ref;
    const badCurrency = tx.currency && String(tx.currency) !== "XAF";
    const underpaid = !Number.isFinite(amount) || amount < expected;
    if (badRef || badCurrency || underpaid) {
      console.error("paiement incohérent", { order: number, expected, amount, badRef, badCurrency });
      return json({ status: "failed", reason: "mismatch", reference: ref });
    }
    // transition unique non payé -> payé, jamais sur une commande annulée
    await admin.from("orders").update({ paid: true, status: 1 }).eq("id", order.id).eq("paid", false).is("cancelled_at", null);
    return json({ status: "complete", reference: ref });
  };

  if (body.action === "start") {
    if (order.paid) return json({ error: "already_paid", message: "Cette commande est déjà payée." }, 409);
    if (cancelled) return json({ error: "order_cancelled", message: "Cette commande est annulée : elle ne peut plus être payée." }, 409);
    // Un paiement déjà demandé et encore en attente n'est pas doublé (deux prélèvements possibles, et l'événement du
    // premier ne retrouverait plus la commande) ; s'il a abouti, il est confirmé au lieu d'en créer un autre.
    if (order.reference) {
      const prev = await readTx(order.reference);
      const st = String(prev.tx.status ?? "");
      if (prev.ok && st === "complete") return await confirmIfComplete(order.reference, prev.tx);
      if (prev.ok && ["pending", "processing", "incomplete"].includes(st)) return json({ reference: order.reference, status: "pending", reused: true });
    }
    const phone = String(body.phone ?? "").replace(/\s+/g, "");
    if (!/^\+237[62]\d{8}$/.test(phone)) return json({ error: "invalid_phone", message: "Numéro invalide (format +237 6XX XX XX XX)." }, 400);
    const channel = body.channel === "cm.mtn" ? "cm.mtn" : "cm.orange";
    const reference = `${number.replace(/[^A-Za-z0-9-]/g, "")}-${Date.now()}`;
    const created = await fetch(`${NOTCH}/payments`, {
      method: "POST", headers,
      body: JSON.stringify({
        amount: expected, currency: "XAF", reference,
        description: `Commande ${number} · Boutik-École`,
        customer: { name: String(body.name ?? "Client"), email: String(body.email ?? u.user.email ?? ""), phone },
      }),
    });
    const c = await created.json();
    const ref = c?.transaction?.reference ?? c?.payment?.reference ?? reference;
    if (!created.ok) return json({ error: "provider_error", message: c?.message ?? "Création du paiement refusée." }, 502);
    const charge = await fetch(`${NOTCH}/payments/${ref}`, { method: "POST", headers, body: JSON.stringify({ channel, data: { phone } }) });
    const ch = await charge.json();
    if (!charge.ok) return json({ error: "provider_error", message: ch?.message ?? "Le prélèvement a été refusé." }, 502);
    await admin.from("orders").update({ reference: ref, method: channel === "cm.mtn" ? "MTN Mobile Money" : "Orange Money" }).eq("id", order.id);
    return json({ reference: ref, status: "pending" });
  }

  if (body.action === "status") {
    const ref = order.reference;
    if (!ref) return json({ status: "pending" });
    if (cancelled) return json({ status: "failed", reason: "cancelled", reference: ref });
    const { tx } = await readTx(ref);
    const st = String(tx.status ?? "pending");
    if (st === "complete") return await confirmIfComplete(ref, tx);
    if (["failed", "canceled", "expired", "rejected"].includes(st)) return json({ status: "failed", reference: ref });
    return json({ status: "pending", reference: ref });
  }
  return json({ error: "bad_action" }, 400);
});
