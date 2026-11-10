// Briques pures de la réinitialisation par code (testées sans réseau).
export const CODE_TTL_MS = 10 * 60 * 1000;
export const MAX_ATTEMPTS = 5;
export const MAX_CODES_PER_HOUR = 3;

/** Numéro camerounais 6XXXXXXXX depuis une saisie libre ; null si invalide. */
export function normalizePhone(v: unknown): string | null {
  let d = String(v ?? "").replace(/[^0-9+]/g, "");
  if (d.startsWith("+237")) d = d.slice(4);
  else if (d.startsWith("237") && d.length === 12) d = d.slice(3);
  return /^6\d{8}$/.test(d) ? d : null;
}

/** Formes sous lesquelles un numéro a pu être enregistré dans profiles.phone. */
export const phoneVariants = (p: string) => [p, `+237${p}`, `237${p}`, `+237 ${p}`];

/** Code à 6 chiffres, tiré au hasard cryptographique (sans biais de modulo). */
export function newCode(): string {
  const a = new Uint32Array(1);
  do { crypto.getRandomValues(a); } while (a[0] >= 4294000000);
  return String(a[0] % 1000000).padStart(6, "0");
}

/** Même règle que l'application : 8 caractères, une majuscule, un chiffre. */
export function passwordError(pw: string): string | null {
  if (pw.length < 8) return "8 caractères minimum.";
  if (!/[A-Z]/.test(pw)) return "Ajoutez une lettre majuscule.";
  if (!/[0-9]/.test(pw)) return "Ajoutez un chiffre.";
  return null;
}

export const smsText = (code: string) => `Boutik-École : votre code de réinitialisation est ${code}. Valable 10 minutes. Ne le communiquez à personne.`;
