create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
create temp table ids (k text, v text); grant all on ids to public;

delete from platform_settings where key like 'zz.%';
delete from cms_items where title like 'ZZ test%';
delete from duels where need_title like 'ZZ test%';
delete from scheduled_lives where title like 'ZZ test%';

-- visiteur
set role anon;
do $$ begin
  begin perform settings_all(); insert into res values (default, 'X1 visiteur ne lit pas les réglages', false, 'accepté'); exception when others then insert into res values (default, 'X1 visiteur ne lit pas les réglages', true, sqlerrm); end;
  insert into res values (default, 'X2 visiteur lit la liste des duels', jsonb_typeof(duels_list()) = 'array', '');
end $$;
reset role;

-- étudiant A
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform setting_set('zz.test', 'true'::jsonb); insert into res values (default, 'X3 étudiant ne modifie pas les réglages', false, 'accepté'); exception when others then insert into res values (default, 'X3 étudiant ne modifie pas les réglages', sqlerrm = 'Action non autorisée', sqlerrm); end;
  begin perform cms_save(null, 'faq', 'ZZ test q', 'r', true); insert into res values (default, 'X4 étudiant ne crée pas de contenu', false, 'accepté'); exception when others then insert into res values (default, 'X4 étudiant ne crée pas de contenu', sqlerrm = 'Action non autorisée', sqlerrm); end;
  begin perform skills_radar(); insert into res values (default, 'X5 étudiant ne lit pas le radar', false, 'accepté'); exception when others then insert into res values (default, 'X5 étudiant ne lit pas le radar', sqlerrm = 'Action non autorisée', sqlerrm); end;
  insert into res values (default, 'X6 code de parrainage stable', my_referral_code() = my_referral_code() and my_referral_code() like 'BE-______', my_referral_code());
  begin perform pickup_register('X', 'borne-1', '1'); insert into res values (default, 'X7 étudiant ne gère pas les casiers', false, 'accepté'); exception when others then insert into res values (default, 'X7 étudiant ne gère pas les casiers', sqlerrm = 'Action non autorisée', sqlerrm); end;
end $$;
reset role;

-- administrateur : réglages, contenus, duel
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare c uuid; d uuid; begin
  perform setting_set('zz.test', 'true'::jsonb);
  insert into res values (default, 'X8 réglage enregistré et relu', (settings_all()->'zz.test') = 'true'::jsonb, '');
  begin perform setting_set('Mauvaise Clé', '1'::jsonb); insert into res values (default, 'X9 clé invalide refusée', false, 'accepté'); exception when others then insert into res values (default, 'X9 clé invalide refusée', sqlerrm = 'Clé invalide', sqlerrm); end;
  c := cms_save(null, 'faq', 'ZZ test question', 'réponse', true);
  insert into res values (default, 'X10 contenu créé', exists (select 1 from cms_items where id = c), '');
  perform cms_save(c, 'faq', 'ZZ test question 2', 'réponse', false);
  insert into res values (default, 'X11 contenu modifié', (select title from cms_items where id = c) = 'ZZ test question 2', '');
  perform cms_delete(c);
  insert into res values (default, 'X12 contenu supprimé', not exists (select 1 from cms_items where id = c), '');
  d := duel_create('ZZ test logo', 'Prix', 48);
  insert into ids values ('duel', d::text);
  begin perform duel_create('ZZ test', 'x', 0); insert into res values (default, 'X13 durée invalide refusée', false, 'accepté'); exception when others then insert into res values (default, 'X13 durée invalide refusée', sqlerrm like 'Durée invalide%', sqlerrm); end;
  insert into res values (default, 'X14 le radar est lisible par la gestion', jsonb_typeof(skills_radar()->'skills') = 'array', '');
end $$;
reset role;

