-- Promotions de la plateforme (Nouvel An, Pâques, fête du travail…) créées par l'administrateur, avec une période et une réduction.
-- Une promotion « automatique » s'applique d'elle-même à chaque commande pendant sa période : le champ du code promo est alors rempli et verrouillé.
-- Retour arrière : drop function platform_promo_save(text, text, text, integer, timestamptz, timestamptz, integer, boolean, boolean), platform_promos(), platform_promo_toggle(uuid, boolean), active_auto_promo();
--                   alter table promo_codes drop column label, drop column auto_apply; puis recréer marketplace_checkout et promo_preview depuis 20261107000000_marketplace.sql.

alter table promo_codes add column if not exists label text check (label is null or char_length(label) <= 60);
alter table promo_codes add column if not exists auto_apply boolean not null default false;

create or replace function marketplace_checkout(p_items jsonb, p_home boolean, p_method text, p_address uuid default null, p_code text default null, p_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  o orders%rowtype; st institution_settings%rowtype; adr addresses%rowtype;
  v_fee int := 0; num text; oid uuid; it jsonb; l listings%rowtype; fs flash_sales%rowtype; pk shop_packs%rowtype; pc promo_codes%rowtype; comp jsonb;
  q int; sub int := 0; v_price int; v_reserved int; v_base int; v_disc int := 0; v_normal int; v_unit int; v_cq int; v_share int; v_flash uuid;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_key is not null then
    if char_length(p_key) not between 8 and 80 then raise exception 'Clé d''idempotence invalide'; end if;
    select * into o from orders where buyer_id = uid and idem_key = p_key;
    if found then return jsonb_build_object('number', o.number, 'subtotal', o.subtotal, 'fee', o.fee, 'discount', o.discount, 'replayed', true); end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if jsonb_array_length(p_items) > 30 then raise exception 'Panier trop volumineux'; end if;
  if coalesce(p_home, false) then
    select * into st from institution_settings where id = 'iut-douala';
    if not found or not st.home_delivery_enabled then raise exception 'Livraison à domicile non proposée pour le moment : choisissez le retrait sur campus'; end if;
    select * into adr from addresses where id = p_address and user_id = uid;
    if not found then raise exception 'Choisissez une adresse de livraison'; end if;
    if lower(trim(adr.city)) <> lower(trim(st.home_delivery_city)) then raise exception 'Livraison à domicile proposée seulement à %', st.home_delivery_city; end if;
    v_fee := st.home_delivery_fee;
  end if;
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
    q := coalesce((it->>'qty')::int, 1);
    if q < 1 or q > 20 then raise exception 'Quantité invalide'; end if;
    if it ? 'pack' then
      select * into pk from shop_packs where id = (it->>'pack')::uuid and active;
      if not found or not exists (select 1 from shops where id = pk.shop_id and status = 'active') then raise exception 'Pack indisponible'; end if;
      select sum(x.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(pk.items) i join listings x on x.id = (i->>'listing')::uuid;
      for comp in select * from jsonb_array_elements(pk.items) loop
        v_cq := (comp->>'qty')::int;
        select * into l from listings where id = (comp->>'listing')::uuid and status = 'approved' for update;
        if not found then raise exception 'Pack indisponible : composant retiré'; end if;
        if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
        select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
        if l.stock - q * v_cq < v_reserved then raise exception 'Stock insuffisant : %', l.title; end if;
        update listings set stock = stock - q * v_cq where id = l.id and stock >= q * v_cq;
        if not found then raise exception 'Stock insuffisant : %', l.title; end if;
        v_share := (pk.price::bigint * (l.price * v_cq) / v_normal)::int;           -- part du prix du pack, au prorata (arrondi au franc inférieur)
        v_unit := greatest(v_share / v_cq, 1);
        insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id) values (oid, l.id, l.title, v_unit, q * v_cq, l.shop_id);
        sub := sub + v_unit * q * v_cq;
      end loop;
      continue;
    end if;
    if it ? 'id' then
      select * into l from listings where id = (it->>'id')::uuid and status = 'approved' for update;
    else
      select * into l from listings where id = (select id from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1) for update;
    end if;
    if not found then raise exception 'Produit indisponible : %', coalesce(it->>'title', it->>'id'); end if;
    if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
    if l.shop_id is not null and not exists (select 1 from shops where id = l.shop_id and status = 'active') then raise exception 'Boutique indisponible : %', l.title; end if;
    if l.stock < q then raise exception 'Stock insuffisant : %', l.title; end if;
    v_price := l.price; v_flash := null;
    select * into fs from flash_sales where listing_id = l.id and not cancelled and starts_at <= now() and ends_at > now() and sold + q <= stock order by sale_price limit 1 for update;
    if found then
      v_price := fs.sale_price; v_flash := fs.id;
      update flash_sales set sold = sold + q where id = fs.id;
    else
      select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
      if l.stock - q < v_reserved then raise exception 'Stock insuffisant : % (le reste est réservé à une vente flash)', l.title; end if;
    end if;
    update listings set stock = stock - q where id = l.id and stock >= q;
    if not found then raise exception 'Stock insuffisant : %', l.title; end if;
    insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id, variant, flash_id)
      values (oid, l.id, l.title, v_price, q, l.shop_id, nullif(left(coalesce(it->>'variant', ''), 80), ''), v_flash);
    sub := sub + v_price * q;
  end loop;
  if nullif(trim(coalesce(p_code, '')), '') is not null then
    select * into pc from promo_codes where code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g')) for update;
    if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
      raise exception 'Code promo invalide ou expiré';
    end if;
    if not pc.auto_apply and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = uid) then raise exception 'Code promo déjà utilisé'; end if;
    select coalesce(sum(unit_price * qty), 0) into v_base from order_lines where order_id = oid and flash_id is null and (pc.shop_id is null or shop_id = pc.shop_id);
    if v_base = 0 or v_base < pc.min_amount then raise exception 'Ce code ne s''applique pas à votre panier (montant minimum % FCFA sur la boutique concernée)', pc.min_amount; end if;
    v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
    v_disc := least(v_disc, greatest(sub - 500, 0));
    if not pc.auto_apply then
      update promo_codes set used_count = used_count + 1 where id = pc.id;
      insert into promo_redemptions (code_id, user_id, order_id) values (pc.id, uid, oid);
    end if;
  end if;
  update orders set subtotal = sub - v_disc, discount = v_disc, promo_code = pc.code where id = oid;
  perform set_config('app.internal', '', true);
  perform set_config('app.stock_reason', '', true);
  perform set_config('app.order_number', '', true);
  return jsonb_build_object('number', num, 'subtotal', sub - v_disc, 'fee', v_fee, 'discount', v_disc, 'replayed', false);
