-- Lot H2 « Département » (1/6) : rattachement compte Département <-> département, cloisonnement strict des fonctions de périmètre.
-- Un compte `dept` appartient à UN SEUL département (table department_accounts, définie par l'administrateur). Sans rattachement : aucune donnée.
-- Aides : _dept_id() (département du compte), _dept_sees(owner) (politiques RLS : vrai seulement pour un compte dept dont l'owner est dans son département),
-- _dept_visible(owner) (RPC déjà filtrées par rôle : restreint le seul rôle dept, les autres rôles gardent leur périmètre), _dept_pick(id) (cible d'une lecture).
-- Remplace les anciens repli « établissement entier » / « département sans responsable : n'importe qui » (_review_scope_ok, _scope_recipients,
-- _listing_staff_scope, _project_reviewers) par une égalité stricte sur le département.
-- Retour arrière : drop trigger trg_dept_profile_lock on profiles ; drop trigger trg_dept_role_leave on profiles ; drop table department_accounts cascade ;
--   recréer _dept_scope, _review_scope_ok, _scope_recipients (20261117010000), _listing_staff_scope (20261119020000), _project_reviewers (20261117050200),
--   profile_set_academic (20261117010000) ; drop function _dept_id(), _dept_sees(uuid), _dept_visible(uuid), _dept_sees_name(text), _dept_pick(uuid),
--   my_department(), admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid), admin_dept_accounts().

create table if not exists department_accounts (
  user_id uuid primary key references profiles(id) on delete cascade,
  department_id uuid not null references departments(id) on delete restrict,
  title text not null default 'Responsable' check (char_length(btrim(title)) between 2 and 80),
  assigned_by uuid references profiles(id) on delete set null,
  assigned_at timestamptz not null default now()
);
create index if not exists department_accounts_department_idx on department_accounts (department_id);
alter table department_accounts enable row level security;
drop policy if exists "rattachements : le compte et l'administration" on department_accounts;
create policy "rattachements : le compte et l'administration" on department_accounts for select
  using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'direction'));
revoke all on department_accounts from public, anon, authenticated;
grant select on department_accounts to authenticated;

-- Reprise des comptes existants : par identifiant de département, sinon par nom unique dans l'établissement. Le reste attend l'administrateur.
insert into department_accounts (user_id, department_id)
select p.id, p.department_id from profiles p where p.role::text = 'dept' and p.department_id is not null
on conflict (user_id) do nothing;
insert into department_accounts (user_id, department_id)
select p.id, (select d.id from departments d where d.institution_id = p.institution_id and lower(btrim(d.name)) = lower(btrim(p.department)) and d.status = 'verified')
from profiles p
where p.role::text = 'dept' and p.department_id is null and p.institution_id is not null and nullif(btrim(coalesce(p.department, '')), '') is not null
  and (select count(*) from departments d where d.institution_id = p.institution_id and lower(btrim(d.name)) = lower(btrim(p.department)) and d.status = 'verified') = 1
on conflict (user_id) do nothing;

-- Le département affiché sur le profil suit le rattachement (les fonctions existantes lisent profiles.department_id).
create or replace function _dept_sync_profile() returns trigger
language plpgsql security definer set search_path = public as $$
declare d departments; i institutions;
begin
  select * into d from departments where id = new.department_id;
  select * into i from institutions where id = d.institution_id;
  perform set_config('app.dept_rpc', '1', true);
  update profiles set department_id = d.id, department = d.name, institution_id = d.institution_id, institution = coalesce(i.name, institution) where id = new.user_id;
  perform set_config('app.dept_rpc', '', true);
  return new;
end $$;
revoke all on function _dept_sync_profile() from public, anon, authenticated;
drop trigger if exists trg_dept_sync_profile on department_accounts;
create trigger trg_dept_sync_profile after insert or update of department_id on department_accounts for each row execute function _dept_sync_profile();

-- Un compte Département ne change pas lui-même de département ; quitter le rôle dept supprime le rattachement.
create or replace function _dept_profile_lock() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.role::text = 'dept' and new.role::text <> 'dept' then
    delete from department_accounts where user_id = old.id;
  end if;
  if new.role::text = 'dept' and auth.uid() is not null and coalesce(current_setting('app.dept_rpc', true), '') <> '1' and coalesce(current_role_name()::text, '') <> 'admin'
     and (new.department_id is distinct from old.department_id or new.institution_id is distinct from old.institution_id
          or new.department is distinct from old.department or new.institution is distinct from old.institution) then
    new.department_id := old.department_id; new.institution_id := old.institution_id;
    new.department := old.department; new.institution := old.institution;
  end if;
  return new;
