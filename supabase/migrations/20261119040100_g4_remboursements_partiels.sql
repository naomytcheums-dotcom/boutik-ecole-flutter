-- Lot G4 (argent du vendeur) 2/3 : remboursements (partiels et totaux), réclamations, litiges.
--   - Remboursement PARTIEL : order_refund_decide(p_id, p_decision, p_note, p_amount) et claim_decide(p_id, p_decision, p_note, p_amount) acceptent un montant inférieur au montant payé :
--     chaque ligne de séquestre de la commande (articles et livraison) est réduite au prorata de son brut (plus grand reste : la somme des réductions = exactement le montant remboursé),
--     et, dans chaque ligne, la part du vendeur, du fonds d'innovation et de la plateforme sont réduites chacune au prorata (somme = brut, aucun FCFA créé ou perdu). La commande n'est pas annulée.
--   - Le montant d'une demande totale tient compte des remboursements partiels déjà accordés (plus de double remboursement).
--   - Argent déjà débloqué puis remboursé : le vendeur et la finance sont prévenus du solde négatif (« deficit »), qui se compense sur ses prochains déblocages.
--   - La finance est prévenue de chaque remboursement à verser, y compris ceux qui naissent d'une décision de réclamation (jusqu'ici personne ne l'était).
--   - Les décisions de litige sont inscrites dans audit_log.
-- Retour arrière : drop function order_refund_decide(uuid, text, text, integer), claim_decide(uuid, text, text, integer), _order_refundable(uuid), _order_refund_partial_apply(uuid, integer), _notify_finance(text, text, jsonb) ;
--   recréer order_refund_request / order_refund_decide / order_refund_set_paid / _order_refund_apply / _order_refund_open (20261117040100), claim_decide (20261117040200), dispute_decide (20261114002000) ;
--   alter table order_refunds drop column kind.

alter table order_refunds add column if not exists kind text not null default 'full';
alter table order_refunds drop constraint if exists order_refunds_kind_check;
alter table order_refunds add constraint order_refunds_kind_check check (kind in ('full', 'partial'));

