// Edge Function « integrations-sync » : import des contenus autorisés (sans doublons, quotas respectés) + webhooks des fournisseurs qui en offrent.
//   POST {connection_id}                   -> synchronisation demandée par l'utilisateur
//   GET/POST …/webhook/<provider>          -> notifications signées (Dropbox, Meta) : relancent la synchronisation des comptes concernés
// Déployer avec --no-verify-jwt ; les appels utilisateur sont authentifiés ici, les webhooks par signature.
import { adminClient, callerOf, cors, hmacHex, jsonResponse, sameString } from "../_shared/core.ts";
import { syncConnection } from "../_shared/engine.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(req) });
  const url = new URL(req.url);
  const hook = url.pathname.match(/\/webhook\/([a-z_]+)$/)?.[1];

  if (hook) return webhook(req, url, hook);
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
  const uid = await callerOf(req);
  if (!uid) return jsonResponse(req, { error: "unauthorized", message: "Connexion requise." }, 401);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return jsonResponse(req, { error: "bad_request" }, 400); }
  const r = await syncConnection(adminClient(), String(b.connection_id ?? ""), uid, "manual");
  return jsonResponse(req, r);
});

async function webhook(req: Request, url: URL, provider: string): Promise<Response> {
  const admin = adminClient();
  if (provider === "dropbox") {
    const secret = Deno.env.get("DROPBOX_CLIENT_SECRET") ?? "";
    if (req.method === "GET") return new Response(url.searchParams.get("challenge") ?? "", { headers: { "Content-Type": "text/plain", "X-Content-Type-Options": "nosniff" } });
    const raw = await req.text();
    if (!secret || !sameString(await hmacHex(secret, raw), req.headers.get("X-Dropbox-Signature") ?? "")) return new Response("forbidden", { status: 403 });
    const accounts: string[] = (JSON.parse(raw)?.list_folder?.accounts ?? []) as string[];
    await fanOut(admin, "dropbox", accounts);
    return new Response("ok");
  }
  if (provider === "facebook" || provider === "instagram") {
    const verify = Deno.env.get("META_WEBHOOK_VERIFY_TOKEN") ?? "";
    if (req.method === "GET") {
      const ok = verify && sameString(url.searchParams.get("hub.verify_token") ?? "", verify);
      return ok ? new Response(url.searchParams.get("hub.challenge") ?? "", { headers: { "Content-Type": "text/plain" } }) : new Response("forbidden", { status: 403 });
    }
    const raw = await req.text();
    const secret = Deno.env.get(`${provider.toUpperCase()}_CLIENT_SECRET`) ?? "";
    const sig = (req.headers.get("X-Hub-Signature-256") ?? "").replace("sha256=", "");
    if (!secret || !sameString(await hmacHex(secret, raw), sig)) return new Response("forbidden", { status: 403 });
    const ids: string[] = ((JSON.parse(raw)?.entry ?? []) as { id: string }[]).map((e) => String(e.id));
    await fanOut(admin, provider, ids);
    return new Response("ok");
  }
  return new Response("not_found", { status: 404 });
}

/** Relance la synchronisation des connexions dont l'identifiant externe (ou l'un des comptes) est cité. Les quotas du moteur restent appliqués. */
async function fanOut(admin: ReturnType<typeof adminClient>, provider: string, externalIds: string[]): Promise<void> {
  if (!externalIds.length) return;
  const { data: direct } = await admin.from("integration_connections").select("id").eq("provider", provider).eq("status", "connected").in("external_id", externalIds);
  const { data: viaAccount } = await admin.from("integration_accounts").select("connection_id").eq("provider", provider).in("external_id", externalIds);
  const ids = new Set<string>([...(direct ?? []).map((c: { id: string }) => c.id), ...(viaAccount ?? []).map((a: { connection_id: string }) => a.connection_id)]);
  for (const id of [...ids].slice(0, 20)) await syncConnection(admin, id, null, "webhook");
}
