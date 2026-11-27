-- Lot H13 COMMERCE (2/3) : états de commande cohérents (client / vendeur / administration), historique réel et suivi par boutique, réservation de stock lisible.
--  1. order_events : historique horodaté ALIMENTÉ PAR DÉCLENCHEURS (commande passée, payée, paiement à la livraison confirmé, étape de préparation de chaque boutique, livraison
--     en cours, remise confirmée, annulation, demandes et décisions de remboursement). Aucune date n'est inventée : une commande antérieure au lot n'a que les dates déjà en base.
--  2. _order_state / _order_state_seller / _order_payment : UNE seule matrice d'états, lue par les trois acteurs.
--       awaiting_payment · to_prepare · accepted · preparing · ready · out_for_delivery · delivered · cancelled · refunded
--       paiement : unpaid · cod_pending · paid · partially_refunded · refunded
--  3. _order_hold_until : fin de la réservation de stock d'une commande impayée, MÊME règle que expire_unpaid_orders (2 h, ou 48 h si une demande de paiement a été ouverte ;
--     aucune expiration tant qu'un paiement est déclaré ou en cours). expire_unpaid_orders n'est pas modifiée.
--  4. order_tracking(numéro) : l'acheteur voit toutes les boutiques de sa commande (état, lignes, sous-total par boutique), le vendeur ne voit QUE sa boutique, l'administration
--     (support commandes / finance lecture) voit tout ; frise = événements réels ; réservation (réservé / paiement en cours / libéré).
--  5. admin_orders : mêmes clés qu'avant + state, payment, cod, shops (nombre de boutiques). Mêmes droits qu'avant.
-- Une commande reste UNE commande par panier (un seul paiement, montant = total) ; la séparation par boutique est portée par les lignes (fulfillment, séquestre par vendeur).
-- Additive et rejouable. Retour arrière : drop trigger trg_h13_ev_* ; drop function order_tracking(text), _order_*, _h13_ev_* ; drop table order_events ; recréer admin_orders depuis 20261122010000.

