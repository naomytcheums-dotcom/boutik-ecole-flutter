// Restauration de CONTROLE (environnement isole, aucune connexion reseau) d'une sauvegarde logique Boutik-Ecole.
//   node tool/backup/restore_drill.mjs <dossier_sauvegardes> <suffixe> <dossier_node_modules_pglite>
// Exemple : node tool/backup/restore_drill.mjs C:\Users\...\boutik_sauvegardes_prod 20261125_avant_h12 C:\tmp\fixroot5\node_modules
// Etapes : (1) integrite des fichiers (JSON valide, cles attendues) ; (2) base PGlite vierge reconstruite avec TOUTES les migrations ;
// (3) rechargement des donnees `public` de la sauvegarde ; (4) comparaison table par table (nombre de lignes) ; (5) comparaison des colonnes avec la structure sauvegardee ;
// (6) controle de coherence Auth (nombre de comptes) ; aucun secret n'est affiche.
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
import { fileURLToPath } from 'url';

const [dir, suffix, nm] = process.argv.slice(2);
if (!dir || !suffix || !nm) { console.log('usage: node restore_drill.mjs <dossier> <suffixe> <node_modules>'); process.exit(2); }
const require = createRequire(path.join(nm, '..', 'noop.js'));
const { PGlite } = await import('file:///' + require.resolve('@electric-sql/pglite').replace(/\\/g, '/'));
const { pgcrypto } = await import('file:///' + require.resolve('@electric-sql/pglite/contrib/pgcrypto').replace(/\\/g, '/'));
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', 'supabase');

let ok = 0, ko = 0;
const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };
const readJson = (f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8').replace(/^\uFEFF/, ''));

// 1. integrite
const data = readJson(`prod_donnees_public_${suffix}.json`);
const struct = readJson(`prod_structure_complete_${suffix}.json`).rows[0].s;
const authMeta = readJson(`prod_auth_storage_metadonnees_${suffix}.json`);
check('1a donnees : fichier JSON valide avec des tables', Array.isArray(data.rows) && data.rows.length > 100, String(data.rows?.length));
check('1b structure : fonctions, politiques, declencheurs, colonnes, migrations presents', ['functions', 'policies', 'triggers', 'columns', 'migrations', 'rls'].every((k) => Array.isArray(struct[k]) && struct[k].length > 0));
check('1c auth/storage : comptes, identites, objets presents', ['users', 'identities', 'storage_objects'].every((k) => Array.isArray(authMeta[k])));
const storageDir = path.join(dir, `storage_${suffix}`);
if (fs.existsSync(storageDir)) {
  const files = fs.readdirSync(storageDir);
  const sizes = new Map(authMeta.storage_objects.map((o) => [`${o.bucket}__${o.name.replace(/[\\/:*?"<>|]/g, '_')}`, Number(o.size)]));
  const bad = files.filter((f) => !sizes.has(f) || fs.statSync(path.join(storageDir, f)).size !== sizes.get(f));
  check('1d storage : chaque fichier sauvegarde existe avec la taille enregistree', files.length === authMeta.storage_objects.length && bad.length === 0, bad.slice(0, 3).join(','));
}

// 2. base vierge reconstruite par les migrations
const db = new PGlite({ extensions: { pgcrypto } });
const stub = fs.readFileSync(path.join(repo, 'tests', 'marketplace_pglite', 'replay.mjs'), 'utf8').match(/const stub = `([\s\S]*?)`;/)[1];
await db.exec(stub);
const files = ['schema.sql', ...fs.readdirSync(path.join(repo, 'migrations')).filter((f) => f.endsWith('.sql')).sort().map((f) => 'migrations/' + f)];
let applied = 0;
for (const f of files) { try { await db.exec(fs.readFileSync(path.join(repo, f), 'utf8')); applied++; } catch (e) { console.log('ECHEC migration', f, String(e.message).split('\n')[0]); } }
check('2 base vierge : toutes les migrations appliquees', applied === files.length, `${applied}/${files.length}`);

// 3. rechargement (declencheurs et cles etrangeres neutralises, comme pg_restore --disable-triggers)
await db.exec('set session_replication_role = replica');
// une restauration part d'une base VIDE : on retire les lignes d'amorcage laissees par les migrations (aucune donnee de production n'est concernee)
const allTables = (await db.query(`select tablename t from pg_tables where schemaname = 'public'`)).rows.map((x) => x.t);
for (const t of allTables) await db.exec(`truncate table public."${t}" cascade`);
// DERIVE CONNUE : la production n'a pas l'index `profiles_phone_verified_uk` (migration 20261117990100) car deux profils verifies y partagent les 9 derniers chiffres d'un
// numero (comparaison d'index production/local du 25/11 : c'est la seule difference sur 664 index). On le retire pour refleter la production ; a traiter par l'administration (voir procedure de restauration).
await db.exec('drop index if exists public.profiles_phone_verified_uk');
let loaded = 0; const failed = [];
for (const { t, r } of data.rows) {
  if (!r.length) continue;
  try {
    await db.query(`insert into public."${t}" overriding system value select * from jsonb_populate_recordset(null::public."${t}", $1::jsonb)`, [JSON.stringify(r)]);
    loaded++;
  } catch (e) { failed.push(`${t}: ${String(e.message).split('\n')[0]}`); }
}
await db.exec('set session_replication_role = origin');
check('3 rechargement : toutes les tables non vides rechargees', failed.length === 0, failed.slice(0, 3).join(' | '));

// 4. comptage
const diff = [];
for (const { t, r } of data.rows) {
  const n = Number((await db.query(`select count(*)::int n from public."${t}"`)).rows[0].n);
  if (n !== r.length) diff.push(`${t}: ${n} != ${r.length}`);
}
check('4 comptage : meme nombre de lignes dans chaque table', diff.length === 0, diff.slice(0, 3).join(' | '));
console.log(`   ${data.rows.length} tables, ${data.rows.reduce((a, x) => a + x.r.length, 0)} lignes, ${loaded} tables non vides rechargees`);

// 5. colonnes : la reconstruction par les migrations contient toutes les colonnes de la production
const cols = (await db.query(`select table_name t, column_name c from information_schema.columns where table_schema = 'public'`)).rows;
const have = new Set(cols.map((x) => `${x.t}.${x.c}`));
const missing = struct.columns.filter((c) => !have.has(`${c.table}.${c.col}`)).map((c) => `${c.table}.${c.col}`);
check('5 structure : aucune colonne de production absente de la reconstruction', missing.length === 0, missing.slice(0, 5).join(','));

// 6. coherence Auth
const profilesN = Number((await db.query('select count(*)::int n from public.profiles')).rows[0].n);
check('6 auth : autant d\'identites que de comptes, au moins autant de comptes que de profils', authMeta.identities.length === authMeta.users.length && authMeta.users.length >= profilesN, `auth=${authMeta.users.length} profils=${profilesN}`);
console.log(`restore_drill : ${ok} OK, ${ko} ECHEC`);
process.exit(ko ? 1 : 0);
