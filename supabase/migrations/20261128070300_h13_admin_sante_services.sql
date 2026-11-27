-- H13 · Administration, sécurité, performance (4/7) : indicateurs de santé des services et intégrations.
-- admin_service_health() : un état par service, calculé UNIQUEMENT à partir de données réelles enregistrées par la plateforme (files d'envoi, événements de paiement reçus, rapports des fonctions Edge,
-- journaux de synchronisation). Règle d'or : ce qui n'est pas mesurable est « inconnu » (jamais « ok », jamais 0) ; un service désactivé ou sans clé est « non_configure ».
--   statuts : ok · degrade · erreur · non_configure · inconnu. Les mesures sont null quand elles ne sont pas connues. Aucun secret, aucune valeur de configuration, aucun appel à un service externe.
-- Lecture réservée à l'administrateur et aux équipes disposant d'une permission technique (tech.config, tech.maintenance, tech.logs, tech.integrations) ; consultation non journalisée (lecture seule).
-- Additive et rejouable. Retour arrière : drop function admin_service_health().

create or replace function admin_service_health() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_out jsonb := '[]'::jsonb;
  v_n bigint; v_a bigint; v_b bigint; v_c bigint; v_t timestamptz; v_min numeric; v_on boolean;
  v_status text; v_detail text; v_active integer; v_ready integer; v_fresh integer; v_stale integer; v_conf boolean;
  v_counts jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_any_admin_permission(array['tech.config', 'tech.maintenance', 'tech.logs', 'tech.integrations']) then
    raise exception 'Réservé : exige une permission technique (tech.config, tech.maintenance, tech.logs ou tech.integrations)';
  end if;

  v_out := v_out || jsonb_build_object('code', 'database', 'label', 'Base de données', 'status', 'ok', 'detail', 'Le serveur a répondu à cette requête.', 'last_event_at', null, 'metrics', '{}'::jsonb);

  -- file d'envoi des notifications (e-mail, SMS…) : statuts queued · sent · failed · skipped
  select count(*), count(*) filter (where status = 'queued'), count(*) filter (where status = 'failed' and created_at > now() - interval '24 hours'),
         count(*) filter (where status = 'sent' and created_at > now() - interval '24 hours'), max(sent_at),
         (extract(epoch from now() - min(created_at) filter (where status = 'queued')) / 60)
    into v_n, v_a, v_b, v_c, v_t, v_min from notification_outbox;
  if v_n = 0 then
    v_status := 'inconnu'; v_detail := 'Aucun envoi enregistré : impossible de dire si le canal fonctionne.';
  elsif v_b > 0 and v_c = 0 then
    v_status := 'erreur'; v_detail := 'Tous les envois des dernières 24 h ont échoué.';
  elsif v_b > 0 or coalesce(v_min, 0) > 30 then
    v_status := 'degrade'; v_detail := case when v_b > 0 then 'Des envois ont échoué dans les dernières 24 h.' else 'Des envois attendent depuis plus de 30 minutes.' end;
  else
    v_status := 'ok'; v_detail := 'Aucun échec récent et file d''attente à jour.';
  end if;
  v_out := v_out || jsonb_build_object('code', 'notifications', 'label', 'Envoi des notifications', 'status', v_status, 'detail', v_detail, 'last_event_at', v_t,
    'metrics', jsonb_build_object('queued', case when v_n = 0 then null else v_a end, 'failed_24h', case when v_n = 0 then null else v_b end, 'sent_24h', case when v_n = 0 then null else v_c end,
      'oldest_queued_minutes', case when v_a > 0 then round(v_min) else null end));

  -- paiements : seuls les événements effectivement reçus du prestataire sont connus de la base
  select count(*), count(*) filter (where received_at > now() - interval '24 hours'), max(received_at) into v_n, v_a, v_t from payment_events;
  if v_n = 0 then
    v_status := 'inconnu'; v_detail := 'Aucun événement de paiement reçu : ni preuve de bon fonctionnement, ni panne constatée.';
  else
    v_status := 'ok'; v_detail := 'Des événements du prestataire de paiement ont été reçus (dernier : voir la date).';
  end if;
  v_out := v_out || jsonb_build_object('code', 'payments', 'label', 'Paiements (rappels du prestataire)', 'status', v_status, 'detail', v_detail, 'last_event_at', v_t,
    'metrics', jsonb_build_object('events_total', case when v_n = 0 then null else v_n end, 'events_24h', case when v_n = 0 then null else v_a end));

  -- évaluations professionnelles : rapport de configuration de la fonction Edge (présence des secrets, jamais leur valeur) + file d'envoi
  if to_regclass('public.assessment_provider_health') is null then
    v_out := v_out || jsonb_build_object('code', 'evaluations', 'label', 'Évaluations professionnelles', 'status', 'inconnu', 'detail', 'Indicateur non installé.', 'last_event_at', null, 'metrics', '{}'::jsonb);
  else
    execute $q$select count(*) filter (where p.status = 'actif'),
                      count(*) filter (where p.status = 'actif' and h.configured and h.checked_at > now() - interval '3 hours'),
                      count(*) filter (where p.status = 'actif' and h.configured and h.checked_at <= now() - interval '3 hours'),
                      max(h.checked_at)
               from assessment_providers p left join assessment_provider_health h on h.provider_code = p.code$q$ into v_active, v_ready, v_stale, v_t;
    select count(*) into v_a from assessment_dispatch_log where event in ('failed', 'gave_up', 'result_rejected') and created_at > now() - interval '24 hours';
    if v_active = 0 then
      v_status := 'non_configure'; v_detail := 'Aucun fournisseur d''évaluation actif.';
    elsif v_ready = 0 and v_stale > 0 then
      v_status := 'inconnu'; v_detail := 'Le dernier contrôle de configuration date de plus de 3 heures.';
    elsif v_ready = 0 then
      v_status := 'non_configure'; v_detail := 'Un fournisseur est actif mais sa configuration (URL, clé, secret de rappel) n''a pas été confirmée.';
    elsif v_a > 0 then
      v_status := 'degrade'; v_detail := 'Des envois ou résultats ont été rejetés dans les dernières 24 h.';
    else
      v_status := 'ok'; v_detail := 'Configuration confirmée il y a moins de 3 heures, aucun échec récent.';
    end if;
    v_out := v_out || jsonb_build_object('code', 'evaluations', 'label', 'Évaluations professionnelles', 'status', v_status, 'detail', v_detail, 'last_event_at', v_t,
      'metrics', jsonb_build_object('active_providers', v_active, 'failed_24h', case when v_active = 0 then null else v_a end));
  end if;

  -- enregistrement des lives (Egress)
  v_on := coalesce((select enabled from live_recording_config where id), false);
  select count(*) filter (where egress_status = 'failed' and created_at > now() - interval '24 hours'),
         count(*) filter (where ready_at > now() - interval '7 days'), max(ready_at) into v_a, v_b, v_t from live_recordings;
  if not v_on then
    v_status := 'non_configure'; v_detail := 'L''enregistrement des lives est désactivé.';
  elsif v_a > 0 then
    v_status := 'degrade'; v_detail := 'Des enregistrements ont échoué dans les dernières 24 h.';
  elsif v_b > 0 then
    v_status := 'ok'; v_detail := 'Au moins un enregistrement a abouti ces 7 derniers jours.';
  else
    v_status := 'inconnu'; v_detail := 'Activé, mais aucun enregistrement récent ne prouve le bon fonctionnement.';
  end if;
  v_out := v_out || jsonb_build_object('code', 'live_recording', 'label', 'Enregistrement des lives', 'status', v_status, 'detail', v_detail, 'last_event_at', v_t,
    'metrics', jsonb_build_object('enabled', v_on, 'failed_24h', case when v_on then v_a else null end, 'ready_7d', case when v_on then v_b else null end));

  -- connexions externes des profils (synchronisations)
  select count(*), count(*) filter (where status in ('error', 'throttled') and started_at > now() - interval '24 hours'),
         count(*) filter (where status = 'ok' and started_at > now() - interval '24 hours'), max(started_at) into v_n, v_a, v_b, v_t from integration_sync_logs;
  if v_n = 0 then
    v_status := 'inconnu'; v_detail := 'Aucune synchronisation enregistrée.';
  elsif v_a > 0 and v_b = 0 then
    v_status := 'erreur'; v_detail := 'Toutes les synchronisations des dernières 24 h ont échoué.';
  elsif v_a > 0 then
    v_status := 'degrade'; v_detail := 'Des synchronisations ont échoué dans les dernières 24 h.';
  else
    v_status := 'ok'; v_detail := 'Aucun échec de synchronisation dans les dernières 24 h.';
  end if;
  v_out := v_out || jsonb_build_object('code', 'integrations', 'label', 'Connexions externes (profils)', 'status', v_status, 'detail', v_detail, 'last_event_at', v_t,
    'metrics', jsonb_build_object('failed_24h', case when v_n = 0 then null else v_a end, 'ok_24h', case when v_n = 0 then null else v_b end));

  -- limites de débit : nombre d'appels comptés (les refus ne sont pas comptés)
  if to_regclass('public.rpc_rate_limits') is null then
    v_out := v_out || jsonb_build_object('code', 'rate_limits', 'label', 'Limites de débit', 'status', 'inconnu', 'detail', 'Limites non installées.', 'last_event_at', null, 'metrics', '{}'::jsonb);
  else
    execute 'select count(*) filter (where enabled), count(*) from rpc_rate_limits' into v_a, v_n;
    select count(*) into v_b from auth_throttle where key like 'rpc:%' and at > now() - interval '1 hour';
    v_out := v_out || jsonb_build_object('code', 'rate_limits', 'label', 'Limites de débit (RPC publiques)', 'status', case when v_a > 0 then 'ok' else 'non_configure' end,
      'detail', case when v_a > 0 then v_a || ' limite(s) active(s) sur ' || v_n || '.' else 'Aucune limite active.' end, 'last_event_at', null,
      'metrics', jsonb_build_object('active_rules', v_a, 'calls_last_hour', v_b));
  end if;

  -- non mesurables depuis la base : déclarés tels quels
  v_out := v_out || jsonb_build_object('code', 'edge_functions', 'label', 'Fonctions Edge', 'status', 'inconnu', 'detail', 'Non mesurable depuis la base : consulter les journaux du fournisseur.', 'last_event_at', null, 'metrics', '{}'::jsonb)
                 || jsonb_build_object('code', 'backups', 'label', 'Sauvegardes', 'status', 'inconnu', 'detail', 'Non mesurable depuis la base : consulter le tableau de bord du fournisseur.', 'last_event_at', null, 'metrics', '{}'::jsonb);

  select jsonb_object_agg(s, c) into v_counts from (select e ->> 'status' s, count(*) c from jsonb_array_elements(v_out) e group by 1) x;
  return jsonb_build_object('generated_at', now(), 'counts', coalesce(v_counts, '{}'::jsonb), 'services', v_out);
end $$;
revoke all on function admin_service_health() from public, anon;
grant execute on function admin_service_health() to authenticated;
