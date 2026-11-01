-- Administration des comptes (écran 128) : rôle et suspension modifiés par l'administrateur global, côté serveur.
-- Avant : l'écran modifiait une liste locale à l'appareil et affichait « Compte mis à jour » sans effet sur le serveur.
-- La liste des comptes se lit déjà par RLS (« profil visible par soi et l'administration ») ; seule l'écriture manquait.
-- Suspension effective, comme pour les comptes de démonstration neutralisés en 20261029000000 : connexion bloquée
-- (auth.users.banned_until) et sessions ouvertes fermées ; la réactivation lève le blocage.

create or replace function admin_set_account(p_user uuid, p_role app_role, p_suspended boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_role app_role;
  v_suspended boolean;
  v_name text;
  v_new_suspended boolean := coalesce(p_suspended, false);
  v_admins integer;
begin
  if me is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
  if p_user is null or p_user = me then raise exception 'Vous ne pouvez pas modifier votre propre rôle ou statut'; end if;
  if p_role is null or p_role = 'visitor' then raise exception 'Rôle invalide'; end if;

  select role, suspended, name into v_role, v_suspended, v_name from profiles where id = p_user for update;
  if not found then raise exception 'Compte introuvable'; end if;
  if v_role = p_role and v_suspended = v_new_suspended then
    return jsonb_build_object('role', v_role, 'suspended', v_suspended, 'changed', false);
  end if;
  if v_role = 'admin' and (p_role <> 'admin' or v_new_suspended) then
    select count(*) into v_admins from profiles where role = 'admin' and not suspended;
    if v_admins <= 1 then raise exception 'Impossible de retirer le dernier administrateur actif'; end if;
  end if;

  -- le déclencheur protect_profile_authority vérifie à nouveau que l'appelant est administrateur
  update profiles set role = p_role, suspended = v_new_suspended where id = p_user;
  if v_new_suspended <> v_suspended then
    update auth.users set banned_until = case when v_new_suspended then '2999-01-01'::timestamptz else null end where id = p_user;
    if v_new_suspended then
      delete from auth.sessions where user_id = p_user;
    end if;
  end if;

  insert into audit_log (actor, action, target, category, level) values (
    coalesce((select name from profiles where id = me), 'Administrateur'),
    case when v_new_suspended and not v_suspended then 'Compte suspendu'
         when not v_new_suspended and v_suspended then 'Compte réactivé'
         else 'Rôle modifié' end,
    left(coalesce(v_name, '') || ' : ' || v_role::text || ' → ' || p_role::text, 200),
    'Comptes', 'Sensible');
  return jsonb_build_object('role', p_role, 'suspended', v_new_suspended, 'changed', true);
end $$;

revoke all on function admin_set_account(uuid, app_role, boolean) from public, anon;
grant execute on function admin_set_account(uuid, app_role, boolean) to authenticated;

-- Signalements d'annonces (écrans 131 et 170) : la modération lit déjà listing_reports (RLS « auteur et modération ») ;
-- seul le changement de statut manquait (l'écran affichait des signalements d'exemple et modifiait un état local).
create or replace function set_report_status(p_report uuid, p_status text) returns text
language plpgsql security definer set search_path = public as $$
declare v_old text; v_title text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'dept', 'admin') then raise exception 'Réservé au support, au département ou à l''administration'; end if;
  if p_status not in ('open', 'reviewing', 'closed') then raise exception 'Statut invalide'; end if;
  select r.status, l.title into v_old, v_title from listing_reports r join listings l on l.id = r.listing_id where r.id = p_report for update of r;
  if not found then raise exception 'Signalement introuvable'; end if;
  if v_old = p_status then return p_status; end if;
  update listing_reports set status = p_status where id = p_report;
  insert into audit_log (actor, action, target, category, level) values (
    coalesce((select name from profiles where id = auth.uid()), 'Modération'), 'Signalement : ' || v_old || ' → ' || p_status,
    left(coalesce(v_title, ''), 200), 'Modération', 'Sensible');
  return p_status;
end $$;

revoke all on function set_report_status(uuid, text) from public, anon;
grant execute on function set_report_status(uuid, text) to authenticated;
