// Edge Function « push-config » : renvoie la CLÉ PUBLIQUE VAPID (secret VAPID_PUBLIC_KEY) pour l'abonnement aux notifications du navigateur.
// La clé publique n'est pas confidentielle ; la clé privée n'est jamais renvoyée. Sans clé : « not_configured ».
const ORIGINS = ["https://boutik-ecole.vercel.app", "http://localhost:8766", "http://localhost:8080"];
Deno.serve((req) => {
  const origin = req.headers.get("Origin") ?? "";
  const cors = { "Access-Control-Allow-Origin": ORIGINS.includes(origin) ? origin : ORIGINS[0], "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Vary": "Origin" };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const key = Deno.env.get("VAPID_PUBLIC_KEY") ?? Deno.env.get("Public Key");
  if (!key) return new Response(JSON.stringify({ error: "not_configured" }), { status: 503, headers: { ...cors, "Content-Type": "application/json" } });
  return new Response(JSON.stringify({ publicKey: key }), { headers: { ...cors, "Content-Type": "application/json" } });
});
