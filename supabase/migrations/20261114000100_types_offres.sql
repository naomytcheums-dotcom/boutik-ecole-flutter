-- Marketplace : 4 types d'offres (produit physique, solution technique ou numérique, service ou expertise, projet à vendre ou licence).
-- Le type se déduit de la catégorie de l'annonce : aucune donnée existante n'est modifiée.
-- Retour arrière : drop function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text); drop function offer_type_of(text);
--                   puis recréer marketplace_search et _listing_card depuis 20261107000000_marketplace.sql.

create or replace function offer_type_of(p_category text) returns text
language sql immutable as $$
  select case lower(coalesce(p_category, ''))
    when 'services' then 'service'
    when 'solutions numériques' then 'tech'
    when 'projets et licences' then 'project'
    else 'product' end
$$;

create or replace function _listing_card(l listings) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', l.id, 'title', l.title, 'price', l.price, 'price_before', l.price_before, 'category', l.category, 'stock', l.stock,
    'offer_type', offer_type_of(l.category),
    'image', coalesce(l.images[1], l.image_url), 'created_at', l.created_at,
    'shop_id', l.shop_id, 'shop_name', s.name, 'shop_slug', s.slug, 'city', coalesce(s.city, sp.city),
    'flash_price', f.sale_price, 'flash_ends', f.ends_at, 'flash_left', f.stock - f.sold,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r where r.listing_id = l.id),
    'rating_count', (select count(*)::int from reviews r where r.listing_id = l.id),
    'sales', coalesce((select sum(ol.qty)::int from order_lines ol join orders o on o.id = ol.order_id where ol.listing_id = l.id and o.paid and o.cancelled_at is null), 0),
    'favs', (select count(*)::int from favorites fv where fv.listing_id = l.id))
  from (select 1) x
  left join shops s on s.id = l.shop_id
  left join profiles sp on sp.id = l.seller_id
  left join lateral (select * from flash_sales fs where fs.listing_id = l.id and not fs.cancelled and fs.starts_at <= now() and fs.ends_at > now() and fs.sold < fs.stock order by fs.sale_price limit 1) f on true
$$;
revoke all on function _listing_card(listings) from public, anon, authenticated;

drop function if exists marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer);
create or replace function marketplace_search(p_q text default null, p_category text default null, p_city text default null, p_min integer default null, p_max integer default null,
  p_sort text default 'popular', p_shop uuid default null, p_limit integer default 24, p_offset integer default 0, p_offer_type text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_q text := nullif(trim(coalesce(p_q, '')), ''); v_t text := nullif(trim(coalesce(p_offer_type, '')), ''); r jsonb;
begin
  select coalesce(jsonb_agg(c order by
      case p_sort when 'price_asc' then (c->>'price')::numeric end asc nulls last,
      case p_sort when 'price_desc' then (c->>'price')::numeric end desc nulls last,
      case p_sort when 'recent' then c->>'created_at' end desc nulls last,
      case p_sort when 'rating' then coalesce((c->>'rating_avg')::numeric, 0) end desc nulls last,
      ((c->>'sales')::int * 3 + (c->>'favs')::int) desc, c->>'created_at' desc), '[]'::jsonb)
  into r from (
    select _listing_card(l) c from listings l
    left join shops s on s.id = l.shop_id
    left join profiles sp on sp.id = l.seller_id
    where l.status = 'approved' and (l.shop_id is null or s.status = 'active')
      and (case
             when v_t is not null then offer_type_of(l.category) = v_t and (p_category is null or p_category = '' or lower(l.category) = lower(p_category))
             when p_category is null or p_category = '' then true
             else lower(l.category) = lower(p_category) end)
      and (v_q is null or l.title ilike '%' || v_q || '%' or coalesce(l.description, '') ilike '%' || v_q || '%' or coalesce(s.name, '') ilike '%' || v_q || '%')
      and (p_city is null or p_city = '' or lower(coalesce(s.city, sp.city, '')) = lower(p_city))
      and (p_min is null or l.price >= p_min) and (p_max is null or l.price <= p_max)
      and (p_shop is null or l.shop_id = p_shop)
    limit least(greatest(coalesce(p_limit, 24), 1), 100) offset greatest(coalesce(p_offset, 0), 0)
  ) q;
  return r;
end $$;
revoke all on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text) from public;
grant execute on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text), offer_type_of(text) to anon, authenticated;
