-- Tests de la migration 20261101000100 (produits de la plateforme) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
-- Chaque cas affiche « RESULT|cas|PASS|détail » ou « RESULT|cas|FAIL|détail ». Rôles simulés comme PostgREST (role + request.jwt.claims).
-- Le script est envoyé à psql avec la migration insérée à la place de la ligne marqueur (ligne entière, voir plus bas).
-- Arrêt à la première erreur jusqu'à la fin de la migration : sans BEGIN effectif, rien ne s'exécute.
\set ON_ERROR_STOP on
\set A1 'c8332c75-ae70-4685-8589-d6ab77667e16'
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set S1 'fbee9999-a07e-4700-be3f-caf5977b77a5'
\set D1 '612763ab-8c63-432b-a6b5-2b23ab7d5590'
\set ST '74197c6c-3b42-48b1-b1e7-fe21b9d2b651'
\set V1 'e44c56a3-377c-4c29-b052-8944f93eeaf3'
\set VL 'zz-test-msg-77b4b8'
\set PL 'Confiture artisanale'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
create temp table t_ctx (num text, pl uuid, vl uuid, pstock int, vstock int);
insert into t_ctx (pl, vl, pstock, vstock)
  select (select id from listings where title = :'PL' and seller_id is null), (select id from listings where title = :'VL'),
         (select stock from listings where title = :'PL' and seller_id is null), (select stock from listings where title = :'VL');
grant select, update on t_ctx to authenticated, anon;

-- T1 commande réelle mixte (plateforme × 2 + vendeur × 1), prix recalculés par le serveur
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r jsonb; begin
  r := create_order(jsonb_build_array(jsonb_build_object('title', 'Confiture artisanale', 'qty', 2), jsonb_build_object('title', 'zz-test-msg-77b4b8', 'qty', 1)), false, 'Orange Money');
  update t_ctx set num = r->>'number';
  raise notice 'RESULT|T1 commande mixte créée (prix serveur)|%|%', case when (r->>'subtotal')::int = 2 * 3000 + 10000 then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T1 commande mixte créée (prix serveur)|FAIL|%', sqlerrm; end $$;
-- T2 le client ne peut pas faire avancer la préparation
do $$ begin perform set_seller_order_status((select num from t_ctx), 1); raise notice 'RESULT|T2 client refusé (préparation)|FAIL|accepté';
exception when others then raise notice 'RESULT|T2 client refusé (préparation)|PASS|%', sqlerrm; end $$;
reset role;
select 'RESULT|T1b stock plateforme décrémenté de 2|' || case when (select stock from listings where id = (select pl from t_ctx)) = (select pstock from t_ctx) - 2 then 'PASS' else 'FAIL' end || '|';
update orders set paid = true where number = (select num from t_ctx);   -- paiement simulé (annulé au ROLLBACK)

