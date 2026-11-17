-- Lot F2 (profil Entreprise) — fiche, pièces justificatives, vérification, équipe.
--  E4-2   Un administrateur de l'équipe peut enregistrer la fiche même quand elle porte le logo du propriétaire (chemin déjà enregistré accepté).
--  E4-12  company_get ne renvoie RCCM, téléphone, interlocuteur et motif de refus qu'au propriétaire et aux administrateurs de l'entreprise.
--  E4-13 / E5-13  company_doc_add vérifie l'existence du fichier dans le stockage, son type et son poids ; les pièces d'une demande envoyée ou
--         d'une entreprise vérifiée ne se suppriment plus (sauf par l'administrateur) ; la fiche n'est plus modifiable pendant l'examen.
--  E4-14 / E5-9  Un administrateur d'équipe ne rétrograde ni ne promeut un administrateur, et ne touche pas au propriétaire.
--  E4-15  company_members_list ne révèle pas l'e-mail (ni le nom) des invités en attente aux simples administrateurs ; invitations plafonnées (20 par jour).
--  E5-10  company_role_of ignore les membres suspendus ; les comptes de la plateforme (administration, finance, support, direction, département) ne s'invitent pas ;
--         la liste des membres indique le rôle du compte et sa certification.
--  E5-21 / E6-3  Décision 5 : approuver une fiche certifie le compte (profiles.certification) ; refuser, retirer ou repasser en vérification retire la certification.
--  E5-24  company_decide laisse une trace dans le journal d'audit (la garde 2FA est complétée dans 20261118020200).
-- Retour arrière : recréer company_role_of, company_get, company_save, company_doc_add, company_doc_delete, company_submit, company_decide, company_invite,
--   company_member_set_role et company_members_list depuis 20261114002500, 20261114002900 et 20261116120000 ;
--   drop trigger trg_company_certification on company_profiles; drop function company_sync_certification(); drop table company_invite_log.

-- ============================================================ rôle dans l'entreprise : un membre suspendu n'a plus aucun accès
create or replace function company_role_of(p_owner uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when p_owner = auth.uid() then 'owner'
              else (select m.role from company_members m join profiles p on p.id = m.user_id
                    where m.owner_id = p_owner and m.user_id = auth.uid() and m.status = 'active' and not coalesce(p.suspended, false)) end
$$;
revoke all on function company_role_of(uuid) from public, anon, authenticated;

-- ============================================================ lecture de la fiche : coordonnées sensibles réservées à qui gère la fiche
create or replace function company_get(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); c company_profiles%rowtype; v_role text; j jsonb;
begin
  select * into c from company_profiles where owner_id = v_owner;
  if not found then return null; end if;
  v_role := company_role_of(v_owner);
  j := to_jsonb(c) || jsonb_build_object('my_role', v_role, 'documents', case when v_role in ('owner', 'admin') then coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime, 'size_bytes', d.size_bytes, 'created_at', d.created_at) order by d.created_at desc)
    from company_documents d where d.owner_id = v_owner), '[]'::jsonb) else '[]'::jsonb end);
  if v_role not in ('owner', 'admin') then
    j := j - 'registration_number' - 'phone' - 'contact_name' - 'contact_role' - 'review_note' - 'reviewed_by';
  end if;
  return j;
end $$;
revoke all on function company_get(uuid) from public, anon;
grant execute on function company_get(uuid) to authenticated;

-- ============================================================ enregistrement de la fiche
create or replace function company_save(p jsonb, p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner)); c company_profiles%rowtype;
        v_name text := btrim(coalesce(p->>'company_name', '')); v_site text := nullif(btrim(coalesce(p->>'website', '')), ''); v_status text; v_reg text := btrim(coalesce(p->>'registration_number', ''));
        v_logo text := nullif(p->>'logo_path', '');
