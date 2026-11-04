-- Référentiels établissements et départements, informations académiques du profil (matricule saisi par la personne),
-- documents de vérification (compartiment privé, historique de validation) et photo de profil (compartiment public).
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale isolée (supabase/tests/referentiels_documents_local.sql).
-- Non destructive : aucune ligne existante n'est modifiée ou supprimée. Retour arrière en fin de fichier.
--
-- Sources du référentiel : site officiel du MINESUP (rubrique « Institutions universitaires »). Seules les universités d'État
-- nommées par cette source sont inscrites comme « vérifiées ». Les institutions privées (IPES) ne sont PAS préchargées :
-- la liste officielle est un fichier PDF à importer par un administrateur (voir docs/transformation/REFERENTIEL_ETABLISSEMENTS.md) ;
-- en attendant, chaque personne peut proposer son établissement, qui est relu par l'équipe avant d'être publié.
-- Aucun département n'est préchargé : aucune liste officielle exploitable n'a été trouvée ; les départements sont proposés puis validés.

-- ------------------------------------------------------------------ profil : informations académiques
alter table profiles add column if not exists matricule text check (matricule is null or char_length(matricule) between 3 and 40);
alter table profiles add column if not exists institution_id uuid;
alter table profiles add column if not exists department_id uuid;
alter table profiles add column if not exists study_level text check (study_level is null or char_length(study_level) <= 40);
-- plus de valeur par défaut pour les NOUVEAUX profils (les lignes existantes ne sont pas touchées)
alter table profiles alter column institution drop default;
alter table profiles alter column city drop default;

-- ------------------------------------------------------------------ référentiels
create table if not exists institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 3 and 160),
  short_name text check (short_name is null or char_length(short_name) <= 40),
  kind text not null default 'autre' check (kind in ('universite_etat', 'institut', 'ecole', 'prive', 'autre')),
  city text check (city is null or char_length(city) <= 80),
  status text not null default 'proposed' check (status in ('verified', 'proposed', 'rejected')),
  source text,
  proposed_by uuid references profiles(id) on delete set null,
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists institutions_name_key on institutions (lower(name));

