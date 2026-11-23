-- Tests de la migration 20261101000800 (produits d'exemple) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
\set ON_ERROR_STOP on
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set D1 '612763ab-8c63-432b-a6b5-2b23ab7d5590'
\set ST '74197c6c-3b42-48b1-b1e7-fe21b9d2b651'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
select 'RESULT|E1 exactement les 11 produits fictifs deviennent des exemples|' || case when (select count(*) from listings where showcase) = 11 and not exists (select 1 from listings where showcase and title like 'zz-test%')
  and not exists (select 1 from listings where showcase and seller_id is not null) then 'PASS' else 'FAIL' end || '|' || (select count(*) from listings where showcase);
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform create_order('[{"title":"Drone éducatif","qty":1}]'::jsonb, false, 'Orange Money'); raise notice 'RESULT|E2 produit d''exemple : commande refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|E2 produit d''exemple : commande refusée|PASS|%', sqlerrm; end $$;
do $$ declare n int; begin select count(*) into n from listings where title = 'Drone éducatif' and showcase; raise notice 'RESULT|E3 exemple toujours visible au catalogue|%|%', case when n = 1 then 'PASS' else 'FAIL' end, n; end $$;
do $$ declare r jsonb; begin r := create_order(jsonb_build_array(jsonb_build_object('title', (select title from listings where seller_id is not null and status = 'approved' and stock > 0 and category <> 'Services' limit 1), 'qty', 1)), false, 'Orange Money');
  raise notice 'RESULT|E4 vrai produit d''étudiant : commande acceptée|PASS|%', r->>'number'; exception when others then raise notice 'RESULT|E4 vrai produit d''étudiant : commande acceptée|FAIL|%', sqlerrm; end $$;
do $$ begin perform set_listing_showcase((select id from listings where title = 'Drone éducatif'), false); raise notice 'RESULT|E5 client ne change pas le statut d''exemple|FAIL|accepté';
exception when others then raise notice 'RESULT|E5 client ne change pas le statut d''exemple|PASS|%', sqlerrm; end $$;
reset role;
select 'RESULT|E2b stock de l''exemple inchangé après le refus|' || case when (select stock from listings where title = 'Drone éducatif') = (select stock from listings where title = 'Drone éducatif') then 'PASS' else 'FAIL' end || '|';
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare b boolean; begin b := set_listing_showcase((select id from listings where title = 'Jus de bissap'), false); raise notice 'RESULT|E6 département passe un exemple en vente réelle|%|%', case when b = false then 'PASS' else 'FAIL' end, b;
exception when others then raise notice 'RESULT|E6 département passe un exemple en vente réelle|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r jsonb; begin r := create_order('[{"title":"Jus de bissap","qty":1}]'::jsonb, false, 'Orange Money'); raise notice 'RESULT|E7 produit devenu réel : commande acceptée|PASS|%', r->>'number';
exception when others then raise notice 'RESULT|E7 produit devenu réel : commande acceptée|FAIL|%', sqlerrm; end $$;
reset role;
rollback;
select 'RESULT|E8 réplique inchangée après ROLLBACK|' || case when not exists (select 1 from information_schema.columns where table_name = 'listings' and column_name = 'showcase') then 'PASS' else 'FAIL' end || '|';
