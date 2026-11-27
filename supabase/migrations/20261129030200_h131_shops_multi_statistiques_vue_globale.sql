-- H13.1 · Multi-boutiques (3/3) : statistiques PAR boutique, liste « Mes boutiques » avec compteurs réels, vue globale du propriétaire.
--  · shop_dashboard / seller_overview / seller_advanced_stats : p_shop optionnel (lecture « viewer » minimum) ; sans p_shop, la boutique ACTIVE ; sans aucune boutique, tout le vendeur (comme avant).
--    Les ventes comptent d'après la boutique figée sur la ligne de commande (order_lines.shop_id) : déplacer une annonce ne déplace pas son historique.
--  · my_shops() : boutiques du compte (propriétaire ou membre) avec compteurs réels ; my_shops_overview() : vue agrégée du propriétaire (jamais une boutique d'un autre).
-- Strictement additive. Retour arrière : voir la fin du fichier.

create or replace function _sc_line(p_ol_shop uuid, p_l_shop uuid, p_l_seller uuid, p_shop uuid, p_owner uuid) returns boolean
language sql immutable as $$
  select case when p_shop is not null then coalesce(p_ol_shop, p_l_shop) = p_shop else p_l_seller = p_owner end
$$;
create or replace function _sc_listing(p_l_shop uuid, p_l_seller uuid, p_shop uuid, p_owner uuid) returns boolean
language sql immutable as $$
  select case when p_shop is not null then p_l_shop = p_shop else p_l_seller = p_owner end
$$;
revoke all on function _sc_line(uuid, uuid, uuid, uuid, uuid), _sc_listing(uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- 1. Tableau de bord de la boutique --------------------------------------------------------------------------------------------------------
drop function if exists shop_dashboard(integer);
create or replace function shop_dashboard(p_days integer default 30, p_shop uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_days int := least(greatest(coalesce(p_days, 30), 1), 365); v_shop uuid; v_owner uuid; v_rev int; v_orders int; v_views int; v_start date;
begin
  select scope_shop, scope_owner into v_shop, v_owner from _shop_scope(p_shop, 'viewer');
  v_start := current_date - (v_days - 1);
  select coalesce(sum(ol.unit_price * ol.qty), 0)::int, count(distinct o.id)::int into v_rev, v_orders
    from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
    where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at >= v_start;
  select coalesce(sum(v.views), 0)::int into v_views from listing_views v join listings l on l.id = v.listing_id
    where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and v.day >= v_start;
  return jsonb_build_object('days', v_days, 'shop_id', v_shop, 'revenue', v_rev, 'orders', v_orders, 'views', v_views,
    'shop_views', coalesce((select sum(views) from shop_views where shop_id = v_shop and day >= v_start), 0),
    'followers', (select count(*)::int from shop_follows where shop_id = v_shop),
    'conversion', case when v_views > 0 then round(v_orders * 100.0 / v_views, 1) else null end,
    'pending_orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and ol.fulfillment < 4),
    'top', (select coalesce(jsonb_agg(t order by (t->>'revenue')::int desc), '[]'::jsonb) from (
              select jsonb_build_object('title', ol.title, 'qty', sum(ol.qty)::int, 'revenue', sum(ol.unit_price * ol.qty)::int) t
              from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at >= v_start group by ol.title order by sum(ol.unit_price * ol.qty) desc limit 5) x),
    'series', (select jsonb_agg(jsonb_build_object('day', d::date,
                 'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                                       where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at::date = d::date), 0)::int,
                 'views', coalesce((select sum(v.views) from listing_views v join listings l on l.id = v.listing_id
                                     where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and v.day = d::date), 0)::int) order by d)
               from generate_series(v_start, current_date, interval '1 day') d));
end $$;

-- 2. Aperçu vendeur (tableau de bord 57 et studio) -------------------------------------------------------------------------------------------
drop function if exists seller_overview(integer);
create or replace function seller_overview(p_days integer default 30, p_shop uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_days int := least(greatest(coalesce(p_days, 30), 1), 365); v_start date := current_date - (least(greatest(coalesce(p_days, 30), 1), 365) - 1);
        v_shop uuid; v_owner uuid;
begin
  select scope_shop, scope_owner into v_shop, v_owner from _shop_scope(p_shop, 'viewer');
  return jsonb_build_object(
    'days', v_days, 'shop_id', v_shop,
    'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                          where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at::date >= v_start), 0)::int,
    'orders', coalesce((select count(distinct o.id) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                         where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at::date >= v_start), 0)::int,
    'units', coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at::date >= v_start), 0)::int,
    'pending_orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and ol.fulfillment < 4),
    'views', coalesce((select sum(v.views) from listing_views v join listings l on l.id = v.listing_id where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and v.day >= v_start), 0)::int,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and l.status <> 'removed'),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and l.status <> 'removed'),
    'listings', jsonb_build_object(
      'approved', (select count(*)::int from listings l where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and status = 'approved'),
      'pending', (select count(*)::int from listings l where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and status = 'pending'),
      'draft', (select count(*)::int from listings l where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and status = 'draft'),
      'rejected', (select count(*)::int from listings l where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and status = 'rejected')),
    'months', coalesce((select jsonb_agg(jsonb_build_object('month', to_char(m, 'YYYY-MM'),
                 'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                                       where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and date_trunc('month', o.created_at) = m), 0)::int) order by m)
               from generate_series(date_trunc('month', now()) - interval '5 months', date_trunc('month', now()), interval '1 month') m), '[]'::jsonb),
    'products', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'price', l.price, 'stock', l.stock, 'status', l.status, 'category', l.category, 'shop_id', l.shop_id,
                 'units', coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id
                                     where ol.listing_id = l.id and _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null), 0)::int,
                 'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id
                                       where ol.listing_id = l.id and _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null), 0)::int)
                 order by l.created_at desc)
               from (select * from listings x where _sc_listing(x.shop_id, x.seller_id, v_shop, v_owner) and x.status <> 'removed' order by x.created_at desc limit 50) l), '[]'::jsonb));
