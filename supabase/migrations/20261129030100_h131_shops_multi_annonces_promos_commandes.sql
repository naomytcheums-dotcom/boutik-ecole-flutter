-- H13.1 · Multi-boutiques (2/3) : annonces, promotions et produits mis en avant, commandes, avis, lecture publique — tout est rattaché à LA BONNE boutique.
--  · listing_shop_guard : une annonce n'appartient qu'à une boutique de SON vendeur ; sans boutique indiquée, elle rejoint la boutique active du vendeur.
--  · listing_move_shop(annonce, boutique) : déplacement entre boutiques du même propriétaire (refusé si une vente flash ou un pack actif en dépend ; l'annonce quitte les campagnes de la boutique
--    d'origine). Les lignes de commande passées gardent leur boutique d'origine (order_lines.shop_id). Variantes, prix et stock suivent l'annonce.
--  · promo_save / flash_save / campaign_save / pack_save / my_promotions : p_shop optionnel (boutique active sinon), droit « manager » minimum ; toggles et annulations idem.
--  · seller_orders / set_seller_order_status / seller_confirm_handover : p_shop optionnel ; lecture « viewer », préparation « staff » ; une ligne n'est jamais traitée au nom d'une autre boutique.
--  · shop_listings : produits et stock d'une boutique (équipe comprise) ; shop_public, avis boutique et seller_public ne mélangent plus les boutiques d'un même propriétaire.
-- Strictement additive (les anciennes signatures sont remplacées par les mêmes avec un paramètre optionnel en plus). Retour arrière : voir la fin du fichier.

-- 1. Annonces -------------------------------------------------------------------------------------------------------------------------
create or replace function listing_shop_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.shop_id is null and tg_op = 'INSERT' and new.seller_id is not null then
    new.shop_id := _shop_default_owned(new.seller_id, true);
  end if;
  if new.shop_id is not null and not exists (select 1 from shops where id = new.shop_id and owner_id = new.seller_id) then
    raise exception 'Cette boutique n''appartient pas au vendeur de l''annonce';
  end if;
  if tg_op = 'UPDATE' and new.shop_id is not null and new.shop_id is distinct from old.shop_id
     and exists (select 1 from shops where id = new.shop_id and status = 'closed') then
    raise exception 'Cette boutique est fermée : choisissez une autre boutique';
  end if;
  return new;
end $$;

create or replace function _attach_seller_listings(p_owner uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; n integer := 0;
begin
  if p_owner is null then return 0; end if;
  v_shop := _shop_default_owned(p_owner, true);
  if v_shop is null then return 0; end if;
  perform set_config('app.internal', '1', true);
  update listings set shop_id = v_shop where seller_id = p_owner and shop_id is null and status <> 'removed';
  get diagnostics n = row_count;
  perform set_config('app.internal', '', true);
  return n;
end $$;
revoke all on function _attach_seller_listings(uuid) from public, anon, authenticated;

-- Après un changement de boutique : pas de vente flash ni de pack actif à cheval sur deux boutiques ; l'annonce quitte les campagnes de la boutique d'origine.
create or replace function listing_shop_move_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.shop_id is null or new.shop_id is not distinct from old.shop_id then return null; end if;
  if exists (select 1 from flash_sales f where f.listing_id = new.id and not f.cancelled and f.ends_at > now()) then
    raise exception 'Une vente flash est en cours ou programmée sur cette annonce : annulez-la avant de changer de boutique';
  end if;
  if exists (select 1 from shop_packs k where k.shop_id = old.shop_id and k.active and k.items @> jsonb_build_array(jsonb_build_object('listing', new.id::text))) then
    raise exception 'Cette annonce fait partie d''un pack actif de sa boutique : désactivez le pack avant de changer de boutique';
  end if;
  update shop_campaigns set listing_ids = array_remove(listing_ids, new.id) where shop_id = old.shop_id and new.id = any (listing_ids);
  return null;
end $$;
revoke all on function listing_shop_move_guard() from public, anon, authenticated;
drop trigger if exists trg_listing_shop_move on listings;
create trigger trg_listing_shop_move after update of shop_id on listings for each row execute function listing_shop_move_guard();

create or replace function listing_move_shop(p_listing uuid, p_shop uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); l listings%rowtype; s shops%rowtype; n integer := 0; v_from uuid;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into l from listings where id = p_listing for update;
  if not found or l.seller_id is distinct from uid then raise exception 'Annonce introuvable'; end if;
  if l.status = 'removed' then raise exception 'Annonce supprimée'; end if;
  select * into s from shops where id = p_shop;
  if not found or s.owner_id <> uid then raise exception 'Boutique introuvable'; end if;
  if l.shop_id is not distinct from s.id then return jsonb_build_object('listing_id', l.id, 'shop_id', s.id, 'moved', false); end if;
  v_from := l.shop_id;
  select count(*)::int into n from shop_campaigns where shop_id = v_from and l.id = any (listing_ids);
  perform set_config('app.internal', '1', true);
  update listings set shop_id = s.id where id = l.id;
  perform set_config('app.internal', '', true);
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Annonce déplacée vers une autre boutique', s.slug, 'Marketplace', 'Normal');
  return jsonb_build_object('listing_id', l.id, 'from_shop_id', v_from, 'shop_id', s.id, 'moved', true, 'removed_from_campaigns', n);
end $$;
revoke all on function listing_move_shop(uuid, uuid) from public, anon;
grant execute on function listing_move_shop(uuid, uuid) to authenticated;

-- Produits et stock d'une boutique (lecture : tout membre).
create or replace function shop_listings(p_shop uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_owner uuid;
begin
  select scope_shop, scope_owner into v_shop, v_owner from _shop_scope(p_shop, 'viewer');
  return jsonb_build_object('shop_id', v_shop, 'listings', coalesce((
    select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'price', l.price, 'stock', l.stock, 'status', l.status, 'category', l.category, 'shop_id', l.shop_id,
             'variants', (select count(*)::int from listing_variants v where v.listing_id = l.id),
             'image', coalesce(l.images[1], l.image_url)) order by l.created_at desc)
    from (select * from listings x where x.status <> 'removed' and case when v_shop is not null then x.shop_id = v_shop else x.seller_id = v_owner end order by x.created_at desc limit 200) l), '[]'::jsonb));
end $$;
revoke all on function shop_listings(uuid) from public, anon;
grant execute on function shop_listings(uuid) to authenticated;

-- 2. Promotions, événements commerciaux et produits mis en avant, par boutique ------------------------------------------------------
drop function if exists promo_save(text, text, integer, integer, integer, timestamptz, boolean, boolean);
create or replace function promo_save(p_code text, p_kind text, p_value integer, p_min integer default 0, p_max_uses integer default null, p_ends timestamptz default null, p_active boolean default true, p_platform boolean default false, p_shop uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); v_id uuid;
begin
  if coalesce(p_platform, false) then
    if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  else
    v_shop := _shop_manage(p_shop, true);
  end if;
  if v_code !~ '^[A-Z0-9]{3,20}$' then raise exception 'Code de 3 à 20 lettres ou chiffres'; end if;
  insert into promo_codes (shop_id, code, kind, value, min_amount, max_uses, ends_at, active) values (v_shop, v_code, p_kind, p_value, coalesce(p_min, 0), p_max_uses, p_ends, coalesce(p_active, true))
  on conflict (code) do update set kind = excluded.kind, value = excluded.value, min_amount = excluded.min_amount, max_uses = excluded.max_uses, ends_at = excluded.ends_at, active = excluded.active
    where promo_codes.shop_id is not distinct from v_shop
  returning id into v_id;
  if v_id is null then raise exception 'Ce code existe déjà'; end if;
  return v_id;
end $$;

drop function if exists flash_save(uuid, integer, integer, timestamptz, timestamptz);
create or replace function flash_save(p_listing uuid, p_price integer, p_stock integer, p_starts timestamptz, p_ends timestamptz, p_shop uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _shop_manage(p_shop, true); l listings%rowtype; v_id uuid; v_reserved integer;
begin
  perform _attach_seller_listings(auth.uid());
  select * into l from listings where id = p_listing and shop_id = v_shop and status = 'approved' for update;
  if not found then raise exception 'Produit introuvable dans votre boutique'; end if;
  if p_price is null or p_price >= l.price then raise exception 'Le prix flash doit être inférieur au prix actuel (% FCFA)', l.price; end if;
  if p_ends <= now() then raise exception 'La vente doit se terminer dans le futur'; end if;
  select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
  if p_stock is null or p_stock < 1 or p_stock + v_reserved > l.stock then raise exception 'Stock flash invalide : %  disponible(s) à réserver', l.stock - v_reserved; end if;
  insert into flash_sales (listing_id, shop_id, sale_price, stock, starts_at, ends_at) values (l.id, v_shop, p_price, p_stock, p_starts, p_ends) returning id into v_id;
  return v_id;
end $$;

create or replace function flash_cancel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update flash_sales set cancelled = true where id = p_id and _shop_rank(_shop_role(shop_id, auth.uid())) >= 3;
  if not found then raise exception 'Vente flash introuvable'; end if;
end $$;

drop function if exists campaign_save(text, text, text, uuid[], timestamptz, timestamptz);
create or replace function campaign_save(p_title text, p_description text, p_banner text, p_listings uuid[], p_starts timestamptz, p_ends timestamptz, p_shop uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _shop_manage(p_shop, true); v_id uuid;
begin
  perform _attach_seller_listings(auth.uid());
  if exists (select 1 from unnest(coalesce(p_listings, '{}')) x where not exists (select 1 from listings l where l.id = x and l.shop_id = v_shop)) then raise exception 'Produit hors de votre boutique'; end if;
  insert into shop_campaigns (shop_id, title, description, banner_url, listing_ids, starts_at, ends_at)
  values (v_shop, trim(p_title), nullif(trim(coalesce(p_description, '')), ''), nullif(p_banner, ''), coalesce(p_listings, '{}'), coalesce(p_starts, now()), p_ends)
  returning id into v_id;
  return v_id;
end $$;

drop function if exists pack_save(text, text, integer, jsonb);
create or replace function pack_save(p_title text, p_description text, p_price integer, p_items jsonb, p_shop uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _shop_manage(p_shop, true); v_id uuid; v_normal integer;
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

create or replace function promo_toggle(p_id uuid, p_active boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update promo_codes set active = coalesce(p_active, not active)
    where id = p_id and _shop_rank(_shop_role(shop_id, auth.uid())) >= 3 returning active into v;
  if v is null then raise exception 'Code promo introuvable'; end if;
  return v;
end $$;

create or replace function campaign_toggle(p_id uuid, p_active boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update shop_campaigns set active = coalesce(p_active, not active)
    where id = p_id and _shop_rank(_shop_role(shop_id, auth.uid())) >= 3 returning active into v;
  if v is null then raise exception 'Campagne introuvable'; end if;
  return v;
end $$;

create or replace function pack_toggle(p_id uuid, p_active boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update shop_packs set active = coalesce(p_active, not active)
    where id = p_id and _shop_rank(_shop_role(shop_id, auth.uid())) >= 3 returning active into v;
  if v is null then raise exception 'Pack introuvable'; end if;
  return v;
end $$;

drop function if exists my_promotions();
create or replace function my_promotions(p_shop uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  select scope_shop into v_shop from _shop_scope(p_shop, 'viewer');
  return jsonb_build_object('shop_id', v_shop,
    'codes', coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at desc) from promo_codes c where c.shop_id = v_shop), '[]'::jsonb),
    'flash', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'title', l.title, 'sale_price', f.sale_price, 'stock', f.stock, 'sold', f.sold, 'starts_at', f.starts_at, 'ends_at', f.ends_at, 'cancelled', f.cancelled) order by f.starts_at desc)
                       from flash_sales f join listings l on l.id = f.listing_id where f.shop_id = v_shop), '[]'::jsonb),
    'campaigns', coalesce((select jsonb_agg(to_jsonb(k) order by k.created_at desc) from shop_campaigns k where k.shop_id = v_shop), '[]'::jsonb),
    'packs', coalesce((select jsonb_agg(to_jsonb(k) order by k.created_at desc) from shop_packs k where k.shop_id = v_shop), '[]'::jsonb));
end $$;

revoke all on function promo_save(text, text, integer, integer, integer, timestamptz, boolean, boolean, uuid), flash_save(uuid, integer, integer, timestamptz, timestamptz, uuid),
  campaign_save(text, text, text, uuid[], timestamptz, timestamptz, uuid), pack_save(text, text, integer, jsonb, uuid), my_promotions(uuid),
  flash_cancel(uuid), promo_toggle(uuid, boolean), campaign_toggle(uuid, boolean), pack_toggle(uuid, boolean) from public, anon;
grant execute on function promo_save(text, text, integer, integer, integer, timestamptz, boolean, boolean, uuid), flash_save(uuid, integer, integer, timestamptz, timestamptz, uuid),
  campaign_save(text, text, text, uuid[], timestamptz, timestamptz, uuid), pack_save(text, text, integer, jsonb, uuid), my_promotions(uuid),
  flash_cancel(uuid), promo_toggle(uuid, boolean), campaign_toggle(uuid, boolean), pack_toggle(uuid, boolean) to authenticated;

-- 3. Commandes par boutique -------------------------------------------------------------------------------------------------------------
-- Une ligne appartient à la boutique figée à la commande (order_lines.shop_id), à défaut à la boutique de l'annonce ; sans boutique : au vendeur.
drop function if exists seller_orders();
create or replace function seller_orders(p_shop uuid default null)
returns table (number text, title text, qty integer, total integer, buyer_name text, status integer, created_at timestamptz, nlines integer,
               cod boolean, home_delivery boolean, delivery_city text, delivered_at timestamptz, confirmed boolean, release_at timestamptz, shop_id uuid, shop_name text)
language sql stable security definer set search_path = public as $$
  with sc as (select * from _shop_scope(p_shop, 'viewer'))
  select o.number,
         min(ol.title),
         sum(ol.qty)::int,
         sum(ol.qty * ol.unit_price)::int,
         coalesce(nullif(trim(split_part(bp.name, ' ', 1) || ' ' || case when split_part(bp.name, ' ', 2) <> '' then left(split_part(bp.name, ' ', 2), 1) || '.' else '' end), ''), 'Client'),
         min(ol.fulfillment)::int,
         o.created_at,
         count(*)::int,
         o.cod,
         o.home_delivery,
         o.delivery_address->>'city',
         max(ol.delivered_at),
         bool_and(ol.confirmed_at is not null),
         case when min(ol.fulfillment) >= 4 and not o.cod and not bool_and(ol.confirmed_at is not null) then max(ol.delivered_at) + make_interval(hours => money_hold_hours()) end,
         sc.scope_shop,
         max(sh.name)
  from sc
  cross join order_lines ol
  join listings l on l.id = ol.listing_id
  join orders o on o.id = ol.order_id
  join profiles bp on bp.id = o.buyer_id
  left join shops sh on sh.id = sc.scope_shop
  where case when sc.scope_shop is not null then coalesce(ol.shop_id, l.shop_id) = sc.scope_shop
             else (l.seller_id = auth.uid() or (l.seller_id is null and is_platform_manager())) end
    and (o.paid or o.cod) and o.cancelled_at is null and not o.cancelled
  group by o.number, o.created_at, bp.name, o.cod, o.home_delivery, o.delivery_address->>'city', sc.scope_shop
  order by o.created_at desc
$$;

-- Sans p_shop : comportement d'origine (toutes les lignes du vendeur) ; avec p_shop : seulement les lignes de cette boutique (droit « staff » minimum).
drop function if exists set_seller_order_status(text, integer);
create or replace function set_seller_order_status(p_order text, p_status integer, p_shop uuid default null) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; cur integer; mgr boolean := is_platform_manager(); remaining integer; v_hold integer := money_hold_hours(); v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : préparation de commande impossible'; end if;
  if p_status is null or p_status < 1 or p_status > 4 then raise exception 'Statut invalide'; end if;
  if p_shop is not null then
    select scope_owner into v_owner from _shop_scope(p_shop, 'staff');
    if v_owner <> auth.uid() and exists (select 1 from profiles where id = v_owner and coalesce(suspended, false)) then raise exception 'Compte suspendu : préparation de commande impossible'; end if;
  end if;
  select * into o from orders where number = p_order and (paid or cod) and cancelled_at is null and not cancelled;
  if not found then raise exception 'Commande introuvable ou non payée'; end if;
  select min(ol.fulfillment) into cur from order_lines ol join listings l on l.id = ol.listing_id
    where ol.order_id = o.id
      and case when p_shop is not null then coalesce(ol.shop_id, l.shop_id) = p_shop else (l.seller_id = auth.uid() or (l.seller_id is null and mgr)) end;
  if cur is null then raise exception 'Commande introuvable ou non payée'; end if;
  if p_status <= cur then raise exception 'Ce statut est déjà atteint ou dépassé'; end if;
  if p_status > cur + 1 then
    raise exception 'Passez les étapes dans l''ordre : la prochaine étape est « % »', case cur + 1 when 1 then 'Acceptée' when 2 then 'En préparation' when 3 then 'Prête' else 'Livrée' end;
  end if;
  if exists (select 1 from order_refunds where order_id = o.id and status in ('requested', 'approved')) then
    raise exception 'Une demande d''annulation est en cours sur cette commande : attendez la décision de l''équipe';
  end if;
  update order_lines set fulfillment = p_status
    where order_id = o.id
      and id in (select ol.id from order_lines ol join listings l on l.id = ol.listing_id
                 where ol.order_id = o.id
                   and case when p_shop is not null then coalesce(ol.shop_id, l.shop_id) = p_shop else (l.seller_id = auth.uid() or (l.seller_id is null and mgr)) end);
  insert into notifications (user_id, kind, title, body, data)
  values (o.buyer_id, 'order',
          case p_status when 1 then 'Commande acceptée' when 2 then 'Commande en préparation' when 3 then 'Commande prête' else 'Commande livrée' end,
          'Votre commande ' || o.number || case p_status when 1 then ' a été acceptée par le vendeur.' when 2 then ' est en préparation.' when 3 then ' est prête : vous pouvez la retirer.'
            else ' a été livrée selon le vendeur. Confirmez la réception ou signalez un problème sous ' || v_hold || ' h : passé ce délai, sans réclamation, le paiement est versé au vendeur.' end,
          jsonb_build_object('order_number', o.number, 'fulfillment', p_status));
  if p_status = 4 and o.cod and not o.paid then
    select count(*) into remaining from order_lines where order_id = o.id and fulfillment < 4;
    if remaining = 0 then update orders set paid = true where id = o.id; end if;   -- tout est remis : l'argent est encaissé
  end if;
  return p_status;
end $$;

drop function if exists seller_confirm_handover(text, text);
create or replace function seller_confirm_handover(p_number text, p_code text, p_shop uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; mgr boolean := is_platform_manager(); remaining integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : remise impossible'; end if;
  if p_shop is not null then perform _shop_scope(p_shop, 'staff'); end if;
  select * into o from orders where number = p_number and (paid or cod) and cancelled_at is null and not cancelled for update;
  if not found or not exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id
       and case when p_shop is not null then coalesce(ol.shop_id, l.shop_id) = p_shop else (l.seller_id = auth.uid() or (l.seller_id is null and mgr)) end) then
    raise exception 'Commande introuvable ou non payée';
  end if;
  if o.home_delivery then raise exception 'Cette commande est livrée à domicile : la remise est confirmée par le client ou par le personnel'; end if;
  if exists (select 1 from order_refunds where order_id = o.id and status in ('requested', 'approved')) then
    raise exception 'Une demande d''annulation est en cours sur cette commande : attendez la décision de l''équipe';
  end if;
  if o.pickup_attempts >= 5 then raise exception 'Trop d''essais : le client doit afficher un nouveau code de retrait'; end if;
  if o.pickup_code is null or o.pickup_code <> regexp_replace(coalesce(p_code, ''), '[^0-9]', '', 'g') then
    update orders set pickup_attempts = pickup_attempts + 1 where id = o.id;
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Code de retrait erroné (vendeur)', o.number, 'Kiosques', 'Sensible');
    return 'incorrect';
  end if;
  update order_lines set fulfillment = 4, delivered_at = coalesce(delivered_at, now()), confirmed_at = coalesce(confirmed_at, now()), confirmed_via = coalesce(confirmed_via, 'code')
    where order_id = o.id
      and id in (select ol.id from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id
                 and case when p_shop is not null then coalesce(ol.shop_id, l.shop_id) = p_shop else (l.seller_id = auth.uid() or (l.seller_id is null and mgr)) end);
  if o.cod and not o.paid then
    select count(*) into remaining from order_lines where order_id = o.id and fulfillment < 4;
    if remaining = 0 then update orders set paid = true where id = o.id; end if;
  end if;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'order', 'Remise confirmée', 'La remise de votre commande ' || o.number || ' a été confirmée avec votre code de retrait.', jsonb_build_object('order_number', o.number, 'fulfillment', 4));
  return 'delivered';
