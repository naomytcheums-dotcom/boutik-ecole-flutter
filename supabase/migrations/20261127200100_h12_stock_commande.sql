-- Lot H12 STOCK (2/2) : commande et annulation tenant compte des variantes (migration 20261127200000).
--  1. _h12_lock_cart : verrous FOR UPDATE ordonnés par identifiant (annonces, puis variantes) AVANT toute écriture d'un panier : deux paniers multi-lignes
--     dans un ordre différent ne peuvent plus s'interbloquer.
--  2. marketplace_checkout : reprise À L'IDENTIQUE de la version G3 (20261119030000) ; seuls changements : verrou ordonné, ligne d'une annonce à variantes
--     (variant_id obligatoire, décrément atomique « stock = stock - q where stock >= q » avec contrôle du nombre de lignes, refus variant_out_of_stock avec
--     la quantité disponible), une ligne de pack dont un composant se vend par variante est refusée. Aucun prix, aucune remise, aucune commission modifié.
--  3. Restitution : un trigger sur orders.cancelled_at (annulation de l'acheteur, expiration des commandes impayées, litige, remboursement) restitue les variantes
--     une seule fois par ligne (order_lines.variant_restocked_at) ; la réservation reste celle du flux actuel : le stock est retenu à la commande et rendu à l'expiration
--     (expire_unpaid_orders : 2 h, ou 48 h si une demande de paiement est ouverte).
-- Additive et rejouable. Retour arrière : drop trigger trg_h12_orders_restock on orders ; drop function _h12_orders_restock(), _h12_lock_cart(jsonb) ;
--   recréer marketplace_checkout depuis 20261119030000_g3_commande_machine_etats.sql.

-- ============================================================ 1. verrou ordonné du panier
create or replace function _h12_lock_cart(p_items jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare v_re constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; v_lids uuid[]; v_vids uuid[];
begin
  select coalesce(array_agg(distinct x.lid), '{}') into v_lids from (
    select case when jsonb_typeof(e) <> 'object' then null
                when e ? 'id' then case when e->>'id' ~ v_re then (e->>'id')::uuid end
                when e ? 'title' then (select id from listings where title = e->>'title' and status = 'approved' order by (seller_id is null) desc limit 1)
           end as lid
    from jsonb_array_elements(p_items) e
    union all
    select case when c->>'listing' ~ v_re then (c->>'listing')::uuid end
    from jsonb_array_elements(p_items) e
    join shop_packs k on jsonb_typeof(e) = 'object' and e ? 'pack' and case when e->>'pack' ~ v_re then k.id = (e->>'pack')::uuid else false end
    cross join lateral jsonb_array_elements(k.items) c
  ) x where x.lid is not null;
  select coalesce(array_agg(distinct (e->>'variant_id')::uuid), '{}') into v_vids
    from jsonb_array_elements(p_items) e where jsonb_typeof(e) = 'object' and e ? 'variant_id' and e->>'variant_id' ~ v_re;
  perform 1 from listings where id = any (v_lids) order by id for update;
  perform 1 from listing_variants where id = any (v_vids) order by id for update;
end $$;
revoke all on function _h12_lock_cart(jsonb) from public, anon, authenticated;

-- ============================================================ 2. marketplace_checkout
create or replace function marketplace_checkout(p_items jsonb, p_home boolean, p_method text, p_address uuid default null, p_code text default null, p_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  o orders%rowtype; st institution_settings%rowtype; adr addresses%rowtype;
  v_fee int := 0; num text; oid uuid; it jsonb; l listings%rowtype; fs flash_sales%rowtype; pk shop_packs%rowtype; pc promo_codes%rowtype; comp jsonb;
  rec record; v_f int; q int; sub int := 0; v_price int; v_reserved int; v_base int; v_disc int := 0; v_normal int; v_unit int; v_cq int; v_share int; v_flash uuid;
  v_skip boolean := false; v_found boolean := false;
  vr listing_variants%rowtype; v_vmode boolean; v_rows integer; v_vre constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_key is not null then
    if char_length(p_key) not between 8 and 80 then raise exception 'Clé d''idempotence invalide'; end if;
    select * into o from orders where buyer_id = uid and idem_key = p_key;
    if found then
      -- seule une commande encore ouverte est rejouée : une commande annulée ou déjà payée laisse place à une nouvelle commande
      if o.cancelled_at is null and not coalesce(o.cancelled, false) and not o.paid then
        return jsonb_build_object('number', o.number, 'subtotal', o.subtotal, 'fee', o.fee, 'discount', o.discount, 'replayed', true);
      end if;
      perform set_config('app.internal', '1', true);
      update orders set idem_key = null where id = o.id;
      perform set_config('app.internal', '', true);
    end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if jsonb_array_length(p_items) > 30 then raise exception 'Panier trop volumineux'; end if;
  if (select count(*) from orders where buyer_id = uid and not paid and cancelled_at is null and not coalesce(cancelled, false)) >= 10 then
    raise exception 'Vous avez déjà 10 commandes en attente : payez-les ou annulez-les avant d''en passer une autre';
  end if;
  if coalesce(p_home, false) then
    select * into st from institution_settings where id = 'iut-douala';
    if not found or not st.home_delivery_enabled then raise exception 'Livraison à domicile non proposée pour le moment : choisissez le retrait sur campus'; end if;
    select * into adr from addresses where id = p_address and user_id = uid;
    if not found then raise exception 'Choisissez une adresse de livraison'; end if;
  end if;
  perform _h12_lock_cart(p_items);
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  perform set_config('app.internal', '1', true);
  perform set_config('app.stock_reason', 'commande', true);
  perform set_config('app.order_number', num, true);
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, delivery_address, idem_key)
    values (num, uid, 0, v_fee, coalesce(nullif(p_method, ''), 'Mobile Money'), 0, false, coalesce(p_home, false),
            case when coalesce(p_home, false) then jsonb_build_object('recipient', adr.recipient, 'phone', adr.phone, 'city', adr.city, 'district', adr.district, 'line', adr.line, 'landmark', adr.landmark) end,
            p_key)
    returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(it) <> 'object' then raise exception 'Panier invalide'; end if;
    if coalesce(it->>'qty', '1') !~ '^[0-9]{1,3}$' then raise exception 'Quantité invalide'; end if;
    q := coalesce((it->>'qty')::int, 1);
    if q < 1 or q > 20 then raise exception 'Quantité invalide'; end if;
    if it ? 'pack' then
      if it->>'pack' !~ '^[0-9a-fA-F-]{36}$' then raise exception 'Pack indisponible'; end if;
      select * into pk from shop_packs where id = (it->>'pack')::uuid and active;
      if not found or not exists (select 1 from shops where id = pk.shop_id and status = 'active') then raise exception 'Pack indisponible'; end if;
      select sum(x.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(pk.items) i join listings x on x.id = (i->>'listing')::uuid;
      if coalesce(v_normal, 0) <= 0 then raise exception 'Pack indisponible'; end if;
      for comp in select * from jsonb_array_elements(pk.items) loop
        v_cq := (comp->>'qty')::int;
        select * into l from listings where id = (comp->>'listing')::uuid and status = 'approved' for update;
        if not found then raise exception 'Pack indisponible : composant retiré'; end if;
        if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
        if l.seller_id is not null and exists (select 1 from profiles where id = l.seller_id and suspended) then raise exception 'Vendeur indisponible : %', l.title; end if;
        if offer_type_of(l.category) = 'service' then raise exception 'Ce service se commande sur devis : %', l.title; end if;
        if exists (select 1 from listing_variants where listing_id = l.id and active) then raise exception 'Pack indisponible : « % » se vend par variante (variant_required)', l.title; end if;
        select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
        if l.stock - q * v_cq < v_reserved then raise exception 'Stock insuffisant : %', l.title; end if;
        update listings set stock = stock - q * v_cq where id = l.id and stock >= q * v_cq;
        if not found then raise exception 'Stock insuffisant : %', l.title; end if;
        v_share := (pk.price::bigint * (l.price * v_cq) / v_normal)::int;
        v_unit := greatest(v_share / v_cq, 1);
        insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id) values (oid, l.id, l.title, v_unit, q * v_cq, l.shop_id);
        sub := sub + v_unit * q * v_cq;
      end loop;
      continue;
    end if;
    if it ? 'id' then
      if it->>'id' !~ '^[0-9a-fA-F-]{36}$' then raise exception 'Produit indisponible'; end if;
      select * into l from listings where id = (it->>'id')::uuid and status = 'approved' for update;
    else
      select * into l from listings where id = (select id from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1) for update;
    end if;
    if not found then raise exception 'Produit indisponible : %', coalesce(it->>'title', it->>'id'); end if;
    if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
    if l.seller_id is not null and exists (select 1 from profiles where id = l.seller_id and suspended) then raise exception 'Vendeur indisponible : %', l.title; end if;
    if offer_type_of(l.category) = 'service' then raise exception 'Ce service se commande sur devis : %', l.title; end if;
    if l.shop_id is not null and not exists (select 1 from shops where id = l.shop_id and status = 'active') then raise exception 'Boutique indisponible : %', l.title; end if;
    v_vmode := exists (select 1 from listing_variants where listing_id = l.id and active);
    if v_vmode then
      if coalesce(it->>'variant_id', '') !~ v_vre then raise exception 'Choisissez une variante pour « % » (variant_required)', l.title; end if;
      select * into vr from listing_variants where id = (it->>'variant_id')::uuid and listing_id = l.id and active for update;
      if not found then raise exception 'Cette variante de « % » n''est plus proposée : choisissez-en une autre (variant_unavailable)', l.title; end if;
      if vr.stock < q then
        raise exception 'Stock insuffisant pour « % — % » : % disponible(s) (variant_out_of_stock)', l.title, vr.label, vr.stock
          using detail = jsonb_build_object('code', 'variant_out_of_stock', 'available', vr.stock, 'requested', q, 'variant_id', vr.id)::text;
      end if;
    elsif coalesce(it->>'variant_id', '') <> '' then
      raise exception 'Cette variante de « % » n''est plus proposée (variant_unavailable)', l.title;
    elsif l.stock < q then
      raise exception 'Stock insuffisant : %', l.title;
    end if;
    v_price := l.price; v_flash := null;
    select * into fs from flash_sales where listing_id = l.id and not cancelled and starts_at <= now() and ends_at > now() and sold + q <= stock order by sale_price limit 1 for update;
    if found then
      v_price := fs.sale_price; v_flash := fs.id;
      update flash_sales set sold = sold + q where id = fs.id;
    else
      select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
      if l.stock - q < v_reserved then raise exception 'Stock insuffisant : % (le reste est réservé à une vente flash)', l.title; end if;
    end if;
    if v_vmode then
      -- décrément atomique de la variante ; le stock de l'annonce suit (somme des variantes actives)
      update listing_variants set stock = stock - q where id = vr.id and stock >= q;
      get diagnostics v_rows = row_count;
      if v_rows <> 1 then
        select stock into v_rows from listing_variants where id = vr.id;
        raise exception 'Stock insuffisant pour « % — % » : % disponible(s) (variant_out_of_stock)', l.title, vr.label, coalesce(v_rows, 0)
          using detail = jsonb_build_object('code', 'variant_out_of_stock', 'available', coalesce(v_rows, 0), 'requested', q, 'variant_id', vr.id)::text;
      end if;
      insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id, variant, flash_id, variant_id)
        values (oid, l.id, l.title, v_price, q, l.shop_id, left(vr.label, 80), v_flash, vr.id);
    else
      update listings set stock = stock - q where id = l.id and stock >= q;
      if not found then raise exception 'Stock insuffisant : %', l.title; end if;
      insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id, variant, flash_id)
        values (oid, l.id, l.title, v_price, q, l.shop_id, nullif(left(coalesce(it->>'variant', ''), 80), ''), v_flash);
    end if;
    sub := sub + v_price * q;
  end loop;
  if coalesce(p_home, false) then
    for rec in select l2.seller_id as sid, _seller_city(l2) as from_city, coalesce(sh.name, display_name(l2.seller_id), 'Boutik-École') as nm
               from order_lines ol join listings l2 on l2.id = ol.listing_id left join shops sh on sh.id = l2.shop_id
               where ol.order_id = oid group by l2.seller_id, _seller_city(l2), coalesce(sh.name, display_name(l2.seller_id), 'Boutik-École') loop
      v_f := _delivery_fee_for(rec.sid, rec.from_city, adr.city);
      if v_f is null then raise exception 'Livraison vers % non proposée par % : choisissez le retrait ou une autre adresse', adr.city, rec.nm; end if;
      v_fee := v_fee + v_f;
    end loop;
    update orders set fee = v_fee where id = oid;
  end if;
  if nullif(trim(coalesce(p_code, '')), '') is not null then
    select * into pc from promo_codes where code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g')) for update;
    v_found := found;
    if not v_found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
      if v_found and pc.auto_apply then v_skip := true; else raise exception 'Code promo invalide ou expiré'; end if;
    end if;
    if not v_skip then
      if not pc.auto_apply and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = uid) then raise exception 'Code promo déjà utilisé'; end if;
      select coalesce(sum(unit_price * qty), 0) into v_base from order_lines where order_id = oid and flash_id is null and (pc.shop_id is null or shop_id = pc.shop_id);
      if v_base = 0 or v_base < pc.min_amount then
        if pc.auto_apply then v_skip := true;
        else raise exception 'Ce code ne s''applique pas à votre panier (montant minimum % FCFA sur la boutique concernée)', pc.min_amount; end if;
      end if;
    end if;
    if not v_skip then
      v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
      v_disc := least(v_disc, greatest(sub - 500, 0));
      if not pc.auto_apply then
        update promo_codes set used_count = used_count + 1 where id = pc.id;
        insert into promo_redemptions (code_id, user_id, order_id) values (pc.id, uid, oid);
      end if;
    end if;
  end if;
  update orders set subtotal = sub - v_disc, discount = v_disc, promo_code = case when v_skip then null else pc.code end where id = oid;
  perform set_config('app.internal', '', true);
  perform set_config('app.stock_reason', '', true);
  perform set_config('app.order_number', '', true);
  return jsonb_build_object('number', num, 'subtotal', sub - v_disc, 'fee', v_fee, 'discount', v_disc, 'replayed', false);
