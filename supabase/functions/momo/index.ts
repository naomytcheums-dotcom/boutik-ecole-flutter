// Edge Function « momo » : numéros Mobile Money (vérification par SMS) et envois avec CONFIRMATION EXPLICITE.
//   POST {action:"status"}
//   POST {action:"request_verification", number_id}     -> envoie un code à 6 chiffres par SMS (empreinte SHA-256 stockée, 10 min, 3 demandes/heure)
//   POST {action:"confirm_transfer", reference, confirm:true}  -> engage l'envoi préparé par momo_prepare_transfer (jamais sans confirm === true)
//   POST {action:"refresh_status", reference}           -> relit l'état chez l'opérateur (utile si le rappel serveur tarde)
// Aucun PIN n'est reçu ni stocké : l'opérateur demande la validation sur le téléphone. Le montant et le destinataire viennent de la base, jamais du client.
// Anti-doublon : passage atomique awaiting_confirmation -> pending ; l'identifiant X-Reference-Id est fixé avant l'appel et ne change plus.
import { adminClient, callerOf, cors, functionUrl, jsonResponse, ProviderError } from "../_shared/core.ts";
import { mtnConfigured, mtnStatus, mtnTransfer } from "../_shared/mtn.ts";

const smsConfigured = () => !!(Deno.env.get("TWILIO_ACCOUNT_SID") && Deno.env.get("TWILIO_AUTH_TOKEN") && Deno.env.get("TWILIO_SMS_FROM"));

