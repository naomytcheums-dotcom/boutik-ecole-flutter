-- Lot H1 (Organisation) 2/5 — fiche, pièces justificatives et vérification adaptées au type d'organisation.
--   · company_save : type (org_type), NIU (tax_number) et mission ; nom, numéro d'immatriculation, NIU ou type modifiés sur une fiche approuvée => nouvelle vérification ;
--   · company_get : renvoie aussi la configuration du type, les exigences de pièces et les champs manquants (sans NIU ni coordonnées sensibles aux simples lecteurs) ;
--   · company_doc_add : la pièce doit correspondre au type de l'organisation (ou être « autre pièce ») ;
--   · company_submit : champs exigés par type + chaque groupe de pièces requis satisfait ; company_decide et company_queue : libellés « Organisation » ;
--   · _company_page (page publique) et company_dashboard : type, libellé du type et mission.
-- Les gardes de 20261118020000 sont conservées (équipe, suspension, fiche non modifiable pendant l'examen, logo, audit, certification du compte).
-- Retour arrière : recréer company_get, company_save, company_doc_add, company_submit, company_decide depuis 20261118020000, company_queue depuis 20261114002500,
--   _company_page depuis 20261118040000 et company_dashboard depuis 20261114002900.

create or replace function company_get(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); c company_profiles%rowtype; v_role text; j jsonb;
begin
  select * into c from company_profiles where owner_id = v_owner;
  if not found then return null; end if;
  v_role := company_role_of(v_owner);
  j := to_jsonb(c) || jsonb_build_object('my_role', v_role, 'org_config', org_type_config(c.org_type),
    'documents', case when v_role in ('owner', 'admin') then coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime, 'size_bytes', d.size_bytes, 'created_at', d.created_at) order by d.created_at desc)
      from company_documents d where d.owner_id = v_owner), '[]'::jsonb) else '[]'::jsonb end,
    'requirements', case when v_role in ('owner', 'admin') then _company_requirements(v_owner) else '[]'::jsonb end,
    'missing_fields', case when v_role in ('owner', 'admin') then to_jsonb(_company_missing(v_owner)) else '[]'::jsonb end);
  if v_role not in ('owner', 'admin') then
    j := j - 'registration_number' - 'tax_number' - 'phone' - 'contact_name' - 'contact_role' - 'review_note' - 'reviewed_by';
  end if;
  return j;
end $$;
revoke all on function company_get(uuid) from public, anon;
grant execute on function company_get(uuid) to authenticated;

create or replace function company_save(p jsonb, p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner)); c company_profiles%rowtype;
        v_name text := btrim(coalesce(p->>'company_name', '')); v_site text := nullif(btrim(coalesce(p->>'website', '')), ''); v_status text; v_reg text := btrim(coalesce(p->>'registration_number', ''));
        v_logo text := nullif(p->>'logo_path', ''); v_tax text := btrim(coalesce(p->>'tax_number', '')); v_mission text := btrim(coalesce(p->>'mission', '')); v_type text;
        v_found boolean;
