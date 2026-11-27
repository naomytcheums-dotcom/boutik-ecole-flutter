// Exécuteur de la bascule des médias NON publics de « post-media » vers « post-media-private » (voir docs\transformation\H131_MATRICE_ACCES_MEDIAS.md).
// COPIE seulement (API Storage /object/copy) puis vérification côté base : AUCUNE suppression, jamais. Clé de service lue dans l'environnement (jamais écrite ici).
//   $env:SUPABASE_URL, $env:SUPABASE_SERVICE_ROLE_KEY
//   node tool/backup/media_migrate_private.mjs --dry-run              (liste ce qui serait copié ; met seulement en file)
//   node tool/backup/media_migrate_private.mjs --limit 50 [--orphans]  (copie + confirmation)
// Prêt, NON exécuté pendant H13.1 (aucun accès production autorisé) ; testé contre la base de test par supabase\tests\marketplace_pglite\h131_media.mjs.
const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) { console.error('SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY requis dans l\'environnement.'); process.exit(2); }
const arg = (n, d) => { const i = process.argv.indexOf(n); return i < 0 ? d : process.argv[i + 1]; };
const dry = process.argv.includes('--dry-run'), orphans = process.argv.includes('--orphans'), limit = Number(arg('--limit', 50));
const H = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
const rpc = async (fn, body) => { const r = await fetch(`${url}/rest/v1/rpc/${fn}`, { method: 'POST', headers: H, body: JSON.stringify(body) }); const t = await r.text(); if (!r.ok) throw new Error(`${fn} ${r.status} ${t}`); return t ? JSON.parse(t) : null; };

const queue = await rpc('media_migrate_private_batch', { p_limit: limit, p_include_orphans: orphans });
console.log(`file d'attente : ${queue.length} fichier(s)`);
for (const x of queue) console.log(` - ${x.path} (${x.reason}, ${x.status})`);
if (dry) { console.log('--dry-run : aucune copie.'); process.exit(0); }
let verified = 0, failed = 0;
for (const x of queue) {
  const r = await fetch(`${url}/storage/v1/object/copy`, { method: 'POST', headers: H, body: JSON.stringify({ bucketId: 'post-media', sourceKey: x.path, destinationBucket: 'post-media-private', destinationKey: x.path }) });
  if (!r.ok && !/already exists|Duplicate/i.test(await r.text())) { console.log('COPIE KO', x.path, r.status); failed++; continue; }
  const st = await rpc('media_migrate_confirm', { p_path: x.path });
  console.log(st === 'verified' ? 'VERIFIE' : `A REVOIR (${st})`, x.path);
  st === 'verified' ? verified++ : failed++;
}
console.log(`terminé : ${verified} vérifié(s), ${failed} à revoir. Anciens fichiers CONSERVÉS : leur suppression reste une action humaine (media_old_deletion_candidates()).`);
console.log(JSON.stringify(await rpc('media_migration_report', {})));
