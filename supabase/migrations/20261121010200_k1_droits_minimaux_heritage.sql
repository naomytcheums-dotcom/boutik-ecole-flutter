-- Lot K1 (3/4) : droits MINIMAUX des comptes Finance / Support et rattrapage de l'héritage de la migration H4 (20261120040000).
-- Problème : la migration H4 donnait aux comptes finance « leurs droits d'avant » (paiements, retraits, remboursements, virements) et aux comptes support leurs droits
-- dans Support ET Sécurité, et inscrivait chaque nouveau compte avec ces mêmes droits de base : un compte finance / support avait donc des opérations sensibles sans que
-- l'administrateur global les ait jamais attribuées. Corrigé :
--  1. droits de base d'un compte finance / support = AUCUNE permission : le compte est inscrit dans son équipe (lecture de son tableau de bord, sans chiffre ni outil) ;
--     toute opération sensible (retraits, remboursements, validation de paiement, virements, répartition, suspension, modération, clés d'API…) exige une permission
--     attribuée EXPLICITEMENT par l'administrateur (admin_team_member_set) ;
--  2. rattrapage : une ligne d'équipe qui n'a jamais été attribuée par l'administrateur (aucun événement grant / update dans admin_team_history, ou granted_by nul : migration,
--     inscription automatique) est réduite à l'ensemble minimal (équipe du rôle, aucune permission ; lignes d'autres équipes supprimées) ; une attribution explicite est conservée ;
--     chaque réduction est historisée (action reduce, permissions avant / après) et auditée ; les administrateurs sont prévenus ;
--  3. admin_team_accounts_review() : liste « à réviser » réservée à l'administrateur global (compte, équipe, permissions actuelles, permissions d'avant la réduction) ;
--  4. my_admin_access et admin_team_dashboard reconnaissent l'appartenance sans permission (tableau de bord vide d'indicateurs : seuls les indicateurs couverts par une permission sont renvoyés).
-- Idempotent. Retour arrière : redéfinir _admin_team_defaults, _admin_team_autoenroll, my_admin_access, admin_team_dashboard comme dans 20261120040000 / 043000 ;
--   drop function admin_team_accounts_review(), _admin_team_member_of(text), _admin_team_explicit(uuid, text) ; les permissions réduites ne sont pas restaurées automatiquement
--   (consulter admin_team_history, action reduce, before_permissions).

-- ============================================================ 1. Historique : nouvelle action « reduce »
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.admin_team_history'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%auto_enroll%' loop
    execute format('alter table admin_team_history drop constraint %I', c.conname);
  end loop;
  alter table admin_team_history add constraint admin_team_history_action_check
    check (action in ('grant', 'update', 'revoke', 'auto_enroll', 'auto_revoke', 'migration', 'reduce'));
exception when duplicate_object then null;
end $$;

-- ============================================================ 2. Droits de base : aucune permission
create or replace function _admin_team_defaults(p_team text) returns text[]
language sql immutable set search_path = public as $$
  select array[]::text[]
$$;
revoke all on function _admin_team_defaults(text) from public, anon, authenticated;

create or replace function _admin_team_autoenroll() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_team text;
begin
  if tg_op = 'UPDATE' and new.role is not distinct from old.role then return new; end if;
  if new.role::text in ('finance', 'support') then
    v_team := new.role::text;
    if not exists (select 1 from admin_team_members where user_id = new.id) then
      insert into admin_team_members (user_id, team_code, permissions, granted_by) values (new.id, v_team, '{}', null);
      insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
      values (auth.uid(), new.id, v_team, 'auto_enroll', '{}', '{}', 'Rôle attribué : inscription dans l''équipe, sans aucune permission (droits minimaux) : l''administrateur global attribue les permissions');
    end if;
  elsif tg_op = 'UPDATE' then
    insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
    select auth.uid(), m.user_id, m.team_code, 'auto_revoke', m.permissions, '{}', 'Le compte n''a plus de rôle d''équipe interne'
    from admin_team_members m where m.user_id = new.id;
    delete from admin_team_members where user_id = new.id;
  end if;
  return new;
end $$;

-- ============================================================ 3. Attribution explicite ?
-- Une ligne est « explicite » si l'administrateur l'a attribuée (granted_by renseigné ET événement grant / update d'un acteur identifié dans l'historique).
create or replace function _admin_team_explicit(p_user uuid, p_team text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admin_team_members m where m.user_id = p_user and m.team_code = p_team and m.granted_by is not null)
     and exists (select 1 from admin_team_history h where h.user_id = p_user and h.team_code = p_team and h.action in ('grant', 'update') and h.actor_id is not null)
$$;
revoke all on function _admin_team_explicit(uuid, text) from public, anon, authenticated;

