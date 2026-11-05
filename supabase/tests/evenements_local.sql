-- Tests des événements sur la base LOCALE isolée (comptes fictifs « Test … »).
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
create temp table ids (k text, v uuid); grant all on ids to public;
delete from events where title like 'ZZ test%';

-- un administrateur crée deux événements
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare a uuid; b uuid; begin
  a := event_create('ZZ test atelier', 'Atelier de test', 'atelier', now() + interval '2 days', now() + interval '2 days 2 hours', 'Salle B2', 0, 1);
  b := event_create('ZZ test exposition', null, 'exposition', now() + interval '3 days', null, 'Hall', 500, null);
  insert into ids values ('atelier', a), ('expo', b);
  insert into res values (default, 'E1 un administrateur crée un événement', a is not null and b is not null, '');
end $$;
reset role;

-- un étudiant ne crée pas
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform event_create('ZZ test pirate', null, 'autre', now() + interval '1 day', null, null, 0, null); insert into res values (default, 'E2 un étudiant ne crée pas', false, 'accepté'); exception when others then insert into res values (default, 'E2 un étudiant ne crée pas', sqlerrm = 'Action non autorisée', sqlerrm); end;
  insert into res values (default, 'E3 la liste filtrée par type', (select jsonb_array_length(events_between(now(), now() + interval '10 days', 'atelier')) = 1 and jsonb_array_length(events_between(now(), now() + interval '10 days', null)) >= 2), '');
  insert into res values (default, 'E4 inscription', event_register((select v from ids where k = 'atelier')) = 'registered', '');
  insert into res values (default, 'E5 double inscription ignorée', event_register((select v from ids where k = 'atelier')) = 'already', '');
  insert into res values (default, 'E6 la liste indique mon inscription et le nombre d''inscrits', (select (e->>'mine')::boolean and (e->>'registered')::int = 1 from jsonb_array_elements(events_between(now(), now() + interval '10 days', 'atelier')) e limit 1), '');
end $$;
reset role;

-- un second étudiant : la capacité (1 place) est atteinte
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform event_register((select v from ids where k = 'atelier')); insert into res values (default, 'E7 événement complet refusé', false, 'accepté'); exception when others then insert into res values (default, 'E7 événement complet refusé', sqlerrm = 'Plus de places', sqlerrm); end;
end $$;
reset role;

-- un visiteur lit sans pouvoir s'inscrire
set role anon;
do $$ begin
  insert into res values (default, 'E8 un visiteur lit la liste', jsonb_array_length(events_between(now(), now() + interval '10 days', null)) >= 2, '');
  begin perform event_register((select v from ids where k = 'expo')); insert into res values (default, 'E9 un visiteur ne s''inscrit pas', false, 'accepté'); exception when others then insert into res values (default, 'E9 un visiteur ne s''inscrit pas', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end;
end $$;
reset role;

-- désinscription puis nettoyage
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  perform event_unregister((select v from ids where k = 'atelier'));
  insert into res values (default, 'E10 désinscription', (select (e->>'registered')::int = 0 from jsonb_array_elements(events_between(now(), now() + interval '10 days', 'atelier')) e limit 1), '');
end $$;
reset role;
delete from events where title like 'ZZ test%';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
