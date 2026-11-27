-- H13.1 · Lot SESSIONS (1/1) : refus effectif, côté base, des requêtes d'une session fermée ou d'un compte suspendu.
--
-- Constat : GoTrue vérifie la signature d'un jeton d'accès sans interroger la base ; un jeton déjà émis reste donc valide (1 h par défaut) pour PostgREST et Storage
-- même après la suppression des lignes de auth.sessions. Ce correctif NE « révoque » PAS le jeton au sens de GoTrue (impossible : le JWT est autonome) ; il fait refuser
-- par la base toute requête dont la session n'existe plus ou dont le compte est suspendu / bloqué.
--
--  1. _session_status_of(compte, session) : état d'une session ('ok' | 'session_revoked' | 'suspended'), appelable par les fonctions Edge (clé de service uniquement).
--  2. _session_status() / _session_is_live() : même contrôle sur les revendications du jeton de la requête en cours (request.jwt.claims : sub, session_id).
--     _session_is_live() est le helper réutilisable par les politiques RLS de Storage et des tables (écrire « (select _session_is_live()) » pour une évaluation unique par requête).
--  3. _session_guard(), appelée en tête de enforce_mfa_on_sensitive() (db_pre_request, exécutée par PostgREST sur CHAQUE requête) : refuse toute requête d'un compte connecté dont la session a disparu (401 PT401, « Session expirée
--     ou révoquée, reconnectez-vous », indice session_revoked) ou dont le compte est suspendu / bloqué (403, indice account_suspended), lectures comprises. Exceptions : requêtes anonymes
--     (sans sub), service_role, et - pour un compte suspendu seulement - les RPC de contact et de droit des personnes (support, suppression de compte, CGU, désinscription d'appareil, journal).
--     La garde 2FA (aal2) est conservée telle quelle. Toute erreur de lecture du contrôle laisse passer la requête : la garde ne doit jamais rendre l'API indisponible.
--  4. Suspension et admin_account_sessions_revoke : les refresh tokens du compte sont aussi marqués révoqués (revoked = true) avant la suppression des sessions.
-- Limites documentées (docs/transformation/H131_SESSIONS_REVOCATION.md) : Realtime (connexion websocket ouverte jusqu'à l'expiration du jeton), fonctions Edge sans contrôle, politiques RLS de Storage
-- tant qu'elles n'appellent pas _session_is_live().
-- Strictement additive. Retour arrière : retirer la ligne « perform public._session_guard(); » du corps de enforce_mfa_on_sensitive() (la recréer depuis pg_get_functiondef), recréer _profile_suspension_sessions() / admin_account_sessions_revoke() depuis 20261128070100 ; drop function _session_*.

-- ============================================================ 1. état d'une session
create or replace function _session_status_of(p_user uuid, p_session uuid) returns text
language plpgsql stable security definer set search_path = public, auth as $$
declare v_live boolean; v_susp boolean; v_ban timestamptz;
begin
  if p_user is null then return 'ok'; end if;
  if p_session is not null and p_session <> '00000000-0000-0000-0000-000000000000'::uuid then
    -- auth.sessions(id) est la clé primaire : une recherche indexée. not_after (durée maximale de session) n'existe pas dans toutes les versions : lecture tolérante.
    select (coalesce(nullif(to_jsonb(s) ->> 'not_after', '')::timestamptz, 'infinity'::timestamptz) > now()) into v_live from auth.sessions s where s.id = p_session and s.user_id = p_user;
    if not coalesce(v_live, false) then return 'session_revoked'; end if;
  end if;
  select coalesce(suspended, false) into v_susp from public.profiles where id = p_user;
  select banned_until into v_ban from auth.users where id = p_user;
  if coalesce(v_susp, false) or (v_ban is not null and v_ban > now()) then return 'suspended'; end if;
  return 'ok';
end $$;
revoke all on function _session_status_of(uuid, uuid) from public, anon, authenticated;
grant execute on function _session_status_of(uuid, uuid) to service_role;

-- ============================================================ 2. état de la session de la requête en cours
create or replace function _session_status() returns text
language plpgsql stable security definer set search_path = public, auth as $$
declare v_claims jsonb; v_uid uuid; v_sid uuid;
begin
  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    v_uid := coalesce(nullif(v_claims ->> 'sub', ''), nullif(current_setting('request.jwt.claim.sub', true), ''))::uuid;
    if v_uid is null or coalesce(v_claims ->> 'role', '') = 'service_role' then return 'ok'; end if;
    v_sid := nullif(coalesce(v_claims ->> 'session_id', current_setting('request.jwt.claim.session_id', true)), '')::uuid;
  exception when others then
    return 'ok';
  end;
  return _session_status_of(v_uid, v_sid);
end $$;
revoke all on function _session_status() from public;
grant execute on function _session_status() to anon, authenticated, service_role;

create or replace function _session_is_live() returns boolean
language sql stable security definer set search_path = public, auth as $$ select _session_status() = 'ok' $$;
revoke all on function _session_is_live() from public;
grant execute on function _session_is_live() to anon, authenticated, service_role;

-- ============================================================ 3. garde de chaque requête API (PostgREST db_pre_request)
-- La liste des opérations 2FA de enforce_mfa_on_sensitive() a été étendue par plusieurs migrations (h4, k1, l3, h10) qui réécrivent le corps de la fonction : on ne la remplace donc PAS ;
-- on y insère, au début du corps, l'appel à _session_guard() (idempotent : sans effet si déjà présent). La garde 2FA et sa liste restent inchangées.
create or replace function _session_guard() returns void
language plpgsql stable security definer set search_path = public, auth as $$
declare v_state text := 'ok';
begin
  begin
    v_state := _session_status();
  exception when others then
    v_state := 'ok';
  end;
  if v_state = 'session_revoked' then
    raise exception 'Session expirée ou révoquée, reconnectez-vous' using errcode = 'PT401', hint = 'session_revoked';
  elsif v_state = 'suspended'
        and coalesce(current_setting('request.path', true), '') !~ '^/rpc/(support_ticket_create|request_account_deletion|cancel_account_deletion|accept_terms|unregister_device|unregister_all_devices|log_audit)$' then
    raise exception 'Compte suspendu : cette action est impossible. Contactez le support.' using errcode = '42501', hint = 'account_suspended';
  end if;
end $$;
revoke all on function _session_guard() from public;
grant execute on function _session_guard() to anon, authenticated, service_role;

do $$
declare r record; v_def text; v_new text;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'enforce_mfa_on_sensitive' loop
    v_def := pg_get_functiondef(r.oid);
    if v_def like '%_session_guard()%' then continue; end if;
    v_new := regexp_replace(v_def, E'(\\r?\\n)begin(\\r?\\n)', E'\\1begin\\2  perform public._session_guard();\\2');
    if v_new = v_def then raise exception 'enforce_mfa_on_sensitive : début du corps introuvable'; end if;
    execute v_new;
  end loop;
end $$;
grant execute on function enforce_mfa_on_sensitive() to anon, authenticated, service_role;

-- ============================================================ 4. suspension et fermeture manuelle : refresh tokens révoqués aussi
create or replace function _session_revoke_tokens(p_user uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  -- Les refresh tokens liés à une session partent avec elle (cascade) ; ceux sans session (anciens) sont marqués révoqués. Colonnes absentes d'un environnement de test : sans effet.
  begin
    update auth.refresh_tokens set revoked = true, updated_at = now() where user_id = p_user::text and not coalesce(revoked, false);
  exception when undefined_column or undefined_table then
    null;
  end;
end $$;
revoke all on function _session_revoke_tokens(uuid) from public, anon, authenticated;

create or replace function _profile_suspension_sessions() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.suspended, false) and not coalesce(old.suspended, false) then
    update auth.users set banned_until = '2999-01-01'::timestamptz where id = new.id and (banned_until is null or banned_until < '2999-01-01'::timestamptz);
    perform _session_revoke_tokens(new.id);
    delete from auth.sessions where user_id = new.id;
  elsif not coalesce(new.suspended, false) and coalesce(old.suspended, false) then
    update auth.users set banned_until = null where id = new.id and banned_until = '2999-01-01'::timestamptz;
  end if;
  return null;
end $$;
revoke all on function _profile_suspension_sessions() from public, anon, authenticated;

create or replace function admin_account_sessions_revoke(p_user uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('security.accounts') then raise exception 'Réservé : exige la permission security.accounts'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 5 then raise exception 'Motif obligatoire (5 caractères minimum)'; end if;
  if p_user is null or p_user = auth.uid() then raise exception 'Vous ne pouvez pas fermer vos propres sessions ici'; end if;
  select role::text, name into v_role, v_name from profiles where id = p_user;
  if not found then raise exception 'Compte introuvable'; end if;
  if v_role = 'admin' and coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Seul un administrateur global ferme les sessions d''un administrateur'; end if;
  perform _session_revoke_tokens(p_user);
  with d as (delete from auth.sessions where user_id = p_user returning 1) select count(*)::int into v_n from d;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Sessions fermées', left(coalesce(v_name, '') || ' : ' || v_n || ' session(s) — ' || btrim(p_reason), 200), 'Comptes', 'Sensible');
  return jsonb_build_object('revoked', v_n);
end $$;
revoke all on function admin_account_sessions_revoke(uuid, text) from public, anon;
grant execute on function admin_account_sessions_revoke(uuid, text) to authenticated;
