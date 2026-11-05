-- Revenus et statistiques du vendeur (écrans 66 Revenus, 67 Statistiques) : chiffres calculés sur les commandes payées contenant ses annonces,
-- moins les reversements saisis par la finance (payout_batches). Lecture de ses propres chiffres uniquement.
-- Retour arrière : drop function seller_revenue();

create or replace function seller_revenue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_total bigint; v_out bigint; v_sched bigint;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select coalesce(sum(ol.unit_price * ol.qty), 0) into v_total
    from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
    where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null;
  select coalesce(sum(amount) filter (where status = 'verse'), 0), coalesce(sum(amount) filter (where status = 'prevu'), 0) into v_out, v_sched
    from payout_batches where seller_id = auth.uid();
  return jsonb_build_object(
    'total', v_total,
    'paid_out', v_out,
    'scheduled', v_sched,
    'available', greatest(v_total - v_out - v_sched, 0),
    'orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
               where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null),
    'pending_count', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                      where l.seller_id = auth.uid() and not o.paid and o.cancelled_at is null and o.reference is not null),
    'pending_amount', (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                       where l.seller_id = auth.uid() and not o.paid and o.cancelled_at is null and o.reference is not null),
    'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'amount', a) order by m), '[]'::jsonb) from (
                 select to_char(date_trunc('month', o.created_at), 'YYYY-MM') m, sum(ol.unit_price * ol.qty)::bigint a
                 from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                 where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null and o.created_at >= date_trunc('month', now()) - interval '5 months' group by 1) x),
    'weeks', (select coalesce(jsonb_agg(jsonb_build_object('week', w, 'amount', a) order by w), '[]'::jsonb) from (
                 select to_char(date_trunc('week', o.created_at), 'YYYY-MM-DD') w, sum(ol.unit_price * ol.qty)::bigint a
                 from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                 where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null and o.created_at >= date_trunc('week', now()) - interval '7 weeks' group by 1) x)
  );
end $$;

revoke all on function seller_revenue() from public, anon;
grant execute on function seller_revenue() to authenticated;
