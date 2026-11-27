-- H13 · Évaluations : indicateur de santé des fournisseurs (sans fuite de secret) et lecture enrichie de la liste du candidat.
--  1. assessment_provider_health : rapport écrit par la fonction Edge « assessment-dispatch » (action ?action=health, clé de service) après vérification de la PRÉSENCE des trois
--     secrets du fournisseur (URL de base, clé d'API, secret de rappel). Aucune valeur de secret n'est jamais envoyée ni stockée : seulement trois booléens et la date de vérification.
--     Aucun appel au fournisseur, aucun crédit consommé.
--  2. assessment_provider_health_report(jsonb) : écriture réservée au service (service_role).
--  3. assessment_provider_readiness() : pour tout compte connecté, « ready » (booléen : un fournisseur ACTIF dont la configuration a été confirmée il y a moins de 3 heures) ;
--     pour l'équipe « tech.integrations », en plus le détail par fournisseur (booléens, date, test d'intégration) et l'état de la file d'envoi. Jamais de secret ni de valeur.
--  4. assessment_my_list() : ajoute le nom du fournisseur attribué par le serveur et le nombre de tentatives d'envoi (le candidat ne choisit jamais le fournisseur).
-- Aucune donnée insérée. Additive et rejouable. Retour arrière : drop function assessment_provider_readiness(), assessment_provider_health_report(jsonb) ; drop table assessment_provider_health ;
--   puis recréer assessment_my_list() depuis 20261127400000.

create table if not exists assessment_provider_health (
  provider_code text primary key references assessment_providers (code) on delete cascade,
  has_base_url boolean not null default false,
  has_api_key boolean not null default false,
  has_webhook_secret boolean not null default false,
  configured boolean generated always as (has_base_url and has_api_key and has_webhook_secret) stored,
  checked_at timestamptz not null default now()
);
alter table assessment_provider_health enable row level security;
revoke all on assessment_provider_health from public, anon, authenticated;

-- Écriture par la fonction Edge seulement. Les fournisseurs inconnus sont ignorés ; la valeur d'un secret n'est jamais reçue (booléens uniquement).
create or replace function assessment_provider_health_report(p_reports jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare x jsonb; v_code text; v_n integer := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  if jsonb_typeof(p_reports) is distinct from 'array' then raise exception 'Rapport invalide'; end if;
  if jsonb_array_length(p_reports) > 200 then raise exception 'Rapport trop volumineux'; end if;
  for x in select * from jsonb_array_elements(p_reports) loop
    v_code := x ->> 'provider';
    continue when v_code is null or not exists (select 1 from assessment_providers where code = v_code);
    insert into assessment_provider_health (provider_code, has_base_url, has_api_key, has_webhook_secret, checked_at)
    values (v_code, (x -> 'base_url') = 'true'::jsonb, (x -> 'api_key') = 'true'::jsonb, (x -> 'webhook_secret') = 'true'::jsonb, now())
    on conflict (provider_code) do update set has_base_url = excluded.has_base_url, has_api_key = excluded.has_api_key, has_webhook_secret = excluded.has_webhook_secret, checked_at = excluded.checked_at;
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'updated', v_n);
end $$;
revoke all on function assessment_provider_health_report(jsonb) from public, anon, authenticated;
grant execute on function assessment_provider_health_report(jsonb) to service_role;

create or replace function assessment_provider_readiness() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_ready boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_ready := exists (select 1 from assessment_providers p join assessment_provider_health h on h.provider_code = p.code
                     where p.status = 'actif' and h.configured and h.checked_at > now() - interval '3 hours');
  if not coalesce(has_admin_permission('tech.integrations'), false) then
    return jsonb_build_object('ready', v_ready);
  end if;
  return jsonb_build_object(
    'ready', v_ready, 'fresh_hours', 3,
    'providers', coalesce((select jsonb_agg(jsonb_build_object(
        'code', p.code, 'name', p.name, 'status', p.status,
        'reported', h.provider_code is not null, 'has_base_url', h.has_base_url, 'has_api_key', h.has_api_key, 'has_webhook_secret', h.has_webhook_secret,
        'configured', h.configured, 'checked_at', h.checked_at, 'stale', h.checked_at is not null and h.checked_at <= now() - interval '3 hours',
        'last_test_ok', (select t.ok from assessment_provider_tests t where t.provider_code = p.code order by t.tested_at desc, t.id desc limit 1)) order by p.code)
      from assessment_providers p left join assessment_provider_health h on h.provider_code = p.code), '[]'::jsonb),
    'queue', jsonb_build_object(
      'waiting', (select count(*)::int from assessment_requests where status = 'envoyee' and provider_code is not null),
      'running', (select count(*)::int from assessment_requests where status in ('acceptee', 'en_cours')),
      'failed_24h', (select count(*)::int from assessment_dispatch_log where event in ('failed', 'gave_up', 'result_rejected') and created_at > now() - interval '24 hours'),
      'last_event_at', (select max(created_at) from assessment_dispatch_log)));
end $$;
revoke all on function assessment_provider_readiness() from public, anon;
grant execute on function assessment_provider_readiness() to authenticated;

-- Liste du candidat : même contrôle d'accès (ses demandes seulement), avec le fournisseur attribué par le serveur et le nombre de tentatives d'envoi.
create or replace function assessment_my_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'family_code', r.family_code, 'family_label', f.label, 'mode', r.mode, 'status', r.status, 'funding', r.funding, 'status_note', r.status_note,
      'created_at', r.created_at, 'accepted_at', r.accepted_at, 'reuse_of', r.reuse_of, 'campaign_id', r.campaign_id, 'shared_with_org', r.share_with_org,
      'provider_name', case when r.status <> 'paiement_requis' then p.name end, 'dispatch_attempts', r.dispatch_attempts,
      'result_id', res.id, 'validation_status', res.validation_status,
      'candidate_url', case when r.status in ('acceptee', 'en_cours') then r.candidate_url end,
      'dispute_status', (select d.status from assessment_disputes d where d.result_id = res.id order by d.created_at desc limit 1)) order by r.created_at desc)
    from assessment_requests r join assessment_families f on f.code = r.family_code left join assessment_providers p on p.code = r.provider_code
         left join assessment_results res on res.request_id = coalesce(r.reuse_of, r.id)
    where r.candidate_id = auth.uid()), '[]'::jsonb);
end $$;
