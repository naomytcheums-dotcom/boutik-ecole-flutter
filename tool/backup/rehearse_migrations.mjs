// Repetition de migration sur une COPIE RESTAUREE de la production (PGlite, aucun reseau) :
//   1. base vierge + toutes les migrations deja appliquees en production (<= derniere version de la sauvegarde) ;
//   2. rechargement des donnees de production de la sauvegarde ;
//   3. application, une a une, des migrations en attente (versions > derniere version appliquee) ; mesure des erreurs ;
//   4. comparaison : memes lignes dans chaque table avant/apres (rien de supprime), tables sans RLS.
//   node tool/backup/rehearse_migrations.mjs <dossier_sauvegardes> <suffixe> <node_modules>
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
import { fileURLToPath } from 'url';

const [dir, suffix, nm] = process.argv.slice(2);
const require = createRequire(path.join(nm, '..', 'noop.js'));
const { PGlite } = await import('file:///' + require.resolve('@electric-sql/pglite').replace(/\\/g, '/'));
const { pgcrypto } = await import('file:///' + require.resolve('@electric-sql/pglite/contrib/pgcrypto').replace(/\\/g, '/'));
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'supabase');
const readJson = (f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8').replace(/^\uFEFF/, ''));
const data = readJson(`prod_donnees_public_${suffix}.json`);
const applied = new Set(readJson(`prod_structure_complete_${suffix}.json`).rows[0].s.migrations);
const last = [...applied].sort().pop();

const db = new PGlite({ extensions: { pgcrypto } });
await db.exec(fs.readFileSync(path.join(repo, 'tests', 'marketplace_pglite', 'replay.mjs'), 'utf8').match(/const stub = `([\s\S]*?)`;/)[1]);
const all = fs.readdirSync(path.join(repo, 'migrations')).filter((f) => f.endsWith('.sql')).sort();
const base = all.filter((f) => applied.has(f.split('_')[0]));
const pending = all.filter((f) => !applied.has(f.split('_')[0])).filter((f) => !process.env.ONLY || new RegExp(process.env.ONLY).test(f)); // ONLY=<regex> : limite la repetition a certaines migrations
console.log(`production : ${applied.size} migrations appliquees (derniere ${last}) ; locales : ${all.length} ; en attente : ${pending.length}`);
let bad = pending.filter((f) => f.split('_')[0] < last);
if (bad.length) console.log('ATTENTION migrations en attente anterieures a la derniere appliquee :', bad.join(', '));

await db.exec(fs.readFileSync(path.join(repo, 'schema.sql'), 'utf8'));
let n = 0, ko = 0;
for (const f of base) { try { await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); n++; } catch (e) { ko++; console.log('ECHEC base', f, String(e.message).split('\n')[0]); } }
console.log(`base de production reconstruite : ${n}/${base.length} migrations`);
const prodHasIdx = !(await db.query(`select 1 from pg_indexes where indexname = 'profiles_phone_verified_uk'`)).rows.length;
await db.exec('drop index if exists public.profiles_phone_verified_uk');
await db.exec('set session_replication_role = replica');
for (const t of (await db.query(`select tablename t from pg_tables where schemaname = 'public'`)).rows.map((x) => x.t)) await db.exec(`truncate table public."${t}" cascade`);
for (const { t, r } of data.rows) {
  if (!r.length) continue;
  try { await db.query(`insert into public."${t}" overriding system value select * from jsonb_populate_recordset(null::public."${t}", $1::jsonb)`, [JSON.stringify(r)]); } catch (e) { console.log('ECHEC chargement', t, String(e.message).split('\n')[0]); ko++; }
}
await db.exec('set session_replication_role = origin');
const count = async () => Object.fromEntries(await Promise.all((await db.query(`select tablename t from pg_tables where schemaname = 'public'`)).rows.map(async (x) => [x.t, Number((await db.query(`select count(*)::int n from public."${x.t}"`)).rows[0].n)])));
// FIDELITE RLS : la base reconstruite par les migrations du depot peut differer de la production (noms de politiques ASCII, definitions anterieures) ; on remplace donc TOUTES les
// politiques de public/storage par celles de la sauvegarde (pg_policies de la production), puis on applique les migrations en attente sur ce schema fidele.
const prodPolicies = readJson(`prod_structure_complete_${suffix}.json`).rows[0].s.policies;
for (const p of (await db.query(`select schemaname s, tablename t, policyname n from pg_policies where schemaname in ('public','storage')`)).rows) await db.exec(`drop policy "${p.n.replace(/"/g, '""')}" on ${p.s}."${p.t}"`);
let polFail = 0;
for (const p of prodPolicies) {
  const roles = (Array.isArray(p.roles) ? p.roles : String(p.roles).replace(/[{}]/g, '').split(',')).filter(Boolean).join(', ') || 'public';
  const sql = `create policy "${p.policyname.replace(/"/g, '""')}" on ${p.schemaname}."${p.tablename}" as ${p.permissive === 'RESTRICTIVE' ? 'restrictive' : 'permissive'} for ${p.cmd.toLowerCase()} to ${roles}${p.qual ? ` using (${p.qual})` : ''}${p.with_check ? ` with check (${p.with_check})` : ''}`;
  try { await db.exec(sql); } catch (e) { polFail++; if (polFail <= 3) console.log('ECHEC politique', p.tablename, p.policyname, String(e.message).split('\n')[0]); }
}
console.log(`politiques de production recreees : ${prodPolicies.length - polFail}/${prodPolicies.length}`);
if (polFail) ko++;
const before = await count();
console.log(`donnees de production chargees : ${Object.values(before).reduce((a, b) => a + b, 0)} lignes`);

