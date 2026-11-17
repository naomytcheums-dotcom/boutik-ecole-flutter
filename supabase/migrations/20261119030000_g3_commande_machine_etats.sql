-- Lot G3 (commande, paiement, livraison, retrait) : machine d'états de commande sans transition illégale, contrôles serveur du panier.
--  1. orders : le moyen de paiement d'une commande créée par un compte connecté est l'un des moyens proposés (un texte libre devient « Mobile Money »).
--  2. marketplace_checkout : l'idempotence ne rejoue qu'une commande encore ouverte ; quantité et identifiants lus avec contrôle de forme ;
--     vendeur suspendu et service sur devis refusés ; plafond de 10 commandes ouvertes par acheteur (une commande réserve le stock).
--  3. confirm_cod_order : refusée tant qu'un paiement en ligne est en cours ; payment_start / payment_declare / payment_set_status :
--     une commande à payer à la livraison, annulée ou déjà payée ne se règle pas en ligne.
--  4. start_delivery / confirm_pickup : une commande à payer à la livraison est livrable et remettable (elle est encaissée à la remise) ;
--     la remise exige une commande payée (ou à payer à la livraison) et non annulée, et encaisse une commande à la livraison.
--  5. set_seller_order_status / seller_confirm_handover : compte suspendu refusé ; pas d'avancement pendant une demande d'annulation.
--  6. QR de retrait : seulement pour une commande payée (ou à payer à la livraison), non annulée, non retirée ; lu par l'acheteur, le vendeur ou le personnel.
--  7. expire_unpaid_orders : l'acheteur est prévenu de l'expiration de sa commande.
-- Retour arrière : drop trigger trg_orders_method on orders ; drop function _orders_method_guard() ;
--   recréer marketplace_checkout et expire_unpaid_orders (20261115000200), confirm_cod_order (20261114000400), payment_start (20261115000200),
--   payment_declare / payment_set_status (20261114004100), start_delivery (20261101000300), confirm_pickup / set_seller_order_status / seller_confirm_handover (20261117040000),
--   qr_issue (20261117000300), qr_resolve (20261110000300).

-- ============================================================ 1. moyen de paiement d'une commande
create or replace function _orders_method_guard() returns trigger language plpgsql set search_path = public as $$
begin
  -- un texte libre ne devient jamais un moyen de paiement : seul « Paiement à la livraison » donne droit au circuit à la livraison
  if auth.uid() is not null and coalesce(new.method, '') not in ('Mobile Money', 'Orange Money', 'MTN Mobile Money', 'Paiement à la livraison') then
    new.method := 'Mobile Money';
  end if;
  return new;
end $$;
drop trigger if exists trg_orders_method on orders;
create trigger trg_orders_method before insert on orders for each row execute function _orders_method_guard();

-- ============================================================ 2. marketplace_checkout
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
revoke all on function marketplace_checkout(jsonb, boolean, text, uuid, text, text) from public, anon;
grant execute on function marketplace_checkout(jsonb, boolean, text, uuid, text, text) to authenticated;

