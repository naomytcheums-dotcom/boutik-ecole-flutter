-- Lot H12 / TOP100-A (1/4) : référentiel des filières et rattachement des étudiants (CDC Top 100, 1.4 et 9).
--  1. nouvelle équipe d'administration « ranking » (Classement et talents) et permission SENSIBLE « institutions.manage » : attribuée explicitement par l'administrateur global,
--     absente de tout jeu de droits par défaut (_admin_team_defaults inchangé). Les contraintes de code d'équipe / de permission sont ÉLARGIES (rien n'est retiré) ;
--  2. programs (filières) par établissement et, au besoin, par département, administrables par « institutions.manage » ;
--  3. institution_managers : responsables institutionnels nommés par l'administration pour UN établissement (périmètre = cet établissement) ;
--  4. student_affiliations : demande de rattachement d'un étudiant à une filière (pending / verified / rejected), validée par l'administration, le responsable de l'établissement
--     ou le responsable du département de la filière (périmètre strict) ; une seule demande en attente et un seul rattachement vérifié en cours par étudiant ;
--     student_affiliation_history conserve chaque événement (demande, validation, refus, fin) ;
--  5. RPC : programs_list, admin_program_upsert, admin_institution_manager_set, student_affiliation_request, my_student_affiliation, student_affiliation_queue,
--     student_affiliation_decide, student_affiliation_history_list.
-- Aucun établissement, département, filière, rattachement ni étudiant n'est inséré (le référentiel est vide en production par décision du propriétaire).
-- Additive et rejouable. Retour arrière :
--   drop function programs_list(uuid, uuid), admin_program_upsert(uuid, uuid, uuid, text, boolean), admin_institution_manager_set(uuid, uuid, boolean), student_affiliation_request(uuid, text),
--     my_student_affiliation(), student_affiliation_queue(), student_affiliation_decide(uuid, text, text), student_affiliation_history_list(uuid), _top100_admin(text), _top100_audit(text, text, text),
--     _affiliation_scope_ok(uuid), _affiliation_guard(), _program_guard(); drop table student_affiliation_history, student_affiliations, institution_managers, programs ;
--   delete from admin_team_members where team_code = 'ranking'; delete from admin_permissions where team_code = 'ranking'; delete from admin_teams where code = 'ranking'.