begin
  if v_role not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if v_owner = auth.uid() and not company_is_org() then raise exception 'Réservé aux entreprises et organisations'; end if;
  if v_owner <> auth.uid() and not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Fiche introuvable'; end if;
  if char_length(v_name) < 2 then raise exception 'Indiquez le nom de l''entreprise'; end if;
  if v_site is not null and v_site !~* '^https?://[^ ]+$' then raise exception 'Le site doit commencer par https://'; end if;
  if coalesce(p->>'size', '') not in ('', '1-10', '11-50', '51-200', '201-1000', '1000+') then raise exception 'Taille inconnue'; end if;
  if char_length(btrim(coalesce(p->>'contact_name', ''))) > 80 or char_length(btrim(coalesce(p->>'contact_role', ''))) > 80 then raise exception 'L''interlocuteur et sa fonction : 80 caractères au plus'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  if found and c.status = 'pending' then raise exception 'La fiche est en cours de vérification : elle ne peut plus être modifiée avant la décision de l''administrateur'; end if;
  -- logo : déposé dans le dossier de l'appelant, ou déjà enregistré sur la fiche (un administrateur de l'équipe peut renvoyer celui du propriétaire)
  if v_logo is not null and split_part(v_logo, '/', 1) <> auth.uid()::text and v_logo is distinct from c.logo_path then
    raise exception 'Logo invalide : déposez-le d''abord dans votre dossier';
  end if;
  v_status := coalesce(c.status, 'draft');
  if found and c.status = 'approved' and (c.company_name is distinct from v_name or c.registration_number is distinct from v_reg) then v_status := 'pending'; end if;
  insert into company_profiles (owner_id, company_name, sector, size, city, website, phone, contact_name, contact_role, description, founded_year, registration_number, logo_path, status, submitted_at)
  values (v_owner, v_name, left(btrim(coalesce(p->>'sector', '')), 80), coalesce(p->>'size', ''), left(btrim(coalesce(p->>'city', '')), 80), v_site, left(btrim(coalesce(p->>'phone', '')), 30),
          left(btrim(coalesce(p->>'contact_name', '')), 80), left(btrim(coalesce(p->>'contact_role', '')), 80), left(btrim(coalesce(p->>'description', '')), 1500), nullif(p->>'founded_year', '')::int, left(v_reg, 60),
          v_logo, 'draft', null)
  on conflict (owner_id) do update set company_name = excluded.company_name, sector = excluded.sector, size = excluded.size, city = excluded.city, website = excluded.website, phone = excluded.phone,
    contact_name = excluded.contact_name, contact_role = excluded.contact_role, description = excluded.description, founded_year = excluded.founded_year, registration_number = excluded.registration_number,
    logo_path = coalesce(excluded.logo_path, company_profiles.logo_path), status = v_status, updated_at = now();
  if v_status = 'pending' and c.status = 'approved' then
    insert into notifications (user_id, kind, title, body, data)
      select a.id, 'company_review', 'Entreprise à revérifier', v_name || ' a modifié son nom ou son numéro d''immatriculation.', jsonb_build_object('owner', v_owner) from profiles a where a.role::text = 'admin';
    insert into notifications (user_id, kind, title, body, data)
      values (v_owner, 'company_review', 'Fiche repassée en vérification', 'Le nom ou le numéro d''immatriculation a changé : le badge est retiré et la publication reste suspendue jusqu''à la nouvelle approbation de l''administrateur.', jsonb_build_object('owner', v_owner, 'status', 'pending'));
  end if;
  return v_status;
end $$;
revoke all on function company_save(jsonb, uuid) from public, anon;
grant execute on function company_save(jsonb, uuid) to authenticated;

-- ============================================================ pièces justificatives
create or replace function company_doc_add(p_kind text, p_name text, p_path text, p_mime text, p_size integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_meta jsonb; v_mime text := p_mime; v_size int := p_size;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from company_profiles where owner_id = auth.uid()) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  if p_kind is null or p_kind not in ('registration', 'tax', 'mandate', 'attestation', 'other') then raise exception 'Type de pièce inconnu'; end if;
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

