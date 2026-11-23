-- Tests de la migration 20261101000300 (livraison) sur la RÉPLIQUE LOCALE, dans une transaction ANNULÉE.
\set ON_ERROR_STOP on
\set A1 'c8332c75-ae70-4685-8589-d6ab77667e16'
\set C1 '37d0d172-5d38-49e3-ab4a-8175997fe8b2'
\set C2 '41c9e35e-cdee-4c1f-8068-817dccd55867'
\set S1 'fbee9999-a07e-4700-be3f-caf5977b77a5'
begin;
--@@MIGRATION@@--
\set ON_ERROR_STOP off
create temp table t_ctx (k text primary key, v text);
grant select, insert, update on t_ctx to authenticated, anon;
create or replace function pg_temp.v(p text) returns text language sql as $$ select v from t_ctx where k = p $$;

select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
-- L1 non-régression : retrait sur campus par l'ancienne signature
do $$ declare r jsonb; begin r := create_order('[{"title":"Jus de bissap","qty":1}]'::jsonb, false, 'Orange Money');
  raise notice 'RESULT|L1 retrait sur campus (ancienne signature)|%|%', case when (r->>'fee')::int = 0 then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|L1 retrait sur campus (ancienne signature)|FAIL|%', sqlerrm; end $$;
-- L2 domicile désactivé par défaut : refusé, sans frais
do $$ begin perform create_order('[{"title":"Jus de bissap","qty":1}]'::jsonb, true, 'Orange Money'); raise notice 'RESULT|L2 domicile désactivé refusé|FAIL|accepté';
exception when others then raise notice 'RESULT|L2 domicile désactivé refusé|PASS|%', sqlerrm; end $$;
-- L3 un client n'active pas la livraison
do $$ begin perform set_home_delivery(true, 'Douala', 5000); raise notice 'RESULT|L3 client ne règle pas la livraison|FAIL|accepté';
exception when others then raise notice 'RESULT|L3 client ne règle pas la livraison|PASS|%', sqlerrm; end $$;
-- L4 carnet : 5 adresses au plus
do $$ begin perform save_address(null, 'X', 'abc', 'Douala', '', 'R', ''); raise notice 'RESULT|L4c adresse invalide refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|L4c adresse invalide refusée|PASS|%', sqlerrm; end $$;
do $$ declare a uuid; i int; begin
  for i in 1..5 loop a := save_address(null, 'Mariam Essono', '+237 690 00 00 0' || i, 'Douala', 'Ndokoti', 'Rue de l''IUT ' || i, 'Bibliothèque'); end loop;
  insert into t_ctx values ('adr', a::text);
  raise notice 'RESULT|L4 cinq adresses enregistrées|PASS|'; exception when others then raise notice 'RESULT|L4 cinq adresses enregistrées|FAIL|%', sqlerrm; end $$;
