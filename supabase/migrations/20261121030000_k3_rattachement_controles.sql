-- Lot K3 « Département » (1/3) : rattachement des comptes Département, traitement administratif des comptes non rattachés, aucune donnée sans rattachement valide.
-- Un compte `dept` n'a un département que si : une ligne department_accounts existe, le département est VÉRIFIÉ et son nom n'est pas ambigu dans l'établissement.
-- Sinon (état none / unverified / ambiguous) : _dept_id() est nul, aucune ligne n'est visible, aucune notification départementale ne lui est adressée.
-- Aucun rattachement automatique par nom : la reprise H2 (par identifiant ou par nom unique) reste, mais tout rattachement sans administrateur (assigned_by nul) est signalé « à confirmer ».
-- Ajoute : contrôle d'unicité des noms de département (normalisés) par établissement ; admin_dept_unassigned_accounts() ; admin_dept_unassigned_count() ; notification de l'administrateur
-- quand un compte Département non rattaché existe ; notify_department() (envoi aux seuls comptes rattachés au bon département) ; my_department() et admin_dept_accounts() enrichis (état, raison).
-- Retour arrière : drop trigger trg_dept_role_notify on profiles ; drop trigger trg_departments_unique_name on departments ; drop index departments_norm_name_key ;
--   drop function admin_dept_unassigned_accounts(), admin_dept_unassigned_count(), notify_department(uuid, text, text, text, jsonb), _notify_admins_dept_unassigned(uuid, text), _dept_role_notify(),
--   _departments_unique_name(), _dept_attachment_state(uuid), _dept_of(uuid), _dept_norm(text) ; recréer _dept_id, _scope_recipients, _owner_reviewers, _project_reviewers, _dept_account_covers,
--   my_department, admin_dept_accounts, admin_dept_assign, admin_dept_unassign depuis 20261120020000 / 20261120020300.

