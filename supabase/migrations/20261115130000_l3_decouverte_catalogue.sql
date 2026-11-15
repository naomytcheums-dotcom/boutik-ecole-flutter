-- Lot L3 « Découverte et catalogue » : recherche serveur complète (disponibilité, vendeurs vérifiés, projets validés, caractères % et _),
-- recommandations classées avant la limite et paginées, boutiques paginées et suivies avec leurs vrais compteurs, favoris lus par le serveur
-- (annonces retirées comprises), avis de boutique réservés aux acheteurs (contrôle exposé à l'application), signalement avec motif,
-- message à une boutique sans doublon.
-- Retour arrière : drop function can_review_shop(uuid), contact_shop_owner(uuid), my_favorites(text, text, integer, integer), favorite_remove(uuid), recommended_offers(integer, integer);
--   alter table favorites drop column created_at ;
--   drop function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[], boolean, boolean, boolean, uuid) ; drop function marketplace_shops(text, text, text, text, integer, integer) ;
--   puis recréer marketplace_search et recommended_offers depuis 20261114000500_decouverte.sql, marketplace_shops, my_followed_shops depuis 20261107000000_marketplace.sql
--   et report_shop depuis 20261107000000_marketplace.sql.

alter table favorites add column if not exists created_at timestamptz not null default now();

