// Concurrence RÉELLE du stock H12 sur un PostgreSQL local (plusieurs connexions simultanées ; PGlite est mono-connexion).
// Cluster temporaire, jamais la production : aucun appel réseau hors 127.0.0.1.
//   initdb -D <dir> -U postgres --auth=trust ; pg_ctl -D <dir> -o "-p 54329" start
//   PG_MODULE_DIR=<dossier contenant node_modules/pg> PGPORT=54329 node h12_stock_concurrence.mjs
// Cas : 20 commandes simultanées sur 5 exemplaires (variante, puis annonce sans variante) => 5 acceptées, 15 refusées, stock 0 ;
// paniers à deux variantes dans des ordres opposés (pas d'interblocage) ; deux annulations simultanées de la même commande (stock restitué une seule fois).
// H13 : variante à prix propre sous 20 acheteurs ; même clé d'idempotence envoyée 10 fois en même temps ; réservation expirée traitée en parallèle (expiration + annulation) puis nouvelle vague.
import fs from 'fs';
import path from 'path';
import { createRequire } from 'module';
import { fileURLToPath } from 'url';

const require = createRequire(path.join(process.env.PG_MODULE_DIR ?? process.cwd(), 'noop.js'));
const { Client } = require('pg');
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const port = Number(process.env.PGPORT ?? 54329);
const conn = (database) => new Client({ host: '127.0.0.1', port, user: 'postgres', database });

let ok = 0, ko = 0;
const check = (name, cond, extra = '') => { if (cond) { ok++; console.log('OK', name); } else { ko++; console.log('ECHEC', name, extra); } };

const stub = `
create extension if not exists pgcrypto;
do $$ begin
  create role anon nologin; create role authenticated nologin; create role service_role nologin; create role supabase_admin nologin;
exception when others then null; end $$;
create schema if not exists auth; create schema if not exists storage; create schema if not exists extensions;
create table if not exists auth.users (id uuid primary key, email text, raw_user_meta_data jsonb default '{}', banned_until timestamptz, encrypted_password text, created_at timestamptz default now());
create table if not exists auth.sessions (id uuid default gen_random_uuid() primary key, user_id uuid, created_at timestamptz default now());
create table if not exists auth.refresh_tokens (id bigserial primary key, user_id text, session_id uuid);
create table if not exists auth.mfa_factors (id uuid default gen_random_uuid() primary key, user_id uuid, status text);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create or replace function auth.role() returns text language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon') $$;
create or replace function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
create table if not exists storage.buckets (id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[], owner uuid, created_at timestamptz default now(), updated_at timestamptz default now());
create table if not exists storage.objects (id uuid default gen_random_uuid() primary key, bucket_id text, name text, owner uuid, owner_id text, metadata jsonb, created_at timestamptz default now());
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[] language sql as $$ select string_to_array(name, '/') $$;
grant usage on schema public, auth, storage to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all functions in schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;
`;

const dbName = 'h12_conc';
const admin = conn('postgres');
await admin.connect();
await admin.query(`drop database if exists ${dbName} with (force)`);
await admin.query(`create database ${dbName}`);
await admin.end();

const sup = conn(dbName);
await sup.connect();
await sup.query(stub);
const files = ['schema.sql', ...fs.readdirSync(path.join(repo, 'migrations')).filter((f) => f.endsWith('.sql')).sort().map((f) => 'migrations/' + f)];
let applied = 0;
for (const f of files) {
  try { await sup.query(fs.readFileSync(path.join(repo, f), 'utf8')); applied++; } catch (e) { console.log('ECHEC migration', f, '-', String(e.message).split('\n')[0]); }
}
console.log(`migrations appliquées : ${applied}/${files.length}`);
check('migrations H12 stock appliquées sur PostgreSQL', (await sup.query(`select to_regclass('public.listing_variants') t`)).rows[0].t !== null);

