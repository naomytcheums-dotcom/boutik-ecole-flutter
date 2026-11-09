import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import fs from 'fs';
import path from 'path';

import { fileURLToPath } from 'url';
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const db = new PGlite({ extensions: { pgcrypto } });
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
await db.exec(stub);
const files = ['schema.sql', ...fs.readdirSync(path.join(repo, 'migrations')).filter(f => f.endsWith('.sql')).sort().map(f => 'migrations/' + f)];
const only = process.argv[2]; // 'base' = sans la migration marketplace
let n = 0;
for (const f of files) {
  if (only === 'base' && f.includes('20261107000000')) continue;
  const sql = fs.readFileSync(path.join(repo, f), 'utf8');
  try { await db.exec(sql); n++; } catch (e) { console.log('ECHEC', f, '-', String(e.message).split('\n')[0]); if (f.includes('20261107')) { console.log(e.message); process.exit(1);} }
}
console.log('fichiers appliqués:', n, '/', files.length);
export { db };
if (process.argv[3]) { const m = await import(process.argv[3]); try { await m.run(db); } catch (e) { console.log("ERREUR", String(e.message).slice(0,300), "|", String(e.where||"").slice(0,200)); } }
