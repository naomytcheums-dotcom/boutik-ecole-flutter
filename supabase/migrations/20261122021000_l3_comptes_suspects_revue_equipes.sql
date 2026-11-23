-- Lot L3 (2/3) : l'administrateur global TRANCHE les comptes suspects transmis, et confirme explicitement les droits minimaux d'un ancien compte Finance / Support.
--  1. security_flag_resolve(p_id, p_decision, p_note) : décision de l'administrateur global sur un signalement ouvert ou transmis : « suspend » (suspension réelle du compte
--     par admin_set_account : connexion bloquée, sessions fermées, audit) ou « dismiss » (classé, motif obligatoire). Le signalement passe à « suspended » ou « cleared »,
--     l'auteur du signalement est prévenu. Garde 2FA ajoutée à enforce_mfa_on_sensitive (compte avec facteur TOTP vérifié : aal2 exigé) et garde interne _require_staff_aal2.
--     security_flags_list accepte le nouveau statut « suspended ».
--  2. admin_team_account_keep_minimal(p_user, p_note) : l'administrateur global confirme, avec un motif, qu'un compte Finance / Support doit garder les droits minimaux
--     (aucune permission) ; l'événement « keep_minimal » est historisé et audité, et le compte sort de la liste « à réviser » (jusqu'à un changement de rôle ou une réduction).
--     admin_team_accounts_review ajoute « minimal_confirmed » ; needs_review tient compte de la confirmation.
-- Idempotent. Retour arrière : drop function security_flag_resolve(uuid, text, text), admin_team_account_keep_minimal(uuid, text) ; redéfinir security_flags_list depuis 20261120042000
--   et admin_team_accounts_review depuis 20261121010200 ; remettre les contraintes account_flags_status_check / admin_team_history_action_check sans les nouvelles valeurs
--   (après avoir converti les lignes « suspended » en « escalated » et supprimé les événements « keep_minimal »).

-- ============================================================ 1. Statuts et actions
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.account_flags'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%escalated%' loop
    execute format('alter table account_flags drop constraint %I', c.conname);
  end loop;
  alter table account_flags add constraint account_flags_status_check check (status in ('open', 'cleared', 'escalated', 'suspended'));
exception when duplicate_object then null;
end $$;

do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.admin_team_history'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%auto_enroll%' loop
    execute format('alter table admin_team_history drop constraint %I', c.conname);
  end loop;
  alter table admin_team_history add constraint admin_team_history_action_check
    check (action in ('grant', 'update', 'revoke', 'auto_enroll', 'auto_revoke', 'migration', 'reduce', 'keep_minimal'));
exception when duplicate_object then null;
end $$;

-- ============================================================ 2. Comptes suspects : décision de l'administrateur global
create or replace function security_flags_list(p_status text default 'open') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _security_accounts_guard();
  if p_status is not null and p_status not in ('open', 'cleared', 'escalated', 'suspended', '') then raise exception 'Statut inconnu'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', f.id, 'user_id', f.user_id, 'name', u.name, 'email', u.email, 'role', u.role::text, 'suspended', coalesce(u.suspended, false),
      'reason', f.reason, 'status', f.status, 'created_at', f.created_at, 'flagged_by', (select b.name from profiles b where b.id = f.flagged_by),
      'decided_at', f.decided_at, 'decided_by', (select b.name from profiles b where b.id = f.decided_by), 'decision_note', f.decision_note) order by f.created_at desc)
    from (select * from account_flags where nullif(p_status, '') is null or status = p_status order by created_at desc limit 100) f
    join profiles u on u.id = f.user_id), '[]'::jsonb);
end $$;

create or replace function security_flag_resolve(p_id uuid, p_decision text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare f account_flags%rowtype; v_note text := nullif(left(btrim(coalesce(p_note, '')), 500), ''); v_role app_role; v_name text; v_who text;
begin
  perform _admin_only();
  perform _require_staff_aal2();
  if p_decision not in ('suspend', 'dismiss') then raise exception 'Décision inconnue'; end if;
  select * into f from account_flags where id = p_id for update;
  if not found or f.status not in ('open', 'escalated') then raise exception 'Signalement introuvable ou déjà tranché'; end if;
  if p_decision = 'dismiss' and (v_note is null or char_length(v_note) < 5) then raise exception 'Indiquez pourquoi le signalement est classé (5 caractères au moins)'; end if;
  select role, name into v_role, v_name from profiles where id = f.user_id;
  if v_role is null then raise exception 'Compte introuvable'; end if;
  if p_decision = 'suspend' then
    perform admin_set_account(f.user_id, v_role, true);
  end if;
  update account_flags set status = case p_decision when 'suspend' then 'suspended' else 'cleared' end, decided_by = auth.uid(), decided_at = now(),
         decision_note = coalesce(v_note, decision_note) where id = f.id;
  select name into v_who from profiles where id = auth.uid();
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(v_who, 'Administrateur'), auth.uid(), case p_decision when 'suspend' then 'Compte suspect suspendu' else 'Signalement de compte classé' end, left(coalesce(v_name, f.user_id::text), 200), 'Sécurité', 'Sensible');
  if f.flagged_by is not null and f.flagged_by <> auth.uid() then
    insert into notifications (user_id, kind, title, body, data)
    values (f.flagged_by, 'security', case p_decision when 'suspend' then 'Compte suspendu par l''administrateur' else 'Signalement classé par l''administrateur' end,
            left(coalesce(v_name, 'Le compte') || coalesce(' : ' || v_note, ''), 300), jsonb_build_object('flag', f.id, 'user', f.user_id));
  end if;
  return p_decision;
