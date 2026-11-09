// MTN MoMo — API Disbursement (envoi d'argent), documentation officielle : https://momodeveloper.mtn.com/
// Secrets (Supabase > Edge Functions > Secrets), tous fournis par MTN après signature du contrat marchand :
//   MTN_MOMO_SUBSCRIPTION_KEY  (clé « Ocp-Apim-Subscription-Key » du produit Disbursements)
//   MTN_MOMO_API_USER, MTN_MOMO_API_KEY  (utilisateur d'API et sa clé)
//   MTN_MOMO_TARGET_ENV  (sandbox ou mtncameroon), MTN_MOMO_CURRENCY (XAF en production ; EUR en sandbox), MTN_MOMO_CALLBACK_SECRET
//   optionnel : MTN_MOMO_BASE_URL (défaut : https://sandbox.momodeveloper.mtn.com)
// Le PIN du titulaire n'est jamais demandé : MTN envoie la demande de validation sur le téléphone du bénéficiaire/titulaire.
import { fetchJson, ProviderError } from "./core.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
export const mtnConfigured = () => ["MTN_MOMO_SUBSCRIPTION_KEY", "MTN_MOMO_API_USER", "MTN_MOMO_API_KEY", "MTN_MOMO_TARGET_ENV", "MTN_MOMO_CALLBACK_SECRET"].every((k) => env(k).length > 0);
const base = () => env("MTN_MOMO_BASE_URL") || "https://sandbox.momodeveloper.mtn.com";

async function token(): Promise<string> {
  const d = await fetchJson(`${base()}/disbursement/token/`, {
    method: "POST",
    headers: { Authorization: "Basic " + btoa(`${env("MTN_MOMO_API_USER")}:${env("MTN_MOMO_API_KEY")}`), "Ocp-Apim-Subscription-Key": env("MTN_MOMO_SUBSCRIPTION_KEY") },
  });
  return String(d.access_token ?? "");
}

const common = (t: string) => ({ Authorization: `Bearer ${t}`, "X-Target-Environment": env("MTN_MOMO_TARGET_ENV"), "Ocp-Apim-Subscription-Key": env("MTN_MOMO_SUBSCRIPTION_KEY") });

/** Lance le transfert (réponse 202 attendue). `referenceId` (UUID) identifie la demande chez MTN : le même UUID ne peut jamais débiter deux fois. */
export async function mtnTransfer(p: { referenceId: string; externalId: string; amount: number; phone: string; message: string; callbackUrl: string }): Promise<void> {
  const t = await token();
  const res = await fetch(`${base()}/disbursement/v1_0/transfer`, {
    method: "POST",
    headers: { ...common(t), "X-Reference-Id": p.referenceId, "X-Callback-Url": p.callbackUrl, "Content-Type": "application/json" },
    body: JSON.stringify({ amount: String(p.amount), currency: env("MTN_MOMO_CURRENCY") || "XAF", externalId: p.externalId, payee: { partyIdType: "MSISDN", partyId: p.phone }, payerMessage: p.message.slice(0, 160), payeeNote: p.message.slice(0, 160) }),
  });
  await res.body?.cancel();
  if (res.status !== 202) throw new ProviderError(res.status, `MTN a refusé le transfert (${res.status}).`);
}

/** État du transfert chez MTN : SUCCESSFUL, FAILED ou PENDING. */
export async function mtnStatus(referenceId: string): Promise<{ status: "SUCCESSFUL" | "FAILED" | "PENDING"; reason?: string; financialTransactionId?: string }> {
  const t = await token();
  const d = await fetchJson(`${base()}/disbursement/v1_0/transfer/${referenceId}`, { headers: common(t) });
  const s = String(d.status ?? "PENDING").toUpperCase();
  return { status: s === "SUCCESSFUL" ? "SUCCESSFUL" : s === "FAILED" ? "FAILED" : "PENDING", reason: d.reason ? String((d.reason as Record<string, unknown>).message ?? d.reason).slice(0, 120) : undefined, financialTransactionId: d.financialTransactionId ? String(d.financialTransactionId) : undefined };
}
