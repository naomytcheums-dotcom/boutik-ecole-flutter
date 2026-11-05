-- Tests impact et sponsoring sur la base LOCALE isolée (comptes fictifs « Test … »).
create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
create temp table ids (k text, v uuid); grant all on ids to public;
delete from sponsorships where title like 'ZZ test%'; delete from sponsors where name like 'ZZ test%';

set role anon;
do $$ declare j jsonb; begin
  j := platform_impact();
  insert into res values (default, 'I1 un visiteur lit l''impact agrégé', (j->>'orders_paid')::int >= 0 and j ? 'cities', '');
  insert into res values (default, 'I2 aucune donnée personnelle dans l''impact', not (j::text ilike '%@%') and not (j ? 'email'), '');
  begin perform my_impact(); insert into res values (default, 'I3 mon impact exige une connexion', false, 'accepté'); exception when others then insert into res values (default, 'I3 mon impact exige une connexion', sqlerrm like 'permission denied%' or sqlerrm = 'Connexion requise', sqlerrm); end;
end $$;
reset role;

-- l'impact calculé suit les chiffres réels
insert into res(test, ok, detail) select 'I4 les chiffres égalent les tables', (j->>'orders_paid')::int = (select count(*) from orders where paid and cancelled_at is null) and (j->>'revenue_paid')::bigint = (select coalesce(sum(subtotal), 0) from orders where paid and cancelled_at is null) and (j->>'missions_delivered')::int = (select count(*) from missions where status = 'delivered'), '' from (select platform_impact() j) x;

-- poids de matériaux récupérés : calculé seulement sur ce que le vendeur a déclaré
do $$ declare l uuid; begin
  select ol.listing_id into l from order_lines ol join orders o on o.id = ol.order_id where o.paid and o.cancelled_at is null and ol.listing_id is not null limit 1;
  create temp table if not exists keep (id uuid, kg numeric); grant all on keep to public;
  insert into keep select id, recycled_kg from listings where id = l;
  update listings set recycled_kg = 2.5 where id = l;
  insert into ids values ('listing', l);
end $$;
insert into res(test, ok, detail) select 'I5 le poids déclaré est compté', (platform_impact()->>'recycled_kg')::numeric >= 2.5, platform_impact()->>'recycled_kg';
update listings set recycled_kg = (select kg from keep limit 1) where id = (select v from ids where k = 'listing');

-- sponsoring : la gestion crée, le propriétaire lit, un autre compte est refusé
select set_config('request.jwt.claims', json_build_object('sub', 'c8332c75-ae70-4685-8589-d6ab77667e16', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare s uuid; begin
  s := sponsor_create('ZZ test sponsor', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab');
  perform sponsorship_add(s, 'ZZ test projet', 'Informatique', 500000, 4, 'Prototype livré', 'termine', 2026);
  perform sponsorship_add(s, 'ZZ test projet 2', null, 250000, 2, null, 'en_cours', 2026);
  insert into ids values ('sponsor', s);
  insert into res values (default, 'S1 la gestion saisit un sponsoring', (sponsor_report(s)->>'total')::bigint = 750000 and (sponsor_report(s)->>'students')::int = 6, '');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  insert into res values (default, 'S2 le sponsor lit son rapport', jsonb_array_length(sponsor_report((select v from ids where k = 'sponsor'))->'projects') = 2, '');
  begin perform sponsorship_add((select v from ids where k = 'sponsor'), 'ZZ test pirate', null, 1, 1, null); insert into res values (default, 'S3 un sponsor ne saisit pas', false, 'accepté'); exception when others then insert into res values (default, 'S3 un sponsor ne saisit pas', sqlerrm = 'Action non autorisée', sqlerrm); end;
  insert into res values (default, 'I6 mon impact : un compte connecté lit le sien', my_impact() ? 'purchases', '');
end $$;
reset role;
select set_config('request.jwt.claims', json_build_object('sub', 'c4dcc973-7b3a-40e8-ac60-c63abb47c6c4', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ begin
  begin perform sponsor_report((select v from ids where k = 'sponsor')); insert into res values (default, 'S4 un autre compte ne lit pas le rapport', false, 'accepté'); exception when others then insert into res values (default, 'S4 un autre compte ne lit pas le rapport', sqlerrm = 'Action non autorisée', sqlerrm); end;
end $$;
reset role;

-- créations des autres établissements : celles du propre établissement sont exclues
update profiles set institution = 'ZZ test établissement A' where id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab';
update profiles set institution = 'ZZ test établissement B' where id in (select seller_id from listings where status = 'approved' and seller_id is not null and seller_id <> 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab' limit 1);
select set_config('request.jwt.claims', json_build_object('sub', 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab', 'role', 'authenticated')::text, false);
set role authenticated;
do $$ declare j jsonb; begin
  j := listings_other_institutions(50);
  insert into res values (default, 'O1 les créations d''un autre établissement sont listées', exists (select 1 from jsonb_array_elements(j) e where e->>'institution' = 'ZZ test établissement B'), '');
  insert into res values (default, 'O2 son propre établissement est exclu', not exists (select 1 from jsonb_array_elements(j) e where e->>'institution' = 'ZZ test établissement A'), '');
end $$;
reset role;
update profiles set institution = '' where institution like 'ZZ test%';
delete from sponsorships where title like 'ZZ test%'; delete from sponsors where name like 'ZZ test%';
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