-- ============================================================ 3. paiement à la livraison et paiements déclarés
create or replace function confirm_cod_order(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.paid or o.cancelled or o.cancelled_at is not null then raise exception 'Cette commande ne peut plus passer en paiement à la livraison'; end if;
  if o.method <> 'Paiement à la livraison' then raise exception 'Cette commande n''est pas en paiement à la livraison'; end if;
  if o.cod then return 'confirmed'; end if;
  if o.reference is not null or exists (select 1 from payment_transactions t where t.payer_id = o.buyer_id and t.kind = 'order' and position(o.number in t.subject) > 0 and t.status in ('pending', 'confirmed')) then
    raise exception 'Un paiement est en cours pour cette commande : attendez sa confirmation ou son échec';
  end if;
  if o.subtotal + o.fee > 200000 then raise exception 'Paiement à la livraison limité à 200 000 FCFA : payez par Mobile Money'; end if;
  update orders set cod = true where id = o.id;
  insert into notifications (user_id, kind, title, body, data)
  select distinct l.seller_id, 'order', 'Nouvelle commande', 'Commande ' || o.number || ' à préparer. Paiement à la livraison : ' || (o.subtotal + o.fee) || ' FCFA à encaisser.', jsonb_build_object('order_number', o.number)
  from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  insert into notifications (user_id, kind, title, body, data)
  values (o.buyer_id, 'order', 'Commande confirmée', 'Votre commande ' || o.number || ' est confirmée. Vous payerez ' || (o.subtotal + o.fee) || ' FCFA à la livraison.', jsonb_build_object('order_number', o.number));
  return 'confirmed';
end $$;
revoke all on function confirm_cod_order(text) from public, anon;
grant execute on function confirm_cod_order(text) to authenticated;

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
    if o.cod then raise exception 'Cette commande se paie à la livraison : elle ne peut pas être payée en ligne'; end if;
    if o.reference is not null then raise exception 'Un paiement Mobile Money est déjà en cours pour cette commande : attendez sa confirmation ou son échec'; end if;
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
revoke all on function payment_start(text, text, int, text) from public, anon;
grant execute on function payment_start(text, text, int, text) to authenticated;

create or replace function payment_declare(p_id uuid, p_provider_ref text) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype; v_num text; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from payment_transactions where id = p_id and payer_id = auth.uid();
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status not in ('created', 'failed') then raise exception 'Ce paiement n''est plus modifiable'; end if;
  if p_provider_ref is null or char_length(trim(p_provider_ref)) < 4 then raise exception 'Référence de transaction invalide'; end if;
  if t.kind = 'order' then
    v_num := substring(t.subject from '#BE-[0-9]{4}-[0-9]+');
    select * into o from orders where number = v_num and buyer_id = t.payer_id;
    if not found or o.paid or o.cancelled_at is not null or coalesce(o.cancelled, false) then raise exception 'Cette commande est annulée ou déjà réglée : aucun paiement à déclarer'; end if;
  end if;
  update payment_transactions set status = 'pending', provider_ref = left(trim(p_provider_ref), 80), declared_at = now() where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'payer', 'J''ai payé. Référence : ' || left(trim(p_provider_ref), 80));
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'system', 'Paiement déclaré. La finance le vérifie ; vous serez notifié.');
  insert into notifications (user_id, kind, title, body, data)
    select f.id, 'payment', 'Paiement à vérifier', t.reference || ' · ' || t.amount || ' FCFA · référence ' || left(trim(p_provider_ref), 80), jsonb_build_object('payment_id', p_id)
    from profiles f where f.role::text in ('finance', 'admin') and not f.suspended;
end $$;
revoke all on function payment_declare(uuid, text) from public, anon;
grant execute on function payment_declare(uuid, text) to authenticated;

