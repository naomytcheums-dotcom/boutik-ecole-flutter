-- Webhook Notch Pay : journal des événements reçus (anti-rejeu) — à exécuter dans l'éditeur SQL Supabase.
create table if not exists payment_events (
  id text primary key,                       -- SHA-256 du corps brut signé : un même événement n'est traité qu'une fois
  event_type text not null,
  reference text not null,
  outcome text,
  received_at timestamptz not null default now()
);
alter table payment_events enable row level security;   -- aucune politique : seul le rôle service (Edge Function) y accède
revoke all on payment_events from anon, authenticated;

select (select count(*) from pg_tables where tablename = 'payment_events') as table_creee,
       (select count(*) from pg_policies where tablename = 'payment_events') as politiques;
