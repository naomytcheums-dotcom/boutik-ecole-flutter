// Edge Function « integrations-oauth » : autorisation officielle des connecteurs (OAuth 2.0 + PKCE ; OAuth 1.0a pour Trello).
//   POST {action:"catalog"}                       -> quels fournisseurs sont configurés côté serveur (booléens, aucun secret)
//   POST {action:"start", provider, return_to?}   -> adresse d'autorisation du fournisseur (PKCE + état à usage unique)
//   GET  …/callback?code&state                    -> retour du fournisseur : échange du code, jetons CHIFFRÉS, redirection vers l'application
//   POST {action:"disconnect", connection_id, purge?} -> révocation chez le fournisseur (si l'API l'offre) + suppression des jetons
// Déployer avec --no-verify-jwt (le retour du fournisseur n'a pas de jeton Supabase) : les actions POST vérifient l'utilisateur elles-mêmes.
// URI de redirection à déclarer chez CHAQUE fournisseur : https://<projet>.supabase.co/functions/v1/integrations-oauth/callback
import { adminClient, callerOf, cors, encryptionConfigured, jsonResponse, ProviderError } from "../_shared/core.ts";
import { completeAuthorization, configured, disconnect, PROVIDERS, startAuthorization } from "../_shared/engine.ts";
import { mtnConfigured } from "../_shared/mtn.ts";

const smsConfigured = () => !!(Deno.env.get("TWILIO_ACCOUNT_SID") && Deno.env.get("TWILIO_AUTH_TOKEN") && Deno.env.get("TWILIO_SMS_FROM"));

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  const url = new URL(req.url);

  if (req.method === "GET" && url.pathname.endsWith("/callback")) {
    const to = await completeAuthorization(adminClient(), url.searchParams);
    return new Response(null, { status: 302, headers: { Location: to, "Cache-Control": "no-store" } });
  }
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);

  const uid = await callerOf(req);
  if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }

  try {
    switch (b.action) {
      case "catalog":
        return jsonResponse(req, {
          encryption: encryptionConfigured(),
          providers: Object.fromEntries(Object.values(PROVIDERS).map((p) => [p.id, configured(p)])),
          momo: { mtn: mtnConfigured(), orange: false, sms: smsConfigured() },
        });
      case "start": {
        const r = await startAuthorization(adminClient(), uid, String(b.provider ?? ""), typeof b.return_to === "string" ? b.return_to : undefined);
        return jsonResponse(req, r);
      }
      case "disconnect": {
        const r = await disconnect(adminClient(), uid, String(b.connection_id ?? ""), b.purge === true);
        return jsonResponse(req, { ok: true, revoked_at_provider: r.revokedAtProvider });
      }
      default:
        return jsonResponse(req, { error: "unknown_action" }, 400);
    }
  } catch (e) {
    const status = e instanceof ProviderError ? e.status : 500;
    console.error("integrations-oauth", b.action, status);
    return jsonResponse(req, { error: status === 503 ? "not_configured" : "failed", message: e instanceof Error ? e.message : "Erreur." }, status >= 400 && status < 600 ? status : 500);
  }
});
