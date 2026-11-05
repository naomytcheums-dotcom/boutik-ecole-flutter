-- Événements (écran 100 « Événements », 102 vitrine, 103 communauté…) : agenda de l'établissement, inscriptions des personnes connectées.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale isolée (supabase/tests/evenements_local.sql).
-- Retour arrière : drop function events_between(timestamptz, timestamptz, text), event_register(uuid), event_unregister(uuid), event_create(text, text, text, timestamptz, timestamptz, text, int, int);
--                   drop table event_registrations, events;

create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 140),
  description text check (description is null or char_length(description) <= 2000),
  kind text not null default 'autre' check (kind in ('exposition', 'atelier', 'conference', 'salon', 'autre')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  place text check (place is null or char_length(place) <= 140),
  price integer not null default 0 check (price >= 0),
  capacity integer check (capacity is null or capacity > 0),
  status text not null default 'published' check (status in ('draft', 'published', 'cancelled')),
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);
create index if not exists events_starts on events (starts_at);

create table if not exists event_registrations (
  event_id uuid not null references events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table events enable row level security;
alter table event_registrations enable row level security;
revoke all on events, event_registrations from anon, authenticated;
grant select on events to anon, authenticated;
grant select on event_registrations to authenticated;
drop policy if exists "événements : publiés pour tous" on events;
create policy "événements : publiés pour tous" on events for select using (status = 'published' or created_by = auth.uid() or is_platform_staff());
drop policy if exists "inscriptions : les miennes ou l'équipe" on event_registrations;
create policy "inscriptions : les miennes ou l'équipe" on event_registrations for select using (user_id = auth.uid() or is_platform_staff());

-- Liste d'une période, avec le nombre d'inscrits, les places restantes et l'inscription de la personne connectée.
create or replace function events_between(p_from timestamptz, p_to timestamptz, p_kind text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'title', e.title, 'description', coalesce(e.description, ''), 'kind', e.kind, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
      'place', coalesce(e.place, ''), 'price', e.price, 'capacity', e.capacity,
      'registered', (select count(*)::int from event_registrations r where r.event_id = e.id),
      'mine', exists (select 1 from event_registrations r where r.event_id = e.id and r.user_id = auth.uid())
    ) order by e.starts_at), '[]'::jsonb)
  from events e
  where e.status = 'published' and e.starts_at >= p_from and e.starts_at < p_to
    and (p_kind is null or p_kind = '' or e.kind = p_kind);
$$;

create or replace function event_register(p_event uuid) returns text
language plpgsql security definer set search_path = public as $$
declare e events; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from events where id = p_event and status = 'published';
  if e.id is null then raise exception 'Événement introuvable'; end if;
  if e.starts_at < now() then raise exception 'Événement terminé'; end if;
  if exists (select 1 from event_registrations where event_id = p_event and user_id = auth.uid()) then return 'already'; end if;
  select count(*) into n from event_registrations where event_id = p_event;
  if e.capacity is not null and n >= e.capacity then raise exception 'Plus de places'; end if;
  insert into event_registrations (event_id, user_id) values (p_event, auth.uid());
  return 'registered';
end $$;

create or replace function event_unregister(p_event uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from event_registrations where event_id = p_event and user_id = auth.uid();
end $$;

-- Création réservée à la gestion (responsable de département, direction, administrateur).
create or replace function event_create(p_title text, p_description text, p_kind text, p_starts timestamptz, p_ends timestamptz, p_place text, p_price int, p_capacity int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_kind not in ('exposition', 'atelier', 'conference', 'salon', 'autre') then p_kind := 'autre'; end if;
  insert into events (title, description, kind, starts_at, ends_at, place, price, capacity, created_by)
  values (trim(p_title), nullif(trim(coalesce(p_description, '')), ''), p_kind, p_starts, p_ends, nullif(trim(coalesce(p_place, '')), ''), greatest(coalesce(p_price, 0), 0), p_capacity, auth.uid())
  returning id into v_id;
  return v_id;
end $$;

revoke all on function events_between(timestamptz, timestamptz, text), event_register(uuid), event_unregister(uuid), event_create(text, text, text, timestamptz, timestamptz, text, int, int) from public, anon;
grant execute on function events_between(timestamptz, timestamptz, text) to anon, authenticated;
grant execute on function event_register(uuid), event_unregister(uuid), event_create(text, text, text, timestamptz, timestamptz, text, int, int) to authenticated;
