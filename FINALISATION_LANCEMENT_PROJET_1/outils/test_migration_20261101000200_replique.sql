-- Tests de la migration 20261101000200 (concours) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
-- Lancement : outils\executer_test_replique.ps1 (le marqueur ci-dessous est remplacé par la migration, ligne entière unique).
\set ON_ERROR_STOP on
\set A1 'c8332c75-ae70-4685-8589-d6ab77667e16'
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set D1 '612763ab-8c63-432b-a6b5-2b23ab7d5590'
\set S1 'c05948bb-3ef0-491e-be5a-93e92f6a19aa'
\set S2 '74197c6c-3b42-48b1-b1e7-fe21b9d2b651'
\set S3 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'
\set S4 '61a250a1-0085-4c9b-8e2f-80e6f3efcf94'
\set E1 'b909924d-f255-4c28-8689-f652efe6ba6b'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
create temp table t_ctx (k text primary key, v text);
insert into t_ctx values ('s2mail', (select email from profiles where id = :'S2')), ('e1mail', (select email from profiles where id = :'E1')),
  ('s4mail', (select email from profiles where id = :'S4')), ('s2jur', (select email from profiles where id = :'S2'));
grant select, insert, update on t_ctx to authenticated, anon;
create or replace function pg_temp.v(p text) returns text language sql as $$ select v from t_ctx where k = p $$;

-- T1 un étudiant ne publie pas de concours
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform save_contest(null, 'Concours pirate', repeat('x', 40), '', '', 'Douala', now() + interval '1 day', now() + interval '2 days', null, null, 0, 10, true);
  raise notice 'RESULT|T1 étudiant refusé (publication)|FAIL|accepté'; exception when others then raise notice 'RESULT|T1 étudiant refusé (publication)|PASS|%', sqlerrm; end $$;
reset role;

-- T2 le département publie (2 places)
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare id uuid; begin
  id := save_contest(null, 'Orange Digital Challenge 2026', 'Solution numérique pour l''inclusion financière, de l''idée au pitch.', 'Inclusion financière', 'Équipes de 2 à 5.', 'Douala',
                     now() + interval '1 day', now() + interval '2 days', current_date + 3, current_date + 5, 5000000, 2, true);
  insert into t_ctx values ('contest', id::text);
  raise notice 'RESULT|T2 département publie|PASS|%', id;
exception when others then raise notice 'RESULT|T2 département publie|FAIL|%', sqlerrm; end $$;
-- T9 après publication : dotation non diminuable, dates prolongeables
do $$ begin perform save_contest(pg_temp.v('contest')::uuid, 'Orange Digital Challenge 2026', 'Solution numérique pour l''inclusion financière, de l''idée au pitch.', '', '', 'Douala',
                     now() + interval '1 day', now() + interval '2 days', null, null, 1000, 2, true);
  raise notice 'RESULT|T9 dotation diminuée refusée|FAIL|accepté'; exception when others then raise notice 'RESULT|T9 dotation diminuée refusée|PASS|%', sqlerrm; end $$;
do $$ begin perform save_contest(pg_temp.v('contest')::uuid, 'Orange Digital Challenge 2026', 'Solution numérique pour l''inclusion financière, de l''idée au pitch.', '', '', 'Douala',
                     now() + interval '3 days', now() + interval '4 days', null, null, 5000000, 2, true);
  raise notice 'RESULT|T9b dates prolongées acceptées|PASS|'; exception when others then raise notice 'RESULT|T9b dates prolongées acceptées|FAIL|%', sqlerrm; end $$;
reset role;

-- T3 un visiteur voit le concours publié
select set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
do $$ declare n int; begin select count(*) into n from contests where title = 'Orange Digital Challenge 2026';
  raise notice 'RESULT|T3 visiteur voit le concours publié|%|%', case when n = 1 then 'PASS' else 'FAIL' end, n; end $$;
do $$ begin perform register_contest_team(gen_random_uuid(), 'x', '', false, true); raise notice 'RESULT|T3b visiteur ne s''inscrit pas|FAIL|accepté';
exception when others then raise notice 'RESULT|T3b visiteur ne s''inscrit pas|PASS|%', sqlerrm; end $$;
reset role;

