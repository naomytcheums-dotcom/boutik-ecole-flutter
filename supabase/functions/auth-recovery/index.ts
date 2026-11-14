// Edge Function « auth-recovery » : mot de passe oublié par SMS / WhatsApp + connexion par téléphone.
//   POST {action:"channels"}                              -> canaux réellement configurés {email, sms, whatsapp}
//   POST {action:"request", channel, phone}               -> envoie un code à usage unique ; réponse IDENTIQUE que le compte existe ou non
//   POST {action:"confirm", phone, code, password}        -> vérifie le code (haché, 10 min, 5 essais) et change le mot de passe (API admin)
//   POST {action:"login_phone", phone, password}          -> connexion par téléphone pour un compte dont l'identifiant Auth est un e-mail
// Déployer avec --no-verify-jwt (appelée avant toute connexion). Secrets : TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_SMS_FROM, TWILIO_WHATSAPP_FROM.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { adminClient, cors, hmacHex, jsonResponse, sameString } from "../_shared/core.ts";
import { CODE_TTL_MS, MAX_ATTEMPTS, MAX_CODES_PER_HOUR, newCode, normalizePhone, passwordError, phoneVariants, smsText } from "../_shared/recovery.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const twilioOk = () => !!(env("TWILIO_ACCOUNT_SID") && env("TWILIO_AUTH_TOKEN"));
const channels = () => ({
  email: true, // lien Supabase Auth
  sms: twilioOk() && !!env("TWILIO_SMS_FROM"),
  whatsapp: twilioOk() && !!env("TWILIO_WHATSAPP_FROM"),
});
const hashCode = (userId: string, code: string) => hmacHex(env("SUPABASE_SERVICE_ROLE_KEY"), `${userId}:${code}`);

