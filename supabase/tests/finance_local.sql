-- Tests de la finance sur la base LOCALE isolée (comptes fictifs « Test … »).
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
delete from payout_batches where seller_id in (select id from profiles where name like 'Test%') and method = 'ZZ test';
create temp table ids (k text, v uuid); grant all on ids to public;
create temp table s (o jsonb, j jsonb, d jsonb); grant all on s to public;

set role anon;
do $$ begin begin perform finance_overview(); insert into res values (default, 'F1 un visiteur est refusé', false, 'accepté'); exception when others then insert into res values (default, 'F1 un visiteur est refusé', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end; end $$;
reset role;

select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform finance_payments(null, 5); insert into res values (default, 'F2 un étudiant ne lit pas les paiements', false, 'accepté'); exception when others then insert into res values (default, 'F2 un étudiant ne lit pas les paiements', sqlerrm = 'Action non autorisée', sqlerrm); end;
  begin perform payout_create('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 1000, 'ZZ test', current_date); insert into res values (default, 'F3 un étudiant ne crée pas de lot', false, 'accepté'); exception when others then insert into res values (default, 'F3 un étudiant ne crée pas de lot', sqlerrm = 'Action non autorisée', sqlerrm); end;
end $$;
reset role;

-- l'administrateur lit ; les chiffres égalent les commandes
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
insert into s select finance_overview(), finance_journal(300), finance_by_department();
reset role;
insert into res(test, ok, detail) select 'F4 l''encaissé égale les commandes payées', (o->>'collected')::bigint = (select coalesce(sum(subtotal + fee), 0) from orders where paid and cancelled_at is null) and (o->>'orders_paid')::int = (select count(*) from orders where paid and cancelled_at is null), o->>'collected' from s;
insert into res(test, ok, detail) select 'F5 le total des crédits du journal égale l''encaissé et les commissions', (j->>'total_credit')::bigint = (select coalesce(sum(subtotal + fee), 0) + coalesce(sum(fee) filter (where fee > 0), 0) from orders where paid and cancelled_at is null), j->>'total_credit' from s;
insert into res(test, ok, detail) select 'F6 les ventes par département totalisent les ventes des vendeurs', (select coalesce(sum((e->>'sales')::bigint), 0) from s, jsonb_array_elements(s.d) e) = (select coalesce(sum(ol.unit_price * ol.qty), 0) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id where o.paid and o.cancelled_at is null and l.seller_id is not null), '' from s;

-- lots de reversement : création par la finance, passage à « versé », effet sur le journal et la vue d'ensemble
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare b uuid; begin
  b := payout_create('a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 25000, 'ZZ test', current_date);
  insert into ids values ('lot', b);
  insert into res values (default, 'F7 un lot prévu compte dans les montants dus', (finance_overview()->>'due')::bigint >= 25000, '');
  perform payout_set_status(b, 'verse');
  insert into res values (default, 'F8 un lot versé compte dans le versé sur 30 jours et débite le journal', (finance_overview()->>'paid_out_30d')::bigint >= 25000 and (finance_journal(300)->>'total_debit')::bigint >= 25000, '');
  insert into res values (default, 'F9 le lot apparaît avec le nom du vendeur', exists (select 1 from jsonb_array_elements(finance_payouts(50)) e where e->>'method' = 'ZZ test' and e->>'status' = 'verse'), '');
  begin perform payout_set_status(b, 'inconnu'); insert into res values (default, 'F10 statut invalide refusé', false, 'accepté'); exception when others then insert into res values (default, 'F10 statut invalide refusé', sqlerrm = 'Statut invalide', sqlerrm); end;
end $$;
reset role;
delete from payout_batches where method = 'ZZ test';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