begin
  if v_role not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''organisation'; end if;
  if v_owner = auth.uid() and not company_is_org() then raise exception 'Réservé aux organisations'; end if;
  if v_owner <> auth.uid() and not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Fiche introuvable'; end if;
  if char_length(v_name) < 2 then raise exception 'Indiquez le nom de l''organisation'; end if;
  if v_site is not null and v_site !~* '^https?://[^ ]+$' then raise exception 'Le site doit commencer par https://'; end if;
  if coalesce(p->>'size', '') not in ('', '1-10', '11-50', '51-200', '201-1000', '1000+') then raise exception 'Taille inconnue'; end if;
  if char_length(btrim(coalesce(p->>'contact_name', ''))) > 80 or char_length(btrim(coalesce(p->>'contact_role', ''))) > 80 then raise exception 'L''interlocuteur et sa fonction : 80 caractères au plus'; end if;
  if char_length(v_tax) > 60 then raise exception 'Le NIU : 60 caractères au plus'; end if;
  if char_length(v_mission) > 1500 then raise exception 'La mission : 1500 caractères au plus'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  v_found := found;
  v_type := coalesce(nullif(btrim(coalesce(p->>'org_type', '')), ''), case when v_found then c.org_type end, 'entreprise_commerciale');
  if not exists (select 1 from org_types where code = v_type) then raise exception 'Type d''organisation inconnu'; end if;
  if v_found and c.status = 'pending' then raise exception 'La fiche est en cours de vérification : elle ne peut plus être modifiée avant la décision de l''administrateur'; end if;
  -- logo : déposé dans le dossier de l'appelant, ou déjà enregistré sur la fiche (un administrateur de l'équipe peut renvoyer celui du propriétaire)
  if v_logo is not null and split_part(v_logo, '/', 1) <> auth.uid()::text and v_logo is distinct from c.logo_path then
    raise exception 'Logo invalide : déposez-le d''abord dans votre dossier';
  end if;
  v_status := coalesce(c.status, 'draft');
  if v_found and c.status = 'approved' and (c.company_name is distinct from v_name or c.registration_number is distinct from v_reg or c.tax_number is distinct from v_tax or c.org_type is distinct from v_type) then v_status := 'pending'; end if;
  insert into company_profiles (owner_id, company_name, sector, size, city, website, phone, contact_name, contact_role, description, founded_year, registration_number, logo_path, status, submitted_at, org_type, tax_number, mission)
  values (v_owner, v_name, left(btrim(coalesce(p->>'sector', '')), 80), coalesce(p->>'size', ''), left(btrim(coalesce(p->>'city', '')), 80), v_site, left(btrim(coalesce(p->>'phone', '')), 30),
          left(btrim(coalesce(p->>'contact_name', '')), 80), left(btrim(coalesce(p->>'contact_role', '')), 80), left(btrim(coalesce(p->>'description', '')), 1500), nullif(p->>'founded_year', '')::int, left(v_reg, 60),
          v_logo, 'draft', null, v_type, left(v_tax, 60), v_mission)
  on conflict (owner_id) do update set company_name = excluded.company_name, sector = excluded.sector, size = excluded.size, city = excluded.city, website = excluded.website, phone = excluded.phone,
    contact_name = excluded.contact_name, contact_role = excluded.contact_role, description = excluded.description, founded_year = excluded.founded_year, registration_number = excluded.registration_number,
    org_type = excluded.org_type, tax_number = excluded.tax_number, mission = excluded.mission,
    logo_path = coalesce(excluded.logo_path, company_profiles.logo_path), status = v_status, updated_at = now();
  if v_status = 'pending' and c.status = 'approved' then
    insert into notifications (user_id, kind, title, body, data)
      select a.id, 'company_review', 'Organisation à revérifier', v_name || ' a modifié son nom, son type, son numéro d''immatriculation ou son NIU.', jsonb_build_object('owner', v_owner) from profiles a where a.role::text = 'admin';
    insert into notifications (user_id, kind, title, body, data)
      values (v_owner, 'company_review', 'Fiche repassée en vérification', 'Le nom, le type, le numéro d''immatriculation ou le NIU a changé : le badge est retiré et la publication reste suspendue jusqu''à la nouvelle approbation de l''administrateur.', jsonb_build_object('owner', v_owner, 'status', 'pending'));
  end if;
  return v_status;
end $$;
revoke all on function company_save(jsonb, uuid) from public, anon;
grant execute on function company_save(jsonb, uuid) to authenticated;

