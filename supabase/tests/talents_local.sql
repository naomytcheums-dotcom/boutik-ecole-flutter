-- Tests de talents_list() sur la base LOCALE isolée (comptes fictifs « Test … »).
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
set role anon;
do $$ begin begin perform talents_list(''); insert into res(test,ok,detail) values ('T1 visiteur refusé', false, 'accepté'); exception when others then insert into res(test,ok,detail) values ('T1 visiteur refusé', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end; end $$;
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
reset role;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
