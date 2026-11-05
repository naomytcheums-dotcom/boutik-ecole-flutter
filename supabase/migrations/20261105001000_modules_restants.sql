-- Modules restants : réglages de la plateforme, contenus éditoriaux, duels de talents, lives (commentaires), retraits en borne (casiers),
-- radar des compétences, code de parrainage.
-- Aucune donnée n'est créée par la migration : tout est vide tant que personne n'a rien saisi. Écritures uniquement par fonctions serveur.
-- Testée sur la base locale (supabase/tests/modules_restants_local.sql).
-- Retour arrière : voir la fin du fichier.

-- ============================================================ 1. réglages de la plateforme (administrateur)
create table if not exists platform_settings (
  key text primary key check (key ~ '^[a-z0-9_.]{3,60}$'),
  value jsonb not null,
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table platform_settings enable row level security;
revoke all on platform_settings from anon, authenticated;

create or replace function settings_all() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'finance', 'support') then raise exception 'Action non autorisée'; end if;
  return coalesce((select jsonb_object_agg(key, value) from platform_settings), '{}'::jsonb);
end $$;

create or replace function setting_set(p_key text, p_value jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Action non autorisée'; end if;
  if p_key is null or p_key !~ '^[a-z0-9_.]{3,60}$' then raise exception 'Clé invalide'; end if;
  if p_value is null then raise exception 'Valeur invalide'; end if;
  insert into platform_settings (key, value, updated_by) values (p_key, p_value, auth.uid())
  on conflict (key) do update set value = excluded.value, updated_by = auth.uid(), updated_at = now();
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Réglage modifié', p_key, 'Réglages', 'Info');
end $$;

-- ============================================================ 2. contenus éditoriaux (pages, bannières, FAQ, modèles de notification)
create table if not exists cms_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('page', 'banner', 'faq', 'template')),
  title text not null check (char_length(title) between 2 and 160),
  body text not null default '' check (char_length(body) <= 8000),
  active boolean not null default true,
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table cms_items enable row level security;
revoke all on cms_items from anon, authenticated;
grant select on cms_items to anon, authenticated;
drop policy if exists "contenus : publics s'ils sont actifs, gestion" on cms_items;
create policy "contenus : publics s'ils sont actifs, gestion" on cms_items for select
  using (active or coalesce(current_role_name()::text, '') in ('admin', 'direction', 'support'));

