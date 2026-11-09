// Edge Function « integrations-publish » : publication Boutik-École -> plateformes choisies, avec texte adapté à chacune.
//   POST {content, link_url?, media_url?, title?, idempotency_key, targets:[{connection_id, account_id?}], preview?:true}
// Anti-doublon : la même idempotency_key retrouve la publication existante et ne renvoie jamais une cible déjà envoyée.
// Chaque cible renvoie son état (sent / failed / unsupported) et le lien de la publication quand la plateforme le fournit.
import { adminClient, callerOf, cors, jsonResponse, ProviderError } from "../_shared/core.ts";
import { publishAll } from "../_shared/engine.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
  const uid = await callerOf(req);
  if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }
  try {
    const r = await publishAll(adminClient(), uid, {
      content: String(b.content ?? ""), link_url: b.link_url ? String(b.link_url) : undefined, media_url: b.media_url ? String(b.media_url) : undefined,
      title: b.title ? String(b.title) : undefined, idempotency_key: String(b.idempotency_key ?? ""), targets: Array.isArray(b.targets) ? b.targets as never : [],
    });
    return jsonResponse(req, r);
  } catch (e) {
    const status = e instanceof ProviderError ? e.status : 500;
    return jsonResponse(req, { error: "failed", message: e instanceof Error ? e.message : "Erreur." }, status);
  }
});
