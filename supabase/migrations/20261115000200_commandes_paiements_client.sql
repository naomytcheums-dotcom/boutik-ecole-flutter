-- Commandes et paiements du profil Client (suite de 20261115000100).
--  1. marketplace_checkout : un nouvel essai après une commande annulée crée une nouvelle commande (l'idempotence ne rejoue plus une commande annulée) ;
--     une promotion automatique qui ne s'applique pas au panier est ignorée au lieu de bloquer la commande
--  2. create_order (anciennes versions) : délèguent à marketplace_checkout (mêmes contrôles : boutique active, stock flash, achat de son propre produit, frais par ville)
--  3. annulation : refusée tant qu'un paiement est en cours, vendeur prévenu d'une commande à la livraison annulée ; expiration automatique des commandes jamais payées
--  4. répartition 70/20/10 calculée sur le montant réellement payé (remise déduite)
--  5. payment_start : pour une commande, le montant doit être le total de la commande et la demande n'est pas dupliquée
-- Retour arrière : voir le bas du fichier.

-- ============================================================ 1. marketplace_checkout
create or replace function marketplace_checkout(p_items jsonb, p_home boolean, p_method text, p_address uuid default null, p_code text default null, p_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  o orders%rowtype; st institution_settings%rowtype; adr addresses%rowtype;
  v_fee int := 0; num text; oid uuid; it jsonb; l listings%rowtype; fs flash_sales%rowtype; pk shop_packs%rowtype; pc promo_codes%rowtype; comp jsonb;
  rec record; v_f int; q int; sub int := 0; v_price int; v_reserved int; v_base int; v_disc int := 0; v_normal int; v_unit int; v_cq int; v_share int; v_flash uuid;
  v_skip boolean := false; v_found boolean := false;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_key is not null then
    if char_length(p_key) not between 8 and 80 then raise exception 'Clé d''idempotence invalide'; end if;
    select * into o from orders where buyer_id = uid and idem_key = p_key;
    if found then
      if o.cancelled_at is null and not coalesce(o.cancelled, false) then
        return jsonb_build_object('number', o.number, 'subtotal', o.subtotal, 'fee', o.fee, 'discount', o.discount, 'replayed', true);
      end if;
      perform set_config('app.internal', '1', true);
      update orders set idem_key = null where id = o.id;
      perform set_config('app.internal', '', true);
    end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if jsonb_array_length(p_items) > 30 then raise exception 'Panier trop volumineux'; end if;
  if coalesce(p_home, false) then
    select * into st from institution_settings where id = 'iut-douala';
    if not found or not st.home_delivery_enabled then raise exception 'Livraison à domicile non proposée pour le moment : choisissez le retrait sur campus'; end if;
    select * into adr from addresses where id = p_address and user_id = uid;
    if not found then raise exception 'Choisissez une adresse de livraison'; end if;
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
      if coalesce(v_normal, 0) <= 0 then raise exception 'Pack indisponible'; end if;
      for comp in select * from jsonb_array_elements(pk.items) loop
        v_cq := (comp->>'qty')::int;
        select * into l from listings where id = (comp->>'listing')::uuid and status = 'approved' for update;
        if not found then raise exception 'Pack indisponible : composant retiré'; end if;
        if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
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

-- ============================================================ 2. Anciennes versions de create_order
create or replace function create_order(p_items jsonb, p_home boolean, p_method text, p_address uuid) returns jsonb
language sql security definer set search_path = public as $$
  select marketplace_checkout(p_items, p_home, p_method, p_address, null, null)
$$;
create or replace function create_order(p_items jsonb, p_home boolean, p_method text) returns jsonb
language sql security definer set search_path = public as $$
  select marketplace_checkout(p_items, p_home, p_method, null, null, null)
$$;

-- ============================================================ 3. Annulation et expiration
create or replace function _cancel_order_core(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; ln record;
begin
  select * into o from orders where id = p_id for update;
  if not found or o.cancelled_at is not null then return; end if;
  perform set_config('app.internal', '1', true);
  perform set_config('app.stock_reason', 'annulation', true);
  perform set_config('app.order_number', o.number, true);
  for ln in select listing_id, qty from order_lines where order_id = o.id loop
    update listings set stock = stock + ln.qty where id = ln.listing_id;
  end loop;
  update orders set cancelled_at = now() where id = o.id;
  perform set_config('app.internal', '', true);
  perform set_config('app.stock_reason', '', true);
  perform set_config('app.order_number', '', true);
end $$;
revoke all on function _cancel_order_core(uuid) from public, anon, authenticated;

create or replace function cancel_order(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.paid then raise exception 'Commande déjà payée : annulation impossible'; end if;
  if o.cancelled_at is not null then raise exception 'Commande déjà annulée'; end if;
  if o.reference is not null then raise exception 'Un paiement est en cours pour cette commande : attendez sa confirmation ou son échec avant de l''annuler'; end if;
  if o.cod and exists (select 1 from order_lines where order_id = o.id and fulfillment >= 2) then
    raise exception 'La préparation a commencé : contactez le vendeur pour annuler';
  end if;
  perform _cancel_order_core(o.id);
  if o.cod then
    insert into notifications (user_id, kind, title, body, data)
    select distinct l.seller_id, 'order', 'Commande annulée', 'La commande ' || o.number || ' a été annulée par l''acheteur.', jsonb_build_object('order_number', o.number)
    from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  end if;
  return 'cancelled';
end $$;

-- Commandes jamais payées : annulées au bout de 2 h (48 h si une demande de paiement manuel est ouverte). Une commande dont un paiement est en cours n'est jamais annulée automatiquement.
create or replace function expire_unpaid_orders() returns integer
language plpgsql security definer set search_path = public as $$
declare o record; n integer := 0;
begin
  for o in
    select x.id from orders x
    where not x.paid and not coalesce(x.cod, false) and x.cancelled_at is null and not coalesce(x.cancelled, false) and x.reference is null
      and not exists (select 1 from payment_transactions t where t.kind = 'order' and position(x.number in t.subject) > 0 and t.status in ('pending', 'confirmed'))
      and x.created_at < now() - case when exists (select 1 from payment_transactions t where t.kind = 'order' and position(x.number in t.subject) > 0) then interval '48 hours' else interval '2 hours' end
    limit 200
  loop
    perform _cancel_order_core(o.id);
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function expire_unpaid_orders() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('expire-unpaid-orders') where exists (select 1 from cron.job where jobname = 'expire-unpaid-orders');
  perform cron.schedule('expire-unpaid-orders', '*/10 * * * *', 'select public.expire_unpaid_orders()');
exception when others then
  raise notice 'pg_cron indisponible : les commandes impayées ne sont pas expirées tant que expire_unpaid_orders() n''est pas planifiée (%).', sqlerrm;
end $$;

-- ============================================================ 4. Répartition sur le montant payé
create or replace function money_order_paid(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; g record; v_b integer; v_i integer; v_p integer; v_split text := money_split_label(); v_total integer; v_net integer;
begin
  select * into o from orders where id = p_order;
  if not found then return; end if;
  select coalesce(sum(unit_price * qty), 0)::int into v_total from order_lines where order_id = p_order;
  for g in
    select l.seller_id, sum(ol.unit_price * ol.qty)::int as gross
    from order_lines ol left join listings l on l.id = ol.listing_id where ol.order_id = p_order group by l.seller_id
  loop
    continue when g.gross <= 0;
    v_net := case when coalesce(o.discount, 0) > 0 and v_total > 0 then greatest(g.gross - (g.gross::bigint * o.discount / v_total)::int, 0) else g.gross end;
    continue when v_net <= 0;
    if g.seller_id is null then
      insert into money_entries (kind, ref, order_id, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
      values ('order', o.number, o.id, o.buyer_id, null, v_net, v_net, 'plateforme', 'released', now()) on conflict do nothing;
    else
      select b, i, p into v_b, v_i, v_p from money_split_amounts(v_net);
      insert into money_entries (kind, ref, order_id, payer_id, beneficiary_id, gross, beneficiary_amount, institution_amount, platform_amount, split, status)
      values ('order', o.number, o.id, o.buyer_id, g.seller_id, v_net, v_b, v_i, v_p, v_split, case when o.cod then 'cod_due' else 'held' end) on conflict do nothing;
    end if;
  end loop;
  perform money_try_release(p_order);
end $$;

-- ============================================================ 5. payment_start
create or replace function payment_start(p_kind text, p_subject text, p_amount int, p_provider text default 'manual') returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; ref text; v_num text; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('order', 'subscription', 'campaign', 'event', 'other') then raise exception 'Type invalide'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_provider not in ('manual', 'dikalo', 'tara') then raise exception 'Prestataire invalide'; end if;
  if p_provider <> 'manual' and coalesce((select value from platform_settings where key = 'payments.' || p_provider || '_enabled'), 'false'::jsonb) <> 'true'::jsonb then
    raise exception 'Ce prestataire n''est pas encore activé';
  end if;
  if p_kind = 'order' then
    v_num := substring(coalesce(p_subject, '') from '#BE-[0-9]{4}-[0-9]+');
    if v_num is null then raise exception 'Commande introuvable dans l''objet du paiement'; end if;
    select * into o from orders where number = v_num and buyer_id = auth.uid();
    if not found or o.paid or o.cancelled_at is not null or coalesce(o.cancelled, false) then raise exception 'Commande introuvable ou déjà réglée'; end if;
    if p_amount <> o.subtotal + o.fee then raise exception 'Le montant doit être le total de la commande'; end if;
    select t.id into v from payment_transactions t where t.payer_id = auth.uid() and t.kind = 'order' and position(v_num in t.subject) > 0 and t.status in ('created', 'pending', 'failed') order by t.created_at desc limit 1;
    if found then return v; end if;
  end if;
  ref := 'PAY-' || nextval('payment_ref_seq');
  insert into payment_transactions (reference, payer_id, provider, kind, subject, amount) values (ref, auth.uid(), p_provider, p_kind, coalesce(left(trim(p_subject), 120), ''), p_amount) returning id into v;
  insert into payment_messages (transaction_id, sender, body) values
    (v, 'system', 'Demande de paiement ' || ref || ' : ' || p_amount || ' FCFA' || case when coalesce(trim(p_subject), '') = '' then '' else ' · ' || left(trim(p_subject), 120) end),
    (v, 'system', 'Effectuez le paiement Mobile Money puis touchez « J''ai payé » en indiquant la référence de la transaction reçue par SMS.');
  return v;
end $$;

-- RETOUR ARRIÈRE : recréer marketplace_checkout (20261114000800), create_order (20261101000300), cancel_order (20261114000400), money_order_paid (20261114002800), payment_start (20261105001200) ;
--   drop function _cancel_order_core(uuid), expire_unpaid_orders() ; select cron.unschedule('expire-unpaid-orders').
