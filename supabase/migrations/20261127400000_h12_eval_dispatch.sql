-- H12 · Évaluations : envoi aux fournisseurs et réception des résultats (Edge Function « assessment-dispatch »).
-- Le serveur de base de données ne parle jamais à un fournisseur : la fonction Edge (service_role) réclame les demandes à envoyer, appelle l'adaptateur du fournisseur,
-- puis enregistre l'acceptation, l'échec ou le résultat par les RPC ci-dessous, réservées au service. Aucun résultat n'est jamais inventé : un résultat n'existe que s'il
-- vient d'un fournisseur ACTIF (registre H9, test d'intégration réussi, activation administrateur + 2FA), et il reste soumis aux garde-fous de 20261125095000
-- (critères en liste blanche, aucun champ de biais, « limites » obligatoire, validation humaine imposée pour tout geste non observable à distance).
-- Données transmises au fournisseur : uniquement la référence de la demande, la famille et le mode. Aucune donnée personnelle (nom, e-mail, téléphone) n'est envoyée :
-- le transfert de données personnelles reste une décision juridique du propriétaire (loi camerounaise 2024/017), non prise ici.
-- Aucune règle financière modifiée ; aucun prix. Retour arrière : drop function assessment_dispatch_*; drop table assessment_dispatch_log ; alter table assessment_requests drop column (4 colonnes ajoutées).

alter table assessment_requests add column if not exists external_ref text check (external_ref is null or char_length(external_ref) between 1 and 200);
alter table assessment_requests add column if not exists candidate_url text check (candidate_url is null or candidate_url ~ '^https://[^\s]{4,255}$');
alter table assessment_requests add column if not exists dispatch_attempts integer not null default 0 check (dispatch_attempts between 0 and 10);
alter table assessment_requests add column if not exists last_dispatch_at timestamptz;

create table if not exists assessment_dispatch_log (
  id bigint generated always as identity primary key,
  request_id uuid not null references assessment_requests (id) on delete cascade,
  provider_code text not null,
  event text not null check (event in ('claimed', 'accepted', 'failed', 'gave_up', 'result', 'result_rejected')),
  http_status integer,
  detail text check (detail is null or char_length(detail) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists assessment_dispatch_log_request on assessment_dispatch_log (request_id, created_at);
alter table assessment_dispatch_log enable row level security;
revoke all on assessment_dispatch_log from anon, authenticated;

-- Journal lisible par les seuls administrateurs habilités (même contrôle que la liste des fournisseurs).
create or replace function assessment_dispatch_log_admin(p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _assessment_admin_only();
  return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'request_id', l.request_id, 'provider', l.provider_code, 'event', l.event, 'http_status', l.http_status, 'detail', l.detail, 'at', l.created_at) order by l.id desc)
    from (select * from assessment_dispatch_log order by id desc limit least(greatest(coalesce(p_limit, 100), 1), 500)) l), '[]'::jsonb);
end $$;
revoke all on function assessment_dispatch_log_admin(integer) from public, anon;
grant execute on function assessment_dispatch_log_admin(integer) to authenticated;