create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references institutions(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 120),
  status text not null default 'proposed' check (status in ('verified', 'proposed', 'rejected')),
  proposed_by uuid references profiles(id) on delete set null,
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists departments_name_key on departments (institution_id, lower(name));

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_institution_fk') then
    alter table profiles add constraint profiles_institution_fk foreign key (institution_id) references institutions(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_department_fk') then
    alter table profiles add constraint profiles_department_fk foreign key (department_id) references departments(id) on delete set null;
  end if;
end $$;

alter table institutions enable row level security;
alter table departments enable row level security;
revoke all on institutions, departments from anon, authenticated;
grant select on institutions, departments to anon, authenticated;
drop policy if exists "établissements : publiés ou proposés par soi" on institutions;
create policy "établissements : publiés ou proposés par soi" on institutions for select
  using (status = 'verified' or proposed_by = auth.uid() or is_platform_staff());
drop policy if exists "départements : publiés ou proposés par soi" on departments;
create policy "départements : publiés ou proposés par soi" on departments for select
  using (status = 'verified' or proposed_by = auth.uid() or is_platform_staff());

-- universités d'État nommées par le MINESUP (source citée) ; l'IUT de Douala est un institut rattaché à l'Université de Douala
insert into institutions (name, short_name, kind, city, status, source) values
  ('Université de Yaoundé I', 'UY1', 'universite_etat', 'Yaoundé', 'verified', 'MINESUP — universités d''État'),
  ('Université de Yaoundé II', 'UY2', 'universite_etat', 'Soa', 'verified', 'MINESUP — universités d''État'),
  ('Université de Douala', 'UDo', 'universite_etat', 'Douala', 'verified', 'MINESUP — universités d''État'),
  ('Université de Dschang', 'UDs', 'universite_etat', 'Dschang', 'verified', 'MINESUP — universités d''État'),
  ('Université de Buea', 'UB', 'universite_etat', 'Buea', 'verified', 'MINESUP — universités d''État'),
  ('Université de Bamenda', 'UBa', 'universite_etat', 'Bamenda', 'verified', 'MINESUP — universités d''État'),
  ('Université de Ngaoundéré', 'UN', 'universite_etat', 'Ngaoundéré', 'verified', 'MINESUP — universités d''État'),
  ('Université de Maroua', 'UMa', 'universite_etat', 'Maroua', 'verified', 'MINESUP — universités d''État'),
  ('Université de Bertoua', 'UBe', 'universite_etat', 'Bertoua', 'verified', 'MINESUP — universités d''État'),
  ('Université d''Ebolowa', 'UEb', 'universite_etat', 'Ebolowa', 'verified', 'MINESUP — universités d''État'),
  ('Institut universitaire de technologie de Douala', 'IUT de Douala', 'institut', 'Douala', 'verified', 'Établissement de l''Université de Douala')
on conflict (lower(name)) do nothing;

-- ------------------------------------------------------------------ fonctions : recherche, proposition, relecture
create or replace function institutions_search(p_query text default '', p_limit int default 40) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name, 'short_name', i.short_name, 'kind', i.kind, 'city', i.city, 'status', i.status) order by i.name), '[]'::jsonb)
  from (select * from institutions
        where (status = 'verified' or proposed_by = auth.uid())
          and (coalesce(trim(p_query), '') = '' or name ilike '%' || trim(p_query) || '%' or coalesce(short_name, '') ilike '%' || trim(p_query) || '%' or coalesce(city, '') ilike '%' || trim(p_query) || '%')
        order by name limit least(greatest(p_limit, 1), 100)) i;
$$;

create or replace function institution_propose(p_name text, p_city text default '', p_kind text default 'autre') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_name) < 3 or char_length(v_name) > 160 then raise exception 'Nom d''établissement invalide'; end if;
  if p_kind not in ('universite_etat', 'institut', 'ecole', 'prive', 'autre') then p_kind := 'autre'; end if;
  select id into v_id from institutions where lower(name) = lower(v_name);
  if v_id is not null then return v_id; end if;
  if (select count(*) from institutions where proposed_by = auth.uid() and status = 'proposed') >= 5 then raise exception 'Trop de propositions en attente'; end if;
  insert into institutions (name, kind, city, status, proposed_by, source) values (v_name, p_kind, nullif(left(trim(coalesce(p_city, '')), 80), ''), 'proposed', auth.uid(), 'Proposition d''un utilisateur') returning id into v_id;
  return v_id;
end $$;

create or replace function departments_list(p_institution uuid, p_query text default '') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name, 'status', d.status) order by d.name), '[]'::jsonb)
  from departments d
  where d.institution_id = p_institution and (d.status = 'verified' or d.proposed_by = auth.uid())
    and (coalesce(trim(p_query), '') = '' or d.name ilike '%' || trim(p_query) || '%');
$$;

