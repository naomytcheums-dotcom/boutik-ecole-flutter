// Serveur MCP « Notch Pay / Boutik-École » (transport Streamable HTTP, JSON-RPC 2.0, sans état).
// LECTURE SEULE : aucun outil ne crée de paiement, de transfert ni de remboursement.
// Secrets : NOTCHPAY_KEY (clé API, déjà présente), MCP_ACCESS_KEY (clé d'accès aux outils, à définir par le propriétaire).
// initialize / tools/list sont publics (découverte du protocole) ; tools/call exige la clé d'accès, transmise en en-tête uniquement
// (x-mcp-access-key, ou Authorization: Bearer quand « Verify JWT » est désactivé), jamais dans l'URL (journalisée).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTCH = Deno.env.get("NOTCHPAY_API") ?? "https://api.notchpay.co";
const SUPPORTED = ["2025-06-18", "2025-03-26", "2024-11-05"];
const enc = new TextEncoder();

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, DELETE",
  "Access-Control-Allow-Headers": "content-type, authorization, mcp-session-id, mcp-protocol-version, accept, x-client-info, apikey",
  "Access-Control-Expose-Headers": "mcp-session-id",
};

function safeEqual(a: string, b: string): boolean {
  const x = enc.encode(a), y = enc.encode(b);
  if (x.length !== y.length) return false;
  let r = 0;
  for (let i = 0; i < x.length; i++) r |= x[i] ^ y[i];
  return r === 0;
}

// Les numéros de téléphone et adresses e-mail ne sortent jamais en clair.
function mask(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(mask);
  if (v && typeof v === "object") {
    const o: Record<string, unknown> = {};
    for (const [k, x] of Object.entries(v as Record<string, unknown>)) {
      if (/phone|msisdn/i.test(k) && typeof x === "string") o[k] = "***" + x.slice(-3);
      else if (/email/i.test(k) && typeof x === "string") o[k] = x.replace(/^(.).*(@.*)$/, "$1***$2");
      else o[k] = mask(x);
    }
    return o;
  }
  return v;
}

