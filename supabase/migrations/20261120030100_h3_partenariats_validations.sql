-- Lot H3 (Direction) : partenariats institutionnels et validations institutionnelles.
--   * institutional_partnerships : partenariats de l'établissement (entreprise, association, ONG, institution, université, collectivité…),
--     rattachables à un département et/ou à une organisation inscrite. Statuts : proposed (proposé), active, suspended, ended, rejected.
--   * institutional_validations : file des validations qui relèvent de la direction (partenariats proposés, rapports ou événements
--     soumis par un département, demandes diverses).
--   * institutional_decision_log : journal des décisions de la direction (qui, quoi, quand, motif).
-- Qui fait quoi : la direction (et l'administrateur) crée, modifie et DÉCIDE ; un responsable de département PROPOSE pour SON département
-- seulement et suit ses propres dossiers ; une organisation liée voit son partenariat une fois décidé ; personne d'autre n'a d'accès.
-- Aucun accès direct aux tables (RLS sans politique) : tout passe par des fonctions qui vérifient auth.uid() et le rôle (un compte suspendu
-- n'a plus de rôle effectif). Toute décision est journalisée (audit_log + journal institutionnel) et notifiée au demandeur.
-- Retour arrière : drop function partnership_save(uuid, text, text, uuid, uuid, text, text, text, text, text[], date, date), partnership_decide(uuid, text, text),
--   partnerships_list(text, uuid), institutional_validation_request(text, text, text, uuid, uuid), institutional_validations_list(text, int),
--   institutional_validation_decide(uuid, boolean, text), institutional_validation_cancel(uuid), direction_decisions_journal(int),
--   _inst_check_direction(), _inst_notify_direction(text, text, jsonb);
--   drop table institutional_decision_log, institutional_validations, institutional_partnerships;

create table if not exists institutional_partnerships (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 160),
  kind text not null default 'entreprise' check (kind in ('entreprise', 'association', 'ong', 'institution', 'universite', 'collectivite', 'autre')),
  department_id uuid references departments(id) on delete set null,
  company_owner_id uuid references profiles(id) on delete set null,
  contact_name text not null default '' check (char_length(contact_name) <= 120),
  contact_email text not null default '' check (contact_email = '' or contact_email ~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$'),
  contact_phone text not null default '' check (char_length(contact_phone) <= 30),
  objective text not null default '' check (char_length(objective) <= 2000),
  domains text[] not null default '{}' check (cardinality(domains) <= 8),
  starts_on date,
  ends_on date,
  status text not null default 'proposed' check (status in ('proposed', 'active', 'suspended', 'ended', 'rejected')),
  decision_note text check (decision_note is null or char_length(decision_note) <= 1000),
  decided_by uuid references profiles(id) on delete set null,
  decided_at timestamptz,
  proposed_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);
create index if not exists institutional_partnerships_status on institutional_partnerships (status, created_at desc);
create index if not exists institutional_partnerships_department on institutional_partnerships (department_id);

create table if not exists institutional_validations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('partnership', 'report', 'event', 'department_request', 'other')),
  subject_id uuid,
  department_id uuid references departments(id) on delete set null,
  title text not null check (char_length(title) between 3 and 160),
  details text not null default '' check (char_length(details) <= 2000),
  requested_by uuid references profiles(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  decision_note text check (decision_note is null or char_length(decision_note) <= 1000),
  decided_by uuid references profiles(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists institutional_validations_status on institutional_validations (status, created_at desc);
create index if not exists institutional_validations_requester on institutional_validations (requested_by);

create table if not exists institutional_decision_log (
  id bigint generated always as identity primary key,
  kind text not null,
  subject_id uuid,
  title text not null,
  action text not null,
  note text,
  department_id uuid references departments(id) on delete set null,
  actor_id uuid references profiles(id) on delete set null,
  actor_name text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists institutional_decision_log_date on institutional_decision_log (created_at desc);

alter table institutional_partnerships enable row level security;
alter table institutional_validations enable row level security;
alter table institutional_decision_log enable row level security;
revoke all on institutional_partnerships, institutional_validations, institutional_decision_log from anon, authenticated;

-- ------------------------------------------------------------------ gardes internes
create or replace function _inst_check_direction() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('direction', 'admin') then raise exception 'Réservé à la direction'; end if;
end $$;
revoke all on function _inst_check_direction() from public, anon, authenticated;

create or replace function _inst_notify_direction(p_title text, p_body text, p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select id from profiles where role::text = 'direction' and not coalesce(suspended, false) loop
    perform notify_user(r.id, 'institution', p_title, p_body, coalesce(p_data, '{}'::jsonb));
  end loop;
end $$;
revoke all on function _inst_notify_direction(text, text, jsonb) from public, anon, authenticated;

-- ------------------------------------------------------------------ partenariats
create or replace function partnership_save(
  p_id uuid, p_name text, p_kind text, p_department uuid, p_company_owner uuid, p_contact_name text, p_contact_email text, p_contact_phone text,
  p_objective text, p_domains text[], p_starts date, p_ends date) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_role text := coalesce(current_role_name()::text, '');
  v_name text := btrim(coalesce(p_name, ''));
  v_email text := btrim(coalesce(p_contact_email, ''));
  v_dept uuid; v_my uuid; v_id uuid; v_ex institutional_partnerships%rowtype; v_who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('direction', 'admin', 'dept') then raise exception 'Action non autorisée'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 160 then raise exception 'Nom du partenaire : 2 à 160 caractères'; end if;
  if coalesce(p_kind, '') not in ('entreprise', 'association', 'ong', 'institution', 'universite', 'collectivite', 'autre') then raise exception 'Type de partenaire invalide'; end if;
  if v_email <> '' and v_email !~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$' then raise exception 'Adresse e-mail du contact invalide'; end if;
  if p_starts is not null and p_ends is not null and p_ends < p_starts then raise exception 'La date de fin précède la date de début'; end if;
  if char_length(coalesce(p_objective, '')) > 2000 then raise exception 'Objectif trop long (2000 caractères maximum)'; end if;
  if cardinality(coalesce(p_domains, '{}')) > 8 then raise exception '8 domaines au maximum'; end if;
  if p_company_owner is not null and not exists (select 1 from profiles where id = p_company_owner and role::text in ('company', 'other')) then raise exception 'Organisation introuvable'; end if;
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
    insert into institutional_partnerships (name, kind, department_id, company_owner_id, contact_name, contact_email, contact_phone, objective, domains, starts_on, ends_on, proposed_by)
    values (v_name, p_kind, v_dept, p_company_owner, left(btrim(coalesce(p_contact_name, '')), 120), v_email, left(btrim(coalesce(p_contact_phone, '')), 30),
            btrim(coalesce(p_objective, '')), coalesce(p_domains, '{}'), p_starts, p_ends, auth.uid())
    returning id into v_id;
    insert into institutional_validations (kind, subject_id, department_id, title, details, requested_by)
    values ('partnership', v_id, v_dept, left('Partenariat : ' || v_name, 160), btrim(coalesce(p_objective, '')), auth.uid());
    insert into audit_log (actor, action, target, category, level) values (coalesce(v_who, 'Direction'), 'Partenariat proposé : ' || v_name, v_id::text, 'Institution', 'Info');
    if v_role = 'dept' then
      perform _inst_notify_direction('Partenariat à valider', coalesce(v_who, 'Un département') || ' propose le partenariat « ' || v_name || ' ».', jsonb_build_object('partnership', v_id));
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
    name = v_name, kind = p_kind, department_id = v_dept, company_owner_id = p_company_owner,
    contact_name = left(btrim(coalesce(p_contact_name, '')), 120), contact_email = v_email, contact_phone = left(btrim(coalesce(p_contact_phone, '')), 30),
    objective = btrim(coalesce(p_objective, '')), domains = coalesce(p_domains, '{}'), starts_on = p_starts, ends_on = p_ends, updated_at = now()
  where id = p_id;
  update institutional_validations set title = left('Partenariat : ' || v_name, 160), details = btrim(coalesce(p_objective, '')), department_id = v_dept
  where kind = 'partnership' and subject_id = p_id and status = 'pending';
  return p_id;
end $$;

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
  perform notify_user(v_ex.company_owner_id, 'institution', 'Partenariat ' || v_label, 'Votre partenariat « ' || v_ex.name || ' » avec l''établissement est ' || v_label || '.', jsonb_build_object('partnership', p_id));
  return v_new;
end $$;

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
      'company_owner_id', x.company_owner_id, 'company', x.company, 'contact_name', x.contact_name, 'contact_email', x.contact_email, 'contact_phone', x.contact_phone,
      'objective', x.objective, 'domains', to_jsonb(x.domains), 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'decision_note', x.decision_note,
      'decided_at', x.decided_at, 'proposer', x.proposer, 'mine', x.proposed_by = auth.uid(), 'created_at', x.created_at
    ) order by case x.status when 'proposed' then 0 when 'active' then 1 when 'suspended' then 2 else 3 end, x.created_at desc)
    from (
      select ip.*, d.name as department, coalesce(cp.company_name, cpo.name) as company, pr.name as proposer
      from institutional_partnerships ip
      left join departments d on d.id = ip.department_id
      left join profiles cpo on cpo.id = ip.company_owner_id
      left join company_profiles cp on cp.owner_id = ip.company_owner_id
      left join profiles pr on pr.id = ip.proposed_by
      where (p_status is null or ip.status = p_status)
        and case
              when v_role in ('direction', 'admin') then (p_department is null or ip.department_id = p_department)
              when v_role = 'dept' then ip.department_id = v_my
              else ip.company_owner_id = auth.uid() and ip.status in ('active', 'suspended', 'ended')
            end
      order by ip.created_at desc limit 300
    ) x
  ), '[]'::jsonb);
end $$;

-- ------------------------------------------------------------------ validations institutionnelles
create or replace function institutional_validation_request(p_kind text, p_title text, p_details text default '', p_department uuid default null, p_subject uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_title text := btrim(coalesce(p_title, '')); v_dept uuid; v_id uuid; v_who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('direction', 'admin', 'dept') then raise exception 'Action non autorisée'; end if;
  if coalesce(p_kind, '') not in ('report', 'event', 'department_request', 'other') then raise exception 'Type de validation invalide'; end if;
  if char_length(v_title) < 3 or char_length(v_title) > 160 then raise exception 'Objet : 3 à 160 caractères'; end if;
  if char_length(coalesce(p_details, '')) > 2000 then raise exception 'Détails trop longs (2000 caractères maximum)'; end if;
  if v_role = 'dept' then
    v_dept := _dept_id();
    if v_dept is null then raise exception 'Aucun département n''est rattaché à votre compte'; end if;
  else
    v_dept := p_department;
    if v_dept is not null and not exists (select 1 from departments where id = v_dept) then raise exception 'Département introuvable'; end if;
  end if;
  insert into institutional_validations (kind, subject_id, department_id, title, details, requested_by)
  values (p_kind, p_subject, v_dept, v_title, btrim(coalesce(p_details, '')), auth.uid()) returning id into v_id;
  select name into v_who from profiles where id = auth.uid();
  perform _inst_notify_direction('Validation demandée', coalesce(v_who, 'Un département') || ' demande : ' || v_title, jsonb_build_object('validation', v_id));
  return v_id;
end $$;

create or replace function institutional_validations_list(p_status text default 'pending', p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_my uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('direction', 'admin', 'dept') then raise exception 'Action non autorisée'; end if;
  if v_role = 'dept' then v_my := _dept_id(); end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', x.id, 'kind', x.kind, 'subject_id', x.subject_id, 'department_id', x.department_id, 'department', x.department, 'title', x.title, 'details', x.details,
      'requester', x.requester, 'status', x.status, 'decision_note', x.decision_note, 'decided_at', x.decided_at, 'decider', x.decider,
      'mine', x.requested_by = auth.uid(), 'created_at', x.created_at
    ) order by x.created_at desc)
    from (
      select v.*, d.name as department, rq.name as requester, dc.name as decider
      from institutional_validations v
      left join departments d on d.id = v.department_id
      left join profiles rq on rq.id = v.requested_by
      left join profiles dc on dc.id = v.decided_by
      where (p_status is null or p_status = 'all' or v.status = p_status)
        and (v_role in ('direction', 'admin') or v.requested_by = auth.uid() or (v_my is not null and v.department_id = v_my))
      order by v.created_at desc limit least(greatest(coalesce(p_limit, 100), 1), 300)
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function institutional_validation_decide(p_id uuid, p_approve boolean, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_v institutional_validations%rowtype; v_note text := btrim(coalesce(p_note, '')); v_who text; v_status text;
begin
  perform _inst_check_direction();
  select * into v_v from institutional_validations where id = p_id for update;
  if not found then raise exception 'Demande de validation introuvable'; end if;
  if v_v.status <> 'pending' then raise exception 'Cette demande a déjà été traitée'; end if;
  if p_approve is null then raise exception 'Décision requise'; end if;
  if not p_approve and char_length(v_note) < 5 then raise exception 'Un motif d''au moins 5 caractères est obligatoire pour refuser'; end if;
  if char_length(v_note) > 1000 then raise exception 'Motif trop long (1000 caractères maximum)'; end if;
  if v_v.kind = 'partnership' and v_v.subject_id is not null and exists (select 1 from institutional_partnerships where id = v_v.subject_id and status = 'proposed') then
    perform partnership_decide(v_v.subject_id, case when p_approve then 'approve' else 'reject' end, v_note);
    return case when p_approve then 'approved' else 'rejected' end;
  end if;
  v_status := case when p_approve then 'approved' else 'rejected' end;
  update institutional_validations set status = v_status, decision_note = nullif(v_note, ''), decided_by = auth.uid(), decided_at = now() where id = p_id;
  select name into v_who from profiles where id = auth.uid();
  insert into institutional_decision_log (kind, subject_id, title, action, note, department_id, actor_id, actor_name)
  values (v_v.kind, coalesce(v_v.subject_id, v_v.id), v_v.title, case when p_approve then 'Validation accordée' else 'Validation refusée' end, nullif(v_note, ''), v_v.department_id, auth.uid(), coalesce(v_who, ''));
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(v_who, 'Direction'), case when p_approve then 'Validation institutionnelle accordée : ' else 'Validation institutionnelle refusée : ' end || v_v.title, p_id::text, 'Institution', 'Sensible');
  perform notify_user(v_v.requested_by, 'institution', case when p_approve then 'Validation accordée' else 'Validation refusée' end,
                      '« ' || v_v.title || ' »' || case when v_note <> '' then ' : ' || v_note else '' end, jsonb_build_object('validation', p_id));
  return v_status;
end $$;

create or replace function institutional_validation_cancel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_v institutional_validations%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('direction', 'admin', 'dept') then raise exception 'Action non autorisée'; end if;
  select * into v_v from institutional_validations where id = p_id for update;
  if not found or v_v.requested_by is distinct from auth.uid() then raise exception 'Demande de validation introuvable'; end if;
  if v_v.status <> 'pending' then raise exception 'Cette demande a déjà été traitée'; end if;
  if v_v.kind = 'partnership' then raise exception 'Un partenariat proposé se corrige ou se refuse depuis l''écran des partenariats'; end if;
  update institutional_validations set status = 'cancelled', decided_at = now() where id = p_id;
end $$;

create or replace function direction_decisions_journal(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _inst_check_direction();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'kind', x.kind, 'title', x.title, 'action', x.action, 'note', x.note, 'department', x.department, 'actor', x.actor_name, 'created_at', x.created_at) order by x.created_at desc, x.id desc)
    from (
      select l.*, d.name as department from institutional_decision_log l left join departments d on d.id = l.department_id
      order by l.created_at desc, l.id desc limit least(greatest(coalesce(p_limit, 100), 1), 300)
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function partnership_save(uuid, text, text, uuid, uuid, text, text, text, text, text[], date, date), partnership_decide(uuid, text, text), partnerships_list(text, uuid),
  institutional_validation_request(text, text, text, uuid, uuid), institutional_validations_list(text, int), institutional_validation_decide(uuid, boolean, text),
  institutional_validation_cancel(uuid), direction_decisions_journal(int) from public, anon;
grant execute on function partnership_save(uuid, text, text, uuid, uuid, text, text, text, text, text[], date, date), partnership_decide(uuid, text, text), partnerships_list(text, uuid),
  institutional_validation_request(text, text, text, uuid, uuid), institutional_validations_list(text, int), institutional_validation_decide(uuid, boolean, text),
  institutional_validation_cancel(uuid), direction_decisions_journal(int) to authenticated;