end $$;

-- 3. Statistiques avancées (forfait du propriétaire) -----------------------------------------------------------------------------------------
drop function if exists seller_advanced_stats(integer);
create or replace function seller_advanced_stats(p_days integer default 30, p_shop uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_days integer := coalesce(p_days, 30); v_start date; v_plans text; v_shop uuid; v_owner uuid;
begin
  select scope_shop, scope_owner into v_shop, v_owner from _shop_scope(p_shop, 'viewer');
  if v_days not in (30, 90) then raise exception 'Période : 30 ou 90 jours'; end if;
  if not feature_granted(v_owner, 'stats_avancees') then
    select string_agg(name, ' ou ' order by name) into v_plans from plans where 'stats_avancees' = any(features) and active and sellable;
    raise exception 'Réservé au forfait %', coalesce(v_plans, 'Vendeur professionnel');
  end if;
  v_start := current_date - (v_days - 1);
  return jsonb_build_object(
    'days', v_days,
    'since', v_start,
    'shop_id', v_shop,
    'products', coalesce((select jsonb_agg(x order by (x->>'revenue')::bigint desc, (x->>'views')::bigint desc, x->>'title') from (
      select jsonb_build_object('id', l.id, 'title', l.title, 'status', l.status,
        'views', coalesce(v.n, 0), 'favorites', coalesce(f.n, 0), 'units', coalesce(s.units, 0), 'orders', coalesce(s.orders, 0), 'revenue', coalesce(s.revenue, 0),
        'conversion', case when coalesce(v.n, 0) > 0 then least(100, round(coalesce(s.orders, 0) * 100.0 / v.n, 1)) else null end) x
      from listings l
      left join lateral (select sum(lv.views)::bigint n from listing_views lv where lv.listing_id = l.id and lv.day >= v_start) v on true
      left join lateral (select count(*)::bigint n from favorites fv where fv.listing_id = l.id and fv.created_at >= v_start) f on true
      left join lateral (select sum(ol.qty)::bigint units, count(distinct o.id)::bigint orders, sum(ol.unit_price::bigint * ol.qty)::bigint revenue
                         from order_lines ol join orders o on o.id = ol.order_id
                         where ol.listing_id = l.id and _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at >= v_start) s on true
      where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner)
      order by coalesce(s.revenue, 0) desc, coalesce(v.n, 0) desc, l.title
      limit 200) q), '[]'::jsonb),
    'series', coalesce((select jsonb_agg(jsonb_build_object('day', d::date,
        'views', coalesce((select sum(lv.views) from listing_views lv join listings l on l.id = lv.listing_id where _sc_listing(l.shop_id, l.seller_id, v_shop, v_owner) and lv.day = d::date), 0)::int,
        'units', coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                           where _sc_line(ol.shop_id, l.shop_id, l.seller_id, v_shop, v_owner) and o.paid and o.cancelled_at is null and o.created_at::date = d::date), 0)::int) order by d)
      from generate_series(v_start, current_date, interval '1 day') d), '[]'::jsonb));
end $$;