-- Suppression : tant que la fiche est en brouillon ou refusée. Une demande envoyée ou approuvée garde ses preuves ; l'administrateur de la plateforme peut intervenir.
create or replace function company_doc_delete(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_path text; v_status text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = 'admin' then
    delete from company_documents where id = p_id returning path into v_path;
  else
    select c.status into v_status from company_documents d join company_profiles c on c.owner_id = d.owner_id where d.id = p_id and d.owner_id = auth.uid();
    if v_status in ('pending', 'approved') then
      raise exception 'Cette pièce a été envoyée pour vérification : elle ne peut plus être supprimée (contactez l''administrateur)';
    end if;
    delete from company_documents where id = p_id and owner_id = auth.uid() returning path into v_path;
  end if;
  if v_path is null then raise exception 'Pièce introuvable'; end if;
  return v_path;
end $$;

-- Envoi pour vérification : fiche complète (message explicite des champs manquants) et au moins une pièce justificative.
create or replace function company_submit() returns text
language plpgsql security definer set search_path = public as $$
declare c company_profiles%rowtype; v_missing text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = auth.uid() for update;
  if not found then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if c.status = 'approved' then raise exception 'Entreprise déjà vérifiée'; end if;
  if c.status = 'pending' then raise exception 'Votre demande est déjà en cours d''examen'; end if;
  if c.sector = '' then v_missing := v_missing || 'le secteur'::text; end if;
  if c.city = '' then v_missing := v_missing || 'la ville'::text; end if;
  if c.contact_name = '' then v_missing := v_missing || 'l''interlocuteur'::text; end if;
  if c.phone = '' then v_missing := v_missing || 'le téléphone'::text; end if;
  if cardinality(v_missing) > 0 then raise exception 'Complétez la fiche : % (champs obligatoires avant l''envoi)', array_to_string(v_missing, ', '); end if;
  if not exists (select 1 from company_documents where owner_id = auth.uid()) then raise exception 'Ajoutez au moins une pièce justificative (immatriculation, numéro fiscal…)'; end if;
  update company_profiles set status = 'pending', submitted_at = now(), review_note = null where owner_id = auth.uid();
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'company_review', 'Entreprise à vérifier', c.company_name || ' demande sa vérification.', jsonb_build_object('owner', auth.uid()) from profiles a where a.role::text = 'admin';
  return 'pending';
end $$;

-- ============================================================ décision de l'administrateur : approbation ou refus/retrait, journal d'audit
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
    values (p_owner, 'company_review', case when p_approve then 'Entreprise vérifiée' when v_was = 'approved' then 'Vérification retirée' else 'Vérification refusée' end,
            case when p_approve then c.company_name || ' est maintenant vérifiée : votre compte est certifié et le badge « Vérifiée » s''affiche sur votre fiche.'
                 else 'Motif : ' || v_note || case when v_was = 'approved' then ' La certification du compte est retirée.' else '' end end,
            jsonb_build_object('status', v_status, 'owner', p_owner));
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Administrateur'), case when p_approve then 'Entreprise vérifiée' when v_was = 'approved' then 'Vérification d''entreprise retirée' else 'Vérification d''entreprise refusée' end, c.company_name, 'Entreprises', 'Sensible');
  return v_status;
end $$;
revoke all on function company_decide(uuid, boolean, text) from public, anon;
grant execute on function company_decide(uuid, boolean, text) to authenticated;

-- ============================================================ décision 5 : vérification unique (la fiche approuvée vaut certification du compte)
create or replace function company_sync_certification() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text;
begin
  if tg_op = 'UPDATE' then
    if new.status is not distinct from old.status then return null; end if;
  end if;
  select role::text into r from profiles where id = new.owner_id;
  if r is null or r not in ('company', 'other') then return null; end if;
  perform set_config('app.cert_rpc', '1', true);
  if new.status = 'approved' then
    update profiles set certification = 'approved', certification_decided_by = new.reviewed_by, certification_decided_at = now()
      where id = new.owner_id and certification <> 'approved';
    update certification_requests set status = 'approved', decision_note = 'Entreprise vérifiée', decided_by = new.reviewed_by, decided_at = now()
      where user_id = new.owner_id and status in ('pending', 'review');
  elsif tg_op = 'UPDATE' then
    if old.status = 'approved' then
      update profiles set certification = 'revoked', certification_decided_by = new.reviewed_by, certification_decided_at = now()
        where id = new.owner_id and certification = 'approved';
    end if;
  end if;
  perform set_config('app.cert_rpc', '', true);
  return null;
end $$;
revoke execute on function company_sync_certification() from public, anon, authenticated;
drop trigger if exists trg_company_certification on company_profiles;
create trigger trg_company_certification after insert or update of status on company_profiles for each row execute function company_sync_certification();

-- Les entreprises déjà vérifiées avant ce lot sont certifiées (une seule vérification).
do $$ begin
  perform set_config('app.cert_rpc', '1', true);
  update profiles p set certification = 'approved', certification_decided_at = coalesce(p.certification_decided_at, now())
    from company_profiles c where c.owner_id = p.id and c.status = 'approved' and p.role::text in ('company', 'other') and p.certification <> 'approved';
  perform set_config('app.cert_rpc', '', true);
end $$;

-- ============================================================ équipe : liste des membres
create or replace function company_members_list(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner));
begin
  return jsonb_build_object('my_role', v_role, 'owner', jsonb_build_object('user_id', v_owner, 'name', display_name(v_owner)),
    'members', coalesce((select jsonb_agg(jsonb_build_object(
        'user_id', m.user_id,
        'name', case when m.status = 'invited' and not (v_role = 'owner' or m.invited_by = auth.uid()) then 'Invitation en attente' else display_name(m.user_id) end,
        'email', case when m.status = 'active' and v_role in ('owner', 'admin') then (select email from profiles where id = m.user_id)
                      when m.status = 'invited' and (v_role = 'owner' or m.invited_by = auth.uid()) then (select email from profiles where id = m.user_id) end,
        'role', m.role, 'status', m.status, 'joined_at', m.joined_at,
        'account_role', case when m.status = 'active' then (select pr.role::text from profiles pr where pr.id = m.user_id) end,
        'certified', case when m.status = 'active' then coalesce((select pr.certification::text = 'approved' from profiles pr where pr.id = m.user_id), false) end,
        'invited_by_me', m.invited_by = auth.uid()) order by m.status, m.invited_at) from company_members m where m.owner_id = v_owner), '[]'::jsonb));
