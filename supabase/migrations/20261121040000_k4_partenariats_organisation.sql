-- Lot K4 (Partenariats et Organisation) 1/2 — rattachement d'une ORGANISATION aux partenariats institutionnels (direction) et aux partenariats de département.
--   * colonnes organization_id (fk company_profiles.owner_id : fiche d'organisation), organization_name (nom public ou nom libre d'une organisation NON inscrite),
--     org_response / org_response_note / org_responded_at / org_responded_by (accord ou contestation de l'organisation) sur institutional_partnerships et department_partnerships ;
--   * trigger de garde : une organisation rattachée doit avoir une fiche APPROUVÉE dont le titulaire n'est pas suspendu ; le nom suit la fiche ; la réponse de l'organisation
--     repasse « en attente » à chaque nouveau rattachement ou activation ; l'organisation (titulaire et administrateurs de son équipe) est notifiée à chaque étape visible ;
--   * partnership_org_search(q, limit) : recherche parmi les fiches APPROUVÉES (nom public, type, ville seulement), réservée à la direction, à l'administrateur et à un département rattaché ;
--   * partnership_save recréée (la direction et l'administrateur décident, un département PROPOSE pour son département) ; partnership_decide ne notifie plus l'organisation
--     (le trigger s'en charge : un refus n'est jamais communiqué à une organisation qui ne l'a jamais vu) ; partnerships_list / dept_partnerships / direction_dept_partnerships renvoient l'organisation et sa réponse ;
--     dept_partnership_save accepte organization_id ;
--   * org_partnerships_list(p_owner) : l'organisation (propriétaire ou membre) voit SES partenariats décidés ; org_partnership_respond(source, id, accepter|contester, motif) :
--     propriétaire et administrateurs de l'organisation seulement, direction/département/auteur prévenus, journal d'audit.
-- Retour arrière : drop function org_partnership_respond(text, uuid, text, text), org_partnerships_list(uuid), partnership_org_search(text, int), _org_notify(uuid, text, text, jsonb),
--   _partnership_org_guard(), _partnership_org_after(), _org_kind_of(text) ; drop trigger trg_partnership_org_guard / trg_partnership_org_after sur les deux tables ;
--   alter table institutional_partnerships drop column organization_id, organization_name, org_response, org_response_note, org_responded_at, org_responded_by (idem department_partnerships) ;
--   recréer partnership_save, partnership_decide, partnerships_list (20261120030100), dept_partnership_save, dept_partnerships (20261120020200), direction_dept_partnerships (20261120030200).

-- ------------------------------------------------------------------ colonnes
alter table institutional_partnerships add column if not exists organization_id uuid references company_profiles(owner_id) on delete set null;
alter table institutional_partnerships add column if not exists organization_name text not null default '' check (char_length(organization_name) <= 160);
alter table institutional_partnerships add column if not exists org_response text not null default 'none' check (org_response in ('none', 'pending', 'accepted', 'contested'));
alter table institutional_partnerships add column if not exists org_response_note text check (org_response_note is null or char_length(org_response_note) <= 1000);
alter table institutional_partnerships add column if not exists org_responded_at timestamptz;
alter table institutional_partnerships add column if not exists org_responded_by uuid references profiles(id) on delete set null;

alter table department_partnerships add column if not exists organization_id uuid references company_profiles(owner_id) on delete set null;
alter table department_partnerships add column if not exists organization_name text not null default '' check (char_length(organization_name) <= 160);
alter table department_partnerships add column if not exists org_response text not null default 'none' check (org_response in ('none', 'pending', 'accepted', 'contested'));
alter table department_partnerships add column if not exists org_response_note text check (org_response_note is null or char_length(org_response_note) <= 1000);
alter table department_partnerships add column if not exists org_responded_at timestamptz;
alter table department_partnerships add column if not exists org_responded_by uuid references profiles(id) on delete set null;

create index if not exists institutional_partnerships_org on institutional_partnerships (organization_id) where organization_id is not null;
create index if not exists department_partnerships_org on department_partnerships (organization_id) where organization_id is not null;

-- Reprise de l'existant : le lien company_owner_id devient organization_id quand la fiche existe ; les autres partenaires sont des organisations non inscrites (nom libre).
update institutional_partnerships ip set organization_id = ip.company_owner_id
  where ip.organization_id is null and ip.company_owner_id is not null and exists (select 1 from company_profiles c where c.owner_id = ip.company_owner_id);
update institutional_partnerships ip set organization_name = coalesce((select c.company_name from company_profiles c where c.owner_id = ip.organization_id), ip.name)
  where ip.organization_name = '';
update institutional_partnerships ip set org_response = 'pending' where ip.organization_id is not null and ip.status = 'active' and ip.org_response = 'none';
update department_partnerships dp set organization_name = dp.partner_name where dp.organization_name = '';

-- ------------------------------------------------------------------ outils internes
create or replace function _org_kind_of(p_org_type text) returns text
language sql immutable set search_path = public as $$
  select case coalesce(p_org_type, '')
    when 'entreprise_commerciale' then 'entreprise' when 'association' then 'association' when 'ong' then 'ong'
    when 'institution' then 'institution' else 'autre' end
$$;
revoke all on function _org_kind_of(text) from public, anon, authenticated;

-- Prévient le titulaire de la fiche et les administrateurs actifs de son équipe (jamais un compte suspendu).
create or replace function _org_notify(p_owner uuid, p_title text, p_body text, p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if p_owner is null then return; end if;
  for r in
    select p_owner as id where exists (select 1 from profiles o where o.id = p_owner and not coalesce(o.suspended, false))
    union
    select m.user_id from company_members m join profiles pr on pr.id = m.user_id
      where m.owner_id = p_owner and m.status = 'active' and m.role = 'admin' and not coalesce(pr.suspended, false)
  loop
    perform notify_user(r.id, 'org_partnership', p_title, p_body, coalesce(p_data, '{}'::jsonb) || jsonb_build_object('owner', p_owner));
  end loop;
end $$;
revoke all on function _org_notify(uuid, text, text, jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------------ garde : organisation approuvée, nom, réponse
create or replace function _partnership_org_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_active text := case when tg_table_name = 'institutional_partnerships' then 'active' else 'actif' end;
        v_status text; v_cname text; v_status_old text; v_label text;
begin
  v_status := to_jsonb(new)->>'status';
  if tg_table_name = 'institutional_partnerships' then
    if new.organization_id is null and new.company_owner_id is not null then new.organization_id := new.company_owner_id; end if;
    new.company_owner_id := new.organization_id;
  end if;
  v_label := coalesce(to_jsonb(new)->>'name', to_jsonb(new)->>'partner_name');
  if new.organization_id is not null and (tg_op = 'INSERT' or new.organization_id is distinct from old.organization_id) then
    select c.company_name into v_cname from company_profiles c join profiles p on p.id = c.owner_id
      where c.owner_id = new.organization_id and c.status = 'approved' and not coalesce(p.suspended, false);
    if v_cname is null then raise exception 'Organisation introuvable ou non approuvée'; end if;
  elsif new.organization_id is not null then
    select c.company_name into v_cname from company_profiles c where c.owner_id = new.organization_id;
  end if;
  if new.organization_id is not null then
    new.organization_name := coalesce(v_cname, nullif(new.organization_name, ''), v_label);
    if tg_table_name = 'institutional_partnerships' then new.name := new.organization_name; else new.partner_name := new.organization_name; end if;
  elsif nullif(btrim(new.organization_name), '') is null or tg_op = 'INSERT' or v_label is distinct from coalesce(to_jsonb(old)->>'name', to_jsonb(old)->>'partner_name') then
    new.organization_name := left(coalesce(v_label, ''), 160);
  end if;
  v_status_old := case when tg_op = 'UPDATE' then to_jsonb(old)->>'status' end;
  if new.organization_id is null then
    new.org_response := 'none'; new.org_response_note := null; new.org_responded_at := null; new.org_responded_by := null;
  elsif tg_op = 'INSERT' or new.organization_id is distinct from old.organization_id then
    new.org_response := case when v_status = v_active then 'pending' else 'none' end;
    new.org_response_note := null; new.org_responded_at := null; new.org_responded_by := null;
  elsif v_status = v_active and v_status_old is distinct from v_active and new.org_response = 'none' then
    new.org_response := 'pending';
  end if;
  return new;
end $$;
revoke all on function _partnership_org_guard() from public, anon, authenticated;

-- Notification de l'organisation : rattachement ou validation, suspension, reprise, clôture.
create or replace function _partnership_org_after() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_active text := case when tg_table_name = 'institutional_partnerships' then 'active' else 'actif' end;
        v_status text := to_jsonb(new)->>'status'; v_old text := case when tg_op = 'UPDATE' then to_jsonb(old)->>'status' end;
        v_label text := coalesce(to_jsonb(new)->>'name', to_jsonb(new)->>'partner_name');
        v_closed text := case when tg_table_name = 'institutional_partnerships' then 'ended' else 'termine' end;
        v_data jsonb := jsonb_build_object('partnership', new.id, 'source', case when tg_table_name = 'institutional_partnerships' then 'institution' else 'department' end);
        v_note text := nullif(btrim(coalesce(to_jsonb(new)->>'decision_note', '')), '');
begin
  if tg_op = 'UPDATE' and old.organization_id is not null and new.organization_id is distinct from old.organization_id
     and to_jsonb(old)->>'status' in (v_active, 'suspended', v_closed) then
    perform _org_notify(old.organization_id, 'Partenariat dissocié', 'Le partenariat « ' || v_label || ' » n''est plus rattaché à votre organisation.', v_data);
  end if;
  if new.organization_id is null then return new; end if;
  if v_status = v_active and (tg_op = 'INSERT' or new.organization_id is distinct from old.organization_id or v_old is distinct from v_active) then
    if v_old = 'suspended' and new.organization_id is not distinct from old.organization_id then
      perform _org_notify(new.organization_id, 'Partenariat repris', 'Le partenariat « ' || v_label || ' » avec l''établissement est repris.', v_data);
    elsif v_old = 'proposed' and new.organization_id is not distinct from old.organization_id then
      perform _org_notify(new.organization_id, 'Partenariat validé',
        'Votre partenariat « ' || v_label || ' » avec l''établissement est validé. Ouvrez « Partenariats » pour l''accepter ou le contester.', v_data);
    else
      perform _org_notify(new.organization_id, 'Partenariat avec l''établissement',
        'Un partenariat « ' || v_label || ' » est actif avec votre organisation. Ouvrez « Partenariats » pour l''accepter ou le contester.', v_data);
    end if;
  elsif tg_op = 'UPDATE' and new.organization_id is not distinct from old.organization_id and v_status is distinct from v_old then
    if v_status = 'suspended' then
      perform _org_notify(new.organization_id, 'Partenariat suspendu', 'Le partenariat « ' || v_label || ' » est suspendu' || coalesce('. Motif : ' || v_note, '.'), v_data);
    elsif v_status = v_closed and v_old in (v_active, 'suspended') then
      perform _org_notify(new.organization_id, 'Partenariat clos', 'Le partenariat « ' || v_label || ' » avec l''établissement est clos' || coalesce('. Motif : ' || v_note, '.'), v_data);
    end if;
  end if;
  return new;
end $$;
revoke all on function _partnership_org_after() from public, anon, authenticated;

drop trigger if exists trg_partnership_org_guard on institutional_partnerships;
create trigger trg_partnership_org_guard before insert or update on institutional_partnerships for each row execute function _partnership_org_guard();
drop trigger if exists trg_partnership_org_guard on department_partnerships;
create trigger trg_partnership_org_guard before insert or update on department_partnerships for each row execute function _partnership_org_guard();
drop trigger if exists trg_partnership_org_after on institutional_partnerships;
create trigger trg_partnership_org_after after insert or update on institutional_partnerships for each row execute function _partnership_org_after();
drop trigger if exists trg_partnership_org_after on department_partnerships;
create trigger trg_partnership_org_after after insert or update on department_partnerships for each row execute function _partnership_org_after();

-- ------------------------------------------------------------------ recherche d'une organisation approuvée (nom public, type, ville seulement)
create or replace function partnership_org_search(p_q text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_q text := btrim(coalesce(p_q, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('direction', 'admin', 'dept') then raise exception 'Action non autorisée'; end if;
  if v_role = 'dept' and _dept_id() is null then raise exception 'Aucun département n''est rattaché à votre compte'; end if;
  if char_length(v_q) > 80 then raise exception 'Recherche trop longue (80 caractères au plus)'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.owner_id, 'name', x.company_name, 'org_type', x.org_type, 'type_label', x.type_label, 'city', x.city) order by x.company_name)
    from (
      select c.owner_id, c.company_name, c.org_type, t.label as type_label, c.city
      from company_profiles c join profiles p on p.id = c.owner_id left join org_types t on t.code = c.org_type
      where c.status = 'approved' and not coalesce(p.suspended, false)
        and (v_q = '' or c.company_name ilike '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%')
      order by c.company_name limit least(greatest(coalesce(p_limit, 20), 1), 30)
    ) x
  ), '[]'::jsonb);
end $$;
revoke all on function partnership_org_search(text, int) from public, anon;
grant execute on function partnership_org_search(text, int) to authenticated;

-- ------------------------------------------------------------------ partenariats institutionnels : enregistrement
create or replace function partnership_save(
  p_id uuid, p_name text, p_kind text, p_department uuid, p_company_owner uuid, p_contact_name text, p_contact_email text, p_contact_phone text,
  p_objective text, p_domains text[], p_starts date, p_ends date) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(current_role_name()::text, '');
  v_name text := btrim(coalesce(p_name, ''));
  v_kind text := p_kind;
  v_email text := btrim(coalesce(p_contact_email, ''));
  v_dept uuid; v_my uuid; v_id uuid; v_ex institutional_partnerships%rowtype; v_who text; v_org record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('direction', 'admin', 'dept') then raise exception 'Action non autorisée'; end if;
  if p_company_owner is not null then
    select c.company_name, c.org_type into v_org from company_profiles c join profiles pr on pr.id = c.owner_id
      where c.owner_id = p_company_owner and c.status = 'approved' and not coalesce(pr.suspended, false);
    if not found then raise exception 'Organisation introuvable ou non approuvée'; end if;
    v_name := v_org.company_name;
    v_kind := _org_kind_of(v_org.org_type);
  end if;
  if char_length(v_name) < 2 or char_length(v_name) > 160 then raise exception 'Nom du partenaire : 2 à 160 caractères'; end if;
  if coalesce(v_kind, '') not in ('entreprise', 'association', 'ong', 'institution', 'universite', 'collectivite', 'autre') then raise exception 'Type de partenaire invalide'; end if;
  if v_email <> '' and v_email !~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$' then raise exception 'Adresse e-mail du contact invalide'; end if;
  if p_starts is not null and p_ends is not null and p_ends < p_starts then raise exception 'La date de fin précède la date de début'; end if;
  if char_length(coalesce(p_objective, '')) > 2000 then raise exception 'Objectif trop long (2000 caractères maximum)'; end if;
  if cardinality(coalesce(p_domains, '{}')) > 8 then raise exception '8 domaines au maximum'; end if;
  select name into v_who from profiles where id = auth.uid();
  if v_role = 'dept' then
    v_my := _dept_id();
    if v_my is null then raise exception 'Aucun département n''est rattaché à votre compte'; end if;
    v_dept := v_my;
  else
    v_dept := p_department;
    if v_dept is not null and not exists (select 1 from departments where id = v_dept) then raise exception 'Département introuvable'; end if;
  end if;
  if p_id is null then
    insert into institutional_partnerships (name, kind, department_id, organization_id, organization_name, contact_name, contact_email, contact_phone, objective, domains, starts_on, ends_on, proposed_by)
    values (v_name, v_kind, v_dept, p_company_owner, v_name, left(btrim(coalesce(p_contact_name, '')), 120), v_email, left(btrim(coalesce(p_contact_phone, '')), 30),
            btrim(coalesce(p_objective, '')), coalesce(p_domains, '{}'), p_starts, p_ends, auth.uid())
    returning id into v_id;
    insert into institutional_validations (kind, subject_id, department_id, title, details, requested_by)
    values ('partnership', v_id, v_dept, left('Partenariat : ' || v_name, 160), btrim(coalesce(p_objective, '')), auth.uid());
    insert into audit_log (actor, action, target, category, level) values (coalesce(v_who, 'Direction'), 'Partenariat proposé : ' || v_name, v_id::text, 'Institution', 'Info');
    if v_role = 'dept' then
      perform _inst_notify_direction('Partenariat à valider', coalesce(v_who, 'Un département') || ' propose le partenariat « ' || v_name || ' »'
        || case when p_company_owner is null then ' (organisation non inscrite).' else ' avec une organisation inscrite.' end, jsonb_build_object('partnership', v_id));
    end if;
    return v_id;
  end if;
  select * into v_ex from institutional_partnerships where id = p_id for update;
  if not found then raise exception 'Partenariat introuvable'; end if;
  if v_role = 'dept' then
    if v_ex.department_id is distinct from v_my or v_ex.proposed_by is distinct from auth.uid() or v_ex.status <> 'proposed' then
      raise exception 'Seule votre proposition en attente de validation peut être modifiée';
    end if;
  elsif v_ex.status not in ('proposed', 'active', 'suspended') then
    raise exception 'Ce partenariat est clos : il ne peut plus être modifié';
  end if;
  update institutional_partnerships set
    name = v_name, kind = v_kind, department_id = v_dept, organization_id = p_company_owner, organization_name = v_name,
    contact_name = left(btrim(coalesce(p_contact_name, '')), 120), contact_email = v_email, contact_phone = left(btrim(coalesce(p_contact_phone, '')), 30),
    objective = btrim(coalesce(p_objective, '')), domains = coalesce(p_domains, '{}'), starts_on = p_starts, ends_on = p_ends, updated_at = now()
  where id = p_id;
  update institutional_validations set title = left('Partenariat : ' || v_name, 160), details = btrim(coalesce(p_objective, '')), department_id = v_dept
  where kind = 'partnership' and subject_id = p_id and status = 'pending';
  if v_ex.organization_id is distinct from p_company_owner then
    insert into audit_log (actor, action, target, category, level) values (coalesce(v_who, 'Direction'), 'Organisation du partenariat modifiée : ' || v_name, p_id::text, 'Institution', 'Info');
  end if;
  return p_id;
end $$;

-- ------------------------------------------------------------------ partenariats institutionnels : décision (l'organisation est prévenue par le trigger)
create or replace function partnership_decide(p_id uuid, p_action text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_ex institutional_partnerships%rowtype; v_new text; v_note text := btrim(coalesce(p_note, '')); v_who text; v_label text;
begin
  perform _inst_check_direction();
  select * into v_ex from institutional_partnerships where id = p_id for update;
  if not found then raise exception 'Partenariat introuvable'; end if;
  if coalesce(p_action, '') not in ('approve', 'reject', 'suspend', 'resume', 'end') then raise exception 'Décision inconnue'; end if;
  if p_action in ('approve', 'reject') and v_ex.status <> 'proposed' then raise exception 'Ce partenariat n''est plus en attente de validation'; end if;
  if p_action = 'suspend' and v_ex.status <> 'active' then raise exception 'Seul un partenariat actif peut être suspendu'; end if;
  if p_action = 'resume' and v_ex.status <> 'suspended' then raise exception 'Seul un partenariat suspendu peut être repris'; end if;
  if p_action = 'end' and v_ex.status not in ('active', 'suspended') then raise exception 'Seul un partenariat actif ou suspendu peut être clos'; end if;
  if p_action in ('reject', 'suspend', 'end') and char_length(v_note) < 5 then raise exception 'Un motif d''au moins 5 caractères est obligatoire'; end if;
  if char_length(v_note) > 1000 then raise exception 'Motif trop long (1000 caractères maximum)'; end if;
  if p_action in ('approve', 'resume') and v_ex.organization_id is not null
     and not exists (select 1 from company_profiles c join profiles pr on pr.id = c.owner_id where c.owner_id = v_ex.organization_id and c.status = 'approved' and not coalesce(pr.suspended, false)) then
    raise exception 'L''organisation rattachée n''est plus approuvée : corrigez le partenariat avant de le valider';
  end if;
  v_new := case p_action when 'approve' then 'active' when 'reject' then 'rejected' when 'suspend' then 'suspended' when 'resume' then 'active' else 'ended' end;
  v_label := case p_action when 'approve' then 'validé' when 'reject' then 'refusé' when 'suspend' then 'suspendu' when 'resume' then 'repris' else 'clos' end;
  update institutional_partnerships set status = v_new, decision_note = nullif(v_note, ''), decided_by = auth.uid(), decided_at = now(), updated_at = now() where id = p_id;
  if p_action in ('approve', 'reject') then
    update institutional_validations set status = case when p_action = 'approve' then 'approved' else 'rejected' end, decision_note = nullif(v_note, ''), decided_by = auth.uid(), decided_at = now()
    where kind = 'partnership' and subject_id = p_id and status = 'pending';
  end if;
  select name into v_who from profiles where id = auth.uid();
  insert into institutional_decision_log (kind, subject_id, title, action, note, department_id, actor_id, actor_name)
  values ('partnership', p_id, v_ex.name, 'Partenariat ' || v_label, nullif(v_note, ''), v_ex.department_id, auth.uid(), coalesce(v_who, ''));
  insert into audit_log (actor, action, target, category, level) values (coalesce(v_who, 'Direction'), 'Partenariat ' || v_label || ' : ' || v_ex.name, p_id::text, 'Institution', 'Sensible');
  perform notify_user(v_ex.proposed_by, 'institution', 'Partenariat ' || v_label, '« ' || v_ex.name || ' » : partenariat ' || v_label || case when v_note <> '' then '. Motif : ' || v_note else '' end, jsonb_build_object('partnership', p_id));
  return v_new;
end $$;

-- ------------------------------------------------------------------ partenariats institutionnels : liste (direction, administrateur, département ; organisation : les siens)
create or replace function partnerships_list(p_status text default null, p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_my uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('direction', 'admin', 'dept', 'company', 'other') then raise exception 'Action non autorisée'; end if;
  if v_role = 'dept' then
    v_my := _dept_id();
    if v_my is null then return '[]'::jsonb; end if;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', x.id, 'name', x.name, 'kind', x.kind, 'status', x.status, 'department_id', x.department_id, 'department', x.department,
      'company_owner_id', x.organization_id, 'organization_id', x.organization_id, 'organization_name', x.organization_name, 'company', x.company,
      'organization_registered', x.organization_id is not null,
      'org_response', case when v_role in ('direction', 'admin', 'dept') then x.org_response else null end,
      'org_response_note', case when v_role in ('direction', 'admin', 'dept') then x.org_response_note else null end,
      'org_responded_at', case when v_role in ('direction', 'admin', 'dept') then x.org_responded_at else null end,
      'contact_name', x.contact_name, 'contact_email', x.contact_email, 'contact_phone', x.contact_phone,
      'objective', x.objective, 'domains', to_jsonb(x.domains), 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'decision_note', x.decision_note,
      'decided_at', x.decided_at, 'proposer', x.proposer, 'mine', x.proposed_by = auth.uid(), 'created_at', x.created_at
    ) order by case x.status when 'proposed' then 0 when 'active' then 1 when 'suspended' then 2 else 3 end, x.created_at desc)
    from (
      select ip.*, d.name as department, coalesce(cp.company_name, ip.organization_name) as company, pr.name as proposer
      from institutional_partnerships ip
      left join departments d on d.id = ip.department_id
      left join company_profiles cp on cp.owner_id = ip.organization_id
      left join profiles pr on pr.id = ip.proposed_by
      where (p_status is null or ip.status = p_status)
        and case
              when v_role in ('direction', 'admin') then (p_department is null or ip.department_id = p_department)
              when v_role = 'dept' then ip.department_id = v_my
              else ip.organization_id = auth.uid() and ip.status in ('active', 'suspended', 'ended')
            end
      order by ip.created_at desc limit 300
    ) x
  ), '[]'::jsonb);
end $$;

-- ------------------------------------------------------------------ partenariats de département
create or replace function dept_partnership_save(p jsonb, p_department uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); v_id uuid; old department_partnerships; v_name text; v_kind text; v_status text; v_mail text; v_phone text;
  v_start date; v_end date; v_amount int; v_students int; r record;
  v_has_org boolean := p ? 'organization_id'; v_org uuid; v_cname text;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if p is null or jsonb_typeof(p) <> 'object' then raise exception 'Fiche invalide'; end if;
  v_id := nullif(p->>'id', '')::uuid;
  if v_id is not null then
    select * into old from department_partnerships where id = v_id;
    if old.id is null or (v is not null and old.department_id <> v) then raise exception 'Partenariat introuvable dans ce département'; end if;
    v := old.department_id;
  end if;
  if v is null then raise exception 'Indiquez le département'; end if;
  v_org := case when v_has_org then nullif(p->>'organization_id', '')::uuid else old.organization_id end;
  if v_org is not null then
    select c.company_name into v_cname from company_profiles c join profiles pr on pr.id = c.owner_id
      where c.owner_id = v_org and c.status = 'approved' and not coalesce(pr.suspended, false);
    if v_cname is null then raise exception 'Organisation introuvable ou non approuvée'; end if;
  end if;
  v_name := coalesce(v_cname, btrim(coalesce(p->>'partner_name', '')));
  v_kind := coalesce(nullif(p->>'kind', ''), 'convention');
  v_status := coalesce(nullif(p->>'status', ''), 'prospect');
  v_mail := lower(btrim(coalesce(p->>'contact_email', '')));
  v_phone := btrim(coalesce(p->>'contact_phone', ''));
  if char_length(v_name) not between 2 and 120 then raise exception 'Nom du partenaire : 2 à 120 caractères'; end if;
  if v_kind not in ('stage', 'convention', 'sponsoring', 'atelier', 'recherche', 'mecenat', 'autre') then raise exception 'Type de partenariat inconnu'; end if;
  if v_status not in ('prospect', 'negociation', 'actif', 'termine', 'abandonne') then raise exception 'Statut inconnu'; end if;
  if v_mail <> '' and v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Adresse e-mail invalide'; end if;
  if v_phone <> '' and v_phone !~ '^[0-9+()\s.-]{6,30}$' then raise exception 'Numéro de téléphone invalide'; end if;
  v_start := nullif(p->>'starts_on', '')::date;
  v_end := nullif(p->>'ends_on', '')::date;
  if v_start is not null and v_end is not null and v_end < v_start then raise exception 'La fin ne peut pas précéder le début'; end if;
  v_amount := coalesce(nullif(p->>'amount', '')::int, 0);
  v_students := coalesce(nullif(p->>'students', '')::int, 0);
  if v_amount < 0 or v_students < 0 then raise exception 'Montant et effectif ne peuvent pas être négatifs'; end if;
  if char_length(coalesce(p->>'description', '')) > 2000 then raise exception 'Description : 2000 caractères au plus'; end if;
  if v_id is null then
    insert into department_partnerships (department_id, partner_name, organization_id, organization_name, kind, status, contact_name, contact_email, contact_phone, description, starts_on, ends_on, amount, students, created_by)
    values (v, v_name, v_org, v_name, v_kind, v_status, left(btrim(coalesce(p->>'contact_name', '')), 120), v_mail, v_phone, btrim(coalesce(p->>'description', '')), v_start, v_end, v_amount, v_students, auth.uid())
    returning id into v_id;
  else
    update department_partnerships set partner_name = v_name, organization_id = v_org, organization_name = v_name, kind = v_kind, status = v_status, contact_name = left(btrim(coalesce(p->>'contact_name', '')), 120), contact_email = v_mail, contact_phone = v_phone,
      description = btrim(coalesce(p->>'description', '')), starts_on = v_start, ends_on = v_end, amount = v_amount, students = v_students, updated_at = now() where id = v_id;
  end if;
  if v_status = 'actif' and (old.id is null or old.status <> 'actif') then
    for r in select id from profiles where role::text = 'direction' and not coalesce(suspended, false) limit 50 loop
      perform notify_user(r.id, 'partnership', 'Partenariat de département', (select d.name from departments d where d.id = v) || ' : « ' || v_name || ' » est actif.',
        jsonb_build_object('partnership', v_id, 'department', v));
    end loop;
  end if;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Responsable'), auth.uid(), case when old.id is null then 'Partenariat de département créé' else 'Partenariat de département modifié' end, left(v_name, 200), 'Départements', 'Info');
  return v_id;
end $$;

create or replace function dept_partnerships(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments;
begin
  if v is not null then select * into d from departments where id = v; end if;
  return jsonb_build_object(
    'partnerships', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'department_id', x.department_id, 'partner_name', x.partner_name, 'organization_id', x.organization_id,
        'organization_name', x.organization_name, 'organization_registered', x.organization_id is not null, 'org_response', x.org_response, 'org_response_note', x.org_response_note,
        'kind', x.kind, 'status', x.status, 'contact_name', x.contact_name,
        'contact_email', x.contact_email, 'contact_phone', x.contact_phone, 'description', x.description, 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'amount', x.amount, 'students', x.students,
        'updated_at', x.updated_at) order by (x.status in ('actif', 'negociation')) desc, x.updated_at desc)
      from department_partnerships x where v is null or x.department_id = v), '[]'::jsonb),
    'sponsorships', coalesce((select jsonb_agg(jsonb_build_object('sponsor', sp.name, 'title', s.title, 'amount', s.amount, 'students', s.students, 'status', s.status, 'year', s.year) order by s.year desc, s.created_at desc)
      from sponsorships s join sponsors sp on sp.id = s.sponsor_id
      where v is not null and nullif(btrim(coalesce(s.department, '')), '') is not null and lower(btrim(s.department)) = lower(btrim(d.name))), '[]'::jsonb));
