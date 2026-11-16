-- Cartes d'annonces (S10-5) : indique à l'application si l'annonce est celle de la personne connectée (« Votre annonce », pas de favori ni de comparaison
-- sur ses propres créations). Reprend la dernière définition (20261114000200_vendeur_verifie.sql) et ajoute la clé is_mine.
-- Retour arrière : recréer _listing_card depuis 20261114000200_vendeur_verifie.sql.

create or replace function _listing_card(l listings) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', l.id, 'title', l.title, 'price', l.price, 'price_before', l.price_before, 'category', l.category, 'stock', l.stock,
    'offer_type', offer_type_of(l.category),
    'validated', (l.status = 'approved' and l.reviewed_by is not null and l.seller_id is not null),
    'image', coalesce(l.images[1], l.image_url), 'created_at', l.created_at,
    'shop_id', l.shop_id, 'shop_name', s.name, 'shop_slug', s.slug, 'city', coalesce(s.city, sp.city),
    'flash_price', f.sale_price, 'flash_ends', f.ends_at, 'flash_left', f.stock - f.sold,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r where r.listing_id = l.id),
    'rating_count', (select count(*)::int from reviews r where r.listing_id = l.id),
    'sales', coalesce((select sum(ol.qty)::int from order_lines ol join orders o on o.id = ol.order_id where ol.listing_id = l.id and o.paid and o.cancelled_at is null), 0),
    'favs', (select count(*)::int from favorites fv where fv.listing_id = l.id),
    'is_mine', coalesce(l.seller_id = auth.uid(), false))
  from (select 1) x
  left join shops s on s.id = l.shop_id
  left join profiles sp on sp.id = l.seller_id
  left join lateral (select * from flash_sales fs where fs.listing_id = l.id and not fs.cancelled and fs.starts_at <= now() and fs.ends_at > now() and fs.sold < fs.stock order by fs.sale_price limit 1) f on true
$$;
revoke all on function _listing_card(listings) from public, anon, authenticated;