create or replace function cms_save(p_id uuid, p_kind text, p_title text, p_body text, p_active boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction') then raise exception 'Action non autorisée'; end if;
  if p_id is null then
    insert into cms_items (kind, title, body, active, updated_by) values (p_kind, trim(p_title), coalesce(p_body, ''), coalesce(p_active, true), auth.uid()) returning id into v;
  else
    update cms_items set title = trim(p_title), body = coalesce(p_body, ''), active = coalesce(p_active, true), updated_by = auth.uid(), updated_at = now() where id = p_id returning id into v;
    if v is null then raise exception 'Contenu introuvable'; end if;
  end if;
  return v;
end $$;

create or replace function cms_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction') then raise exception 'Action non autorisée'; end if;
  delete from cms_items where id = p_id;
  if not found then raise exception 'Contenu introuvable'; end if;
end $$;

-- ============================================================ 3. duels de talents
create table if not exists duels (
  id uuid primary key default gen_random_uuid(),
  need_title text not null check (char_length(need_title) between 3 and 160),
  prize text not null default '' check (char_length(prize) <= 120),
  ends_at timestamptz not null,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists duel_entries (
  id uuid primary key default gen_random_uuid(),
  duel_id uuid not null references duels(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 160),
  created_at timestamptz not null default now(),
  unique (duel_id, author_id)
);
create table if not exists duel_votes (
  duel_id uuid not null references duels(id) on delete cascade,
  entry_id uuid not null references duel_entries(id) on delete cascade,
  voter_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (duel_id, voter_id)
);
alter table duels enable row level security;
alter table duel_entries enable row level security;
alter table duel_votes enable row level security;
revoke all on duels, duel_entries, duel_votes from anon, authenticated;

create or replace function duel_create(p_need text, p_prize text, p_hours int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'dept', 'company', 'client') then raise exception 'Action non autorisée'; end if;
  if p_hours is null or p_hours not between 1 and 336 then raise exception 'Durée invalide (1 à 336 heures)'; end if;
  insert into duels (need_title, prize, ends_at, created_by) values (trim(p_need), coalesce(trim(p_prize), ''), now() + make_interval(hours => p_hours), auth.uid()) returning id into v;
  return v;
end $$;

create or replace function duel_enter(p_duel uuid, p_title text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; d duels%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Réservé aux étudiants'; end if;
  select * into d from duels where id = p_duel;
  if not found or d.ends_at <= now() then raise exception 'Duel terminé ou introuvable'; end if;
  if d.created_by = auth.uid() then raise exception 'Action non autorisée'; end if;
  insert into duel_entries (duel_id, author_id, title) values (p_duel, auth.uid(), trim(p_title)) returning id into v;
  return v;
exception when unique_violation then raise exception 'Vous participez déjà à ce duel';
end $$;

create or replace function duel_vote(p_entry uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e duel_entries%rowtype; d duels%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from duel_entries where id = p_entry;
  if not found then raise exception 'Participation introuvable'; end if;
  select * into d from duels where id = e.duel_id;
  if d.ends_at <= now() then raise exception 'Duel terminé'; end if;
  if e.author_id = auth.uid() then raise exception 'Vous ne pouvez pas voter pour vous-même'; end if;
  insert into duel_votes (duel_id, entry_id, voter_id) values (e.duel_id, e.id, auth.uid());
exception when unique_violation then raise exception 'Vous avez déjà voté pour ce duel';
end $$;

-- Liste publique : duels, participations et votes ; le vainqueur n'est connu qu'à la fin.
create or replace function duels_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'need', d.need_title, 'prize', d.prize, 'ends_at', d.ends_at, 'open', d.ends_at > now(),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'author', coalesce(p.name, 'Étudiant'),
                  'votes', (select count(*)::int from duel_votes v where v.entry_id = e.id)) order by e.created_at)
                from duel_entries e left join profiles p on p.id = e.author_id where e.duel_id = d.id), '[]'::jsonb)
  ) order by d.created_at desc), '[]'::jsonb)
  from (select * from duels order by created_at desc limit 50) d;
$$;

-- ============================================================ 4. lives : états et commentaires
alter table scheduled_lives drop constraint if exists scheduled_lives_status_check;
alter table scheduled_lives add constraint scheduled_lives_status_check check (status in ('draft', 'scheduled', 'live', 'ended', 'cancelled'));
create table if not exists live_comments (
  id bigint generated always as identity primary key,
  live_id uuid not null references scheduled_lives(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 300),
  created_at timestamptz not null default now()
);
alter table live_comments enable row level security;
revoke all on live_comments from anon, authenticated;
grant select on live_comments to anon, authenticated;
drop policy if exists "commentaires de live : publics" on live_comments;
create policy "commentaires de live : publics" on live_comments for select using (true);
drop policy if exists "lives : programmés publics, brouillons à l'hôte" on scheduled_lives;
create policy "lives : programmés publics, brouillons à l'hôte" on scheduled_lives for select using (status in ('scheduled', 'live', 'ended') or host_id = auth.uid());

