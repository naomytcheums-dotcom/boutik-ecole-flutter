-- Lot S5 — économie circulaire et impact : la déclaration « matériaux récupérés » (listings.recycled / recycled_kg, poids PAR ARTICLE) est
-- bornée côté base, compte seulement quand elle est cochée ; « Mon impact » couvre aussi les ventes du vendeur et n'inclut plus ses propres achats ;
-- l'impact par ville ne révèle plus un vendeur isolé (villes de moins de 3 étudiants regroupées sous « Autres villes »).
-- Corrige S5-65 (avec le formulaire vendeur Flutter), S5-66, S5-69, S5-70, S5-71, S5-74. Les colonnes, leurs GRANT et les politiques de listings ne sont pas modifiés.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (etu_s5.mjs).
-- Retour arrière : alter table listings drop constraint if exists listings_recycled_decl_check ;
--   recréer platform_impact() et my_impact() depuis 20261105000100_impact_sponsoring.sql.

-- Le poids n'a de sens que pour un produit déclaré récupéré ; 1 000 kg par article au plus (les lignes existantes ne sont pas revérifiées).
do $$ begin
  alter table listings add constraint listings_recycled_decl_check check (recycled_kg is null or (recycled and recycled_kg <= 1000)) not valid;
exception when duplicate_object then null; end $$;

create or replace function platform_impact() returns jsonb
language sql stable security definer set search_path = public as $$
  with paid as (
    select o.id, o.created_at, o.subtotal, l.seller_id, coalesce(p.city, '') as city, ol.qty, case when l.recycled then l.recycled_kg end as recycled_kg
    from orders o
    join order_lines ol on ol.order_id = o.id
    left join listings l on l.id = ol.listing_id
    left join profiles p on p.id = l.seller_id
    where o.paid and o.cancelled_at is null
  ), by_city as (
    select city, count(distinct id)::int n, count(distinct seller_id)::int s from paid where city <> '' group by city
  )
  select jsonb_build_object(
    'students_paid', (select count(distinct seller_id)::int from paid where seller_id is not null),
    'revenue_paid', (select coalesce(sum(subtotal), 0)::bigint from (select distinct id, subtotal from paid) x),
    'orders_paid', (select count(distinct id)::int from paid),
    'missions_delivered', (select count(*)::int from missions where status = 'delivered'),
    'recycled_kg', (select coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) from paid where recycled_kg is not null),
    'cities', (select coalesce(jsonb_agg(jsonb_build_object('city', c.city, 'orders', c.n, 'students', c.s) order by c.n desc), '[]'::jsonb)
               from (
                 select city, n, s from by_city where s >= 3
                 union all
                 select 'Autres villes', sum(n)::int, sum(s)::int from by_city where s < 3 having sum(s) >= 3
               ) c)
  );
$$;
revoke all on function platform_impact() from public;
grant execute on function platform_impact() to anon, authenticated;

-- Impact de la personne : achats payés auprès d'étudiants (hors ses propres annonces) et, pour un vendeur, ses ventes et les matériaux récupérés qu'elles représentent.
create or replace function my_impact() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return (
    with mine as (
      select o.id, o.created_at, o.subtotal, l.seller_id, ol.qty, case when l.recycled then l.recycled_kg end as recycled_kg
      from orders o join order_lines ol on ol.order_id = o.id left join listings l on l.id = ol.listing_id
      where o.buyer_id = auth.uid() and o.paid and o.cancelled_at is null and l.seller_id is distinct from auth.uid()
    ), sold as (
      select o.id, o.buyer_id, o.created_at, ol.qty, ol.unit_price, case when l.recycled then l.recycled_kg end as recycled_kg
      from orders o join order_lines ol on ol.order_id = o.id join listings l on l.id = ol.listing_id
      where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null
    )
    select jsonb_build_object(
      'purchases', (select count(distinct id)::int from mine),
      'amount', (select coalesce(sum(subtotal), 0)::bigint from (select distinct id, subtotal from mine) x),
      'students_supported', (select count(distinct seller_id)::int from mine where seller_id is not null),
      'recycled_kg', (select coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) from mine where recycled_kg is not null),
      'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'recycled_kg', kg) order by m), '[]'::jsonb)
                 from (select to_char(date_trunc('month', created_at), 'YYYY-MM') m, coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) kg
                       from mine where created_at >= date_trunc('month', now()) - interval '5 months' group by 1) t),
      'seller', jsonb_build_object(
        'listings', (select count(*)::int from listings where seller_id = auth.uid() and status = 'approved'),
        'recycled_listings', (select count(*)::int from listings where seller_id = auth.uid() and status = 'approved' and recycled),
        'orders', (select count(distinct id)::int from sold),
        'sales', (select coalesce(sum(qty * unit_price), 0)::bigint from sold),
        'clients', (select count(distinct buyer_id)::int from sold),
        'recycled_kg', (select coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) from sold where recycled_kg is not null),
        'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'recycled_kg', kg) order by m), '[]'::jsonb)
                   from (select to_char(date_trunc('month', created_at), 'YYYY-MM') m, coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) kg
                         from sold where created_at >= date_trunc('month', now()) - interval '5 months' group by 1) t))
    )
  );
end $$;
revoke all on function my_impact() from public, anon;
grant execute on function my_impact() to authenticated;
