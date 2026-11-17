-- Lot G4 (argent du vendeur) 1/3 : arithmétique entière, déblocage idempotent, gel, solde et transparence de la règle de répartition.
--   - money_order_paid : la remise d'un code promo (hors boutique) était arrondie vers le bas pour CHAQUE vendeur : jusqu'à (n - 1) FCFA de plus que le prix payé étaient répartis
--     (création de FCFA). Le dernier groupe prend désormais le reliquat : la somme des lignes de séquestre = exactement le prix des articles payé.
--   - money_try_release : verrou de ligne + mise à jour conditionnelle (deux exécutions simultanées ne débloquent ni ne notifient deux fois) ; un vendeur SUSPENDU ne reçoit rien
--     tant que son compte l'est (le montant reste en séquestre, il repart à la levée de la suspension) ; la notification des frais de livraison ne parle plus de « part de 100 % ».
--   - money_auto_release : ne parcourt plus que les commandes sans réclamation / litige / remboursement (plus de famine au-delà de 500 commandes bloquées).
--   - money_release_now : refuse de débloquer de force une commande avec réclamation, litige ou remboursement en cours, ou un vendeur suspendu ; trace l'action (audit_log).
--   - money_wallet : nouvelle clé « deficit » (argent versé ou en cours de versement qui n'est plus couvert, après un remboursement d'un montant déjà débloqué).
--   - seller_revenue : règle lue en base (clé « rule_parts » : parts et base de calcul), motif « compte suspendu », « deficit ».
-- Retour arrière : recréer money_order_paid (20261117045200), money_try_release (20261117040000), money_auto_release (20261117040000), money_release_now (20261114002800),
--   money_wallet (20261117040300), seller_revenue (20261117040400) ; drop function _money_rule_parts().

-- ============================================================ règle de répartition (lue en base, jamais écrite en dur côté application)
create or replace function _money_rule_parts() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('beneficiary', r.beneficiary_pct, 'institution', r.institution_pct, 'platform', r.platform_pct,
                          'base', 'Prix des articles, hors frais de livraison ni frais de plateforme ; le reliquat d''arrondi va à la plateforme.')
                     from money_split_rules r order by r.id desc limit 1), 'null'::jsonb)
$$;
revoke all on function _money_rule_parts() from public, anon, authenticated;

-- ============================================================ répartition d'une commande payée
create or replace function money_order_paid(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  o orders%rowtype; g record; v_b integer; v_i integer; v_p integer; v_split text := money_split_label();
  v_total integer; v_net integer; v_disc integer; v_d integer; v_shop uuid; v_shop_base integer := 0; v_cnt integer := 0; v_rank integer := 0; v_left integer;
  v_city text; v_sellers uuid[]; v_w bigint[]; v_wsum bigint; v_share integer; v_fee_left integer; k integer; v_idx integer := 0; v_ngrp integer := 0;
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
  select count(*)::int into v_ngrp from (
    select 1 from order_lines ol left join listings l on l.id = ol.listing_id where ol.order_id = p_order group by l.seller_id having sum(ol.unit_price * ol.qty) > 0) z;
  for g in
    select l.seller_id, sum(ol.unit_price * ol.qty)::int as gross,
           coalesce(sum(case when ol.shop_id = v_shop and ol.flash_id is null then ol.unit_price * ol.qty end), 0)::int as shop_gross
    from order_lines ol left join listings l on l.id = ol.listing_id where ol.order_id = p_order group by l.seller_id order by l.seller_id nulls last
  loop
    continue when g.gross <= 0;
    v_d := 0;
    if v_disc > 0 and v_total > 0 then
      if v_shop is null then
        v_idx := v_idx + 1;
        v_d := case when v_idx >= v_ngrp then least(v_left, g.gross) else (g.gross::bigint * v_disc / v_total)::int end;
        v_left := v_left - v_d;
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

-- ============================================================ déblocage idempotent, gel du vendeur suspendu
create or replace function money_try_release(p_order uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype; n integer := 0; v_hold integer := money_hold_hours(); v_done uuid;
begin
  if exists (select 1 from orders where id = p_order and (cancelled_at is not null or cancelled)) then return 0; end if;
  if money_order_blocker(p_order) is not null then return 0; end if;
  for e in select * from money_entries where order_id = p_order and status = 'held' and beneficiary_id is not null order by id for update loop
    if exists (select 1 from profiles where id = e.beneficiary_id and coalesce(suspended, false)) then continue; end if;
    if exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = p_order and l.seller_id = e.beneficiary_id and ol.fulfillment < 4) then continue; end if;
    if exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id
               where ol.order_id = p_order and l.seller_id = e.beneficiary_id and ol.confirmed_at is null
                 and coalesce(ol.delivered_at, now()) + make_interval(hours => v_hold) > now()) then continue; end if;
    v_done := null;
    update money_entries set status = 'released', released_at = now() where id = e.id and status = 'held' returning id into v_done;
    if v_done is null then continue; end if;
    insert into notifications (user_id, kind, title, body, data)
      values (e.beneficiary_id, 'money', 'Argent débloqué',
              e.beneficiary_amount || ' FCFA sont disponibles sur votre solde (commande ' || e.ref || case when e.kind = 'delivery' then ', frais de livraison)' else ', part de ' || split_part(e.split, '/', 1) || ' %)' end || '.',
              jsonb_build_object('entry', e.id));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function money_try_release(uuid) from public, anon, authenticated;