-- ============================================================ 1. Équipe et permission
do $$
declare c record;
begin
  for c in select conrelid::regclass::text t, conname from pg_constraint
           where contype = 'c' and conrelid in ('admin_teams'::regclass, 'admin_permissions'::regclass) and conname not like '%v2' and pg_get_constraintdef(oid) like '%finance%' loop
    execute format('alter table %s drop constraint %I', c.t, c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'admin_teams_code_check_v2') then
    alter table admin_teams add constraint admin_teams_code_check_v2 check (code in ('finance', 'support', 'security', 'tech', 'ranking'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'admin_permissions_code_check_v2') then
    alter table admin_permissions add constraint admin_permissions_code_check_v2 check (code ~ '^(finance|support|security|tech|ranking|institutions)\.[a-z_]+$');
  end if;
end $$;

insert into admin_teams (code, name, description, position) values
  ('ranking', 'Classement et talents', 'Référentiel des établissements et filières, règles de score, publication et modération du Top 100 des talents.', 5)
on conflict (code) do update set name = excluded.name, description = excluded.description, position = excluded.position;
insert into admin_permissions (code, team_code, label, description, sensitive, position) values
  ('institutions.manage', 'ranking', 'Référentiel établissements et filières', 'Gérer les filières, nommer les responsables d''établissement et valider les rattachements des étudiants.', true, 1)
on conflict (code) do update set team_code = excluded.team_code, label = excluded.label, description = excluded.description, sensitive = excluded.sensitive, position = excluded.position;

-- ============================================================ 2. Gardes communes du lot
create or replace function _top100_admin(p_perm text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission(p_perm) then raise exception 'Réservé : exige la permission %', p_perm; end if;
  perform _require_staff_aal2();
end $$;
revoke all on function _top100_admin(text) from public, anon, authenticated;

create or replace function _top100_audit(p_action text, p_target text, p_level text default 'Sensible') returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Système'), auth.uid(), left(p_action, 120), left(p_target, 200), 'Classement', p_level);
end $$;
revoke all on function _top100_audit(text, text, text) from public, anon, authenticated;

-- ============================================================ 3. Tables
create table if not exists programs (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references institutions (id) on delete cascade,
  department_id uuid references departments (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 120),
  active boolean not null default true,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists programs_name_key on programs (institution_id, coalesce(department_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(btrim(name)));
create index if not exists programs_department on programs (department_id) where department_id is not null;

create or replace function _program_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.department_id is not null and not exists (select 1 from departments d where d.id = new.department_id and d.institution_id = new.institution_id) then
    raise exception 'Le département n''appartient pas à cet établissement';
  end if;
  new.name := btrim(new.name);
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_program_guard on programs;
create trigger trg_program_guard before insert or update on programs for each row execute function _program_guard();

create table if not exists institution_managers (
  user_id uuid not null references profiles (id) on delete cascade,
  institution_id uuid not null references institutions (id) on delete cascade,
  assigned_by uuid references profiles (id) on delete set null,
  assigned_at timestamptz not null default now(),
  primary key (user_id, institution_id)
);

create table if not exists student_affiliations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  institution_id uuid not null references institutions (id) on delete cascade,
  department_id uuid references departments (id) on delete set null,
  program_id uuid not null references programs (id) on delete cascade,
  promotion text not null check (char_length(btrim(promotion)) between 2 and 20),
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
  requested_at timestamptz not null default now(),
  decided_by uuid references profiles (id) on delete set null,
  decided_at timestamptz,
  decision_note text check (decision_note is null or char_length(decision_note) <= 500),
  ended_at timestamptz
);
create unique index if not exists student_affiliations_one_pending on student_affiliations (user_id) where status = 'pending';
create unique index if not exists student_affiliations_one_current on student_affiliations (user_id) where status = 'verified' and ended_at is null;
create index if not exists student_affiliations_program on student_affiliations (program_id) where status = 'verified' and ended_at is null;
create index if not exists student_affiliations_institution on student_affiliations (institution_id, status);

create table if not exists student_affiliation_history (
  id bigint generated always as identity primary key,
  affiliation_id uuid not null references student_affiliations (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  action text not null check (action in ('requested', 'verified', 'rejected', 'ended')),
  actor_id uuid references profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists student_affiliation_history_user on student_affiliation_history (user_id, id desc);

alter table programs enable row level security;
alter table institution_managers enable row level security;
alter table student_affiliations enable row level security;
alter table student_affiliation_history enable row level security;
revoke all on programs, institution_managers, student_affiliations, student_affiliation_history from public, anon, authenticated;
grant select on programs, student_affiliations to authenticated;
drop policy if exists "filières : actives" on programs;
create policy "filières : actives" on programs for select to authenticated using (active or has_admin_permission('institutions.manage'));
drop policy if exists "rattachements : l'étudiant" on student_affiliations;
create policy "rattachements : l'étudiant" on student_affiliations for select to authenticated using (user_id = auth.uid());

-- Un rattachement ne change ni d'étudiant ni de filière ; seul le statut avance, une décision est définitive.
create or replace function _affiliation_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then return old; end if;
  if new.user_id is distinct from old.user_id or new.program_id is distinct from old.program_id or new.institution_id is distinct from old.institution_id
     or new.promotion is distinct from old.promotion then
    raise exception 'Un rattachement n''est pas modifiable : déposez une nouvelle demande';
  end if;
  if old.status in ('rejected') and new.status is distinct from old.status then raise exception 'Une demande refusée est définitive'; end if;
  if old.status = 'verified' and new.status is distinct from 'verified' then raise exception 'Un rattachement vérifié ne revient pas en arrière'; end if;
  return new;
end $$;
drop trigger if exists trg_affiliation_guard on student_affiliations;
create trigger trg_affiliation_guard before update on student_affiliations for each row execute function _affiliation_guard();

-- ============================================================ 4. Périmètre de validation
-- Vrai pour : l'administration (permission institutions.manage), un responsable de l'établissement, le responsable du département de la filière.
create or replace function _affiliation_scope_ok(p_aff uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare a student_affiliations; v_dept uuid;
begin
  if auth.uid() is null then return false; end if;
  select * into a from student_affiliations where id = p_aff;
  if a.id is null then return false; end if;
  if has_admin_permission('institutions.manage') then return true; end if;
  if exists (select 1 from institution_managers m join profiles p on p.id = m.user_id
             where m.user_id = auth.uid() and m.institution_id = a.institution_id and not coalesce(p.suspended, false)) then return true; end if;
  select department_id into v_dept from programs where id = a.program_id;
  return v_dept is not null and _dept_of(auth.uid()) is not distinct from v_dept;
end $$;
revoke all on function _affiliation_scope_ok(uuid) from public, anon, authenticated;

-- ============================================================ 5. RPC : filières
create or replace function programs_list(p_institution uuid, p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_institution is null then raise exception 'Établissement obligatoire'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name, 'institution_id', g.institution_id, 'department_id', g.department_id, 'active', g.active) order by g.name)
    from programs g join institutions i on i.id = g.institution_id
    where g.institution_id = p_institution and i.status = 'verified' and (p_department is null or g.department_id = p_department)
      and (g.active or has_admin_permission('institutions.manage'))), '[]'::jsonb);
end $$;

create or replace function admin_program_upsert(p_id uuid, p_institution uuid, p_department uuid, p_name text, p_active boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text := btrim(coalesce(p_name, ''));
begin
  perform _top100_admin('institutions.manage');
  if char_length(v_name) not between 2 and 120 then raise exception 'Nom de filière : 2 à 120 caractères'; end if;
  if p_id is null then
    if not exists (select 1 from institutions where id = p_institution and status = 'verified') then raise exception 'Établissement introuvable ou non vérifié'; end if;
    insert into programs (institution_id, department_id, name, active, created_by) values (p_institution, p_department, v_name, coalesce(p_active, true), auth.uid()) returning id into v_id;
    perform _top100_audit('Filière créée', v_id::text);
  else
    update programs set name = v_name, active = coalesce(p_active, active), department_id = coalesce(p_department, department_id) where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Filière introuvable'; end if;
    perform _top100_audit('Filière modifiée', v_id::text);
  end if;
  return jsonb_build_object('ok', true, 'id', v_id);
exception when unique_violation then raise exception 'Cette filière existe déjà dans cet établissement';
end $$;

create or replace function admin_institution_manager_set(p_user uuid, p_institution uuid, p_on boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _top100_admin('institutions.manage');
  if not exists (select 1 from profiles where id = p_user) then raise exception 'Compte introuvable'; end if;
  if not exists (select 1 from institutions where id = p_institution) then raise exception 'Établissement introuvable'; end if;
  if p_on then
    if exists (select 1 from profiles where id = p_user and role::text = 'student') then raise exception 'Un compte étudiant ne peut pas être responsable d''établissement'; end if;
    insert into institution_managers (user_id, institution_id, assigned_by) values (p_user, p_institution, auth.uid()) on conflict do nothing;
  else
    delete from institution_managers where user_id = p_user and institution_id = p_institution;
  end if;
  perform _top100_audit(case when p_on then 'Responsable d''établissement nommé' else 'Responsable d''établissement retiré' end, p_user::text || ' · ' || p_institution::text);
  return jsonb_build_object('ok', true, 'user', p_user, 'institution', p_institution, 'manager', coalesce(p_on, false));
end $$;

-- ============================================================ 6. RPC : rattachement de l'étudiant
create or replace function student_affiliation_request(p_program uuid, p_promotion text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare g programs; v_id uuid; v_promo text := btrim(coalesce(p_promotion, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Réservé aux comptes étudiants'; end if;
  if char_length(v_promo) not between 2 and 20 then raise exception 'Promotion : 2 à 20 caractères'; end if;
  select * into g from programs where id = p_program and active;
  if g.id is null or not exists (select 1 from institutions where id = g.institution_id and status = 'verified') then raise exception 'Filière introuvable'; end if;
  if exists (select 1 from student_affiliations where user_id = auth.uid() and status = 'verified' and ended_at is null and program_id = g.id and promotion = v_promo) then
    raise exception 'Vous êtes déjà rattaché(e) à cette filière';
  end if;
  begin
    insert into student_affiliations (user_id, institution_id, department_id, program_id, promotion) values (auth.uid(), g.institution_id, g.department_id, g.id, v_promo) returning id into v_id;
  exception when unique_violation then raise exception 'Une demande de rattachement est déjà en attente';
  end;
  insert into student_affiliation_history (affiliation_id, user_id, action, actor_id) values (v_id, auth.uid(), 'requested', auth.uid());
  return jsonb_build_object('ok', true, 'id', v_id, 'status', 'pending');
end $$;

create or replace function my_student_affiliation() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'current', (select jsonb_build_object('id', a.id, 'status', a.status, 'promotion', a.promotion, 'program_id', a.program_id, 'program', g.name,
                  'institution_id', a.institution_id, 'institution', i.name, 'department_id', a.department_id, 'requested_at', a.requested_at, 'decided_at', a.decided_at, 'decision_note', a.decision_note)
                from student_affiliations a join programs g on g.id = a.program_id join institutions i on i.id = a.institution_id
                where a.user_id = auth.uid() and a.ended_at is null and a.status in ('pending', 'verified')
                order by (a.status = 'pending') desc, a.requested_at desc limit 1),
    'history', coalesce((select jsonb_agg(jsonb_build_object('action', h.action, 'at', h.created_at, 'note', h.note) order by h.id desc)
                from (select * from student_affiliation_history where user_id = auth.uid() order by id desc limit 50) h), '[]'::jsonb));
end $$;

-- ============================================================ 7. RPC : validation (administration, responsable d'établissement ou de département)
create or replace function student_affiliation_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'student', display_name(a.user_id), 'promotion', a.promotion, 'program_id', a.program_id, 'program', g.name,
      'institution_id', a.institution_id, 'institution', i.name, 'department_id', g.department_id, 'requested_at', a.requested_at) order by a.requested_at)
    from student_affiliations a join programs g on g.id = a.program_id join institutions i on i.id = a.institution_id
    where a.status = 'pending' and _affiliation_scope_ok(a.id)), '[]'::jsonb);
end $$;

create or replace function student_affiliation_decide(p_id uuid, p_decision text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a student_affiliations; v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_decision is null or p_decision not in ('verified', 'rejected') then raise exception 'Décision inconnue (verified ou rejected)'; end if;
  if v_note is not null and char_length(v_note) > 500 then raise exception 'Note : 500 caractères au plus'; end if;
  if p_decision = 'rejected' and v_note is null then raise exception 'Motivez le refus'; end if;
  select * into a from student_affiliations where id = p_id for update;
  if a.id is null or not _affiliation_scope_ok(p_id) then raise exception 'Demande introuvable ou hors de votre périmètre'; end if;
  if has_admin_permission('institutions.manage') then perform _require_staff_aal2(); end if;
  if a.user_id = auth.uid() then raise exception 'Vous ne pouvez pas valider votre propre rattachement'; end if;
  if a.status <> 'pending' then raise exception 'Cette demande a déjà été traitée'; end if;
  if p_decision = 'verified' then
    update student_affiliations set ended_at = now() where user_id = a.user_id and status = 'verified' and ended_at is null;
    insert into student_affiliation_history (affiliation_id, user_id, action, actor_id, note)
      select s.id, s.user_id, 'ended', auth.uid(), 'Remplacé par un nouveau rattachement' from student_affiliations s where s.user_id = a.user_id and s.status = 'verified' and s.ended_at is not null and s.id <> a.id
        and not exists (select 1 from student_affiliation_history h where h.affiliation_id = s.id and h.action = 'ended');
  end if;
  update student_affiliations set status = p_decision, decided_by = auth.uid(), decided_at = now(), decision_note = v_note where id = a.id;
  insert into student_affiliation_history (affiliation_id, user_id, action, actor_id, note) values (a.id, a.user_id, p_decision, auth.uid(), v_note);
  perform _top100_audit('Rattachement étudiant : ' || p_decision, a.id::text, 'Info');
  perform notify_user(a.user_id, 'profile', case p_decision when 'verified' then 'Votre filière est confirmée' else 'Votre rattachement à une filière est refusé' end,
    coalesce(v_note, 'Votre rattachement a été validé.'), jsonb_build_object('affiliation', a.id, 'status', p_decision));
  return jsonb_build_object('ok', true, 'id', a.id, 'status', p_decision);
end $$;

create or replace function student_affiliation_history_list(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := coalesce(p_user, auth.uid());
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_user <> auth.uid() and not exists (select 1 from student_affiliations a where a.user_id = v_user and _affiliation_scope_ok(a.id)) then
    raise exception 'Accès refusé : hors de votre périmètre';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('affiliation_id', h.affiliation_id, 'action', h.action, 'at', h.created_at, 'note', h.note,
      'program', g.name, 'institution', i.name, 'promotion', a.promotion) order by h.id desc)
    from student_affiliation_history h join student_affiliations a on a.id = h.affiliation_id join programs g on g.id = a.program_id join institutions i on i.id = a.institution_id
    where h.user_id = v_user), '[]'::jsonb);
end $$;

revoke all on function programs_list(uuid, uuid), admin_program_upsert(uuid, uuid, uuid, text, boolean), admin_institution_manager_set(uuid, uuid, boolean),
  student_affiliation_request(uuid, text), my_student_affiliation(), student_affiliation_queue(), student_affiliation_decide(uuid, text, text), student_affiliation_history_list(uuid) from public, anon;
grant execute on function programs_list(uuid, uuid), admin_program_upsert(uuid, uuid, uuid, text, boolean), admin_institution_manager_set(uuid, uuid, boolean),
  student_affiliation_request(uuid, text), my_student_affiliation(), student_affiliation_queue(), student_affiliation_decide(uuid, text, text), student_affiliation_history_list(uuid) to authenticated;
