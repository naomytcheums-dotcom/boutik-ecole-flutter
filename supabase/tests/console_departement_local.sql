-- Tests de la console du département sur la base LOCALE isolée.
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;

set role anon;
do $$ begin begin perform dept_stats(); insert into res values (default, 'D1 un visiteur est refusé', false, 'accepté'); exception when others then insert into res values (default, 'D1 un visiteur est refusé', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end; end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin begin perform dept_students(5); insert into res values (default, 'D2 un étudiant est refusé', false, 'accepté'); exception when others then insert into res values (default, 'D2 un étudiant est refusé', sqlerrm = 'Action non autorisée', sqlerrm); end; end $$;
reset role;

-- l'administrateur voit tout l'établissement ; les chiffres égalent les tables
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
create temp table s (j jsonb, st jsonb); grant all on s to public;
insert into s select dept_students(200), dept_stats();
reset role;
insert into res(test, ok, detail) select 'D3 l''administrateur liste les étudiants', jsonb_array_length(j) = (select count(*) from profiles where role::text = 'student'), jsonb_array_length(j)::text from s;
insert into res(test, ok, detail) select 'D4 le chiffre d''affaires égale les lignes payées', (st->>'revenue')::bigint = (select coalesce(sum(ol.unit_price * ol.qty), 0) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id where o.paid and o.cancelled_at is null and l.seller_id is not null), st->>'revenue' from s;
insert into res(test, ok, detail) select 'D5 les ventes par étudiant totalisent le chiffre d''affaires', (select coalesce(sum((e->>'sales')::bigint), 0) from s, jsonb_array_elements(s.j) e) = (st->>'revenue')::bigint, '' from s;

-- un responsable de département sans département renseigné ne voit rien
update profiles set department_id = null where id = (select id from profiles where role::text = 'dept' limit 1);
do $$ declare d uuid := (select id from profiles where role::text = 'dept' limit 1); begin perform set_config('request.jwt.claims', json_build_object('sub', d, 'role', 'authenticated')::text, false); end $$;
set role authenticated;
do $$ begin insert into res values (default, 'D6 un responsable sans département ne voit aucune ligne', jsonb_array_length(dept_students(50)) = 0 and (dept_stats()->>'orders')::int = 0, ''); end $$;
reset role;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