-- T4 inscription : règlement obligatoire, puis équipe Alpha
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform register_contest_team(pg_temp.v('contest')::uuid, 'Équipe Alpha', 'Paiement', false, false); raise notice 'RESULT|T4 règlement obligatoire|FAIL|accepté';
exception when others then raise notice 'RESULT|T4 règlement obligatoire|PASS|%', sqlerrm; end $$;
do $$ declare t uuid; begin t := register_contest_team(pg_temp.v('contest')::uuid, 'Équipe Alpha', 'Paiement', false, true); insert into t_ctx values ('alpha', t::text);
  raise notice 'RESULT|T4b équipe Alpha inscrite|PASS|%', t; exception when others then raise notice 'RESULT|T4b équipe Alpha inscrite|FAIL|%', sqlerrm; end $$;
do $$ begin perform register_contest_team(pg_temp.v('contest')::uuid, 'Équipe Doublon', '', false, true); raise notice 'RESULT|T5 double inscription refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|T5 double inscription refusée|PASS|%', sqlerrm; end $$;
-- T7 invitation d'un coéquipier
do $$ begin perform invite_contest_member(pg_temp.v('alpha')::uuid, pg_temp.v('s2mail')); raise notice 'RESULT|T7 invitation envoyée|PASS|';
exception when others then raise notice 'RESULT|T7 invitation envoyée|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform register_contest_team(pg_temp.v('contest')::uuid, 'Équipe Client', '', true, true); raise notice 'RESULT|T6 client refusé (étudiants seulement)|FAIL|accepté';
exception when others then raise notice 'RESULT|T6 client refusé (étudiants seulement)|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := answer_contest_invite(pg_temp.v('alpha')::uuid, true); raise notice 'RESULT|T7b invitation acceptée|%|%', case when r = 'member' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T7b invitation acceptée|FAIL|%', sqlerrm; end $$;
do $$ begin perform submit_contest_project(pg_temp.v('alpha')::uuid, 'Paiement hors ligne', repeat('Description du projet. ', 3), null, null, null, true, true);
  raise notice 'RESULT|T10 membre non capitaine ne dépose pas|FAIL|accepté'; exception when others then raise notice 'RESULT|T10 membre non capitaine ne dépose pas|PASS|%', sqlerrm; end $$;
reset role;

