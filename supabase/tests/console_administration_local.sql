-- Tests de la console d'administration sur la base LOCALE isolée.
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;

set role anon;
do $$ begin begin perform admin_users(null, 5); insert into res values (default, 'C1 un visiteur est refusé', false, 'accepté'); exception when others then insert into res values (default, 'C1 un visiteur est refusé', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end; end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform admin_users(null, 5); insert into res values (default, 'C2 un étudiant est refusé', false, 'accepté'); exception when others then insert into res values (default, 'C2 un étudiant est refusé', sqlerrm = 'Action non autorisée', sqlerrm); end;
  begin perform admin_departments(); insert into res values (default, 'C3 un étudiant ne lit pas les départements', false, 'accepté'); exception when others then insert into res values (default, 'C3 un étudiant ne lit pas les départements', sqlerrm = 'Action non autorisée', sqlerrm); end;
end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare u jsonb; r jsonb; begin
  u := admin_users(null, 200);
  insert into res values (default, 'C4 la gestion liste les personnes', jsonb_array_length(u) > 10, jsonb_array_length(u)::text);
  insert into res values (default, 'C5 aucune donnée sensible (mot de passe, téléphone, e-mail)', not (u::text ilike '%password%') and not (u::text ilike '%@%') and not exists (select 1 from jsonb_array_elements(u) e where e ? 'phone' or e ? 'email'), '');
  r := admin_users(array['dept'], 50);
  insert into res values (default, 'C6 filtre par rôle', jsonb_array_length(r) > 0 and not exists (select 1 from jsonb_array_elements(r) e where e->>'role' <> 'dept'), jsonb_array_length(r)::text);
  insert into res values (default, 'C7 les départements se listent', jsonb_typeof(admin_departments()) = 'array', '');
end $$;
reset role;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
