-- Répartition de l'argent d'une commande payée (lot S4 « devis-missions » ; money_order_paid est confiée à ce lot par le chef).
--   S4-121    les frais de livraison payés (orders.fee) sont écrits dans money_entries (kind 'delivery') : au prorata des tarifs de livraison des vendeurs concernés
--             (à défaut, du brut de leurs lignes), intégralement au vendeur qui livre (ni fonds d'institution ni commission) ou à la plateforme si elle vend elle-même ;
--             même cycle de vie que la ligne « order » (garde, déblocage, remboursement) ; paiement à la livraison : le vendeur encaisse déjà les frais, aucune ligne
--   SQL1G2-1  la remise d'un code promo de BOUTIQUE n'est imputée qu'aux lignes (donc au vendeur) de cette boutique, jamais aux autres vendeurs du panier ;
--             les promotions de la plateforme (shop_id nul) gardent la répartition proportionnelle sur tout le panier.
--             orders.promo_shop_id mémorise la boutique du code appliqué (trigger BEFORE UPDATE OF promo_code, sans toucher à marketplace_checkout).
-- Retour arrière : drop trigger trg_orders_promo_shop on orders ; drop function trg_orders_promo_shop() ; alter table orders drop column promo_shop_id ;
--   delete from money_entries where kind = 'delivery' ; drop index money_entries_delivery_seller, money_entries_delivery_platform ;
--   recréer money_order_paid (20261115000200) et la contrainte money_entries_kind_check d'origine.

-- ============================================================ 1. money_entries : lignes de livraison
alter table money_entries drop constraint if exists money_entries_kind_check;
alter table money_entries add constraint money_entries_kind_check
  check (kind in ('order', 'subscription', 'mission', 'campaign', 'event', 'gift', 'other', 'delivery'));
create unique index if not exists money_entries_delivery_seller on money_entries (order_id, beneficiary_id) where kind = 'delivery' and order_id is not null and beneficiary_id is not null;
create unique index if not exists money_entries_delivery_platform on money_entries (order_id) where kind = 'delivery' and order_id is not null and beneficiary_id is null;

-- ============================================================ 2. boutique du code promo mémorisée sur la commande
alter table orders add column if not exists promo_shop_id uuid references shops(id) on delete set null;

create or replace function trg_orders_promo_shop() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.promo_shop_id := case when new.promo_code is null then null else (select pc.shop_id from promo_codes pc where pc.code = new.promo_code limit 1) end;
  return new;
end $$;
revoke all on function trg_orders_promo_shop() from public, anon, authenticated;
drop trigger if exists trg_orders_promo_shop on orders;
create trigger trg_orders_promo_shop before update of promo_code on orders for each row execute function trg_orders_promo_shop();

-- Commandes déjà créées avec un code de boutique (non encore payées) : la boutique du code est retrouvée.
do $$ begin
  perform set_config('app.internal', '1', true);
  update orders set promo_code = promo_code where promo_code is not null and promo_shop_id is null;
  perform set_config('app.internal', '', true);
end $$;

-- ============================================================ 3. répartition
create or replace function money_order_paid(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  o orders%rowtype; g record; v_b integer; v_i integer; v_p integer; v_split text := money_split_label();
  v_total integer; v_net integer; v_disc integer; v_d integer; v_shop uuid; v_shop_base integer := 0; v_cnt integer := 0; v_rank integer := 0; v_left integer;
  v_city text; v_sellers uuid[]; v_w bigint[]; v_wsum bigint; v_share integer; v_fee_left integer; k integer;
begin
  select * into o from orders where id = p_order;
  if not found then return; end if;
  select coalesce(sum(unit_price * qty), 0)::int into v_total from order_lines where order_id = p_order;
  v_disc := coalesce(o.discount, 0);
  v_shop := o.promo_shop_id;
  if v_disc > 0 and v_shop is not null then
    select coalesce(sum(ol.unit_price * ol.qty), 0)::int, count(distinct l.seller_id)::int into v_shop_base, v_cnt
      from order_lines ol left join listings l on l.id = ol.listing_id where ol.order_id = p_order and ol.shop_id = v_shop and ol.flash_id is null;
    if v_shop_base <= 0 then v_shop := null; end if; -- base introuvable : repli sur la répartition proportionnelle
  end if;
  v_left := v_disc;
  for g in
    select l.seller_id, sum(ol.unit_price * ol.qty)::int as gross,
           coalesce(sum(case when ol.shop_id = v_shop and ol.flash_id is null then ol.unit_price * ol.qty end), 0)::int as shop_gross
    from order_lines ol left join listings l on l.id = ol.listing_id where ol.order_id = p_order group by l.seller_id order by l.seller_id nulls last
  loop
    continue when g.gross <= 0;
    v_d := 0;
    if v_disc > 0 and v_total > 0 then
      if v_shop is null then
        v_d := (g.gross::bigint * v_disc / v_total)::int;
      elsif g.shop_gross > 0 then
        v_rank := v_rank + 1;
        v_d := case when v_rank >= v_cnt then v_left else (v_disc::bigint * g.shop_gross / v_shop_base)::int end;
        v_left := v_left - v_d;
      end if;
    end if;
    v_net := greatest(g.gross - v_d, 0);
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

  -- Frais de livraison : au prorata des tarifs de livraison de chaque vendeur (repli : du brut de ses lignes) ; pas de ligne pour un paiement à la livraison.
  if coalesce(o.home_delivery, false) and coalesce(o.fee, 0) > 0 and not coalesce(o.cod, false) then
    v_city := o.delivery_address ->> 'city';
    with s as (
      select distinct l2.seller_id, _seller_city(l2) as from_city
        from order_lines ol join listings l2 on l2.id = ol.listing_id where ol.order_id = p_order),
    per as (select seller_id, sum(coalesce(_delivery_fee_for(seller_id, from_city, v_city), 0))::bigint as w from s group by seller_id),
    gr as (
      select l3.seller_id, sum(ol.unit_price * ol.qty)::bigint as gw
        from order_lines ol join listings l3 on l3.id = ol.listing_id where ol.order_id = p_order group by l3.seller_id),
    x as (select per.seller_id, case when (select sum(w) from per) > 0 then per.w else gr.gw end as w from per join gr on gr.seller_id is not distinct from per.seller_id)
    select array_agg(seller_id order by w desc, seller_id), array_agg(w order by w desc, seller_id) into v_sellers, v_w from x where w > 0;
    v_wsum := coalesce((select sum(z) from unnest(v_w) z), 0);
    if v_wsum > 0 then
      v_fee_left := o.fee;
      for k in 1 .. array_length(v_sellers, 1) loop
        v_share := case when k = array_length(v_sellers, 1) then v_fee_left else (o.fee::bigint * v_w[k] / v_wsum)::int end;
        v_fee_left := v_fee_left - v_share;
        continue when v_share <= 0;
        if v_sellers[k] is null then
          insert into money_entries (kind, ref, order_id, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
          values ('delivery', o.number, o.id, o.buyer_id, null, v_share, v_share, 'plateforme', 'released', now()) on conflict do nothing;
        else
          insert into money_entries (kind, ref, order_id, payer_id, beneficiary_id, gross, beneficiary_amount, split, status)
          values ('delivery', o.number, o.id, o.buyer_id, v_sellers[k], v_share, v_share, '100/0/0', 'held') on conflict do nothing;
        end if;
      end loop;
    end if;
  end if;
  perform money_try_release(p_order);
end $$;
revoke all on function money_order_paid(uuid) from public, anon, authenticated;
