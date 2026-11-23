-- Tests de la migration 20261101000500 (notifications multicanal) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
\set ON_ERROR_STOP on
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set C2 '41c9e35e-cdee-4c1f-8068-817dccd55867'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
-- N1 aucun canal sans appareil ni consentement : rien en file
insert into notifications (user_id, kind, title, body) values (:'C1', 'order', 'Commande prête', '#BE-1');
select 'RESULT|N1 sans appareil ni consentement : aucune file|' || case when (select count(*) from notification_outbox) = 0 then 'PASS' else 'FAIL' end || '|';
-- N2 appareil enregistré : push en file ; e-mail et SMS toujours absents
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform register_device(repeat('t', 40), 'android'); raise notice 'RESULT|N2a appareil enregistré|PASS|'; exception when others then raise notice 'RESULT|N2a appareil enregistré|FAIL|%', sqlerrm; end $$;
reset role;
insert into notifications (user_id, kind, title, body) values (:'C1', 'order', 'Commande prête', '#BE-2');
select 'RESULT|N2 push seulement (pas d''e-mail ni de SMS sans consentement)|' || case when (select string_agg(channel, ',') from notification_outbox) = 'push' then 'PASS' else 'FAIL' end || '|' || coalesce((select string_agg(channel, ',') from notification_outbox), '');
-- N3 consentement SMS pour les commandes, refus du push pour les messages
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform set_notification_preference('sms', 'order', true); perform set_notification_preference('push', 'message', false); raise notice 'RESULT|N3a préférences enregistrées|PASS|';
exception when others then raise notice 'RESULT|N3a préférences enregistrées|FAIL|%', sqlerrm; end $$;
do $$ begin perform set_notification_preference('pigeon', '*', true); raise notice 'RESULT|N3b canal inconnu refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|N3b canal inconnu refusé|PASS|%', sqlerrm; end $$;
reset role;
delete from notification_outbox;
insert into notifications (user_id, kind, title, body) values (:'C1', 'order', 'Commande prête', '#BE-3');
insert into notifications (user_id, kind, title, body) values (:'C1', 'message', 'Nouveau message', 'Bonjour');
select 'RESULT|N3 commande : push + SMS ; message : push refusé|' || case when (select string_agg(kind || ':' || channel, ',' order by kind, channel) from notification_outbox) = 'order:push,order:sms' then 'PASS' else 'FAIL' end
  || '|' || (select string_agg(kind || ':' || channel, ',' order by kind, channel) from notification_outbox);
select 'RESULT|N4 tout reste en attente : aucun envoi|' || case when (select bool_and(status = 'queued' and sent_at is null) from notification_outbox) then 'PASS' else 'FAIL' end || '|';
-- N5 RLS : un autre compte ne voit ni la file ni les appareils ; écriture directe refusée
select set_config('request.jwt.claims', json_build_object('sub', :'C2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare a int; b int; begin select count(*) into a from notification_outbox; select count(*) into b from device_tokens;
  raise notice 'RESULT|N5 file et appareils d''autrui invisibles|%|% %', case when a = 0 and b = 0 then 'PASS' else 'FAIL' end, a, b; end $$;
do $$ begin insert into notification_outbox (user_id, channel, kind, title) values (auth.uid(), 'sms', 'x', 'x'); raise notice 'RESULT|N5b écriture directe refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|N5b écriture directe refusée|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
do $$ begin perform register_device(repeat('a', 40), 'web'); raise notice 'RESULT|N6 anonyme refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|N6 anonyme refusé|PASS|%', sqlerrm; end $$;
reset role;
-- N7 retrait de l'appareil : plus de push
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform unregister_device(repeat('t', 40)); end $$;
reset role;
delete from notification_outbox;
insert into notifications (user_id, kind, title, body) values (:'C1', 'order', 'Commande prête', '#BE-4');
select 'RESULT|N7 appareil retiré : SMS seulement|' || case when (select string_agg(channel, ',') from notification_outbox) = 'sms' then 'PASS' else 'FAIL' end || '|';
rollback;
select 'RESULT|N8 réplique inchangée après ROLLBACK|' || case when to_regclass('public.notification_outbox') is null then 'PASS' else 'FAIL' end || '|';
