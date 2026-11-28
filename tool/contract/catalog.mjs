// Rejoue schema.sql + migrations dans PGlite (aucun reseau, aucune production) et exporte le catalogue
// des objets publics : fonctions (arguments, defauts, EXECUTE anon/authenticated), tables/vues
// (colonnes), cles etrangeres, buckets Storage, publication Realtime.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const STUB = `
create extension if not exists pgcrypto;
do $$ begin
  create role anon nologin; create role authenticated nologin; create role service_role nologin; create role supabase_admin nologin;
exception when others then null; end $$;
do $$ begin create publication supabase_realtime; exception when others then null; end $$;
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

async function loadPglite(supabaseDir) {
  const base = process.env.PGLITE_DIR || path.join(supabaseDir, 'tests', 'marketplace_pglite');
  const req = createRequire(pathToFileURL(path.join(base, 'x.js')));
  const { PGlite } = await import(pathToFileURL(req.resolve('@electric-sql/pglite')).href);
  const { pgcrypto } = await import(pathToFileURL(req.resolve('@electric-sql/pglite/contrib/pgcrypto')).href);
  return { PGlite, pgcrypto };
}

export async function buildCatalog(supabaseDir) {
  const { PGlite, pgcrypto } = await loadPglite(supabaseDir);
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(STUB);
  const files = ['schema.sql', ...fs.readdirSync(path.join(supabaseDir, 'migrations')).filter((f) => f.endsWith('.sql')).sort().map((f) => 'migrations/' + f)];
  const failed = [];
  let replayed = 0;
  for (const f of files) {
    try { await db.exec(fs.readFileSync(path.join(supabaseDir, f), 'utf8')); replayed++; } catch (e) { failed.push({ file: f, error: String(e.message).split('\n')[0] }); }
  }

  const fnRows = (await db.query(`
    select p.proname as name, p.oid::int as oid, p.pronargs as nargs, p.pronargdefaults as ndef, p.prokind as kind,
      coalesce(p.proargnames, '{}') as argnames, p.proargmodes as argmodes, p.proallargtypes::int[] as allargs, p.proargtypes::text as argtypes,
      has_function_privilege('anon', p.oid, 'EXECUTE') as anon, has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth,
      pg_get_function_identity_arguments(p.oid) as sig, p.prorettype::regtype::text as ret
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prokind in ('f','p')`)).rows;
  const functions = {};
  for (const r of fnRows) {
    const modes = r.argmodes || null;
    const inNames = [];
    const total = (r.argnames || []).length;
    const inCount = r.nargs;
    // arguments d'entree : modes i/b/v (ou tous si proargmodes est nul)
    let idx = 0;
    for (let i = 0; i < Math.max(total, inCount); i++) {
      const mode = modes ? modes[i] : 'i';
      if (mode === 'i' || mode === 'b' || mode === 'v') { inNames.push((r.argnames || [])[i] || `$${idx + 1}`); idx++; }
    }
    const names = inNames.slice(0, inCount);
    const required = names.slice(0, Math.max(0, names.length - r.ndef));
    (functions[r.name] ||= []).push({ names, required, anon: r.anon, auth: r.auth, sig: r.sig, ret: r.ret, kind: r.kind });
  }

  const colRows = (await db.query(`
    select c.relname as t, c.relkind as kind, a.attname as col
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
    where n.nspname = 'public' and c.relkind in ('r','v','m','p','f')`)).rows;
  const tables = {};
  for (const r of colRows) (tables[r.t] ||= { kind: r.kind, cols: [] }).cols.push(r.col);

  const fkRows = (await db.query(`
    select con.conname as name, c1.relname as src, c2.relname as dst,
      (select array_agg(a.attname) from unnest(con.conkey) k join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k) as cols
    from pg_constraint con join pg_class c1 on c1.oid = con.conrelid join pg_class c2 on c2.oid = con.confrelid
    join pg_namespace n on n.oid = c1.relnamespace where con.contype = 'f' and n.nspname = 'public'`)).rows;

  const buckets = (await db.query('select id, public from storage.buckets')).rows;
  let realtime = [];
  try { realtime = (await db.query(`select tablename from pg_publication_tables where pubname = 'supabase_realtime'`)).rows.map((r) => r.tablename); } catch { /* publication absente du banc */ }

  const edgeDir = path.join(supabaseDir, 'functions');
  const edge = fs.existsSync(edgeDir) ? fs.readdirSync(edgeDir, { withFileTypes: true }).filter((d) => d.isDirectory() && !d.name.startsWith('_') && !d.name.startsWith('.')).map((d) => d.name) : [];
  await db.close();
  return { replayed, total: files.length, failed, functions, tables, fks: fkRows, buckets, realtime, edge };
}