async function sendTwilio(channel: "sms" | "whatsapp", phone: string, body: string): Promise<void> {
  const wa = channel === "whatsapp";
  const from = wa ? "whatsapp:" + env("TWILIO_WHATSAPP_FROM").replace(/^whatsapp:/, "").replace(/\s/g, "") : env("TWILIO_SMS_FROM");
  const r = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${env("TWILIO_ACCOUNT_SID")}/Messages.json`, {
    method: "POST",
    headers: { Authorization: "Basic " + btoa(`${env("TWILIO_ACCOUNT_SID")}:${env("TWILIO_AUTH_TOKEN")}`), "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ To: (wa ? "whatsapp:" : "") + "+237" + phone, From: from, Body: body }),
  });
  if (!r.ok) throw new Error(`twilio ${r.status}`);
}

async function userByPhone(db: ReturnType<typeof adminClient>, phone: string): Promise<{ id: string } | null> {
  const { data } = await db.from("profiles").select("id").in("phone", phoneVariants(phone)).limit(2);
  // numéro partagé par plusieurs comptes : on n'envoie rien (ambigu) plutôt que de viser le mauvais compte
  return data && data.length === 1 ? { id: data[0].id as string } : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { ...cors(req), "Access-Control-Allow-Methods": "POST, OPTIONS" } });
  if (req.method !== "POST") return jsonResponse(req, { error: "method" }, 405);
  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return jsonResponse(req, { error: "bad_request", message: "Requête illisible." }, 400); }
  const db = adminClient();

  try {
    switch (b.action) {
      case "channels":
        return jsonResponse(req, channels());

      case "request": {
        const phone = normalizePhone(b.phone);
        const channel = b.channel === "whatsapp" ? "whatsapp" : b.channel === "sms" ? "sms" : null;
        if (!phone || !channel) return jsonResponse(req, { error: "bad_request", message: "Numéro invalide : 9 chiffres commençant par 6." }, 400);
        if (!channels()[channel]) return jsonResponse(req, { error: "channel_unavailable", message: `L’envoi par ${channel === "sms" ? "SMS" : "WhatsApp"} n’est pas disponible pour le moment.` }, 503);
        const same = { ok: true, ttl_minutes: CODE_TTL_MS / 60000 }; // réponse unique : aucune information sur l'existence du compte
        const user = await userByPhone(db, phone);
        if (!user) return jsonResponse(req, same);
        const since = new Date(Date.now() - 3600_000).toISOString();
        const { count } = await db.from("auth_recovery_codes").select("id", { count: "exact", head: true }).eq("phone", phone).gte("created_at", since);
        if ((count ?? 0) >= MAX_CODES_PER_HOUR) return jsonResponse(req, same);
        const code = newCode();
        await db.from("auth_recovery_codes").update({ used_at: new Date().toISOString() }).eq("user_id", user.id).is("used_at", null); // un seul code actif
        const { error } = await db.from("auth_recovery_codes").insert({
          user_id: user.id, phone, channel, code_hash: await hashCode(user.id, code), expires_at: new Date(Date.now() + CODE_TTL_MS).toISOString(),
        });
        if (error) throw error;
        // Envoi en arrière-plan, sans l'attendre : un compte inconnu répond instantanément, un compte existant doit répondre aussi vite
        // (sinon l'écart de durée révélerait l'existence du compte). Un échec d'envoi est seulement journalisé.
        const envoi = sendTwilio(channel, phone, smsText(code)).catch((e) => console.error("envoi du code", String(e)));
        const runtime = (globalThis as unknown as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;
        if (runtime?.waitUntil) runtime.waitUntil(envoi);
        return jsonResponse(req, same);
      }

      case "confirm": {
        const phone = normalizePhone(b.phone);
        const code = String(b.code ?? "").trim();
        const password = String(b.password ?? "");
        const bad = { error: "invalid_code", message: "Code incorrect ou expiré. Demandez un nouveau code." };
        if (!phone || !/^\d{6}$/.test(code)) return jsonResponse(req, bad, 400);
        const pwErr = passwordError(password);
        if (pwErr) return jsonResponse(req, { error: "weak_password", message: pwErr }, 400);
        const { data: rows } = await db.from("auth_recovery_codes").select("*").eq("phone", phone).is("used_at", null)
          .gt("expires_at", new Date().toISOString()).order("created_at", { ascending: false }).limit(1);
        const row = rows?.[0];
        if (!row || row.attempts >= MAX_ATTEMPTS) return jsonResponse(req, bad, 400);
        await db.from("auth_recovery_codes").update({ attempts: row.attempts + 1 }).eq("id", row.id);
        if (!sameString(row.code_hash as string, await hashCode(row.user_id as string, code))) return jsonResponse(req, bad, 400);
        const { error } = await db.auth.admin.updateUserById(row.user_id as string, { password });
        if (error) {
          const same = /different from the old/i.test(error.message);
          return jsonResponse(req, { error: same ? "same_password" : "update_failed", message: same ? "Choisissez un mot de passe différent de l’ancien." : "Mot de passe non modifié. Réessayez." }, 400);
        }
        await db.from("auth_recovery_codes").update({ used_at: new Date().toISOString() }).eq("user_id", row.user_id).is("used_at", null);
        return jsonResponse(req, { ok: true });
      }

      case "login_phone": {
        const phone = normalizePhone(b.phone);
        const password = String(b.password ?? "");
        const bad = { error: "invalid_credentials", message: "Identifiant ou mot de passe incorrect." };
        if (!phone || !password) return jsonResponse(req, bad, 401);
        const user = await userByPhone(db, phone);
        if (!user) return jsonResponse(req, bad, 401);
        const { data: u } = await db.auth.admin.getUserById(user.id);
        const email = u?.user?.email;
        if (!email) return jsonResponse(req, bad, 401);
        const anon = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), { auth: { persistSession: false, autoRefreshToken: false } });
        const { data, error } = await anon.auth.signInWithPassword({ email, password });
        if (error || !data.session) return jsonResponse(req, bad, 401);
        return jsonResponse(req, { refresh_token: data.session.refresh_token });
      }
    }
    return jsonResponse(req, { error: "unknown_action" }, 400);
  } catch (e) {
    console.error("auth-recovery", String(e));
    return jsonResponse(req, { error: "server", message: "Service momentanément indisponible. Réessayez." }, 500);
  }
});
