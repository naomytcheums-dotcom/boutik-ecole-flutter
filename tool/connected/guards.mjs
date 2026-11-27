// Gardes communes des outils de validation CONNECTEE (H13.1) : ces outils ECRIVENT des donnees, ils ne doivent donc tourner que sur un projet Supabase de TEST
// explicitement fourni, jamais sur la production (reference zxqcnmgwhtbxkdpjqtlr). Aucune cle n'est lue ici : seules l'URL et (si fournie) la cle sont inspectees.
export const PROD_REF = 'zxqcnmgwhtbxkdpjqtlr';

export class GuardError extends Error {
  constructor(message) { super(message); this.name = 'GuardError'; }
}

const decodeJwtPayload = (token) => {
  try {
    const part = String(token).split('.')[1];
    if (!part) return null;
    return JSON.parse(Buffer.from(part.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
  } catch { return null; }
};

/** Verifie l'environnement d'un outil qui ECRIT. Renvoie { url, host } ou leve GuardError (message commencant par REFUS). */
export function assertTestEnvironment(env, { keys = [] } = {}) {
  const raw = String(env.SUPABASE_URL ?? '').trim();
  if (!raw) throw new GuardError('REFUS : SUPABASE_URL est obligatoire (URL du projet Supabase de TEST).');
  if (!String(env.ALLOW_TEST_PROJECT ?? '').trim()) {
    throw new GuardError('REFUS : ALLOW_TEST_PROJECT n\'est pas defini. Definissez-le seulement si SUPABASE_URL est un projet Supabase de TEST jetable.');
  }
  let u;
  try { u = new URL(raw); } catch { throw new GuardError('REFUS : SUPABASE_URL n\'est pas une URL valide.'); }
  const everything = `${raw} ${decodeURIComponent(raw)}`.toLowerCase();
  if (everything.includes(PROD_REF)) throw new GuardError(`REFUS : l'URL contient la reference de PRODUCTION (${PROD_REF}). Aucune ecriture n'est jamais permise sur la production.`);
  const host = u.hostname.toLowerCase();
  const local = host === 'localhost' || host === '127.0.0.1' || host === '[::1]';
  if (!local && !/^[a-z0-9-]+\.supabase\.co$/.test(host)) throw new GuardError('REFUS : l\'hote doit etre <reference>.supabase.co (projet de test) ou localhost.');
  if (!local && u.protocol !== 'https:') throw new GuardError('REFUS : un projet distant doit etre joint en https.');
  if (u.username || u.password) throw new GuardError('REFUS : l\'URL ne doit contenir ni identifiant ni mot de passe.');
  for (const k of keys) {
    const p = k ? decodeJwtPayload(k) : null;
    if (p && JSON.stringify(p).toLowerCase().includes(PROD_REF)) throw new GuardError('REFUS : une cle fournie appartient au projet de PRODUCTION.');
  }
  return { url: raw.replace(/\/$/, ''), host };
}

export const TEST_DOMAIN = 'test.invalid';
export const isTestEmail = (e) => String(e).toLowerCase().endsWith(`@${TEST_DOMAIN}`);
