create temp table res (n serial, test text, ok boolean, detail text);
grant all on res to public; grant usage on sequence res_n_seq to public;
create temp table nm as select name from profiles where id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'; grant all on nm to public;
set role anon;
do $$ declare j jsonb; n text; begin
  select name into n from nm;
  j := seller_public(n);
  insert into res values (default, 'V1 un visiteur lit le profil public', (j->>'found')::boolean, coalesce(j->>'name', ''));
  insert into res values (default, 'V2 aucune donnée privée exposée', not (j ? 'email') and not (j ? 'phone') and not (j ? 'city'), '');
  insert into res values (default, 'V3 vendeur inconnu : found = false', (seller_public('Personne Inexistante ZZ')->>'found')::boolean = false, '');
end $$;
reset role;
do $$ declare j jsonb; n text; exp int; begin
  select name into n from profiles where id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab';
  j := seller_public(n);
  select count(*) into exp from listings where seller_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab' and status = 'approved' and category <> 'Services';
  insert into res values (default, 'V4 le nombre de produits égale les annonces approuvées', (j->>'products')::int = exp, exp::text);
  insert into res values (default, 'V5 les notes sont cohérentes', (j->>'rating_count')::int = (select count(*) from reviews r join listings l on l.id = r.listing_id where l.seller_id = 'a7ae1021-2bc7-437b-b7af-bd7d6422c5ab'), '');
end $$;
select n, case when ok then 'PASS' else 'FAIL' end resultat, test, left(detail, 80) detail from res order by n;
select count(*) filter (where ok) reussis, count(*) filter (where not ok) echoues from res;
