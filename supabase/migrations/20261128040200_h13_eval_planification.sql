-- H13 · Évaluations : planification de l'envoi et du rapport de santé (pg_cron + pg_net, comme dispatch-notifications dans 20261115000100).
--  assessment-dispatch  : toutes les 5 minutes, SEULEMENT s'il existe un fournisseur ACTIF (sinon aucun appel) ; l'espacement de 10 minutes entre deux tentatives et le plafond de 5
--                         tentatives par demande sont imposés par assessment_dispatch_claim (20261127400000), pas par la planification.
--  assessment-health    : toutes les 15 minutes, SEULEMENT s'il existe au moins un fournisseur enregistré ; la fonction vérifie la présence des secrets, sans appeler le fournisseur.
-- Authentification : en-tête x-dispatch-key (clé interne internal_secrets 'dispatch_key', 20261115000100) vérifiée par dispatch_key_check ; aucune clé n'est écrite ici.
-- L'URL de la fonction est celle du projet (comme pour dispatch-notifications) ; sans pg_cron / pg_net la migration passe quand même et la planification est à faire à la main
-- (voir docs/transformation/H13_CONTRAT_FOURNISSEUR_EVALUATION.md). Aucune donnée de table insérée. Rejouable (replanifie sous le même nom).
-- Retour arrière : select cron.unschedule('assessment-dispatch'); select cron.unschedule('assessment-health');

do $$ begin
  create extension if not exists pg_cron;
  create extension if not exists pg_net;
  perform cron.unschedule('assessment-dispatch') where exists (select 1 from cron.job where jobname = 'assessment-dispatch');
  perform cron.schedule('assessment-dispatch', '*/5 * * * *',
    $cron$select net.http_post(url := 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/assessment-dispatch?action=dispatch', headers := jsonb_build_object('Content-Type', 'application/json', 'x-dispatch-key', (select value from public.internal_secrets where name = 'dispatch_key')), body := '{}'::jsonb) where exists (select 1 from public.assessment_providers where status = 'actif')$cron$);
  perform cron.unschedule('assessment-health') where exists (select 1 from cron.job where jobname = 'assessment-health');
  perform cron.schedule('assessment-health', '*/15 * * * *',
    $cron$select net.http_post(url := 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/assessment-dispatch?action=health', headers := jsonb_build_object('Content-Type', 'application/json', 'x-dispatch-key', (select value from public.internal_secrets where name = 'dispatch_key')), body := '{}'::jsonb) where exists (select 1 from public.assessment_providers)$cron$);
exception when others then
  raise notice 'pg_cron / pg_net indisponible : planifier à la main assessment-dispatch?action=dispatch (5 min) et ?action=health (15 min) (%).', sqlerrm;
end $$;
