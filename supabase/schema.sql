-- Boutik-École : schéma de base de données (Supabase / PostgreSQL)
-- À exécuter dans l'éditeur SQL du projet Supabase. Les règles d'accès (RLS) sont appliquées par le serveur.

create extension if not exists pgcrypto;

-- Rôles de la plateforme
create type app_role as enum ('visitor','client','student','company','other','dept','direction','finance','support','admin');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  phone text unique,
  email text unique,
  role app_role not null default 'client',
  city text default 'Douala',
  institution text default 'IUT de Douala',
  department text,
  birth date,
  suspended boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function current_role_name() returns app_role language sql stable security definer as $$
  select role from profiles where id = auth.uid()
$$;

create table listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references profiles(id),
  title text not null,
  department text not null,
  category text not null default 'Maison',
  price integer not null check (price >= 0),
  stock integer not null default 1,
  description text,
  image_url text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','removed')),
  reviewed_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  number text unique not null,
  buyer_id uuid not null references profiles(id),
  subtotal integer not null,
  fee integer not null default 0,
  method text not null,
  reference text,
  status smallint not null default 0 check (status between 0 and 3),
  paid boolean not null default false,
  cancelled boolean not null default false,
  created_at timestamptz not null default now()
);

create table order_lines (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  listing_id uuid references listings(id),
  title text not null,
  unit_price integer not null,
  qty integer not null default 1
);

create table favorites (
  user_id uuid not null references profiles(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  primary key (user_id, listing_id)
);

create table audit_log (
  id bigint generated always as identity primary key,
  actor text not null,
  action text not null,
  target text,
  category text,
  level text not null default 'Info',
  created_at timestamptz not null default now()
);

create table missions (
  id uuid primary key default gen_random_uuid(),
  number text unique not null,
  client_id uuid not null references profiles(id),
  kind text not null,
  description text not null,
  total integer not null,
  accepted boolean not null default false,
  funded smallint not null default 0,
  proof smallint not null default 0,
  released smallint not null default 0,
  created_at timestamptz not null default now()
);

create table hackathon_teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id),
  name text not null,
  theme text,
  rules_accepted boolean not null default false,
  created_at timestamptz not null default now()
);

create table kiosk_sessions (
  token text primary key,
  listing_id uuid references listings(id),
  created_at timestamptz not null default now(),
  used boolean not null default false
);

-- Sécurité : RLS activée partout
alter table profiles enable row level security;
alter table listings enable row level security;
alter table orders enable row level security;
alter table order_lines enable row level security;
alter table favorites enable row level security;
alter table audit_log enable row level security;
alter table missions enable row level security;
alter table hackathon_teams enable row level security;
alter table kiosk_sessions enable row level security;

create policy "profil visible par soi et l'administration" on profiles for select
  using (id = auth.uid() or current_role_name() in ('admin','direction','support'));
create policy "profil modifiable par soi" on profiles for update using (id = auth.uid());

create policy "annonces approuvées visibles par tous" on listings for select
  using (status = 'approved' or seller_id = auth.uid() or current_role_name() in ('dept','admin'));
create policy "un vendeur crée ses annonces" on listings for insert
  with check (seller_id = auth.uid() and current_role_name() in ('student','dept','admin'));
create policy "validation par le département" on listings for update
  using (seller_id = auth.uid() or current_role_name() in ('dept','admin'));

create policy "commandes de l'acheteur ou de l'administration" on orders for select
  using (buyer_id = auth.uid() or current_role_name() in ('admin','finance','support'));
create policy "un client passe sa commande" on orders for insert with check (buyer_id = auth.uid());
create policy "lignes visibles avec la commande" on order_lines for select
  using (exists (select 1 from orders o where o.id = order_id and (o.buyer_id = auth.uid() or current_role_name() in ('admin','finance','support'))));
create policy "lignes ajoutées par l'acheteur" on order_lines for insert
  with check (exists (select 1 from orders o where o.id = order_id and o.buyer_id = auth.uid()));

create policy "favoris personnels" on favorites for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "journal lisible par l'administration" on audit_log for select
  using (current_role_name() in ('admin','direction','support','finance'));
create policy "journal alimenté par les utilisateurs connectés" on audit_log for insert with check (auth.uid() is not null);

create policy "missions du client ou de l'administration" on missions for select
  using (client_id = auth.uid() or current_role_name() in ('admin','dept'));
create policy "un client crée sa mission" on missions for insert with check (client_id = auth.uid());
create policy "mise à jour des missions" on missions for update
  using (client_id = auth.uid() or current_role_name() in ('admin','dept','student'));

create policy "équipes visibles par tous" on hackathon_teams for select using (true);
create policy "un étudiant crée son équipe" on hackathon_teams for insert with check (owner_id = auth.uid());

create policy "sessions borne lisibles par tous" on kiosk_sessions for select using (true);
create policy "sessions borne créées par la borne" on kiosk_sessions for insert with check (true);
create policy "usage unique du code" on kiosk_sessions for update using (not used);