create or replace function company_doc_add(p_kind text, p_name text, p_path text, p_mime text, p_size integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_meta jsonb; v_mime text := p_mime; v_size int := p_size; v_type text; v_label text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select org_type into v_type from company_profiles where owner_id = auth.uid();
  if v_type is null then raise exception 'Enregistrez d''abord la fiche de l''organisation'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  if p_kind is null or p_kind not in ('registration', 'tax', 'mandate', 'attestation', 'other', 'statutes', 'receipt', 'authorization', 'decree', 'identity', 'convention') then raise exception 'Type de pièce inconnu'; end if;
  if p_kind <> 'other' and not exists (select 1 from org_type_docs where org_type = v_type and kind = p_kind) then
    select label into v_label from org_types where code = v_type;
    raise exception 'Cette pièce ne correspond pas au type « % » : choisissez une des pièces demandées pour ce type', v_label;
  end if;
  select metadata into v_meta from storage.objects where bucket_id = 'profile-documents' and name = p_path;
  if not found then raise exception 'Fichier absent du stockage : envoyez-le d''abord'; end if;
  if v_meta is not null then
    v_mime := coalesce(nullif(v_meta ->> 'mimetype', ''), v_mime);
    begin
      v_size := coalesce((v_meta ->> 'size')::int, v_size);
    exception when others then
      v_size := p_size;
    end;
  end if;
  if v_mime is null or v_mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then raise exception 'Format non accepté (PDF, JPG, PNG ou WebP)'; end if;
  if v_size is null or v_size < 1 or v_size > 10485760 then raise exception 'Fichier trop lourd (10 Mo au maximum)'; end if;
  if exists (select 1 from company_documents where path = p_path) then raise exception 'Ce fichier est déjà enregistré'; end if;
  if (select count(*) from company_documents where owner_id = auth.uid()) >= 8 then raise exception 'Huit pièces au plus : supprimez-en une'; end if;
  insert into company_documents (owner_id, kind, name, path, mime, size_bytes) values (auth.uid(), p_kind, left(coalesce(nullif(btrim(p_name), ''), 'document'), 160), p_path, v_mime, v_size) returning id into v_id;
  return v_id;
end $$;

create or replace function company_submit() returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype; v_missing text[]; v_label text; v_lack text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = auth.uid() for update;
  if not found then raise exception 'Enregistrez d''abord la fiche de l''organisation'; end if;
  if c.status = 'approved' then raise exception 'Organisation déjà vérifiée'; end if;
  if c.status = 'pending' then raise exception 'Votre demande est déjà en cours d''examen'; end if;
  v_missing := _company_missing(auth.uid());
  if cardinality(v_missing) > 0 then raise exception 'Complétez la fiche : % (champs obligatoires avant l''envoi)', array_to_string(v_missing, ', '); end if;
  select string_agg(r ->> 'label', ' ; ' order by (r ->> 'group')::int) into v_lack from jsonb_array_elements(_company_requirements(auth.uid())) r where not (r ->> 'satisfied')::boolean;
  if v_lack is not null then
    select lower(label) into v_label from org_types where code = c.org_type;
    raise exception 'Ajoutez au moins une pièce justificative (%) : %', v_label, v_lack;
  end if;
  update company_profiles set status = 'pending', submitted_at = now(), review_note = null where owner_id = auth.uid();
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'company_review', 'Organisation à vérifier', c.company_name || ' demande sa vérification.', jsonb_build_object('owner', auth.uid()) from profiles a where a.role::text = 'admin';
  return 'pending';
end $$;

create or replace function company_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((select jsonb_agg(to_jsonb(c) || jsonb_build_object('email', u.email, 'account_name', p.name, 'org_config', org_type_config(c.org_type), 'requirements', _company_requirements(c.owner_id),
      'documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime) order by d.created_at) from company_documents d where d.owner_id = c.owner_id), '[]'::jsonb)) order by c.submitted_at)
    from company_profiles c join profiles p on p.id = c.owner_id left join auth.users u on u.id = c.owner_id where c.status = 'pending'), '[]'::jsonb);
end $$;

create or replace function company_decide(p_owner uuid, p_approve boolean, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype; v_status text; v_was text; who text; v_note text := btrim(coalesce(p_note, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into c from company_profiles where owner_id = p_owner and (status = 'pending' or (not p_approve and status = 'approved')) for update;
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  if not p_approve and char_length(v_note) < 3 then raise exception 'Indiquez le motif du refus'; end if;
  v_was := c.status;
  v_status := case when p_approve then 'approved' else 'rejected' end;
  -- la certification du compte suit le statut (déclencheur trg_company_certification)
  update company_profiles set status = v_status, review_note = nullif(left(v_note, 500), ''), reviewed_by = auth.uid(), reviewed_at = now() where owner_id = p_owner;
  insert into notifications (user_id, kind, title, body, data)
    values (p_owner, 'company_review', case when p_approve then 'Organisation vérifiée' when v_was = 'approved' then 'Vérification retirée' else 'Vérification refusée' end,
            case when p_approve then c.company_name || ' est maintenant vérifiée : votre compte est certifié et le badge « Vérifiée » s''affiche sur votre fiche.'
                 else 'Motif : ' || v_note || case when v_was = 'approved' then ' La certification du compte est retirée.' else '' end end,
            jsonb_build_object('status', v_status, 'owner', p_owner));
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Administrateur'), case when p_approve then 'Organisation vérifiée' when v_was = 'approved' then 'Vérification d''organisation retirée' else 'Vérification d''organisation refusée' end, c.company_name, 'Organisations', 'Sensible');
  return v_status;
end $$;
revoke all on function company_queue() from public, anon;
grant execute on function company_queue() to authenticated;
revoke all on function company_decide(uuid, boolean, text) from public, anon;
grant execute on function company_decide(uuid, boolean, text) to authenticated;

-- ============================================================ page publique : type et mission (jamais RCCM, NIU, téléphone, interlocuteur ni pièces)
create or replace function _company_page(p_owner uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); c company_profiles%rowtype; v_mine boolean := false; v_staff boolean := false; v_all boolean; t org_types%rowtype;
begin
  if p_owner is null then return null; end if;
  select * into c from company_profiles where owner_id = p_owner;
  if not found then return null; end if;
  if v_uid is not null then
    v_mine := v_uid = p_owner or company_role_of(p_owner) is not null;
    v_staff := coalesce(current_role_name()::text, '') in ('admin', 'support');
  end if;
  if not (v_mine or v_staff) then
    if c.status <> 'approved' then return null; end if;
    if exists (select 1 from profiles where id = p_owner and coalesce(suspended, false)) then return null; end if;
  end if;
  v_all := v_uid is not null;
  select * into t from org_types where code = c.org_type;
  return jsonb_build_object(
    'owner_id', c.owner_id, 'company_name', c.company_name, 'sector', c.sector, 'size', c.size, 'city', c.city, 'website', c.website,
    'description', c.description, 'founded_year', c.founded_year, 'logo_path', c.logo_path, 'cover_path', c.cover_path,
    'org_type', c.org_type, 'org_type_label', t.label, 'commercial', t.commercial, 'sector_label', t.sector_label, 'mission', c.mission,
    'verified', c.status = 'approved', 'status', case when v_mine or v_staff then c.status else null end, 'mine', v_mine,
    'offers', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'title', o.title, 'kind', o.kind, 'location', o.location, 'deadline', o.deadline) order by o.created_at desc)
                        from (select * from opportunities where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date) order by created_at desc limit 20) o), '[]'::jsonb),
    'contests', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'kind', a.kind, 'deadline', a.deadline) order by a.created_at desc)
                          from (select * from contest_announcements where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date) order by created_at desc limit 20) a), '[]'::jsonb),
    'needs', case when v_all then coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'title', n.title, 'budget_min', n.budget_min, 'budget_max', n.budget_max, 'deadline', n.deadline) order by n.created_at desc)
                          from (select * from missions where client_id = p_owner and status = 'published' and title is not null and kind is distinct from 'mission' order by created_at desc limit 20) n), '[]'::jsonb) else null end,
    'offers_open', (select count(*)::int from opportunities where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date)),
    'contests_open', (select count(*)::int from contest_announcements where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date)),
    'needs_open', case when v_all then (select count(*)::int from missions where client_id = p_owner and status = 'published' and title is not null and kind is distinct from 'mission') else null end,
    'recruits', (select count(*)::int from opportunity_applications x join opportunities o on o.id = x.opportunity_id where o.poster_id = p_owner and x.status = 'hired')
  );
