-- Profil Entreprise : fiche (nom, secteur, taille, ville, site, interlocuteur, présentation, logo), pièces justificatives déposées par l'entreprise
-- (compartiment privé « profile-documents », dossier de la personne) et vérification par l'administrateur uniquement : « Vérifiée » après examen des pièces.
-- Retour arrière : drop function company_get(), company_save(jsonb), company_doc_add(text, text, text, text, integer), company_doc_delete(uuid), company_submit(),
--   company_queue(), company_decide(uuid, boolean, text), company_public(uuid); drop table company_documents, company_profiles.

create table if not exists company_profiles (
  owner_id uuid primary key references profiles(id) on delete cascade,
  company_name text not null check (char_length(btrim(company_name)) between 2 and 120),
  sector text not null default '' check (char_length(sector) <= 80),
  size text not null default '' check (size in ('', '1-10', '11-50', '51-200', '201-1000', '1000+')),
  city text not null default '' check (char_length(city) <= 80),
  website text check (website is null or website ~* '^https?://[^ ]+$'),
  phone text not null default '' check (char_length(phone) <= 30),
  contact_name text not null default '' check (char_length(contact_name) <= 80),
  contact_role text not null default '' check (char_length(contact_role) <= 80),
  description text not null default '' check (char_length(description) <= 1500),
  founded_year integer check (founded_year is null or founded_year between 1900 and 2100),
  registration_number text not null default '' check (char_length(registration_number) <= 60),
  logo_path text check (logo_path is null or char_length(logo_path) between 5 and 300),
  status text not null default 'draft' check (status in ('draft', 'pending', 'approved', 'rejected')),
  review_note text check (review_note is null or char_length(review_note) <= 500),
  reviewed_by uuid references profiles(id) on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists company_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references company_profiles(owner_id) on delete cascade,
  kind text not null check (kind in ('registration', 'tax', 'mandate', 'attestation', 'other')),
  name text not null check (char_length(btrim(name)) between 1 and 160),
  path text not null unique,
  mime text not null check (mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  size_bytes integer not null check (size_bytes between 1 and 10485760),
  created_at timestamptz not null default now()
);
create index if not exists company_documents_owner on company_documents (owner_id, created_at desc);

alter table company_profiles enable row level security;
alter table company_documents enable row level security;
revoke all on company_profiles, company_documents from anon, authenticated;

create or replace function company_is_org() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name()::text, '') in ('company', 'other', 'admin')
$$;

-- Ma fiche et mes pièces (null tant que je n'ai rien enregistré).
create or replace function company_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c company_profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = auth.uid();
  if not found then return null; end if;
  return to_jsonb(c) || jsonb_build_object('documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime, 'size_bytes', d.size_bytes, 'created_at', d.created_at) order by d.created_at desc)
    from company_documents d where d.owner_id = auth.uid()), '[]'::jsonb));
end $$;