-- ============================================================ aides internes
create or replace function _notify_finance(p_title text, p_body text, p_data jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = public as $$
  insert into notifications (user_id, kind, title, body, data)
  select p.id, 'refund', p_title, p_body, p_data from profiles p where p.role::text in ('finance', 'admin') and not coalesce(p.suspended, false)
$$;
revoke all on function _notify_finance(text, text, jsonb) from public, anon, authenticated;

-- Montant encore remboursable d'une commande : prix payé (articles après remise + livraison) moins les remboursements partiels accordés.
create or replace function _order_refundable(p_order uuid) returns integer
language sql stable security definer set search_path = public as $$
  select greatest(o.subtotal + o.fee - coalesce((select sum(r.amount) from order_refunds r where r.order_id = o.id and r.kind = 'partial' and r.status in ('approved', 'refunded')), 0), 0)::int
    from orders o where o.id = p_order
$$;
revoke all on function _order_refundable(uuid) from public, anon, authenticated;

-- Prévient le vendeur et la finance quand de l'argent déjà versé (ou en cours de versement) n'est plus couvert.
create or replace function _money_notify_deficit(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r record; v_def integer; v_num text;
begin
  select number into v_num from orders where id = p_order;
  for r in select distinct beneficiary_id from money_entries where order_id = p_order and beneficiary_id is not null loop
    v_def := (money_wallet(r.beneficiary_id)->>'deficit')::int;
    if v_def > 0 then
      insert into notifications (user_id, kind, title, body, data)
        values (r.beneficiary_id, 'money', 'Solde à compenser',
                'La commande ' || v_num || ' a été remboursée alors qu''une partie de votre argent était déjà versée : ' || v_def || ' FCFA seront déduits de vos prochains déblocages.', jsonb_build_object('order_number', v_num));
      perform _notify_finance('Montant versé à récupérer', 'Commande ' || v_num || ' remboursée : ' || v_def || ' FCFA déjà versés à ' || display_name(r.beneficiary_id) || ' sont à compenser sur ses prochains déblocages.', jsonb_build_object('order_number', v_num));
    end if;
  end loop;
end $$;
revoke all on function _money_notify_deficit(uuid) from public, anon, authenticated;

-- ============================================================ application d'un remboursement
create or replace function _order_refund_apply(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _cancel_order_core(p_order);
  update money_entries set status = 'refunded', frozen_reason = null where order_id = p_order and status in ('held', 'frozen', 'released');
  perform _money_notify_deficit(p_order);
end $$;

-- Remboursement partiel : réduction proportionnelle, en entiers, des lignes de séquestre (somme des réductions = p_amount).
create or replace function _order_refund_partial_apply(p_order uuid, p_amount integer) returns void
language plpgsql security definer set search_path = public as $$
declare tot bigint; v_base_sum bigint; v_left bigint; r record; k integer := 0; v_red integer; v_g integer; v_b integer; v_i integer; v_p integer; v_num text;
begin
  select number into v_num from orders where id = p_order;
  select coalesce(sum(gross), 0) into tot from money_entries where order_id = p_order and status in ('held', 'frozen', 'released') and kind in ('order', 'delivery');
  if p_amount is null or p_amount < 1 or p_amount > tot then raise exception 'Montant de remboursement invalide (1 à % FCFA)', tot; end if;
  select coalesce(sum(p_amount::bigint * gross / tot), 0) into v_base_sum from money_entries where order_id = p_order and status in ('held', 'frozen', 'released') and kind in ('order', 'delivery');
  v_left := p_amount - v_base_sum;
  for r in select * from money_entries where order_id = p_order and status in ('held', 'frozen', 'released') and kind in ('order', 'delivery')
           order by (p_amount::bigint * gross) % tot desc, id for update loop
    k := k + 1;
    v_red := (p_amount::bigint * r.gross / tot)::int + case when k <= v_left then 1 else 0 end;
    continue when v_red <= 0;
    v_g := r.gross - v_red;
    v_b := (r.beneficiary_amount::bigint * v_g / r.gross)::int;
    v_i := (r.institution_amount::bigint * v_g / r.gross)::int;
    v_p := v_g - v_b - v_i;
    update money_entries set gross = v_g, beneficiary_amount = v_b, institution_amount = v_i, platform_amount = v_p,
      status = case when v_g = 0 then 'refunded' else status end where id = r.id;
    if r.beneficiary_id is not null and r.beneficiary_amount - v_b > 0 then
      insert into notifications (user_id, kind, title, body, data)
        values (r.beneficiary_id, 'refund', 'Remboursement partiel',
                'Commande ' || v_num || ' : l''acheteur est remboursé d''une partie du prix. Votre part est réduite de ' || (r.beneficiary_amount - v_b) || ' FCFA au prorata (' || v_b || ' FCFA restent pour cette commande).',
                jsonb_build_object('order_number', v_num));
    end if;
  end loop;
  perform _money_notify_deficit(p_order);
end $$;
revoke all on function _order_refund_apply(uuid), _order_refund_partial_apply(uuid, integer) from public, anon, authenticated;

-- Demande déjà acceptée (décision d'une réclamation en faveur de l'acheteur), totale ou partielle.
drop function if exists _order_refund_open(uuid, uuid, text, uuid, text);
create or replace function _order_refund_open(p_order uuid, p_claim uuid, p_reason text, p_by uuid, p_note text, p_amount integer default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; v_id uuid; pm payment_methods%rowtype; v_rem integer := _order_refundable(p_order); v_amt integer; v_kind text;
begin
  select * into o from orders where id = p_order;
  select * into pm from payment_methods where owner_id = o.buyer_id order by is_default desc, created_at limit 1;
  v_amt := coalesce(p_amount, v_rem);
  v_kind := case when v_amt < v_rem then 'partial' else 'full' end;
  update order_refunds set status = 'rejected', decision_note = 'Remplacée par la décision de la réclamation', decided_at = now() where order_id = p_order and status = 'requested';
  insert into order_refunds (order_id, requested_by, requester_role, claim_id, reason, status, kind, amount, refund_phone, refund_provider, decision_note, decided_by, decided_at)
  values (p_order, o.buyer_id, 'staff', p_claim, left(p_reason, 1000), 'approved', v_kind, v_amt, pm.phone, pm.provider, nullif(left(coalesce(p_note, ''), 500), ''), p_by, now())
  on conflict (order_id) where status in ('requested', 'approved') do update set claim_id = excluded.claim_id returning id into v_id;
  perform _notify_finance('Remboursement à verser', 'Commande ' || o.number || ' : ' || v_amt || ' FCFA à rembourser à l''acheteur' || case when pm.phone is null then ' (aucun numéro enregistré : le demander).' else ' sur ' || pm.phone || '.' end,
                          jsonb_build_object('refund', v_id, 'order_number', o.number));
  return v_id;
end $$;
revoke all on function _order_refund_open(uuid, uuid, text, uuid, text, integer) from public, anon, authenticated;

-- ============================================================ demande d'annulation / remboursement
create or replace function order_refund_request(p_order text, p_reason text, p_phone text default null, p_provider text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; v_role text; v_id uuid; v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'); pm payment_methods%rowtype; mgr boolean := is_platform_manager(); v_rem integer;
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
  v_rem := _order_refundable(o.id);
  if v_rem <= 0 then raise exception 'Cette commande est déjà intégralement remboursée'; end if;
  if left(v_phone, 3) = '237' and char_length(v_phone) = 12 then v_phone := substr(v_phone, 4); end if;
  if v_phone <> '' and v_phone !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide : 9 chiffres commençant par 6'; end if;
  if v_phone = '' then
    select * into pm from payment_methods where owner_id = o.buyer_id order by is_default desc, created_at limit 1;
    v_phone := pm.phone; p_provider := coalesce(nullif(p_provider, ''), pm.provider);
  end if;
  if v_phone is not null and v_phone <> '' and coalesce(p_provider, '') not in ('orange_money', 'mtn_momo') then raise exception 'Choisissez Orange Money ou MTN MoMo'; end if;
  insert into order_refunds (order_id, requested_by, requester_role, reason, amount, refund_phone, refund_provider)
  values (o.id, auth.uid(), v_role, left(btrim(p_reason), 1000), v_rem, nullif(v_phone, ''), case when nullif(v_phone, '') is null then null else p_provider end)
  returning id into v_id;
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'refund', 'Remboursement à traiter', 'Commande ' || o.number || ' : ' || v_rem || ' FCFA, demande déposée par ' || case v_role when 'buyer' then 'l''acheteur' else 'le vendeur' end || '.', jsonb_build_object('refund', v_id, 'order_number', o.number)
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

-- Décision du support / de la finance : accepter (totalement, ou partiellement avec p_amount) ou refuser.
drop function if exists order_refund_decide(uuid, text, text);
create or replace function order_refund_decide(p_id uuid, p_decision text, p_note text default '', p_amount integer default null) returns text
language plpgsql security definer set search_path = public as $$
declare r order_refunds%rowtype; o orders%rowtype; v_rem integer; v_amt integer; v_partial boolean := false;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'support', 'finance') then raise exception 'Réservé au support et à la finance'; end if;
  if p_decision not in ('approve', 'reject') then raise exception 'Décision inconnue'; end if;
  select * into r from order_refunds where id = p_id for update;
  if not found or r.status <> 'requested' then raise exception 'Demande introuvable ou déjà traitée'; end if;
  if p_decision = 'reject' and char_length(btrim(coalesce(p_note, ''))) < 5 then raise exception 'Indiquez le motif du refus'; end if;
  select * into o from orders where id = r.order_id for update;
  v_rem := _order_refundable(o.id);
  v_amt := coalesce(p_amount, v_rem);
  if p_decision = 'approve' then
    if o.cancelled_at is not null or o.cancelled then raise exception 'Cette commande est déjà annulée'; end if;
    if v_amt < 1 or v_amt > v_rem then raise exception 'Montant invalide : de 1 à % FCFA', v_rem; end if;
    v_partial := v_amt < v_rem;
    if v_partial and char_length(btrim(coalesce(p_note, ''))) < 5 then raise exception 'Indiquez le motif du remboursement partiel'; end if;
  end if;
  update order_refunds set status = case p_decision when 'approve' then 'approved' else 'rejected' end, kind = case when v_partial then 'partial' else kind end,
    amount = case when p_decision = 'approve' then v_amt else amount end,
    decision_note = nullif(left(btrim(coalesce(p_note, '')), 500), ''), decided_by = auth.uid(), decided_at = now() where id = r.id;
  if p_decision = 'approve' then
    if v_partial then perform _order_refund_partial_apply(r.order_id, v_amt); else perform _order_refund_apply(r.order_id); end if;
    perform _notify_finance('Remboursement à verser', 'Commande ' || o.number || ' : ' || v_amt || ' FCFA à rembourser à l''acheteur' || case when r.refund_phone is null then ' (aucun numéro enregistré : le demander).' else ' sur ' || r.refund_phone || '.' end,
                            jsonb_build_object('refund', r.id, 'order_number', o.number));
  else
    perform money_try_release(r.order_id);
  end if;
  insert into audit_log (actor, action, target, category, level)
    values (auth.uid()::text, case p_decision when 'approve' then case when v_partial then 'Remboursement partiel accepté' else 'Remboursement accepté' end else 'Remboursement refusé' end, o.number, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    select u, 'refund', case p_decision when 'approve' then 'Remboursement accepté' else 'Demande d''annulation refusée' end,
           'Commande ' || o.number || case p_decision when 'approve' then case when v_partial then ' : ' || v_amt || ' FCFA vous seront remboursés par Mobile Money (remboursement partiel, la commande reste valide).' else ' annulée : ' || v_amt || ' FCFA vous seront remboursés par Mobile Money.' end
                                                     else ' : la demande est refusée. ' || coalesce(nullif(btrim(p_note), ''), '') end,
           jsonb_build_object('refund', r.id, 'order_number', o.number)
    from unnest(array[o.buyer_id, r.requested_by]) u where u is not null
    union
    select distinct l.seller_id, 'refund', case p_decision when 'approve' then case when v_partial then 'Remboursement partiel accordé' else 'Commande annulée et remboursée' end else 'Demande d''annulation refusée' end,
           'Commande ' || o.number || case p_decision when 'approve' then case when v_partial then ' : l''acheteur est remboursé de ' || v_amt || ' FCFA, votre part est réduite au prorata.' else ' : annulée, le séquestre correspondant est remboursé à l''acheteur.' end
                                                     else ' : la demande est refusée, la commande suit son cours.' end,
           jsonb_build_object('refund', r.id, 'order_number', o.number)
    from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  return p_decision;
end $$;

-- La finance inscrit le remboursement effectivement versé ; un remboursement partiel relance le déblocage du reste.
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
  if r.kind = 'partial' then perform money_try_release(r.order_id); end if;
  return 'refunded';
end $$;

-- ============================================================ réclamations : décision de la médiation (remboursement total ou partiel)
drop function if exists claim_decide(uuid, text, text);
create or replace function claim_decide(p_id uuid, p_decision text, p_note text default '', p_amount integer default null) returns text
language plpgsql security definer set search_path = public as $$
declare c claims%rowtype; o orders%rowtype; v_note text := left(btrim(coalesce(p_note, '')), 500); v_rem integer; v_partial boolean := false;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à l''équipe de médiation'; end if;
  if p_decision not in ('release', 'refund') then raise exception 'Décision inconnue'; end if;
  select * into c from claims where id = p_id for update;
  if not found then raise exception 'Litige introuvable'; end if;
  if c.status = 'closed' then raise exception 'Cette réclamation est déjà clôturée'; end if;
  select * into o from orders where id = c.order_id for update;
  if p_decision = 'refund' then
    if char_length(v_note) < 5 then raise exception 'Indiquez le motif de la décision'; end if;
    if not o.paid or o.cod then raise exception 'Remboursement impossible : la commande a été payée en espèces à la livraison ou n''est pas payée'; end if;
    if p_amount is not null then
      v_rem := _order_refundable(o.id);
      if p_amount < 1 or p_amount > v_rem then raise exception 'Montant invalide : de 1 à % FCFA', v_rem; end if;
      v_partial := p_amount < v_rem and o.cancelled_at is null;
    end if;
  elsif p_amount is not null then
    raise exception 'Un montant ne s''indique que pour un remboursement';
  end if;
  update claims set status = 'closed', decision = p_decision, decided_by = auth.uid(), decided_at = now(), answer = coalesce(nullif(v_note, ''), answer) where id = c.id;
  insert into claim_messages (claim_id, author_id, author_role, body)
    values (c.id, auth.uid(), 'staff', 'Décision : ' || case p_decision when 'refund' then case when v_partial then 'acheteur remboursé de ' || p_amount || ' FCFA (remboursement partiel)' else 'acheteur remboursé' end else 'réclamation non retenue' end || case when v_note <> '' then ' — ' || v_note else '' end);
  if p_decision = 'refund' then
    if o.cancelled_at is null then
      perform _order_refund_open(o.id, c.id, 'Décision de la réclamation : ' || coalesce(nullif(v_note, ''), 'acheteur remboursé') || ' (réclamation ' || left(c.id::text, 8) || ')', auth.uid(), v_note, case when v_partial then p_amount end);
      if v_partial then perform _order_refund_partial_apply(o.id, p_amount); else perform _order_refund_apply(o.id); end if;
    end if;
  else
    perform money_try_release(o.id);
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Litige clos', c.id::text, 'Marketplace', 'Normal');
  insert into notifications (user_id, kind, title, body, data)
    select u, 'claim', 'Réclamation tranchée', 'Commande ' || o.number || case p_decision when 'refund' then case when v_partial then ' : vous êtes remboursé de ' || p_amount || ' FCFA (remboursement partiel).' else ' : vous êtes remboursé (annulation de la commande).' end else ' : la réclamation n''est pas retenue.' end || case when v_note <> '' then ' ' || v_note else '' end,
           jsonb_build_object('claim_id', c.id, 'order_number', o.number)
    from (select c.claimant_id as u union select seller_id from claim_sellers where claim_id = c.id) x;
  return p_decision;
end $$;

-- Ancienne fonction de la modération (écran Litiges) : clore = rejeter la réclamation, l'argent suit son cours.
create or replace function dispute_close(p_id uuid, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à l''équipe de médiation'; end if;
  perform claim_decide(p_id, 'release', coalesce(p_note, ''));
end $$;

-- ============================================================ litiges (paiement à la livraison refusé) : la décision est tracée
create or replace function dispute_decide(p_id uuid, p_decision text, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare d order_disputes%rowtype; o orders%rowtype; ln record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_platform_staff() then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  if p_decision not in ('close', 'cancel') then raise exception 'Décision inconnue'; end if;
  select * into d from order_disputes where id = p_id for update;
  if not found or d.status <> 'open' then raise exception 'Litige introuvable ou déjà tranché'; end if;
  select * into o from orders where id = d.order_id for update;
  if p_decision = 'cancel' and o.cancelled_at is null and not o.paid then
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
  end if;
  update order_disputes set status = 'resolved', decision = p_decision, decision_note = nullif(left(btrim(coalesce(p_note, '')), 500), ''), decided_at = now() where id = d.id;
  insert into audit_log (actor, action, target, category, level)
    values (auth.uid()::text, case p_decision when 'cancel' then 'Litige tranché : commande annulée' else 'Litige clos' end, o.number, 'Marketplace', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    select u, 'dispute', 'Litige tranché', 'Commande ' || o.number || (case when p_decision = 'cancel' then ' : annulée par l''équipe.' else ' : litige clos.' end), jsonb_build_object('dispute', d.id)
    from unnest(array[d.opened_by, d.buyer_id]) u;
  return p_decision;
end $$;

revoke all on function order_refund_request(text, text, text, text), order_refund_decide(uuid, text, text, integer), order_refund_set_paid(uuid, text),
  claim_decide(uuid, text, text, integer), dispute_close(uuid, text), dispute_decide(uuid, text, text) from public, anon;
grant execute on function order_refund_request(text, text, text, text), order_refund_decide(uuid, text, text, integer), order_refund_set_paid(uuid, text),
  claim_decide(uuid, text, text, integer), dispute_close(uuid, text), dispute_decide(uuid, text, text) to authenticated;
