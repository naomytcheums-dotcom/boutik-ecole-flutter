-- Planification des traitements périodiques ajoutés par les correctifs du profil Étudiant (ceux qui ne se planifient pas eux-mêmes).
-- Retour arrière : select cron.unschedule('wish-close-expired'); select cron.unschedule('lives-expire-stale'); select cron.unschedule('process-account-deletions');
do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('wish-close-expired') where exists (select 1 from cron.job where jobname = 'wish-close-expired');
  perform cron.schedule('wish-close-expired', '*/30 * * * *', 'select public.wish_close_expired()');
  perform cron.unschedule('lives-expire-stale') where exists (select 1 from cron.job where jobname = 'lives-expire-stale');
  perform cron.schedule('lives-expire-stale', '*/10 * * * *', 'select public.lives_expire_stale()');
  perform cron.unschedule('process-account-deletions') where exists (select 1 from cron.job where jobname = 'process-account-deletions');
  perform cron.schedule('process-account-deletions', '30 3 * * *', 'select public.process_account_deletions()');
exception when others then
  raise notice 'pg_cron indisponible : wish_close_expired(), lives_expire_stale() et process_account_deletions() doivent être planifiées autrement (%).', sqlerrm;
end $$;