create or replace function payment_set_status(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype; pl plans%rowtype; v_code text; v_num text; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('confirmed', 'failed', 'cancelled') then raise exception 'Statut invalide'; end if;
  select * into t from payment_transactions where id = p_id;
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status = 'confirmed' then raise exception 'Paiement déjà confirmé'; end if;
  if p_status = 'confirmed' and t.kind = 'order' then
    v_num := substring(t.subject from '#BE-[0-9]{4}-[0-9]+');
    if v_num is null then raise exception 'Commande introuvable dans l''objet du paiement'; end if;
    select * into o from orders where number = v_num and buyer_id = t.payer_id for update;
    if not found then raise exception 'Commande introuvable'; end if;
    if o.cancelled or o.cancelled_at is not null then raise exception 'Commande annulée : le paiement ne peut pas être confirmé'; end if;
    if o.cod then raise exception 'Commande en paiement à la livraison : elle est encaissée à la remise, pas en ligne'; end if;
    if t.amount < o.subtotal + o.fee then raise exception 'Montant inférieur au total de la commande'; end if;
  end if;
  update payment_transactions set status = p_status, decided_at = now(), decided_by = auth.uid(), note = left(p_note, 300) where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'finance',
    case p_status when 'confirmed' then 'Paiement confirmé. Merci !' when 'failed' then 'Paiement non retrouvé' || coalesce(' : ' || left(p_note, 200), '') || '. Vous pouvez le redéclarer.' else 'Paiement annulé.' end);
  insert into notifications (user_id, kind, title, body, data) values (t.payer_id, 'payment', 'Paiement ' || t.reference,
    case p_status when 'confirmed' then 'Confirmé' when 'failed' then 'Non retrouvé' else 'Annulé' end, jsonb_build_object('payment_id', p_id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Paiement ' || p_status, t.reference, 'Finance', 'Info');
  if p_status = 'confirmed' and t.kind = 'subscription' and t.subject like 'plan:%' then
    v_code := split_part(substr(t.subject, 6), ':', 1);
    select * into pl from plans where plans.code = v_code;
    update subscriptions set status = 'active', started_at = now(), current_period_end = now() + make_interval(days => pl.period_days) where payment_id = p_id;
  elsif p_status = 'confirmed' and t.kind = 'campaign' and t.subject like 'campagne:%' then
    update ad_campaigns set status = 'pending_review' where payment_id = p_id and status = 'awaiting_payment';
  elsif p_status = 'confirmed' and t.kind = 'order' then
    update orders set paid = true, status = greatest(status, 1) where id = o.id and not paid;
  end if;
end $$;
revoke all on function payment_set_status(uuid, text, text) from public, anon;
grant execute on function payment_set_status(uuid, text, text) to authenticated;

-- ============================================================ 4. livraison et remise (équipe)
create or replace function start_delivery(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé à l''équipe logistique'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not (o.paid or o.cod) or o.cancelled or o.cancelled_at is not null then raise exception 'Commande introuvable ou non payée'; end if;
  if not o.home_delivery then raise exception 'Commande à retirer sur campus'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà remise'; end if;
  if exists (select 1 from order_lines where order_id = o.id and fulfillment < 3) then raise exception 'La commande n''est pas encore prête'; end if;
  update orders set out_for_delivery_at = now() where id = o.id;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'order', 'Commande en livraison', o.number || ' : préparez votre code de retrait, le livreur vous le demandera.', jsonb_build_object('order_number', o.number));
  return 'out_for_delivery';
end $$;
revoke all on function start_delivery(text) from public, anon;
grant execute on function start_delivery(text) to authenticated;

create or replace function confirm_pickup(p_number text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au personnel du kiosque'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not (o.paid or o.cod) or o.cancelled or o.cancelled_at is not null then raise exception 'Commande introuvable ou non payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà remise'; end if;
  if o.pickup_attempts >= 5 then raise exception 'Trop d''essais : l''acheteur doit afficher un nouveau code de retrait'; end if;
  if o.pickup_code is null or o.pickup_code <> trim(coalesce(p_code, '')) then
    update orders set pickup_attempts = pickup_attempts + 1 where id = o.id;
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Code de retrait erroné', o.number, 'Kiosques', 'Sensible');
    return 'incorrect';
  end if;
  update orders set picked_up_at = now(), status = 3 where id = o.id;
  update order_lines set fulfillment = 4, delivered_at = coalesce(delivered_at, now()), confirmed_at = coalesce(confirmed_at, now()), confirmed_via = coalesce(confirmed_via, 'staff') where order_id = o.id;
  if o.cod and not o.paid then update orders set paid = true where id = o.id; end if;   -- remis en main propre : le paiement à la livraison est encaissé
  insert into notifications (user_id, kind, title, body, data) values (o.buyer_id, 'order', 'Commande retirée', o.number, jsonb_build_object('order_number', o.number));
  return 'delivered';
end $$;
revoke all on function confirm_pickup(text, text) from public, anon;
grant execute on function confirm_pickup(text, text) to authenticated;

-- ============================================================ 5. avancement et remise par le vendeur
create or replace function set_seller_order_status(p_order text, p_status integer) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; cur integer; mgr boolean := is_platform_manager(); remaining integer; v_hold integer := money_hold_hours();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : préparation de commande impossible'; end if;
  if p_status is null or p_status < 1 or p_status > 4 then raise exception 'Statut invalide'; end if;
  select * into o from orders where number = p_order and (paid or cod) and cancelled_at is null and not cancelled;
  if not found then raise exception 'Commande introuvable ou non payée'; end if;
  select min(ol.fulfillment) into cur from order_lines ol join listings l on l.id = ol.listing_id
    where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr));
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
      and listing_id in (select id from listings where seller_id = auth.uid() or (seller_id is null and mgr));
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
revoke all on function set_seller_order_status(text, integer) from public, anon;
grant execute on function set_seller_order_status(text, integer) to authenticated;

create or replace function seller_confirm_handover(p_number text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; mgr boolean := is_platform_manager(); remaining integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : remise impossible'; end if;
  select * into o from orders where number = p_number and (paid or cod) and cancelled_at is null and not cancelled for update;
  if not found or not exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr))) then
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
    where order_id = o.id and listing_id in (select id from listings where seller_id = auth.uid() or (seller_id is null and mgr));
  if o.cod and not o.paid then
    select count(*) into remaining from order_lines where order_id = o.id and fulfillment < 4;
    if remaining = 0 then update orders set paid = true where id = o.id; end if;
  end if;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'order', 'Remise confirmée', 'La remise de votre commande ' || o.number || ' a été confirmée avec votre code de retrait.', jsonb_build_object('order_number', o.number, 'fulfillment', 4));
  return 'delivered';
