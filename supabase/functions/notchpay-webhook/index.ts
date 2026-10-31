// Edge Function « notchpay-webhook » : confirmation de paiement signée par Notch Pay.
// Secrets requis : NOTCHPAY_HASH (Hash Key du webhook, Notch Pay > Paramètres > Clés API) et NOTCHPAY_KEY (clé API).
// À déployer SANS vérification JWT (Notch Pay n'envoie pas de jeton Supabase) : l'authenticité vient de la signature HMAC.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTCH = Deno.env.get("NOTCHPAY_API") ?? "https://api.notchpay.co"; // surchargeable uniquement pour les tests locaux
const enc = new TextEncoder();

const toHex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");

// Comparaison en temps constant de deux chaînes hexadécimales.
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function hmacHex(secret: string, data: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return toHex(await crypto.subtle.sign("HMAC", k, enc.encode(data)));
}

async function sha256Hex(data: string): Promise<string> {
  return toHex(await crypto.subtle.digest("SHA-256", enc.encode(data)));
}

Deno.serve(async (req) => {
  const reply = (status: number, body: Record<string, unknown>) =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const hash = Deno.env.get("NOTCHPAY_HASH");
  const key = Deno.env.get("NOTCHPAY_KEY");
  if (!hash || !key) return reply(503, { error: "not_configured" });

  // 1. Signature : HMAC-SHA256 du corps brut, comparée en temps constant. Sans signature valide, rien n'est lu ni écrit.
  const raw = await req.text();
  // Le fournisseur peut préfixer la signature par « sha256= » : seul le préfixe est toléré, le HMAC reste obligatoire.
  const received = (req.headers.get("x-notch-signature") ?? "").trim().toLowerCase().replace(/^sha256=/, "");
  const expected = await hmacHex(hash, raw);
  if (!received || !safeEqual(received, expected)) {
    // Diagnostic sans aucune valeur sensible : noms d'en-têtes, longueurs et indicateurs booléens uniquement.
    let reserialized = false, withApiKey = false;
    try { reserialized = safeEqual(received, await hmacHex(hash, JSON.stringify(JSON.parse(raw)))); } catch { /* corps non JSON */ }
    try { withApiKey = safeEqual(received, await hmacHex(key, raw)); } catch { /* ignore */ }
    console.error("webhook refusé : signature invalide", JSON.stringify({
      headers: [...req.headers.keys()].filter((h) => !["authorization", "apikey", "cookie"].includes(h)),
      signature_header_present: received.length > 0,
      signature_length: received.length,
      signature_is_hex: /^[0-9a-f]+$/.test(received),
      expected_length: expected.length,
      body_length: raw.length,
      content_type: req.headers.get("content-type"),
      matches_if_body_reserialized: reserialized,
      matches_if_signed_with_api_key: withApiKey,
    }));
    return reply(401, { error: "invalid_signature" });
  }

  let evt: any;
  try { evt = JSON.parse(raw); } catch { return reply(400, { error: "bad_json" }); }
  const type = String(evt?.type ?? evt?.event ?? "");
  const obj = evt?.data?.transaction ?? evt?.data?.payment ?? evt?.data ?? {};
  const ref = String(obj?.reference ?? obj?.trxref ?? "");
  if (!type.startsWith("payment.") || !ref) return reply(200, { ignored: true });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // 2. Rejeu : le même contenu signé n'est traité qu'une fois (clé primaire sur l'empreinte du corps).
  const eventId = await sha256Hex(raw);
  const ins = await admin.from("payment_events").insert({ id: eventId, event_type: type, reference: ref });
  if (ins.error) {
    if (ins.error.code === "23505") return reply(200, { duplicate: true });
    console.error("journal des événements indisponible", ins.error.message);
    return reply(500, { error: "event_log_failed" });
  }

  // 3. Rapprochement : la référence doit appartenir à une commande connue.
  const { data: order } = await admin.from("orders").select("*").eq("reference", ref).maybeSingle();
  if (!order) {
    await admin.from("payment_events").update({ outcome: "unknown_reference" }).eq("id", eventId);
    return reply(200, { ignored: "unknown_reference" });
  }

  // 4. Seul un paiement terminé peut confirmer une commande, et seulement après relecture auprès du fournisseur.
  if (type !== "payment.complete") {
    await admin.from("payment_events").update({ outcome: type }).eq("id", eventId);
    return reply(200, { recorded: type });
  }
  if (order.paid) {
    await admin.from("payment_events").update({ outcome: "already_paid" }).eq("id", eventId);
    return reply(200, { already_paid: true });
  }
  // Commande annulée (stock restitué) : un paiement reçu ensuite n'est pas confirmé ; il est journalisé pour remboursement.
  if (order.cancelled === true || order.cancelled_at != null) {
    console.error("paiement reçu sur une commande annulée", { order: order.number });
    await admin.from("payment_events").update({ outcome: "paid_after_cancellation" }).eq("id", eventId);
    return reply(200, { confirmed: false, problems: ["order_cancelled"] });
  }

  const r = await fetch(`${NOTCH}/payments/${encodeURIComponent(ref)}`, { headers: { Authorization: key, Accept: "application/json" } });
  const d = await r.json().catch(() => ({}));
  const tx = d?.transaction ?? d?.payment ?? {};
  const due = order.subtotal + order.fee;
  const amount = Number(tx.amount);
  const problems: string[] = [];
  if (!r.ok) problems.push("provider_unreachable");
  if (String(tx.status ?? "") !== "complete") problems.push("not_complete");
  if (tx.reference && tx.reference !== ref) problems.push("reference_mismatch");
  if (String(tx.currency ?? "XAF") !== "XAF") problems.push("currency_mismatch");
  if (!Number.isFinite(amount) || amount < due) problems.push("underpaid");
  if (problems.includes("provider_unreachable")) {
    // Panne passagère : on libère l'événement et on répond 503 pour que Notch Pay réessaie.
    await admin.from("payment_events").delete().eq("id", eventId);
    return reply(503, { error: "provider_unreachable" });
  }
  if (problems.length) {
    console.error("paiement non confirmé", { order: order.number, due, amount, problems });
    await admin.from("payment_events").update({ outcome: problems.join(",") }).eq("id", eventId);
    return reply(200, { confirmed: false, problems });
  }

  // 5. Transition unique non payé -> payé (idempotente : la condition paid = false protège d'un double passage).
  const upd = await admin.from("orders").update({ paid: true, status: 1 }).eq("id", order.id).eq("paid", false).select("id");
  await admin.from("payment_events").update({ outcome: upd.data?.length ? "confirmed" : "already_paid" }).eq("id", eventId);
  return reply(200, { confirmed: true });
});
