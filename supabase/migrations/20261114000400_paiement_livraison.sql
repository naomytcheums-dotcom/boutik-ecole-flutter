-- Paiement à la livraison : la commande est confirmée sans prélèvement ; le vendeur la voit, la prépare, puis encaisse à la remise.
-- La commande n'est marquée « payée » qu'une fois livrée (le chiffre d'affaires, les gains de parrainage et les avis ne comptent donc que l'argent réellement reçu).
-- Plafond de 200 000 FCFA par commande ; annulation par l'acheteur impossible une fois la préparation commencée.
-- Retour arrière : drop function confirm_cod_order(text); alter table orders drop column cod; puis recréer seller_orders, set_seller_order_status, cancel_order et on_order_paid
--                   depuis 20261101000100_produits_plateforme.sql, 20261030000200_annonces_stock.sql et 20261030000300_messagerie_notifications.sql.

alter table orders add column if not exists cod boolean not null default false;

-- L'acheteur confirme sa commande à payer à la livraison (après la création normale de la commande, dont le stock est réservé).
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

-- Commandes reçues : les commandes en paiement à la livraison y figurent dès leur confirmation.
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
  where (l.seller_id = auth.uid() or (l.seller_id is null and is_platform_manager()))
    and (o.paid or o.cod) and o.cancelled_at is null and not o.cancelled
  group by o.number, o.created_at, bp.name
  order by o.created_at desc
$$;
revoke all on function seller_orders() from public, anon;
grant execute on function seller_orders() to authenticated;

-- Avancement par le vendeur : accepté les commandes payées ou à payer à la livraison ; la remise (statut 4) encaisse une commande à la livraison.
create or replace function set_seller_order_status(p_order text, p_status integer) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; cur integer; mgr boolean := is_platform_manager(); remaining integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status < 1 or p_status > 4 then raise exception 'Statut invalide'; end if;
  select * into o from orders where number = p_order and (paid or cod) and cancelled_at is null and not cancelled;
  if not found then raise exception 'Commande introuvable ou non payée'; end if;
  select min(ol.fulfillment) into cur from order_lines ol join listings l on l.id = ol.listing_id
    where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr));
  if cur is null then raise exception 'Commande introuvable ou non payée'; end if;
  if p_status <= cur then raise exception 'Ce statut est déjà atteint ou dépassé'; end if;
  update order_lines set fulfillment = p_status
    where order_id = o.id
      and listing_id in (select id from listings where seller_id = auth.uid() or (seller_id is null and mgr));
  insert into notifications (user_id, kind, title, body, data)
  values (o.buyer_id, 'order',
          case p_status when 1 then 'Commande acceptée' when 2 then 'Commande en préparation' when 3 then 'Commande prête' else 'Commande livrée' end,
          'Votre commande ' || o.number || case p_status when 1 then ' a été acceptée par le vendeur.' when 2 then ' est en préparation.' when 3 then ' est prête : vous pouvez la retirer.' else ' a été livrée.' end,
          jsonb_build_object('order_number', o.number, 'fulfillment', p_status));
  if p_status = 4 and o.cod and not o.paid then
    select count(*) into remaining from order_lines where order_id = o.id and fulfillment < 4;
    if remaining = 0 then update orders set paid = true where id = o.id; end if;   -- tout est remis : l'argent est encaissé
  end if;
  return p_status;
end $$;
revoke all on function set_seller_order_status(text, integer) from public, anon;
grant execute on function set_seller_order_status(text, integer) to authenticated;

-- Annulation : une commande à payer à la livraison ne s'annule plus une fois la préparation commencée.
create or replace function cancel_order(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; ln record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.paid then raise exception 'Commande déjà payée : annulation impossible'; end if;
  if o.cancelled_at is not null then raise exception 'Commande déjà annulée'; end if;
  if o.cod and exists (select 1 from order_lines where order_id = o.id and fulfillment >= 2) then
    raise exception 'La préparation a commencé : contactez le vendeur pour annuler';
  end if;
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
  return 'cancelled';
end $$;
revoke all on function cancel_order(text) from public, anon;
grant execute on function cancel_order(text) to authenticated;

-- Notification de paiement : pour une commande à la livraison, l'argent arrive à la remise (pas de seconde « nouvelle commande » au vendeur).
create or replace function on_order_paid() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.paid and not old.paid then
    insert into notifications (user_id, kind, title, body, data)
    values (new.buyer_id, 'order', case when new.cod then 'Paiement reçu' else 'Paiement confirmé' end,
            case when new.cod then 'Merci : le paiement de votre commande ' || new.number || ' a été encaissé à la livraison.' else 'Votre commande ' || new.number || ' est payée.' end,
            jsonb_build_object('order_number', new.number));
    if not new.cod then
      insert into notifications (user_id, kind, title, body, data)
      select distinct l.seller_id, 'order', 'Nouvelle commande', 'Commande ' || new.number || ' à préparer.', jsonb_build_object('order_number', new.number)
      from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = new.id and l.seller_id is not null;
    end if;
  end if;
  return null;
end $$;
