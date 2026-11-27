-- H13 · Administration, sécurité, performance (1/7) : limites de débit des RPC publiques coûteuses + outil interne d'enveloppe de fonction.
--  1. rpc_rate_limits : une ligne par RPC publique (limite par client, fenêtre en secondes, plafond global optionnel, interrupteur). Table fermée (service uniquement).
--  2. _rpc_throttle(rpc) : compte les appels dans auth_throttle (table existante, clé « rpc:<nom>:<client> ») ; client = utilisateur connecté, sinon adresse IP transmise par la
--     passerelle (cf-connecting-ip, x-real-ip, premier x-forwarded-for), sinon clé commune. Une erreur interne du compteur ne bloque JAMAIS l'appel (le compteur est ouvert en cas de panne).
--  3. _h13_wrap_fn(fonction, genre, libellé, catégorie) : renomme la fonction existante en « _rl_<nom> » ou « _au_<nom> » (jamais supprimée) et recrée une enveloppe du même nom, de
--     même signature et mêmes droits d'exécution, qui applique la limite (genre « throttle ») ou écrit une ligne dans audit_log après succès (genre « audit »). Idempotent (marqueur dans le corps).
--  4. Enveloppes de limite sur les RPC publiques de vérification (certificats, empreinte du classement, passeport, QR, preuve de projet, CV partagé, invitation) et de liste (Top 100,
--     historiques de classement, recherche, talents). Limites par défaut volontairement larges (réseaux d'établissement partagés) ; réglables par l'équipe technique (admin_rpc_rate_limit_set).
--  5. admin_rpc_rate_limits_list() / admin_rpc_rate_limit_set(...) : lecture (tech.config, tech.maintenance, tech.logs) et réglage (tech.config) avec écriture au journal d'audit.
-- Strictement additive : aucune fonction supprimée, aucune donnée existante modifiée. Retour arrière : pour chaque « _rl_<nom> » : drop function <nom>(args) ; alter function _rl_<nom>(args) rename to <nom> ;
--   puis regranter l'exécution à anon, authenticated ; drop function _rpc_throttle(text), _h13_wrap_fn(...), admin_rpc_rate_limit* ; drop table rpc_rate_limits.

create index if not exists auth_throttle_at on auth_throttle (at);

create table if not exists rpc_rate_limits (
  rpc text primary key,
  max_per_client integer not null check (max_per_client between 1 and 1000000),
  window_seconds integer not null check (window_seconds between 1 and 86400),
  max_global integer check (max_global is null or max_global between 1 and 100000000),
  enabled boolean not null default true,
  note text,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table rpc_rate_limits enable row level security;
revoke all on rpc_rate_limits from public, anon, authenticated;

create or replace function _rpc_throttle(p_rpc text) returns void
language plpgsql security definer set search_path = public as $$
declare
  c rpc_rate_limits;
  v_headers jsonb; v_ip text; v_client text; v_key text; v_gkey text; v_n integer; v_deny boolean := false;
begin
  begin
    select * into c from rpc_rate_limits where rpc = p_rpc and enabled;
    if not found then return; end if;
    begin v_headers := nullif(current_setting('request.headers', true), '')::jsonb; exception when others then v_headers := null; end;
    v_ip := nullif(btrim(coalesce(v_headers ->> 'cf-connecting-ip', v_headers ->> 'x-real-ip', split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1))), '');
    v_client := coalesce(auth.uid()::text, v_ip);
    v_key := 'rpc:' || p_rpc || ':' || case when v_client is null then 'commun' else left(md5(v_client), 16) end;
    select count(*) into v_n from auth_throttle where key = v_key and at > now() - make_interval(secs => c.window_seconds);
    if v_n >= c.max_per_client then v_deny := true;
    else
      insert into auth_throttle (key) values (v_key);
      if c.max_global is not null and v_client is not null then
        v_gkey := 'rpc:' || p_rpc || ':*';
        select count(*) into v_n from auth_throttle where key = v_gkey and at > now() - make_interval(secs => c.window_seconds);
        if v_n >= c.max_global then v_deny := true; else insert into auth_throttle (key) values (v_gkey); end if;
      end if;
    end if;
    if random() < 0.01 then delete from auth_throttle where at < now() - interval '1 day'; end if;
  exception when others then
    v_deny := false;
  end;
  if v_deny then raise exception 'Trop de requêtes : réessayez dans un instant' using errcode = 'P0429'; end if;
end $$;
revoke all on function _rpc_throttle(text) from public, anon, authenticated;

-- Ligne de journal écrite par une enveloppe d'audit (niveau « Sensible », acteur = compte connecté, jamais de valeur libre : seulement des identifiants et des booléens).
create or replace function _h13_audit(p_action text, p_target text, p_category text) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), case when auth.uid() is null then 'Service' else 'Utilisateur' end), auth.uid(),
          left(coalesce(p_action, ''), 120), left(coalesce(p_target, ''), 200), left(coalesce(p_category, ''), 40), 'Sensible');