end $$;
revoke all on function seller_confirm_handover(text, text) from public, anon;
grant execute on function seller_confirm_handover(text, text) to authenticated;

-- ============================================================ 6. QR de retrait
create or replace function qr_issue(p_kind text, p_target_id text, p_label text default '', p_ttl_seconds integer default null, p_single_use boolean default false) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare r qr_codes%rowtype; tok text; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : QR impossible'; end if;
  if p_kind not in ('profile', 'listing', 'order_pickup', 'kiosk_transfer', 'event', 'certificate') then raise exception 'Type de QR inconnu'; end if;
  if p_kind = 'profile' and p_target_id <> auth.uid()::text then raise exception 'Vous ne pouvez créer que votre propre QR de profil'; end if;
  if p_kind = 'listing' and not exists (select 1 from listings where id::text = p_target_id and seller_id = auth.uid()) then raise exception 'Cette annonce ne vous appartient pas'; end if;
  if p_kind = 'order_pickup' then
    select * into o from orders where number = p_target_id and buyer_id = auth.uid();
    if not found then raise exception 'Cette commande ne vous appartient pas'; end if;
    if o.cancelled or o.cancelled_at is not null then raise exception 'Cette commande est annulée : pas de code de retrait'; end if;
    if not (o.paid or o.cod) then raise exception 'Le code de retrait est délivré une fois la commande payée'; end if;
    if o.picked_up_at is not null then raise exception 'Commande déjà retirée'; end if;
  end if;
  if p_kind in ('event', 'certificate') and coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'support', 'admin') then raise exception 'Ce QR est réservé à l''équipe'; end if;
  if p_ttl_seconds is not null and (p_ttl_seconds < 30 or p_ttl_seconds > 86400) then raise exception 'Durée de validité invalide'; end if;
  if p_ttl_seconds is null then
    select * into r from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked;
    if found then return jsonb_build_object('token', r.token, 'expires_at', null, 'single_use', r.single_use, 'created', false); end if;
  else
    update qr_codes set revoked = true where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is not null and not revoked and used_at is null;
  end if;
  loop
    tok := qr_new_token();
    begin
      insert into qr_codes (token, owner_id, kind, target_id, label, single_use, expires_at)
        values (tok, auth.uid(), p_kind, p_target_id, left(coalesce(p_label, ''), 120), p_single_use or p_ttl_seconds is not null and p_kind in ('kiosk_transfer', 'order_pickup'),
                case when p_ttl_seconds is null then null else now() + make_interval(secs => p_ttl_seconds) end)
        returning * into r;
      exit;
    exception when unique_violation then
      if p_ttl_seconds is null and exists (select 1 from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked) then
        select * into r from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked;
        exit;
      end if;
    end;
  end loop;
  return jsonb_build_object('token', r.token, 'expires_at', r.expires_at, 'single_use', r.single_use, 'created', true);
