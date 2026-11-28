// Crochets de chargement des tests de contrat : imports distants (esm.sh, npm:) vers de faux modules locaux, et deux adaptations de SOURCE nécessaires pour Node
// (les fonctions sont écrites pour Deno, qui accepte ces formes) :
//   * « import.meta.main » (vrai sous Deno quand la fonction est le point d'entrée) est remplacé par true ;
//   * les imports de types sans « type » depuis types.ts (Provider, TokenSet) sont retirés (ils sont effacés à la compilation sous Deno, mais Node les cherche à l'exécution).
const FAKE = {
  'https://esm.sh/@supabase/supabase-js@2': new URL('./fake_supabase_js.mjs', import.meta.url).href,
  'npm:web-push@3.6.7': new URL('./fake_webpush.mjs', import.meta.url).href,
};
export async function resolve(specifier, context, nextResolve) {
  if (FAKE[specifier]) return { url: FAKE[specifier], shortCircuit: true };
  return nextResolve(specifier, context);
}
export async function load(url, context, nextLoad) {
  const r = await nextLoad(url, context);
  if (!/\/supabase\/functions\//.test(url) || !/\.ts(\?|$)/.test(url) || r.source == null) return r;
  let s = String(r.source);
  s = s.replace(/import\.meta\.main/g, 'true') + '\nexport {};'; // « export {} » : force le mode ESM (un fichier sans import/export serait chargé en CommonJS et mis en cache sans la requête ?c=)
  s = s.replace(/import\s*\{([^}]*)\}\s*from\s*(["'][^"']*types\.ts["'])\s*;?/g, (m, names, from) => {
    const kept = names.split(',').map((x) => x.trim()).filter((x) => x && !/^(Provider|TokenSet)$/.test(x));
    return kept.length ? `import { ${kept.join(', ')} } from ${from};` : '';
  });
  return { ...r, format: 'module-typescript', source: s };
}