const U = (n) => `00000000-0000-0000-0000-0000000121${String(n).padStart(2, '0')}`;
const seller = U(1);
await sup.query(`insert into auth.users(id,email) values ('${seller}','h12c1@t.cm'); insert into profiles(id,name,role,email) values ('${seller}','Vendeur H12C','student','h12c1@t.cm')`);
await sup.query(`update profiles set phone = '691210001', phone_verified = true where id = '${seller}'`);
await sup.query(`insert into user_documents (owner_id, kind, name, path, mime, size_bytes, status) values ('${seller}', 'student_card', 'c.pdf', '${seller}/c/c.pdf', 'application/pdf', 10, 'verified'); update profiles set certification = 'approved' where id = '${seller}'`);
const BUYERS = 20;
for (let n = 10; n < 10 + BUYERS; n++) {
  await sup.query(`insert into auth.users(id,email) values ('${U(n)}','h12cb${n}@t.cm'); insert into profiles(id,name,role,email) values ('${U(n)}','Acheteur H12C ${n}','client','h12cb${n}@t.cm')`);
  await sup.query(`update profiles set phone = '6912' || lpad('${n}', 5, '0'), phone_verified = true where id = '${U(n)}'`);
}
const mk = async (title, stock) => (await sup.query(`insert into listings (seller_id, title, department, category, price, stock, status, images) values ('${seller}', '${title}', 'Design', 'Maison', 8000, ${stock}, 'approved', '{photo.jpg}') returning id`)).rows[0].id;
const as = async (uid) => { const c = conn(dbName); await c.connect(); await c.query(`select set_config('request.jwt.claim.sub', '${uid}', false); set role authenticated`); return c; };
const lStock = async (id) => Number((await sup.query(`select stock from listings where id = '${id}'`)).rows[0].stock);
const vStock = async (id) => Number((await sup.query(`select stock from listing_variants where id = '${id}'`)).rows[0].stock);

// Lance toutes les commandes en même temps (une connexion par acheteur) puis classe les résultats.
async function rush(carts) {
  const clients = [];
  for (let i = 0; i < carts.length; i++) clients.push(await as(U(10 + i)));
  let go; const gate = new Promise((r) => { go = r; });
  const runs = clients.map((c, i) => gate.then(async () => {
    try {
      const r = await c.query(`select marketplace_checkout($1::jsonb, false, 'Mobile Money', null, null, $2) r`, [JSON.stringify(carts[i]), `conc-key-${Date.now()}-${i}`]);
      return { ok: true, r: r.rows[0].r };
    } catch (e) { return { ok: false, code: e.code, message: e.message }; }
  }));
  go();
  const res = await Promise.all(runs);
  await Promise.all(clients.map((c) => c.end()));
  return res;
}
const clean = async () => { await sup.query(`delete from order_lines; delete from orders`); };