end $$;

revoke all on function seller_orders(uuid), set_seller_order_status(text, integer, uuid), seller_confirm_handover(text, text, uuid) from public, anon;
grant execute on function seller_orders(uuid), set_seller_order_status(text, integer, uuid), seller_confirm_handover(text, text, uuid) to authenticated;

-- 4. Avis et lecture publique : une boutique n'hérite pas des ventes de la boutique sœur ------------------------------------------------------
create or replace function can_review_shop(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from shops s
    where s.id = p_shop and s.status = 'active' and s.owner_id <> auth.uid()
      and exists (select 1 from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                  where o.buyer_id = auth.uid() and o.paid and o.cancelled_at is null
                    and (coalesce(ol.shop_id, l.shop_id) = s.id or (coalesce(ol.shop_id, l.shop_id) is null and l.seller_id = s.owner_id))))
$$;

create or replace function submit_shop_review(p_shop uuid, p_rating integer, p_comment text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_rating not between 1 and 5 then raise exception 'Note de 1 à 5'; end if;
  select * into s from shops where id = p_shop and status = 'active';
  if not found then raise exception 'Boutique introuvable'; end if;
  if not exists (select 1 from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                 where o.buyer_id = auth.uid() and o.paid and o.cancelled_at is null
                   and (coalesce(ol.shop_id, l.shop_id) = s.id or (coalesce(ol.shop_id, l.shop_id) is null and l.seller_id = s.owner_id))) then
    raise exception 'Seuls les clients ayant acheté dans cette boutique peuvent la noter';
  end if;
  insert into shop_reviews (shop_id, reviewer_id, rating, comment) values (p_shop, auth.uid(), p_rating, nullif(trim(coalesce(p_comment, '')), ''))
  on conflict (shop_id, reviewer_id) do update set rating = excluded.rating, comment = excluded.comment, created_at = now();
end $$;

create or replace function shop_public(p_slug text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s shops%rowtype; uid uuid := auth.uid();
begin
  select * into s from shops where slug = lower(trim(p_slug));
  if not found or (s.status <> 'active' and s.owner_id is distinct from uid and _my_shop_role(s.id) is null and coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support')) then
    return jsonb_build_object('found', false);
  end if;
  return jsonb_build_object('found', true,
    'shop', jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'description', s.description, 'logo_url', s.logo_url, 'banner_url', s.banner_url,
      'categories', s.categories, 'city', s.city, 'delivery_info', s.delivery_info, 'terms', s.terms, 'socials', s.socials,
      'color_primary', s.color_primary, 'color_secondary', s.color_secondary, 'status', s.status, 'created_at', s.created_at, 'owner_id', s.owner_id),
    'followers', (select count(*)::int from shop_follows f where f.shop_id = s.id),
    'following', exists (select 1 from shop_follows f where f.shop_id = s.id and f.user_id = uid),
    'is_owner', s.owner_id = uid,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from shop_reviews r where r.shop_id = s.id),
    'rating_count', (select count(*)::int from shop_reviews r where r.shop_id = s.id),
    'sales', (select coalesce(sum(ol.qty), 0)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where (coalesce(ol.shop_id, l.shop_id) = s.id or (coalesce(ol.shop_id, l.shop_id) is null and l.seller_id = s.owner_id)) and o.paid and o.cancelled_at is null),
    'products', (select coalesce(jsonb_agg(_listing_card(l) order by l.created_at desc), '[]'::jsonb) from (select * from listings where shop_id = s.id and status = 'approved' order by created_at desc limit 60) l),
    'flash', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'listing', _listing_card(l), 'sale_price', f.sale_price, 'ends_at', f.ends_at, 'left', f.stock - f.sold)), '[]'::jsonb)
              from flash_sales f join listings l on l.id = f.listing_id where f.shop_id = s.id and not f.cancelled and f.starts_at <= now() and f.ends_at > now() and f.sold < f.stock and l.status = 'approved'),
    'campaigns', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'description', c.description, 'banner_url', c.banner_url, 'ends_at', c.ends_at,
                    'products', (select coalesce(jsonb_agg(_listing_card(l)), '[]'::jsonb) from listings l where l.id = any (c.listing_ids) and l.status = 'approved'))), '[]'::jsonb)
                  from shop_campaigns c where c.shop_id = s.id and c.active and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())),
    'packs', (select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'description', k.description, 'price', k.price, 'items', k.items,
                    'normal_price', (select coalesce(sum(l.price * (i->>'qty')::int), 0) from jsonb_array_elements(k.items) i join listings l on l.id = (i->>'listing')::uuid))), '[]'::jsonb)
              from shop_packs k where k.shop_id = s.id and k.active),
    'reviews', (select coalesce(jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.reviewer_id), 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
                from (select * from shop_reviews where shop_id = s.id order by created_at desc limit 20) r));
