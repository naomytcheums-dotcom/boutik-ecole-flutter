// Inventaire des médias de « post-media » : lecture seule, AUCUNE écriture, AUCUNE suppression, aucune donnée personnelle dans le rapport.
// Une ligne par objet : référence (publication, histoire, couverture…), niveau de confidentialité (publique / en_attente_validation / restreinte / non_rattachee), motif, taille, type MIME,
// copie privée présente, état de la bascule. Les identifiants d'objet sont des empreintes du chemin (jamais le chemin, ni l'identifiant du compte).
//   $env:SUPABASE_URL, $env:SUPABASE_SERVICE_ROLE_KEY  (jamais écrits dans un fichier)
//   node tool/backup/media_inventory.mjs [--out media_inventaire.json] [--orphans]      rapport complet par objet (RPC media_inventory_objects, service_role)
//   node tool/backup/media_inventory.mjs --linked                                       compteurs seulement, via la CLI Supabase déjà liée (aucune clé dans ce script)
// Prérequis du rapport par objet : migration 20261130060200 (media_inventory_objects). Réservé au propriétaire / à l'administrateur.
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { buildReport, fetchInventory, makeClient } from './media_lib.mjs';

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

const arg = (n, d) => { const i = process.argv.indexOf(n); return i < 0 ? d : process.argv[i + 1]; };

if (process.argv.includes('--linked')) {
  if (/\b(insert|update|delete|drop|alter|truncate)\b/i.test(SQL.replace(/_media_restrict_reason|storage\.objects/g, ''))) throw new Error('requête non lecture seule');
  console.log(execFileSync('supabase', ['db', 'query', '--linked', SQL], { encoding: 'utf8', shell: process.platform === 'win32' }));
} else {
  let client;
  try { client = makeClient({ url: process.env.SUPABASE_URL, key: process.env.SUPABASE_SERVICE_ROLE_KEY }); } catch (e) { console.error(e.message); process.exit(2); }
  const objects = await fetchInventory(client);
  const buckets = await client.rpc('media_inventory_buckets', {});
  const report = buildReport(objects, buckets, { orphans: process.argv.includes('--orphans') });
  const out = arg('--out', 'media_inventaire.json');
  fs.writeFileSync(out, JSON.stringify(report, null, 1));
  console.log(JSON.stringify(report.summary, null, 1));
  console.log(`rapport par objet écrit : ${out} (${report.objects.length} objets, sans donnée personnelle)`);
}
