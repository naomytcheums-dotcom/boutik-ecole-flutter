-- Lot S3 (espace vendeur) : services « Sur devis », rattachement des annonces à la boutique, gestion des promotions,
-- alertes de stock réelles, aperçu vendeur (tableau de bord 57 et studio D1), fiche produit d'une boutique non active.
-- Fichier additif et rejouable. Retour arrière (manuel) : voir le bas du fichier.

-- 1. Service « Sur devis » : prix 0 accepté pour les offres qui ne sont pas des produits (S3-11) ----------------------------------------
alter table listings drop constraint if exists listings_price_min;
alter table listings add constraint listings_price_min
  check (price <= 100000000 and (price >= 500 or (price = 0 and offer_type_of(category) <> 'product')));

-- 2. Rattachement des annonces à la boutique du vendeur (S3-8) ----------------------------------------------------------------------------
-- Une annonce créée avant la boutique (ou pendant qu'elle était fermée) n'était jamais rattachée : vitrine vide, ventes flash, packs et
-- campagnes impossibles. La fonction interne ne touche que les annonces sans boutique du vendeur ; elle n'est pas une modification de contenu.
create or replace function _attach_seller_listings(p_owner uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; n integer := 0;
begin
  if p_owner is null then return 0; end if;
  select id into v_shop from shops where owner_id = p_owner and status <> 'closed';
  if v_shop is null then return 0; end if;
  perform set_config('app.internal', '1', true);
  update listings set shop_id = v_shop where seller_id = p_owner and shop_id is null and status <> 'removed';
  get diagnostics n = row_count;
  perform set_config('app.internal', '', true);
  return n;
end $$;
revoke all on function _attach_seller_listings(uuid) from public, anon, authenticated;

create or replace function shop_attach_listings() returns integer
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return _attach_seller_listings(auth.uid());
end $$;
revoke all on function shop_attach_listings() from public, anon;
grant execute on function shop_attach_listings() to authenticated;

-- Rattrapage unique des annonces existantes.
do $$
declare s record;
begin
  for s in select owner_id from shops where status <> 'closed' loop
    perform _attach_seller_listings(s.owner_id);
  end loop;
end $$;

-- Les promotions rattachent d'abord les annonces du vendeur, puis appliquent les mêmes règles qu'avant.
create or replace function flash_save(p_listing uuid, p_price integer, p_stock integer, p_starts timestamptz, p_ends timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _my_shop_id(true); l listings%rowtype; v_id uuid; v_reserved integer;
begin
  perform _attach_seller_listings(auth.uid());
  select * into l from listings where id = p_listing and seller_id = auth.uid() and shop_id = v_shop and status = 'approved' for update;
  if not found then raise exception 'Produit introuvable dans votre boutique'; end if;
  if p_price is null or p_price >= l.price then raise exception 'Le prix flash doit être inférieur au prix actuel (% FCFA)', l.price; end if;
  if p_ends <= now() then raise exception 'La vente doit se terminer dans le futur'; end if;
  select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
  if p_stock is null or p_stock < 1 or p_stock + v_reserved > l.stock then raise exception 'Stock flash invalide : %  disponible(s) à réserver', l.stock - v_reserved; end if;
  insert into flash_sales (listing_id, shop_id, sale_price, stock, starts_at, ends_at) values (l.id, v_shop, p_price, p_stock, p_starts, p_ends) returning id into v_id;
  return v_id;
end $$;

create or replace function campaign_save(p_title text, p_description text, p_banner text, p_listings uuid[], p_starts timestamptz, p_ends timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _my_shop_id(true); v_id uuid;
begin
  perform _attach_seller_listings(auth.uid());
  if exists (select 1 from unnest(coalesce(p_listings, '{}')) x where not exists (select 1 from listings l where l.id = x and l.shop_id = v_shop)) then raise exception 'Produit hors de votre boutique'; end if;
  insert into shop_campaigns (shop_id, title, description, banner_url, listing_ids, starts_at, ends_at)
  values (v_shop, trim(p_title), nullif(trim(coalesce(p_description, '')), ''), nullif(p_banner, ''), coalesce(p_listings, '{}'), coalesce(p_starts, now()), p_ends)
  returning id into v_id;
  return v_id;
end $$;

create or replace function pack_save(p_title text, p_description text, p_price integer, p_items jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _my_shop_id(true); v_id uuid; v_normal integer;
begin
  perform _attach_seller_listings(auth.uid());
  if jsonb_typeof(p_items) <> 'array' then raise exception 'Composition invalide'; end if;
  if exists (select 1 from jsonb_array_elements(p_items) i where not exists (select 1 from listings l where l.id = (i->>'listing')::uuid and l.shop_id = v_shop and l.status = 'approved') or coalesce((i->>'qty')::int, 0) not between 1 and 10) then
    raise exception 'Chaque composant doit être un produit approuvé de votre boutique (quantité de 1 à 10)';
  end if;
  select sum(l.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(p_items) i join listings l on l.id = (i->>'listing')::uuid;
  if p_price >= v_normal then raise exception 'Le prix du pack doit être inférieur à la somme des produits (% FCFA)', v_normal; end if;
  insert into shop_packs (shop_id, title, description, price, items) values (v_shop, trim(p_title), nullif(trim(coalesce(p_description, '')), ''), p_price, p_items) returning id into v_id;
  return v_id;
end $$;

-- 3. Promotions désactivables (S3-12) -------------------------------------------------------------------------------------------------------
create or replace function promo_toggle(p_id uuid, p_active boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update promo_codes set active = coalesce(p_active, not active)
    where id = p_id and shop_id = (select id from shops where owner_id = auth.uid()) returning active into v;
  if v is null then raise exception 'Code promo introuvable'; end if;
  return v;
end $$;

create or replace function campaign_toggle(p_id uuid, p_active boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update shop_campaigns set active = coalesce(p_active, not active)
    where id = p_id and shop_id = (select id from shops where owner_id = auth.uid()) returning active into v;
  if v is null then raise exception 'Campagne introuvable'; end if;
  return v;
end $$;

create or replace function pack_toggle(p_id uuid, p_active boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update shop_packs set active = coalesce(p_active, not active)
    where id = p_id and shop_id = (select id from shops where owner_id = auth.uid()) returning active into v;
  if v is null then raise exception 'Pack introuvable'; end if;
  return v;
end $$;

revoke all on function promo_toggle(uuid, boolean), campaign_toggle(uuid, boolean), pack_toggle(uuid, boolean) from public, anon;
grant execute on function promo_toggle(uuid, boolean), campaign_toggle(uuid, boolean), pack_toggle(uuid, boolean) to authenticated;

-- 4. Fiche produit : l'annonce d'une boutique non active n'est lisible que de son propriétaire et de l'équipe (S3-9) --------------------------
create or replace function product_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l listings%rowtype; uid uuid := auth.uid();
begin
  select * into l from listings where id = p_id;
  if not found or (l.status <> 'approved' and l.seller_id is distinct from uid) then return jsonb_build_object('found', false); end if;
  if l.seller_id is distinct from uid and l.shop_id is not null and coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support')
     and not exists (select 1 from shops s where s.id = l.shop_id and s.status = 'active') then
    return jsonb_build_object('found', false);
  end if;
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

-- 5. Alertes de stock du vendeur (S3-13) : réglages réels et notification quand le stock passe sous le seuil ou à zéro ------------------------
create table if not exists seller_settings (
  user_id uuid primary key references profiles(id) on delete cascade,
  stock_threshold integer not null default 30 check (stock_threshold between 0 and 100000),
  notify_low boolean not null default true,
  notify_out boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table seller_settings enable row level security;
revoke all on seller_settings from anon, authenticated;

create or replace function seller_settings_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s seller_settings%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from seller_settings where user_id = auth.uid();
  if not found then return jsonb_build_object('stock_threshold', 30, 'notify_low', true, 'notify_out', true); end if;
  return jsonb_build_object('stock_threshold', s.stock_threshold, 'notify_low', s.notify_low, 'notify_out', s.notify_out);
end $$;

create or replace function seller_settings_set(p_threshold integer, p_low boolean, p_out boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_threshold is null or p_threshold < 0 or p_threshold > 100000 then raise exception 'Seuil : un entier de 0 à 100 000'; end if;
  insert into seller_settings (user_id, stock_threshold, notify_low, notify_out) values (auth.uid(), p_threshold, coalesce(p_low, true), coalesce(p_out, true))
  on conflict (user_id) do update set stock_threshold = excluded.stock_threshold, notify_low = excluded.notify_low, notify_out = excluded.notify_out, updated_at = now();
  return seller_settings_get();
end $$;
revoke all on function seller_settings_get(), seller_settings_set(integer, boolean, boolean) from public, anon;
grant execute on function seller_settings_get(), seller_settings_set(integer, boolean, boolean) to authenticated;

create or replace function s3_stock_alert() returns trigger
language plpgsql security definer set search_path = public as $$
declare s seller_settings%rowtype; v_thr integer := 30; v_low boolean := true; v_out boolean := true;
begin
  if new.seller_id is null or new.status <> 'approved' or offer_type_of(new.category) <> 'product' or new.stock is not distinct from old.stock then return null; end if;
  select * into s from seller_settings where user_id = new.seller_id;
  if found then v_thr := s.stock_threshold; v_low := s.notify_low; v_out := s.notify_out; end if;
  if new.stock = 0 and old.stock > 0 then
    if v_out then perform notify_user(new.seller_id, 'listing', 'Rupture de stock', new.title || ' est épuisé.', jsonb_build_object('listing', new.id)); end if;
  elsif new.stock > 0 and new.stock <= v_thr and old.stock > v_thr then
    if v_low then perform notify_user(new.seller_id, 'listing', 'Stock bas', new.title || ' : plus que ' || new.stock || ' en stock.', jsonb_build_object('listing', new.id)); end if;
  end if;
  return null;
end $$;
revoke all on function s3_stock_alert() from public, anon, authenticated;
drop trigger if exists trg_s3_stock_alert on listings;
create trigger trg_s3_stock_alert after update of stock on listings for each row execute function s3_stock_alert();

-- 6. Aperçu du vendeur : données réelles pour le tableau de bord 57 et le studio D1 (S3-3, S3-4, S3-48, S3-49) ------------------------------
create or replace function seller_overview(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_days int := least(greatest(coalesce(p_days, 30), 1), 365); v_start date := current_date - (least(greatest(coalesce(p_days, 30), 1), 365) - 1);
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'days', v_days,
    'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                          where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at::date >= v_start), 0)::int,
    'orders', coalesce((select count(distinct o.id) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                         where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at::date >= v_start), 0)::int,
    'units', coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at::date >= v_start), 0)::int,
    'pending_orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where l.seller_id = uid and o.paid and o.cancelled_at is null and ol.fulfillment < 4),
    'views', coalesce((select sum(v.views) from listing_views v join listings l on l.id = v.listing_id where l.seller_id = uid and v.day >= v_start), 0)::int,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where l.seller_id = uid and l.status <> 'removed'),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = uid and l.status <> 'removed'),
    'listings', jsonb_build_object(
      'approved', (select count(*)::int from listings where seller_id = uid and status = 'approved'),
      'pending', (select count(*)::int from listings where seller_id = uid and status = 'pending'),
      'draft', (select count(*)::int from listings where seller_id = uid and status = 'draft'),
      'rejected', (select count(*)::int from listings where seller_id = uid and status = 'rejected')),
    'months', coalesce((select jsonb_agg(jsonb_build_object('month', to_char(m, 'YYYY-MM'),
                 'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                                       where l.seller_id = uid and o.paid and o.cancelled_at is null and date_trunc('month', o.created_at) = m), 0)::int) order by m)
               from generate_series(date_trunc('month', now()) - interval '5 months', date_trunc('month', now()), interval '1 month') m), '[]'::jsonb),
    'products', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'price', l.price, 'stock', l.stock, 'status', l.status, 'category', l.category,
                 'units', coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id where ol.listing_id = l.id and o.paid and o.cancelled_at is null), 0)::int,
                 'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id where ol.listing_id = l.id and o.paid and o.cancelled_at is null), 0)::int)
                 order by l.created_at desc)
               from (select * from listings where seller_id = uid and status <> 'removed' order by created_at desc limit 50) l), '[]'::jsonb));
end $$;
revoke all on function seller_overview(integer) from public, anon;
grant execute on function seller_overview(integer) to authenticated;

-- Retour arrière : drop function seller_overview(integer), s3_stock_alert(), seller_settings_get(), seller_settings_set(integer, boolean, boolean), promo_toggle(uuid, boolean),
--   campaign_toggle(uuid, boolean), pack_toggle(uuid, boolean), shop_attach_listings(), _attach_seller_listings(uuid); drop trigger trg_s3_stock_alert on listings; drop table seller_settings;
--   recréer flash_save / campaign_save / pack_save depuis 20261107000000_marketplace.sql et product_detail depuis 20261114000200_vendeur_verifie.sql ;
--   alter table listings drop constraint listings_price_min, add constraint listings_price_min check (price >= 500 and price <= 100000000).