end $$;

create or replace function promo_preview(p_code text, p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pc promo_codes%rowtype; it jsonb; l listings%rowtype; v_base int := 0; v_disc int; v_sub int := 0; q int;
begin
  select * into pc from promo_codes where code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
    return jsonb_build_object('valid', false, 'message', 'Code promo invalide ou expiré');
  end if;
  if not pc.auto_apply and auth.uid() is not null and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = auth.uid()) then return jsonb_build_object('valid', false, 'message', 'Code promo déjà utilisé'); end if;
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it->>'qty')::int, 1), 1), 20);
    select * into l from listings where status = 'approved' and ((it ? 'id' and id = (it->>'id')::uuid) or (not it ? 'id' and title = it->>'title')) limit 1;
    if found then
      v_sub := v_sub + l.price * q;
      if (pc.shop_id is null or l.shop_id = pc.shop_id) and not exists (select 1 from flash_sales f where f.listing_id = l.id and not f.cancelled and f.starts_at <= now() and f.ends_at > now()) then v_base := v_base + l.price * q; end if;
    end if;
  end loop;
  if v_base = 0 or v_base < pc.min_amount then return jsonb_build_object('valid', false, 'message', 'Ce code ne s''applique pas à votre panier'); end if;
  v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
  return jsonb_build_object('valid', true, 'discount', least(v_disc, greatest(v_sub - 500, 0)), 'code', pc.code);
