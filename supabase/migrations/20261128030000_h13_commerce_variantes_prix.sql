-- Lot H13 COMMERCE (1/3) : variantes complètes (prix propre OPTIONNEL, image, caractéristiques), commande qui lit ce prix, vérification de panier par boutique.
--  1. listing_variants.price (nullable) : prix propre de la variante, fixé par le vendeur dans les mêmes bornes que le prix d'une annonce de produit (500 à 100 000 000 FCFA).
--     NULL = la variante se vend au prix de l'annonce (comportement H12 inchangé). Aucune commission, aucun barème, aucune règle d'arrondi n'est créé ou modifié :
--     la répartition (money_order_paid / money_split_amounts) lit unit_price × qty des lignes de commande, comme avant.
--  2. listing_variants.image : chemin d'une image déjà déposée dans le bucket public « listing-images » (dossier du vendeur) ; RPC variant_details_save (prix + image,
--     propriétaire seulement, audité) et variant_upsert (création/modification + prix + image en une seule transaction).
--  3. _variant_json : price, effective_price, image ; pour le vendeur, « reserved » = quantité retenue par des commandes non payées.
--  4. marketplace_checkout : reprise À L'IDENTIQUE de la version H12 (20261127200100) ; changements : prix de ligne = prix de la variante s'il existe, sinon prix de l'annonce
--     (une ligne à prix propre n'est pas soumise à une vente flash de l'annonce : le prix flash est celui de l'annonce) ; double envoi simultané de la même clé d'idempotence =
--     la commande déjà créée est rejouée (plus d'erreur brute de clé en double).
--  5. promo_preview : même prix de ligne que la commande (variante à prix propre).
--  6. cart_check(p_items) : contrôle sans écriture, ligne par ligne, avec le nom de la boutique, le code (out_of_stock, variant_required, ...) et la quantité disponible ;
--     la commande reste atomique : si une seule ligne est refusée, rien n'est créé.
-- Additive et rejouable. Retour arrière : drop function cart_check(jsonb), variant_upsert(...), variant_details_save(...) ; recréer marketplace_checkout depuis 20261127200100,
--   promo_preview depuis 20261115150000, _variant_json depuis 20261127200000 ; alter table listing_variants drop column price, drop column image.

-- ============================================================ 1. colonnes
alter table listing_variants add column if not exists price integer;
alter table listing_variants add column if not exists image text;
alter table listing_variants drop constraint if exists listing_variants_price_range;
alter table listing_variants add constraint listing_variants_price_range check (price is null or (price >= 500 and price <= 100000000));
alter table listing_variants drop constraint if exists listing_variants_image_len;
alter table listing_variants add constraint listing_variants_image_len check (image is null or char_length(image) between 3 and 300);

-- ============================================================ 2. représentation JSON
create or replace function _variant_json(v listing_variants, p_exact boolean) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('id', v.id, 'listing_id', v.listing_id, 'label', v.label, 'attributes', v.attributes, 'active', v.active,
           'state', case when v.stock = 0 then 'out' when v.stock <= v.low_threshold then 'low' else 'available' end,
           'price', v.price, 'image', v.image,
           'effective_price', coalesce(v.price, (select l.price from listings l where l.id = v.listing_id)))
         || case when p_exact then jsonb_build_object('sku', v.sku, 'stock', v.stock, 'low_threshold', v.low_threshold, 'position', v.position,
              'reserved', (select coalesce(sum(ol.qty), 0)::int from order_lines ol join orders o on o.id = ol.order_id
                           where ol.variant_id = v.id and not o.paid and not coalesce(o.cod, false) and o.cancelled_at is null and not coalesce(o.cancelled, false)))
            else '{}'::jsonb end
$$;
revoke all on function _variant_json(listing_variants, boolean) from public, anon, authenticated;

-- ============================================================ 3. prix et image d'une variante
create or replace function variant_details_save(p_id uuid, p_price integer default null, p_clear_price boolean default false, p_image text default null, p_clear_image boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v listing_variants%rowtype; l listings%rowtype; v_img text := nullif(btrim(coalesce(p_image, '')), ''); v_who text; v_old integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select listing_id into v.listing_id from listing_variants where id = p_id;
  if not found then raise exception 'Variante introuvable'; end if;
  l := _variant_owner_listing(v.listing_id);
  select * into v from listing_variants where id = p_id for update;
  v_old := v.price;
  if coalesce(p_clear_price, false) and p_price is not null then raise exception 'Indiquez un prix ou retirez-le, pas les deux'; end if;
  if coalesce(p_clear_image, false) and v_img is not null then raise exception 'Indiquez une image ou retirez-la, pas les deux'; end if;
  if coalesce(p_clear_price, false) then
    v.price := null;
  elsif p_price is not null then
    if p_price < 500 or p_price > 100000000 then raise exception 'Prix de la variante : de 500 à 100 000 000 FCFA (laissez vide pour garder le prix de l''annonce)'; end if;
    v.price := p_price;
  end if;
  if coalesce(p_clear_image, false) then
    v.image := null;
  elsif v_img is not null then
    if v_img !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/([A-Za-z0-9._ -]{1,80}/){0,2}[A-Za-z0-9._ -]{1,150}\.(jpg|jpeg|png|webp)$' or v_img like '%..%' or split_part(v_img, '/', 1) <> auth.uid()::text then
      raise exception 'Image invalide : choisissez une image envoyée depuis votre compte (jpg, png ou webp)';
    end if;
    if not exists (select 1 from storage.objects o where o.bucket_id = 'listing-images' and o.name = v_img) then raise exception 'Image introuvable : envoyez-la d''abord'; end if;
    v.image := v_img;
  end if;
  update listing_variants set price = v.price, image = v.image where id = v.id returning * into v;
  if v.price is distinct from v_old then
    select name into v_who from profiles where id = auth.uid();
    insert into audit_log (actor, actor_id, action, target, category, level)
    values (coalesce(v_who, 'Utilisateur'), auth.uid(), left('Prix de variante : ' || l.title || ' — ' || v.label || ' : ' || coalesce(v_old::text, 'prix de l''annonce') || ' → ' || coalesce(v.price::text, 'prix de l''annonce'), 120), v.id::text, 'Marketplace', 'Normal');
  end if;
  return _variant_json(v, true);
end $$;
revoke all on function variant_details_save(uuid, integer, boolean, text, boolean) from public, anon;
grant execute on function variant_details_save(uuid, integer, boolean, text, boolean) to authenticated;

-- Création ou modification complète (libellé, critères, SKU, stock, seuil, prix, image) en UNE transaction : un refus annule tout.
create or replace function variant_upsert(p_listing uuid, p_label text, p_attributes jsonb default '{}'::jsonb, p_sku text default null, p_stock integer default null, p_threshold integer default 3, p_id uuid default null,
                                          p_price integer default null, p_clear_price boolean default false, p_image text default null, p_clear_image boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := variant_save(p_listing, p_label, p_attributes, p_sku, p_stock, p_threshold, p_id);
  if p_price is not null or coalesce(p_clear_price, false) or nullif(btrim(coalesce(p_image, '')), '') is not null or coalesce(p_clear_image, false) then
    r := variant_details_save((r->>'id')::uuid, p_price, p_clear_price, p_image, p_clear_image);
  end if;
  return r;
end $$;
revoke all on function variant_upsert(uuid, text, jsonb, text, integer, integer, uuid, integer, boolean, text, boolean) from public, anon;
grant execute on function variant_upsert(uuid, text, jsonb, text, integer, integer, uuid, integer, boolean, text, boolean) to authenticated;

-- ============================================================ 4. marketplace_checkout
create or replace function marketplace_checkout(p_items jsonb, p_home boolean, p_method text, p_address uuid default null, p_code text default null, p_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  o orders%rowtype; st institution_settings%rowtype; adr addresses%rowtype;
  v_fee int := 0; num text; oid uuid; it jsonb; l listings%rowtype; fs flash_sales%rowtype; pk shop_packs%rowtype; pc promo_codes%rowtype; comp jsonb;
  rec record; v_f int; q int; sub int := 0; v_price int; v_reserved int; v_base int; v_disc int := 0; v_normal int; v_unit int; v_cq int; v_share int; v_flash uuid;
  v_skip boolean := false; v_found boolean := false;
  vr listing_variants%rowtype; v_vmode boolean; v_rows integer; v_own boolean; v_has_fs boolean; v_vre constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
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
  begin
    insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, delivery_address, idem_key)
      values (num, uid, 0, v_fee, coalesce(nullif(p_method, ''), 'Mobile Money'), 0, false, coalesce(p_home, false),
              case when coalesce(p_home, false) then jsonb_build_object('recipient', adr.recipient, 'phone', adr.phone, 'city', adr.city, 'district', adr.district, 'line', adr.line, 'landmark', adr.landmark) end,
              p_key)
      returning id into oid;
  exception when unique_violation then
    -- double envoi simultané de la même clé : la commande de l'autre envoi est rejouée
    select * into o from orders where buyer_id = uid and idem_key = p_key;
    if not found then raise; end if;
    perform set_config('app.internal', '', true);
    perform set_config('app.stock_reason', '', true);
    perform set_config('app.order_number', '', true);
    return jsonb_build_object('number', o.number, 'subtotal', o.subtotal, 'fee', o.fee, 'discount', o.discount, 'replayed', true);
  end;
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
    v_own := false;
    if v_vmode then
      if coalesce(it->>'variant_id', '') !~ v_vre then raise exception 'Choisissez une variante pour « % » (variant_required)', l.title; end if;
      select * into vr from listing_variants where id = (it->>'variant_id')::uuid and listing_id = l.id and active for update;
      if not found then raise exception 'Cette variante de « % » n''est plus proposée : choisissez-en une autre (variant_unavailable)', l.title; end if;
      if vr.stock < q then
        raise exception 'Stock insuffisant pour « % — % » : % disponible(s) (variant_out_of_stock)', l.title, vr.label, vr.stock
          using detail = jsonb_build_object('code', 'variant_out_of_stock', 'available', vr.stock, 'requested', q, 'variant_id', vr.id)::text;
      end if;
      v_own := vr.price is not null;
    elsif coalesce(it->>'variant_id', '') <> '' then
      raise exception 'Cette variante de « % » n''est plus proposée (variant_unavailable)', l.title;
    elsif l.stock < q then
      raise exception 'Stock insuffisant : %', l.title;
    end if;
    -- prix de ligne : celui de la variante quand le vendeur en a fixé un, sinon celui de l'annonce
    v_price := case when v_own then vr.price else l.price end; v_flash := null; v_has_fs := false;
    if not v_own then
      select * into fs from flash_sales where listing_id = l.id and not cancelled and starts_at <= now() and ends_at > now() and sold + q <= stock order by sale_price limit 1 for update;
      v_has_fs := found;
    end if;
    if v_has_fs then
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

-- ============================================================ 5. promo_preview : même prix de ligne que la commande
create or replace function promo_preview(p_code text, p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pc promo_codes%rowtype; it jsonb; comp jsonb; l listings%rowtype; pk shop_packs%rowtype;
  v_base int := 0; v_disc int; v_sub int := 0; q int; v_normal bigint; v_cq int; v_unit int; v_vprice integer;
begin
  select * into pc from promo_codes where code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
    return jsonb_build_object('valid', false, 'message', 'Code promo invalide ou expiré');
  end if;
  if not pc.auto_apply and auth.uid() is not null and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = auth.uid()) then return jsonb_build_object('valid', false, 'message', 'Code promo déjà utilisé'); end if;
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it->>'qty')::int, 1), 1), 20);
    if it ? 'pack' then
      select * into pk from shop_packs where id = (it->>'pack')::uuid and active;
      if found then
        select sum(x.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(pk.items) i join listings x on x.id = (i->>'listing')::uuid;
        if coalesce(v_normal, 0) > 0 then
          for comp in select * from jsonb_array_elements(pk.items) loop
            v_cq := (comp->>'qty')::int;
            select * into l from listings where id = (comp->>'listing')::uuid;
            if found and v_cq > 0 then
              v_unit := greatest((pk.price::bigint * (l.price * v_cq) / v_normal)::int / v_cq, 1);
              v_sub := v_sub + v_unit * q * v_cq;
              if pc.shop_id is null or l.shop_id = pc.shop_id then v_base := v_base + v_unit * q * v_cq; end if;
            end if;
          end loop;
        end if;
      end if;
      continue;
    end if;
    select * into l from listings where status = 'approved' and ((it ? 'id' and id = (it->>'id')::uuid) or (not it ? 'id' and title = it->>'title')) limit 1;
    if found then
      v_vprice := null;
      if coalesce(it->>'variant_id', '') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
        select price into v_vprice from listing_variants where id = (it->>'variant_id')::uuid and listing_id = l.id and active;
      end if;
      v_sub := v_sub + coalesce(v_vprice, l.price) * q;
      if (pc.shop_id is null or l.shop_id = pc.shop_id)
         and (v_vprice is not null or not exists (select 1 from flash_sales f where f.listing_id = l.id and not f.cancelled and f.starts_at <= now() and f.ends_at > now())) then
        v_base := v_base + coalesce(v_vprice, l.price) * q;
      end if;
    end if;
  end loop;
  if v_base = 0 or v_base < pc.min_amount then return jsonb_build_object('valid', false, 'message', 'Ce code ne s''applique pas à votre panier'); end if;
  v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
  return jsonb_build_object('valid', true, 'discount', least(v_disc, greatest(v_sub - 500, 0)), 'code', pc.code);
end $$;
revoke all on function promo_preview(text, jsonb) from public;
grant execute on function promo_preview(text, jsonb) to anon, authenticated;

-- ============================================================ 6. cart_check : contrôle ligne par ligne, sans écriture
create or replace function cart_check(p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); it jsonb; comp jsonb; n integer := 0; l listings%rowtype; vr listing_variants%rowtype; pk shop_packs%rowtype; q integer;
  v_lines jsonb := '[]'::jsonb; v_code text; v_msg text; v_title text; v_own boolean; v_avail integer; v_price integer; v_shop text; v_reserved integer; v_vmode boolean; v_ok boolean := true;
  v_re constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if jsonb_array_length(p_items) > 30 then raise exception 'Panier trop volumineux'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    n := n + 1; v_code := null; v_msg := null; v_avail := null; v_price := null; v_shop := null; q := 1; v_own := false; v_title := case when jsonb_typeof(it) = 'object' then it->>'title' end;
    if jsonb_typeof(it) <> 'object' then
      v_code := 'invalid'; v_msg := 'Ligne de panier invalide';
    elsif coalesce(it->>'qty', '1') !~ '^[0-9]{1,3}$' or coalesce((it->>'qty')::int, 1) not between 1 and 20 then
      v_code := 'invalid_qty'; v_msg := 'Quantité invalide (1 à 20)';
    else
      q := coalesce((it->>'qty')::int, 1);
      if it ? 'pack' then
        select * into pk from shop_packs where case when it->>'pack' ~ v_re then id = (it->>'pack')::uuid else false end and active;
        if not found or not exists (select 1 from shops where id = pk.shop_id and status = 'active') then
          v_code := 'pack_unavailable'; v_msg := 'Pack indisponible';
        else
          select coalesce(name, 'Boutik-École') into v_shop from shops where id = pk.shop_id;
          v_price := pk.price; v_title := coalesce(v_title, 'Pack');
          for comp in select * from jsonb_array_elements(pk.items) loop
            select * into l from listings where id = (comp->>'listing')::uuid and status = 'approved';
            if not found then v_code := 'pack_unavailable'; v_msg := 'Pack indisponible : composant retiré'; exit; end if;
            if exists (select 1 from listing_variants where listing_id = l.id and active) then v_code := 'variant_required'; v_msg := 'Pack indisponible : « ' || l.title || ' » se vend par variante'; exit; end if;
            if l.stock < q * (comp->>'qty')::int then v_code := 'out_of_stock'; v_avail := l.stock; v_msg := 'Stock insuffisant : ' || l.title; exit; end if;
          end loop;
        end if;
      else
        if it ? 'id' then
          select * into l from listings where case when it->>'id' ~ v_re then id = (it->>'id')::uuid else false end and status = 'approved';
        else
          select * into l from listings where id = (select id from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1);
        end if;
        if not found then
          v_code := 'unavailable'; v_msg := 'Produit indisponible : ' || coalesce(it->>'title', it->>'id', '?');
        else
          select coalesce(sh.name, display_name(l.seller_id), 'Boutik-École') into v_shop from (select 1) z left join shops sh on sh.id = l.shop_id;
          v_price := l.price; v_title := l.title;
          if l.seller_id = uid then v_code := 'own_product'; v_msg := 'Vous ne pouvez pas acheter votre propre produit';
          elsif l.seller_id is not null and exists (select 1 from profiles where id = l.seller_id and suspended) then v_code := 'seller_unavailable'; v_msg := 'Vendeur indisponible : ' || l.title;
          elsif offer_type_of(l.category) = 'service' then v_code := 'quote_only'; v_msg := 'Ce service se commande sur devis : ' || l.title;
          elsif l.shop_id is not null and not exists (select 1 from shops where id = l.shop_id and status = 'active') then v_code := 'shop_unavailable'; v_msg := 'Boutique indisponible : ' || l.title;
          else
            v_vmode := exists (select 1 from listing_variants where listing_id = l.id and active);
            if v_vmode then
              if coalesce(it->>'variant_id', '') !~ v_re then
                v_code := 'variant_required'; v_msg := 'Choisissez une variante pour « ' || l.title || ' »';
              else
                select * into vr from listing_variants where id = (it->>'variant_id')::uuid and listing_id = l.id and active;
                if not found then v_code := 'variant_unavailable'; v_msg := 'Cette variante de « ' || l.title || ' » n''est plus proposée';
                else
                  v_price := coalesce(vr.price, l.price); v_avail := vr.stock; v_own := vr.price is not null;
                  if vr.stock < q then v_code := 'out_of_stock'; v_msg := 'Stock insuffisant pour « ' || l.title || ' — ' || vr.label || ' » : ' || vr.stock || ' disponible(s)'; end if;
                end if;
              end if;
            elsif coalesce(it->>'variant_id', '') <> '' then
              v_code := 'variant_unavailable'; v_msg := 'Cette variante de « ' || l.title || ' » n''est plus proposée';
            else
              v_avail := l.stock;
              if l.stock < q then v_code := 'out_of_stock'; v_msg := 'Stock insuffisant : ' || l.title || ' (' || l.stock || ' disponible(s))'; end if;
            end if;
            if v_code is null then
              select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
              if l.stock - q < v_reserved and (v_own or not exists (select 1 from flash_sales f where f.listing_id = l.id and not f.cancelled and f.starts_at <= now() and f.ends_at > now() and f.sold + q <= f.stock)) then
                v_code := 'out_of_stock'; v_msg := 'Stock insuffisant : ' || l.title || ' (le reste est réservé à une vente flash)';
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
    if v_code is not null then v_ok := false; end if;
    v_lines := v_lines || jsonb_build_object('index', n - 1, 'title', v_title, 'shop', v_shop, 'qty', q, 'ok', v_code is null,
                                             'code', v_code, 'message', v_msg, 'available', v_avail, 'unit_price', v_price);
  end loop;
  return jsonb_build_object('ok', v_ok, 'lines', v_lines,
    'shops', coalesce((select jsonb_agg(jsonb_build_object('shop', s.shop, 'lines', s.n, 'subtotal_estimate', s.sub, 'ok', s.ok) order by s.shop)
                       from (select coalesce(x->>'shop', 'Boutik-École') as shop, count(*)::int as n, coalesce(sum((x->>'unit_price')::int * (x->>'qty')::int) filter (where (x->>'ok')::boolean), 0)::int as sub, bool_and((x->>'ok')::boolean) as ok
                             from jsonb_array_elements(v_lines) x group by 1) s), '[]'::jsonb));
end $$;
revoke all on function cart_check(jsonb) from public, anon;
grant execute on function cart_check(jsonb) to authenticated;
