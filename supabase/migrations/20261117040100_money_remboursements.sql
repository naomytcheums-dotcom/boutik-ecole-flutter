-- Lot MONEY (2/6) : annulation / remboursement d'une commande PAYÉE par une demande tracée (S4-48).
-- Avant : « contactez le vendeur » sans aucun outil ; l'argent restait en séquestre indéfiniment. Désormais : l'acheteur (avant remise confirmée) ou le vendeur
-- (avant livraison) dépose une demande ; le support, l'administrateur ou la finance l'acceptent (commande annulée, stock remis, séquestre « remboursé »)
-- ou la refusent ; la finance inscrit ensuite la référence du remboursement Mobile Money effectué hors application (aucun appel à un prestataire de paiement ici).
-- Une demande en cours bloque la libération du séquestre.
-- Retour arrière : drop function order_refund_request(text, text, text, text), order_refund_decide(uuid, text, text), order_refund_set_paid(uuid, text), my_refunds(), _order_refund_apply(uuid), _order_refund_open(uuid, uuid, text, uuid, text) ;
--   (la table order_refunds est créée par 20261117040000.)

-- Annule la commande payée (stock remis) et marque tout son séquestre « remboursé ». Paiement à la livraison : rien à rembourser par la plateforme.
create or replace function _order_refund_apply(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _cancel_order_core(p_order);
  update money_entries set status = 'refunded', frozen_reason = null where order_id = p_order and status in ('held', 'frozen', 'released');
end $$;

-- Crée une demande déjà acceptée (décision d'une réclamation en faveur de l'acheteur).
create or replace function _order_refund_open(p_order uuid, p_claim uuid, p_reason text, p_by uuid, p_note text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; v_id uuid; pm payment_methods%rowtype;
begin
  select * into o from orders where id = p_order;
  select * into pm from payment_methods where owner_id = o.buyer_id order by is_default desc, created_at limit 1;
  update order_refunds set status = 'rejected', decision_note = 'Remplacée par la décision de la réclamation', decided_at = now() where order_id = p_order and status = 'requested';
  insert into order_refunds (order_id, requested_by, requester_role, claim_id, reason, status, amount, refund_phone, refund_provider, decision_note, decided_by, decided_at)
  values (p_order, o.buyer_id, 'staff', p_claim, left(p_reason, 1000), 'approved', o.subtotal + o.fee, pm.phone, pm.provider, nullif(left(coalesce(p_note, ''), 500), ''), p_by, now())
  on conflict (order_id) where status in ('requested', 'approved') do update set claim_id = excluded.claim_id returning id into v_id;
  return v_id;
end $$;
revoke all on function _order_refund_apply(uuid), _order_refund_open(uuid, uuid, text, uuid, text) from public, anon, authenticated;

create or replace function order_refund_request(p_order text, p_reason text, p_phone text default null, p_provider text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; v_role text; v_id uuid; v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'); pm payment_methods%rowtype; mgr boolean := is_platform_manager();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and not suspended) then raise exception 'Compte inactif'; end if;
  select * into o from orders where number = p_order for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.buyer_id = auth.uid() then v_role := 'buyer';
  elsif exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr))) then v_role := 'seller';
  else raise exception 'Commande introuvable'; end if;
  if o.cancelled_at is not null or o.cancelled then raise exception 'Cette commande est déjà annulée'; end if;
  if not o.paid then raise exception 'Cette commande n''est pas payée : annulez-la depuis « Annuler la commande »'; end if;
  if o.cod then raise exception 'Cette commande a été payée en espèces à la livraison : déposez une réclamation'; end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then raise exception 'Expliquez la raison en 10 caractères minimum'; end if;
  if v_role = 'buyer' and exists (select 1 from order_lines where order_id = o.id and confirmed_at is not null) then
    raise exception 'Vous avez confirmé la réception : déposez une réclamation si un problème subsiste';
  end if;
  if v_role = 'seller' and exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr)) and ol.fulfillment >= 4) then
    raise exception 'Vous avez déjà livré cette commande : le client peut déposer une réclamation';
  end if;
  if exists (select 1 from order_refunds where order_id = o.id and status in ('requested', 'approved')) then raise exception 'Une demande de remboursement est déjà en cours pour cette commande'; end if;
  if left(v_phone, 3) = '237' and char_length(v_phone) = 12 then v_phone := substr(v_phone, 4); end if;
  if v_phone <> '' and v_phone !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide : 9 chiffres commençant par 6'; end if;
  if v_phone = '' then
    select * into pm from payment_methods where owner_id = o.buyer_id order by is_default desc, created_at limit 1;
    v_phone := pm.phone; p_provider := coalesce(nullif(p_provider, ''), pm.provider);
  end if;
  if v_phone is not null and v_phone <> '' and coalesce(p_provider, '') not in ('orange_money', 'mtn_momo') then raise exception 'Choisissez Orange Money ou MTN MoMo'; end if;
  insert into order_refunds (order_id, requested_by, requester_role, reason, amount, refund_phone, refund_provider)
  values (o.id, auth.uid(), v_role, left(btrim(p_reason), 1000), o.subtotal + o.fee, nullif(v_phone, ''), case when nullif(v_phone, '') is null then null else p_provider end)
  returning id into v_id;
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'refund', 'Remboursement à traiter', 'Commande ' || o.number || ' : ' || (o.subtotal + o.fee) || ' FCFA, demande déposée par ' || case v_role when 'buyer' then 'l''acheteur' else 'le vendeur' end || '.', jsonb_build_object('refund', v_id, 'order_number', o.number)
    from profiles p where p.role::text in ('admin', 'support', 'finance') and not p.suspended;
  if v_role = 'buyer' then
    insert into notifications (user_id, kind, title, body, data)
      select distinct l.seller_id, 'refund', 'Demande d''annulation', 'Commande ' || o.number || ' : l''acheteur demande l''annulation et le remboursement. Le séquestre est gelé en attendant la décision de l''équipe.', jsonb_build_object('refund', v_id, 'order_number', o.number)
      from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  else
    insert into notifications (user_id, kind, title, body, data)
      values (o.buyer_id, 'refund', 'Annulation demandée par le vendeur', 'Commande ' || o.number || ' : le vendeur ne peut pas la honorer. L''équipe examine la demande et vous serez remboursé.', jsonb_build_object('refund', v_id, 'order_number', o.number));
  end if;
  return v_id;