-- ============================================================ 1. Recherche : filtres de disponibilité, de vendeur vérifié et de projet validé ; « % » et « _ » saisis sont des caractères comme les autres
drop function if exists marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[]);
create or replace function marketplace_search(p_q text default null, p_category text default null, p_city text default null, p_min integer default null, p_max integer default null,
  p_sort text default 'popular', p_shop uuid default null, p_limit integer default 24, p_offset integer default 0, p_offer_type text default null,
  p_department text default null, p_terms text[] default null, p_in_stock boolean default null, p_verified boolean default null, p_validated boolean default null,
  p_seller uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_q text := nullif(lower(trim(coalesce(p_q, ''))), '');
  v_t text := nullif(trim(coalesce(p_offer_type, '')), '');
  v_d text := nullif(lower(trim(coalesce(p_department, ''))), '');
  v_terms text[] := (select nullif(array_agg(distinct lower(trim(x))), '{}') from unnest(coalesce(p_terms, '{}'::text[])) x where char_length(trim(x)) between 3 and 30 limit 12);
  r jsonb;
begin
  select coalesce(jsonb_agg(q.c order by
      case when v_terms is not null then q.score end desc nulls last,
      case p_sort when 'price_asc' then (q.c->>'price')::numeric end asc nulls last,
      case p_sort when 'price_desc' then (q.c->>'price')::numeric end desc nulls last,
      case p_sort when 'recent' then q.c->>'created_at' end desc nulls last,
      case p_sort when 'rating' then coalesce((q.c->>'rating_avg')::numeric, 0) end desc nulls last,
      ((q.c->>'sales')::int * 3 + (q.c->>'favs')::int) desc, q.c->>'created_at' desc), '[]'::jsonb)
  into r from (
    select _listing_card(l) c,
           case when v_terms is null then 0 else (select count(*)::int from unnest(v_terms) t where strpos(lower(l.title || ' ' || coalesce(l.description, '') || ' ' || l.category), t) > 0) end score
    from listings l
    left join shops s on s.id = l.shop_id
    left join profiles sp on sp.id = l.seller_id
    where l.status = 'approved' and (l.shop_id is null or s.status = 'active')
      and (case
             when v_t is not null then offer_type_of(l.category) = v_t and (p_category is null or p_category = '' or lower(l.category) = lower(p_category))
             when p_category is null or p_category = '' then true
             else lower(l.category) = lower(p_category) end)
      and (v_q is null or strpos(lower(l.title), v_q) > 0 or strpos(lower(coalesce(l.description, '')), v_q) > 0 or strpos(lower(coalesce(s.name, '')), v_q) > 0)
      and (v_d is null or strpos(lower(coalesce(l.department, '')), v_d) > 0)
      and (p_city is null or p_city = '' or lower(coalesce(s.city, sp.city, '')) = lower(p_city))
      and (p_min is null or l.price >= p_min) and (p_max is null or l.price <= p_max)
      and (p_shop is null or l.shop_id = p_shop)
      and (p_seller is null or l.seller_id = p_seller)
      and (not coalesce(p_in_stock, false) or offer_type_of(l.category) in ('service', 'project') or l.stock > 0)
      and (not coalesce(p_verified, false) or sp.certification::text = 'approved')
      and (not coalesce(p_validated, false) or (l.reviewed_by is not null and l.seller_id is not null))
  ) q
  where v_terms is null or q.score > 0;
  -- pagination appliquée après le classement par pertinence
  select coalesce(jsonb_agg(e), '[]'::jsonb) into r from (
    select e from jsonb_array_elements(r) with ordinality t(e, n)
    order by n limit least(greatest(coalesce(p_limit, 24), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) z;
  return r;
end $$;
revoke all on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[], boolean, boolean, boolean, uuid) from public;
grant execute on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[], boolean, boolean, boolean, uuid) to anon, authenticated;

-- ============================================================ 2. Recommandations : le classement précède la limite ; filière, catégories des favoris et des achats, puis popularité ; pagination
drop function if exists recommended_offers(integer);
create or replace function recommended_offers(p_limit integer default 10, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_dept text;
  v_cats text[] := '{}';
  v_lim integer := least(greatest(coalesce(p_limit, 10), 1), 50);
  v_off integer := greatest(coalesce(p_offset, 0), 0);
  r jsonb;
begin
  if uid is not null then
    select nullif(lower(trim(department)), '') into v_dept from profiles where id = uid;
    select coalesce(array_agg(distinct lower(l.category)), '{}') into v_cats from (
      select f.listing_id from favorites f where f.user_id = uid
      union
      select ol.listing_id from order_lines ol join orders o on o.id = ol.order_id where o.buyer_id = uid and o.cancelled_at is null) k
      join listings l on l.id = k.listing_id;
  end if;
  select coalesce(jsonb_agg(z.c order by z.n), '[]'::jsonb) into r from (
    select y.c, row_number() over (order by y.score desc, y.pop desc, y.cr desc) n from (
      select k.c c, l.created_at cr,
             (case when v_dept is not null and lower(coalesce(l.department, '')) = v_dept then 100 else 0 end
              + case when lower(l.category) = any (v_cats) then 50 else 0 end) score,
             ((k.c->>'sales')::int * 3 + (k.c->>'favs')::int) pop
      from listings l
      left join shops s on s.id = l.shop_id
      cross join lateral (select _listing_card(l) c) k
      where l.status = 'approved' and (l.shop_id is null or s.status = 'active') and l.seller_id is distinct from uid
        and (offer_type_of(l.category) <> 'product' or l.stock > 0)) y
    order by n limit v_lim offset v_off) z;
  return r;
end $$;
revoke all on function recommended_offers(integer, integer) from public;
grant execute on function recommended_offers(integer, integer) to anon, authenticated;

-- ============================================================ 3. Boutiques : le classement précède la limite, pagination
drop function if exists marketplace_shops(text, text, text, text, integer);
create or replace function marketplace_shops(p_q text default null, p_category text default null, p_city text default null, p_sort text default 'popular', p_limit integer default 24, p_offset integer default 0) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(z.x order by z.n), '[]'::jsonb) from (
    select q.x, row_number() over (order by
        case p_sort when 'recent' then q.x->>'created_at' end desc nulls last,
        case p_sort when 'rating' then coalesce((q.x->>'rating_avg')::numeric, 0) end desc nulls last,
        ((q.x->>'followers')::int * 2 + (q.x->>'products')::int) desc) n
    from (
      select jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'logo_url', s.logo_url, 'banner_url', s.banner_url, 'city', s.city, 'categories', s.categories,
        'created_at', s.created_at, 'color_primary', s.color_primary,
        'followers', (select count(*)::int from shop_follows f where f.shop_id = s.id),
        'products', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'approved'),
        'rating_avg', (select round(avg(r.rating)::numeric, 1) from shop_reviews r where r.shop_id = s.id),
        'rating_count', (select count(*)::int from shop_reviews r where r.shop_id = s.id)) x
      from shops s
      where s.status = 'active'
        and (nullif(trim(coalesce(p_q, '')), '') is null or strpos(lower(s.name), lower(trim(p_q))) > 0 or strpos(lower(coalesce(s.description, '')), lower(trim(p_q))) > 0)
        and (p_category is null or p_category = '' or exists (select 1 from unnest(s.categories) c where lower(c) = lower(p_category)))
        and (p_city is null or p_city = '' or lower(coalesce(s.city, '')) = lower(p_city))) q
    order by n limit least(greatest(coalesce(p_limit, 24), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) z
$$;
revoke all on function marketplace_shops(text, text, text, text, integer, integer) from public;
grant execute on function marketplace_shops(text, text, text, text, integer, integer) to anon, authenticated;

-- Boutiques suivies : les compteurs réels (produits publiés, abonnés, note) accompagnent chaque boutique
create or replace function my_followed_shops() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'logo_url', s.logo_url, 'city', s.city,
      'products', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'approved'),
      'followers', (select count(*)::int from shop_follows x where x.shop_id = s.id),
      'rating_avg', (select round(avg(r.rating)::numeric, 1) from shop_reviews r where r.shop_id = s.id),
      'rating_count', (select count(*)::int from shop_reviews r where r.shop_id = s.id)) order by f.created_at desc), '[]'::jsonb)
  from shop_follows f join shops s on s.id = f.shop_id where f.user_id = auth.uid() and s.status = 'active'