let sv;
try {
  sv = await as(seller);
  // ---------------------------------------------------------------- 1. 20 acheteurs, 5 exemplaires d'une variante 20 acheteurs, 5 exemplaires d'une variante
  const LA = await mk('Tee-shirt concurrence', 50);
  const vA = (await sv.query(`select variant_save('${LA}', 'M', '{}'::jsonb, null, 5, 1) r`)).rows[0].r.id;
  const res1 = await rush(Array.from({ length: BUYERS }, () => [{ id: LA, qty: 1, variant_id: vA }]));
  const won1 = res1.filter((x) => x.ok), lost1 = res1.filter((x) => !x.ok);
  check(`variante : ${BUYERS} commandes simultanées sur 5 exemplaires => 5 acceptées`, won1.length === 5, `${won1.length}`);
  check('variante : 15 refusées', lost1.length === BUYERS - 5, `${lost1.length}`);
  check('variante : tous les refus sont « variant_out_of_stock » (aucun autre échec)', lost1.every((x) => /variant_out_of_stock/.test(x.message)), JSON.stringify(lost1.filter((x) => !/variant_out_of_stock/.test(x.message)).slice(0, 2)));
  check('variante : stock de la variante = 0 (jamais négatif)', (await vStock(vA)) === 0);
  check('variante : stock de l\'annonce (somme des variantes) = 0', (await lStock(LA)) === 0);
  check('variante : exactement 5 lignes de commande pour la variante', Number((await sup.query(`select coalesce(sum(qty),0) s from order_lines where variant_id = '${vA}'`)).rows[0].s) === 5);
  check('variante : 5 acheteurs distincts servis', new Set(won1.map((x) => x.r.number)).size === 5);
  await clean();

  // ---------------------------------------------------------------- 2. annonce sans variante : même règle
  const LN = await mk('Cahier concurrence', 5);
  const res2 = await rush(Array.from({ length: BUYERS }, () => [{ id: LN, qty: 1 }]));
  const won2 = res2.filter((x) => x.ok), lost2 = res2.filter((x) => !x.ok);
  check('sans variante : 20 commandes simultanées sur 5 exemplaires => 5 acceptées', won2.length === 5, `${won2.length}`);
  check('sans variante : 15 refusées « Stock insuffisant »', lost2.length === BUYERS - 5 && lost2.every((x) => /Stock insuffisant/.test(x.message)), JSON.stringify(lost2.slice(0, 2)));
  check('sans variante : stock = 0 (jamais négatif)', (await lStock(LN)) === 0);
  await clean();

  // ---------------------------------------------------------------- 3. paniers à deux variantes dans des ordres opposés : pas d'interblocage
  const LP = await mk('Pull concurrence', 50);
  const p1 = (await sv.query(`select variant_save('${LP}', 'P1', '{}'::jsonb, null, 5, 1) r`)).rows[0].r.id;
  const p2 = (await sv.query(`select variant_save('${LP}', 'P2', '{}'::jsonb, null, 5, 1) r`)).rows[0].r.id;
  const a = { id: LP, qty: 1, variant_id: p1 }, b = { id: LP, qty: 1, variant_id: p2 };
  const res3 = await rush(Array.from({ length: BUYERS }, (_, i) => (i % 2 ? [a, b] : [b, a])));
  const won3 = res3.filter((x) => x.ok);
  check('paniers croisés : aucun interblocage (40P01) ni erreur de sérialisation', res3.every((x) => x.ok || !['40P01', '40001'].includes(x.code)), JSON.stringify(res3.filter((x) => !x.ok).slice(0, 2)));
  check('paniers croisés : 5 acceptés (chaque panier prend 1 P1 + 1 P2)', won3.length === 5, `${won3.length}`);
  check('paniers croisés : P1 = 0 et P2 = 0, jamais négatifs', (await vStock(p1)) === 0 && (await vStock(p2)) === 0);
  check('paniers croisés : refus de stock nets (pas de commande partielle)', Number((await sup.query(`select count(*) c from orders`)).rows[0].c) === 5);
  await clean();

  // ---------------------------------------------------------------- 4. deux annulations simultanées : stock restitué une seule fois
  const LC = await mk('Casquette concurrence', 50);
  const vC = (await sv.query(`select variant_save('${LC}', 'Unique', '{}'::jsonb, null, 4, 1) r`)).rows[0].r.id;
  const buyer = await as(U(10));
  const num = (await buyer.query(`select marketplace_checkout($1::jsonb, false, 'Mobile Money', null, null, 'conc-cancel-key-1') r`, [JSON.stringify([{ id: LC, qty: 3, variant_id: vC }])])).rows[0].r.number;
  check('annulation : commande de 3 sur 4 => stock 1', (await vStock(vC)) === 1);
  const c1 = await as(U(10)), c2 = await as(U(10));
  const settled = await Promise.allSettled([c1.query(`select cancel_order('${num}') r`), c2.query(`select cancel_order('${num}') r`)]);
  await Promise.all([buyer.end(), c1.end(), c2.end()]);
  check('annulation : au moins une annulation aboutit', settled.some((s) => s.status === 'fulfilled'), JSON.stringify(settled.map((s) => s.status)));
  check('annulation : stock restitué UNE seule fois (4, jamais 7)', (await vStock(vC)) === 4, `${await vStock(vC)}`);
  check('annulation : stock de l\'annonce cohérent (4)', (await lStock(LC)) === 4);
  await clean();

  // ---------------------------------------------------------------- 5. H13 : variante à prix propre, 20 acheteurs simultanés sur 5 exemplaires
  const LV = await mk('Veste prix variante', 50);
  const vV = (await sv.query(`select variant_save('${LV}', 'Premium', '{}'::jsonb, null, 5, 1) r`)).rows[0].r.id;
  await sv.query(`select variant_details_save('${vV}', 9500)`);
  const res5 = await rush(Array.from({ length: BUYERS }, () => [{ id: LV, qty: 1, variant_id: vV }]));
  const won5 = res5.filter((x) => x.ok);
  check('prix de variante : 5 commandes acceptées sur 5 exemplaires, toutes à 9500 (jamais le prix de l\'annonce 8000)', won5.length === 5 && won5.every((x) => x.r.subtotal === 9500), JSON.stringify(won5.map((x) => x.r.subtotal)));
  check('prix de variante : les lignes enregistrées portent 9500', Number((await sup.query(`select count(*) c from order_lines where variant_id = '${vV}' and unit_price = 9500`)).rows[0].c) === 5);
  check('prix de variante : 15 refusés pour stock, stock 0', res5.filter((x) => !x.ok).every((x) => /variant_out_of_stock/.test(x.message)) && (await vStock(vV)) === 0);
  await clean();

  // ---------------------------------------------------------------- 6. H13 : même clé d'idempotence envoyée 10 fois en même temps => une seule commande
  const LK = await mk('Sac double clic', 50);
  const vK = (await sv.query(`select variant_save('${LK}', 'Unique', '{}'::jsonb, null, 20, 1) r`)).rows[0].r.id;
  const dbl = await Promise.all(Array.from({ length: 10 }, async () => {
    const c = await as(U(10));
    try { const r = await c.query(`select marketplace_checkout($1::jsonb, false, 'Mobile Money', null, null, 'conc-double-clic-1') r`, [JSON.stringify([{ id: LK, qty: 2, variant_id: vK }])]); return { ok: true, r: r.rows[0].r }; }
    catch (e) { return { ok: false, message: e.message, code: e.code }; } finally { await c.end(); }
  }));
  check('double clic simultané : aucune erreur brute (clé en double)', dbl.every((x) => x.ok), JSON.stringify(dbl.filter((x) => !x.ok).slice(0, 2)));
  check('double clic simultané : un seul numéro de commande pour les 10 envois', new Set(dbl.filter((x) => x.ok).map((x) => x.r.number)).size === 1);
  check('double clic simultané : une seule commande, stock décrémenté une seule fois (18)', Number((await sup.query(`select count(*) c from orders where idem_key = 'conc-double-clic-1'`)).rows[0].c) === 1 && (await vStock(vK)) === 18, `${await vStock(vK)}`);
  await clean();

  // ---------------------------------------------------------------- 7. H13 : réservation expirée traitée en parallèle (expiration planifiée + annulation de l'acheteur) puis nouvelle vague d'acheteurs
  const LE = await mk('Écharpe réservation', 50);
  const vE = (await sv.query(`select variant_save('${LE}', 'Unique', '{}'::jsonb, null, 5, 1) r`)).rows[0].r.id;
  const buyerE = await as(U(10));
  const numE = (await buyerE.query(`select marketplace_checkout($1::jsonb, false, 'Mobile Money', null, null, 'conc-expire-key-1') r`, [JSON.stringify([{ id: LE, qty: 5, variant_id: vE }])])).rows[0].r.number;
  check('réservation : 5 exemplaires retenus par une commande impayée => stock 0', (await vStock(vE)) === 0);
  const blocked = await rush([[{ id: LE, qty: 1, variant_id: vE }]]);
  check('réservation : un autre acheteur est refusé tant que la réservation court', !blocked[0].ok && /variant_out_of_stock/.test(blocked[0].message));
  await sup.query(`update orders set created_at = now() - interval '3 hours' where number = '${numE}'`);
  const x1 = conn(dbName), x2 = conn(dbName), cb = await as(U(10));
  await x1.connect(); await x2.connect();
  const exp = await Promise.allSettled([x1.query('select expire_unpaid_orders() n'), x2.query('select expire_unpaid_orders() n'), cb.query(`select cancel_order('${numE}') r`)]);
  await Promise.all([x1.end(), x2.end(), cb.end(), buyerE.end()]);
  check('réservation expirée : au moins un traitement aboutit', exp.some((s) => s.status === 'fulfilled'), JSON.stringify(exp.map((s) => s.status === 'rejected' ? s.reason.message : s.status)));
  check('réservation expirée : stock restitué UNE seule fois (5, jamais 10)', (await vStock(vE)) === 5, `${await vStock(vE)}`);
  const wave = await rush(Array.from({ length: 8 }, () => [{ id: LE, qty: 1, variant_id: vE }]));
  check('après expiration : 5 des 8 nouveaux acheteurs servis, stock 0', wave.filter((x) => x.ok).length === 5 && (await vStock(vE)) === 0, `${wave.filter((x) => x.ok).length}`);
  await clean();
} catch (e) {
  ko++; console.log('ERREUR', String(e.message).slice(0, 300));
} finally {
  await sv?.end();
  await sup.end();
}
console.log(`${ok} OK / ${ko} ECHEC`);
