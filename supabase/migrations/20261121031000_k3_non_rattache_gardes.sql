-- Lot K3 « Département » (2/3) : un compte Département sans rattachement valide ne lit, n'écrit et ne reçoit rien ; les notifications départementales ne vont qu'aux comptes du bon département.
-- Audit des définitions en vigueur (après 20261121030000) : modifications SUR PLACE (la définition courante est relue, garde-fous conservés), un contrôle de plus par fonction :
--  - save_mission : « Nouveau besoin à qualifier » aux administrateurs et aux seuls comptes rattachés au département du porteur (et non plus à tous les comptes dept) ;
--  - profiles_name_recertify : prévenus = administrateurs et comptes rattachés au département de la personne (et non l'égalité de texte libre) ;
--  - save_wish : destinataires = comptes validement rattachés au département de l'auteur ;
--  - open_calls / open_needs_list / open_needs : un compte Département ne voit les besoins « mission » (réservés à la qualification) que de SON département ;
--  - sos_list : la filière d'un compte Département est celle de son rattachement valide (et non le texte libre de son profil) ;
--  - event_create / event_update / event_cancel / events_managed / event_registrants, challenge_create, invite_department_member : refus sans rattachement valide ;
--  - admin_users : le compteur d'étudiants de la ligne d'un compte Département ne porte que sur son rattachement valide (plus sur un département hérité en texte) ;
--  - ann_save : un concours déposé par un compte Département non rattaché n'est plus publié d'office ;
--  - is_contest_staff / is_platform_manager : le rôle dept n'y entre que rattaché.
-- Retour arrière : select _k3_patch_fn(nom, '', array[nouveau, ancien]) avec les motifs inversés ; recréer is_contest_staff (20261105000800) et is_platform_manager ; drop function _k3_patch_fn(text, text, text[]).

create or replace function _k3_patch_fn(p_name text, p_sig text, p_pairs text[]) returns integer
language plpgsql set search_path = public as $$
declare r record; v_def text; v_new text; i integer; pos integer; n integer := 0; v_hit integer := 0;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name and p.prokind = 'f'
             and (p_sig = '' or pg_get_function_identity_arguments(p.oid) ilike '%' || p_sig || '%') loop
    v_hit := v_hit + 1;
    v_def := replace(pg_get_functiondef(r.oid), E'\r\n', E'\n');
    v_new := v_def;
    i := 1;
    while i < array_length(p_pairs, 1) loop
      if position(p_pairs[i + 1] in v_new) = 0 then   -- motif déjà posé : rien à faire
        pos := position(p_pairs[i] in v_new);
        if pos = 0 then raise exception 'K3 : motif absent dans % (%)', p_name, left(p_pairs[i], 80); end if;
        v_new := overlay(v_new placing p_pairs[i + 1] from pos for char_length(p_pairs[i]));
      end if;
      i := i + 2;
    end loop;
    if v_new <> v_def then execute v_new; n := n + 1; end if;
  end loop;
  if v_hit = 0 then raise exception 'K3 : fonction introuvable : %', p_name; end if;
  return n;
end $$;
revoke all on function _k3_patch_fn(text, text, text[]) from public, anon, authenticated;

-- ============================== Notifications départementales ==============================
select _k3_patch_fn('save_mission', '', array[
  $k3$for r in select id from profiles where role::text in ('dept', 'admin') and not suspended and id <> v_actor loop$k3$,
  $k3$for r in select x as id from _owner_reviewers(v_owner) x where x <> v_actor loop$k3$]);

select _k3_patch_fn('profiles_name_recertify', '', array[
  $k3$(p.role::text = 'dept' and lower(coalesce(p.department, '')) = lower(coalesce(new.department, '')))$k3$,
  $k3$(p.role::text = 'dept' and new.department_id is not null and _dept_of(p.id) = new.department_id)$k3$]);

select _k3_patch_fn('save_wish', '', array[
  $k3$select array_agg(id) into v_to from profiles where role::text = 'dept' and not coalesce(suspended, false) and me.department_id is not null and department_id = me.department_id;$k3$,
  $k3$select array_agg(p.id) into v_to from profiles p where p.role::text = 'dept' and not coalesce(p.suspended, false) and me.department_id is not null and _dept_of(p.id) = me.department_id;$k3$]);

-- ============================== Besoins « mission » réservés à la qualification ==============================
select _k3_patch_fn('open_calls', '', array[
  $k3$v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');$k3$, $k3$v_staff boolean := coalesce(current_role_name()::text, '') = 'admin';$k3$,
  $k3$(m.kind is distinct from 'mission' or m.client_id = uid or v_staff)$k3$, $k3$(m.kind is distinct from 'mission' or m.client_id = uid or v_staff or _dept_sees(m.client_id))$k3$]);

select _k3_patch_fn('open_needs_list', '', array[
  $k3$v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');$k3$, $k3$v_staff boolean := coalesce(current_role_name()::text, '') = 'admin';$k3$,
  $k3$(m.kind is distinct from 'mission' or m.client_id = uid or v_staff)$k3$, $k3$(m.kind is distinct from 'mission' or m.client_id = uid or v_staff or _dept_sees(m.client_id))$k3$]);

select _k3_patch_fn('open_needs', '', array[
  $k3$(kind is distinct from 'mission' or coalesce(current_role_name()::text, '') in ('dept', 'admin'))$k3$,
  $k3$(kind is distinct from 'mission' or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(client_id))$k3$]);

-- ============================== Filière d'un compte Département ==============================
select _k3_patch_fn('sos_list', '', array[
  $k3$select coalesce(btrim(department), '') into v_dept from profiles where id = auth.uid();$k3$,
  $k3$select coalesce(btrim(case when current_role_name()::text = 'dept' then (select d.name from departments d where d.id = _dept_id()) else department end), '') into v_dept from profiles where id = auth.uid();$k3$]);

-- ============================== Écritures et gestion sans rattachement valide ==============================
select _k3_patch_fn('event_create', '', array[
  $k3$if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;$k3$,
  $k3$if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$k3$]);

select _k3_patch_fn('event_update', '', array[
  $k3$if v_role not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;$k3$,
  $k3$if v_role not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  if v_role = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$k3$]);

select _k3_patch_fn('event_cancel', '', array[
  $k3$if v_role not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;$k3$,
  $k3$if v_role not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  if v_role = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$k3$]);

select _k3_patch_fn('events_managed', '', array[
  $k3$if not (has_admin_permission('finance.read') or v_role in ('dept', 'direction')) then raise exception 'Action non autorisée'; end if;$k3$,
  $k3$if not (has_admin_permission('finance.read') or v_role in ('dept', 'direction')) then raise exception 'Action non autorisée'; end if;
  if v_role = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$k3$]);

select _k3_patch_fn('event_registrants', '', array[
  $k3$if not (has_admin_permission('finance.read') or v_role in ('dept', 'direction')) or not exists$k3$,
  $k3$if (v_role = 'dept' and _dept_id() is null) or not (has_admin_permission('finance.read') or v_role in ('dept', 'direction')) or not exists$k3$]);

select _k3_patch_fn('challenge_create', '', array[
  $k3$if coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme et au département'; end if;$k3$,
  $k3$if coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme et au département'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$k3$]);

select _k3_patch_fn('invite_department_member', '', array[
  $k3$if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au responsable de département'; end if;$k3$,
  $k3$if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au responsable de département'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$k3$]);

select _k3_patch_fn('ann_save', '', array[
  $k3$v_staff := v_role in ('admin', 'dept');$k3$,
  $k3$v_staff := v_role = 'admin' or (v_role = 'dept' and _dept_of(v_owner) is not null);$k3$]);

select _k3_patch_fn('admin_users', '', array[
  $k3$(select count(*)::int from profiles s where s.department_id is not null and s.department_id = p.department_id and s.role::text = 'student') as students$k3$,
  $k3$(select count(*)::int from profiles s where s.department_id is not null and s.department_id = p.department_id and s.role::text = 'student' and (r <> 'dept' or p.department_id = v)) as students$k3$]);

create or replace function is_contest_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (coalesce(current_role_name()::text, '') = 'admin' or (coalesce(current_role_name()::text, '') = 'dept' and _dept_id() is not null))
$$;

create or replace function is_platform_manager() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (coalesce(current_role_name()::text, '') = 'admin' or (coalesce(current_role_name()::text, '') = 'dept' and _dept_id() is not null))
$$;
