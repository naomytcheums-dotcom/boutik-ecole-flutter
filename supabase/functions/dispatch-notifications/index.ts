
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const MAX = 40;

const GOOGLE_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";

type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

type CachedGoogleToken = {
  value: string;
  expiresAt: number;
};

let cachedGoogleToken: CachedGoogleToken | null = null;

// Repli : les clés VAPID ont pu être enregistrées sous les noms « Public Key » / « Private Key ».
const ALIASES: Record<string, string> = { VAPID_PUBLIC_KEY: "Public Key", VAPID_PRIVATE_KEY: "Private Key" };
const env = (key: string) => Deno.env.get(key) ?? (ALIASES[key] ? Deno.env.get(ALIASES[key]) ?? "" : "");

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);

  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function encodeJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)));
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes.buffer;
}

function loadFirebaseServiceAccount(): FirebaseServiceAccount {
  const raw = env("FIREBASE_SERVICE_ACCOUNT_JSON");

  if (!raw) {
    throw new Error("Secret Firebase absent");
  }

  let account: FirebaseServiceAccount;

  try {
    account = JSON.parse(raw);
  } catch {
    throw new Error("Configuration Firebase JSON invalide");
  }

  if (
    !account.project_id ||
    !account.client_email ||
    !account.private_key
  ) {
    throw new Error("Configuration Firebase incomplète");
  }

  return account;
}

async function getGoogleAccessToken(): Promise<string> {
  if (
    cachedGoogleToken &&
    cachedGoogleToken.expiresAt > Date.now() + 60_000
  ) {
    return cachedGoogleToken.value;
  }

  const account = loadFirebaseServiceAccount();
  const now = Math.floor(Date.now() / 1000);

  const header = encodeJson({
    alg: "RS256",
    typ: "JWT",
  });

  const claims = encodeJson({
    iss: account.client_email,
    scope: GOOGLE_SCOPE,
    aud: account.token_uri || GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  });

  const unsignedJwt = `${header}.${claims}`;

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(account.private_key.replace(/\\n/g, "\n")),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedJwt),
  );

  const assertion = `${unsignedJwt}.${base64Url(
    new Uint8Array(signature),
  )}`;

  const response = await fetch(
    account.token_uri || GOOGLE_TOKEN_URL,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`Authentification Google refusée (${response.status})`);
  }

  const result = await response.json();

  if (!result.access_token) {
    throw new Error("Google n'a pas fourni de jeton OAuth");
  }

  cachedGoogleToken = {
    value: result.access_token,
    expiresAt: Date.now() + Number(result.expires_in || 3600) * 1000,
  };

  return cachedGoogleToken.value;
}

async function sendFcm(
  token: string,
  notification: {
    title: string;
    body: string;
    notification_id?: string;
    kind?: string;
  },
): Promise<void> {
  const account = loadFirebaseServiceAccount();
  const accessToken = await getGoogleAccessToken();

  const data: Record<string, string> = {};

  if (notification.notification_id) {
    data.notification_id = notification.notification_id;
  }

  if (notification.kind) {
    data.kind = notification.kind;
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data,
        },
      }),
    },
  );

  if (!response.ok) {
    let errorCode = "";
    let status = "";

    try {
      const result = await response.json();
      status = result?.error?.status ?? "";

      const details = result?.error?.details;
      if (Array.isArray(details)) {
        const fcmError = details.find(
          (item: any) =>
            item?.["@type"] ===
            "type.googleapis.com/google.firebase.fcm.v1.FcmError",
        );

        errorCode = fcmError?.errorCode ?? "";
      }
    } catch {
      // Ne pas exposer le corps brut de la réponse Google.
    }

    if (errorCode === "UNREGISTERED") {
      throw new Error("FCM_TOKEN_UNREGISTERED");
    }

    throw new Error(
      `FCM refusé (${response.status}${status ? ` ${status}` : ""})`,
    );
  }
}