end $$;
revoke all on function security_flags_list(text), security_flag_resolve(uuid, text, text) from public, anon;
grant execute on function security_flags_list(text), security_flag_resolve(uuid, text, text) to authenticated;

-- ============================================================ 3. Revue des anciens comptes Finance / Support
create or replace function admin_team_account_keep_minimal(p_user uuid, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), ''); v_team text; v_perms text[];
begin
  perform _admin_only();
  perform _require_staff_aal2();
  if p_user is null or p_user = auth.uid() then raise exception 'Vous ne pouvez pas modifier vos propres droits d''équipe'; end if;
  if v_note is null or char_length(v_note) < 5 then raise exception 'Indiquez pourquoi ce compte garde les droits minimaux (5 caractères au moins)'; end if;
  select role::text, name into v_role, v_name from profiles where id = p_user;
  if v_role is null then raise exception 'Compte introuvable'; end if;
  if v_role not in ('finance', 'support') then raise exception 'Seuls les comptes de rôle Finance ou Support sont concernés'; end if;
  if exists (select 1 from admin_team_members m where m.user_id = p_user and cardinality(m.permissions) > 0) then
    raise exception 'Ce compte a déjà des permissions : modifiez-les depuis son équipe';
  end if;
  v_team := v_role;
  select coalesce(array_agg(distinct x), '{}') into v_perms from admin_team_members m, unnest(m.permissions) x where m.user_id = p_user;
  insert into admin_team_members (user_id, team_code, permissions, granted_by) values (p_user, v_team, '{}', auth.uid())
  on conflict (user_id, team_code) do nothing;
  insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
  values (auth.uid(), p_user, v_team, 'keep_minimal', v_perms, '{}', v_note);
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Équipe : droits minimaux confirmés', left(coalesce(v_name, p_user::text) || ' · ' || v_team, 200), 'Équipes', 'Critique');
  return jsonb_build_object('user', p_user, 'team', v_team, 'minimal_confirmed', true);
end $$;
revoke all on function admin_team_account_keep_minimal(uuid, text) from public, anon;
grant execute on function admin_team_account_keep_minimal(uuid, text) to authenticated;

create or replace function _admin_team_minimal_confirmed(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admin_team_history h where h.user_id = p_user and h.action = 'keep_minimal'
                 and h.id > coalesce((select max(x.id) from admin_team_history x where x.user_id = p_user and x.action in ('auto_enroll', 'auto_revoke', 'reduce', 'revoke', 'grant', 'update')), 0))
$$;
revoke all on function _admin_team_minimal_confirmed(uuid) from public, anon, authenticated;

create or replace function admin_team_accounts_review() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _admin_only();
  return coalesce((
    select jsonb_agg(x order by (x ->> 'needs_review') desc, x ->> 'name')
    from (
      select jsonb_build_object(
        'user_id', p.id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'suspended', coalesce(p.suspended, false),
        'needs_review', not exists (select 1 from admin_team_members m where m.user_id = p.id and cardinality(m.permissions) > 0 and _admin_team_explicit(m.user_id, m.team_code))
                        and not _admin_team_minimal_confirmed(p.id),
        'minimal_confirmed', _admin_team_minimal_confirmed(p.id),
        'teams', (select coalesce(jsonb_agg(jsonb_build_object('team', m.team_code, 'permissions', to_jsonb(m.permissions), 'explicit', _admin_team_explicit(m.user_id, m.team_code)) order by m.team_code), '[]'::jsonb)
                  from admin_team_members m where m.user_id = p.id),
        'previous', (select coalesce(jsonb_agg(jsonb_build_object('team', h.team_code, 'permissions', to_jsonb(h.before_permissions), 'at', h.created_at) order by h.id), '[]'::jsonb)
                     from admin_team_history h where h.user_id = p.id and h.action = 'reduce')) as x
      from profiles p where p.role::text in ('finance', 'support')) s), '[]'::jsonb);
end $$;
revoke all on function admin_team_accounts_review() from public, anon;
grant execute on function admin_team_accounts_review() to authenticated;

-- ============================================================ 4. 2FA serveur : nouvelles opérations sensibles (liste complétée, rien n'est retiré)
do $$
declare
  r record; v_def text; v_new text; v_list text; v_name text; v_add text[] := '{}';
  c_all constant text[] := array['security_flag_resolve', 'admin_team_account_keep_minimal'];
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'enforce_mfa_on_sensitive' loop
    v_def := pg_get_functiondef(r.oid);
    v_list := substring(v_def from '\^/rpc/\(request_account_deletion\|([^'')]*)\)\$''');
    if v_list is null then raise exception 'enforce_mfa_on_sensitive : liste des opérations sensibles introuvable'; end if;
    v_add := '{}';
    foreach v_name in array c_all loop
      if not (v_name = any(string_to_array(v_list, '|'))) then v_add := v_add || v_name; end if;
    end loop;
    if cardinality(v_add) = 0 then continue; end if;
    v_new := replace(v_def, '^/rpc/(request_account_deletion|' || v_list || ')$''', '^/rpc/(request_account_deletion|' || v_list || '|' || array_to_string(v_add, '|') || ')$''');
    if v_new = v_def then raise exception 'enforce_mfa_on_sensitive : remplacement sans effet'; end if;
    execute v_new;
  end loop;
end $$;