-- 4. Mes boutiques : fiche et compteurs réels d'une boutique ----------------------------------------------------------------------------------
create or replace function _shop_card(p_shop uuid, p_uid uuid, p_active uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', s.id, 'slug', s.slug, 'name', s.name, 'logo_url', s.logo_url, 'banner_url', s.banner_url, 'color_primary', s.color_primary, 'color_secondary', s.color_secondary,
    'status', s.status, 'role', _shop_role(s.id, p_uid), 'is_active', s.id = p_active, 'owner_id', s.owner_id, 'created_at', s.created_at,
    'listings', jsonb_build_object(
      'approved', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'approved'),
      'pending', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'pending'),
      'draft', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'draft'),
      'rejected', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'rejected')),
    'stock_units', coalesce((select sum(l.stock)::int from listings l where l.shop_id = s.id and l.status = 'approved' and l.category <> 'Services'), 0),
    'out_of_stock', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'approved' and l.category <> 'Services' and l.stock = 0),
    'pending_orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where coalesce(ol.shop_id, l.shop_id) = s.id and (o.paid or o.cod) and o.cancelled_at is null and not o.cancelled and ol.fulfillment < 4),
    'orders_30d', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                    where coalesce(ol.shop_id, l.shop_id) = s.id and o.paid and o.cancelled_at is null and o.created_at >= now() - interval '30 days'),
    'revenue_30d', coalesce((select sum(ol.unit_price::bigint * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                              where coalesce(ol.shop_id, l.shop_id) = s.id and o.paid and o.cancelled_at is null and o.created_at >= now() - interval '30 days'), 0)::bigint,
    'followers', (select count(*)::int from shop_follows f where f.shop_id = s.id),
    'active_promos', (select count(*)::int from promo_codes c where c.shop_id = s.id and c.active and (c.ends_at is null or c.ends_at > now()))
                     + (select count(*)::int from flash_sales f where f.shop_id = s.id and not f.cancelled and f.ends_at > now())
                     + (select count(*)::int from shop_campaigns k where k.shop_id = s.id and k.active and (k.ends_at is null or k.ends_at > now())),
    'members', case when s.owner_id = p_uid then (select count(*)::int from shop_members m where m.shop_id = s.id) end)
  from shops s where s.id = p_shop
$$;
revoke all on function _shop_card(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function my_shops() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_active uuid;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  v_active := _shop_active_id(uid);
  return coalesce((select jsonb_agg(_shop_card(s.id, uid, v_active) order by s.created_at, s.id) from shops s where _shop_rank(_shop_role(s.id, uid)) >= 1), '[]'::jsonb);
end $$;

-- Vue globale du propriétaire : uniquement SES boutiques ; totaux = somme des compteurs réels de chaque boutique.
create or replace function my_shops_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_active uuid; v_cards jsonb; v_max integer := shops_max_per_owner(); v_open integer; v_reason text;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  v_active := _shop_active_id(uid);
  select coalesce(jsonb_agg(_shop_card(s.id, uid, v_active) order by s.created_at, s.id), '[]'::jsonb) into v_cards from shops s where s.owner_id = uid;
  select count(*)::int into v_open from shops where owner_id = uid and status <> 'closed';
  v_reason := _seller_block_reason(uid, false);
  if v_reason is null and v_open >= v_max then v_reason := 'Limite atteinte : ' || v_max || ' boutique(s) au maximum par compte'; end if;
  return jsonb_build_object(
    'active_shop_id', v_active, 'max', v_max, 'owned', v_open, 'can_create', v_reason is null, 'create_blocked_reason', v_reason,
    'totals', jsonb_build_object(
      'shops', jsonb_array_length(v_cards),
      'revenue_30d', coalesce((select sum((c->>'revenue_30d')::bigint) from jsonb_array_elements(v_cards) c), 0),
      'orders_30d', coalesce((select sum((c->>'orders_30d')::int) from jsonb_array_elements(v_cards) c), 0),
      'pending_orders', coalesce((select sum((c->>'pending_orders')::int) from jsonb_array_elements(v_cards) c), 0),
      'listings_approved', coalesce((select sum((c->'listings'->>'approved')::int) from jsonb_array_elements(v_cards) c), 0),
      'stock_units', coalesce((select sum((c->>'stock_units')::int) from jsonb_array_elements(v_cards) c), 0),
      'followers', coalesce((select sum((c->>'followers')::int) from jsonb_array_elements(v_cards) c), 0)),
    'shops', v_cards);
end $$;

revoke all on function shop_dashboard(integer, uuid), seller_overview(integer, uuid), seller_advanced_stats(integer, uuid), my_shops(), my_shops_overview() from public, anon;
grant execute on function shop_dashboard(integer, uuid), seller_overview(integer, uuid), seller_advanced_stats(integer, uuid), my_shops(), my_shops_overview() to authenticated;

-- Retour arrière : drop function my_shops(), my_shops_overview(), _shop_card(uuid, uuid, uuid), _sc_line(...), _sc_listing(...) ; drop les versions à p_shop de shop_dashboard, seller_overview, seller_advanced_stats
--   puis les recréer depuis 20261107000000 (shop_dashboard), 20261117030000 (seller_overview), 20261116120000 (seller_advanced_stats).