Deno.serve(async () => {
  const admin = createClient(
    env("SUPABASE_URL"),
    env("SUPABASE_SERVICE_ROLE_KEY"),
  );

  const webPushReady =
    !!env("VAPID_PUBLIC_KEY") &&
    !!env("VAPID_PRIVATE_KEY") &&
    !!env("VAPID_SUBJECT");

  const firebaseReady = !!env("FIREBASE_SERVICE_ACCOUNT_JSON");

  const ready: Record<string, boolean> = {
    email: !!env("RESEND_API_KEY") && !!env("RESEND_FROM"),
    sms:
      !!env("TWILIO_ACCOUNT_SID") &&
      !!env("TWILIO_AUTH_TOKEN") &&
      !!env("TWILIO_SMS_FROM"),
    whatsapp:
      !!env("TWILIO_ACCOUNT_SID") &&
      !!env("TWILIO_AUTH_TOKEN") &&
      !!env("TWILIO_WHATSAPP_FROM"),
    push: webPushReady || firebaseReady,
  };

  const channels = Object.keys(ready).filter((channel) => ready[channel]);

  if (channels.length === 0) {
    return Response.json({
      sent: 0,
      note: "aucun canal configuré",
    });
  }

  // Les notifications âgées de plus de 24 h ne sont pas envoyées.
  await admin
    .from("notification_outbox")
    .update({
      status: "skipped",
      last_error: "périmée",
    })
    .eq("status", "queued")
    .lt(
      "created_at",
      new Date(Date.now() - 86400_000).toISOString(),
    );

  const { data: rows, error: selectError } = await admin
    .from("notification_outbox")
    .select("*")
    .eq("status", "queued")
    .in("channel", channels)
    .order("created_at")
    .limit(MAX);

  if (selectError) {
    return Response.json(
      { sent: 0, error: "lecture de la file impossible" },
      { status: 500 },
    );
  }

  if (!rows?.length) {
    return Response.json({ sent: 0 });
  }

  if (webPushReady) {
    webpush.setVapidDetails(
      env("VAPID_SUBJECT"),
      env("VAPID_PUBLIC_KEY"),
      env("VAPID_PRIVATE_KEY"),
    );
  }

  let sent = 0;

  for (const r of rows) {
    let error: string | null = null;

    try {
      const { data: profile, error: profileError } = await admin
        .from("profiles")
        .select("email, phone, name")
        .eq("id", r.user_id)
        .maybeSingle();

      if (profileError) {
        throw new Error("lecture du profil impossible");
      }

      const messageText = `${r.title}${r.body ? "\n" + r.body : ""}`;

      if (r.channel === "email") {
        if (!profile?.email) {
          throw new Error("pas d'adresse e-mail");
        }

        const response = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${env("RESEND_API_KEY")}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: env("RESEND_FROM"),
            to: [profile.email],
            subject: r.title,
            text: r.body ?? r.title,
          }),
        });

        if (!response.ok) {
          throw new Error(`e-mail refusé (${response.status})`);
        }
      } else if (r.channel === "sms" || r.channel === "whatsapp") {
        if (!profile?.phone) {
          throw new Error("pas de numéro");
        }

        const whatsapp = r.channel === "whatsapp";
        const to =
          (whatsapp ? "whatsapp:" : "") +
          profile.phone.replace(/\s/g, "");

        const response = await fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${env("TWILIO_ACCOUNT_SID")}/Messages.json`,
          {
            method: "POST",
            headers: {
              Authorization:
                "Basic " +
                btoa(
                  `${env("TWILIO_ACCOUNT_SID")}:${env("TWILIO_AUTH_TOKEN")}`,
                ),
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: new URLSearchParams({
              To: to,
              From: whatsapp
                ? "whatsapp:" + env("TWILIO_WHATSAPP_FROM").replace(/^whatsapp:/, "").replace(/\s/g, "")
                : env("TWILIO_SMS_FROM"),
              Body: messageText.slice(0, 1500),
            }),
          },
        );

        if (!response.ok) {
          let code = "";
          try {
            code = String((await response.json())?.code ?? "");
          } catch {
            // corps illisible : on garde le seul statut HTTP
          }
          throw new Error(`${r.channel} refusé (${response.status}${code ? ` Twilio ${code}` : ""})`);
        }
      } else if (r.channel === "push") {
        const { data: devices, error: devicesError } = await admin
          .from("device_tokens")
          .select("token, platform")
          .eq("user_id", r.user_id);

        if (devicesError) {
          throw new Error("lecture des appareils impossible");
        }

        if (!devices?.length) {
          throw new Error("aucun appareil enregistré");
        }

        let accepted = 0;
        const errors: string[] = [];

        for (const device of devices) {
          if (device.platform === "web" && webPushReady) {
            try {
              await webpush.sendNotification(
                JSON.parse(device.token),
                JSON.stringify({
                  title: r.title,
                  body: r.body ?? "",
                  notification_id: r.notification_id
                    ? String(r.notification_id)
                    : "",
                  kind: r.kind ? String(r.kind) : "",
                }),
              );

              accepted++;
            } catch (e: any) {
              if (e?.statusCode === 404 || e?.statusCode === 410) {
                await admin
                  .from("device_tokens")
                  .delete()
                  .eq("token", device.token)
                  .eq("user_id", r.user_id);
              } else {
                errors.push("échec Web Push");
              }
            }
          } else if (
            (device.platform === "android" || device.platform === "ios") &&
            firebaseReady
          ) {
            try {
              await sendFcm(device.token, {
                title: r.title,
                body: r.body ?? "",
                notification_id: r.notification_id
                  ? String(r.notification_id)
                  : undefined,
                kind: r.kind ? String(r.kind) : undefined,
              });

              accepted++;
            } catch (e: any) {
              if (e?.message === "FCM_TOKEN_UNREGISTERED") {
                await admin
                  .from("device_tokens")
                  .delete()
                  .eq("token", device.token)
                  .eq("user_id", r.user_id);
              } else {
                errors.push(String(e?.message ?? "échec FCM").slice(0, 120));
              }
            }
          }
        }

        if (accepted === 0) {
          throw new Error(
            errors.length
              ? errors.join("; ").slice(0, 190)
              : "aucun appareil compatible avec les canaux configurés",
          );
        }
      }
    } catch (e: any) {
      error = String(e?.message ?? e).slice(0, 200);
    }

    const { error: updateError } = await admin
      .from("notification_outbox")
      .update({
        status: error ? "failed" : "sent",
        last_error: error,
        attempts: (r.attempts ?? 0) + 1,
        sent_at: error ? null : new Date().toISOString(),
      })
      .eq("id", r.id);

    if (!error && !updateError) {
      sent++;
    }
  }

  return Response.json({
    sent,
    examined: rows.length,
  });
});