-- ============================================================ 1. historique
create table if not exists order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references orders(id) on delete cascade,
  seller_id uuid,
  kind text not null check (char_length(kind) between 1 and 60),
  label text not null check (char_length(label) between 1 and 200),
  at timestamptz not null default now()
);
create unique index if not exists order_events_uniq on order_events (order_id, kind, coalesce(seller_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index if not exists order_events_order_idx on order_events (order_id, at);
alter table order_events enable row level security;
revoke all on order_events from anon, authenticated;

create or replace function _h13_ev_add(p_order uuid, p_kind text, p_label text, p_seller uuid default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into order_events (order_id, seller_id, kind, label) values (p_order, p_seller, p_kind, p_label)
  on conflict (order_id, kind, coalesce(seller_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;
end $$;
revoke all on function _h13_ev_add(uuid, text, text, uuid) from public, anon, authenticated;

create or replace function _h13_ev_order() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform _h13_ev_add(new.id, 'created', 'Commande passée');
    return null;
  end if;
  if new.paid and not old.paid then perform _h13_ev_add(new.id, 'paid', 'Paiement confirmé'); end if;
  if coalesce(new.cod, false) and not coalesce(old.cod, false) then perform _h13_ev_add(new.id, 'cod_confirmed', 'Commande confirmée : paiement à la livraison'); end if;
  if new.out_for_delivery_at is not null and old.out_for_delivery_at is null then perform _h13_ev_add(new.id, 'out_for_delivery', 'Commande en livraison'); end if;
  if new.picked_up_at is not null and old.picked_up_at is null then perform _h13_ev_add(new.id, 'picked_up', 'Commande remise'); end if;
  if new.cancelled_at is not null and old.cancelled_at is null then perform _h13_ev_add(new.id, 'cancelled', 'Commande annulée : stock remis en vente'); end if;
  return null;
end $$;
revoke all on function _h13_ev_order() from public, anon, authenticated;
drop trigger if exists trg_h13_ev_order_ins on orders;
create trigger trg_h13_ev_order_ins after insert on orders for each row execute function _h13_ev_order();
drop trigger if exists trg_h13_ev_order_upd on orders;
create trigger trg_h13_ev_order_upd after update of paid, cod, out_for_delivery_at, picked_up_at, cancelled_at on orders for each row execute function _h13_ev_order();

create or replace function _h13_ev_line() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_seller uuid;
begin
  if new.fulfillment is not distinct from old.fulfillment and not (new.confirmed_at is not null and old.confirmed_at is null) then return null; end if;
  select seller_id into v_seller from listings where id = new.listing_id;
  if new.fulfillment > old.fulfillment and new.fulfillment between 1 and 4 then
    perform _h13_ev_add(new.order_id, 'fulfillment_' || new.fulfillment,
      case new.fulfillment when 1 then 'Acceptée par la boutique' when 2 then 'En préparation' when 3 then 'Prête' else 'Livrée selon la boutique' end, v_seller);
  end if;
  if new.confirmed_at is not null and old.confirmed_at is null then perform _h13_ev_add(new.order_id, 'received', 'Réception confirmée', v_seller); end if;
  return null;
end $$;
revoke all on function _h13_ev_line() from public, anon, authenticated;
drop trigger if exists trg_h13_ev_line on order_lines;
create trigger trg_h13_ev_line after update of fulfillment, confirmed_at on order_lines for each row execute function _h13_ev_line();

create or replace function _h13_ev_refund() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return null; end if;
  perform _h13_ev_add(new.order_id, 'refund_' || new.status || '_' || left(new.id::text, 8),
    case new.status when 'requested' then 'Demande d''annulation ou de remboursement envoyée'
                    when 'approved' then case when new.kind = 'partial' then 'Remboursement partiel accordé' else 'Remboursement accordé' end
                    when 'refunded' then 'Remboursement versé'
                    else 'Demande de remboursement refusée' end);
  return null;
end $$;
revoke all on function _h13_ev_refund() from public, anon, authenticated;
drop trigger if exists trg_h13_ev_refund on order_refunds;
create trigger trg_h13_ev_refund after insert or update of status on order_refunds for each row execute function _h13_ev_refund();

-- ============================================================ 2. matrice d'états
create or replace function _order_full_refund(p_order uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from order_refunds r where r.order_id = p_order and r.kind = 'full' and r.status in ('approved', 'refunded'))
$$;
revoke all on function _order_full_refund(uuid) from public, anon, authenticated;

create or replace function _order_state_core(o orders, p_min integer, p_full_refund boolean) returns text
language sql stable set search_path = public as $$
  select case
    when o.cancelled_at is not null or coalesce(o.cancelled, false) then case when p_full_refund then 'refunded' else 'cancelled' end
    when not o.paid and not coalesce(o.cod, false) then 'awaiting_payment'
    when o.picked_up_at is not null or coalesce(p_min, 0) >= 4 then 'delivered'
    when o.out_for_delivery_at is not null then 'out_for_delivery'
    when p_min = 3 then 'ready'
    when p_min = 2 then 'preparing'
    when p_min = 1 then 'accepted'
    else 'to_prepare' end
$$;
revoke all on function _order_state_core(orders, integer, boolean) from public, anon, authenticated;

create or replace function _order_state(p_order uuid) returns text
language sql stable security definer set search_path = public as $$
  select _order_state_core(o, (select min(ol.fulfillment)::int from order_lines ol where ol.order_id = o.id), _order_full_refund(o.id)) from orders o where o.id = p_order
$$;
revoke all on function _order_state(uuid) from public, anon, authenticated;

-- état vu par UNE boutique (p_seller null : lignes de la plateforme)
create or replace function _order_state_seller(p_order uuid, p_seller uuid) returns text
language sql stable security definer set search_path = public as $$
  select _order_state_core(o, (select min(ol.fulfillment)::int from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not distinct from p_seller), _order_full_refund(o.id))
  from orders o where o.id = p_order
$$;
revoke all on function _order_state_seller(uuid, uuid) from public, anon, authenticated;

create or replace function _order_payment(p_order uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when _order_full_refund(o.id) then 'refunded'
    when exists (select 1 from order_refunds r where r.order_id = o.id and r.kind = 'partial' and r.status in ('approved', 'refunded')) then 'partially_refunded'
    when o.paid then 'paid'
    when coalesce(o.cod, false) then 'cod_pending'
    else 'unpaid' end
  from orders o where o.id = p_order
$$;
revoke all on function _order_payment(uuid) from public, anon, authenticated;

-- ============================================================ 3. fin de réservation : même règle que expire_unpaid_orders
create or replace function _order_hold_until(p_order uuid) returns timestamptz
language plpgsql stable security definer set search_path = public as $$
declare o orders%rowtype;
begin
  select * into o from orders where id = p_order;
  if not found or o.paid or coalesce(o.cod, false) or o.cancelled_at is not null or coalesce(o.cancelled, false) then return null; end if;
  if o.reference is not null or exists (select 1 from payment_transactions t where t.kind = 'order' and position(o.number in t.subject) > 0 and t.status in ('pending', 'confirmed')) then return null; end if;
  return o.created_at + case when exists (select 1 from payment_transactions t where t.kind = 'order' and position(o.number in t.subject) > 0) then interval '48 hours' else interval '2 hours' end;
end $$;
revoke all on function _order_hold_until(uuid) from public, anon, authenticated;

-- ============================================================ 4. suivi
create or replace function order_tracking(p_number text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); o orders%rowtype; v_buyer boolean; v_admin boolean; v_mgr boolean := false; v_seller boolean := false; v_role text;
  v_shops jsonb; v_events jsonb; v_refunds jsonb := '[]'::jsonb; v_until timestamptz; v_res jsonb; v_total integer; v_own_sub integer := 0;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number;
  if not found then raise exception 'Commande introuvable'; end if;
  v_buyer := o.buyer_id = uid;
  v_admin := not v_buyer and has_any_admin_permission(array['support.orders', 'finance.read']);
  if not v_buyer and not v_admin then
    v_mgr := is_platform_manager();
    v_seller := (o.paid or coalesce(o.cod, false)) and exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = uid or (l.seller_id is null and v_mgr)));
    if not v_seller then raise exception 'Commande introuvable'; end if;
  end if;
  v_role := case when v_buyer then 'buyer' when v_admin then 'admin' else 'seller' end;

  select coalesce(jsonb_agg(g order by g->>'shop'), '[]'::jsonb) into v_shops from (
    select jsonb_build_object(
             'shop', coalesce(string_agg(distinct sh.name, ', ') filter (where sh.name is not null), max(display_name(l.seller_id)), 'Boutik-École'),
             'seller_id', case when v_role = 'admin' then l.seller_id end,
             'state', _order_state_seller(o.id, l.seller_id),
             'subtotal', sum(ol.unit_price * ol.qty)::int,
             'delivered_at', max(ol.delivered_at), 'confirmed_at', max(ol.confirmed_at),
             'lines', jsonb_agg(jsonb_build_object('title', ol.title, 'variant', ol.variant, 'qty', ol.qty, 'unit_price', ol.unit_price, 'fulfillment', ol.fulfillment) order by ol.title)) as g
    from order_lines ol join listings l on l.id = ol.listing_id left join shops sh on sh.id = l.shop_id
    where ol.order_id = o.id and (v_role <> 'seller' or l.seller_id = uid or (l.seller_id is null and v_mgr))
    group by l.seller_id
  ) s;
  select coalesce(sum((x->>'subtotal')::int), 0)::int into v_own_sub from jsonb_array_elements(v_shops) x;

  select coalesce(jsonb_agg(jsonb_build_object('at', e.at, 'kind', e.kind, 'label', e.label,
           'shop', case when e.seller_id is null then null else coalesce((select nullif(string_agg(distinct sh2.name, ', '), '') from listings l2 join shops sh2 on sh2.id = l2.shop_id where l2.seller_id = e.seller_id and l2.id in (select listing_id from order_lines where order_id = o.id)), display_name(e.seller_id)) end)
           order by e.at, e.id), '[]'::jsonb)
    into v_events
    from order_events e
    where e.order_id = o.id and (v_role <> 'seller' or e.seller_id is null or e.seller_id = uid)
      and (v_role <> 'seller' or e.kind not like 'refund\_%');
  -- commande antérieure au lot : seules les dates déjà en base sont reprises
  if not exists (select 1 from order_events where order_id = o.id and kind = 'created') then
    v_events := jsonb_build_array(jsonb_build_object('at', o.created_at, 'kind', 'created', 'label', 'Commande passée', 'shop', null)) || v_events;
  end if;
  if o.cancelled_at is not null and not exists (select 1 from order_events where order_id = o.id and kind = 'cancelled') then
    v_events := v_events || jsonb_build_array(jsonb_build_object('at', o.cancelled_at, 'kind', 'cancelled', 'label', 'Commande annulée : stock remis en vente', 'shop', null));
  end if;

  if v_role <> 'seller' then
    select coalesce(jsonb_agg(jsonb_build_object('kind', r.kind, 'status', r.status, 'amount', r.amount, 'at', coalesce(r.refunded_at, r.decided_at, r.created_at)) order by r.created_at), '[]'::jsonb) into v_refunds from order_refunds r where r.order_id = o.id;
  end if;

  v_until := _order_hold_until(o.id);
  v_res := case
    when o.paid or coalesce(o.cod, false) then jsonb_build_object('state', 'sold')
    when o.cancelled_at is not null or coalesce(o.cancelled, false) then jsonb_build_object('state', 'released', 'released_at', o.cancelled_at)
    when v_until is null then jsonb_build_object('state', 'payment_in_progress')
    else jsonb_build_object('state', 'reserved', 'until', v_until) end;

  return jsonb_build_object('number', o.number, 'viewer', v_role,
    'state', case when v_role = 'seller' then _order_state_seller(o.id, case when v_mgr and not exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = uid) then null else uid end) else _order_state(o.id) end,
    'payment', case when v_role = 'seller' then null else _order_payment(o.id) end,
    'paid', o.paid, 'cod', coalesce(o.cod, false), 'home_delivery', o.home_delivery, 'created_at', o.created_at, 'cancelled_at', o.cancelled_at,
    'subtotal', case when v_role = 'seller' then v_own_sub else o.subtotal end, 'fee', case when v_role = 'seller' then null else o.fee end,
    'discount', case when v_role = 'seller' then null else o.discount end,
    'multi_shop', jsonb_array_length(v_shops) > 1 or (v_role = 'seller' and (select count(distinct l.seller_id) from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id) > 1),
    'shops', v_shops, 'events', v_events, 'refunds', v_refunds, 'reservation', v_res);
end $$;
revoke all on function order_tracking(text) from public, anon;
grant execute on function order_tracking(text) to authenticated;

-- ============================================================ 5. administration : mêmes clés + état et paiement de la matrice
create or replace function admin_orders(p_limit integer default 200) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_any_admin_permission(array['support.orders', 'finance.read']) then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.created_at desc)
    from (
      select o.number,
             o.status,
             o.paid,
             (o.cancelled_at is not null or coalesce(o.cancelled, false)) as cancelled,
             o.method,
             (o.subtotal + o.fee)::bigint as total,
             o.created_at,
             coalesce(nullif(btrim(b.name), ''), 'Client') as buyer,
             coalesce((select string_agg(distinct coalesce(nullif(btrim(s.name), ''), 'Vendeur'), ', ')
                       from order_lines ol join listings l on l.id = ol.listing_id join profiles s on s.id = l.seller_id
                       where ol.order_id = o.id), '') as sellers,
             _order_state(o.id) as state,
             _order_payment(o.id) as payment,
             coalesce(o.cod, false) as cod,
             (select count(distinct l.seller_id)::int from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id) as shops
      from orders o
      left join profiles b on b.id = o.buyer_id
      order by o.created_at desc
      limit greatest(1, least(coalesce(p_limit, 200), 500))
    ) x
  ), '[]'::jsonb);
end $$;
revoke all on function admin_orders(integer) from public, anon;
grant execute on function admin_orders(integer) to authenticated;
