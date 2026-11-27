// Inventaire des médias de « post-media » PAR STATUT DU CONTENU : lecture seule, AUCUNE écriture, AUCUNE suppression.
// Sorties : compteurs (publics / en attente / restreints / non rattachés) + liste des fichiers restreints encore exposés par URL publique.
// Deux modes, au choix :
//   1. via la CLI Supabase déjà liée au projet (aucune clé dans ce script) :
//        node tool/backup/media_inventory.mjs --linked
//   2. via l'API REST avec une clé de service lue dans l'environnement (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY) : appelle media_migration_report() (lecture seule) :
//        node tool/backup/media_inventory.mjs --rest
// Réservé au propriétaire / à l'administrateur ; n'a pas été exécuté pendant le lot H13.1 (aucun accès production autorisé).
import { execFileSync } from 'child_process';

const SQL = `
with o as (
  select o.name, o.created_at, _media_ref_state(o.name) as etat
  from storage.objects o where o.bucket_id = 'post-media')
select jsonb_build_object(
  'objets_post_media', (select count(*) from o),
  'publics', (select count(*) from o where etat = 'public'),
  'en_attente_validation', (select count(*) from o where etat = 'pending'),
  'restreints_encore_exposes_par_url', (select count(*) from o where etat = 'restricted'),
  'non_rattaches', (select count(*) from o where etat = 'unreferenced'),
  'objets_post_media_private', (select count(*) from storage.objects where bucket_id = 'post-media-private'),
  'compartiments', (select jsonb_agg(jsonb_build_object('id', id, 'public', public) order by id) from storage.buckets),
  'restreints_par_motif', (select coalesce(jsonb_object_agg(motif, n), '{}'::jsonb) from (
      select r.reason as motif, count(*) n from o cross join lateral _media_restrict_reason(o.name, true) r where o.etat in ('restricted', 'unreferenced') group by r.reason) x)
) as inventaire;`;

const mode = process.argv.includes('--rest') ? 'rest' : 'linked';
if (/\b(insert|update|delete|drop|alter|truncate)\b/i.test(SQL.replace(/_media_restrict_reason|storage\.objects/g, ''))) throw new Error('requête non lecture seule');

if (mode === 'linked') {
  const out = execFileSync('supabase', ['db', 'query', '--linked', SQL], { encoding: 'utf8', shell: process.platform === 'win32' });
  console.log(out);
} else {
  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) { console.error('SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY requis dans l\'environnement.'); process.exit(2); }
  const r = await fetch(`${url}/rest/v1/rpc/media_migration_report`, { method: 'POST', headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' }, body: '{}' });
  console.log(r.status, await r.text());
}