const TOOLS = [
  {
    name: "notchpay_list_payments",
    description: "Liste les derniers paiements Notch Pay du compte marchand (lecture seule, téléphones et e-mails masqués).",
    inputSchema: { type: "object", properties: { limit: { type: "integer", minimum: 1, maximum: 50, description: "Nombre de paiements (1 à 50, défaut 10)" } }, additionalProperties: false },
    annotations: { readOnlyHint: true, openWorldHint: true },
  },
  {
    name: "notchpay_get_payment",
    description: "Détail d'un paiement Notch Pay à partir de sa référence (ex. trx.xxxx), en lecture seule.",
    inputSchema: { type: "object", properties: { reference: { type: "string", description: "Référence Notch Pay du paiement" } }, required: ["reference"], additionalProperties: false },
    annotations: { readOnlyHint: true, openWorldHint: true },
  },
  {
    name: "boutik_recent_webhook_events",
    description: "Derniers événements de webhook Notch Pay reçus et acceptés par Boutik-École (type, référence, résultat du traitement). Les rejets de signature n'y figurent pas : ils sont dans les journaux de la fonction.",
    inputSchema: { type: "object", properties: { limit: { type: "integer", minimum: 1, maximum: 50 } }, additionalProperties: false },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  {
    name: "boutik_order_payment_status",
    description: "État de paiement d'une commande Boutik-École (numéro du type #BE-2026-0001) : payée ou non, montant dû, méthode, référence. Aucune donnée personnelle.",
    inputSchema: { type: "object", properties: { order_number: { type: "string", description: "Numéro de commande, ex. #BE-2026-0146" } }, required: ["order_number"], additionalProperties: false },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
];

const text = (o: unknown, isError = false) => ({ content: [{ type: "text", text: typeof o === "string" ? o : JSON.stringify(o, null, 2) }], isError });

async function notch(path: string) {
  const key = Deno.env.get("NOTCHPAY_KEY");
  if (!key) return text("Clé Notch Pay absente côté serveur.", true);
  try {
    const r = await fetch(`${NOTCH}${path}`, { headers: { Authorization: key, Accept: "application/json" } });
    const d = await r.json().catch(() => ({}));
    if (!r.ok) return text({ error: "provider_error", status: r.status, message: (d as any)?.message ?? "Réponse refusée par le fournisseur" }, true);
    return text(mask(d));
  } catch {
    return text("Fournisseur injoignable.", true);
  }
}

function db() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
}

async function callTool(name: string, a: Record<string, unknown>) {
  const lim = Math.min(50, Math.max(1, Number(a.limit ?? 10) || 10));
  switch (name) {
    case "notchpay_list_payments":
      return await notch(`/payments?limit=${lim}`);
    case "notchpay_get_payment": {
      const ref = String(a.reference ?? "");
      if (!/^[A-Za-z0-9._-]{3,80}$/.test(ref)) return text("Référence invalide.", true);
      return await notch(`/payments/${encodeURIComponent(ref)}`);
    }
    case "boutik_recent_webhook_events": {
      const { data, error } = await db().from("payment_events").select("event_type,reference,outcome,received_at").order("received_at", { ascending: false }).limit(lim);
      return error ? text("Lecture impossible.", true) : text(data);
    }
    case "boutik_order_payment_status": {
      const n = String(a.order_number ?? "");
      if (!/^#?BE-\d{4}-\d{3,6}$/.test(n)) return text("Numéro de commande invalide.", true);
      const { data, error } = await db().from("orders").select("number,paid,status,subtotal,fee,method,reference").eq("number", n.startsWith("#") ? n : "#" + n).maybeSingle();
      if (error) return text("Lecture impossible.", true);
      return data ? text({ ...data, montant_du: data.subtotal + data.fee }) : text("Commande introuvable.", true);
    }
  }
  return null;
}

const rpcError = (id: unknown, code: number, message: string) => ({ jsonrpc: "2.0", id: id ?? null, error: { code, message } });

async function handle(req: Request, msg: any): Promise<any | null> {
  if (!msg || msg.jsonrpc !== "2.0" || typeof msg.method !== "string") return rpcError(msg?.id, -32600, "Requête JSON-RPC invalide");
  const id = msg.id;
  const isNotification = id === undefined || id === null;
  switch (msg.method) {
    case "initialize": {
      const asked = String(msg.params?.protocolVersion ?? "");
      return { jsonrpc: "2.0", id, result: {
        protocolVersion: SUPPORTED.includes(asked) ? asked : SUPPORTED[0],
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "notchpay-boutik-mcp", title: "Notch Pay · Boutik-École (lecture seule)", version: "1.0.0" },
        instructions: "Outils en lecture seule pour suivre les paiements Notch Pay et l'état de paiement des commandes Boutik-École. Aucune opération financière n'est possible.",
      } };
    }
    case "ping":
      return { jsonrpc: "2.0", id, result: {} };
    case "tools/list":
      return { jsonrpc: "2.0", id, result: { tools: TOOLS } };
    case "resources/list":
      return { jsonrpc: "2.0", id, result: { resources: [] } };
    case "prompts/list":
      return { jsonrpc: "2.0", id, result: { prompts: [] } };
    case "tools/call": {
      const expected = Deno.env.get("MCP_ACCESS_KEY") ?? "";
      // La clé n'est acceptée qu'en en-tête (jamais dans l'URL, qui apparaît dans les journaux de la plateforme) :
      // « x-mcp-access-key: <clé> » (compatible avec « Verify JWT ») ou « Authorization: Bearer <clé> » (fonction sans Verify JWT).
      const given = (req.headers.get("x-mcp-access-key") ?? (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "")).trim();
      if (!expected) return { jsonrpc: "2.0", id, result: text("Les outils ne sont pas encore activés : le propriétaire doit définir le secret MCP_ACCESS_KEY.", true) };
      if (!given || !safeEqual(given, expected)) return { jsonrpc: "2.0", id, result: text("Accès refusé : clé d'accès manquante ou invalide.", true) };
      const r = await callTool(String(msg.params?.name ?? ""), (msg.params?.arguments ?? {}) as Record<string, unknown>);
      return r === null ? rpcError(id, -32602, "Outil inconnu") : { jsonrpc: "2.0", id, result: r };
    }
    default:
      if (msg.method.startsWith("notifications/") || isNotification) return null;
      return rpcError(id, -32601, "Méthode inconnue");
  }
}

Deno.serve(async (req) => {
  const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method === "GET" || req.method === "DELETE") return new Response(JSON.stringify({ error: "Ce serveur MCP est sans état : utilisez POST." }), { status: 405, headers: { ...CORS, Allow: "POST, OPTIONS", "Content-Type": "application/json" } });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: any;
  try { body = await req.json(); } catch { return json(rpcError(null, -32700, "JSON invalide"), 400); }

  if (Array.isArray(body)) {
    const out = (await Promise.all(body.map((m) => handle(req, m)))).filter((x) => x !== null);
    return out.length ? json(out) : new Response(null, { status: 202, headers: CORS });
  }
  const res = await handle(req, body);
  return res === null ? new Response(null, { status: 202, headers: CORS }) : json(res);
});
