-- Tests de la migration 20261101000400 (parrainage et gains) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
\set ON_ERROR_STOP on
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set C2 '41c9e35e-cdee-4c1f-8068-817dccd55867'
\set SU 'fbee9999-a07e-4700-be3f-caf5977b77a5'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
create temp table t_ctx (k text primary key, v text);
grant select, insert, update on t_ctx to authenticated, anon;
create or replace function pg_temp.v(p text) returns text language sql as $$ select v from t_ctx where k = p $$;
-- les comptes de la réplique doivent être « récents » (code saisi dans les 30 jours) et sans téléphone commun
update auth.users set created_at = now() - interval '2 days' where id in (:'C1', :'C2');
update profiles set phone = null where id in (:'C1', :'C2');

select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare c text; c2 text; begin c := my_referral_code(); c2 := my_referral_code(); insert into t_ctx values ('code', c);
  raise notice 'RESULT|R1 code personnel stable (8 caractères)|%|%', case when c ~ '^[A-Z0-9]{8}$' and c = c2 then 'PASS' else 'FAIL' end, c; end $$;
do $$ begin perform claim_referral(pg_temp.v('code')); raise notice 'RESULT|R2 auto-parrainage refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|R2 auto-parrainage refusé|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'C2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform claim_referral('ZZZZZZZZ'); raise notice 'RESULT|R3a code inconnu refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|R3a code inconnu refusé|PASS|%', sqlerrm; end $$;
do $$ declare r text; begin r := claim_referral(lower(pg_temp.v('code'))); raise notice 'RESULT|R3 filleul enregistré (en attente)|%|%', case when r = 'pending' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|R3 filleul enregistré (en attente)|FAIL|%', sqlerrm; end $$;
do $$ begin perform claim_referral(pg_temp.v('code')); raise notice 'RESULT|R3b second parrain refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|R3b second parrain refusé|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'SU', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform claim_referral(pg_temp.v('code')); raise notice 'RESULT|R4 personnel exclu|FAIL|accepté';
exception when others then raise notice 'RESULT|R4 personnel exclu|PASS|%', sqlerrm; end $$;
reset role;

