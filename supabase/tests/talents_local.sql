-- Tests de talents_list() sur la base LOCALE isolée (comptes fictifs « Test … »).
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
set role anon;
do $$ declare j jsonb; begin j := talents_list(''); insert into res(test,ok,detail) values ('T1 un visiteur voit les talents (sans donnée privée)', jsonb_array_length(j) > 0 and not exists (select 1 from jsonb_array_elements(j) e where e ? 'email' or e ? 'phone' or e ? 'matricule'), jsonb_array_length(j)::text); end $$;
do $$ begin begin perform start_direct_conversation('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'bonjour'); insert into res(test,ok,detail) values ('T0 un visiteur ne peut pas écrire', false, 'accepté'); exception when others then insert into res(test,ok,detail) values ('T0 un visiteur ne peut pas écrire', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare j jsonb; begin
  j := talents_list('');
  insert into res(test,ok,detail) values ('T2 un compte connecté lit des talents', jsonb_array_length(j) > 0, jsonb_array_length(j)::text);
  insert into res(test,ok,detail) values ('T3 seuls les étudiants avec compétences sont listés', not exists (select 1 from jsonb_array_elements(j) e where coalesce(e->>'skills','') = ''), '');
  insert into res(test,ok,detail) values ('T4 aucune donnée privée (e-mail, téléphone, matricule)', not exists (select 1 from jsonb_array_elements(j) e where e ? 'email' or e ? 'phone' or e ? 'matricule'), '');
  insert into res(test,ok,detail) values ('T5 limite respectée', jsonb_array_length(talents_list('', 2)) <= 2, '');
  insert into res(test,ok,detail) values ('T6 recherche sans résultat : liste vide', jsonb_array_length(talents_list('zzzzqqq')) = 0, '');
end $$;
do $$ declare c1 uuid; c2 uuid; begin
  c1 := start_direct_conversation('c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'Proposition de mission : site vitrine');
  c2 := start_direct_conversation('c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'Deuxième message');
  insert into res(test,ok,detail) values ('T7 message direct : une seule conversation réutilisée', c1 = c2, '');
  insert into res(test,ok,detail) values ('T8 les deux messages sont enregistrés', (select count(*) = 2 from messages where conversation_id = c1), '');
  begin perform start_direct_conversation('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'moi'); insert into res(test,ok,detail) values ('T9 pas de message à soi-même', false, 'accepté'); exception when others then insert into res(test,ok,detail) values ('T9 pas de message à soi-même', sqlerrm like 'Vous ne pouvez pas%', sqlerrm); end;
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin insert into res(test,ok,detail) values ('T10 le destinataire voit la mission dans ses messages', exists (select 1 from my_conversations() where last_body = 'Deuxième message'), ''); end $$;
reset role;
delete from messages where body in ('Proposition de mission : site vitrine', 'Deuxième message');
delete from conversations c where c.listing_id is null and not exists (select 1 from messages m where m.conversation_id = c.id) and c.created_by = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
