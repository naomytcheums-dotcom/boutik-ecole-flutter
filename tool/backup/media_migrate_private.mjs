// Bascule des médias NON publics de « post-media » vers « post-media-private » (procédure : docs\transformation\H132_MEDIAS_ANCIENS_PROCEDURE.md).
// DRY-RUN PAR DÉFAUT : sans --apply, rien n'est écrit (ni copie, ni file d'attente, ni référence). AUCUNE suppression, jamais : ce script n'en contient aucune.
// Avec --apply, pour chaque fichier de la file : copie par l'API Storage -> relecture des DEUX compartiments -> taille ET SHA-256 identiques -> seulement alors la référence
// (post_media.storage_bucket) est mise à jour par media_migrate_confirm_checked. Un incident sur un fichier n'arrête pas les autres ; relancer la commande reprend (fichier d'état).
//   $env:SUPABASE_URL, $env:SUPABASE_SERVICE_ROLE_KEY   (clé de service lue dans l'environnement, jamais écrite)
//   node tool/backup/media_migrate_private.mjs                                   plan seulement (dry-run)
//   node tool/backup/media_migrate_private.mjs --apply --limit 50 [--orphans] [--state media_migration_state.json] [--report media_bascule_rapport.json]
//   node tool/backup/media_migrate_private.mjs --rollback --path <chemin> --apply   (ou --all) : retour arrière côté base ; les copies privées sont conservées
import fs from 'node:fs';
import { makeClient, migrate, rollback } from './media_lib.mjs';

const arg = (n, d) => { const i = process.argv.indexOf(n); return i < 0 ? d : process.argv[i + 1]; };
const has = (n) => process.argv.includes(n);
let client;
try { client = makeClient({ url: process.env.SUPABASE_URL, key: process.env.SUPABASE_SERVICE_ROLE_KEY }); } catch (e) { console.error(e.message); process.exit(2); }
const log = (m) => console.log(m);

if (has('--rollback')) {
  await rollback(client, { apply: has('--apply'), path: arg('--path', null), all: has('--all'), log });
} else {
  const res = await migrate(client, { apply: has('--apply'), limit: Number(arg('--limit', 50)), orphans: has('--orphans'), statePath: arg('--state', 'media_migration_state.json'), log });
  const { errors, ...summary } = res;
  console.log(JSON.stringify({ ...summary, incidents: errors.length }));
  if (has('--apply')) {
    fs.writeFileSync(arg('--report', 'media_bascule_rapport.json'), JSON.stringify({ generated_at: new Date().toISOString(), contient_des_donnees_personnelles: false, ...summary, incidents: errors }, null, 1));
    console.log('Anciens fichiers CONSERVÉS : leur suppression reste une action humaine (media_old_deletion_candidates()), après contrôle.');
  }
  process.exitCode = res.failed ? 1 : 0;
}