end $$;
revoke all on function _dept_profile_lock() from public, anon, authenticated;
drop trigger if exists trg_dept_profile_lock on profiles;
create trigger trg_dept_profile_lock before update on profiles for each row execute function _dept_profile_lock();

-- ============================== Aides de cloisonnement ==============================
create or replace function _dept_id() returns uuid
language sql stable security definer set search_path = public as $$
  select a.department_id from department_accounts a where a.user_id = auth.uid() and coalesce(current_role_name()::text, '') = 'dept'
$$;

create or replace function _dept_sees(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and coalesce(current_role_name()::text, '') = 'dept'
     and exists (select 1 from profiles t where t.id = p_owner and t.department_id is not null and t.department_id = _dept_id())
$$;

create or replace function _dept_sees_dept(p_department uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and p_department is not null and p_department = _dept_id()
$$;

-- Texte libre de département (annonces, projets, vœux) : égalité stricte sur le nom du département rattaché.
create or replace function _dept_sees_name(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and coalesce(current_role_name()::text, '') = 'dept' and nullif(lower(btrim(coalesce(p_name, ''))), '') is not null
     and exists (select 1 from departments d where d.id = _dept_id() and lower(btrim(d.name)) = lower(btrim(p_name)))
$$;

-- À appeler après le contrôle de rôle de la fonction : seul le rôle dept est restreint.
create or replace function _dept_visible(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select case when coalesce(current_role_name()::text, '') = 'dept' then _dept_sees(p_owner) else true end
$$;

create or replace function _dept_visible_dept(p_department uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select case when coalesce(current_role_name()::text, '') = 'dept' then _dept_sees_dept(p_department) else true end
$$;

-- Cible d'une lecture : dept = son département (un autre est refusé) ; admin / direction = le département demandé (null : tous) ; autres rôles refusés.
create or replace function _dept_pick(p_department uuid default null) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r = 'dept' then
    v := _dept_id();
    if v is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;
    if p_department is not null and p_department <> v then raise exception 'Ce département n''est pas le vôtre'; end if;
    return v;
  elsif r in ('admin', 'direction') then
    return p_department;
  end if;
  raise exception 'Action non autorisée';
end $$;

revoke all on function _dept_id(), _dept_sees(uuid), _dept_sees_dept(uuid), _dept_sees_name(text), _dept_visible(uuid), _dept_visible_dept(uuid), _dept_pick(uuid) from public, anon, authenticated;
grant execute on function _dept_id(), _dept_sees(uuid), _dept_sees_dept(uuid), _dept_sees_name(text), _dept_visible(uuid), _dept_visible_dept(uuid) to anon, authenticated;
grant execute on function _dept_pick(uuid) to authenticated;

-- ============================== Anciennes aides de périmètre : égalité stricte ==============================
create or replace function _dept_scope() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  if r = 'dept' then
    return coalesce(_dept_id(), '00000000-0000-0000-0000-000000000000'::uuid);   -- non rattaché : aucune ligne
  end if;
  return null;   -- null : tout l'établissement
end $$;

create or replace function _review_scope_ok(p_target uuid, p_support boolean default false) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then return false; end if;
  if r = 'admin' or (p_support and r = 'support') then return true; end if;
  if r <> 'dept' then return false; end if;
  return _dept_sees(p_target);
end $$;

create or replace function _scope_recipients(p_target uuid, p_support boolean default false) returns setof uuid
language sql stable security definer set search_path = public as $$
  select a.id from profiles a, profiles t
  where t.id = p_target and not coalesce(a.suspended, false)
    and (a.role::text = 'admin' or (p_support and a.role::text = 'support')
         or (a.role::text = 'dept' and t.department_id is not null
             and exists (select 1 from department_accounts da where da.user_id = a.id and da.department_id = t.department_id)))
$$;

create or replace function _listing_staff_scope(p_dept text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then return false; end if;
  if r = 'admin' then return true; end if;
  if r <> 'dept' then return false; end if;
  return _dept_sees_name(p_dept);
end $$;

create or replace function _project_reviewers(p_dept text) returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from profiles where role::text = 'admin' and not coalesce(suspended, false)
  union
  select a.user_id from department_accounts a join departments d on d.id = a.department_id join profiles x on x.id = a.user_id
  where x.role::text = 'dept' and not coalesce(x.suspended, false)
    and nullif(lower(btrim(coalesce(p_dept, ''))), '') is not null and lower(btrim(d.name)) = lower(btrim(p_dept))
$$;

-- Projet : le propriétaire détermine le département (le texte libre du projet n'est qu'un libellé).
create or replace function _can_review_project(p_project uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); v_owner uuid;
begin
  if auth.uid() is null then return false; end if;
  if r = 'admin' then return true; end if;
  if r <> 'dept' then return false; end if;
  select owner_id into v_owner from projects where id = p_project;
  return v_owner is not null and _dept_sees(v_owner);
end $$;
revoke all on function _can_review_project(uuid) from public, anon, authenticated;
grant execute on function _can_review_project(uuid) to authenticated;

-- ============================== Un département ne se choisit pas lui-même ==============================
create or replace function profile_set_academic(p_institution uuid, p_department uuid, p_matricule text default null, p_level text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_inst institutions; v_dept departments; v_mat text := nullif(regexp_replace(trim(coalesce(p_matricule, '')), '\s+', '', 'g'), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' then
    raise exception 'Le département d''un compte Département est défini par l''administrateur';
  end if;
  if p_institution is not null then
    select * into v_inst from institutions where id = p_institution and (status = 'verified' or proposed_by = auth.uid());
    if v_inst.id is null then raise exception 'Établissement introuvable'; end if;
  end if;
  if p_department is not null then
    select * into v_dept from departments where id = p_department and (status = 'verified' or proposed_by = auth.uid());
    if v_dept.id is null or v_dept.institution_id is distinct from p_institution then raise exception 'Département introuvable pour cet établissement'; end if;
  end if;
  if v_mat is not null and (char_length(v_mat) < 3 or char_length(v_mat) > 40 or v_mat !~ '^[A-Za-z0-9/_.-]+$') then raise exception 'Matricule invalide'; end if;
  if v_mat is not null and exists (select 1 from profiles o where o.id <> auth.uid() and lower(o.matricule) = lower(v_mat)
                                   and o.institution_id is not distinct from p_institution) then
    raise exception 'Ce matricule est déjà enregistré par un autre compte : vérifiez votre saisie ou contactez le support';
  end if;
  update profiles set
    institution_id = p_institution, institution = coalesce(v_inst.name, ''),
    department_id = p_department, department = coalesce(v_dept.name, ''),
    matricule = v_mat, study_level = nullif(left(trim(coalesce(p_level, '')), 40), '')
  where id = auth.uid();
end $$;

-- ============================== Gestion du rattachement (administrateur) ==============================
create or replace function my_department() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); a department_accounts; d departments; i institutions;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into a from department_accounts where user_id = auth.uid();
  if a.user_id is null then
    return jsonb_build_object('role', r, 'attached', false, 'name', (select name from profiles where id = auth.uid()));
  end if;
  select * into d from departments where id = a.department_id;
  select * into i from institutions where id = d.institution_id;
  return jsonb_build_object('role', r, 'attached', r = 'dept', 'department_id', d.id, 'department', d.name, 'institution', coalesce(i.name, ''), 'institution_id', d.institution_id,
    'title', a.title, 'name', (select name from profiles where id = auth.uid()));
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
  insert into department_accounts (user_id, department_id, title, assigned_by) values (p_user, p_department, v_title, auth.uid())
  on conflict (user_id) do update set department_id = excluded.department_id, title = excluded.title, assigned_by = excluded.assigned_by, assigned_at = now();
  perform notify_user(p_user, 'department', 'Rattachement à un département', 'Votre compte gère désormais le département « ' || d.name || ' ».', jsonb_build_object('department', p_department));
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
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Rattachement retiré', left(t.name, 200), 'Départements', 'Sensible');
end $$;

create or replace function admin_dept_accounts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'suspended', coalesce(p.suspended, false), 'title', a.title,
      'department_id', a.department_id, 'department', d.name, 'institution', i.name, 'attached', a.user_id is not null) order by (a.user_id is null) desc, p.name)
    from profiles p left join department_accounts a on a.user_id = p.id left join departments d on d.id = a.department_id left join institutions i on i.id = d.institution_id
    where p.role::text = 'dept'), '[]'::jsonb);
end $$;

revoke all on function my_department(), admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid), admin_dept_accounts() from public, anon;
grant execute on function my_department(), admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid), admin_dept_accounts() to authenticated;
