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
const pending = all.filter((f) => !applied.has(f.split('_')[0]));
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
console.log(noRls.length ? 'TABLES SANS RLS : ' + noRls.join(', ') : 'OK toutes les tables public ont la RLS');
const seeded = (await db.query(`select (select count(*) from talent_score_rules where active)::int a, (select count(*) from ranking_periods)::int p, (select count(*) from ranking_entries)::int e, (select count(*) from programs)::int g`)).rows[0];
console.log(`etat apres migration : regles de score actives ${seeded.a}, periodes ${seeded.p}, entrees de classement ${seeded.e}, filieres ${seeded.g}`);
console.log(`rehearse_migrations : ${ko} echec(s)`);
process.exit(ko || lost.length || noRls.length || seeded.a || seeded.p || seeded.e ? 1 : 0);
