-- Vivier de talents : une entreprise enregistre des étudiants dans des listes nommées (« Favoris » par défaut), avec une note privée.
-- Les listes et les notes ne sont visibles que de leur propriétaire ; l'étudiant n'est pas prévenu.
create table if not exists talent_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 40),
  created_at timestamptz not null default now(),
  unique (owner_id, name)
);
create table if not exists talent_list_members (
  list_id uuid not null references talent_lists(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  note text not null default '' check (char_length(note) <= 200),
  added_at timestamptz not null default now(),
  primary key (list_id, student_id)
);
create index if not exists talent_list_members_student on talent_list_members (student_id);
alter table talent_lists enable row level security;
alter table talent_list_members enable row level security;
revoke all on talent_lists, talent_list_members from anon, authenticated;

create or replace function _talent_guard() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('company', 'dept', 'admin') then raise exception 'Réservé aux entreprises'; end if;
end $$;
revoke all on function _talent_guard() from public, anon, authenticated;

-- Mes listes (la liste « Favoris » est créée au premier appel). Avec p_student : indique dans quelles listes il se trouve.
create or replace function talent_lists_get(p_student uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  insert into talent_lists (owner_id, name) values (auth.uid(), 'Favoris') on conflict do nothing;
  return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name,
      'count', (select count(*)::int from talent_list_members m where m.list_id = l.id),
      'has', case when p_student is null then null else exists (select 1 from talent_list_members m where m.list_id = l.id and m.student_id = p_student) end)
      order by (l.name = 'Favoris') desc, l.name)
    from talent_lists l where l.owner_id = auth.uid()), '[]'::jsonb);
end $$;

create or replace function talent_list_create(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text := btrim(coalesce(p_name, ''));
begin
  perform _talent_guard();
  if char_length(v_name) < 2 then raise exception 'Donnez un nom d''au moins 2 caractères'; end if;
  if (select count(*) from talent_lists where owner_id = auth.uid()) >= 20 then raise exception '20 listes au plus'; end if;
  if exists (select 1 from talent_lists where owner_id = auth.uid() and lower(name) = lower(v_name)) then raise exception 'Une liste porte déjà ce nom'; end if;
  insert into talent_lists (owner_id, name) values (auth.uid(), left(v_name, 40)) returning id into v_id;
  return v_id;
end $$;

create or replace function talent_list_delete(p_list uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  if exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid() and name = 'Favoris') then raise exception 'La liste Favoris ne peut pas être supprimée'; end if;
  delete from talent_lists where id = p_list and owner_id = auth.uid();
end $$;

create or replace function talent_list_add(p_list uuid, p_student uuid, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  if not exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid()) then raise exception 'Liste introuvable'; end if;
  if not exists (select 1 from profiles where id = p_student and role = 'student' and not suspended) then raise exception 'Étudiant introuvable'; end if;
  if (select count(*) from talent_list_members where list_id = p_list) >= 500 then raise exception '500 étudiants au plus par liste'; end if;
  insert into talent_list_members (list_id, student_id, note) values (p_list, p_student, left(btrim(coalesce(p_note, '')), 200))
  on conflict (list_id, student_id) do update set note = excluded.note;
end $$;

create or replace function talent_list_remove(p_list uuid, p_student uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  delete from talent_list_members m using talent_lists l where m.list_id = l.id and l.id = p_list and l.owner_id = auth.uid() and m.student_id = p_student;
end $$;

-- Étudiants d'une liste (identifiants et note) ; l'affichage du nom et de la filière vient du profil public.
create or replace function talent_list_members_get(p_list uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _talent_guard();
  if not exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid()) then raise exception 'Liste introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.student_id, 'name', display_name(m.student_id), 'department', pr.department, 'note', m.note, 'added_at', m.added_at) order by m.added_at desc)
                   from talent_list_members m join profiles pr on pr.id = m.student_id where m.list_id = p_list), '[]'::jsonb);
end $$;

revoke all on function talent_lists_get(uuid), talent_list_create(text), talent_list_delete(uuid), talent_list_add(uuid, uuid, text), talent_list_remove(uuid, uuid), talent_list_members_get(uuid) from public, anon;
grant execute on function talent_lists_get(uuid), talent_list_create(text), talent_list_delete(uuid), talent_list_add(uuid, uuid, text), talent_list_remove(uuid, uuid), talent_list_members_get(uuid) to authenticated;