-- ============================== Unicité des noms de département ==============================
create or replace function _dept_norm(p text) returns text
language sql immutable set search_path = public as $$
  select lower(btrim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g')))
$$;

create or replace function _departments_unique_name() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'verified' and exists (select 1 from departments d where d.id <> new.id and d.institution_id = new.institution_id and d.status = 'verified'
                                        and _dept_norm(d.name) = _dept_norm(new.name)) then
    raise exception 'Un département portant ce nom existe déjà dans cet établissement : le rattachement des comptes serait ambigu';
  end if;
  return new;
end $$;
revoke all on function _departments_unique_name() from public, anon, authenticated;
drop trigger if exists trg_departments_unique_name on departments;
create trigger trg_departments_unique_name before insert or update of name, status, institution_id on departments
  for each row execute function _departments_unique_name();

-- Index d'unicité : posé seulement si les données existantes le permettent (sinon les doublons restent signalés « ambigus » et ne donnent aucun accès).
do $$ begin
  create unique index if not exists departments_norm_name_key on departments (institution_id, _dept_norm(name)) where status = 'verified';
exception when unique_violation then
  raise notice 'K3 : des départements vérifiés portent le même nom dans un établissement : index non posé, les comptes concernés sont signalés ambigus (admin_dept_unassigned_accounts).';
end $$;

-- ============================== État de rattachement ==============================
-- none : aucun rattachement ; unverified : département non vérifié ; ambiguous : un autre département vérifié porte le même nom dans l'établissement ; ok : rattachement valide.
create or replace function _dept_attachment_state(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when p.id is null or p.role::text <> 'dept' then 'not_dept'
    when a.user_id is null then 'none'
    when d.id is null or d.status <> 'verified' then 'unverified'
    when exists (select 1 from departments o where o.id <> d.id and o.institution_id = d.institution_id and o.status = 'verified' and _dept_norm(o.name) = _dept_norm(d.name)) then 'ambiguous'
    else 'ok' end
  from (select 1) x
  left join profiles p on p.id = p_user
  left join department_accounts a on a.user_id = p_user
  left join departments d on d.id = a.department_id
$$;

-- Département d'un compte Département actif ET validement rattaché (sinon nul).
create or replace function _dept_of(p_user uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select a.department_id from department_accounts a join profiles p on p.id = a.user_id
  where a.user_id = p_user and p.role::text = 'dept' and not coalesce(p.suspended, false) and _dept_attachment_state(p_user) = 'ok'
$$;
revoke all on function _dept_attachment_state(uuid), _dept_of(uuid) from public, anon, authenticated;

create or replace function _dept_id() returns uuid
language sql stable security definer set search_path = public as $$
  select case when coalesce(current_role_name()::text, '') = 'dept' then _dept_of(auth.uid()) end
$$;

-- Destinataires et périmètres : seuls les rattachements valides comptent.
create or replace function _scope_recipients(p_target uuid, p_support boolean default false) returns setof uuid
language sql stable security definer set search_path = public as $$
  select a.id from profiles a, profiles t
  where t.id = p_target and not coalesce(a.suspended, false)
    and (a.role::text = 'admin' or (p_support and a.role::text = 'support')
         or (a.role::text = 'dept' and t.department_id is not null and _dept_of(a.id) = t.department_id))
$$;

create or replace function _owner_reviewers(p_owner uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from profiles where role::text = 'admin' and not coalesce(suspended, false)
  union
  select p.id from profiles p join profiles t on t.id = p_owner
  where p.role::text = 'dept' and not coalesce(p.suspended, false) and t.department_id is not null and _dept_of(p.id) = t.department_id
$$;

create or replace function _project_reviewers(p_dept text) returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from profiles where role::text = 'admin' and not coalesce(suspended, false)
  union
  select p.id from profiles p join departments d on d.id = _dept_of(p.id)
  where p.role::text = 'dept' and not coalesce(p.suspended, false) and nullif(_dept_norm(p_dept), '') is not null and _dept_norm(d.name) = _dept_norm(p_dept)
$$;

create or replace function _dept_account_covers(p_account uuid, p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select _dept_of(p_account) is not null and exists (select 1 from profiles t where t.id = p_owner and t.department_id = _dept_of(p_account))
$$;

-- Envoi à un département : uniquement les comptes Département actifs et validement rattachés à CE département. Usage interne (appelé par des fonctions serveur).
create or replace function notify_department(p_department uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  if p_department is null then return 0; end if;
  for r in select p.id from profiles p where p.role::text = 'dept' and not coalesce(p.suspended, false) and _dept_of(p.id) = p_department limit 200 loop
    perform notify_user(r.id, p_kind, p_title, p_body, p_data);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function notify_department(uuid, text, text, text, jsonb) from public, anon, authenticated;

-- ============================== Notification de l'administrateur ==============================
create or replace function _notify_admins_dept_unassigned(p_user uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare t profiles; r record;
begin
  select * into t from profiles where id = p_user;
  if t.id is null or t.role::text <> 'dept' then return; end if;
  for r in select id from profiles where role::text = 'admin' and not coalesce(suspended, false) limit 50 loop
    if not exists (select 1 from notifications n where n.user_id = r.id and n.kind = 'department' and n.read_at is null
                   and n.data->>'type' = 'unassigned' and n.data->>'user' = p_user::text) then
      perform notify_user(r.id, 'department', 'Compte Département à rattacher',
        coalesce(nullif(btrim(t.name), ''), 'Un compte Département') || ' n''est rattaché à aucun département : aucune donnée ne lui est affichée tant que vous ne l''avez pas rattaché.',
        jsonb_build_object('type', 'unassigned', 'user', p_user, 'reason', coalesce(p_reason, 'none')));
    end if;
  end loop;
end $$;
revoke all on function _notify_admins_dept_unassigned(uuid, text) from public, anon, authenticated;

create or replace function _dept_role_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role::text = 'dept' and (tg_op = 'INSERT' or old.role::text is distinct from 'dept')
     and not exists (select 1 from department_accounts where user_id = new.id) then
    perform _notify_admins_dept_unassigned(new.id, 'none');
    perform notify_user(new.id, 'department', 'En attente de rattachement',
      'Votre compte Département doit être rattaché à un département par l''administrateur. Vous serez prévenu(e) dès que ce sera fait ; en attendant, aucune donnée n''est affichée.',
      jsonb_build_object('type', 'waiting'));
  end if;
  return new;
end $$;
revoke all on function _dept_role_notify() from public, anon, authenticated;
drop trigger if exists trg_dept_role_notify on profiles;
create trigger trg_dept_role_notify after insert or update of role on profiles for each row execute function _dept_role_notify();

-- Comptes déjà non rattachés : un seul message de synthèse par administrateur (sans doublon).
do $$
declare v_n integer; r record;
begin
  select count(*) into v_n from profiles p where p.role::text = 'dept' and not coalesce(p.suspended, false) and _dept_attachment_state(p.id) <> 'ok';
  if v_n > 0 then
    for r in select id from profiles where role::text = 'admin' and not coalesce(suspended, false) limit 50 loop
      if not exists (select 1 from notifications n where n.user_id = r.id and n.kind = 'department' and n.read_at is null and n.data->>'type' = 'unassigned_summary') then
        insert into notifications (user_id, kind, title, body, data)
        values (r.id, 'department', 'Comptes Département à rattacher', v_n || ' compte(s) Département n''ont pas de rattachement valide : ils ne voient aucune donnée tant que vous ne les avez pas rattachés.',
                jsonb_build_object('type', 'unassigned_summary', 'count', v_n));
      end if;
    end loop;
  end if;
end $$;

-- ============================== Lecture du rattachement ==============================
create or replace function my_department() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); a department_accounts; d departments; i institutions; v_state text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into a from department_accounts where user_id = auth.uid();
  v_state := case when r = 'dept' then _dept_attachment_state(auth.uid()) when a.user_id is null then 'none' else 'ok' end;
  if a.user_id is null or v_state <> 'ok' then
    return jsonb_build_object('role', r, 'attached', false, 'waiting', r = 'dept', 'state', v_state,
      'reason', case v_state
        when 'unverified' then 'Le département auquel votre compte est rattaché n''est pas encore vérifié.'
        when 'ambiguous' then 'Le nom de votre département est ambigu dans votre établissement : l''administrateur doit confirmer le rattachement.'
        else 'Aucun département ne vous a encore été attribué.' end,
      'name', (select name from profiles where id = auth.uid()));
  end if;
  select * into d from departments where id = a.department_id;
  select * into i from institutions where id = d.institution_id;
  return jsonb_build_object('role', r, 'attached', r = 'dept', 'waiting', false, 'state', 'ok', 'department_id', d.id, 'department', d.name, 'institution', coalesce(i.name, ''), 'institution_id', d.institution_id,
    'title', a.title, 'name', (select name from profiles where id = auth.uid()));
end $$;

-- ============================== Traitement administratif ==============================
create or replace function admin_dept_accounts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'suspended', coalesce(p.suspended, false), 'title', a.title,
      'department_id', a.department_id, 'department', d.name, 'institution', i.name,
      'attached', _dept_attachment_state(p.id) = 'ok', 'state', _dept_attachment_state(p.id),
      'to_review', a.user_id is not null and a.assigned_by is null, 'assigned_at', a.assigned_at)
      order by (_dept_attachment_state(p.id) = 'ok'), p.name)
    from profiles p left join department_accounts a on a.user_id = p.id left join departments d on d.id = a.department_id left join institutions i on i.id = d.institution_id
    where p.role::text = 'dept'), '[]'::jsonb);
end $$;

-- Comptes Département sans rattachement valide, avec la raison et des suggestions (jamais appliquées automatiquement).
create or replace function admin_dept_unassigned_accounts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', x.id, 'name', x.name, 'email', x.email, 'suspended', x.suspended, 'since', x.created_at, 'state', x.state,
      'reason', case x.state
        when 'unverified' then 'Département non vérifié'
        when 'ambiguous' then 'Nom de département ambigu'
        else 'Aucun rattachement' end,
      'declared_institution', coalesce(x.institution, ''), 'declared_department', coalesce(x.department, ''),
      'current_department', x.current_department,
      'candidates', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name, 'institution', i.name) order by i.name, d.name)
                              from departments d join institutions i on i.id = d.institution_id
                              where d.status = 'verified' and nullif(_dept_norm(x.department), '') is not null and _dept_norm(d.name) = _dept_norm(x.department)
                                and (x.institution_id is null or d.institution_id = x.institution_id)), '[]'::jsonb))
      order by x.suspended, x.created_at)
    from (select p.id, p.name, p.email, coalesce(p.suspended, false) suspended, p.created_at, p.institution, p.department, p.institution_id, _dept_attachment_state(p.id) state,
                 (select d.name from department_accounts a join departments d on d.id = a.department_id where a.user_id = p.id) current_department
          from profiles p where p.role::text = 'dept') x
    where x.state <> 'ok'), '[]'::jsonb);