async function sha256Hex(s: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(d)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function sendSms(phone: string, body: string): Promise<void> {
  const sid = Deno.env.get("TWILIO_ACCOUNT_SID")!;
  const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: "POST",
    headers: { Authorization: "Basic " + btoa(`${sid}:${Deno.env.get("TWILIO_AUTH_TOKEN")}`), "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ To: "+" + phone, From: Deno.env.get("TWILIO_SMS_FROM")!, Body: body }).toString(),
  });
  await res.body?.cancel();
  if (!res.ok) throw new ProviderError(502, "Le SMS n'a pas pu être envoyé.");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
  const uid = await callerOf(req);
  if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }
  const admin = adminClient();

  try {
    if (b.action === "status") return jsonResponse(req, { mtn: mtnConfigured(), orange: false, sms: smsConfigured() });

    if (b.action === "request_verification") {
      if (!smsConfigured()) return jsonResponse(req, { error: "not_configured", message: "L'envoi de SMS n'est pas encore configuré : vérification indisponible." }, 503);
      const { data: n } = await admin.from("momo_numbers").select("id,phone").eq("id", String(b.number_id ?? "")).eq("user_id", uid).maybeSingle();
      if (!n) return jsonResponse(req, { error: "not_found", message: "Numéro introuvable." }, 404);
      const since = new Date(Date.now() - 3600_000).toISOString();
      const { count } = await admin.from("momo_verifications").select("id", { count: "exact", head: true }).eq("user_id", uid).eq("number_id", n.id).gte("created_at", since);
      if ((count ?? 0) >= 3) return jsonResponse(req, { error: "rate_limited", message: "Trois codes par heure au maximum : réessayez plus tard." }, 429);
      const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, "0");
      const ins = await admin.from("momo_verifications").insert({ number_id: n.id, user_id: uid, code_hash: await sha256Hex(code) }).select("id").single();
      if (ins.error) return jsonResponse(req, { error: "failed", message: "Code non créé." }, 500);
      try {
        await sendSms(n.phone, `Boutik-École : votre code de vérification est ${code}. Valable 10 minutes. Ne le communiquez à personne.`);
      } catch (e) {
        await admin.from("momo_verifications").delete().eq("id", ins.data.id);
        return jsonResponse(req, { error: "sms_failed", message: e instanceof Error ? e.message : "SMS non envoyé." }, 502);
      }
      await admin.from("momo_numbers").update({ verification_status: "pending" }).eq("id", n.id).neq("verification_status", "verified");
      return jsonResponse(req, { ok: true });
    }

    if (b.action === "confirm_transfer") {
      if (b.confirm !== true) return jsonResponse(req, { error: "confirmation_required", message: "Confirmation explicite requise." }, 400);
      const { data: tx } = await admin.from("momo_transactions").select("*").eq("reference", String(b.reference ?? "")).eq("user_id", uid).maybeSingle();
      if (!tx) return jsonResponse(req, { error: "not_found", message: "Transaction introuvable." }, 404);
      if (tx.status !== "awaiting_confirmation") return jsonResponse(req, { status: tx.status, reference: tx.reference, message: "Cette transaction a déjà été traitée." });
      if (tx.operator === "ORANGE") {
        return jsonResponse(req, { error: "not_available", message: "Orange Money : l'envoi automatisé exige un contrat marchand Orange et ses identifiants d'API. Aucun débit n'a été fait." }, 501);
      }
      if (!mtnConfigured()) return jsonResponse(req, { error: "not_configured", message: "MTN MoMo n'est pas encore activé (contrat marchand et clés en attente). Aucun débit n'a été fait." }, 503);
      const { data: num } = await admin.from("momo_numbers").select("verification_status").eq("id", tx.number_id).maybeSingle();
      if (num?.verification_status !== "verified") return jsonResponse(req, { error: "unverified", message: "Le numéro émetteur n'est plus vérifié." }, 409);

      const providerRef = crypto.randomUUID();
      const lock = await admin.from("momo_transactions").update({ status: "pending", confirmed_by_user_at: new Date().toISOString(), provider_ref: providerRef })
        .eq("id", tx.id).eq("status", "awaiting_confirmation").select("id");
      if (!lock.data?.length) return jsonResponse(req, { status: "pending", reference: tx.reference, message: "Envoi déjà engagé." }); // double appui : un seul débit
      const secret = Deno.env.get("MTN_MOMO_CALLBACK_SECRET")!;
      try {
        await mtnTransfer({ referenceId: providerRef, externalId: tx.reference, amount: tx.amount, phone: tx.counterparty_phone, message: tx.note || "Boutik-École", callbackUrl: `${functionUrl("momo-callback")}?s=${encodeURIComponent(secret)}` });
      } catch (e) {
        await admin.from("momo_transactions").update({ status: "failed", failure_reason: "Refus de l'opérateur", decided_at: new Date().toISOString() }).eq("id", tx.id).eq("status", "pending");
        console.error("momo transfer refus", e instanceof ProviderError ? e.status : 0);
        return jsonResponse(req, { status: "failed", reference: tx.reference, message: "L'opérateur a refusé l'envoi. Aucun débit n'a eu lieu." }, 502);
      }
      return jsonResponse(req, { status: "pending", reference: tx.reference, message: "Envoi demandé : validez-le sur votre téléphone si l'opérateur vous le demande." });
    }

    if (b.action === "refresh_status") {
      const { data: tx } = await admin.from("momo_transactions").select("*").eq("reference", String(b.reference ?? "")).eq("user_id", uid).maybeSingle();
      if (!tx) return jsonResponse(req, { error: "not_found", message: "Transaction introuvable." }, 404);
      if (tx.status !== "pending" || !tx.provider_ref || tx.operator !== "MTN" || !mtnConfigured()) return jsonResponse(req, { status: tx.status, reference: tx.reference });
      const s = await mtnStatus(tx.provider_ref);
      if (s.status !== "PENDING") {
        await admin.from("momo_transactions").update({ status: s.status === "SUCCESSFUL" ? "confirmed" : "failed", failure_reason: s.status === "FAILED" ? (s.reason ?? "Échec chez l'opérateur") : null, decided_at: new Date().toISOString() })
          .eq("id", tx.id).eq("status", "pending");
      }
      return jsonResponse(req, { status: s.status === "SUCCESSFUL" ? "confirmed" : s.status === "FAILED" ? "failed" : "pending", reference: tx.reference });
    }
    return jsonResponse(req, { error: "unknown_action" }, 400);
  } catch (e) {
    console.error("momo", b.action);
    return jsonResponse(req, { error: "failed", message: e instanceof Error ? e.message : "Erreur." }, e instanceof ProviderError ? e.status : 500);
  }
});