end $$;

create or replace function direction_dept_partnerships(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _inst_check_direction();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'department_id', x.department_id, 'department', x.department, 'partner', x.partner_name, 'organization_id', x.organization_id,
                                        'organization_registered', x.organization_id is not null, 'org_response', x.org_response, 'org_response_note', x.org_response_note,
                                        'kind', x.kind, 'status', x.status, 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'students', x.students, 'amount', x.amount, 'updated_at', x.updated_at)
                     order by (x.status in ('actif', 'negociation')) desc, x.updated_at desc)
    from (
      select dp.*, d.name as department from department_partnerships dp join departments d on d.id = dp.department_id
      where p_department is null or dp.department_id = p_department order by dp.updated_at desc limit 300
    ) x
  ), '[]'::jsonb);
end $$;

-- ------------------------------------------------------------------ côté organisation : mes partenariats et ma réponse
create or replace function org_partnerships_list(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner));
begin
  if v_role is null or exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Accès refusé à cette organisation'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'source', x.src, 'id', x.id, 'name', x.name, 'kind', x.kind, 'status', x.status, 'department', x.department, 'objective', x.objective, 'domains', x.domains,
      'starts_on', x.starts_on, 'ends_on', x.ends_on, 'students', x.students, 'org_response', x.org_response, 'org_response_note', x.org_response_note,
      'org_responded_at', x.org_responded_at, 'decision_note', case when x.status in ('suspended', 'ended', 'termine') then x.decision_note end,
      'updated_at', x.updated_at, 'can_respond', v_role in ('owner', 'admin') and x.status in ('active', 'actif')
    ) order by (x.status in ('active', 'actif')) desc, x.updated_at desc)
    from (
      select 'institution'::text as src, ip.id, ip.name, ip.kind, ip.status, d.name as department, ip.objective, to_jsonb(ip.domains) as domains, ip.starts_on, ip.ends_on, 0 as students,
             ip.org_response, ip.org_response_note, ip.org_responded_at, ip.decision_note, ip.updated_at
      from institutional_partnerships ip left join departments d on d.id = ip.department_id
      where ip.organization_id = v_owner and ip.status in ('active', 'suspended', 'ended')
      union all
      select 'department', dp.id, dp.partner_name, dp.kind, dp.status, d.name, dp.description, '[]'::jsonb, dp.starts_on, dp.ends_on, dp.students,
             dp.org_response, dp.org_response_note, dp.org_responded_at, null::text, dp.updated_at
      from department_partnerships dp join departments d on d.id = dp.department_id
      where dp.organization_id = v_owner and dp.status in ('actif', 'termine')
    ) x
  ), '[]'::jsonb);
