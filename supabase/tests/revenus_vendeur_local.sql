create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
set role anon;
do $$ begin begin perform seller_revenue(); insert into res values (default, 'R1 visiteur refusé', false, 'accepté'); exception when others then insert into res values (default, 'R1 visiteur refusé', true, sqlerrm); end; end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare j jsonb; exp bigint; begin
  j := seller_revenue();
  select coalesce(sum(ol.unit_price * ol.qty), 0) into exp from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id where l.seller_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab' and o.paid and o.cancelled_at is null;
  insert into res values (default, 'R2 le total égale les ventes payées du vendeur', (j->>'total')::bigint = exp, exp::text);
  insert into res values (default, 'R3 disponible = total - versé - prévu', (j->>'available')::bigint = greatest((j->>'total')::bigint - (j->>'paid_out')::bigint - (j->>'scheduled')::bigint, 0), '');
  insert into res values (default, 'R4 séries mensuelle et hebdomadaire sont des listes', jsonb_typeof(j->'months') = 'array' and jsonb_typeof(j->'weeks') = 'array', '');
end $$;
reset role;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
