-- Encadrement et productions (écrans 113 Suivi des productions, 114 Mentors et encadreurs) : tables et fonctions réservées au personnel
-- (administrateur, direction, responsable de département ; lecture aussi pour le support). Aucune donnée n'est créée par la migration.
-- Testée sur la base locale (supabase/tests/encadrement_local.sql).
-- Retour arrière : drop function staff_mentors(), staff_productions(), mentor_create(text, text, text), production_create(text, text, uuid, date), production_update(uuid, int, text), _staff_check(boolean);
--                   drop table productions; drop table mentors;

create table if not exists mentors (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  role text not null default 'Mentor' check (role in ('Mentor', 'Encadreur')),
  specialty text not null default '' check (char_length(specialty) <= 120),
  active boolean not null default true,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists productions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 160),
  team text not null default '' check (char_length(team) <= 160),
  mentor_id uuid references mentors(id) on delete set null,
  progress smallint not null default 0 check (progress between 0 and 100),
  status text not null default 'en_cours' check (status in ('en_cours', 'terminee', 'annulee')),
  due_on date,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index if not exists productions_mentor on productions (mentor_id);
alter table mentors enable row level security;
alter table productions enable row level security;
revoke all on mentors, productions from anon, authenticated;

create or replace function _staff_check(p_write boolean) returns void
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_write and r not in ('admin', 'direction', 'dept') then raise exception 'Action non autorisée'; end if;
  if not p_write and r not in ('admin', 'direction', 'dept', 'support') then raise exception 'Action non autorisée'; end if;
end $$;
revoke all on function _staff_check(boolean) from public, anon, authenticated;

create or replace function staff_mentors() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _staff_check(false);
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'specialty', m.specialty, 'active', m.active,
    'productions', (select count(*)::int from productions p where p.mentor_id = m.id and p.status = 'en_cours')) order by m.created_at desc) from mentors m), '[]'::jsonb);
end $$;

-- « En retard » est calculé : en cours et échéance dépassée.
create or replace function staff_productions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _staff_check(false);
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'title', p.title, 'team', p.team, 'mentor', coalesce(m.name, ''), 'progress', p.progress,
    'status', case when p.status = 'en_cours' and p.due_on is not null and p.due_on < current_date then 'en_retard' else p.status end, 'due_on', p.due_on,
    'finished_at', p.finished_at) order by p.created_at desc)
    from productions p left join mentors m on m.id = p.mentor_id), '[]'::jsonb);
end $$;

create or replace function mentor_create(p_name text, p_role text, p_specialty text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  perform _staff_check(true);
  insert into mentors (name, role, specialty, created_by) values (trim(p_name), coalesce(nullif(p_role, ''), 'Mentor'), coalesce(trim(p_specialty), ''), auth.uid()) returning id into v;
  return v;
end $$;

create or replace function production_create(p_title text, p_team text, p_mentor uuid, p_due date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  perform _staff_check(true);
  insert into productions (title, team, mentor_id, due_on, created_by) values (trim(p_title), coalesce(trim(p_team), ''), p_mentor, p_due, auth.uid()) returning id into v;
  return v;
end $$;

create or replace function production_update(p_id uuid, p_progress int, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _staff_check(true);
  if p_status not in ('en_cours', 'terminee', 'annulee') then raise exception 'Statut invalide'; end if;
  update productions set progress = case when p_status = 'terminee' then 100 else least(greatest(p_progress, 0), 100) end, status = p_status,
    finished_at = case when p_status = 'terminee' then now() else null end where id = p_id;
  if not found then raise exception 'Production introuvable'; end if;
end $$;

revoke all on function staff_mentors(), staff_productions(), mentor_create(text, text, text), production_create(text, text, uuid, date), production_update(uuid, int, text) from public, anon;
grant execute on function staff_mentors(), staff_productions(), mentor_create(text, text, text), production_create(text, text, uuid, date), production_update(uuid, int, text) to authenticated;