create or replace function department_propose(p_institution uuid, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then raise exception 'Nom de département invalide'; end if;
  if not exists (select 1 from institutions where id = p_institution and (status = 'verified' or proposed_by = auth.uid())) then raise exception 'Établissement introuvable'; end if;
  select id into v_id from departments where institution_id = p_institution and lower(name) = lower(v_name);
  if v_id is not null then return v_id; end if;
  if (select count(*) from departments where proposed_by = auth.uid() and status = 'proposed') >= 10 then raise exception 'Trop de propositions en attente'; end if;
  insert into departments (institution_id, name, status, proposed_by) values (p_institution, v_name, 'proposed', auth.uid()) returning id into v_id;
  return v_id;
end $$;

-- relecture par l'équipe (admin ou support) : publication ou refus d'une proposition
create or replace function reference_review(p_kind text, p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_status text := case when p_approve then 'verified' else 'rejected' end;
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_kind = 'institution' then
    update institutions set status = v_status, reviewed_by = auth.uid(), reviewed_at = now() where id = p_id and status = 'proposed';
  elsif p_kind = 'department' then
    update departments set status = v_status, reviewed_by = auth.uid(), reviewed_at = now() where id = p_id and status = 'proposed';
  else
    raise exception 'Type inconnu';
  end if;
end $$;

-- informations académiques du profil : l'établissement et le département viennent du référentiel, le matricule est saisi
-- par la personne (jamais généré) ; vide tant qu'elle ne l'a pas renseigné
create or replace function profile_set_academic(p_institution uuid, p_department uuid, p_matricule text default null, p_level text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_inst institutions; v_dept departments; v_mat text := nullif(regexp_replace(trim(coalesce(p_matricule, '')), '\s+', '', 'g'), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_institution is not null then
    select * into v_inst from institutions where id = p_institution and (status = 'verified' or proposed_by = auth.uid());
    if v_inst.id is null then raise exception 'Établissement introuvable'; end if;
  end if;
  if p_department is not null then
    select * into v_dept from departments where id = p_department and (status = 'verified' or proposed_by = auth.uid());
    if v_dept.id is null or v_dept.institution_id is distinct from p_institution then raise exception 'Département introuvable pour cet établissement'; end if;
  end if;
  if v_mat is not null and (char_length(v_mat) < 3 or char_length(v_mat) > 40 or v_mat !~ '^[A-Za-z0-9/_.-]+$') then raise exception 'Matricule invalide'; end if;
  update profiles set
    institution_id = p_institution, institution = coalesce(v_inst.name, ''),
    department_id = p_department, department = coalesce(v_dept.name, ''),
    matricule = v_mat, study_level = nullif(left(trim(coalesce(p_level, '')), 40), '')
  where id = auth.uid();
end $$;

-- ------------------------------------------------------------------ documents de vérification (privés)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-documents', 'profile-documents', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create table if not exists user_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('student_card', 'enrollment_certificate', 'diploma', 'certificate', 'cv', 'other')),
  name text not null check (char_length(name) between 1 and 160),
  path text not null unique,
  mime text not null check (mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  size_bytes integer not null check (size_bytes between 1 and 10485760),
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
  review_note text,
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists user_documents_owner on user_documents (owner_id, created_at desc);

create table if not exists user_document_history (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references user_documents(id) on delete cascade,
  status text not null check (status in ('pending', 'verified', 'rejected', 'deleted')),
  note text,
  actor_id uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table user_documents enable row level security;
alter table user_document_history enable row level security;
revoke all on user_documents, user_document_history from anon, authenticated;
grant select on user_documents, user_document_history to authenticated;
drop policy if exists "documents : propriétaire ou équipe" on user_documents;
create policy "documents : propriétaire ou équipe" on user_documents for select using (owner_id = auth.uid() or is_platform_staff());
drop policy if exists "historique documents : propriétaire ou équipe" on user_document_history;
create policy "historique documents : propriétaire ou équipe" on user_document_history for select
  using (is_platform_staff() or exists (select 1 from user_documents d where d.id = document_id and d.owner_id = auth.uid()));

drop policy if exists "documents profil : lecture" on storage.objects;
create policy "documents profil : lecture" on storage.objects for select to authenticated
  using (bucket_id = 'profile-documents' and ((storage.foldername(name))[1] = auth.uid()::text or is_platform_staff()));
drop policy if exists "documents profil : dépôt dans son dossier" on storage.objects;
create policy "documents profil : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-documents' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "documents profil : suppression par le propriétaire" on storage.objects;
create policy "documents profil : suppression par le propriétaire" on storage.objects for delete to authenticated
  using (bucket_id = 'profile-documents' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function document_register(p_kind text, p_path text, p_name text, p_mime text, p_size int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if (storage.foldername(p_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'profile-documents' and name = p_path) then raise exception 'Fichier absent du stockage'; end if;
  if (select count(*) from user_documents where owner_id = auth.uid()) >= 30 then raise exception 'Trop de documents : supprimez-en avant d''en ajouter'; end if;
  insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values (auth.uid(), p_kind, left(p_name, 160), p_path, p_mime, p_size) returning id into v_id;
  insert into user_document_history (document_id, status, actor_id) values (v_id, 'pending', auth.uid());
  return v_id;
end $$;

-- suppression par le propriétaire (un document déjà vérifié ne peut plus être retiré) ; renvoie le chemin à retirer du stockage
create or replace function document_delete(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v user_documents;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into v from user_documents where id = p_id and owner_id = auth.uid();
  if v.id is null then raise exception 'Document introuvable'; end if;
  if v.status = 'verified' then raise exception 'Un document vérifié ne peut pas être supprimé'; end if;
  delete from user_documents where id = p_id;
  return v.path;
end $$;

create or replace function document_review(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_status not in ('verified', 'rejected') then raise exception 'Statut invalide'; end if;
  update user_documents set status = p_status, review_note = left(p_note, 500), reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  if not found then raise exception 'Document introuvable'; end if;
  insert into user_document_history (document_id, status, note, actor_id) values (p_id, p_status, left(p_note, 500), auth.uid());
end $$;

-- ------------------------------------------------------------------ photo de profil (publique : une photo de profil est visible par les autres)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "avatars : dépôt dans son dossier" on storage.objects;
create policy "avatars : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars : suppression par le propriétaire" on storage.objects;
create policy "avatars : suppression par le propriétaire" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create or replace function profile_set_avatar(p_path text, p_url text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_path is null or p_path = '' then
    update profiles set avatar_url = null where id = auth.uid();
    return;
  end if;
  if (storage.foldername(p_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'avatars' and name = p_path) then raise exception 'Fichier absent du stockage'; end if;
  if position(p_path in coalesce(p_url, '')) = 0 then raise exception 'Adresse de photo invalide'; end if;
  update profiles set avatar_url = p_url where id = auth.uid();
end $$;

-- ------------------------------------------------------------------ droits d'exécution
revoke all on function institutions_search(text, int), institution_propose(text, text, text), departments_list(uuid, text), department_propose(uuid, text),
  reference_review(text, uuid, boolean), profile_set_academic(uuid, uuid, text, text), document_register(text, text, text, text, int), document_delete(uuid),
  document_review(uuid, text, text), profile_set_avatar(text, text) from public, anon;
grant execute on function institutions_search(text, int), departments_list(uuid, text) to anon, authenticated;
grant execute on function institution_propose(text, text, text), department_propose(uuid, text), reference_review(text, uuid, boolean), profile_set_academic(uuid, uuid, text, text),
  document_register(text, text, text, text, int), document_delete(uuid), document_review(uuid, text, text), profile_set_avatar(text, text) to authenticated;

-- Retour arrière (aucune donnée de la plateforme n'est touchée ; ne supprime que ce que ce fichier crée) :
--   drop function institutions_search(text,int), institution_propose(text,text,text), departments_list(uuid,text), department_propose(uuid,text),
--     reference_review(text,uuid,boolean), profile_set_academic(uuid,uuid,text,text), document_register(text,text,text,text,int), document_delete(uuid),
--     document_review(uuid,text,text), profile_set_avatar(text,text);
--   drop table user_document_history, user_documents, departments, institutions;  -- après avoir retiré les contraintes profiles_institution_fk/profiles_department_fk
--   alter table profiles drop column matricule, drop column institution_id, drop column department_id, drop column study_level;
--   (les objets des compartiments profile-documents et avatars doivent être supprimés avant les compartiments eux-mêmes)