-- ============================================================ 4. Rattrapage des comptes déjà migrés
do $$
declare r record; v_reduced int := 0; v_after text[]; v_target text; v_name text;
begin
  for r in select m.user_id, m.team_code, m.permissions, p.role::text as role, p.name
           from admin_team_members m join profiles p on p.id = m.user_id
           where not _admin_team_explicit(m.user_id, m.team_code) loop
    v_target := case when r.role in ('finance', 'support') then r.role else null end;
    if r.team_code = v_target then
      continue when cardinality(r.permissions) = 0 and exists (select 1 from admin_team_members x where x.user_id = r.user_id and x.team_code = r.team_code and x.granted_by is null);
      update admin_team_members set permissions = '{}', granted_by = null, updated_at = now() where user_id = r.user_id and team_code = r.team_code;
    else
      delete from admin_team_members where user_id = r.user_id and team_code = r.team_code;
    end if;
    insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
    values (null, r.user_id, r.team_code, 'reduce', r.permissions, '{}',
            'Rattrapage : droits hérités de la migration des comptes existants, jamais attribués par l''administrateur ; ramenés au minimum (aucune permission)');
    insert into audit_log (actor, actor_id, action, target, category, level)
    values ('Système', null, 'Équipe : droits hérités réduits', left(coalesce(r.name, r.user_id::text) || ' · ' || r.team_code || ' · ' || array_to_string(r.permissions, ', '), 200), 'Équipes', 'Critique');
    v_reduced := v_reduced + 1;
  end loop;
  if v_reduced > 0 then
    insert into notifications (user_id, kind, title, body, data)
    select a.id, 'security', 'Comptes Finance / Support à réviser',
           v_reduced || ' attribution(s) héritée(s) automatiquement ont été ramenées aux droits minimaux. Attribuez explicitement les permissions nécessaires dans « Équipes et permissions ».',
           jsonb_build_object('reduced', v_reduced)
    from profiles a where a.role::text = 'admin' and not coalesce(a.suspended, false);
  end if;
end $$;

-- ============================================================ 5. Lecture : appartenance sans permission
create or replace function _admin_team_member_of(p_team text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from profiles p join admin_team_members m on m.user_id = p.id
    where p.id = auth.uid() and not coalesce(p.suspended, false) and p.role::text in ('finance', 'support') and m.team_code = p_team)
$$;
revoke all on function _admin_team_member_of(text) from public, anon;
grant execute on function _admin_team_member_of(text) to authenticated;

do $$
declare v_def text; v_new text;
begin
  select pg_get_functiondef('public.admin_team_dashboard(text)'::regprocedure) into v_def;
  if position('_admin_team_member_of' in v_def) = 0 then
    v_new := replace(v_def, 'if not has_any_admin_permission(_admin_team_perms(p_team)) then raise exception',
                     'if not (has_any_admin_permission(_admin_team_perms(p_team)) or _admin_team_member_of(p_team)) then raise exception');
    v_new := replace(v_new, 'return jsonb_build_object(''team'', v_team, ''counters'', v);',
                     'return jsonb_build_object(''team'', v_team, ''counters'', v, ''minimal'', not has_any_admin_permission(_admin_team_perms(p_team)));');
    if v_new = v_def then raise exception 'admin_team_dashboard : remplacement sans effet'; end if;
    execute v_new;
  end if;
  select pg_get_functiondef('public.my_admin_access()'::regprocedure) into v_def;
  if position('cardinality(m.permissions) > 0' in v_def) > 0 then
    execute replace(v_def, ' and cardinality(m.permissions) > 0', '');
  end if;
end $$;

-- ============================================================ 6. Liste « à réviser » (administrateur global)
create or replace function admin_team_accounts_review() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _admin_only();
  return coalesce((
    select jsonb_agg(x order by (x ->> 'needs_review') desc, x ->> 'name')
    from (
      select jsonb_build_object(
        'user_id', p.id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'suspended', coalesce(p.suspended, false),
        'needs_review', not exists (select 1 from admin_team_members m where m.user_id = p.id and cardinality(m.permissions) > 0 and _admin_team_explicit(m.user_id, m.team_code)),
        'teams', (select coalesce(jsonb_agg(jsonb_build_object('team', m.team_code, 'permissions', to_jsonb(m.permissions), 'explicit', _admin_team_explicit(m.user_id, m.team_code)) order by m.team_code), '[]'::jsonb)
                  from admin_team_members m where m.user_id = p.id),
        'previous', (select coalesce(jsonb_agg(jsonb_build_object('team', h.team_code, 'permissions', to_jsonb(h.before_permissions), 'at', h.created_at) order by h.id), '[]'::jsonb)
                     from admin_team_history h where h.user_id = p.id and h.action = 'reduce')) as x
      from profiles p where p.role::text in ('finance', 'support')) s), '[]'::jsonb);
end $$;
revoke all on function admin_team_accounts_review() from public, anon;
grant execute on function admin_team_accounts_review() to authenticated;