end $$;
revoke all on function _company_page(uuid) from public, anon, authenticated;

-- ============================================================ tableau de bord : type d'organisation
create or replace function company_dashboard(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); c company_profiles%rowtype; pl company_plans%rowtype; t org_types%rowtype;
begin
  select * into c from company_profiles where owner_id = v_owner;
  select * into t from org_types where code = c.org_type;
  select * into pl from company_current_plan(v_owner);
  return jsonb_build_object(
    'owner_id', v_owner, 'my_role', company_role_of(v_owner),
    'company_name', c.company_name, 'status', coalesce(c.status, 'none'), 'review_note', c.review_note, 'plan_name', pl.name,
    'org_type', c.org_type, 'org_type_label', t.label, 'commercial', coalesce(t.commercial, true),
    'plan_ends_at', (select max(ends_at) from company_subscriptions where owner_id = v_owner and status = 'active' and ends_at > now()),
    'needs_open', (select count(*)::int from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress')),
    'needs_draft', (select count(*)::int from missions where client_id = v_owner and status = 'draft'),
    'proposals_new', (select count(*)::int from mission_proposals mp join missions m on m.id = mp.mission_id where m.client_id = v_owner and mp.status = 'submitted'),
    'offers_active', (select count(*)::int from opportunities where poster_id = v_owner and status in ('pending', 'published')),
    'applications_new', (select count(*)::int from opportunity_applications a join opportunities o on o.id = a.opportunity_id where o.poster_id = v_owner and a.status = 'sent'),
    'recruits', (select count(*)::int from opportunity_applications a join opportunities o on o.id = a.opportunity_id where o.poster_id = v_owner and a.status = 'hired'),
    'contests_active', (select count(*)::int from contest_announcements where poster_id = v_owner and status in ('pending', 'published')),
    'members', (select count(*)::int from company_members where owner_id = v_owner and status = 'active') + 1);
end $$;
revoke all on function company_dashboard(uuid) from public, anon;
grant execute on function company_dashboard(uuid) to authenticated;