end $$;

create or replace function seller_public(p_name text default null, p_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_p profiles%rowtype; v_n integer;
begin
  if p_id is not null then
    select * into v_p from profiles p where p.id = p_id and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved');
  else
    if nullif(trim(coalesce(p_name, '')), '') is null then return jsonb_build_object('found', false); end if;
    select count(*) into v_n from profiles p where lower(p.name) = lower(trim(p_name))
      and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved');
    if v_n > 1 then return jsonb_build_object('found', false, 'ambiguous', true); end if;
    if v_n = 0 then return jsonb_build_object('found', false); end if;
    select * into v_p from profiles p where lower(p.name) = lower(trim(p_name))
      and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved') limit 1;
  end if;
  if v_p.id is null or coalesce(v_p.suspended, false) then return jsonb_build_object('found', false); end if;
  v_id := v_p.id;
  return jsonb_build_object(
    'found', true,
    'id', v_id,
    'name', v_p.name,
    'department', coalesce(v_p.department, ''),
    'institution', coalesce(v_p.institution, ''),
    'verified', v_p.certification::text = 'approved',
    'since', v_p.created_at,
    'shop_slug', (select s.slug from shops s where s.owner_id = v_id and s.status = 'active' order by s.created_at, s.id limit 1),
    'shop_name', (select s.name from shops s where s.owner_id = v_id and s.status = 'active' order by s.created_at, s.id limit 1),
    'shops', (select coalesce(jsonb_agg(jsonb_build_object('slug', s.slug, 'name', s.name, 'logo_url', s.logo_url) order by s.created_at, s.id), '[]'::jsonb) from shops s where s.owner_id = v_id and s.status = 'active'),
    'products', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category <> 'Services'),
    'services', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category = 'Services'),
    'sales', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = v_id and o.paid and o.cancelled_at is null),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'stars', (select coalesce(jsonb_object_agg(s::text, c), '{}'::jsonb) from (select r.rating s, count(*)::int c from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id group by 1) x)
  );
end $$;

-- Retour arrière : drop function listing_move_shop(uuid, uuid), shop_listings(uuid), listing_shop_move_guard() (+ drop trigger trg_listing_shop_move on listings) ; recréer depuis les fichiers d'origine :
--   listing_shop_guard (20261107000000), _attach_seller_listings (20261117030000), promo_save (20261107000000), flash_save / campaign_save / pack_save / toggles (20261117030000), flash_cancel / my_promotions (20261107000000),
--   seller_orders (20261117040400), set_seller_order_status / seller_confirm_handover (20261119030000), can_review_shop (20261115130000), submit_shop_review / shop_public (20261107000000), seller_public (20261115000100)
--   après avoir supprimé les versions à paramètre p_shop (drop function ... avec la nouvelle signature).