end $$;
revoke all on function qr_issue(text, text, text, integer, boolean) from public, anon;
grant execute on function qr_issue(text, text, text, integer, boolean) to authenticated;

-- Un code de retrait n'est lisible que par l'acheteur, un vendeur de la commande ou le personnel, tant que la commande est active ; l'acheteur ne le « consomme » pas lui-même.
create or replace function qr_resolve(p_token text, p_consume boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r qr_codes%rowtype; owner_name text; o orders%rowtype; v_consume boolean := p_consume;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into r from qr_codes where token = coalesce(p_token, '') for update;
  if not found then return jsonb_build_object('valid', false, 'reason', 'unknown'); end if;
  select name into owner_name from profiles where id = r.owner_id;
  if r.revoked then return jsonb_build_object('valid', false, 'reason', 'revoked', 'kind', r.kind); end if;
  if r.expires_at is not null and r.expires_at < now() then return jsonb_build_object('valid', false, 'reason', 'expired', 'kind', r.kind); end if;
  if r.single_use and r.used_at is not null then return jsonb_build_object('valid', false, 'reason', 'used', 'kind', r.kind); end if;
  if r.kind = 'order_pickup' then
    select * into o from orders where number = r.target_id and buyer_id = r.owner_id;
    if not found or o.cancelled or o.cancelled_at is not null or o.picked_up_at is not null or not (o.paid or o.cod) then
      return jsonb_build_object('valid', false, 'reason', 'unavailable', 'kind', r.kind);
    end if;
    if auth.uid() = r.owner_id then
      v_consume := false;
    elsif not (coalesce(current_role_name()::text, '') in ('support', 'admin')
               or exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = auth.uid())) then
      return jsonb_build_object('valid', false, 'reason', 'forbidden', 'kind', r.kind);
    end if;
  end if;
  if v_consume then
    update qr_codes set scans = scans + 1, used_at = case when r.single_use then now() else used_at end where id = r.id;
  end if;
  return jsonb_build_object('valid', true, 'kind', r.kind, 'target_id', r.target_id, 'label', r.label, 'owner_id', r.owner_id,
                            'owner_name', coalesce(owner_name, ''), 'single_use', r.single_use, 'expires_at', r.expires_at);
end $$;
revoke all on function qr_resolve(text, boolean) from public, anon;
grant execute on function qr_resolve(text, boolean) to authenticated;

-- ============================================================ 7. expiration : l'acheteur est prévenu
create or replace function expire_unpaid_orders() returns integer
language plpgsql security definer set search_path = public as $$
declare o record; n integer := 0;
begin
  for o in
    select x.id, x.number, x.buyer_id from orders x
    where not x.paid and not coalesce(x.cod, false) and x.cancelled_at is null and not coalesce(x.cancelled, false) and x.reference is null
      and not exists (select 1 from payment_transactions t where t.kind = 'order' and position(x.number in t.subject) > 0 and t.status in ('pending', 'confirmed'))
      and x.created_at < now() - case when exists (select 1 from payment_transactions t where t.kind = 'order' and position(x.number in t.subject) > 0) then interval '48 hours' else interval '2 hours' end
    limit 200
  loop
    perform _cancel_order_core(o.id);
    insert into notifications (user_id, kind, title, body, data)
      values (o.buyer_id, 'order', 'Commande expirée', 'Votre commande ' || o.number || ' n''a pas été payée à temps : elle a été annulée et le stock remis en vente. Vous pouvez la repasser.', jsonb_build_object('order_number', o.number));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function expire_unpaid_orders() from public, anon, authenticated;