-- Enregistre la fiche. Après approbation, modifier le nom ou le numéro d'immatriculation demande une nouvelle vérification.
create or replace function company_save(p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype; v_name text := btrim(coalesce(p->>'company_name', '')); v_site text := nullif(btrim(coalesce(p->>'website', '')), ''); v_status text; v_reg text := btrim(coalesce(p->>'registration_number', ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not company_is_org() then raise exception 'Réservé aux entreprises et organisations'; end if;
  if char_length(v_name) < 2 then raise exception 'Indiquez le nom de l''entreprise'; end if;
  if v_site is not null and v_site !~* '^https?://[^ ]+$' then raise exception 'Le site doit commencer par https://'; end if;
  if coalesce(p->>'size', '') not in ('', '1-10', '11-50', '51-200', '201-1000', '1000+') then raise exception 'Taille inconnue'; end if;
  if nullif(p->>'logo_path', '') is not null and split_part(p->>'logo_path', '/', 1) <> auth.uid()::text then raise exception 'Logo invalide : déposez-le d''abord dans votre dossier'; end if;
  select * into c from company_profiles where owner_id = auth.uid();
  v_status := coalesce(c.status, 'draft');
  if found and c.status = 'approved' and (c.company_name is distinct from v_name or c.registration_number is distinct from v_reg) then v_status := 'pending'; end if;
  insert into company_profiles (owner_id, company_name, sector, size, city, website, phone, contact_name, contact_role, description, founded_year, registration_number, logo_path, status, submitted_at)
  values (auth.uid(), v_name, left(btrim(coalesce(p->>'sector', '')), 80), coalesce(p->>'size', ''), left(btrim(coalesce(p->>'city', '')), 80), v_site, left(btrim(coalesce(p->>'phone', '')), 30),
          left(btrim(coalesce(p->>'contact_name', '')), 80), left(btrim(coalesce(p->>'contact_role', '')), 80), left(btrim(coalesce(p->>'description', '')), 1500), nullif(p->>'founded_year', '')::int, left(v_reg, 60),
          nullif(p->>'logo_path', ''), 'draft', null)
  on conflict (owner_id) do update set company_name = excluded.company_name, sector = excluded.sector, size = excluded.size, city = excluded.city, website = excluded.website, phone = excluded.phone,
    contact_name = excluded.contact_name, contact_role = excluded.contact_role, description = excluded.description, founded_year = excluded.founded_year, registration_number = excluded.registration_number,
    logo_path = coalesce(excluded.logo_path, company_profiles.logo_path), status = v_status, updated_at = now();
  if v_status = 'pending' and c.status = 'approved' then
    insert into notifications (user_id, kind, title, body, data)
      select a.id, 'company_review', 'Entreprise à revérifier', v_name || ' a modifié son nom ou son numéro d''immatriculation.', jsonb_build_object('owner', auth.uid()) from profiles a where a.role::text = 'admin';
  end if;
  return v_status;
end $$;

create or replace function company_doc_add(p_kind text, p_name text, p_path text, p_mime text, p_size integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from company_profiles where owner_id = auth.uid()) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  if (select count(*) from company_documents where owner_id = auth.uid()) >= 8 then raise exception 'Huit pièces au plus : supprimez-en une'; end if;
  insert into company_documents (owner_id, kind, name, path, mime, size_bytes) values (auth.uid(), p_kind, btrim(p_name), p_path, p_mime, p_size) returning id into v_id;
  return v_id;
end $$;

create or replace function company_doc_delete(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_path text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from company_documents where id = p_id and owner_id = auth.uid() returning path into v_path;
  if v_path is null then raise exception 'Pièce introuvable'; end if;
  return v_path;
end $$;

-- Envoi pour vérification : fiche complète et au moins une pièce justificative.
create or replace function company_submit() returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = auth.uid() for update;
  if not found then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if c.status = 'approved' then raise exception 'Entreprise déjà vérifiée'; end if;
  if c.status = 'pending' then raise exception 'Votre demande est déjà en cours d''examen'; end if;
  if c.sector = '' or c.city = '' or c.contact_name = '' or c.phone = '' then raise exception 'Complétez le secteur, la ville, l''interlocuteur et le téléphone'; end if;
  if not exists (select 1 from company_documents where owner_id = auth.uid()) then raise exception 'Ajoutez au moins une pièce justificative (immatriculation, numéro fiscal…)'; end if;
  update company_profiles set status = 'pending', submitted_at = now(), review_note = null where owner_id = auth.uid();
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'company_review', 'Entreprise à vérifier', c.company_name || ' demande sa vérification.', jsonb_build_object('owner', auth.uid()) from profiles a where a.role::text = 'admin';
  return 'pending';
end $$;

-- File d'examen de l'administrateur.
create or replace function company_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((select jsonb_agg(to_jsonb(c) || jsonb_build_object('email', u.email, 'account_name', p.name,
      'documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime) order by d.created_at) from company_documents d where d.owner_id = c.owner_id), '[]'::jsonb)) order by c.submitted_at)
    from company_profiles c join profiles p on p.id = c.owner_id left join auth.users u on u.id = c.owner_id where c.status = 'pending'), '[]'::jsonb);
end $$;

create or replace function company_decide(p_owner uuid, p_approve boolean, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype; v_status text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into c from company_profiles where owner_id = p_owner and status = 'pending' for update;
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  if not p_approve and char_length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'Indiquez le motif du refus'; end if;
  v_status := case when p_approve then 'approved' else 'rejected' end;
  update company_profiles set status = v_status, review_note = nullif(left(btrim(coalesce(p_note, '')), 500), ''), reviewed_by = auth.uid(), reviewed_at = now() where owner_id = p_owner;
  insert into notifications (user_id, kind, title, body, data)
    values (p_owner, 'company_review', case when p_approve then 'Entreprise vérifiée' else 'Vérification refusée' end,
            case when p_approve then c.company_name || ' est maintenant vérifiée : le badge « Vérifiée » s''affiche sur votre fiche.' else 'Motif : ' || btrim(p_note) end, jsonb_build_object('status', v_status));
  return v_status;
end $$;

-- Carte publique d'une entreprise (nom, logo, secteur, ville, site, présentation, vérifiée ou non) : jamais les pièces ni le numéro.
create or replace function company_public(p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('owner_id', c.owner_id, 'company_name', c.company_name, 'sector', c.sector, 'size', c.size, 'city', c.city, 'website', c.website, 'description', c.description,
      'founded_year', c.founded_year, 'logo_path', c.logo_path, 'verified', c.status = 'approved')
  from company_profiles c where c.owner_id = p_owner and auth.uid() is not null
$$;

revoke all on function company_is_org(), company_get(), company_save(jsonb), company_doc_add(text, text, text, text, integer), company_doc_delete(uuid), company_submit(), company_queue(), company_decide(uuid, boolean, text), company_public(uuid) from public, anon;
grant execute on function company_get(), company_save(jsonb), company_doc_add(text, text, text, text, integer), company_doc_delete(uuid), company_submit(), company_queue(), company_decide(uuid, boolean, text), company_public(uuid) to authenticated;