end $$;

-- Création ou mise à jour d'une promotion de la plateforme (réservé à l'administration).
create or replace function platform_promo_save(p_label text, p_code text, p_kind text, p_value integer, p_starts timestamptz, p_ends timestamptz,
  p_min integer default 0, p_auto boolean default true, p_active boolean default true) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); v_id uuid; v_label text := nullif(trim(coalesce(p_label, '')), '');
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  if v_label is null or char_length(v_label) < 3 then raise exception 'Donnez un nom à la promotion (3 caractères minimum)'; end if;
  if v_code !~ '^[A-Z0-9]{3,20}$' then raise exception 'Code de 3 à 20 lettres ou chiffres'; end if;
  if p_kind not in ('percent', 'fixed') then raise exception 'Type de réduction inconnu'; end if;
  if p_value is null or p_value <= 0 or (p_kind = 'percent' and p_value > 90) then raise exception 'Réduction invalide (90 %% au plus)'; end if;
  if p_starts is null or p_ends is null or p_ends <= p_starts then raise exception 'La fin doit suivre le début'; end if;
  insert into promo_codes (shop_id, code, kind, value, min_amount, starts_at, ends_at, active, label, auto_apply)
  values (null, v_code, p_kind, p_value, greatest(coalesce(p_min, 0), 0), p_starts, p_ends, coalesce(p_active, true), left(v_label, 60), coalesce(p_auto, true))
  on conflict (code) do update set kind = excluded.kind, value = excluded.value, min_amount = excluded.min_amount, starts_at = excluded.starts_at, ends_at = excluded.ends_at,
    active = excluded.active, label = excluded.label, auto_apply = excluded.auto_apply
    where promo_codes.shop_id is null
  returning id into v_id;
  if v_id is null then raise exception 'Ce code appartient à une boutique'; end if;
  return v_id;
end $$;

create or replace function platform_promos() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'label', c.label, 'code', c.code, 'kind', c.kind, 'value', c.value, 'min_amount', c.min_amount,
    'starts_at', c.starts_at, 'ends_at', c.ends_at, 'active', c.active, 'auto_apply', c.auto_apply, 'used_count', c.used_count) order by c.starts_at desc)
    from promo_codes c where c.shop_id is null), '[]'::jsonb);
end $$;

create or replace function platform_promo_toggle(p_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  update promo_codes set active = coalesce(p_active, false) where id = p_id and shop_id is null;
  if not found then raise exception 'Promotion introuvable'; end if;
end $$;

-- Promotion automatique en cours (la plus avantageuse) : lue par le panier pour remplir et verrouiller le champ du code. Null s'il n'y en a pas.
create or replace function active_auto_promo() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('code', c.code, 'label', c.label, 'kind', c.kind, 'value', c.value, 'min_amount', c.min_amount, 'ends_at', c.ends_at)
  from promo_codes c
  where c.shop_id is null and c.auto_apply and c.active and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())
    and (c.max_uses is null or c.used_count < c.max_uses)
  order by case c.kind when 'percent' then c.value else 0 end desc, c.value desc
  limit 1
$$;

revoke all on function platform_promo_save(text, text, text, integer, timestamptz, timestamptz, integer, boolean, boolean), platform_promos(), platform_promo_toggle(uuid, boolean) from public, anon;
grant execute on function platform_promo_save(text, text, text, integer, timestamptz, timestamptz, integer, boolean, boolean), platform_promos(), platform_promo_toggle(uuid, boolean) to authenticated;
revoke all on function active_auto_promo() from public;
grant execute on function active_auto_promo() to anon, authenticated;