end $$;
revoke all on function org_partnerships_list(uuid) from public, anon;
grant execute on function org_partnerships_list(uuid) to authenticated;

create or replace function org_partnership_respond(p_source text, p_id uuid, p_action text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_note text := btrim(coalesce(p_note, '')); v_new text; v_org uuid; v_name text; v_status text; v_dept uuid; v_creator uuid; v_who text; v_oname text; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Compte suspendu'; end if;
  if coalesce(p_source, '') not in ('institution', 'department') then raise exception 'Source de partenariat inconnue'; end if;
  if coalesce(p_action, '') not in ('accept', 'contest') then raise exception 'Réponse inconnue'; end if;
  if p_action = 'contest' and char_length(v_note) < 5 then raise exception 'Un motif d''au moins 5 caractères est obligatoire pour contester'; end if;
  if char_length(v_note) > 1000 then raise exception 'Motif trop long (1000 caractères maximum)'; end if;
  if p_source = 'institution' then
    select organization_id, name, status, department_id, proposed_by into v_org, v_name, v_status, v_dept, v_creator from institutional_partnerships where id = p_id for update;
    if v_org is null or v_status <> 'active' then raise exception 'Partenariat introuvable ou non actif'; end if;
  else
    select organization_id, partner_name, status, department_id, created_by into v_org, v_name, v_status, v_dept, v_creator from department_partnerships where id = p_id for update;
    if v_org is null or v_status <> 'actif' then raise exception 'Partenariat introuvable ou non actif'; end if;
  end if;
  if coalesce(company_role_of(v_org), '') not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''organisation'; end if;
  v_new := case p_action when 'accept' then 'accepted' else 'contested' end;
  if p_source = 'institution' then
    update institutional_partnerships set org_response = v_new, org_response_note = nullif(v_note, ''), org_responded_at = now(), org_responded_by = auth.uid() where id = p_id;
  else
    update department_partnerships set org_response = v_new, org_response_note = nullif(v_note, ''), org_responded_at = now(), org_responded_by = auth.uid() where id = p_id;
  end if;
  select coalesce((select company_name from company_profiles where owner_id = v_org), 'Une organisation') into v_oname;
  select name into v_who from profiles where id = auth.uid();
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(v_who, 'Organisation'), auth.uid(), case p_action when 'accept' then 'Partenariat accepté par l''organisation : ' else 'Partenariat contesté par l''organisation : ' end || v_name, p_id::text, 'Institution',
          case p_action when 'accept' then 'Info' else 'Sensible' end);
  if p_action = 'contest' then
    perform _inst_notify_direction('Partenariat contesté', v_oname || ' conteste le partenariat « ' || v_name || ' » : ' || v_note, jsonb_build_object('partnership', p_id, 'source', p_source));
  end if;
  perform notify_user(v_creator, 'institution', case p_action when 'accept' then 'Partenariat accepté' else 'Partenariat contesté' end,
    v_oname || case p_action when 'accept' then ' a accepté' else ' conteste' end || ' le partenariat « ' || v_name || ' »' || case when v_note <> '' then ' : ' || v_note else '.' end,
    jsonb_build_object('partnership', p_id, 'source', p_source))
  where p_action = 'accept' or not exists (select 1 from profiles where id = v_creator and role::text = 'direction');
  if v_dept is not null then
    for r in select da.user_id from department_accounts da join profiles pr on pr.id = da.user_id where da.department_id = v_dept and not coalesce(pr.suspended, false) loop
      if r.user_id is distinct from v_creator then
        perform notify_user(r.user_id, 'institution', case p_action when 'accept' then 'Partenariat accepté' else 'Partenariat contesté' end,
          v_oname || case p_action when 'accept' then ' a accepté' else ' conteste' end || ' le partenariat « ' || v_name || ' »' || case when v_note <> '' then ' : ' || v_note else '.' end,
          jsonb_build_object('partnership', p_id, 'source', p_source));
      end if;
    end loop;
  end if;
  return v_new;
end $$;
revoke all on function org_partnership_respond(text, uuid, text, text) from public, anon;
grant execute on function org_partnership_respond(text, uuid, text, text) to authenticated;

revoke all on function partnership_save(uuid, text, text, uuid, uuid, text, text, text, text, text[], date, date), partnership_decide(uuid, text, text), partnerships_list(text, uuid),
  dept_partnership_save(jsonb, uuid), dept_partnerships(uuid), direction_dept_partnerships(uuid) from public, anon;
grant execute on function partnership_save(uuid, text, text, uuid, uuid, text, text, text, text, text[], date, date), partnership_decide(uuid, text, text), partnerships_list(text, uuid),
  dept_partnership_save(jsonb, uuid), dept_partnerships(uuid), direction_dept_partnerships(uuid) to authenticated;
