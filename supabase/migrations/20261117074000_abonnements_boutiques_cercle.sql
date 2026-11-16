-- Abonnements : l'onglet « Abonnements » du Cercle inclut les créateurs dont on suit la boutique (S7-18).
-- my_followed_shops renvoie en plus l'identifiant du propriétaire de chaque boutique suivie (owner_id) ; rien d'autre ne change.
-- Retour arrière : recréer my_followed_shops depuis 20261115130000_l3_decouverte_catalogue.sql.

create or replace function my_followed_shops() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'logo_url', s.logo_url, 'city', s.city, 'owner_id', s.owner_id,
      'products', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'approved'),
      'followers', (select count(*)::int from shop_follows x where x.shop_id = s.id),
      'rating_avg', (select round(avg(r.rating)::numeric, 1) from shop_reviews r where r.shop_id = s.id),
      'rating_count', (select count(*)::int from shop_reviews r where r.shop_id = s.id)) order by f.created_at desc), '[]'::jsonb)
  from shop_follows f join shops s on s.id = f.shop_id where f.user_id = auth.uid() and s.status = 'active'
$$;
revoke all on function my_followed_shops() from public, anon;
grant execute on function my_followed_shops() to authenticated;
