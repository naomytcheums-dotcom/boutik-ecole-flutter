-- Vendeur vérifié : enseignant encadrant du projet, badge « validé par l'IUT » (annonce approuvée par un responsable), vendeur dans la fiche.
-- Retour arrière : alter table listings drop column supervisor; puis recréer product_detail et _listing_card depuis les migrations précédentes.
alter table listings add column if not exists supervisor text check (supervisor is null or char_length(supervisor) <= 80);

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
    'favs', (select count(*)::int from favorites fv where fv.listing_id = l.id))
  from (select 1) x
  left join shops s on s.id = l.shop_id
  left join profiles sp on sp.id = l.seller_id
  left join lateral (select * from flash_sales fs where fs.listing_id = l.id and not fs.cancelled and fs.starts_at <= now() and fs.ends_at > now() and fs.sold < fs.stock order by fs.sale_price limit 1) f on true
$$;
revoke all on function _listing_card(listings) from public, anon, authenticated;

create or replace function product_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l listings%rowtype; uid uuid := auth.uid();
begin
  select * into l from listings where id = p_id;
  if not found or (l.status <> 'approved' and l.seller_id is distinct from uid) then return jsonb_build_object('found', false); end if;
  return jsonb_build_object('found', true, 'card', _listing_card(l),
    'description', l.description, 'images', to_jsonb(l.images), 'video_url', l.video_url, 'variants', l.variants, 'specs', l.specs, 'department', l.department,
    'seller_id', l.seller_id, 'is_owner', l.seller_id = uid,
    'supervisor', l.supervisor, 'validated', (l.status = 'approved' and l.reviewed_by is not null and l.seller_id is not null),
    'seller', (select jsonb_build_object('id', p.id, 'name', p.name, 'avatar_url', p.avatar_url, 'department', coalesce(nullif(p.department, ''), l.department),
                 'study_level', p.study_level, 'institution', p.institution, 'certified', p.certification = 'approved')
               from profiles p where p.id = l.seller_id),
    'favorite', exists (select 1 from favorites f where f.listing_id = l.id and f.user_id = uid),
    'alerts', coalesce((select jsonb_agg(a.kind) from price_alerts a where a.listing_id = l.id and a.user_id = uid), '[]'::jsonb),
    'questions', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'question', q.question, 'answer', q.answer, 'author', display_name(q.asker_id), 'created_at', q.created_at) order by q.created_at desc), '[]'::jsonb)
                  from (select * from product_questions where listing_id = l.id order by created_at desc limit 30) q),
    'reviews', (select coalesce(jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.reviewer_id), 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
                from (select * from reviews where listing_id = l.id order by created_at desc limit 20) r));
end $$;