do $$ begin perform save_address(null, 'Mariam Essono', '+237 690000006', 'Douala', '', 'Rue 6', ''); raise notice 'RESULT|L4b sixième adresse refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|L4b sixième adresse refusée|PASS|%', sqlerrm; end $$;
reset role;
-- L5 un autre compte ne voit ni n'utilise l'adresse
select set_config('request.jwt.claims', json_build_object('sub', :'C2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare n int; begin select count(*) into n from addresses; raise notice 'RESULT|L5 adresses d''autrui invisibles|%|%', case when n = 0 then 'PASS' else 'FAIL' end, n; end $$;
reset role;
-- L3b l'administrateur active la livraison à Douala
select set_config('request.jwt.claims', json_build_object('sub', :'A1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := set_home_delivery(true, 'Douala', 5000); raise notice 'RESULT|L3b administrateur active la livraison|%|%', case when r = 'enabled' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|L3b administrateur active la livraison|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'C2', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform create_order('[{"title":"Jus de bissap","qty":1}]'::jsonb, true, 'Orange Money', pg_temp.v('adr')::uuid); raise notice 'RESULT|L5b adresse d''autrui refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|L5b adresse d''autrui refusée|PASS|%', sqlerrm; end $$;
reset role;
-- L6 commande livrée à domicile : frais du réglage, adresse figée
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r jsonb; begin r := create_order('[{"title":"Confiture artisanale","qty":2}]'::jsonb, true, 'Orange Money', pg_temp.v('adr')::uuid); insert into t_ctx values ('num', r->>'number');
  raise notice 'RESULT|L6 commande à domicile (frais 5 000)|%|%', case when (r->>'fee')::int = 5000 then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|L6 commande à domicile (frais 5 000)|FAIL|%', sqlerrm; end $$;
do $$ declare a uuid; begin a := save_address(pg_temp.v('adr')::uuid, 'Mariam Essono', '+237 690000005', 'Yaoundé', 'Bastos', 'Rue 5', ''); 
  perform create_order('[{"title":"Jus de bissap","qty":1}]'::jsonb, true, 'Orange Money', a); raise notice 'RESULT|L7 ville non desservie refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|L7 ville non desservie refusée|PASS|%', sqlerrm; end $$;
reset role;
select 'RESULT|L6b adresse figée sur la commande (Douala, même après modification du carnet)|' || case when (select delivery_address->>'city' from orders where number = (select v from t_ctx where k = 'num')) = 'Douala'
  and (select home_delivery from orders where number = (select v from t_ctx where k = 'num')) then 'PASS' else 'FAIL' end || '|';
-- L8 départ en livraison : seulement commande payée et prête, par la logistique
update orders set paid = true where number = (select v from t_ctx where k = 'num');
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform start_delivery(pg_temp.v('num')); raise notice 'RESULT|L8 départ refusé tant que non prête|FAIL|accepté';
exception when others then raise notice 'RESULT|L8 départ refusé tant que non prête|PASS|%', sqlerrm; end $$;
reset role;
update order_lines set fulfillment = 3 where order_id = (select id from orders where number = (select v from t_ctx where k = 'num'));
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ begin perform start_delivery(pg_temp.v('num')); raise notice 'RESULT|L8b client ne déclenche pas la livraison|FAIL|accepté';
exception when others then raise notice 'RESULT|L8b client ne déclenche pas la livraison|PASS|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; n int; begin r := start_delivery(pg_temp.v('num')); select count(*) into n from orders where number = pg_temp.v('num') and delivery_address is not null;
  raise notice 'RESULT|L8c logistique lance la livraison et lit l''adresse|%|% adresse=%', case when r = 'out_for_delivery' and n = 1 then 'PASS' else 'FAIL' end, r, n;
exception when others then raise notice 'RESULT|L8c logistique lance la livraison et lit l''adresse|FAIL|%', sqlerrm; end $$;
-- L9 échecs : motif obligatoire ; 1er échec reporté ; 2e échec → retour au kiosque
do $$ begin perform delivery_failed(pg_temp.v('num'), ''); raise notice 'RESULT|L9 motif obligatoire|FAIL|accepté';
exception when others then raise notice 'RESULT|L9 motif obligatoire|PASS|%', sqlerrm; end $$;
do $$ declare r1 text; r2 text; begin r1 := delivery_failed(pg_temp.v('num'), 'Destinataire absent'); perform start_delivery(pg_temp.v('num')); r2 := delivery_failed(pg_temp.v('num'), 'Destinataire absent');
  raise notice 'RESULT|L9b report puis retour au kiosque|%|% puis %', case when r1 = 'rescheduled' and r2 = 'returned_to_kiosk' then 'PASS' else 'FAIL' end, r1, r2;
exception when others then raise notice 'RESULT|L9b report puis retour au kiosque|FAIL|%', sqlerrm; end $$;
reset role;
-- L10 non-régression 31c : remise au kiosque par le code à 6 chiffres
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare c text; begin c := my_pickup_code(pg_temp.v('num')); insert into t_ctx values ('code', c); raise notice 'RESULT|L10 code de retrait délivré|PASS|'; 
exception when others then raise notice 'RESULT|L10 code de retrait délivré|FAIL|%', sqlerrm; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', :'S1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := confirm_pickup(pg_temp.v('num'), pg_temp.v('code')); raise notice 'RESULT|L10b remise confirmée par le code|%|%', case when r = 'delivered' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|L10b remise confirmée par le code|FAIL|%', sqlerrm; end $$;
reset role;
-- L11 suppression d'une adresse
select set_config('request.jwt.claims', json_build_object('sub', :'C1', 'role', 'authenticated')::text, true); set local role authenticated;
do $$ declare r text; begin r := delete_address(pg_temp.v('adr')::uuid); raise notice 'RESULT|L11 adresse supprimée|%|%', case when r = 'deleted' then 'PASS' else 'FAIL' end, r;
exception when others then raise notice 'RESULT|L11 adresse supprimée|FAIL|%', sqlerrm; end $$;
do $$ begin insert into addresses (user_id, recipient, phone, city, line) values (auth.uid(), 'Direct', '+237690000000', 'Douala', 'Rue directe'); raise notice 'RESULT|L12 écriture directe refusée|FAIL|accepté';
exception when others then raise notice 'RESULT|L12 écriture directe refusée|PASS|%', sqlerrm; end $$;
reset role;
rollback;
select 'RESULT|L13 réplique inchangée après ROLLBACK|' || case when to_regclass('public.addresses') is null
  and not exists (select 1 from information_schema.columns where table_name = 'orders' and column_name = 'home_delivery') then 'PASS' else 'FAIL' end || '|';
