-- Profil étudiant : disponibilités (stage, stage de vacances, mission, job, bénévolat) et langues, visibles de tous les comptes connectés (entreprises comprises).
-- Le portfolio de réalisations existe déjà (portfolio_items, migration 20261110010000, lecture publique) : il n'est pas touché. L'étudiant choisit ce qu'il renseigne ; rien n'est inventé.
-- Retour arrière : drop function profile_extras_get(uuid), availability_save(jsonb), language_save(text, text), language_delete(text); drop table student_languages, student_availability.

create table if not exists student_availability (
  user_id uuid primary key references profiles(id) on delete cascade,
  kinds text[] not null default '{}' check (kinds <@ array['internship', 'vacation', 'mission', 'job', 'volunteer']::text[]),
  note text not null default '' check (char_length(note) <= 300),
  available_from date,
  updated_at timestamptz not null default now()
);
create table if not exists student_languages (
  user_id uuid not null references profiles(id) on delete cascade,
  language text not null check (char_length(btrim(language)) between 2 and 40),
  level text not null check (level in ('basic', 'intermediate', 'advanced', 'native')),
  primary key (user_id, language)
);
alter table student_availability enable row level security;
alter table student_languages enable row level security;
revoke all on student_availability, student_languages from anon, authenticated;

-- Disponibilités et langues d'une personne (les miennes par défaut). Lecture : tout compte connecté.
create or replace function profile_extras_get(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := coalesce(p_user, auth.uid());
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object('user_id', v, 'mine', v = auth.uid(),
    'availability', (select jsonb_build_object('kinds', to_jsonb(a.kinds), 'note', a.note, 'available_from', a.available_from) from student_availability a where a.user_id = v),
    'languages', coalesce((select jsonb_agg(jsonb_build_object('language', l.language, 'level', l.level) order by l.language) from student_languages l where l.user_id = v), '[]'::jsonb));
end $$;

create or replace function availability_save(p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare v_kinds text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select coalesce(array_agg(distinct x), '{}') into v_kinds from jsonb_array_elements_text(coalesce(p->'kinds', '[]'::jsonb)) x;
  if not (v_kinds <@ array['internship', 'vacation', 'mission', 'job', 'volunteer']::text[]) then raise exception 'Type de disponibilité inconnu'; end if;
  insert into student_availability (user_id, kinds, note, available_from, updated_at)
  values (auth.uid(), v_kinds, left(btrim(coalesce(p->>'note', '')), 300), nullif(p->>'available_from', '')::date, now())
  on conflict (user_id) do update set kinds = excluded.kinds, note = excluded.note, available_from = excluded.available_from, updated_at = now();
end $$;

create or replace function language_save(p_language text, p_level text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_language, ''))) < 2 then raise exception 'Indiquez la langue'; end if;
  if p_level not in ('basic', 'intermediate', 'advanced', 'native') then raise exception 'Niveau inconnu'; end if;
  if (select count(*) from student_languages where user_id = auth.uid()) >= 12 and not exists (select 1 from student_languages where user_id = auth.uid() and lower(language) = lower(btrim(p_language))) then raise exception 'Douze langues au plus'; end if;
  delete from student_languages where user_id = auth.uid() and lower(language) = lower(btrim(p_language));
  insert into student_languages (user_id, language, level) values (auth.uid(), initcap(btrim(p_language)), p_level);
end $$;

create or replace function language_delete(p_language text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from student_languages where user_id = auth.uid() and lower(language) = lower(btrim(p_language));
end $$;

revoke all on function profile_extras_get(uuid), availability_save(jsonb), language_save(text, text), language_delete(text) from public, anon;
grant execute on function profile_extras_get(uuid), availability_save(jsonb), language_save(text, text), language_delete(text) to authenticated;
