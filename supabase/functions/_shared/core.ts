// Noyau commun des Edge Functions d'intégrations : CORS, authentification, chiffrement des jetons, PKCE, signatures.
// Les jetons ne sont JAMAIS renvoyés au client ni écrits dans les journaux : chiffrés en AES-256-GCM avec INTEGRATIONS_ENC_KEY.
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const ORIGINS = ["https://boutik-ecole.vercel.app", "http://localhost:8766", "http://localhost:8080"];
export const APP_ORIGIN = ORIGINS[0];

export function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ORIGINS.includes(origin) ? origin : ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

export function jsonResponse(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors(req), "Content-Type": "application/json" } });
}

export const adminClient = (): SupabaseClient => createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

/** Utilisateur appelant (jeton Supabase du client), ou null. */
export async function callerOf(req: Request): Promise<string | null> {
  const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data } = await asUser.auth.getUser();
  return data?.user?.id ?? null;
}

export const functionUrl = (name: string) => `${Deno.env.get("SUPABASE_URL")}/functions/v1/${name}`;
export const redirectUri = () => functionUrl("integrations-oauth") + "/callback";

// ---------------------------------------------------------------- chiffrement
const b64 = {
  enc: (b: ArrayBuffer | Uint8Array) => btoa(String.fromCharCode(...new Uint8Array(b))),
  dec: (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0)),
};
export const b64url = (b: ArrayBuffer | Uint8Array) => b64.enc(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

export function encryptionConfigured(): boolean {
  const k = Deno.env.get("INTEGRATIONS_ENC_KEY");
  if (!k) return false;
  try { return b64.dec(k).length === 32; } catch { return false; }
}

async function aesKey(): Promise<CryptoKey> {
  const raw = b64.dec(Deno.env.get("INTEGRATIONS_ENC_KEY") ?? "");
  if (raw.length !== 32) throw new Error("INTEGRATIONS_ENC_KEY doit contenir 32 octets en base64");
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

/** Format : v1.<iv base64>.<texte chiffré base64>. Un IV aléatoire de 96 bits par valeur. */
export async function seal(plain: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await aesKey(), new TextEncoder().encode(plain));
  return `v1.${b64.enc(iv)}.${b64.enc(ct)}`;
}

export async function open(sealed: string): Promise<string> {
  const [v, iv, ct] = sealed.split(".");
  if (v !== "v1" || !iv || !ct) throw new Error("format de jeton inconnu");
  const pt = await crypto.subtle.decrypt({ name: "AES-GCM", iv: b64.dec(iv) }, await aesKey(), b64.dec(ct));
  return new TextDecoder().decode(pt);
}

// ---------------------------------------------------------------- PKCE / états
export function randomToken(bytes = 32): string { return b64url(crypto.getRandomValues(new Uint8Array(bytes))); }

export async function pkcePair(): Promise<{ verifier: string; challenge: string }> {
  const verifier = randomToken(48); // 64 caractères, dans la plage 43–128 de la RFC 7636
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return { verifier, challenge: b64url(digest) };
}

export function sameString(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

export async function hmacHex(secret: string, data: string, hash: "SHA-256" | "SHA-1" = "SHA-256"): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return [...new Uint8Array(sig)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

export async function hmacBase64(secret: string, data: string, hash: "SHA-256" | "SHA-1" = "SHA-1"): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash }, false, ["sign"]);
  return b64.enc(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data)));
}

/** Erreur d'API fournisseur : jamais le corps brut (il peut contenir des données personnelles) dans les journaux. */
export class ProviderError extends Error {
  constructor(public status: number, message: string, public retryAfterSec?: number, public authFailure = false) { super(message); }
}

export async function fetchJson(url: string, init: RequestInit = {}): Promise<Record<string, unknown>> {
  let res: Response;
  try { res = await fetch(url, init); } catch { throw new ProviderError(502, "Fournisseur injoignable"); }
  const text = await res.text();
  let data: Record<string, unknown> = {};
  try { data = text ? JSON.parse(text) : {}; } catch { data = { _raw: text.slice(0, 200) }; }
  if (!res.ok) {
    const retry = Number(res.headers.get("Retry-After") ?? "") || undefined;
    const code = String((data.error as Record<string, unknown>)?.code ?? data.error ?? res.status);
    throw new ProviderError(res.status, `Refus du fournisseur (${res.status} ${code}`.slice(0, 80) + ")", retry, res.status === 401);
  }
  return data;
}

export const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