$$;

-- ============================================================ 4. Favoris lus par le serveur (une annonce retirée reste listée, marquée indisponible, et peut être retirée)
create or replace function my_favorites(p_offer_type text default null, p_q text default null, p_limit integer default 24, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_t text := nullif(trim(coalesce(p_offer_type, '')), '');
  v_q text := nullif(lower(trim(coalesce(p_q, ''))), '');
  r jsonb;
begin
  if uid is null then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(y.e order by y.n), '[]'::jsonb) into r from (
    select z.e, z.n from (
      select case when l.status = 'approved' and (l.shop_id is null or s.status = 'active') then _listing_card(l) || jsonb_build_object('available', true)
                  else jsonb_build_object('id', l.id, 'title', l.title, 'offer_type', offer_type_of(l.category), 'available', false) end e,
             row_number() over (order by f.created_at desc, l.title) n
      from favorites f
      join listings l on l.id = f.listing_id
      left join shops s on s.id = l.shop_id
      where f.user_id = uid
        and (v_t is null or offer_type_of(l.category) = v_t)
        and (v_q is null or strpos(lower(l.title), v_q) > 0)) z
    order by z.n limit least(greatest(coalesce(p_limit, 24), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) y;
  return r;
end $$;
revoke all on function my_favorites(text, text, integer, integer) from public, anon;
grant execute on function my_favorites(text, text, integer, integer) to authenticated;

create or replace function favorite_remove(p_listing uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from favorites where user_id = auth.uid() and listing_id = p_listing;
end $$;
revoke all on function favorite_remove(uuid) from public, anon;
grant execute on function favorite_remove(uuid) to authenticated;

-- ============================================================ 5. Boutique : avis réservés aux acheteurs (contrôle exposé), signalement avec motif, message sans doublon
create or replace function can_review_shop(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from shops s
    where s.id = p_shop and s.status = 'active' and s.owner_id <> auth.uid()
      and exists (select 1 from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                  where o.buyer_id = auth.uid() and o.paid and o.cancelled_at is null and l.seller_id = s.owner_id))
$$;
revoke all on function can_review_shop(uuid) from public, anon;
grant execute on function can_review_shop(uuid) to authenticated;

create or replace function report_shop(p_shop uuid, p_reason text, p_details text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; m record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_reason, '') not in ('fraud', 'counterfeit', 'abuse', 'other') then raise exception 'Choisissez un motif de signalement'; end if;
  select * into s from shops where id = p_shop and status = 'active' and owner_id <> auth.uid();
  if not found then raise exception 'Boutique introuvable'; end if;
  if (select count(*) from shop_reports where reporter_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then
    raise exception 'Trop de signalements aujourd''hui : réessayez demain';
  end if;
  insert into shop_reports (shop_id, reporter_id, reason, details) values (p_shop, auth.uid(), p_reason, nullif(left(trim(coalesce(p_details, '')), 2000), ''))
  on conflict (shop_id, reporter_id) do nothing;
  if not found then raise exception 'Vous avez déjà signalé cette boutique'; end if;
  for m in select id from profiles where role::text in ('admin', 'support') and not coalesce(suspended, false) limit 20 loop
    perform notify_user(m.id, 'shop', 'Boutique signalée', s.name || ' a été signalée (' ||
      case p_reason when 'fraud' then 'fraude' when 'counterfeit' then 'contrefaçon' when 'abuse' then 'comportement abusif' else 'autre motif' end || ').', jsonb_build_object('shop', s.slug));
  end loop;
end $$;

-- Écrire à une boutique : si une conversation directe existe déjà avec son propriétaire, elle est retrouvée sans ajouter de message
create or replace function contact_shop_owner(p_shop uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where id = p_shop and status = 'active';
  if not found then raise exception 'Boutique introuvable'; end if;
  if s.owner_id = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  select c.id into cid from conversations c
    where c.listing_id is null
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = s.owner_id)
      and (select count(*) from conversation_participants p where p.conversation_id = c.id) = 2
    limit 1;
  if cid is not null then return jsonb_build_object('existing', true, 'conversation', cid); end if;
  cid := start_direct_conversation(s.owner_id, 'Bonjour, je vous contacte au sujet de votre boutique ' || s.name || '.');
  return jsonb_build_object('existing', false, 'conversation', cid);
end $$;
revoke all on function contact_shop_owner(uuid) from public, anon;
grant execute on function contact_shop_owner(uuid) to authenticated;
