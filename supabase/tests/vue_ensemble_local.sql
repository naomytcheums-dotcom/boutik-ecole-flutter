-- Tests de platform_overview() sur la base LOCALE isolée (comptes fictifs « Test … »).
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
\set STAFF '612763ab-8c63-432b-a6b5-2b23ab7d5590'
\set STUDENT 'c05948bb-3ef0-491e-be5a-93e92f6a19aa'
set role anon;
do $$ begin begin perform platform_overview(); insert into res(test,ok,detail) values ('V1 anonyme refusé', false, 'accepté'); exception when others then insert into res(test,ok,detail) values ('V1 anonyme refusé', true, sqlerrm); end; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'STUDENT', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin begin perform platform_overview(); insert into res(test,ok,detail) values ('V2 un étudiant est refusé', false, 'accepté'); exception when others then insert into res(test,ok,detail) values ('V2 un étudiant est refusé', sqlerrm = 'Action non autorisée', sqlerrm); end; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'STAFF', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare j jsonb; begin
  j := platform_overview();
  insert into res(test,ok,detail) values ('V3 le département lit la vue', j is not null, j::text);
  create temp table if not exists vue (j jsonb); grant all on vue to public; insert into vue values (j);
end $$;
reset role;
-- comparaison faite avec les droits complets : la fonction lit toutes les lignes, la politique de lecture limite le rôle départementaire
insert into res(test, ok, detail) select 'V4 les chiffres égalent les tables', (j->>'orders')::int = (select count(*) from orders) and (j->>'paid_revenue')::bigint = (select coalesce(sum(subtotal+fee),0) from orders where paid and cancelled_at is null) and (j->>'students')::int = (select count(*) from profiles where role::text='student'), '' from vue;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 90) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
