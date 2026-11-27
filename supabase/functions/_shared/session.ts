// Contrôle serveur de la session de l'appelant d'une Edge Function (H13.1 · lot SESSIONS).
// Pourquoi : la signature d'un jeton d'accès reste valable jusqu'à son expiration (1 h) même après la fermeture de la session ou la suspension du compte.
// Une fonction qui agit avec la clé de service au nom de l'appelant ne doit donc JAMAIS se contenter de décoder ou de vérifier la signature du jeton :
//   1. l'identité vient de GoTrue (auth.getUser), qui refuse un jeton dont la session n'existe plus ;
//   2. l'état de la session et du compte est revérifié dans la base (fonction _session_status_of, réservée à la clé de service) : session fermée => 401 « session_revoked »,
//      compte suspendu ou bloqué => 403 « account_suspended » ; si la vérification est indisponible, la requête est refusée (503) plutôt qu'acceptée.
// Module sans dépendance (testable sous Node avec de faux services).

export type Denial = { status: 401 | 403 | 503; body: { error: string; code: string; message: string } };
export type CallerResult = { ok: true; uid: string; sessionId: string | null } | ({ ok: false } & Denial);

export type CallerDeps = {
  /** Identité vérifiée par GoTrue (auth.getUser) ; null si le jeton est refusé. */
  getUserId: () => Promise<string | null>;
  /** 'ok' | 'session_revoked' | 'suspended' ; null si la vérification a échoué. */
  sessionStatus: (uid: string, sessionId: string | null) => Promise<string | null>;
};

export const MSG_REVOKED = "Session expirée ou révoquée, reconnectez-vous";
export const MSG_SUSPENDED = "Compte suspendu : cette action est impossible. Contactez le support.";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Revendications du jeton SANS vérifier la signature : ne sert qu'à lire session_id (jamais à établir une identité). */
export function claimsOf(authHeader: string | null | undefined): Record<string, unknown> {
  const m = /^Bearer\s+([^\s]+)$/i.exec((authHeader ?? "").trim());
  const parts = m ? m[1].split(".") : [];
  if (parts.length !== 3) return {};
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = new TextDecoder().decode(Uint8Array.from(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)), (c) => c.charCodeAt(0)));
    const c = JSON.parse(json);
    return c && typeof c === "object" ? c : {};
  } catch {
    return {};
  }
}

export function sessionIdOf(authHeader: string | null | undefined): string | null {
  const s = claimsOf(authHeader).session_id;
  return typeof s === "string" && UUID.test(s) ? s : null;
}

const unauthorized = (): Denial => ({ status: 401, body: { error: "unauthorized", code: "unauthorized", message: "Connexion requise." } });

function denialFor(status: string | null): Denial | null {
  if (status === "ok") return null;
  if (status === "session_revoked") return { status: 401, body: { error: "session_revoked", code: "session_revoked", message: MSG_REVOKED } };
  if (status === "suspended") return { status: 403, body: { error: "account_suspended", code: "account_suspended", message: MSG_SUSPENDED } };
  return { status: 503, body: { error: "session_check_unavailable", code: "session_check_unavailable", message: "Vérification de la session impossible, réessayez." } };
}

export async function verifyCaller(authHeader: string | null | undefined, deps: CallerDeps): Promise<CallerResult> {
  const sid = sessionIdOf(authHeader);
  let uid: string | null = null;
  try { uid = await deps.getUserId(); } catch { uid = null; }
  if (!uid) {
    // Jeton refusé par GoTrue : on précise le motif (session fermée) si la base le confirme, sans jamais accepter la requête.
    const sub = claimsOf(authHeader).sub;
    if (sid && typeof sub === "string" && UUID.test(sub)) {
      let st: string | null = null;
      try { st = await deps.sessionStatus(sub, sid); } catch { st = null; }
      if (st === "session_revoked" || st === "suspended") return { ok: false, ...denialFor(st)! };
    }
    return { ok: false, ...unauthorized() };
  }
  let status: string | null = null;
  try { status = await deps.sessionStatus(uid, sid); } catch { status = null; }
  const d = denialFor(status);
  return d ? { ok: false, ...d } : { ok: true, uid, sessionId: sid };
}
