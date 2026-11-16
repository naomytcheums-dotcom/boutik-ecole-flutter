-- Lot MONEY (5/6) : revenus, relevé, livraison, gel. S4-121, S4-124, S4-73, S4-23/24/25/29/30, S4-85/S4-108 (valeurs lues dans money_entries), S4-11/S4-15 (mode de remise et paiement à la livraison visibles du vendeur).
-- - seller_revenue : 6 mois réels, clé « weeks » rétablie (écran 67), « en attente » en part nette, chiffre d'affaires BRUT distinct de la part nette, raison de chaque blocage (réclamation, litige,
--   remboursement, gel, attente de confirmation avec date de libération), ventes à la livraison comptées à part.
-- - seller_money_statement / seller_sale_receipt : relevé des parts nettes (money_entries) sur une période (seller_statement, relevé brut + missions, est défini par 20261117045100) et reçu de vente (justificatif pour le vendeur), lus dans money_entries.
-- - money_freeze / money_unfreeze : le vendeur est prévenu (motif compris).
-- - Frais de livraison (S4-121) : la répartition (money_order_paid, kind « delivery ») est livrée par 20261117045200 (lot devis-missions, désigné par le chef) ; ici le journal finance les nomme « Dont frais de livraison » (plus « Commission »).
-- - seller_orders : mode de remise, ville de livraison, paiement à la livraison, date de livraison déclarée, confirmation et date de libération prévue.
-- Retour arrière : drop function seller_money_statement(date, date), seller_sale_receipt(text) ; recréer seller_revenue (20261114002800), money_freeze/money_unfreeze (20261114002800),
--   seller_orders (20261114000400), finance_journal (20261105000500).

-- ============================================================ gel / dégel : le vendeur est prévenu
create or replace function money_freeze(p_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'Indiquez le motif du blocage'; end if;
  update money_entries set status = 'frozen', frozen_reason = left(btrim(p_reason), 300) where id = p_id and status = 'held' returning * into e;
  if not found then raise exception 'Seul un montant en séquestre peut être bloqué'; end if;
  if e.beneficiary_id is not null then
    insert into notifications (user_id, kind, title, body, data)
      values (e.beneficiary_id, 'money', 'Montant bloqué', e.beneficiary_amount || ' FCFA (commande ' || e.ref || ') sont bloqués par la plateforme : ' || left(btrim(p_reason), 200) || '. Pour contester, écrivez au support depuis « Aide ».', jsonb_build_object('entry', e.id));
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Montant bloqué', e.ref, 'Finance', 'Sensible');
end $$;

create or replace function money_unfreeze(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  update money_entries set status = 'held', frozen_reason = null where id = p_id and status = 'frozen' returning * into e;
  if not found then raise exception 'Montant introuvable ou non bloqué'; end if;
  if e.beneficiary_id is not null then
    insert into notifications (user_id, kind, title, body, data)
      values (e.beneficiary_id, 'money', 'Montant débloqué du gel', e.beneficiary_amount || ' FCFA (commande ' || e.ref || ') ne sont plus bloqués : ils suivent de nouveau les règles de livraison.', jsonb_build_object('entry', e.id));
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Montant débloqué du gel', e.ref, 'Finance', 'Sensible');
  perform money_try_release(e.order_id);
end $$;
revoke all on function money_freeze(uuid, text), money_unfreeze(uuid) from public, anon;
grant execute on function money_freeze(uuid, text), money_unfreeze(uuid) to authenticated;

-- ============================================================ revenus du vendeur
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
    'rule', money_split_label(),
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
                            when money_order_blocker(e.order_id) is not null then money_order_blocker(e.order_id)
                            when exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = e.order_id and l.seller_id = e.beneficiary_id and ol.fulfillment < 4) then 'delivery'
                            else 'confirmation' end as reason,
                       (select max(ol.delivered_at) + make_interval(hours => v_hold) from order_lines ol join listings l on l.id = ol.listing_id
                         where ol.order_id = e.order_id and l.seller_id = e.beneficiary_id and ol.confirmed_at is null and ol.fulfillment >= 4) as releases_at
                from money_entries e where e.beneficiary_id = auth.uid() and e.status in ('held', 'frozen') order by e.created_at desc limit 30) h));
end $$;

-- ============================================================ relevé de ventes et reçu de vente
create or replace function seller_money_statement(p_from date default null, p_to date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_from date := coalesce(p_from, (current_date - interval '12 months')::date); v_to date := coalesce(p_to, current_date);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_to < v_from then raise exception 'La période est invalide'; end if;
  if v_to - v_from > 731 then raise exception 'Période limitée à 2 ans'; end if;
  return jsonb_build_object(
    'seller', display_name(auth.uid()), 'from', v_from, 'to', v_to, 'rule', money_split_label(), 'generated_at', now(),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('ref', e.ref, 'kind', e.kind, 'date', e.created_at::date, 'status', e.status, 'gross', e.gross, 'mine', e.beneficiary_amount,
        'institution', e.institution_amount, 'platform', e.platform_amount, 'split', e.split, 'released_at', e.released_at) order by e.created_at desc)
      from (select * from money_entries where beneficiary_id = auth.uid() and created_at::date between v_from and v_to order by created_at desc limit 500) e), '[]'::jsonb),
    'totals', (select jsonb_build_object(
        'gross', coalesce(sum(gross) filter (where status <> 'refunded'), 0), 'mine', coalesce(sum(beneficiary_amount) filter (where status <> 'refunded'), 0),
        'released', coalesce(sum(beneficiary_amount) filter (where status = 'released'), 0), 'held', coalesce(sum(beneficiary_amount) filter (where status in ('held', 'frozen')), 0),
        'refunded', coalesce(sum(beneficiary_amount) filter (where status = 'refunded'), 0), 'count', count(*) filter (where status <> 'refunded'))
      from money_entries where beneficiary_id = auth.uid() and created_at::date between v_from and v_to),
    'payouts', coalesce((select jsonb_agg(jsonb_build_object('number', b.number, 'amount', b.amount, 'status', b.status, 'date', coalesce(b.paid_on, b.scheduled_on), 'reference', b.reference) order by b.created_at desc)
      from payout_batches b where b.seller_id = auth.uid() and b.status = 'verse' and coalesce(b.paid_on, b.scheduled_on) between v_from and v_to), '[]'::jsonb));