end $$;
revoke all on function company_members_list(uuid) from public, anon;
grant execute on function company_members_list(uuid) to authenticated;

-- ============================================================ équipe : changement de rôle
-- L'administrateur d'équipe ne modifie que les finances et lecteurs ; seul le propriétaire promeut ou rétrograde un administrateur.
create or replace function company_member_set_role(p_user uuid, p_role text, p_owner uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner)); m company_members%rowtype;
begin
  if v_role not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if p_role not in ('admin', 'finance', 'viewer') then raise exception 'Rôle inconnu'; end if;
  if p_user = v_owner then raise exception 'Le rôle du propriétaire ne se modifie pas'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas modifier votre propre rôle'; end if;
  select * into m from company_members where owner_id = v_owner and user_id = p_user;
  if not found then raise exception 'Membre introuvable'; end if;
  if v_role = 'admin' and (m.role = 'admin' or p_role = 'admin') then raise exception 'Seul le propriétaire promeut ou rétrograde un administrateur'; end if;
  update company_members set role = p_role where id = m.id;
end $$;
revoke all on function company_member_set_role(uuid, text, uuid) from public, anon;
grant execute on function company_member_set_role(uuid, text, uuid) to authenticated;

-- ============================================================ équipe : invitation
create table if not exists company_invite_log (
  id bigserial primary key,
  owner_id uuid not null references company_profiles(owner_id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists company_invite_log_owner on company_invite_log (owner_id, at desc);
alter table company_invite_log enable row level security;
revoke all on company_invite_log from anon, authenticated;

create or replace function company_invite(p_email text, p_role text default 'viewer', p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_target uuid; v_name text; v_email text := lower(btrim(coalesce(p_email, ''))); m company_members%rowtype; v_trole text; v_prev boolean;
begin
  if company_role_of(v_owner) not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if not company_team_allowed(v_owner) then
    raise exception 'L''invitation de collègues fait partie de l''offre Entreprise (ou d''un forfait d''entreprise payant). Les membres déjà dans l''équipe gardent leur accès.';
  end if;
  if p_role not in ('admin', 'finance', 'viewer') then raise exception 'Rôle inconnu'; end if;
  if p_role = 'admin' and company_role_of(v_owner) <> 'owner' then raise exception 'Seul le propriétaire nomme un administrateur'; end if;
  if v_email = '' or v_email !~ '^[^@ ]+@[^@ ]+$' then raise exception 'Saisissez l''e-mail de la personne'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if (select count(*) from company_members where owner_id = v_owner) >= 10 then raise exception 'Dix membres au plus'; end if;
  -- chaque tentative compte, qu'un compte existe ou non (pas d'oracle sur les adresses)
  if (select count(*) from company_invite_log where owner_id = v_owner and at > now() - interval '1 day') >= 20 then
    raise exception 'Trop d''invitations aujourd''hui (20 au plus par jour) : réessayez demain';
  end if;
  insert into company_invite_log (owner_id) values (v_owner);
  select id, role::text into v_target, v_trole from profiles where lower(email) = v_email and not suspended;
  -- compte inconnu, propriétaire, membre déjà actif ou compte de la plateforme : même réponse, sans invitation ni notification
  if v_target is null or v_target = v_owner or v_trole in ('admin', 'finance', 'support', 'direction', 'dept', 'visitor')
     or exists (select 1 from company_members where owner_id = v_owner and user_id = v_target and status = 'active') then
    return 'invited';
  end if;
  select * into m from company_members where owner_id = v_owner and user_id = v_target;
  v_prev := found;
  insert into company_members (owner_id, user_id, role, status, invited_by) values (v_owner, v_target, p_role, 'invited', auth.uid())
  on conflict (owner_id, user_id) do update set role = excluded.role, status = 'invited', invited_by = auth.uid(), invited_at = now();
  -- une invitation déjà envoyée dans les 24 h n'est pas renotifiée
  if v_prev and m.status = 'invited' and m.invited_at > now() - interval '1 day' then return 'invited'; end if;
  select company_name into v_name from company_profiles where owner_id = v_owner;
  insert into notifications (user_id, kind, title, body, data)
    values (v_target, 'company_team', 'Invitation à rejoindre une entreprise', display_name(auth.uid()) || ' vous invite à rejoindre l''équipe de « ' || v_name || ' ».', jsonb_build_object('owner', v_owner, 'invitation', true));
  return 'invited';
end $$;
revoke all on function company_invite(text, text, uuid) from public, anon;
grant execute on function company_invite(text, text, uuid) to authenticated;
