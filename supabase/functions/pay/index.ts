// Edge Function « pay » : paiement Mobile Money (Orange Money / MTN MoMo) via Notch Pay.
// Secret requis (Supabase > Edge Functions > Secrets) : NOTCHPAY_KEY (clé publique pk_test_… en sandbox, pk_live_… en production).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTCH = "https://api.notchpay.co";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
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

  const headers = { Authorization: key, "Content-Type": "application/json", Accept: "application/json" };

  if (body.action === "start") {
    const phone = String(body.phone ?? "").replace(/\s+/g, "");
    if (!/^\+237[62]\d{8}$/.test(phone)) return json({ error: "invalid_phone", message: "Numéro invalide (format +237 6XX XX XX XX)." }, 400);
    const channel = body.channel === "cm.mtn" ? "cm.mtn" : "cm.orange";
    const reference = `${number.replace(/[^A-Za-z0-9-]/g, "")}-${Date.now()}`;
    const created = await fetch(`${NOTCH}/payments`, {
      method: "POST", headers,
      body: JSON.stringify({
        amount: order.subtotal + order.fee, currency: "XAF", reference,
        description: `Commande ${number} · Boutik-École`,
        customer: { name: String(body.name ?? "Client"), email: String(body.email ?? u.user.email ?? ""), phone },
      }),
    });
    const c = await created.json();
    const ref = c?.transaction?.reference ?? c?.payment?.reference ?? reference;
    if (!created.ok) return json({ error: "provider_error", message: c?.message ?? "Création du paiement refusée.", detail: c }, 502);
    const charge = await fetch(`${NOTCH}/payments/${ref}`, { method: "POST", headers, body: JSON.stringify({ channel, data: { phone } }) });
    const ch = await charge.json();
    if (!charge.ok) return json({ error: "provider_error", message: ch?.message ?? "Le prélèvement a été refusé.", detail: ch }, 502);
    await admin.from("orders").update({ reference: ref, method: channel === "cm.mtn" ? "MTN Mobile Money" : "Orange Money" }).eq("id", order.id);
    return json({ reference: ref, status: "pending" });
  }

  if (body.action === "status") {
    const ref = order.reference;
    if (!ref) return json({ status: "pending" });
    const r = await fetch(`${NOTCH}/payments/${ref}`, { headers });
    const d = await r.json();
    const st = String(d?.transaction?.status ?? d?.payment?.status ?? "pending");
    if (st === "complete") {
      await admin.from("orders").update({ paid: true, status: 1 }).eq("id", order.id);
      return json({ status: "complete", reference: ref });
    }
    if (["failed", "canceled", "expired", "rejected"].includes(st)) return json({ status: "failed", reference: ref });
    return json({ status: "pending", reference: ref });
  }
  return json({ error: "bad_action" }, 400);
});
