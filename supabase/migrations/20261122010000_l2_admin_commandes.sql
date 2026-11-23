-- Lot L2 (H6) : supervision des commandes de la plateforme (écran 132 « Commandes et incidents »).
-- Avant : l'écran affichait les propres achats du compte (client « M. Essono », vendeur « Vendeurs » figés) avec des compteurs inventés.
-- Maintenant : `admin_orders` renvoie les commandes de TOUTE la plateforme (client, vendeurs, montant, paiement, état), réservée à l'administrateur global
-- et aux agents qui ont la permission de support « commandes » ou de finance « lecture » (garde d'équipe H4) ; compte suspendu refusé ; lecture seule.
-- Retour arrière : drop function admin_orders(integer);

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
                       where ol.order_id = o.id), '') as sellers
      from orders o
      left join profiles b on b.id = o.buyer_id
      order by o.created_at desc
      limit greatest(1, least(coalesce(p_limit, 200), 500))
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function admin_orders(integer) from public, anon;
grant execute on function admin_orders(integer) to authenticated;