-- 1. Réclamation : demandes « envoyee » dont le fournisseur est ACTIF et couvre la famille et le mode ; au plus 5 tentatives, espacées d'au moins 10 minutes.
create or replace function assessment_dispatch_claim(p_limit integer default 10, p_providers text[] default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_requests; v_out jsonb := '[]'::jsonb; v_lim integer := least(greatest(coalesce(p_limit, 10), 1), 50);
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  for r in
    select q.* from assessment_requests q join assessment_providers p on p.code = q.provider_code
    where q.status = 'envoyee' and q.provider_code is not null and q.consent
      and p.status = 'actif' and q.family_code = any (p.family_codes) and q.mode = any (p.modes)
      and (p_providers is null or q.provider_code = any (p_providers))
      and q.dispatch_attempts < 5 and (q.last_dispatch_at is null or q.last_dispatch_at < now() - interval '10 minutes')
    order by q.created_at limit v_lim for update of q skip locked
  loop
    update assessment_requests set dispatch_attempts = dispatch_attempts + 1, last_dispatch_at = now(), updated_at = now() where id = r.id;
    insert into assessment_dispatch_log (request_id, provider_code, event) values (r.id, r.provider_code, 'claimed');
    v_out := v_out || jsonb_build_object('request_id', r.id, 'provider', r.provider_code, 'family', r.family_code, 'mode', r.mode, 'attempt', r.dispatch_attempts + 1);
  end loop;
  return v_out;
end $$;

-- 2. Acceptation par le fournisseur : la demande devient « acceptee » (elle compte alors dans le quota mensuel gratuit, comme le prévoit 20261125095000).
create or replace function assessment_dispatch_accepted(p_request uuid, p_external_ref text, p_candidate_url text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_requests; v_url text := nullif(btrim(coalesce(p_candidate_url, '')), '');
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  if p_external_ref is null or char_length(btrim(p_external_ref)) = 0 then raise exception 'Référence du fournisseur obligatoire'; end if;
  if v_url is not null and v_url !~ '^https://[^\s]{4,255}$' then v_url := null; end if;
  select * into r from assessment_requests where id = p_request for update;
  if r.id is null then raise exception 'Demande introuvable'; end if;
  if r.status <> 'envoyee' then return jsonb_build_object('ok', false, 'reason', 'not_pending', 'status', r.status); end if;
  update assessment_requests set status = 'acceptee', accepted_at = now(), external_ref = left(btrim(p_external_ref), 200), candidate_url = v_url, status_note = null, updated_at = now() where id = r.id;
  insert into assessment_dispatch_log (request_id, provider_code, event) values (r.id, r.provider_code, 'accepted');
  perform notify_user(r.candidate_id, 'assessment', 'Votre évaluation est prête à démarrer',
    case when v_url is null then 'Le fournisseur a accepté votre demande. Suivez son avancement dans « Évaluations de compétences ».' else 'Le fournisseur a accepté votre demande : ouvrez « Évaluations de compétences » pour la commencer.' end,
    jsonb_build_object('request', r.id));
  return jsonb_build_object('ok', true, 'status', 'acceptee');
end $$;

-- 3. Échec d'envoi : la demande reste « envoyee » (nouvelle tentative plus tard) ; après 5 tentatives elle devient « echouee », le quota gratuit n'est PAS consommé.
create or replace function assessment_dispatch_failed(p_request uuid, p_http integer, p_detail text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_requests; v_final boolean;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  select * into r from assessment_requests where id = p_request for update;
  if r.id is null then raise exception 'Demande introuvable'; end if;
  if r.status <> 'envoyee' then return jsonb_build_object('ok', false, 'reason', 'not_pending', 'status', r.status); end if;
  v_final := r.dispatch_attempts >= 5;
  insert into assessment_dispatch_log (request_id, provider_code, event, http_status, detail) values (r.id, coalesce(r.provider_code, '?'), case when v_final then 'gave_up' else 'failed' end, p_http, left(coalesce(p_detail, ''), 500));
  if v_final then
    update assessment_requests set status = 'echouee', status_note = 'Le fournisseur n''a pas pu être joint après plusieurs tentatives. Votre évaluation gratuite du mois n''est pas consommée : vous pouvez refaire une demande.', updated_at = now() where id = r.id;
    perform notify_user(r.candidate_id, 'assessment', 'Évaluation non démarrée', 'Le fournisseur n''a pas répondu. Votre évaluation gratuite du mois n''est pas consommée.', jsonb_build_object('request', r.id));
  end if;
  return jsonb_build_object('ok', true, 'final', v_final);
end $$;

-- 4. Résultat reçu (rappel signé du fournisseur, vérifié par la fonction Edge). Idempotent : un résultat déjà enregistré n'est jamais remplacé.
-- Les garde-fous (biais, critères, limites, validation humaine) s'appliquent par le déclencheur de assessment_results ; un refus est journalisé.
create or replace function assessment_dispatch_result(p_request uuid, p_provider text, p_external_ref text, p_competences jsonb, p_criteria jsonb, p_evidence jsonb, p_details jsonb, p_limits text, p_recommendations jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_requests; v_res uuid;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  select * into r from assessment_requests where id = p_request for update;
  if r.id is null then raise exception 'Demande introuvable'; end if;
  if r.provider_code is distinct from p_provider then raise exception 'Fournisseur différent de celui de la demande'; end if;
  if r.external_ref is not null and p_external_ref is not null and r.external_ref <> p_external_ref then raise exception 'Référence du fournisseur différente'; end if;
  if exists (select 1 from assessment_results where request_id = r.id) then return jsonb_build_object('ok', true, 'duplicate', true); end if;
  if r.status not in ('acceptee', 'en_cours') then return jsonb_build_object('ok', false, 'reason', 'not_running', 'status', r.status); end if;
  if not exists (select 1 from assessment_providers where code = r.provider_code and status = 'actif') then
    insert into assessment_dispatch_log (request_id, provider_code, event, detail) values (r.id, r.provider_code, 'result_rejected', 'fournisseur non actif');
    return jsonb_build_object('ok', false, 'reason', 'provider_not_active');
  end if;
  begin
    insert into assessment_results (request_id, candidate_id, provider_code, competences, criteria, evidence, details, limits, recommendations)
    values (r.id, r.candidate_id, r.provider_code, coalesce(p_competences, '[]'::jsonb), coalesce(p_criteria, '[]'::jsonb), coalesce(p_evidence, '[]'::jsonb), coalesce(p_details, '{}'::jsonb), coalesce(p_limits, ''), coalesce(p_recommendations, '[]'::jsonb))
    returning id into v_res;
  exception when others then
    insert into assessment_dispatch_log (request_id, provider_code, event, detail) values (r.id, r.provider_code, 'result_rejected', left(sqlerrm, 500));
    return jsonb_build_object('ok', false, 'reason', 'result_rejected', 'detail', left(sqlerrm, 300));
  end;
  update assessment_requests set status = 'terminee', updated_at = now() where id = r.id;
  insert into assessment_dispatch_log (request_id, provider_code, event) values (r.id, r.provider_code, 'result');
  perform notify_user(r.candidate_id, 'assessment', 'Votre résultat d''évaluation est disponible', 'Consultez-le dans « Évaluations de compétences ». Un évaluateur humain le valide si nécessaire.', jsonb_build_object('request', r.id, 'result', v_res));
  return jsonb_build_object('ok', true, 'result', v_res);
end $$;

-- Échec signalé par le fournisseur après acceptation (abandon, incident) : la demande devient « echouee » sans consommer le quota (non comptée une fois « echouee »).
create or replace function assessment_dispatch_provider_failed(p_request uuid, p_provider text, p_detail text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_requests;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  select * into r from assessment_requests where id = p_request for update;
  if r.id is null then raise exception 'Demande introuvable'; end if;
  if r.provider_code is distinct from p_provider then raise exception 'Fournisseur différent de celui de la demande'; end if;
  if r.status not in ('acceptee', 'en_cours') then return jsonb_build_object('ok', false, 'reason', 'not_running', 'status', r.status); end if;
  update assessment_requests set status = 'echouee', status_note = 'Le fournisseur a signalé un échec. Votre évaluation gratuite du mois n''est pas consommée.', updated_at = now() where id = r.id;
  insert into assessment_dispatch_log (request_id, provider_code, event, detail) values (r.id, r.provider_code, 'failed', left(coalesce(p_detail, ''), 500));
  perform notify_user(r.candidate_id, 'assessment', 'Évaluation interrompue', 'Le fournisseur a signalé un échec. Votre évaluation gratuite du mois n''est pas consommée.', jsonb_build_object('request', r.id));
  return jsonb_build_object('ok', true);
end $$;

revoke all on function assessment_dispatch_claim(integer, text[]), assessment_dispatch_accepted(uuid, text, text), assessment_dispatch_failed(uuid, integer, text),
  assessment_dispatch_result(uuid, text, text, jsonb, jsonb, jsonb, jsonb, text, jsonb), assessment_dispatch_provider_failed(uuid, text, text) from public, anon, authenticated;
grant execute on function assessment_dispatch_claim(integer, text[]), assessment_dispatch_accepted(uuid, text, text), assessment_dispatch_failed(uuid, integer, text),
  assessment_dispatch_result(uuid, text, text, jsonb, jsonb, jsonb, jsonb, text, jsonb), assessment_dispatch_provider_failed(uuid, text, text) to service_role;

-- 5. Liste du candidat : ajoute le lien d'évaluation du fournisseur (https uniquement), s'il existe. Même contrôle d'accès qu'avant (ses demandes seulement).
create or replace function assessment_my_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'family_code', r.family_code, 'family_label', f.label, 'mode', r.mode, 'status', r.status, 'funding', r.funding, 'status_note', r.status_note,
      'created_at', r.created_at, 'accepted_at', r.accepted_at, 'reuse_of', r.reuse_of, 'campaign_id', r.campaign_id, 'shared_with_org', r.share_with_org,
      'result_id', res.id, 'validation_status', res.validation_status,
      'candidate_url', case when r.status in ('acceptee', 'en_cours') then r.candidate_url end,
      'dispute_status', (select d.status from assessment_disputes d where d.result_id = res.id order by d.created_at desc limit 1)) order by r.created_at desc)
    from assessment_requests r join assessment_families f on f.code = r.family_code left join assessment_results res on res.request_id = coalesce(r.reuse_of, r.id)
    where r.candidate_id = auth.uid()), '[]'::jsonb);
end $$;