create or replace function money_auto_release() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select distinct order_id from money_entries
            where status = 'held' and order_id is not null and beneficiary_id is not null and money_order_blocker(order_id) is null limit 500 loop
    n := n + money_try_release(r.order_id);
  end loop;
  return n;
end $$;
revoke all on function money_auto_release() from public, anon, authenticated;

-- Déblocage forcé (administrateur) : jamais par-dessus une réclamation, un litige ou un remboursement en cours, ni pour un vendeur suspendu.
create or replace function money_release_now(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into e from money_entries where id = p_id and status in ('held', 'frozen') and beneficiary_id is not null for update;
  if not found then raise exception 'Montant introuvable'; end if;
  if e.order_id is not null and money_order_blocker(e.order_id) is not null then
    raise exception 'Une réclamation, un litige ou un remboursement est en cours sur cette commande : tranchez-le avant de débloquer';
  end if;
  if exists (select 1 from profiles where id = e.beneficiary_id and coalesce(suspended, false)) then
    raise exception 'Le compte du vendeur est suspendu : levez la suspension avant de débloquer';
  end if;
  update money_entries set status = 'released', released_at = now(), frozen_reason = null where id = p_id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Déblocage forcé du séquestre', e.ref, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (e.beneficiary_id, 'money', 'Argent débloqué', e.beneficiary_amount || ' FCFA sont disponibles sur votre solde (commande ' || e.ref || ').', jsonb_build_object('entry', e.id));
end $$;
revoke all on function money_release_now(uuid) from public, anon;
grant execute on function money_release_now(uuid) to authenticated;

-- ============================================================ solde
-- « deficit » : montants versés ou en cours de versement qui ne sont plus couverts par de l'argent débloqué (remboursement d'une vente déjà débloquée) ;
-- ils se compensent automatiquement sur les prochains déblocages (disponible = débloqué - versé - prévu - demandé - à recouvrer).
create or replace function money_wallet(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  with m as (
    select coalesce(sum(beneficiary_amount) filter (where status in ('held', 'frozen')), 0) as held,
           coalesce(sum(beneficiary_amount) filter (where status = 'frozen'), 0) as frozen,
           coalesce(sum(beneficiary_amount) filter (where status = 'released'), 0) as released,
           coalesce(sum(institution_amount + platform_amount) filter (where status = 'cod_due'), 0) as owed
      from money_entries where beneficiary_id = p_user),
  b as (
    select coalesce(sum(amount) filter (where status = 'verse'), 0) as paid,
           coalesce(sum(amount) filter (where status = 'prevu'), 0) as scheduled,
           coalesce(sum(amount) filter (where status = 'demande'), 0) as requested
      from payout_batches where seller_id = p_user)
  select jsonb_build_object(
    'held', m.held::int, 'frozen', m.frozen::int, 'released', m.released::int,
    'paid_out', b.paid::int, 'scheduled', b.scheduled::int, 'requested', b.requested::int, 'owed', m.owed::int,
    'available', greatest(m.released - b.paid - b.scheduled - b.requested - m.owed, 0)::int,
    'deficit', greatest(b.paid + b.scheduled + b.requested - m.released, 0)::int)
  from m, b
$$;
revoke all on function money_wallet(uuid) from public, anon, authenticated;

-- ============================================================ revenus du vendeur : règle lue en base, motifs réels
create or replace function seller_revenue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare w jsonb; v_hold integer := money_hold_hours();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  w := money_wallet(auth.uid());
  return jsonb_build_object(
    'total', (w->>'held')::int + (w->>'released')::int,
    'held', (w->>'held')::int,
    'frozen', (w->>'frozen')::int,
    'paid_out', (w->>'paid_out')::int,
    'scheduled', (w->>'scheduled')::int,
    'requested', (w->>'requested')::int,
    'available', (w->>'available')::int,
    'owed', (w->>'owed')::int,
    'deficit', (w->>'deficit')::int,
    'suspended', coalesce((select suspended from profiles where id = auth.uid()), false),
    'rule', money_split_label(),
    'rule_parts', _money_rule_parts(),
    'hold_hours', v_hold,
    'orders', (select count(distinct order_id)::int from money_entries where beneficiary_id = auth.uid() and kind = 'order' and status <> 'refunded'),
    'gross', (select coalesce(sum(gross), 0)::bigint from money_entries where beneficiary_id = auth.uid() and kind = 'order' and status <> 'refunded'),
    'cod_net', (select coalesce(sum(beneficiary_amount), 0)::bigint from money_entries where beneficiary_id = auth.uid() and status = 'cod_due'),
    'pending_count', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id where l.seller_id = auth.uid() and not o.paid and o.cancelled_at is null and o.reference is not null),
    'pending_amount', (select coalesce(sum((money_split_amounts(x.gross)).b), 0)::bigint from (
                         select sum(ol.unit_price * ol.qty)::int as gross from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                         where l.seller_id = auth.uid() and not o.paid and o.cancelled_at is null and o.reference is not null group by o.id) x),
    'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'amount', a) order by m), '[]'::jsonb) from (
                 select to_char(date_trunc('month', created_at), 'YYYY-MM') m, sum(beneficiary_amount)::bigint a from money_entries
                 where beneficiary_id = auth.uid() and status in ('held', 'frozen', 'released', 'cod_due') and created_at >= date_trunc('month', now()) - interval '5 months' group by 1) x),
    'weeks', (select coalesce(jsonb_agg(jsonb_build_object('week', k, 'amount', a) order by k), '[]'::jsonb) from (
                 select to_char(date_trunc('week', created_at), 'YYYY-MM-DD') k, sum(beneficiary_amount)::bigint a from money_entries
                 where beneficiary_id = auth.uid() and status in ('held', 'frozen', 'released', 'cod_due') and created_at >= date_trunc('week', now()) - interval '7 weeks' group by 1) x),
    'holds', (select coalesce(jsonb_agg(jsonb_build_object('ref', h.ref, 'amount', h.beneficiary_amount, 'status', h.status, 'frozen_reason', h.frozen_reason, 'reason', h.reason, 'releases_at', h.releases_at) order by h.created_at desc), '[]'::jsonb)
              from (
                select e.ref, e.beneficiary_amount, e.status, e.frozen_reason, e.created_at,
                       case when e.status = 'frozen' then 'frozen'
                            when exists (select 1 from profiles sp where sp.id = e.beneficiary_id and coalesce(sp.suspended, false)) then 'suspended'
                            when money_order_blocker(e.order_id) is not null then money_order_blocker(e.order_id)
                            when exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = e.order_id and l.seller_id = e.beneficiary_id and ol.fulfillment < 4) then 'delivery'
                            else 'confirmation' end as reason,
                       (select max(ol.delivered_at) + make_interval(hours => v_hold) from order_lines ol join listings l on l.id = ol.listing_id
                         where ol.order_id = e.order_id and l.seller_id = e.beneficiary_id and ol.confirmed_at is null and ol.fulfillment >= 4) as releases_at
                from money_entries e where e.beneficiary_id = auth.uid() and e.status in ('held', 'frozen') order by e.created_at desc limit 30) h));
end $$;
revoke all on function seller_revenue() from public, anon;
grant execute on function seller_revenue() to authenticated;
