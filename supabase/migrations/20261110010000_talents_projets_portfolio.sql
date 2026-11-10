-- Talent Passport (compétences par domaine et métier, portfolio) et fiche complète des projets / innovations.
-- Additif uniquement : aucune table existante n'est supprimée ni vidée. Aucune donnée d'utilisateur fictive : seul le catalogue de référence
-- (domaines, métiers, compétences) est fourni ; il est extensible par les utilisateurs (propositions visibles de leur auteur jusqu'à validation).
-- Retour arrière : voir la fin du fichier.

-- ============================================================ catalogue de référence : domaine > métier > compétence
create table if not exists skill_catalog (
  id uuid primary key default gen_random_uuid(),
  domain text not null check (char_length(domain) between 2 and 80),
  job text not null default '' check (char_length(job) <= 80),
  skill text not null default '' check (char_length(skill) <= 80),
  status text not null default 'approved' check (status in ('approved', 'proposed')),
  proposed_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (domain, job, skill)
);
alter table skill_catalog enable row level security;
revoke all on skill_catalog from anon, authenticated;
grant select on skill_catalog to anon, authenticated;
drop policy if exists "catalogue : validé, ou proposé par soi" on skill_catalog;
create policy "catalogue : validé, ou proposé par soi" on skill_catalog for select
  using (status = 'approved' or proposed_by = auth.uid() or is_platform_staff());

-- Entrées de référence (domaine seul, métier, compétences).
insert into skill_catalog (domain, job, skill)
select d, j, s from (values
  ('Génie civil', 'Ingénieur structures', array['Calcul de structures', 'Béton armé', 'Charpente métallique', 'Logiciels de calcul (Robot, SAP2000)', 'Résistance des matériaux']),
  ('Génie civil', 'Conducteur de travaux', array['Gestion de chantier', 'Planification (MS Project)', 'Lecture de plans', 'Hygiène et sécurité sur chantier', 'Métré et devis']),
  ('Génie civil', 'Topographe', array['Levé topographique', 'Implantation', 'Cartographie SIG', 'Utilisation de station totale', 'AutoCAD Covadis']),
  ('Génie civil', 'Dessinateur projeteur', array['AutoCAD', 'Revit', 'ArchiCAD', 'Plans d''exécution', 'Modélisation 3D']),
  ('Génie civil', 'Géotechnicien', array['Étude de sol', 'Fondations', 'Hydraulique et assainissement', 'Essais de laboratoire']),
  ('Informatique', 'Développeur web', array['HTML / CSS', 'JavaScript', 'PHP / Laravel', 'React', 'Node.js', 'Bases de données SQL']),
  ('Informatique', 'Développeur mobile', array['Flutter', 'Kotlin / Android', 'Swift / iOS', 'React Native', 'API REST']),
  ('Informatique', 'Réseaux et systèmes', array['Administration Linux', 'Réseaux Cisco', 'Cybersécurité', 'Virtualisation', 'Support utilisateurs']),
  ('Informatique', 'Données et IA', array['Python', 'Analyse de données', 'Apprentissage automatique', 'Tableaux de bord', 'Statistiques']),
  ('Design et communication', 'Graphiste', array['Identité visuelle', 'Logo', 'Photoshop', 'Illustrator', 'Mise en page']),
  ('Design et communication', 'Vidéaste', array['Tournage', 'Montage vidéo', 'Motion design', 'Étalonnage', 'Prise de son']),
  ('Design et communication', 'Community manager', array['Animation de communauté', 'Rédaction pour les réseaux', 'Publicité en ligne', 'Calendrier éditorial', 'Analyse d''audience']),
  ('Design et communication', 'Designer UI / UX', array['Maquettes (Figma)', 'Recherche utilisateur', 'Prototypage', 'Design system']),
  ('Gestion et commerce', 'Comptable', array['Comptabilité générale', 'Déclarations fiscales', 'Logiciels de comptabilité', 'Paie']),
  ('Gestion et commerce', 'Commercial', array['Prospection', 'Négociation', 'Vente en ligne', 'Gestion de la relation client']),
  ('Gestion et commerce', 'Entrepreneuriat', array['Business plan', 'Étude de marché', 'Gestion de projet', 'Recherche de financement']),
  ('Électricité et électronique', 'Électricien du bâtiment', array['Installation électrique', 'Schémas électriques', 'Normes de sécurité', 'Maintenance']),
  ('Électricité et électronique', 'Électronicien', array['Électronique analogique', 'Microcontrôleurs (Arduino)', 'Circuits imprimés', 'Énergie solaire', 'Automatisme']),
  ('Mécanique et industrie', 'Mécanicien', array['Maintenance industrielle', 'Soudure', 'Usinage', 'CAO (SolidWorks)', 'Diagnostic automobile']),
  ('Agriculture et agroalimentaire', 'Technicien agricole', array['Production végétale', 'Élevage', 'Transformation agroalimentaire', 'Contrôle qualité']),
  ('Santé et social', 'Aide-soignant', array['Soins de base', 'Hygiène et prévention', 'Accompagnement des patients']),
  ('Enseignement et formation', 'Répétiteur', array['Mathématiques', 'Physique-chimie', 'Langues', 'Pédagogie'])
) as t(d, j, skills), unnest(t.skills) as s
on conflict (domain, job, skill) do nothing;
insert into skill_catalog (domain, job, skill)
select distinct domain, job, '' from skill_catalog where job <> '' on conflict (domain, job, skill) do nothing;
insert into skill_catalog (domain, job, skill)
select distinct domain, '', '' from skill_catalog on conflict (domain, job, skill) do nothing;

create or replace function catalog_propose(p_domain text, p_job text default '', p_skill text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; d text := trim(coalesce(p_domain, '')); j text := trim(coalesce(p_job, '')); s text := trim(coalesce(p_skill, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(d) < 2 or char_length(d) > 80 or char_length(j) > 80 or char_length(s) > 80 then raise exception 'Intitulé invalide (2 à 80 caractères)'; end if;
  if (select count(*) from skill_catalog where proposed_by = auth.uid()) >= 200 then raise exception 'Trop de propositions : attendez leur validation'; end if;
  select id into v from skill_catalog where domain = d and job = j and skill = s;
  if v is not null then return v; end if;
  insert into skill_catalog (domain, job, skill, status, proposed_by) values (d, j, s, 'proposed', auth.uid()) returning id into v;
  if j <> '' then insert into skill_catalog (domain, job, skill, status, proposed_by) values (d, j, '', 'proposed', auth.uid()) on conflict do nothing; end if;
  insert into skill_catalog (domain, job, skill, status, proposed_by) values (d, '', '', 'proposed', auth.uid()) on conflict do nothing;
  return v;
end $$;

create or replace function catalog_review(p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_approve then update skill_catalog set status = 'approved' where id = p_id;
  else delete from skill_catalog where id = p_id and status = 'proposed'; end if;
end $$;

-- ============================================================ compétences du Talent Passport
create table if not exists talent_skills (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  domain text not null check (char_length(domain) between 2 and 80),
  job text not null default '' check (char_length(job) <= 80),
  skill text not null check (char_length(skill) between 2 and 80),
  level text not null check (level in ('debutant', 'intermediaire', 'avance', 'expert')),
  years numeric(4, 1) check (years is null or years between 0 and 60),
  description text not null default '' check (char_length(description) <= 1000),
  proof_document_id uuid references user_documents(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, domain, job, skill)
);
create index if not exists talent_skills_owner on talent_skills (owner_id, created_at desc);
alter table talent_skills enable row level security;
revoke all on talent_skills from anon, authenticated;
grant select on talent_skills to authenticated;
drop policy if exists "compétences : lecture connectée" on talent_skills;
create policy "compétences : lecture connectée" on talent_skills for select to authenticated using (true);

create or replace function profile_skills_sync(p_user uuid) returns void
language sql security definer set search_path = public as $$
  update profiles set skills = coalesce((select string_agg(skill, ', ' order by created_at) from talent_skills where owner_id = p_user), '') where id = p_user;
$$;
revoke all on function profile_skills_sync(uuid) from public, anon, authenticated;

create or replace function skill_save(p_id uuid, p_domain text, p_job text, p_skill text, p_level text, p_years numeric, p_description text, p_proof uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; d text := trim(coalesce(p_domain, '')); j text := trim(coalesce(p_job, '')); s text := trim(coalesce(p_skill, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(d) < 2 then raise exception 'Choisissez un domaine'; end if;
  if char_length(s) < 2 then raise exception 'Choisissez ou saisissez une compétence'; end if;
  if p_level not in ('debutant', 'intermediaire', 'avance', 'expert') then raise exception 'Choisissez un niveau'; end if;
  if p_proof is not null and not exists (select 1 from user_documents where id = p_proof and owner_id = auth.uid()) then raise exception 'Justificatif introuvable'; end if;
  perform catalog_propose(d, j, s);
  if p_id is null then
    if (select count(*) from talent_skills where owner_id = auth.uid()) >= 100 then raise exception 'Limite de 100 compétences atteinte'; end if;
    insert into talent_skills (owner_id, domain, job, skill, level, years, description, proof_document_id)
    values (auth.uid(), d, j, s, p_level, p_years, left(trim(coalesce(p_description, '')), 1000), p_proof) returning id into v;
  else
    update talent_skills set domain = d, job = j, skill = s, level = p_level, years = p_years, description = left(trim(coalesce(p_description, '')), 1000),
      proof_document_id = p_proof, updated_at = now() where id = p_id and owner_id = auth.uid() returning id into v;
    if v is null then raise exception 'Compétence introuvable'; end if;
  end if;
  perform profile_skills_sync(auth.uid());
  return v;
exception when unique_violation then raise exception 'Cette compétence est déjà dans votre profil';
end $$;

create or replace function skill_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from talent_skills where id = p_id and owner_id = auth.uid();
  if not found then raise exception 'Compétence introuvable'; end if;
  perform profile_skills_sync(auth.uid());
end $$;

-- ============================================================ portfolio (réalisations, images, vidéos, liens)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('portfolio-media', 'portfolio-media', true, 52428800, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "portfolio : dépôt dans son dossier" on storage.objects;
create policy "portfolio : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'portfolio-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "portfolio : suppression par le propriétaire" on storage.objects;
create policy "portfolio : suppression par le propriétaire" on storage.objects for delete to authenticated
  using (bucket_id = 'portfolio-media' and (storage.foldername(name))[1] = auth.uid()::text);

create table if not exists portfolio_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('realisation', 'image', 'video', 'link')),
  title text not null check (char_length(title) between 2 and 120),
  description text not null default '' check (char_length(description) <= 2000),
  category text not null default '' check (char_length(category) <= 80),
  happened_on text not null default '' check (char_length(happened_on) <= 40),
  url text not null default '' check (char_length(url) <= 500),
  media_path text,
  featured boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists portfolio_items_owner on portfolio_items (owner_id, created_at desc);
create unique index if not exists portfolio_one_featured on portfolio_items (owner_id) where featured;
alter table portfolio_items enable row level security;
revoke all on portfolio_items from anon, authenticated;
grant select on portfolio_items to anon, authenticated;
drop policy if exists "portfolio : lecture publique" on portfolio_items;
create policy "portfolio : lecture publique" on portfolio_items for select using (true);

create or replace function portfolio_save(p_id uuid, p_kind text, p_title text, p_description text, p_category text, p_date text, p_url text, p_media_path text, p_featured boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; u text := trim(coalesce(p_url, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('realisation', 'image', 'video', 'link') then raise exception 'Type invalide'; end if;
  if char_length(trim(coalesce(p_title, ''))) < 2 then raise exception 'Donnez un titre (2 caractères minimum)'; end if;
  if u <> '' and u !~* '^https?://[^ ]+$' then raise exception 'Le lien doit commencer par http:// ou https://'; end if;
  if p_kind = 'link' and u = '' then raise exception 'Saisissez le lien'; end if;
  if p_kind in ('image', 'video') and p_media_path is null and u = '' and p_id is null then raise exception 'Ajoutez un fichier ou un lien'; end if;
  if p_media_path is not null and (storage.foldername(p_media_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  if coalesce(p_featured, false) then update portfolio_items set featured = false where owner_id = auth.uid() and featured and id is distinct from p_id; end if;
  if p_id is null then
    if (select count(*) from portfolio_items where owner_id = auth.uid()) >= 100 then raise exception 'Limite de 100 éléments atteinte'; end if;
    insert into portfolio_items (owner_id, kind, title, description, category, happened_on, url, media_path, featured)
    values (auth.uid(), p_kind, trim(p_title), left(trim(coalesce(p_description, '')), 2000), left(trim(coalesce(p_category, '')), 80), left(trim(coalesce(p_date, '')), 40), u, p_media_path, coalesce(p_featured, false)) returning id into v;
  else
    update portfolio_items set kind = p_kind, title = trim(p_title), description = left(trim(coalesce(p_description, '')), 2000), category = left(trim(coalesce(p_category, '')), 80),
      happened_on = left(trim(coalesce(p_date, '')), 40), url = u, media_path = coalesce(p_media_path, media_path), featured = coalesce(p_featured, false)
    where id = p_id and owner_id = auth.uid() returning id into v;
    if v is null then raise exception 'Élément introuvable'; end if;
  end if;
  return v;
end $$;

create or replace function portfolio_delete(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v portfolio_items;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from portfolio_items where id = p_id and owner_id = auth.uid() returning * into v;
  if v.id is null then raise exception 'Élément introuvable'; end if;
  return coalesce(v.media_path, '');
end $$;

-- ============================================================ projets et innovations : fiche complète
alter table projects add column if not exists kind text not null default 'projet';
alter table projects add column if not exists details jsonb not null default '{}'::jsonb;
alter table projects add column if not exists media jsonb not null default '[]'::jsonb;
alter table projects add column if not exists visibility text not null default 'public';
do $$ begin
  alter table projects add constraint projects_kind_check check (kind in ('innovation', 'projet'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table projects add constraint projects_visibility_check check (visibility in ('private', 'public'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table projects add constraint projects_details_check check (jsonb_typeof(details) = 'object' and pg_column_size(details) <= 40000);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table projects add constraint projects_media_check check (jsonb_typeof(media) = 'array' and pg_column_size(media) <= 12000);
exception when duplicate_object then null; end $$;

drop policy if exists "projets : porteur, approuvés, département" on projects;
create policy "projets : porteur, approuvés, département" on projects for select
  using (owner_id = auth.uid() or (status = 'approved' and visibility = 'public') or current_role_name() in ('dept', 'admin'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('project-media', 'project-media', true, 52428800, array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "projets médias : dépôt dans son dossier" on storage.objects;
create policy "projets médias : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'project-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "projets médias : suppression par le propriétaire" on storage.objects;
create policy "projets médias : suppression par le propriétaire" on storage.objects for delete to authenticated
  using (bucket_id = 'project-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- Enregistrement du brouillon ou publication (envoi à l'établissement pour examen). La publication exige les champs essentiels.
create or replace function project_save_full(p_id uuid, p_kind text, p_title text, p_summary text, p_department text, p_details jsonb, p_media jsonb, p_visibility text, p_publish boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; d jsonb := coalesce(p_details, '{}'::jsonb); m jsonb := coalesce(p_media, '[]'::jsonb); miss text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_kind not in ('innovation', 'projet') then raise exception 'Type invalide'; end if;
  if p_visibility not in ('private', 'public') then raise exception 'Visibilité invalide'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(d) <> 'object' or pg_column_size(d) > 40000 then raise exception 'Fiche trop volumineuse'; end if;
  if jsonb_typeof(m) <> 'array' or pg_column_size(m) > 12000 then raise exception 'Trop de médias'; end if;
  if p_publish then
    if char_length(trim(coalesce(p_summary, ''))) < 30 then miss := array_append(miss, 'description (30 caractères minimum)'); end if;
    if char_length(trim(coalesce(d->>'domain', ''))) < 2 then miss := array_append(miss, 'domaine'); end if;
    if char_length(trim(coalesce(d->>'problem', ''))) < 10 then miss := array_append(miss, 'problème résolu'); end if;
    if char_length(trim(coalesce(d->>'solution', ''))) < 10 then miss := array_append(miss, 'solution proposée'); end if;
    if char_length(trim(coalesce(d->>'progress', ''))) < 2 then miss := array_append(miss, 'état d''avancement'); end if;
    if char_length(trim(coalesce(d->>'contact_email', ''))) + char_length(trim(coalesce(d->>'contact_phone', ''))) < 5 then miss := array_append(miss, 'un contact'); end if;
    if array_length(miss, 1) > 0 then raise exception 'Pour publier, complétez : %', array_to_string(miss, ', '); end if;
  end if;
  if p_id is null then
    insert into projects (owner_id, kind, title, summary, department, details, media, visibility, status)
    values (auth.uid(), p_kind, trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), nullif(left(trim(coalesce(p_department, '')), 120), ''), d, m, p_visibility,
      case when p_publish then 'submitted' else 'draft' end) returning id into pid;
    return pid;
  end if;
  select * into p from projects where id = p_id and owner_id = auth.uid();
  if not found then raise exception 'Projet introuvable'; end if;
  if p.status in ('submitted', 'approved') then raise exception 'Ce projet est en cours d''examen ou déjà publié : il ne peut plus être modifié ici'; end if;
  update projects set kind = p_kind, title = trim(p_title), summary = nullif(left(trim(coalesce(p_summary, '')), 4000), ''), department = nullif(left(trim(coalesce(p_department, '')), 120), ''),
    details = d, media = m, visibility = p_visibility,
    status = case when p_publish then 'submitted' when p.status = 'rejected' then 'draft' else p.status end, updated_at = now()
  where id = p.id;
  return p.id;
end $$;

create or replace function project_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from projects where id = p_id and owner_id = auth.uid() and status in ('draft', 'rejected');
  if not found then raise exception 'Seuls les brouillons et projets refusés peuvent être supprimés'; end if;
end $$;

-- ============================================================ droits d'appel
revoke all on function catalog_propose(text, text, text), catalog_review(uuid, boolean), skill_save(uuid, text, text, text, text, numeric, text, uuid), skill_delete(uuid),
  portfolio_save(uuid, text, text, text, text, text, text, text, boolean), portfolio_delete(uuid),
  project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean), project_delete(uuid) from public, anon;
grant execute on function catalog_propose(text, text, text), catalog_review(uuid, boolean), skill_save(uuid, text, text, text, text, numeric, text, uuid), skill_delete(uuid),
  portfolio_save(uuid, text, text, text, text, text, text, text, boolean), portfolio_delete(uuid),
  project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean), project_delete(uuid) to authenticated;

-- Retour arrière (ne supprime aucune donnée utilisateur existante avant d'être exécuté volontairement) :
--   drop function project_delete(uuid); drop function project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean);
--   drop function portfolio_delete(uuid); drop function portfolio_save(uuid, text, text, text, text, text, text, text, boolean);
--   drop function skill_delete(uuid); drop function skill_save(uuid, text, text, text, text, numeric, text, uuid); drop function profile_skills_sync(uuid);
--   drop function catalog_review(uuid, boolean); drop function catalog_propose(text, text, text);
--   drop table portfolio_items; drop table talent_skills; drop table skill_catalog;
--   (colonnes ajoutées à projects : kind, details, media, visibility ; compartiments portfolio-media et project-media à vider avant suppression)