create or replace function live_set_state(p_id uuid, p_state text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_state not in ('live', 'ended', 'cancelled') then raise exception 'État invalide'; end if;
  update scheduled_lives set status = p_state where id = p_id and host_id = auth.uid() and status in ('scheduled', 'live');
  if not found then raise exception 'Live introuvable ou non modifiable'; end if;
end $$;

create or replace function live_comment(p_live uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare v bigint;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from scheduled_lives where id = p_live and status = 'live') then raise exception 'Ce live n''est pas en cours'; end if;
  insert into live_comments (live_id, user_id, body) values (p_live, auth.uid(), trim(p_body)) returning id into v;
  return v;
end $$;

-- ============================================================ 5. retraits en borne (casiers)
create table if not exists pickups (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  kiosk_id text not null references kiosks(id) on delete restrict,
  locker text not null check (char_length(locker) between 1 and 20),
  status text not null default 'ready' check (status in ('ready', 'collected')),
  ready_at timestamptz not null default now(),
  collected_at timestamptz,
  created_by uuid references profiles(id) on delete set null,
  unique (order_id)
);
alter table pickups enable row level security;
revoke all on pickups from anon, authenticated;
grant select on pickups to authenticated;
drop policy if exists "retraits : gestion ou acheteur" on pickups;
create policy "retraits : gestion ou acheteur" on pickups for select
  using (coalesce(current_role_name()::text, '') in ('admin', 'direction', 'dept', 'support')
         or exists (select 1 from orders o where o.id = order_id and o.buyer_id = auth.uid()));

create or replace function pickup_register(p_order text, p_kiosk text, p_locker text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') then raise exception 'Action non autorisée'; end if;
  select * into o from orders where number = p_order;
  if not found or not o.paid or o.cancelled_at is not null then raise exception 'Commande introuvable ou non payée'; end if;
  insert into pickups (order_id, kiosk_id, locker, created_by) values (o.id, p_kiosk, trim(p_locker), auth.uid()) returning id into v;
  insert into notifications (user_id, kind, title, body, data) values (o.buyer_id, 'order', 'Commande prête au retrait', 'Casier ' || trim(p_locker), jsonb_build_object('order', o.number));
  return v;
exception when unique_violation then raise exception 'Cette commande a déjà un casier';
end $$;

create or replace function pickup_collect(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') then raise exception 'Action non autorisée'; end if;
  update pickups set status = 'collected', collected_at = now() where id = p_id and status = 'ready';
  if not found then raise exception 'Retrait introuvable ou déjà remis'; end if;
end $$;

create or replace function pickups_list(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'dept', 'support') then raise exception 'Action non autorisée'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'order', o.number, 'kiosk', p.kiosk_id, 'locker', p.locker, 'status', p.status,
      'ready_at', p.ready_at, 'collected_at', p.collected_at, 'buyer', coalesce(b.name, 'Client')) order by p.ready_at desc)
    from (select * from pickups order by ready_at desc limit least(greatest(p_limit, 1), 300)) p
    join orders o on o.id = p.order_id left join profiles b on b.id = o.buyer_id), '[]'::jsonb);
end $$;

-- ============================================================ 6. code de parrainage et radar des compétences
create or replace function my_referral_code() returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return 'BE-' || upper(substr(md5(auth.uid()::text), 1, 6));
end $$;

create or replace function skills_radar() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'dept', 'support') then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object(
    'skills', coalesce((select jsonb_agg(jsonb_build_object('skill', s, 'count', c) order by c desc, s)
                        from (select lower(trim(x)) s, count(*)::int c from profiles, regexp_split_to_table(coalesce(skills, ''), '[,;\n]') x
                              where trim(x) <> '' group by 1 order by 2 desc, 1 limit 20) t), '[]'::jsonb),
    'open_needs', (select count(*)::int from missions where status = 'published'),
    'students', (select count(*)::int from profiles where role = 'student')
  );
end $$;

revoke all on function settings_all(), setting_set(text, jsonb), cms_save(uuid, text, text, text, boolean), cms_delete(uuid),
  duel_create(text, text, int), duel_enter(uuid, text), duel_vote(uuid), live_set_state(uuid, text), live_comment(uuid, text),
  pickup_register(text, text, text), pickup_collect(uuid), pickups_list(int), my_referral_code(), skills_radar() from public, anon;
grant execute on function settings_all(), setting_set(text, jsonb), cms_save(uuid, text, text, text, boolean), cms_delete(uuid),
  duel_create(text, text, int), duel_enter(uuid, text), duel_vote(uuid), live_set_state(uuid, text), live_comment(uuid, text),
  pickup_register(text, text, text), pickup_collect(uuid), pickups_list(int), my_referral_code(), skills_radar() to authenticated;
revoke all on function duels_list() from public;
grant execute on function duels_list() to anon, authenticated;

-- RETOUR ARRIÈRE :
-- drop function settings_all(), setting_set(text, jsonb), cms_save(uuid, text, text, text, boolean), cms_delete(uuid), duel_create(text, text, int), duel_enter(uuid, text),
--   duel_vote(uuid), duels_list(), live_set_state(uuid, text), live_comment(uuid, text), pickup_register(text, text, text), pickup_collect(uuid), pickups_list(int),
--   _streak(uuid), my_referral_code(), skills_radar();
-- drop table platform_settings, cms_items, duel_votes, duel_entries, duels, live_comments, pickups;