-- T8 deuxième équipe, puis places épuisées
select set_config('request.jwt.claims', json_build_object('sub', :'S3', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare t uuid; begin t := register_contest_team(pg_temp.v('contest')::uuid, 'Équipe Beta', 'Énergie', true, true); insert into t_ctx values ('beta', t::text);
  raise notice 'RESULT|T8 équipe Beta inscrite|PASS|'; exception when others then raise notice 'RESULT|T8 équipe Beta inscrite|FAIL|%', sqlerrm; end $$;
do $$ begin perform submit_contest_project(pg_temp.v('beta')::uuid, 'Kit solaire', repeat('Description du projet solaire. ', 3), 'https://exemple.cm/demo', null, null, true, true);
  raise notice 'RESULT|T11 Beta dépose|PASS|'; exception when others then raise notice 'RESULT|T11 Beta dépose|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S4', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform register_contest_team(pg_temp.v('contest')::uuid, 'Équipe Gamma', '', true, true); raise notice 'RESULT|T8b places épuisées|FAIL|accepté';
exception when others then raise notice 'RESULT|T8b places épuisées|PASS|%', sqlerrm; end $$;
reset role;

-- T10b dépôt du capitaine : brouillon, puis soumission définitive, puis verrouillage
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform submit_contest_project(pg_temp.v('alpha')::uuid, 'Paiement hors ligne', repeat('Description du projet. ', 3), null, null, null, true, false);
  perform submit_contest_project(pg_temp.v('alpha')::uuid, 'Paiement hors ligne', repeat('Description du projet final. ', 3), 'https://exemple.cm/app', null, null, true, true);
  raise notice 'RESULT|T10b brouillon puis dépôt définitif|PASS|'; exception when others then raise notice 'RESULT|T10b brouillon puis dépôt définitif|FAIL|%', sqlerrm; end $$;
do $$ begin perform submit_contest_project(pg_temp.v('alpha')::uuid, 'Autre', repeat('Autre description du projet. ', 3), null, null, null, true, true);
  raise notice 'RESULT|T10c dépôt verrouillé après soumission|FAIL|accepté'; exception when others then raise notice 'RESULT|T10c dépôt verrouillé après soumission|PASS|%', sqlerrm; end $$;
reset role;
-- T20 RLS : Beta ne lit pas le dépôt d'Alpha
select set_config('request.jwt.claims', json_build_object('sub', :'S3', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from contest_submissions where team_id = pg_temp.v('alpha')::uuid;
  raise notice 'RESULT|T20 une équipe ne lit pas le dépôt d''une autre|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
reset role;

-- T12 jurés : entreprise E1, étudiant S4 et S2 (membre d'Alpha, pour le conflit d'intérêts)
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform assign_contest_juror(pg_temp.v('contest')::uuid, pg_temp.v('e1mail'), true); perform assign_contest_juror(pg_temp.v('contest')::uuid, pg_temp.v('s4mail'), true);
  perform assign_contest_juror(pg_temp.v('contest')::uuid, pg_temp.v('s2jur'), true); raise notice 'RESULT|T12 jurés désignés|PASS|';
exception when others then raise notice 'RESULT|T12 jurés désignés|FAIL|%', sqlerrm; end $$;
-- T14 délibération impossible avant la clôture des dépôts
do $$ begin perform set_contest_status(pg_temp.v('contest')::uuid, 'judging'); raise notice 'RESULT|T14 jury avant clôture refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T14 jury avant clôture refusé|PASS|%', sqlerrm; end $$;
reset role;
-- T13 note avant ouverture du jury : refusée
select set_config('request.jwt.claims', json_build_object('sub', :'E1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('alpha')::uuid), 8::smallint, 7::smallint, 9::smallint, 6::smallint, null);
  raise notice 'RESULT|T13 note avant ouverture refusée|FAIL|accepté'; exception when others then raise notice 'RESULT|T13 note avant ouverture refusée|PASS|%', sqlerrm; end $$;
reset role;
-- le temps passe (simulation, annulée au ROLLBACK)
update contests set reg_close_at = now() - interval '2 hours', submit_close_at = now() - interval '1 hour' where id = (select v from t_ctx where k = 'contest')::uuid;
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := set_contest_status(pg_temp.v('contest')::uuid, 'judging'); raise notice 'RESULT|T15 délibération ouverte|%|%', case when r = 'judging' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T15 délibération ouverte|FAIL|%', sqlerrm; end $$;
reset role;
-- T16 notes ; conflit d'intérêts
select set_config('request.jwt.claims', json_build_object('sub', :'E1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from contest_submissions; 
  perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('alpha')::uuid), 8::smallint, 7::smallint, 9::smallint, 6::smallint, 'Solide');
  raise notice 'RESULT|T16 juré lit les dépôts et note|%|dépôts visibles=%', case when n = 2 then 'PASS' else 'FAIL' end, n; exception when others then raise notice 'RESULT|T16 juré lit les dépôts et note|FAIL|%', sqlerrm; end $$;
do $$ begin perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('alpha')::uuid), 11::smallint, 7::smallint, 9::smallint, 6::smallint, null);
  raise notice 'RESULT|T16b note > 10 refusée|FAIL|accepté'; exception when others then raise notice 'RESULT|T16b note > 10 refusée|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('alpha')::uuid), 10::smallint, 10::smallint, 10::smallint, 10::smallint, null);
  raise notice 'RESULT|T16c conflit d''intérêts refusé|FAIL|accepté'; exception when others then raise notice 'RESULT|T16c conflit d''intérêts refusé|PASS|%', sqlerrm; end $$;
reset role;
-- T17 résultats impossibles tant qu'un projet a moins de 2 notes
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform set_contest_status(pg_temp.v('contest')::uuid, 'results'); raise notice 'RESULT|T17 résultats incomplets refusés|FAIL|accepté';
exception when others then raise notice 'RESULT|T17 résultats incomplets refusés|PASS|%', sqlerrm; end $$;
reset role;
-- T18 notes manquantes
select set_config('request.jwt.claims', json_build_object('sub', :'S4', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('alpha')::uuid), 9::smallint, 8::smallint, 8::smallint, 7::smallint, null);
  perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('beta')::uuid), 6::smallint, 6::smallint, 7::smallint, 5::smallint, null);
  raise notice 'RESULT|T18 deuxième juré note|PASS|'; exception when others then raise notice 'RESULT|T18 deuxième juré note|FAIL|%', sqlerrm; end $$;
-- T19a avant résultats, un étudiant non juré... S4 est juré : il voit le classement provisoire
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'E1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform score_contest_submission((select id from contest_submissions where team_id = pg_temp.v('beta')::uuid), 7::smallint, 6::smallint, 8::smallint, 6::smallint, null);
  raise notice 'RESULT|T18b notes complètes|PASS|'; exception when others then raise notice 'RESULT|T18b notes complètes|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S3', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from contest_ranking(pg_temp.v('contest')::uuid);
  raise notice 'RESULT|T19a classement caché avant publication (équipe)|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := set_contest_status(pg_temp.v('contest')::uuid, 'results'); raise notice 'RESULT|T18c résultats publiés|%|%', case when r = 'results' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T18c résultats publiés|FAIL|%', sqlerrm; end $$;
reset role;
-- T19 classement réel : Alpha (30 et 32 → 31) devant Beta (24 et 27 → 25,5)
select set_config('request.jwt.claims', json_build_object('sub', :'S3', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin select string_agg(rank || ':' || team_name || ':' || total || ':' || notes, ' ' order by rank) into r from contest_ranking(pg_temp.v('contest')::uuid);
  raise notice 'RESULT|T19 classement réel publié|%|%', case when r = '1:Équipe Alpha:31.00:2 2:Équipe Beta:25.50:2' then 'PASS' else 'FAIL' end, r; end $$;
do $$ declare n int; begin select count(*) into n from contest_scores s join contest_submissions x on x.id = s.submission_id where x.team_id = pg_temp.v('beta')::uuid;
  raise notice 'RESULT|T19b l''équipe voit ses notes après résultats|%|%', case when n = 2 then 'PASS' else 'FAIL' end, n; end $$;
reset role;
select 'RESULT|T21 membres notifiés des résultats|' || case when (select count(*) from notifications where kind = 'contest' and title = 'Résultats publiés') = 3 then 'PASS' else 'FAIL' end
  || '|' || (select count(*) from notifications where kind = 'contest' and title = 'Résultats publiés');

-- T22 modération : motif obligatoire ; équipe écartée retirée du classement
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform moderate_contest_team(pg_temp.v('beta')::uuid, true, 'non'); raise notice 'RESULT|T22 motif obligatoire|FAIL|accepté';
exception when others then raise notice 'RESULT|T22 motif obligatoire|PASS|%', sqlerrm; end $$;
do $$ declare n int; begin perform moderate_contest_team(pg_temp.v('beta')::uuid, true, 'Projet non original'); select count(*) into n from contest_ranking(pg_temp.v('contest')::uuid);
  raise notice 'RESULT|T22b équipe écartée hors classement|%|%', case when n = 1 then 'PASS' else 'FAIL' end, n; exception when others then raise notice 'RESULT|T22b équipe écartée hors classement|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin insert into contests (title, reg_close_at, submit_close_at, places) values ('Direct', now(), now(), 1); raise notice 'RESULT|T23 écriture directe refusée (RLS/droits)|FAIL|accepté';
exception when others then raise notice 'RESULT|T23 écriture directe refusée (RLS/droits)|PASS|%', sqlerrm; end $$;
reset role;
rollback;
select 'RESULT|T24 réplique inchangée après ROLLBACK|' || case when to_regclass('public.contests') is null and (select count(*) from pg_proc where proname = 'save_contest') = 0 then 'PASS' else 'FAIL' end || '|';