let t0 = Date.now(); let okp = 0;
for (const f of pending) {
  try { await db.exec(fs.readFileSync(path.join(repo, 'migrations', f), 'utf8')); okp++; } catch (e) { ko++; console.log('ECHEC migration', f, '-', String(e.message).split('\n')[0]); }
}
console.log(`migrations en attente appliquees sur la copie : ${okp}/${pending.length} en ${Math.round((Date.now() - t0) / 1000)} s`);
const after = await count();
const lost = Object.entries(before).filter(([t, c]) => (after[t] ?? 0) < c).map(([t, c]) => `${t}: ${c} -> ${after[t] ?? 'absente'}`);
const changed = Object.entries(before).filter(([t, c]) => (after[t] ?? 0) !== c).map(([t, c]) => `${t}: ${c} -> ${after[t]}`);
console.log(lost.length ? 'LIGNES PERDUES : ' + lost.join(' | ') : 'OK aucune ligne supprimee dans les tables existantes');
console.log(changed.length ? 'Tables dont le nombre de lignes change : ' + changed.join(' | ') : 'OK aucune table existante ne change de nombre de lignes');
const noRls = (await db.query(`select c.relname n from pg_class c join pg_namespace s on s.oid = c.relnamespace where s.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity`)).rows.map((x) => x.n);
// controles de l'alignement des politiques (migration 20261129900000) : plus aucune politique de borne heritee, definitions alignees
const pols = (await db.query(`select tablename t, policyname n, qual q, with_check w from pg_policies where schemaname = 'public'`)).rows;
const kiosk = pols.filter((p) => p.t === 'kiosk_sessions' && /connect/.test(p.n)).length;
const listingsPol = pols.find((p) => p.t === 'listings' && /annonces appro/.test(p.n));
const profilesPol = pols.find((p) => p.t === 'profiles' && /profil cr.. . l.inscription|profil cree a l inscription/.test(p.n));
const asciiLeft = pols.filter((p) => /^(profil cree a l inscription|annonces approuvees visibles par tous|journal lisible par l administration|equipes visibles par tous|un etudiant cree son equipe|un vendeur cree ses annonces|commandes de l acheteur ou de l administration|profil visible par soi et l administration|sessions borne (lisibles|creees) par les connectes)$/.test(p.n)).map((p) => p.n);
const alignOk = kiosk === 0 && asciiLeft.length === 0 && listingsPol && /_dept_sees/.test(listingsPol.q) && profilesPol && !/other/.test(profilesPol.w);
console.log(alignOk ? 'OK alignement des politiques : kiosk_sessions ferme, listings cloisonnee par departement, inscription sans role other, noms du depot' : `ECHEC alignement des politiques : kiosk=${kiosk} ascii=${asciiLeft.join('|')} listings=${listingsPol ? /_dept_sees/.test(listingsPol.q) : 'absente'} profiles=${profilesPol ? !/other/.test(profilesPol.w) : 'absente'}`);
if (!alignOk) ko++;
console.log(noRls.length ? 'TABLES SANS RLS : ' + noRls.join(', ') : 'OK toutes les tables public ont la RLS');
const seeded = (await db.query(`select (select count(*) from talent_score_rules where active)::int a, (select count(*) from ranking_periods)::int p, (select count(*) from ranking_entries)::int e, (select count(*) from programs)::int g`)).rows[0];
console.log(`etat apres migration : regles de score actives ${seeded.a}, periodes ${seeded.p}, entrees de classement ${seeded.e}, filieres ${seeded.g}`);
console.log(`rehearse_migrations : ${ko} echec(s)`);
process.exit(ko || lost.length || noRls.length || seeded.a || seeded.p || seeded.e ? 1 : 0);
