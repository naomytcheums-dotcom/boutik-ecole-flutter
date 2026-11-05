-- Tests de l'espace entreprise sur la base LOCALE isolée.
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;

set role anon;
do $$ begin begin perform company_missions(); insert into res values (default, 'E1 un visiteur est refusé', false, 'accepté'); exception when others then insert into res values (default, 'E1 un visiteur est refusé', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end; end $$;
reset role;

-- le client d'un besoin voit ses besoins et leurs propositions, et seulement les siens
do $$ declare c uuid := (select client_id from missions m where exists (select 1 from mission_proposals p where p.mission_id = m.id) limit 1); begin
  perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, false);
  create temp table if not exists keep (c uuid); grant all on keep to public; insert into keep values (c);
end $$;
set role authenticated;
create temp table s (m jsonb, p jsonb); grant all on s to public;
insert into s select company_missions(), company_proposals();
reset role;
insert into res(test, ok, detail) select 'E2 le client liste ses besoins', jsonb_array_length(m) = (select count(*) from missions where client_id = (select c from keep)), jsonb_array_length(m)::text from s;
insert into res(test, ok, detail) select 'E3 il voit les propositions reçues avec le nom de l''auteur', jsonb_array_length(p) = (select count(*) from mission_proposals mp join missions mm on mm.id = mp.mission_id where mm.client_id = (select c from keep)) and jsonb_array_length(p) > 0 and not exists (select 1 from jsonb_array_elements(p) e where coalesce(e->>'author','') = ''), jsonb_array_length(p)::text from s;
insert into res(test, ok, detail) select 'E4 aucune donnée sensible (e-mail, téléphone)', not (s.p::text ilike '%@%') and not (s.m::text ilike '%@%'), '' from s;

-- un compte sans besoin ne voit rien
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin insert into res values (default, 'E5 un compte sans besoin ne voit aucune proposition', not exists (select 1 from missions where client_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab') = false or jsonb_array_length(company_proposals()) = (select count(*) from mission_proposals mp join missions mm on mm.id = mp.mission_id where mm.client_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'), ''); end $$;
reset role;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
