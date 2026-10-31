-- Commandes reçues par le vendeur : liste (commandes payées contenant ses annonces) et suivi de préparation.
-- L'état de préparation est porté par les lignes de commande ; il n'est modifiable que par le vendeur de la ligne, via la fonction ci-dessous.

alter table order_lines add column if not exists fulfillment smallint not null default 0;
alter table order_lines drop constraint if exists order_lines_fulfillment_check;
alter table order_lines add constraint order_lines_fulfillment_check check (fulfillment between 0 and 4);   -- 0 nouvelle · 1 à préparer · 2 en cours · 3 prête · 4 livrée

create or replace function seller_orders()
returns table (number text, title text, qty integer, total integer, buyer_name text, status integer, created_at timestamptz, nlines integer)
language sql stable security definer set search_path = public as $$
  select o.number,
         min(ol.title),
         sum(ol.qty)::int,
         sum(ol.qty * ol.unit_price)::int,
         coalesce(nullif(trim(split_part(bp.name, ' ', 1) || ' ' || case when split_part(bp.name, ' ', 2) <> '' then left(split_part(bp.name, ' ', 2), 1) || '.' else '' end), ''), 'Client'),
         min(ol.fulfillment)::int,
         o.created_at,
         count(*)::int
  from order_lines ol
  join listings l on l.id = ol.listing_id
  join orders o on o.id = ol.order_id
  join profiles bp on bp.id = o.buyer_id
  where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null and not o.cancelled
  group by o.number, o.created_at, bp.name
  order by o.created_at desc
$$;
revoke all on function seller_orders() from public, anon;
grant execute on function seller_orders() to authenticated;

create or replace function set_seller_order_status(p_order text, p_status integer) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; cur integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status < 1 or p_status > 4 then raise exception 'Statut invalide'; end if;
  select * into o from orders where number = p_order and paid and cancelled_at is null and not cancelled;
  if not found then raise exception 'Commande introuvable ou non payée'; end if;
  select min(ol.fulfillment) into cur from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = auth.uid();
  if cur is null then raise exception 'Commande introuvable ou non payée'; end if;
  if p_status <= cur then raise exception 'Ce statut est déjà atteint ou dépassé'; end if;
  update order_lines set fulfillment = p_status
    where order_id = o.id and listing_id in (select id from listings where seller_id = auth.uid());
  insert into notifications (user_id, kind, title, body, data)
  values (o.buyer_id, 'order',
          case p_status when 1 then 'Commande acceptée' when 2 then 'Commande en préparation' when 3 then 'Commande prête' else 'Commande livrée' end,
          'Votre commande ' || o.number || case p_status when 1 then ' a été acceptée par le vendeur.' when 2 then ' est en préparation.' when 3 then ' est prête : vous pouvez la retirer.' else ' a été livrée.' end,
          jsonb_build_object('order_number', o.number, 'fulfillment', p_status));
  return p_status;
end $$;
revoke all on function set_seller_order_status(text, integer) from public, anon;
grant execute on function set_seller_order_status(text, integer) to authenticated;