end $$;

create or replace function order_refund_decide(p_id uuid, p_decision text, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare r order_refunds%rowtype; o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'support', 'finance') then raise exception 'Réservé au support et à la finance'; end if;
  if p_decision not in ('approve', 'reject') then raise exception 'Décision inconnue'; end if;
  select * into r from order_refunds where id = p_id for update;
  if not found or r.status <> 'requested' then raise exception 'Demande introuvable ou déjà traitée'; end if;
  if p_decision = 'reject' and char_length(btrim(coalesce(p_note, ''))) < 5 then raise exception 'Indiquez le motif du refus'; end if;
  select * into o from orders where id = r.order_id for update;
  update order_refunds set status = case p_decision when 'approve' then 'approved' else 'rejected' end, decision_note = nullif(left(btrim(coalesce(p_note, '')), 500), ''), decided_by = auth.uid(), decided_at = now() where id = r.id;
  if p_decision = 'approve' then
    perform _order_refund_apply(r.order_id);
  else
    perform money_try_release(r.order_id);
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case p_decision when 'approve' then 'Remboursement accepté' else 'Remboursement refusé' end, o.number, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    select u, 'refund', case p_decision when 'approve' then 'Remboursement accepté' else 'Demande d''annulation refusée' end,
           'Commande ' || o.number || case p_decision when 'approve' then ' annulée : ' || r.amount || ' FCFA vous seront remboursés par Mobile Money.' else ' : la demande est refusée. ' || coalesce(nullif(btrim(p_note), ''), '') end,
           jsonb_build_object('refund', r.id, 'order_number', o.number)
    from unnest(array[o.buyer_id, r.requested_by]) u where u is not null
    union
    select distinct l.seller_id, 'refund', case p_decision when 'approve' then 'Commande annulée et remboursée' else 'Demande d''annulation refusée' end,
           'Commande ' || o.number || case p_decision when 'approve' then ' : annulée, le séquestre correspondant est remboursé à l''acheteur.' else ' : la demande est refusée, la commande suit son cours.' end,
           jsonb_build_object('refund', r.id, 'order_number', o.number)
    from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  return p_decision;
end $$;

-- La finance inscrit le remboursement effectivement versé (référence de la transaction Mobile Money).
create or replace function order_refund_set_paid(p_id uuid, p_reference text) returns text
language plpgsql security definer set search_path = public as $$
declare r order_refunds%rowtype; v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Réservé à la finance'; end if;
  if char_length(btrim(coalesce(p_reference, ''))) < 3 then raise exception 'Indiquez la référence du remboursement'; end if;
  select * into r from order_refunds where id = p_id and status = 'approved' for update;
  if not found then raise exception 'Demande introuvable ou non acceptée'; end if;
  update order_refunds set status = 'refunded', reference = left(btrim(p_reference), 80), refunded_at = now() where id = r.id;
  select number into v_num from orders where id = r.order_id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Remboursement versé', v_num, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    select o.buyer_id, 'refund', 'Remboursement versé', r.amount || ' FCFA remboursés pour la commande ' || o.number || ' (réf. ' || left(btrim(p_reference), 80) || ').', jsonb_build_object('refund', r.id, 'order_number', o.number)
    from orders o where o.id = r.order_id;
  return 'refunded';
end $$;

create or replace function my_refunds() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare mgr boolean := is_platform_manager(); v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'support', 'finance');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'order_number', o.number, 'status', r.status, 'reason', r.reason, 'amount', r.amount, 'requester_role', r.requester_role,
      'created_at', r.created_at, 'decision_note', r.decision_note, 'reference', r.reference, 'claim_id', r.claim_id,
      'refund_phone', case when o.buyer_id = auth.uid() or v_staff then r.refund_phone end, 'refund_provider', case when o.buyer_id = auth.uid() or v_staff then r.refund_provider end,
      'as', case when o.buyer_id = auth.uid() then 'buyer' when v_staff then 'staff' else 'seller' end) order by r.created_at desc)
    from (select * from order_refunds order by created_at desc limit 200) r join orders o on o.id = r.order_id
    where v_staff or o.buyer_id = auth.uid() or r.requested_by = auth.uid()
       or exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr)))), '[]'::jsonb);
end $$;

revoke all on function order_refund_request(text, text, text, text), order_refund_decide(uuid, text, text), order_refund_set_paid(uuid, text), my_refunds() from public, anon;
grant execute on function order_refund_request(text, text, text, text), order_refund_decide(uuid, text, text), order_refund_set_paid(uuid, text), my_refunds() to authenticated;