end $$;
revoke all on function marketplace_checkout(jsonb, boolean, text, uuid, text, text) from public, anon;
grant execute on function marketplace_checkout(jsonb, boolean, text, uuid, text, text) to authenticated;

-- ============================================================ 3. restitution des variantes à l'annulation (une seule fois par ligne)
create or replace function _h12_orders_restock() returns trigger
language plpgsql security definer set search_path = public as $$
declare ln record; v_reason text; v_prev_reason text := coalesce(current_setting('app.stock_reason', true), ''); v_prev_num text := coalesce(current_setting('app.order_number', true), '');
begin
  if old.cancelled_at is not null or new.cancelled_at is null then return null; end if;
  if not exists (select 1 from order_lines where order_id = new.id and variant_id is not null and variant_restocked_at is null) then return null; end if;
  perform 1 from listings where id in (select listing_id from order_lines where order_id = new.id and variant_id is not null and variant_restocked_at is null) order by id for update;
  perform 1 from listing_variants where id in (select variant_id from order_lines where order_id = new.id and variant_id is not null and variant_restocked_at is null) order by id for update;
  v_reason := case when exists (select 1 from order_refunds where order_id = new.id and status in ('approved', 'refunded')) then 'remboursement' else 'annulation' end;
  perform set_config('app.stock_reason', v_reason, true);
  perform set_config('app.order_number', new.number, true);
  for ln in select id, variant_id, qty from order_lines where order_id = new.id and variant_id is not null and variant_restocked_at is null order by variant_id, id loop
    update order_lines set variant_restocked_at = now() where id = ln.id and variant_restocked_at is null;
    if found then update listing_variants set stock = least(stock + ln.qty, 100000) where id = ln.variant_id; end if;
  end loop;
  perform set_config('app.stock_reason', v_prev_reason, true);
  perform set_config('app.order_number', v_prev_num, true);
  return null;
end $$;
revoke all on function _h12_orders_restock() from public, anon, authenticated;
drop trigger if exists trg_h12_orders_restock on orders;
create trigger trg_h12_orders_restock after update of cancelled_at on orders for each row execute function _h12_orders_restock();
