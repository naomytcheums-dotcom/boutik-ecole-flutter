// Tests des briques partagées. Exécution : deno test --no-lock --allow-env --allow-net supabase/functions/_shared
import { adaptText } from "./adapt.ts";
import { b64url, hmacHex, open, pkcePair, randomToken, sameString, seal } from "./core.ts";
import { liEscape } from "./providers/linkedin.ts";
import { oauth1Header } from "./providers/trello.ts";

function assert(cond: boolean, msg: string) { if (!cond) throw new Error(msg); }

Deno.test("chiffrement AES-GCM : aller-retour, IV distinct, altération détectée", async () => {
  Deno.env.set("INTEGRATIONS_ENC_KEY", btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))));
  const a = await seal("jeton-secret"), b = await seal("jeton-secret");
  assert(a !== b, "deux chiffrements d'une même valeur doivent différer (IV aléatoire)");
  assert(!a.includes("jeton-secret"), "le clair ne doit pas apparaître");
  assert((await open(a)) === "jeton-secret", "aller-retour");
  let failed = false;
  try { await open(a.slice(0, -4) + "AAAA"); } catch { failed = true; }
  assert(failed, "un jeton altéré doit être refusé");
});

Deno.test("PKCE : le défi est le SHA-256 base64url du vérificateur", async () => {
  const { verifier, challenge } = await pkcePair();
  assert(verifier.length >= 43 && verifier.length <= 128, "longueur RFC 7636");
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  assert(challenge === b64url(d), "défi S256");
  assert(!/[+/=]/.test(challenge), "base64url sans remplissage");
  assert(randomToken() !== randomToken(), "états distincts");
});

Deno.test("HMAC-SHA256 (vecteur RFC 4231 n°2) et comparaison en temps constant", async () => {
  const h = await hmacHex("Jefe", "what do ya want for nothing?");
  assert(h === "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", "vecteur RFC 4231");
  assert(sameString("abc", "abc") && !sameString("abc", "abd") && !sameString("abc", "ab"), "sameString");
});

Deno.test("OAuth 1.0a : en-tête signé, secret jamais dans l'en-tête", async () => {
  const h = await oauth1Header("POST", "https://trello.com/1/OAuthGetRequestToken", { key: "k", secret: "TOPSECRET" }, undefined, { oauth_callback: "https://x/cb?state=1" });
  assert(h.startsWith("OAuth "), "schéma");
  assert(h.includes("oauth_signature_method=\"HMAC-SHA1\"") && h.includes("oauth_signature=\""), "signature");
  assert(!h.includes("TOPSECRET"), "le secret ne doit pas fuiter");
});

Deno.test("adaptation du texte : mêmes règles que l'application", () => {
  const ig = adaptText("instagram", "Nouveau produit !", "https://boutik-ecole.vercel.app/p/1");
  assert(ig.text === "Nouveau produit !\n\nLien dans la bio.", "Instagram sans lien cliquable");
  assert(adaptText("instagram", "x".repeat(5000)).text.length <= 2200, "limite Instagram");
  const fb = adaptText("facebook", "Annonce", "https://exemple.cm");
  assert(fb.text === "Annonce" && fb.link === "https://exemple.cm", "Facebook : lien séparé");
  const dc = adaptText("discord", "mot ".repeat(900), "https://exemple.cm/x");
  assert(dc.text.length <= 2000 && dc.text.endsWith("\n\nhttps://exemple.cm/x") && dc.text.includes("…"), "Discord : coupure, lien conservé");
  assert(adaptText("slack", "Un **gros** titre").text === "Un *gros* titre", "Slack : gras");
  assert(adaptText("linkedin", "  Bonjour   \n\n\n\nMonde  ").text === "Bonjour\n\nMonde", "espaces normalisés");
  const tags = Array.from({ length: 40 }, (_, i) => `#tag${i}`).join(" ");
  assert((adaptText("instagram", "Texte " + tags).text.match(/#\w+/g) ?? []).length === 30, "30 mots-clics");
});

Deno.test("LinkedIn : caractères réservés échappés", () => {
  assert(liEscape("a (b) [c] #d @e *f* _g_ ~h~ |i| {j} <k>") === "a \\(b\\) \\[c\\] \\#d \\@e \\*f\\* \\_g\\_ \\~h\\~ \\|i\\| \\{j\\} \\<k\\>", "échappement");
});
