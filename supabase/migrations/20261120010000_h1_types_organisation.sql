-- Lot H1 (Organisation) 1/5 — types d'organisation et justificatifs requis par type.
-- Décision : « Entreprise » devient « Organisation » (entreprises commerciales, associations, ONG, coopératives, fondations, institutions, structures
-- partenaires, autres organisations reconnues). Un TYPE est choisi à l'inscription ; la fiche, les pièces justificatives et les forfaits s'y adaptent.
-- Les identifiants techniques company_* restent (compatibilité) ; l'enum app_role n'est pas touché.
--   · org_types / org_type_docs : référentiel lisible par tous (types, libellés, champs de fiche exigés, pièces par type et alternatives par « groupe » :
--     un groupe est satisfait dès qu'UNE des pièces du groupe est déposée) ;
--   · company_profiles.org_type, tax_number (NIU), mission ; company_documents.kind étendu (statuts, récépissé, agrément, acte de création, identité, convention) ;
--   · org_types_list() (public), company_org_type(p_owner) (type, exigences et manques de la fiche), company_set_type(p_type) (inscription ou changement).
-- Retour arrière : drop function company_set_type(text), company_org_type(uuid), org_types_list(), _company_missing(uuid), _company_requirements(uuid), org_type_config(text);
--   alter table company_profiles drop column org_type, drop column tax_number, drop column mission; drop table org_type_docs, org_types ;
--   recréer la contrainte company_documents_kind_check depuis 20261114002500.

create table if not exists org_types (
  code text primary key check (code ~ '^[a-z_]{3,40}$'),
  label text not null check (char_length(btrim(label)) between 2 and 60),
  description text not null default '' check (char_length(description) <= 300),
  commercial boolean not null default false,
  position integer not null default 0,
  sector_label text not null default 'Secteur d''activité',
  registration_label text not null default 'Numéro d''immatriculation',
  registration_required boolean not null default false,
  tax_required boolean not null default false,
  mission_required boolean not null default false
);

create table if not exists org_type_docs (
  org_type text not null references org_types(code) on delete cascade,
  kind text not null,
  label text not null,
  hint text not null default '',
  req_group integer,
  position integer not null default 0,
  primary key (org_type, kind)
);

alter table org_types enable row level security;
alter table org_type_docs enable row level security;
revoke all on org_types, org_type_docs from anon, authenticated;

insert into org_types (code, label, description, commercial, position, sector_label, registration_label, registration_required, tax_required, mission_required) values
  ('entreprise_commerciale', 'Entreprise commerciale', 'Société ou entreprise individuelle qui vend des biens ou des services.', true, 1, 'Secteur d''activité', 'RCCM / numéro d''immatriculation', false, false, false),
  ('association', 'Association', 'Association déclarée (culturelle, sportive, étudiante, de développement…).', false, 2, 'Domaine d''action', 'Numéro du récépissé de déclaration', true, false, true),
  ('ong', 'ONG', 'Organisation non gouvernementale ou organisation internationale agréée.', false, 3, 'Domaine d''action', 'Numéro d''agrément ou d''autorisation', true, false, true),
  ('cooperative', 'Coopérative', 'Coopérative ou groupement d''initiative commune.', false, 4, 'Domaine d''activité', 'Numéro d''immatriculation de la coopérative', true, false, true),
  ('fondation', 'Fondation', 'Fondation ou structure de mécénat reconnue.', false, 5, 'Domaine d''action', 'Numéro de l''acte de constitution ou d''autorisation', false, false, true),
  ('institution', 'Institution', 'Administration, établissement public, université ou organisme officiel.', false, 6, 'Domaine de compétence', 'Référence de l''acte de création', false, false, false),
  ('structure_partenaire', 'Structure partenaire', 'Structure liée à l''IUT par un partenariat (incubateur, centre, réseau…).', false, 7, 'Domaine d''activité', 'Numéro d''enregistrement (si applicable)', false, false, false),
  ('autre_reconnue', 'Autre organisation reconnue', 'Toute autre organisation reconnue qui ne rentre pas dans les types ci-dessus.', false, 8, 'Domaine d''activité', 'Numéro d''enregistrement (si applicable)', false, false, false)
on conflict (code) do update set label = excluded.label, description = excluded.description, commercial = excluded.commercial, position = excluded.position,
  sector_label = excluded.sector_label, registration_label = excluded.registration_label, registration_required = excluded.registration_required,
  tax_required = excluded.tax_required, mission_required = excluded.mission_required;

-- Pièces par type : req_group renseigné = exigence obligatoire (alternatives au sein d'un même groupe), null = pièce facultative.
delete from org_type_docs where org_type in (select code from org_types);
insert into org_type_docs (org_type, kind, label, hint, req_group, position) values
  ('entreprise_commerciale', 'registration', 'RCCM', 'Registre du commerce et du crédit mobilier', 1, 1),
  ('entreprise_commerciale', 'tax', 'NIU', 'Attestation du numéro d''identifiant unique', 1, 2),
  ('entreprise_commerciale', 'mandate', 'Mandat du représentant', 'Pouvoir de la personne qui agit pour l''entreprise', null, 3),
  ('entreprise_commerciale', 'attestation', 'Attestation officielle', '', null, 4),
  ('entreprise_commerciale', 'other', 'Autre pièce', '', null, 5),
  ('association', 'receipt', 'Récépissé de déclaration', 'Récépissé ou arrêté de déclaration de l''association', 1, 1),
  ('association', 'statutes', 'Statuts', 'Statuts signés de l''association', 2, 2),
  ('association', 'mandate', 'Mandat du représentant', 'Procès-verbal ou lettre désignant le responsable', null, 3),
  ('association', 'identity', 'Pièce d''identité du responsable', '', null, 4),
  ('association', 'attestation', 'Attestation officielle', '', null, 5),
  ('association', 'other', 'Autre pièce', '', null, 6),
  ('ong', 'authorization', 'Agrément ou autorisation d''exercer', 'Agrément, autorisation ou accord-cadre', 1, 1),
  ('ong', 'statutes', 'Statuts', 'Statuts ou charte de l''organisation', 2, 2),
  ('ong', 'receipt', 'Récépissé de déclaration', '', null, 3),
  ('ong', 'mandate', 'Mandat du représentant', '', null, 4),
  ('ong', 'identity', 'Pièce d''identité du responsable', '', null, 5),
  ('ong', 'attestation', 'Attestation officielle', '', null, 6),
  ('ong', 'other', 'Autre pièce', '', null, 7),
  ('cooperative', 'registration', 'Immatriculation de la coopérative', 'Certificat ou récépissé d''immatriculation', 1, 1),
  ('cooperative', 'statutes', 'Statuts', 'Statuts de la coopérative', 2, 2),
  ('cooperative', 'receipt', 'Récépissé de déclaration', '', null, 3),
  ('cooperative', 'mandate', 'Mandat du représentant', '', null, 4),
  ('cooperative', 'identity', 'Pièce d''identité du responsable', '', null, 5),
  ('cooperative', 'attestation', 'Attestation officielle', '', null, 6),
  ('cooperative', 'other', 'Autre pièce', '', null, 7),
  ('fondation', 'statutes', 'Acte de constitution ou statuts', 'Acte constitutif de la fondation', 1, 1),
  ('fondation', 'authorization', 'Autorisation ou reconnaissance', 'Arrêté, décret ou décision d''autorisation', 2, 2),
  ('fondation', 'decree', 'Acte officiel de création', '', 2, 3),
  ('fondation', 'receipt', 'Récépissé de déclaration', '', 2, 4),
  ('fondation', 'mandate', 'Mandat du représentant', '', null, 5),
  ('fondation', 'identity', 'Pièce d''identité du responsable', '', null, 6),
  ('fondation', 'attestation', 'Attestation officielle', '', null, 7),
  ('fondation', 'other', 'Autre pièce', '', null, 8),
  ('institution', 'decree', 'Acte de création', 'Décret, arrêté, loi ou texte instituant la structure', 1, 1),
  ('institution', 'mandate', 'Mandat du représentant', 'Décision ou lettre qui habilite la personne à agir', 2, 2),
  ('institution', 'identity', 'Pièce d''identité du responsable', '', null, 3),
  ('institution', 'attestation', 'Attestation officielle', '', null, 4),
  ('institution', 'other', 'Autre pièce', '', null, 5),
  ('structure_partenaire', 'convention', 'Convention ou lettre de partenariat', 'Convention signée ou lettre d''engagement avec l''IUT', 1, 1),
  ('structure_partenaire', 'attestation', 'Attestation officielle', '', 1, 2),
  ('structure_partenaire', 'registration', 'Immatriculation', '', 2, 3),
  ('structure_partenaire', 'receipt', 'Récépissé de déclaration', '', 2, 4),
  ('structure_partenaire', 'statutes', 'Statuts', '', 2, 5),
  ('structure_partenaire', 'decree', 'Acte de création', '', 2, 6),
  ('structure_partenaire', 'authorization', 'Agrément ou autorisation', '', 2, 7),
  ('structure_partenaire', 'tax', 'NIU', '', null, 8),
  ('structure_partenaire', 'mandate', 'Mandat du représentant', '', null, 9),
  ('structure_partenaire', 'identity', 'Pièce d''identité du responsable', '', null, 10),
  ('structure_partenaire', 'other', 'Autre pièce', '', null, 11),
  ('autre_reconnue', 'registration', 'Immatriculation', '', 1, 1),
  ('autre_reconnue', 'receipt', 'Récépissé de déclaration', '', 1, 2),
  ('autre_reconnue', 'statutes', 'Statuts', '', 1, 3),
  ('autre_reconnue', 'decree', 'Acte de création', '', 1, 4),
  ('autre_reconnue', 'authorization', 'Agrément ou autorisation', '', 1, 5),
  ('autre_reconnue', 'attestation', 'Attestation officielle', '', 1, 6),
  ('autre_reconnue', 'tax', 'NIU', '', null, 7),
  ('autre_reconnue', 'mandate', 'Mandat du représentant', '', null, 8),
  ('autre_reconnue', 'identity', 'Pièce d''identité du responsable', '', null, 9),
  ('autre_reconnue', 'other', 'Autre pièce', '', null, 10);

-- ============================================================ colonnes de la fiche et nature des pièces
alter table company_profiles add column if not exists org_type text not null default 'entreprise_commerciale' references org_types(code);
alter table company_profiles add column if not exists tax_number text not null default '' check (char_length(tax_number) <= 60);
alter table company_profiles add column if not exists mission text not null default '' check (char_length(mission) <= 1500);

do $$
declare r record;
begin
  for r in select conname from pg_constraint where conrelid = 'company_documents'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%kind%' loop
    execute format('alter table company_documents drop constraint %I', r.conname);
  end loop;
  alter table company_documents add constraint company_documents_kind_check
    check (kind in ('registration', 'tax', 'mandate', 'attestation', 'other', 'statutes', 'receipt', 'authorization', 'decree', 'identity', 'convention'));
end $$;

-- ============================================================ lecture du référentiel
create or replace function org_type_config(p_type text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('code', t.code, 'label', t.label, 'description', t.description, 'commercial', t.commercial,
      'sector_label', t.sector_label, 'registration_label', t.registration_label, 'registration_required', t.registration_required,
      'tax_required', t.tax_required, 'mission_required', t.mission_required,
      'docs', coalesce((select jsonb_agg(jsonb_build_object('kind', d.kind, 'label', d.label, 'hint', d.hint, 'group', d.req_group, 'required', d.req_group is not null) order by d.position)
                        from org_type_docs d where d.org_type = t.code), '[]'::jsonb))
  from org_types t where t.code = p_type
$$;
revoke all on function org_type_config(text) from public, anon, authenticated;

create or replace function org_types_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(org_type_config(t.code) order by t.position), '[]'::jsonb) from org_types t
$$;
revoke all on function org_types_list() from public;
grant execute on function org_types_list() to anon, authenticated;

-- Exigences de pièces d'une fiche : un groupe est satisfait dès qu'une de ses pièces est déposée.
create or replace function _company_requirements(p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('group', g.grp, 'label', g.label, 'kinds', to_jsonb(g.kinds),
      'satisfied', exists (select 1 from company_documents x where x.owner_id = p_owner and x.kind = any (g.kinds))) order by g.grp), '[]'::jsonb)
  from company_profiles c
  join lateral (select d.req_group as grp, array_agg(d.kind order by d.position) as kinds, string_agg(d.label, ' ou ' order by d.position) as label
                from org_type_docs d where d.org_type = c.org_type and d.req_group is not null group by d.req_group) g on true
  where c.owner_id = p_owner
$$;
revoke all on function _company_requirements(uuid) from public, anon, authenticated;

-- Champs de fiche encore à remplir avant l'envoi pour vérification.
create or replace function _company_missing(p_owner uuid) returns text[]
language plpgsql stable security definer set search_path = public as $$
declare c company_profiles%rowtype; t org_types%rowtype; v text[] := '{}';
begin
  select * into c from company_profiles where owner_id = p_owner;
  if not found then return v; end if;
  select * into t from org_types where code = c.org_type;
  if c.sector = '' then v := v || ('le ' || lower(t.sector_label))::text; end if;
  if c.city = '' then v := v || 'la ville'::text; end if;
  if c.contact_name = '' then v := v || 'l''interlocuteur'::text; end if;
  if c.phone = '' then v := v || 'le téléphone'::text; end if;
  if t.registration_required and c.registration_number = '' then v := v || ('le champ « ' || t.registration_label || ' »')::text; end if;
  if t.tax_required and c.tax_number = '' then v := v || 'le NIU'::text; end if;
  if t.mission_required and c.mission = '' then v := v || 'la mission de l''organisation'::text; end if;
  return v;
end $$;
revoke all on function _company_missing(uuid) from public, anon, authenticated;

-- Type de l'organisation de l'appelant (ou de celle dont il est membre) avec ses exigences et ce qu'il reste à fournir ; null sans fiche.
create or replace function company_org_type(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); c company_profiles%rowtype; v_role text := company_role_of(company_effective_owner(p_owner));
begin
  select * into c from company_profiles where owner_id = v_owner;
  if not found then return null; end if;
  return org_type_config(c.org_type) || jsonb_build_object('org_type', c.org_type, 'status', c.status,
    'missing_fields', case when v_role in ('owner', 'admin') then to_jsonb(_company_missing(v_owner)) else '[]'::jsonb end,
    'requirements', case when v_role in ('owner', 'admin') then _company_requirements(v_owner) else '[]'::jsonb end);
end $$;
revoke all on function company_org_type(uuid) from public, anon;
grant execute on function company_org_type(uuid) to authenticated;

-- Choix (ou changement) du type : crée la fiche en brouillon si elle n'existe pas. Une fiche approuvée qui change de nature repasse en vérification.
create or replace function company_set_type(p_type text) returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype; v_name text; v_label text; v_status text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not company_is_org() then raise exception 'Réservé aux organisations'; end if;
  select label into v_label from org_types where code = p_type;
  if v_label is null then raise exception 'Type d''organisation inconnu'; end if;
  select * into c from company_profiles where owner_id = auth.uid() for update;
  if not found then
    select left(btrim(name), 120) into v_name from profiles where id = auth.uid();
    if char_length(coalesce(v_name, '')) < 2 then raise exception 'Complétez d''abord le nom du compte'; end if;
    insert into company_profiles (owner_id, company_name, org_type) values (auth.uid(), v_name, p_type);
    return 'draft';
  end if;
  if c.org_type = p_type then return c.status; end if;
  if c.status = 'pending' then raise exception 'La fiche est en cours de vérification : le type ne peut plus être modifié avant la décision de l''administrateur'; end if;
  v_status := c.status;
  if c.status = 'approved' then v_status := 'pending'; end if;
  update company_profiles set org_type = p_type, status = v_status, submitted_at = case when v_status = 'pending' then now() else submitted_at end, updated_at = now() where owner_id = auth.uid();
  if v_status = 'pending' then
    insert into notifications (user_id, kind, title, body, data)
      select a.id, 'company_review', 'Organisation à revérifier', c.company_name || ' a changé de type d''organisation (' || v_label || ').', jsonb_build_object('owner', auth.uid()) from profiles a where a.role::text = 'admin';
    insert into notifications (user_id, kind, title, body, data)
      values (auth.uid(), 'company_review', 'Fiche repassée en vérification', 'Le type d''organisation a changé : le badge est retiré jusqu''à la nouvelle approbation de l''administrateur.', jsonb_build_object('owner', auth.uid(), 'status', 'pending'));
  end if;
  return v_status;
end $$;
revoke all on function company_set_type(text) from public, anon;
grant execute on function company_set_type(text) to authenticated;