-- T3 département : voit la commande, uniquement les lignes de la plateforme
select set_config('request.jwt.claims', json_build_object('sub', :'D1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare t int; q int; begin select total, qty into t, q from seller_orders() where number = (select num from t_ctx);
  raise notice 'RESULT|T3 département voit les lignes plateforme|%|total=% qté=%', case when t = 6000 and q = 2 then 'PASS' else 'FAIL' end, t, q; end $$;
do $$ declare b boolean; begin b := is_platform_manager(); raise notice 'RESULT|T3b département gestionnaire plateforme|%|%', case when b then 'PASS' else 'FAIL' end, b; end $$;
-- T4 département fait passer la commande « acceptée »
do $$ declare r int; begin r := set_seller_order_status((select num from t_ctx), 1); raise notice 'RESULT|T4 département accepte|%|%', case when r = 1 then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T4 département accepte|FAIL|%', sqlerrm; end $$;
-- T5 même statut une seconde fois : refusé
do $$ begin perform set_seller_order_status((select num from t_ctx), 1); raise notice 'RESULT|T5 double avancement refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T5 double avancement refusé|PASS|%', sqlerrm; end $$;
-- T6 département modifie le stock d'un produit plateforme (journalisé) et ne peut pas se l'approprier
do $$ declare n int; begin update listings set stock = 40 where id = (select pl from t_ctx); get diagnostics n = row_count;
  raise notice 'RESULT|T6 département ajuste le stock plateforme|%|lignes=%', case when n = 1 then 'PASS' else 'FAIL' end, n;
exception when others then raise notice 'RESULT|T6 département ajuste le stock plateforme|FAIL|%', sqlerrm; end $$;
do $$ begin update listings set seller_id = auth.uid() where id = (select pl from t_ctx); exception when others then null; end $$;
do $$ begin update listings set price = 100 where id = (select pl from t_ctx); raise notice 'RESULT|T7 prix < 500 refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|T7 prix < 500 refusé|PASS|%', sqlerrm; end $$;
reset role;
select 'RESULT|T6b vendeur inchangé (plateforme)|' || case when (select seller_id from listings where id = (select pl from t_ctx)) is null then 'PASS' else 'FAIL' end || '|';
select 'RESULT|T6c mouvement de stock journalisé (ajustement, acteur département)|' || case when exists (select 1 from stock_movements where listing_id = (select pl from t_ctx) and reason = 'ajustement' and actor = :'D1' and stock_after = 40) then 'PASS' else 'FAIL' end || '|';
select 'RESULT|T4b seules les lignes plateforme avancent|' || case when (select string_agg(l.seller_id is null || ':' || ol.fulfillment, ',' order by l.seller_id is null) from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id where o.number = (select num from t_ctx)) = 'false:0,true:1' then 'PASS' else 'FAIL' end
  || '|' || (select string_agg(l.seller_id is null || ':' || ol.fulfillment, ',' order by l.seller_id is null) from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id where o.number = (select num from t_ctx));
select 'RESULT|T4c acheteur notifié|' || case when exists (select 1 from notifications where user_id = :'C1' and kind = 'order' and data->>'order_number' = (select num from t_ctx) and data->>'fulfillment' = '1') then 'PASS' else 'FAIL' end || '|';

-- T8 administrateur : voit aussi les lignes plateforme
select set_config('request.jwt.claims', json_build_object('sub', :'A1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare t int; begin select total into t from seller_orders() where number = (select num from t_ctx);
  raise notice 'RESULT|T8 administrateur voit les lignes plateforme|%|%', case when t = 6000 then 'PASS' else 'FAIL' end, t; end $$;
reset role;

-- T9 support (kiosque) : ne prépare pas les commandes de la plateforme
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from seller_orders() where number = (select num from t_ctx);
  raise notice 'RESULT|T9 support ne voit pas la commande|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
do $$ begin perform set_seller_order_status((select num from t_ctx), 2); raise notice 'RESULT|T9b support refusé (préparation)|FAIL|accepté';
exception when others then raise notice 'RESULT|T9b support refusé (préparation)|PASS|%', sqlerrm; end $$;
reset role;

-- T10 étudiant sans ligne dans la commande : ni lecture ni écriture, ni sur le stock plateforme
select set_config('request.jwt.claims', json_build_object('sub', :'ST', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from seller_orders() where number = (select num from t_ctx);
  raise notice 'RESULT|T10 étudiant tiers ne voit pas la commande|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
do $$ declare b boolean; begin b := is_platform_manager(); raise notice 'RESULT|T10b étudiant non gestionnaire|%|%', case when not b then 'PASS' else 'FAIL' end, b; end $$;
do $$ declare n int; begin update listings set stock = 1 where id = (select pl from t_ctx); get diagnostics n = row_count;
  raise notice 'RESULT|T10c étudiant ne modifie pas le stock plateforme|%|lignes=%', case when n = 0 then 'PASS' else 'FAIL' end, n;
exception when others then raise notice 'RESULT|T10c étudiant ne modifie pas le stock plateforme|PASS|%', sqlerrm; end $$;
reset role;

-- T11 vendeur de la ligne : voit et prépare uniquement sa ligne (non-régression), ne peut pas changer de vendeur
select set_config('request.jwt.claims', json_build_object('sub', :'V1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare t int; begin select total into t from seller_orders() where number = (select num from t_ctx);
  raise notice 'RESULT|T11 vendeur voit sa seule ligne|%|%', case when t = 10000 then 'PASS' else 'FAIL' end, t; end $$;
do $$ declare r int; begin r := set_seller_order_status((select num from t_ctx), 3); raise notice 'RESULT|T11b vendeur marque prête|%|%', case when r = 3 then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T11b vendeur marque prête|FAIL|%', sqlerrm; end $$;
do $$ declare n int; begin update listings set stock = stock + 1 where id = (select vl from t_ctx); get diagnostics n = row_count;
  raise notice 'RESULT|T11c vendeur ajuste son stock|%|lignes=%', case when n = 1 then 'PASS' else 'FAIL' end, n;
exception when others then raise notice 'RESULT|T11c vendeur ajuste son stock|FAIL|%', sqlerrm; end $$;
reset role;
select 'RESULT|T11d lignes : plateforme 1, vendeur 3|' || case when (select string_agg(l.seller_id is null || ':' || ol.fulfillment, ',' order by l.seller_id is null) from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id where o.number = (select num from t_ctx)) = 'false:3,true:1' then 'PASS' else 'FAIL' end || '|';

-- T12 anonyme : aucune fonction exécutable
select set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
do $$ begin perform seller_orders(); raise notice 'RESULT|T12 anonyme refusé (commandes)|FAIL|accepté';
exception when others then raise notice 'RESULT|T12 anonyme refusé (commandes)|PASS|%', sqlerrm; end $$;
do $$ begin perform is_platform_manager(); raise notice 'RESULT|T12b anonyme refusé (gestionnaire)|FAIL|accepté';
exception when others then raise notice 'RESULT|T12b anonyme refusé (gestionnaire)|PASS|%', sqlerrm; end $$;
reset role;

-- T13 retrait au kiosque d'une commande plateforme (non-régression 31c) : code délivré à l'acheteur, remise par le support
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare c text; begin c := my_pickup_code((select num from t_ctx)); update t_ctx set vstock = c::int;
  raise notice 'RESULT|T13 code de retrait délivré|%|6 chiffres=%', case when c ~ '^[0-9]{6}$' then 'PASS' else 'FAIL' end, c ~ '^[0-9]{6}$';
exception when others then raise notice 'RESULT|T13 code de retrait délivré|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := confirm_pickup((select num from t_ctx), lpad((select vstock from t_ctx)::text, 6, '0'));
  raise notice 'RESULT|T13b remise au kiosque|%|%', case when r = 'delivered' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|T13b remise au kiosque|FAIL|%', sqlerrm; end $$;
reset role;
rollback;
select 'RESULT|T14 réplique inchangée après ROLLBACK|' || case when (select count(*) from pg_proc where proname = 'is_platform_manager') = 0
  and (select stock from listings where title = 'Confiture artisanale' and seller_id is null) = 99
  and (select stock from listings where title = 'zz-test-msg-77b4b8') = 9
  and not exists (select 1 from stock_movements where created_at > now() - interval '2 minutes') then 'PASS' else 'FAIL' end || '|';
