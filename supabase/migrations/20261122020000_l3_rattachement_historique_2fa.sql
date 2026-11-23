-- Lot L3 (1/3) : rattachement des comptes Département, procédure complète côté administrateur global.
--  1. Historique : table department_assignment_history (qui a rattaché / changé / retiré / confirmé quel compte, à quel département, quand, avec quelle fonction) ;
--     les rattachements existants avant ce lot sont repris UNE fois (action « existing », acteur = assigned_by, ou « repris par le système » s'il est nul).
--  2. admin_dept_assign / admin_dept_unassign : mêmes garde-fous qu'en 20261121030000 (connexion, administrateur global, compte Département, département vérifié et non ambigu,
--     notifications, audit) + garde 2FA INTERNE (_require_staff_aal2 : un administrateur avec facteur TOTP vérifié doit être en aal2, quel que soit le chemin d'appel) + historique.
--  3. admin_dept_assignments_history(p_user, p_limit) : lecture de l'historique (administrateur global seul).
--  4. admin_dept_accounts : ajoute l'e-mail (homonymes) ; le reste est inchangé.
-- Idempotent (rejouable). Retour arrière : drop function admin_dept_assignments_history(uuid, integer) ; drop table department_assignment_history ;
--   redéfinir admin_dept_assign, admin_dept_unassign, admin_dept_accounts depuis 20261121030000.

create table if not exists department_assignment_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  action text not null check (action in ('assign', 'change', 'confirm', 'unassign', 'existing')),
  department_id uuid references departments (id) on delete set null,
  department_name text,
  institution_name text,
  previous_department text,
  title text,
  actor_id uuid references profiles (id) on delete set null,
  note text check (note is null or char_length(note) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists department_assignment_history_user on department_assignment_history (user_id, id desc);
create index if not exists department_assignment_history_at on department_assignment_history (id desc);
alter table department_assignment_history enable row level security;
revoke all on department_assignment_history from public, anon, authenticated;

-- Reprise des rattachements existants (une seule fois par compte).
insert into department_assignment_history (user_id, action, department_id, department_name, institution_name, title, actor_id, note, created_at)
select a.user_id, 'existing', d.id, d.name, i.name, a.title, a.assigned_by,
       case when a.assigned_by is null then 'Repris automatiquement par le système avant le suivi des rattachements : à confirmer par l''administrateur'
            else 'Rattachement antérieur au suivi des rattachements' end,
       a.assigned_at
from department_accounts a join departments d on d.id = a.department_id left join institutions i on i.id = d.institution_id
where not exists (select 1 from department_assignment_history h where h.user_id = a.user_id);

create or replace function admin_dept_assign(p_user uuid, p_department uuid, p_title text default 'Responsable') returns void
language plpgsql security definer set search_path = public as $$
declare t profiles; d departments; v_inst text; v_prev department_accounts; v_prev_name text; v_action text;
        v_title text := coalesce(nullif(btrim(coalesce(p_title, '')), ''), 'Responsable');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  perform _require_staff_aal2();
  if char_length(v_title) > 80 then raise exception 'Fonction : 80 caractères au plus'; end if;
  select * into t from profiles where id = p_user;
  if t.id is null then raise exception 'Compte introuvable'; end if;
  if t.role::text <> 'dept' then raise exception 'Ce compte n''est pas un compte Département'; end if;
  select * into d from departments where id = p_department and status = 'verified';
  if d.id is null then raise exception 'Département introuvable ou non vérifié'; end if;
  if exists (select 1 from departments o where o.id <> d.id and o.institution_id = d.institution_id and o.status = 'verified' and _dept_norm(o.name) = _dept_norm(d.name)) then
    raise exception 'Le nom de ce département est ambigu dans son établissement : corrigez le référentiel avant de rattacher un compte';
  end if;
  select * into v_prev from department_accounts where user_id = p_user for update;
  select name into v_prev_name from departments where id = v_prev.department_id;
  select name into v_inst from institutions where id = d.institution_id;
  v_action := case when v_prev.user_id is null then 'assign' when v_prev.department_id = p_department then 'confirm' else 'change' end;
  insert into department_accounts (user_id, department_id, title, assigned_by) values (p_user, p_department, v_title, auth.uid())
  on conflict (user_id) do update set department_id = excluded.department_id, title = excluded.title, assigned_by = excluded.assigned_by, assigned_at = now();
  insert into department_assignment_history (user_id, action, department_id, department_name, institution_name, previous_department, title, actor_id)
  values (p_user, v_action, d.id, d.name, v_inst, v_prev_name, v_title, auth.uid());
  update notifications set read_at = now() where kind = 'department' and read_at is null and data->>'type' in ('unassigned', 'waiting') and (data->>'user' = p_user::text or user_id = p_user);
  perform notify_user(p_user, 'department', 'Rattachement à un département', 'Votre compte gère désormais le département « ' || d.name || ' ».', jsonb_build_object('department', p_department, 'type', 'attached'));
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Rattachement au département', left(t.name || ' -> ' || d.name, 200), 'Départements', 'Sensible');
end $$;

create or replace function admin_dept_unassign(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t profiles; v_prev department_accounts; v_prev_name text; v_inst text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  perform _require_staff_aal2();
  select * into t from profiles where id = p_user;
  if t.id is null then raise exception 'Compte introuvable'; end if;
  select * into v_prev from department_accounts where user_id = p_user for update;
  if v_prev.user_id is null then raise exception 'Ce compte n''est rattaché à aucun département'; end if;
  select d.name, i.name into v_prev_name, v_inst from departments d left join institutions i on i.id = d.institution_id where d.id = v_prev.department_id;
  delete from department_accounts where user_id = p_user;
  insert into department_assignment_history (user_id, action, department_id, department_name, institution_name, previous_department, title, actor_id)
  values (p_user, 'unassign', v_prev.department_id, v_prev_name, v_inst, v_prev_name, v_prev.title, auth.uid());
  if t.role::text = 'dept' then
    perform notify_user(p_user, 'department', 'Rattachement retiré', 'Votre compte n''est plus rattaché à un département : aucune donnée n''est affichée tant que l''administrateur ne vous a pas rattaché à nouveau.', jsonb_build_object('type', 'waiting'));
    perform _notify_admins_dept_unassigned(p_user, 'none');
  end if;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Rattachement retiré', left(t.name, 200), 'Départements', 'Sensible');
end $$;

create or replace function admin_dept_accounts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'email', p.email, 'suspended', coalesce(p.suspended, false), 'title', a.title,
      'department_id', a.department_id, 'department', d.name, 'institution', i.name,
      'attached', _dept_attachment_state(p.id) = 'ok', 'state', _dept_attachment_state(p.id),
      'to_review', a.user_id is not null and a.assigned_by is null, 'assigned_at', a.assigned_at)
      order by (_dept_attachment_state(p.id) = 'ok'), p.name)
    from profiles p left join department_accounts a on a.user_id = p.id left join departments d on d.id = a.department_id left join institutions i on i.id = d.institution_id
    where p.role::text = 'dept'), '[]'::jsonb);
end $$;

create or replace function admin_dept_assignments_history(p_user uuid default null, p_limit integer default 60) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', h.id, 'at', h.created_at, 'action', h.action, 'user_id', h.user_id, 'user', u.name, 'department', h.department_name, 'institution', h.institution_name,
      'previous', h.previous_department, 'title', h.title, 'actor', (select a.name from profiles a where a.id = h.actor_id), 'note', h.note) order by h.id desc)
    from (select * from department_assignment_history where p_user is null or user_id = p_user order by id desc limit least(greatest(coalesce(p_limit, 60), 1), 200)) h
    join profiles u on u.id = h.user_id), '[]'::jsonb);
end $$;

revoke all on function admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid), admin_dept_accounts(), admin_dept_assignments_history(uuid, integer) from public, anon;
grant execute on function admin_dept_assign(uuid, uuid, text), admin_dept_unassign(uuid), admin_dept_accounts(), admin_dept_assignments_history(uuid, integer) to authenticated;
