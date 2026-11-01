-- Produits de la plateforme (annonces sans vendeur créées par 20261029000000_p0_securite) vendus réellement :
--   1. le département et l'administrateur voient et préparent les lignes de ces produits dans « Commandes reçues » ;
--   2. personne ne peut s'approprier un produit de la plateforme (ni un produit d'un vendeur) en changeant son vendeur.
-- Aucune donnée n'est modifiée ; les signatures des fonctions sont inchangées (le client n'a rien à adapter pour les vendeurs).

-- 1. Gestionnaire du catalogue de la plateforme ---------------------------------------------------------------------
create or replace function is_platform_manager() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and coalesce(current_role_name()::text, '') in ('dept', 'admin')
$$;
revoke all on function is_platform_manager() from public, anon;
grant execute on function is_platform_manager() to authenticated;

-- 2. Commandes reçues : lignes du vendeur, et lignes de la plateforme pour le département ou l'administrateur ---------
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
    and o.paid and o.cancelled_at is null and not o.cancelled
  group by o.number, o.created_at, bp.name
  order by o.created_at desc
$$;
revoke all on function seller_orders() from public, anon;
grant execute on function seller_orders() to authenticated;

create or replace function set_seller_order_status(p_order text, p_status integer) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; cur integer; mgr boolean := is_platform_manager();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status < 1 or p_status > 4 then raise exception 'Statut invalide'; end if;
  select * into o from orders where number = p_order and paid and cancelled_at is null and not cancelled;
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
  return p_status;
end $$;
revoke all on function set_seller_order_status(text, integer) from public, anon;
grant execute on function set_seller_order_status(text, integer) to authenticated;

-- 3. Le vendeur d'une annonce ne change jamais, même pour le département ou l'administrateur ------------------------
create or replace function protect_listing_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null or coalesce(current_setting('app.internal', true), '') = '1' then return new; end if;  -- éditeur SQL / fonctions serveur
  if r in ('dept', 'admin') then
    if tg_op = 'UPDATE' then
      new.seller_id := old.seller_id;                               -- un produit de la plateforme reste à la plateforme
      if new.status is distinct from old.status then new.reviewed_by := auth.uid(); end if;
    end if;
    new.updated_at := now();
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.seller_id := auth.uid();                                   -- une annonce appartient toujours à son créateur
    if new.status not in ('draft', 'pending') then new.status := 'pending'; end if;
    new.reviewed_by := null;
    new.review_note := null;
  else
    if old.seller_id is distinct from auth.uid() then raise exception 'Annonce d''un autre vendeur'; end if;
    if old.status = 'removed' then raise exception 'Annonce supprimée'; end if;
    if new.status is distinct from old.status and not (
         (old.status = 'draft' and new.status in ('pending', 'removed'))
      or (old.status = 'pending' and new.status in ('draft', 'removed'))
      or (old.status = 'rejected' and new.status in ('draft', 'pending', 'removed'))
      or (old.status = 'approved' and new.status = 'removed')) then
      raise exception 'Transition de statut non autorisée (% vers %)', old.status, new.status;
    end if;
    new.seller_id := old.seller_id;
    new.reviewed_by := old.reviewed_by;
    new.review_note := case when new.status = 'pending' and old.status <> 'pending' then null else old.review_note end;
  end if;
  new.updated_at := now();
  return new;
end $$;
revoke execute on function protect_listing_status() from public, anon, authenticated;

-- Retour arrière (manuel) : réappliquer seller_orders et set_seller_order_status de 20261030000700_commandes_vendeur.sql,
-- protect_listing_status de 20261030000200_annonces_stock.sql, puis : drop function if exists is_platform_manager();