-- R5 première commande payée < 10 000 : pas d'activation
select set_config('request.jwt.claims', json_build_object('sub', :'C2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r jsonb; begin r := create_order('[{"title":"Confiture artisanale","qty":2}]'::jsonb, false, 'Orange Money'); insert into t_ctx values ('o1', r->>'number');
  r := create_order('[{"title":"Drone éducatif","qty":1}]'::jsonb, false, 'Orange Money'); insert into t_ctx values ('o2', r->>'number');
  r := create_order('[{"title":"Sac à dos design","qty":1}]'::jsonb, false, 'Orange Money'); insert into t_ctx values ('o3', r->>'number');
  r := create_order('[{"title":"Tableau décoratif","qty":1}]'::jsonb, false, 'Orange Money'); insert into t_ctx values ('o4', r->>'number');
  raise notice 'RESULT|R5a commandes du filleul créées|PASS|'; exception when others then raise notice 'RESULT|R5a commandes du filleul créées|FAIL|%', sqlerrm; end $$;
reset role;
update orders set paid = true where number = (select v from t_ctx where k = 'o1');
select 'RESULT|R5 commande payée de 6 000 F : filleul toujours en attente, aucun gain|' || case when (select status from referrals where referee_id = :'C2') = 'pending'
  and (select count(*) from earnings) = 0 then 'PASS' else 'FAIL' end || '|' || (select status from referrals where referee_id = :'C2');
-- R6 commande payée de 150 000 F : activation, prime Bronze 500 F, pas de part des ventes (Bronze)
update orders set paid = true where number = (select v from t_ctx where k = 'o2');
select 'RESULT|R6 activation et prime Bronze 500 F (14 jours d''attente)|' || case when (select status from referrals where referee_id = :'C2') = 'active'
  and (select string_agg(source || ':' || amount, ',') from earnings) = 'referral_bonus:500'
  and (select bool_and(available_at > now() + interval '13 days') from earnings) then 'PASS' else 'FAIL' end || '|' || coalesce((select string_agg(source || ':' || amount, ',') from earnings), 'aucun');
-- R7 nouvelle commande payée : aucune seconde prime
update orders set paid = true where number = (select v from t_ctx where k = 'o3');
select 'RESULT|R7 une seule prime par filleul|' || case when (select count(*) from earnings where source = 'referral_bonus') = 1 then 'PASS' else 'FAIL' end || '|';
-- R8 synthèse du parrain
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare s jsonb; begin s := my_referral_summary();
  raise notice 'RESULT|R8 synthèse : Bronze, 1 actif, 500 F en attente, 0 disponible, filleul abrégé|%|%',
    case when s->>'tier' = 'Bronze' and (s->>'active')::int = 1 and (s->>'waiting')::int = 500 and (s->>'available')::int = 0
          and (s->'referees'->0->>'name') ~ '^\S+( \S\.)?$' then 'PASS' else 'FAIL' end, s; end $$;
reset role;
-- R11 RLS : le filleul ne voit pas les gains du parrain ; écriture directe refusée ; anonyme refusé
select set_config('request.jwt.claims', json_build_object('sub', :'C2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from earnings; raise notice 'RESULT|R11 gains du parrain invisibles au filleul|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
do $$ begin insert into earnings (user_id, source, amount) values (auth.uid(), 'referral_bonus', 100000); raise notice 'RESULT|R11b écriture directe refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|R11b écriture directe refusée|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
do $$ begin perform my_referral_code(); raise notice 'RESULT|R11c anonyme refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|R11c anonyme refusé|PASS|%', sqlerrm; end $$;
reset role;
-- R9 commande annulée (remboursée) : la prime en attente est annulée
update orders set cancelled = true, cancelled_at = now() where number = (select v from t_ctx where k = 'o2');
select 'RESULT|R9 annulation de la commande : prime annulée|' || case when (select status from earnings where source = 'referral_bonus') = 'void' then 'PASS' else 'FAIL' end || '|';
-- R10 palier Argent (5 actifs) : part de 2 % sur les ventes du filleul
insert into referrals (referee_id, referrer_id, status, activated_at)
  select id, :'C1', 'active', now() - interval '40 days' from profiles where role = 'student' and not suspended and id <> :'C1' limit 4;
update orders set paid = true where number = (select v from t_ctx where k = 'o4');
select 'RESULT|R10 palier Argent : part de 2 % (18 000 F → 360 F)|' || case when (select amount from earnings where source = 'referral_share' and order_id = (select id from orders where number = (select v from t_ctx where k = 'o4'))) = 360
  then 'PASS' else 'FAIL' end || '|' || coalesce((select amount::text from earnings where source = 'referral_share'), 'aucune');
-- R12 après 14 jours : disponible (jamais « versé »)
update earnings set available_at = now() - interval '1 day' where source = 'referral_share';
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare s jsonb; begin s := my_referral_summary();
  raise notice 'RESULT|R12 Argent, 5 actifs, 360 F disponibles, prime annulée exclue|%|%', case when s->>'tier' = 'Argent' and (s->>'active')::int = 5 and (s->>'available')::int = 360 and (s->>'waiting')::int = 0 then 'PASS' else 'FAIL' end, s - 'referees'; end $$;
reset role;
-- R13 expiration : filleul en attente au-delà de 90 jours
update referrals set status = 'pending', activated_at = null, created_at = now() - interval '91 days' where referee_id = :'C2';
update orders set paid = false where number = (select v from t_ctx where k = 'o3');
update orders set paid = true where number = (select v from t_ctx where k = 'o3');
select 'RESULT|R13 parrainage expiré après 90 jours|' || case when (select status from referrals where referee_id = :'C2') = 'expired' then 'PASS' else 'FAIL' end || '|';
rollback;
select 'RESULT|R14 réplique inchangée après ROLLBACK|' || case when to_regclass('public.earnings') is null and (select count(*) from pg_trigger where tgname like 'trg_order_%referral') = 0 then 'PASS' else 'FAIL' end || '|';
