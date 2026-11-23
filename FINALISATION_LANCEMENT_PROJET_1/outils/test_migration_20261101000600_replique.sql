-- Tests de la migration 20261101000600 (reels et défis) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
\set ON_ERROR_STOP on
\set ST '74197c6c-3b42-48b1-b1e7-fe21b9d2b651'
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set D1 '612763ab-8c63-432b-a6b5-2b23ab7d5590'
\set SU 'fbee9999-a07e-4700-be3f-caf5977b77a5'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
create temp table t_ctx (k text primary key, v text);
grant select, insert, update on t_ctx to authenticated, anon;
create or replace function pg_temp.v(p text) returns text language sql as $$ select v from t_ctx where k = p $$;
update profiles set certification = 'none' where id = :'ST';

select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform create_post(auth.uid()::text || '/a.mp4', 'video', 'x', null, null); raise notice 'RESULT|D1 client ne publie pas|FAIL|accepté';
exception when others then raise notice 'RESULT|D1 client ne publie pas|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'ST', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform create_post('autre-dossier/a.mp4', 'video', 'x', null, null); raise notice 'RESULT|D2 média hors de son dossier refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|D2 média hors de son dossier refusé|PASS|%', sqlerrm; end $$;
do $$ begin perform create_post(auth.uid()::text || '/a.mp4', 'video', 'x', null, (select id from listings where seller_id is null limit 1)); raise notice 'RESULT|D3 lien vers une annonce d''autrui refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|D3 lien vers une annonce d''autrui refusé|PASS|%', sqlerrm; end $$;
do $$ declare r jsonb; begin r := create_post(auth.uid()::text || '/kit-solaire.mp4', 'video', 'Pose d''un kit solaire', array['Solaire', 'solaire', 'GE'], null); insert into t_ctx values ('p1', r->>'id');
  raise notice 'RESULT|D4 compte non certifié : publication en attente de validation|%|%', case when r->>'status' = 'pending' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|D4 compte non certifié : publication en attente de validation|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from reels_feed(20); raise notice 'RESULT|D5 publication en attente absente du fil|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := moderate_post(pg_temp.v('p1')::uuid, true, null); raise notice 'RESULT|D6 département valide|%|%', case when r = 'published' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|D6 département valide|FAIL|%', sqlerrm; end $$;
do $$ declare r jsonb; begin r := create_post(auth.uid()::text || '/atelier.jpg', 'image', 'Atelier', null, null); raise notice 'RESULT|D7 département publié directement|%|%', case when r->>'status' = 'published' then 'PASS' else 'FAIL' end, r->>'status';
exception when others then raise notice 'RESULT|D7 département publié directement|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
do $$ declare r record; n int; begin select count(*) into n from reels_feed(20); select * into r from reels_feed(20) where caption like 'Pose%';
  raise notice 'RESULT|D8 visiteur lit le fil : 2 publiées, auteur abrégé, mots-clés dédoublonnés|%|% % %', case when n = 2 and r.author ~ '^\S+( \S\.)?$' and r.tags = array['ge', 'solaire'] then 'PASS' else 'FAIL' end, n, r.author, r.tags; end $$;
do $$ begin perform toggle_post_like(pg_temp.v('p1')::uuid); raise notice 'RESULT|D8b visiteur ne peut pas aimer|FAIL|accepté';
exception when others then raise notice 'RESULT|D8b visiteur ne peut pas aimer|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare a boolean; b boolean; n int; begin a := toggle_post_like(pg_temp.v('p1')::uuid); select likes into n from reels_feed(20) where id = pg_temp.v('p1')::uuid; b := toggle_post_like(pg_temp.v('p1')::uuid);
  raise notice 'RESULT|D9 « j''aime » puis retrait|%|% % %', case when a and not b and n = 1 then 'PASS' else 'FAIL' end, a, n, b; end $$;
do $$ begin perform report_post(pg_temp.v('p1')::uuid, 'Contenu trompeur'); raise notice 'RESULT|D10 signalement|PASS|'; exception when others then raise notice 'RESULT|D10 signalement|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'SU', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform moderate_post(pg_temp.v('p1')::uuid, false, ''); raise notice 'RESULT|D11 masquage sans motif refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|D11 masquage sans motif refusé|PASS|%', sqlerrm; end $$;
do $$ declare r text; begin r := moderate_post(pg_temp.v('p1')::uuid, false, 'Signalement fondé'); raise notice 'RESULT|D11b support masque, signalement clos|%|%',
  case when r = 'hidden' and not exists (select 1 from post_reports where status = 'open') then 'PASS' else 'FAIL' end, r; end $$;
reset role;
-- Défis : série, récompense à 6 jours, défi « 3 posts »
select set_config('request.jwt.claims', json_build_object('sub', :'ST', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare s int; begin s := daily_checkin(); s := daily_checkin(); raise notice 'RESULT|D12 présence du jour comptée une fois|%|%', case when s = 1 then 'PASS' else 'FAIL' end, s; end $$;
do $$ begin perform claim_streak_boost(); raise notice 'RESULT|D13 boost refusé avant 6 jours|FAIL|accepté';
exception when others then raise notice 'RESULT|D13 boost refusé avant 6 jours|PASS|%', sqlerrm; end $$;
do $$ begin perform claim_challenge('posts3'); raise notice 'RESULT|D14 défi non atteint refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|D14 défi non atteint refusé|PASS|%', sqlerrm; end $$;
reset role;
insert into daily_checkins (user_id, day) select :'ST', (now() at time zone 'Africa/Douala')::date - g from generate_series(1, 5) g;
update posts set status = 'published', published_at = now() where id = (select v from t_ctx where k = 'p1')::uuid;
insert into posts (author_id, media_path, media_kind, status, published_at) select :'ST', :'ST' || '/p' || g || '.jpg', 'image', 'published', now() from generate_series(2, 3) g;
select set_config('request.jwt.claims', json_build_object('sub', :'ST', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare j jsonb; begin j := my_challenges(); raise notice 'RESULT|D15 synthèse : série 6, 3 posts, récompenses disponibles|%|%',
  case when (j->>'streak')::int = 6 and (j->>'posts_week')::int = 3 and (j->>'posts_claimable')::boolean and (j->>'streak_reward_claimable')::boolean then 'PASS' else 'FAIL' end, j - 'badges'; end $$;
do $$ declare r text; p int; begin r := claim_streak_boost(); p := claim_challenge('posts3');
  raise notice 'RESULT|D16 boost 24 h et +200 points|%|% %', case when r = 'boosted' and p = 200 then 'PASS' else 'FAIL' end, r, p; end $$;
do $$ begin perform claim_challenge('posts3'); raise notice 'RESULT|D17 récompense hebdomadaire unique|FAIL|accepté';
exception when others then raise notice 'RESULT|D17 récompense hebdomadaire unique|PASS|%', sqlerrm; end $$;
do $$ declare b boolean; begin select boosted into b from reels_feed(1); raise notice 'RESULT|D18 publication boostée en tête du fil|%|%', case when b then 'PASS' else 'FAIL' end, b; end $$;
do $$ begin insert into points_ledger (user_id, source, points) values (auth.uid(), 'triche', 100000); raise notice 'RESULT|D19 points non modifiables directement|FAIL|accepté';
exception when others then raise notice 'RESULT|D19 points non modifiables directement|PASS|%', sqlerrm; end $$;
reset role;
rollback;
select 'RESULT|D20 réplique inchangée après ROLLBACK|' || case when to_regclass('public.posts') is null and not exists (select 1 from storage.buckets where id = 'post-media') then 'PASS' else 'FAIL' end || '|';