end $$;

-- Compteur du badge « Rattachement des comptes » (comptes actifs sans rattachement valide).
create or replace function admin_dept_unassigned_count() returns integer
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return (select count(*)::int from profiles p where p.role::text = 'dept' and not coalesce(p.suspended, false) and _dept_attachment_state(p.id) <> 'ok');
end $$;

create or replace function admin_dept_assign(p_user uuid, p_department uuid, p_title text default 'Responsable') returns void
language plpgsql security definer set search_path = public as $$
declare t profiles; d departments; v_title text := coalesce(nullif(btrim(coalesce(p_title, '')), ''), 'Responsable');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if char_length(v_title) > 80 then raise exception 'Fonction : 80 caractères au plus'; end if;
  select * into t from profiles where id = p_user;
  if t.id is null then raise exception 'Compte introuvable'; end if;
  if t.role::text <> 'dept' then raise exception 'Ce compte n''est pas un compte Département'; end if;
  select * into d from departments where id = p_department and status = 'verified';
  if d.id is null then raise exception 'Département introuvable ou non vérifié'; end if;
  if exists (select 1 from departments o where o.id <> d.id and o.institution_id = d.institution_id and o.status = 'verified' and _dept_norm(o.name) = _dept_norm(d.name)) then
    raise exception 'Le nom de ce département est ambigu dans son établissement : corrigez le référentiel avant de rattacher un compte';
  end if;
  insert into department_accounts (user_id, department_id, title, assigned_by) values (p_user, p_department, v_title, auth.uid())
  on conflict (user_id) do update set department_id = excluded.department_id, title = excluded.title, assigned_by = excluded.assigned_by, assigned_at = now();
  update notifications set read_at = now() where kind = 'department' and read_at is null and data->>'type' in ('unassigned', 'waiting') and (data->>'user' = p_user::text or user_id = p_user);
  perform notify_user(p_user, 'department', 'Rattachement à un département', 'Votre compte gère désormais le département « ' || d.name || ' ».', jsonb_build_object('department', p_department, 'type', 'attached'));
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Rattachement au département', left(t.name || ' -> ' || d.name, 200), 'Départements', 'Sensible');
end $$;

create or replace function admin_dept_unassign(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t profiles;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into t from profiles where id = p_user;
  if t.id is null then raise exception 'Compte introuvable'; end if;
  delete from department_accounts where user_id = p_user;
  if not found then raise exception 'Ce compte n''est rattaché à aucun département'; end if;
  if t.role::text = 'dept' then
    perform notify_user(p_user, 'department', 'Rattachement retiré', 'Votre compte n''est plus rattaché à un département : aucune donnée n''est affichée tant que l''administrateur ne vous a pas rattaché à nouveau.', jsonb_build_object('type', 'waiting'));
    perform _notify_admins_dept_unassigned(p_user, 'none');
  end if;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Rattachement retiré', left(t.name, 200), 'Départements', 'Sensible');
end $$;

revoke all on function my_department(), admin_dept_accounts(), admin_dept_unassigned_accounts(), admin_dept_unassigned_count(), admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid) from public, anon;
grant execute on function my_department(), admin_dept_accounts(), admin_dept_unassigned_accounts(), admin_dept_unassigned_count(), admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid) to authenticated;