end $$;
revoke all on function _h13_audit(text, text, text) from public, anon, authenticated;

create or replace function _h13_wrap_fn(p_proc regprocedure, p_kind text, p_label text default null, p_category text default null) returns text
language plpgsql set search_path = public as $$
declare
  p pg_proc%rowtype; v_core text; v_args text; v_res text; v_call text; v_i integer; v_tgt text := ''; v_body text; v_n integer := 0; v_r text;
  v_anon boolean; v_auth boolean; v_svc boolean; v_name text; v_ident text;
begin
  if p_kind not in ('throttle', 'audit') then raise exception 'genre inconnu'; end if;
  select * into p from pg_proc where oid = p_proc::oid;
  if not found then return 'absente'; end if;
  if p.prosrc like '%/*h13:%' or p.prosrc like '%_rpc_throttle(%' then return 'deja'; end if; -- déjà enveloppée, ou limitée par son propre corps
  if p.proretset or p.prokind <> 'f' or p.proargmodes is not null or p.prorettype = 'trigger'::regtype then return 'ignoree'; end if;
  v_name := p.proname;
  v_core := case p_kind when 'throttle' then '_rl_' else '_au_' end || v_name;
  v_args := pg_get_function_arguments(p.oid);
  v_res := pg_get_function_result(p.oid);
  v_anon := has_function_privilege('anon', p.oid, 'execute');
  v_auth := has_function_privilege('authenticated', p.oid, 'execute');
  v_svc := has_function_privilege('service_role', p.oid, 'execute');
  v_ident := pg_get_function_identity_arguments(p.oid);
  v_call := '';
  for v_i in 1..p.pronargs loop
    v_call := v_call || case when v_i > 1 then ', ' else '' end || '$' || v_i;
    -- cible d'audit : seulement des identifiants/booléens/nombres (jamais de texte libre)
    if v_n < 3 and p.proargnames is not null and p.proargnames[v_i] is not null and p.proargtypes[v_i - 1] in ('uuid'::regtype::oid, 'boolean'::regtype::oid, 'integer'::regtype::oid, 'bigint'::regtype::oid, 'numeric'::regtype::oid) then
      v_tgt := v_tgt || case when v_n > 0 then ' || '', '' || ' else '' end || quote_literal(regexp_replace(p.proargnames[v_i], '^p_', '') || '=') || ' || coalesce($' || v_i || '::text, '''')';
      v_n := v_n + 1;
    end if;
  end loop;
  if v_tgt = '' then v_tgt := ''''''; end if;
  execute format('alter function %s rename to %I', p_proc, v_core);
  if p_kind = 'throttle' then
    v_body := format('begin /*h13:throttle*/ perform _rpc_throttle(%L); %s end', v_name,
      case when v_res = 'void' then format('perform %I(%s);', v_core, v_call) else format('return %I(%s);', v_core, v_call) end);
  else
    v_body := format('%s begin /*h13:audit*/ %s perform _h13_audit(%L, %s, %L); %s end',
      case when v_res = 'void' then '' else format('declare v_r %s;', v_res) end,
      case when v_res = 'void' then format('perform %I(%s);', v_core, v_call) else format('v_r := %I(%s);', v_core, v_call) end,
      coalesce(p_label, v_name), v_tgt, coalesce(p_category, 'Administration'),
      case when v_res = 'void' then '' else 'return v_r;' end);
  end if;
  execute format('create or replace function %I(%s) returns %s language plpgsql security definer set search_path = public as %L', v_name, v_args, v_res, v_body);
  v_r := format('%I(%s)', v_name, v_ident);
  execute format('revoke all on function %s from public, anon, authenticated, service_role', v_r);
  execute format('revoke all on function %I(%s) from public, anon, authenticated, service_role', v_core, v_ident);
  if v_anon then execute format('grant execute on function %s to anon', v_r); end if;
  if v_auth then execute format('grant execute on function %s to authenticated', v_r); end if;
  if v_svc then execute format('grant execute on function %s to service_role', v_r); end if;
  return 'enveloppee';
end $$;
revoke all on function _h13_wrap_fn(regprocedure, text, text, text) from public, anon, authenticated;

-- ============================================================ limites par défaut (réglables)
insert into rpc_rate_limits (rpc, max_per_client, window_seconds, max_global, note) values
  ('verify_certificate', 60, 60, 3000, 'vérification publique par code : empêche l''énumération'),
  ('verify_certificate_public', 60, 60, 3000, 'vérification publique par code et nom : empêche l''énumération'),
  ('ranking_verify_hash', 60, 60, 3000, 'vérification publique de l''empreinte d''un classement'),
  ('replay_certificate_verify', 60, 60, 3000, 'vérification publique d''une attestation de replay'),
  ('passport_token_verify', 60, 60, 3000, 'vérification publique d''un passeport'),
  ('qr_resolve_public', 60, 60, 3000, 'résolution publique d''un QR'),
  ('project_proof_verify', 60, 60, 3000, 'vérification publique d''une preuve de projet'),
  ('shared_cv', 120, 60, 6000, 'CV partagé par lien'),
  ('dept_invite_info', 60, 60, 3000, 'lecture publique d''une invitation de département'),
  ('top100_national', 600, 60, null, 'liste publique du Top 100'),
  ('top100_by_domain', 600, 60, null, 'liste publique du Top 100'),
  ('top100_by_institution', 600, 60, null, 'liste publique du Top 100'),
  ('top100_by_department', 600, 60, null, 'liste publique du Top 100'),
  ('top100_by_program', 600, 60, null, 'liste publique du Top 100'),
  ('ranking_history', 300, 60, null, 'historique public des classements'),
  ('ranking_institution_history', 300, 60, null, 'historique public d''un établissement'),
  ('ranking_institutions_public', 300, 60, null, 'classement public des établissements'),
  ('talents_new', 300, 60, null, 'liste publique de talents'),
  ('talents_rising', 300, 60, null, 'liste publique de talents'),
  ('talents_most_viewed_by_companies', 300, 60, null, 'liste publique de talents'),
  ('marketplace_search', 600, 60, null, 'recherche publique de la marketplace'),
  ('marketplace_shops', 600, 60, null, 'liste publique des boutiques'),
  ('public_projects', 300, 60, null, 'liste publique de projets')
on conflict (rpc) do nothing;

do $$
declare r record; v_sig regprocedure;
begin
  for r in select rpc from rpc_rate_limits loop
    for v_sig in select p.oid::regprocedure from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = r.rpc and p.prokind = 'f' loop
      perform _h13_wrap_fn(v_sig, 'throttle');
    end loop;
  end loop;
end $$;

-- ============================================================ lecture et réglage (équipe technique)
create or replace function admin_rpc_rate_limits_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_any_admin_permission(array['tech.config', 'tech.maintenance', 'tech.logs']) then raise exception 'Réservé : exige une permission technique (tech.config, tech.maintenance ou tech.logs)'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('rpc', l.rpc, 'max_per_client', l.max_per_client, 'window_seconds', l.window_seconds, 'max_global', l.max_global,
      'enabled', l.enabled, 'note', l.note, 'updated_at', l.updated_at,
      'hits_last_hour', (select count(*)::int from auth_throttle t where t.key like 'rpc:' || l.rpc || ':%' and t.at > now() - interval '1 hour')) order by l.rpc) from rpc_rate_limits l), '[]'::jsonb);
end $$;
revoke all on function admin_rpc_rate_limits_list() from public, anon;
grant execute on function admin_rpc_rate_limits_list() to authenticated;

create or replace function admin_rpc_rate_limit_set(p_rpc text, p_max_per_client integer, p_window_seconds integer, p_max_global integer, p_enabled boolean, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('tech.config') then raise exception 'Réservé : exige la permission tech.config'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 5 then raise exception 'Motif obligatoire (5 caractères minimum)'; end if;
  if not exists (select 1 from rpc_rate_limits where rpc = p_rpc) then raise exception 'RPC inconnue : aucune limite à régler'; end if;
  if p_max_per_client is null or p_max_per_client < 1 or p_window_seconds is null or p_window_seconds < 1 or p_window_seconds > 86400 then raise exception 'Limite invalide'; end if;
  if p_max_global is not null and p_max_global < 1 then raise exception 'Plafond global invalide'; end if;
  update rpc_rate_limits set max_per_client = p_max_per_client, window_seconds = p_window_seconds, max_global = p_max_global, enabled = coalesce(p_enabled, true), updated_at = now(), updated_by = auth.uid()
  where rpc = p_rpc;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Limite de débit modifiée', left(p_rpc || ' : ' || p_max_per_client || '/' || p_window_seconds || ' s'
    || case when coalesce(p_enabled, true) then '' else ' (désactivée)' end || ' — ' || btrim(p_reason), 200), 'Technique', 'Sensible');
  return jsonb_build_object('rpc', p_rpc, 'max_per_client', p_max_per_client, 'window_seconds', p_window_seconds, 'max_global', p_max_global, 'enabled', coalesce(p_enabled, true));
end $$;
revoke all on function admin_rpc_rate_limit_set(text, integer, integer, integer, boolean, text) from public, anon;
grant execute on function admin_rpc_rate_limit_set(text, integer, integer, integer, boolean, text) to authenticated;
