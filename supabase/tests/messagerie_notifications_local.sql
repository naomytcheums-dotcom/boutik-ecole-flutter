create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
delete from conversations where id = '66666666-6666-6666-6666-666666666666';
delete from notification_outbox where title like 'ZZ test%';
delete from notifications where title like 'ZZ test%';
delete from notification_preferences where user_id = 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4';
delete from user_blocks;
update profiles set phone = '+237600000001', email = 'zz.test@example.com' where id = 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4';
insert into conversations (id, created_by) values ('66666666-6666-6666-6666-666666666666', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab');
insert into conversation_participants (conversation_id, user_id) values ('66666666-6666-6666-6666-666666666666', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'), ('66666666-6666-6666-6666-666666666666', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4');

-- sans consentement : rien n'est mis en file
insert into notifications (user_id, kind, title, body) values ('c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'test', 'ZZ test sans consentement', 'x');
insert into res (test, ok, detail) select 'N1 sans consentement, aucun envoi en file', (select count(*) from notification_outbox where title = 'ZZ test sans consentement') = 0, '';

-- B active SMS et WhatsApp
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
select set_notification_preference('sms', '*', true);
select set_notification_preference('whatsapp', '*', true);
do $$ begin
  begin perform set_notification_preference('fax', '*', true); insert into res values (default, 'N2 canal inconnu refusé', false, 'accepté'); exception when others then insert into res values (default, 'N2 canal inconnu refusé', sqlerrm = 'Canal inconnu', sqlerrm); end;
end $$;
reset role;
insert into notifications (user_id, kind, title, body) values ('c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'test', 'ZZ test avec consentement', 'x');
insert into res (test, ok, detail) select 'N3 SMS et WhatsApp mis en file, pas l''e-mail', (select count(*) from notification_outbox where title = 'ZZ test avec consentement' and channel in ('sms', 'whatsapp')) = 2
  and (select count(*) from notification_outbox where title = 'ZZ test avec consentement' and channel = 'email') = 0, '';
update profiles set phone = null where id = 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4';
insert into notifications (user_id, kind, title, body) values ('c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'test', 'ZZ test sans téléphone', 'x');
insert into res (test, ok, detail) select 'N4 sans téléphone valide, rien n''est mis en file', (select count(*) from notification_outbox where title = 'ZZ test sans téléphone') = 0, '';

-- messagerie : blocage et signalement
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  insert into messages (conversation_id, sender_id, body) values ('66666666-6666-6666-6666-666666666666', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'ZZ test avant blocage');
  insert into res values (default, 'M1 envoi possible avant blocage', true, '');
  begin perform block_user('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', true); insert into res values (default, 'M2 on ne se bloque pas soi-même', false, 'accepté'); exception when others then insert into res values (default, 'M2 on ne se bloque pas soi-même', sqlerrm like 'Action impossible%', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
select block_user('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', true);
do $$ begin
  begin perform report_conversation('66666666-6666-6666-6666-666666666666', 'ab'); insert into res values (default, 'M3 motif trop court refusé', false, 'accepté'); exception when others then insert into res values (default, 'M3 motif trop court refusé', sqlerrm = 'Motif trop court', sqlerrm); end;
  perform report_conversation('66666666-6666-6666-6666-666666666666', 'Propos déplacés');
  insert into res values (default, 'M4 signalement enregistré', exists (select 1 from message_reports where conversation_id = '66666666-6666-6666-6666-666666666666'), '');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin insert into messages (conversation_id, sender_id, body) values ('66666666-6666-6666-6666-666666666666', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'ZZ test après blocage'); insert into res values (default, 'M5 envoi refusé après blocage', false, 'accepté'); exception when others then insert into res values (default, 'M5 envoi refusé après blocage', true, sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
select block_user('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', false);
do $$ begin
  insert into messages (conversation_id, sender_id, body) values ('66666666-6666-6666-6666-666666666666', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'ZZ test après déblocage');
  insert into res values (default, 'M6 envoi possible après déblocage', true, '');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform report_conversation('66666666-6666-6666-6666-666666666666', 'Je ne suis pas participant'); insert into res values (default, 'M7 un tiers ne signale pas une conversation qui n''est pas la sienne', false, 'accepté'); exception when others then insert into res values (default, 'M7 un tiers ne signale pas une conversation qui n''est pas la sienne', sqlerrm = 'Conversation introuvable', sqlerrm); end;
end $$;
reset role;
delete from conversations where id = '66666666-6666-6666-6666-666666666666';
delete from notification_outbox where title like 'ZZ test%';
delete from notifications where title like 'ZZ test%';
delete from notification_preferences where user_id = 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4';
delete from user_blocks;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
