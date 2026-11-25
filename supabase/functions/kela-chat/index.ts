// Edge Function « kela-chat » : l'assistante Kéla traite le texte (écrit ou dicté) et répond.
// Secret requis (Supabase > Edge Functions > Secrets) : ANTHROPIC_API_KEY. Sans elle, la fonction répond « non configuré » : aucune réponse n'est inventée.
// Modèle surchargeable par le secret KELA_MODEL. Limite : 30 messages par heure et par personne (table kela_usage).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ORIGINS = ["https://boutik-ecole.vercel.app", "http://localhost:8766", "http://localhost:8080"];
const SYSTEM = `Tu es Kéla, l'assistante de Boutik-École, la marketplace des étudiants de l'IUT de Douala (produits, services, talents, projets, missions).
Réponds toujours en français, en phrases courtes et claires. Tu aides à : décrire un besoin, trouver un type de talent, comprendre une commande, un paiement ou une mission.
Tu n'inventes jamais de prix, de délai, de personne ni de commande : si tu ne sais pas, dis-le et propose une étape de l'application.
Si la personne décrit un besoin à confier à des étudiants, ajoute à la fin de ta réponse, sur une ligne séparée, exactement : BRIEF={"title":"…","description":"…","budget":nombre ou null}
(titre de 60 caractères maximum, description reprenant ses mots, budget en FCFA seulement si elle l'a donné). N'ajoute cette ligne que s'il y a un vrai besoin.`;

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin") ?? "";
  const cors = {
    "Access-Control-Allow-Origin": ORIGINS.includes(origin) ? origin : ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
  const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) return json({ error: "not_configured", message: "L'assistante n'est pas encore configurée (clé de l'IA manquante)." }, 503);

  let body: Record<string, any>;
  try { body = await req.json(); } catch { return json({ error: "bad_request" }, 400); }
  // Sonde d'état (aucun quota, aucun appel au fournisseur) : l'application sait ainsi si Kéla est activée avant d'inviter à lui écrire.
  if (body.status === true) return json({ enabled: true });

  const url = Deno.env.get("SUPABASE_URL")!;
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: u } = await asUser.auth.getUser();
  if (!u?.user) return json({ error: "unauthorized", message: "Connexion requise." }, 401);
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const message = String(body.message ?? "").trim().slice(0, 2000);
  if (message.length < 2) return json({ error: "empty", message: "Message vide." }, 400);
  const history = Array.isArray(body.history) ? body.history.slice(-8) : [];

  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count } = await admin.from("kela_usage").select("id", { count: "exact", head: true }).eq("user_id", u.user.id).gte("created_at", since);
  if ((count ?? 0) >= 30) return json({ error: "rate_limited", message: "Vous avez atteint la limite de 30 messages par heure." }, 429);
  await admin.from("kela_usage").insert({ user_id: u.user.id });

  const messages = [
    ...history.filter((m: any) => (m?.role === "user" || m?.role === "assistant") && typeof m?.content === "string").map((m: any) => ({ role: m.role, content: String(m.content).slice(0, 2000) })),
    { role: "user", content: message },
  ];
  // Contexte autorisé : kela_context() ne renvoie que les chiffres et capacités du compte connecté (jamais de contenu privé). Échec = Kéla répond sans contexte.
  let ctx = "";
  try {
    const { data: c } = await asUser.rpc("kela_context");
    if (c && typeof c === "object") {
      ctx = `\n\nContexte du compte (lecture seule, ne le récite pas) : rôle ${c.role}, ${c.unread_notifications} notification(s) non lue(s), ${c.pending_agent_actions} action(s) en attente de confirmation. Tu ne peux exécuter aucune action : tu expliques et tu orientes vers l'écran concerné.`;
    }
  } catch { /* sans contexte */ }
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: Deno.env.get("KELA_MODEL") ?? "claude-haiku-5-5", max_tokens: 600, system: SYSTEM + ctx, messages }),
  });
  if (!r.ok) return json({ error: "provider_error", message: "L'assistante est momentanément indisponible." }, 502);
  const out = await r.json();
  let text = String(out?.content?.[0]?.text ?? "").trim();
  let brief: unknown = null;
  const m = text.match(/\nBRIEF=(\{.*\})\s*$/s);
  if (m) {
    try { brief = JSON.parse(m[1]); } catch { brief = null; }
    text = text.slice(0, m.index).trim();
  }
  return json({ reply: text, brief });
});
