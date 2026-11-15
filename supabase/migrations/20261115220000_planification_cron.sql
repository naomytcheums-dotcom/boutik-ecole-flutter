-- Planification des traitements périodiques ajoutés par les correctifs du profil Client.
-- Retour arrière : select cron.unschedule('expire-subscriptions'); select cron.unschedule('send-event-reminders');

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('expire-subscriptions') where exists (select 1 from cron.job where jobname = 'expire-subscriptions');
  perform cron.schedule('expire-subscriptions', '5 * * * *', 'select public.expire_subscriptions()');
  perform cron.unschedule('send-event-reminders') where exists (select 1 from cron.job where jobname = 'send-event-reminders');
  perform cron.schedule('send-event-reminders', '*/15 * * * *', 'select public.send_event_reminders()');
exception when others then
  raise notice 'pg_cron indisponible : expire_subscriptions() et send_event_reminders() doivent être planifiées autrement (%).', sqlerrm;
end $$;