end $$;

create or replace function seller_sale_receipt(p_number text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o orders%rowtype; mgr boolean := is_platform_manager(); v_hold integer := money_hold_hours(); v_buyer text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number;
  if not found or not exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr))) then raise exception 'Vente introuvable'; end if;
  select coalesce(nullif(trim(split_part(bp.name, ' ', 1) || ' ' || case when split_part(bp.name, ' ', 2) <> '' then left(split_part(bp.name, ' ', 2), 1) || '.' else '' end), ''), 'Client') into v_buyer from profiles bp where bp.id = o.buyer_id;
  return jsonb_build_object(
    'number', o.number, 'date', o.created_at, 'paid', o.paid, 'cod', o.cod, 'cancelled', o.cancelled_at is not null, 'method', o.method,
    'buyer', coalesce(v_buyer, 'Client'),
    'mode', case when o.home_delivery then 'domicile' else 'campus' end, 'city', o.delivery_address->>'city',
    'lines', coalesce((select jsonb_agg(jsonb_build_object('title', ol.title, 'qty', ol.qty, 'unit_price', ol.unit_price, 'total', ol.unit_price * ol.qty, 'status', ol.fulfillment, 'delivered_at', ol.delivered_at, 'confirmed_at', ol.confirmed_at) order by ol.id)
                       from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr))), '[]'::jsonb),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'gross', e.gross, 'mine', e.beneficiary_amount, 'institution', e.institution_amount, 'platform', e.platform_amount, 'split', e.split, 'status', e.status,
                           'frozen_reason', e.frozen_reason, 'released_at', e.released_at) order by e.kind)
                         from money_entries e where e.order_id = o.id and e.beneficiary_id = auth.uid()), '[]'::jsonb),
    'blocker', money_order_blocker(o.id), 'hold_hours', v_hold, 'rule', money_split_label());
end $$;

-- ============================================================ commandes reçues : mode de remise, paiement à la livraison, état de la remise
drop function if exists seller_orders();
create or replace function seller_orders()
returns table (number text, title text, qty integer, total integer, buyer_name text, status integer, created_at timestamptz, nlines integer,
               cod boolean, home_delivery boolean, delivery_city text, delivered_at timestamptz, confirmed boolean, release_at timestamptz)
language sql stable security definer set search_path = public as $$
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
         case when min(ol.fulfillment) >= 4 and not o.cod and not bool_and(ol.confirmed_at is not null) then max(ol.delivered_at) + make_interval(hours => money_hold_hours()) end
  from order_lines ol
  join listings l on l.id = ol.listing_id
  join orders o on o.id = ol.order_id
  join profiles bp on bp.id = o.buyer_id
  where (l.seller_id = auth.uid() or (l.seller_id is null and is_platform_manager()))
    and (o.paid or o.cod) and o.cancelled_at is null and not o.cancelled
  group by o.number, o.created_at, bp.name, o.cod, o.home_delivery, o.delivery_address->>'city'
  order by o.created_at desc
$$;

-- ============================================================ journal finance : les frais de livraison ne sont plus des « commissions » ; une demande de retrait n'est pas encore une écriture
create or replace function finance_journal(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return (
    with j as (
      select o.created_at::date as d, 'Encaissement ' || o.number as label, 0::bigint as debit, (o.subtotal + o.fee)::bigint as credit, true as reconciled, o.created_at as ts
      from orders o where o.paid and o.cancelled_at is null
      union all
      select o.created_at::date, 'Dont frais de livraison ' || o.number, 0, o.fee::bigint, true, o.created_at from orders o where o.paid and o.cancelled_at is null and o.fee > 0
      union all
      select coalesce(b.paid_on, b.scheduled_on), 'Reversement ' || b.number, b.amount::bigint, 0, b.status = 'verse', b.created_at from payout_batches b where b.status in ('prevu', 'verse')
    )
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(jsonb_build_object('date', d, 'label', label, 'debit', debit, 'credit', credit, 'reconciled', reconciled) order by ts desc)
                        from (select * from j order by ts desc limit least(greatest(p_limit, 1), 300)) x), '[]'::jsonb),
      'total_credit', (select coalesce(sum(credit), 0)::bigint from j where label like 'Encaissement %'),
      'total_debit', (select coalesce(sum(debit), 0)::bigint from j),
      'to_reconcile', (select count(*)::int from j where not reconciled)
    )
  );
end $$;

revoke all on function seller_revenue(), seller_money_statement(date, date), seller_sale_receipt(text), seller_orders(), finance_journal(int) from public, anon;
grant execute on function seller_revenue(), seller_money_statement(date, date), seller_sale_receipt(text), seller_orders(), finance_journal(int) to authenticated;