-- duel : étudiant A participe, étudiant B vote
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare e uuid; d uuid; begin
  select v::uuid into d from ids where k = 'duel';
  e := duel_enter(d, 'Ma proposition');
  insert into ids values ('entry', e::text);
  begin perform duel_enter(d, 'Encore'); insert into res values (default, 'X15 double participation refusée', false, 'accepté'); exception when others then insert into res values (default, 'X15 double participation refusée', sqlerrm like 'Vous participez déjà%', sqlerrm); end;
  begin perform duel_vote(e); insert into res values (default, 'X16 vote pour soi-même refusé', false, 'accepté'); exception when others then insert into res values (default, 'X16 vote pour soi-même refusé', sqlerrm like 'Vous ne pouvez pas voter%', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare e uuid; begin
  select v::uuid into e from ids where k = 'entry';
  perform duel_vote(e);
  insert into res values (default, 'X17 le vote est compté', (select (x->>'votes')::int from jsonb_array_elements(duels_list()) d, jsonb_array_elements(d->'entries') x where x->>'id' = e::text) = 1, '');
  begin perform duel_vote(e); insert into res values (default, 'X18 double vote refusé', false, 'accepté'); exception when others then insert into res values (default, 'X18 double vote refusé', sqlerrm like 'Vous avez déjà voté%', sqlerrm); end;
end $$;
reset role;

-- live : l'hôte démarre, un autre commente
insert into scheduled_lives (id, host_id, title, status) values ('11111111-1111-1111-1111-111111111111', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'ZZ test live', 'scheduled');
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform live_comment('11111111-1111-1111-1111-111111111111', 'Bonjour'); insert into res values (default, 'X19 pas de commentaire avant le direct', false, 'accepté'); exception when others then insert into res values (default, 'X19 pas de commentaire avant le direct', sqlerrm like 'Ce live n%', sqlerrm); end;
  begin perform live_set_state('11111111-1111-1111-1111-111111111111', 'live'); insert into res values (default, 'X20 seul l''hôte démarre le live', false, 'accepté'); exception when others then insert into res values (default, 'X20 seul l''hôte démarre le live', sqlerrm like 'Live introuvable%', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
select live_set_state('11111111-1111-1111-1111-111111111111', 'live');
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  perform live_comment('11111111-1111-1111-1111-111111111111', 'Bonjour');
  insert into res values (default, 'X21 commentaire enregistré pendant le direct', (select count(*) from live_comments where live_id = '11111111-1111-1111-1111-111111111111') = 1, '');
end $$;
reset role;

-- casiers
insert into kiosks (id, name, location) values ('borne-99', 'ZZ test borne', 'Hall') on conflict do nothing;
insert into orders (id, number, buyer_id, subtotal, fee, method, paid) values ('22222222-2222-2222-2222-222222222222', 'ZZ-TEST-1', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 1000, 0, 'Mobile Money', true);
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare p uuid; begin
  p := pickup_register('ZZ-TEST-1', 'borne-99', '12');
  insert into res values (default, 'X22 casier attribué', exists (select 1 from jsonb_array_elements(pickups_list(50)) e where e->>'order' = 'ZZ-TEST-1' and e->>'status' = 'ready'), '');
  begin perform pickup_register('ZZ-TEST-1', 'borne-99', '13'); insert into res values (default, 'X23 double casier refusé', false, 'accepté'); exception when others then insert into res values (default, 'X23 double casier refusé', sqlerrm like 'Cette commande a déjà%', sqlerrm); end;
  perform pickup_collect(p);
  insert into res values (default, 'X24 remise enregistrée', exists (select 1 from jsonb_array_elements(pickups_list(50)) e where e->>'order' = 'ZZ-TEST-1' and e->>'status' = 'collected'), '');
  begin perform pickup_collect(p); insert into res values (default, 'X25 double remise refusée', false, 'accepté'); exception when others then insert into res values (default, 'X25 double remise refusée', sqlerrm like 'Retrait introuvable%', sqlerrm); end;
end $$;
reset role;

delete from pickups where order_id = '22222222-2222-2222-2222-222222222222';
delete from orders where id = '22222222-2222-2222-2222-222222222222';
delete from kiosks where id = 'borne-99';
delete from scheduled_lives where id = '11111111-1111-1111-1111-111111111111';
delete from duels where need_title like 'ZZ test%';
delete from platform_settings where key like 'zz.%';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
