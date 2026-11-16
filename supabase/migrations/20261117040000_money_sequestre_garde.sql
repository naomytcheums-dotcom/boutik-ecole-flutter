-- Lot MONEY (1/6) : le séquestre ne se libère plus sur la seule déclaration « livrée » du vendeur.
-- S4-12 / SQL1-1 / S10-1 : un article livré est libéré quand l'acheteur confirme la réception, quand le vendeur saisit le code de retrait de l'acheteur,
--   quand le personnel du kiosque confirme la remise, OU après un délai de garde (72 h par défaut, réglage « money.hold_hours ») sans réclamation ni litige.
--   Les statuts de préparation se suivent dans l'ordre (1 → 2 → 3 → 4).
-- Une réclamation ouverte OU répondue-mais-non-tranchée, un litige ouvert, une demande de remboursement en cours bloquent la libération.
-- SQL1-17 : la prime et la part de parrainage d'une commande payée à la livraison attendent la confirmation de l'acheteur ; elles ne sont jamais
--   créditées au parrain qui vend lui-même sur la commande.
-- Retour arrière : drop trigger trg_order_lines_delivered on order_lines ; drop function confirm_receipt(text), seller_confirm_handover(text, text), money_auto_release(), money_hold_hours(), referral_award(orders) ;
--   select cron.unschedule('money-auto-release') ; recréer money_try_release et trg_money_release (20261114002800), set_seller_order_status (20261114000400), confirm_pickup (20261031000200),
--   my_pickup_code (20261031000200), on_order_paid_referral (20261115170000) ; alter table order_lines drop column delivered_at, confirmed_at, confirmed_via ; drop table order_refunds.

-- ============================================================ 1. colonnes et suivi de la remise
alter table order_lines add column if not exists delivered_at timestamptz;
alter table order_lines add column if not exists confirmed_at timestamptz;
alter table order_lines add column if not exists confirmed_via text;
alter table order_lines drop constraint if exists order_lines_confirmed_via_check;
alter table order_lines add constraint order_lines_confirmed_via_check check (confirmed_via is null or confirmed_via in ('buyer', 'code', 'staff'));

-- Les lignes déjà livrées n'ont pas de date : le délai de garde repart d'aujourd'hui (rien n'est libéré par surprise, rien n'est bloqué pour toujours).
update order_lines set delivered_at = now() where fulfillment >= 4 and delivered_at is null;

create or replace function trg_order_lines_delivered() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.fulfillment >= 4 and coalesce(old.fulfillment, 0) < 4 and new.delivered_at is null then new.delivered_at := now(); end if;
  return new;
end $$;
drop trigger if exists trg_order_lines_delivered on order_lines;
create trigger trg_order_lines_delivered before update of fulfillment on order_lines for each row execute function trg_order_lines_delivered();

-- Demandes d'annulation / remboursement d'une commande payée (traitées par le support ou la finance : voir 20261117040100).
create table if not exists order_refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  requested_by uuid references profiles(id) on delete set null,
  requester_role text not null default 'buyer' check (requester_role in ('buyer', 'seller', 'staff')),
  claim_id uuid references claims(id) on delete set null,
  reason text not null check (char_length(reason) between 10 and 1000),
  status text not null default 'requested' check (status in ('requested', 'approved', 'refunded', 'rejected')),
  amount integer not null default 0 check (amount >= 0),
  refund_phone text check (refund_phone is null or refund_phone ~ '^6[0-9]{8}$'),
  refund_provider text check (refund_provider is null or refund_provider in ('orange_money', 'mtn_momo')),
  decision_note text check (decision_note is null or char_length(decision_note) <= 500),
  reference text check (reference is null or char_length(reference) <= 80),
  decided_by uuid references profiles(id) on delete set null,
  decided_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists order_refunds_one_open on order_refunds (order_id) where status in ('requested', 'approved');
create index if not exists order_refunds_status on order_refunds (status, created_at);
alter table order_refunds enable row level security;
revoke all on order_refunds from anon, authenticated;
grant select on order_refunds to authenticated;
-- Lecture directe : demandeur, acheteur et équipe ; les vendeurs lisent par la RPC my_refunds().
drop policy if exists "remboursements : acheteur, vendeurs, équipe" on order_refunds;
drop policy if exists "remboursements : demandeur, acheteur, équipe" on order_refunds;
create policy "remboursements : demandeur, acheteur, équipe" on order_refunds for select
  using (requested_by = auth.uid()
         or exists (select 1 from orders o where o.id = order_id and o.buyer_id = auth.uid())
         or coalesce(current_role_name()::text, '') in ('admin', 'support', 'finance'));

-- ============================================================ 2. délai de garde et libération
create or replace function money_hold_hours() returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((select least(greatest((value #>> '{}')::numeric, 1), 720)::int from platform_settings where key = 'money.hold_hours' and jsonb_typeof(value) = 'number'), 72)
$$;

-- Y a-t-il une raison de garder l'argent d'une commande ? (réclamation non tranchée, litige, remboursement en cours)
create or replace function money_order_blocker(p_order uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from claims where order_id = p_order and status in ('open', 'answered')) then 'claim'
    when exists (select 1 from order_disputes where order_id = p_order and status = 'open') then 'dispute'
    when exists (select 1 from order_refunds where order_id = p_order and status in ('requested', 'approved')) then 'refund'
    else null end
$$;

-- Déblocage : tous les articles du vendeur sont livrés ET (confirmés par l'acheteur / le kiosque OU le délai de garde est écoulé), sans réclamation, litige ni remboursement en cours.
create or replace function money_try_release(p_order uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype; n integer := 0; v_hold integer := money_hold_hours();
begin
  if exists (select 1 from orders where id = p_order and (cancelled_at is not null or cancelled)) then return 0; end if;
  if money_order_blocker(p_order) is not null then return 0; end if;
  for e in select * from money_entries where order_id = p_order and status = 'held' and beneficiary_id is not null loop
    if exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = p_order and l.seller_id = e.beneficiary_id and ol.fulfillment < 4) then continue; end if;
    if exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id
               where ol.order_id = p_order and l.seller_id = e.beneficiary_id and ol.confirmed_at is null
                 and coalesce(ol.delivered_at, now()) + make_interval(hours => v_hold) > now()) then continue; end if;
    update money_entries set status = 'released', released_at = now() where id = e.id;
    insert into notifications (user_id, kind, title, body, data)
      values (e.beneficiary_id, 'money', 'Argent débloqué', e.beneficiary_amount || ' FCFA sont disponibles sur votre solde (commande ' || e.ref || ', part de ' || split_part(e.split, '/', 1) || ' %).', jsonb_build_object('entry', e.id));
    n := n + 1;
  end loop;
  return n;
end $$;

-- Tâche planifiée : libère les montants dont le délai de garde est écoulé sans réclamation.
create or replace function money_auto_release() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select distinct order_id from money_entries where status = 'held' and order_id is not null and beneficiary_id is not null limit 500 loop
    n := n + money_try_release(r.order_id);
  end loop;
  return n;
end $$;
revoke all on function money_hold_hours(), money_order_blocker(uuid), money_try_release(uuid), money_auto_release() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('money-auto-release') where exists (select 1 from cron.job where jobname = 'money-auto-release');
  perform cron.schedule('money-auto-release', '*/15 * * * *', 'select public.money_auto_release()');
exception when others then
  raise notice 'pg_cron indisponible : money_auto_release() doit être planifiée autrement, sinon le délai de garde ne libère rien (%).', sqlerrm;
end $$;

-- Libération : à la livraison, à la confirmation (acheteur, code, kiosque), puis par la tâche planifiée. Parrainage des commandes à la livraison : à la confirmation de TOUTES les lignes.
create or replace function trg_money_release() returns trigger language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if new.fulfillment >= 4 and (coalesce(old.fulfillment, 0) < 4 or (new.confirmed_at is not null and old.confirmed_at is null)) then
    perform money_try_release(new.order_id);
  end if;
  if new.confirmed_at is not null and old.confirmed_at is null then
    select * into o from orders where id = new.order_id;
    if found and o.cod and o.paid and o.cancelled_at is null and not o.cancelled
       and not exists (select 1 from order_lines where order_id = o.id and (confirmed_at is null or fulfillment < 4)) then
      perform referral_award(o);
    end if;
  end if;
  return null;
end $$;
drop trigger if exists trg_money_release on order_lines;
create trigger trg_money_release after update of fulfillment, confirmed_at on order_lines for each row execute function trg_money_release();

-- ============================================================ 3. parrainage (SQL1-17)
create or replace function referral_award(o orders) returns void
language plpgsql security definer set search_path = public as $$
declare rf referrals%rowtype; t record; month_count int; share int;
begin
  select * into rf from referrals where referee_id = o.buyer_id;
  if not found or rf.status = 'expired' then return; end if;
  -- le parrain ne gagne rien sur une commande où il est lui-même vendeur
  if exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = rf.referrer_id) then return; end if;
  if rf.status = 'pending' then
    if now() > rf.created_at + interval '90 days' then
      update referrals set status = 'expired' where referee_id = rf.referee_id;
      return;
    end if;
    if o.subtotal < 10000 then return; end if;
    select count(*) into month_count from referrals where referrer_id = rf.referrer_id and status = 'active' and activated_at >= date_trunc('month', now());
    update referrals set status = 'active', activated_at = now() where referee_id = rf.referee_id;
    select * into t from referral_tier(rf.referrer_id);
    if t.bonus is null then
      insert into notifications (user_id, kind, title, body, data)
        select a.id, 'referral', 'Parrainage : récompense non définie',
               'Un filleul est devenu actif mais aucun palier de récompense n''est défini (table referral_rules). Aucune prime n''a été créée.', jsonb_build_object('referral_rules', true)
        from profiles a
        where a.role::text = 'admin'
          and not exists (select 1 from notifications n where n.user_id = a.id and n.title = 'Parrainage : récompense non définie' and n.created_at > now() - interval '1 day');
    elsif t.bonus > 0 and month_count < 50 then
      insert into earnings (user_id, source, referee_id, order_id, amount) values (rf.referrer_id, 'referral_bonus', rf.referee_id, o.id, t.bonus)
      on conflict do nothing;
      insert into notifications (user_id, kind, title, body, data)
        values (rf.referrer_id, 'referral', 'Prime de parrainage', t.bonus || ' FCFA en attente (disponibles sous 14 jours).', jsonb_build_object('order', o.number));
    end if;
    rf.status := 'active'; rf.activated_at := now();
  end if;
  if rf.status = 'active' and now() <= rf.activated_at + interval '12 months' then
    select * into t from referral_tier(rf.referrer_id);
    share := least(floor(o.subtotal * t.share_pct), 5000);
    if share > 0 then
      insert into earnings (user_id, source, referee_id, order_id, amount) values (rf.referrer_id, 'referral_share', rf.referee_id, o.id, share)
      on conflict do nothing;
    end if;
  end if;
end $$;
revoke all on function referral_award(orders) from public, anon, authenticated;

-- Paiement Mobile Money confirmé : la prime est due tout de suite. Paiement à la livraison déclaré par le vendeur : elle attend la confirmation de l'acheteur.
create or replace function on_order_paid_referral() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not (new.paid and not coalesce(old.paid, false)) or new.cancelled or new.cancelled_at is not null then return null; end if;
  if coalesce(new.cod, false) then return null; end if;
  perform referral_award(new);
  return null;
end $$;

-- ============================================================ 4. avancement par le vendeur (ordre imposé) et remise
create or replace function set_seller_order_status(p_order text, p_status integer) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; cur integer; mgr boolean := is_platform_manager(); remaining integer; v_hold integer := money_hold_hours();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status < 1 or p_status > 4 then raise exception 'Statut invalide'; end if;
  select * into o from orders where number = p_order and (paid or cod) and cancelled_at is null and not cancelled;
  if not found then raise exception 'Commande introuvable ou non payée'; end if;
  select min(ol.fulfillment) into cur from order_lines ol join listings l on l.id = ol.listing_id
    where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr));
  if cur is null then raise exception 'Commande introuvable ou non payée'; end if;
  if p_status <= cur then raise exception 'Ce statut est déjà atteint ou dépassé'; end if;
  if p_status > cur + 1 then
    raise exception 'Passez les étapes dans l''ordre : la prochaine étape est « % »', case cur + 1 when 1 then 'Acceptée' when 2 then 'En préparation' when 3 then 'Prête' else 'Livrée' end;
  end if;
  update order_lines set fulfillment = p_status
    where order_id = o.id
      and listing_id in (select id from listings where seller_id = auth.uid() or (seller_id is null and mgr));
  insert into notifications (user_id, kind, title, body, data)
  values (o.buyer_id, 'order',
          case p_status when 1 then 'Commande acceptée' when 2 then 'Commande en préparation' when 3 then 'Commande prête' else 'Commande livrée' end,
          'Votre commande ' || o.number || case p_status when 1 then ' a été acceptée par le vendeur.' when 2 then ' est en préparation.' when 3 then ' est prête : vous pouvez la retirer.'
            else ' a été livrée selon le vendeur. Confirmez la réception ou signalez un problème sous ' || v_hold || ' h : passé ce délai, sans réclamation, le paiement est versé au vendeur.' end,
          jsonb_build_object('order_number', o.number, 'fulfillment', p_status));
  if p_status = 4 and o.cod and not o.paid then
    select count(*) into remaining from order_lines where order_id = o.id and fulfillment < 4;
    if remaining = 0 then update orders set paid = true where id = o.id; end if;   -- tout est remis : l'argent est encaissé
  end if;
  return p_status;
end $$;
revoke all on function set_seller_order_status(text, integer) from public, anon;
grant execute on function set_seller_order_status(text, integer) to authenticated;

-- L'acheteur confirme avoir reçu ses articles : le séquestre correspondant est libéré (sauf réclamation en cours).
create or replace function confirm_receipt(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.cancelled_at is not null or o.cancelled then raise exception 'Cette commande est annulée'; end if;
  if not (o.paid or o.cod) then raise exception 'Cette commande n''est pas payée'; end if;
  if money_order_blocker(o.id) is not null then raise exception 'Une réclamation, un litige ou un remboursement est en cours sur cette commande : il doit être réglé avant de confirmer la réception'; end if;
  update order_lines set confirmed_at = now(), confirmed_via = 'buyer' where order_id = o.id and fulfillment >= 4 and confirmed_at is null;
  get diagnostics n = row_count;
  if n = 0 then
    if exists (select 1 from order_lines where order_id = o.id and fulfillment >= 4) then return 'already'; end if;
    raise exception 'Le vendeur n''a pas encore déclaré la livraison de cette commande';
  end if;
  return 'confirmed';
end $$;
revoke all on function confirm_receipt(text) from public, anon;
grant execute on function confirm_receipt(text) to authenticated;

-- Remise en main propre : le vendeur saisit le code de retrait que l'acheteur affiche (« Mon code de retrait »). Un code juste vaut preuve de remise : libération immédiate.
create or replace function seller_confirm_handover(p_number text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; mgr boolean := is_platform_manager(); remaining integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and (paid or cod) and cancelled_at is null and not cancelled for update;
  if not found or not exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and (l.seller_id = auth.uid() or (l.seller_id is null and mgr))) then
    raise exception 'Commande introuvable ou non payée';
  end if;
  if o.home_delivery then raise exception 'Cette commande est livrée à domicile : la remise est confirmée par le client ou par le personnel'; end if;
  if o.pickup_attempts >= 5 then raise exception 'Trop d''essais : le client doit afficher un nouveau code de retrait'; end if;
  if o.pickup_code is null or o.pickup_code <> regexp_replace(coalesce(p_code, ''), '[^0-9]', '', 'g') then
    update orders set pickup_attempts = pickup_attempts + 1 where id = o.id;
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Code de retrait erroné (vendeur)', o.number, 'Kiosques', 'Sensible');
    return 'incorrect';
  end if;
  update order_lines set fulfillment = 4, delivered_at = coalesce(delivered_at, now()), confirmed_at = coalesce(confirmed_at, now()), confirmed_via = coalesce(confirmed_via, 'code')
    where order_id = o.id and listing_id in (select id from listings where seller_id = auth.uid() or (seller_id is null and mgr));
  if o.cod and not o.paid then
    select count(*) into remaining from order_lines where order_id = o.id and fulfillment < 4;
    if remaining = 0 then update orders set paid = true where id = o.id; end if;
  end if;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'order', 'Remise confirmée', 'La remise de votre commande ' || o.number || ' a été confirmée avec votre code de retrait.', jsonb_build_object('order_number', o.number, 'fulfillment', 4));
  return 'delivered';
end $$;
revoke all on function seller_confirm_handover(text, text) from public, anon;
grant execute on function seller_confirm_handover(text, text) to authenticated;

-- Code de retrait : disponible dès la commande payée OU confirmée pour un paiement à la livraison (le vendeur le saisit à la remise).
create or replace function my_pickup_code(p_number text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if not (o.paid or o.cod) or o.cancelled or o.cancelled_at is not null then raise exception 'Le code de retrait est délivré une fois la commande payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà retirée'; end if;
  if o.pickup_code is null or o.pickup_attempts >= 5 then
    update orders set pickup_code = lpad(((('x' || encode(gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0'), pickup_attempts = 0
    where id = o.id returning pickup_code into o.pickup_code;
  end if;
  return o.pickup_code;
end $$;

-- Remise au kiosque par le personnel : preuve de remise, libération immédiate.
create or replace function confirm_pickup(p_number text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au personnel du kiosque'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not o.paid or o.cancelled then raise exception 'Commande introuvable ou non payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà remise'; end if;
  if o.pickup_attempts >= 5 then raise exception 'Trop d''essais : l''acheteur doit afficher un nouveau code de retrait'; end if;
  if o.pickup_code is null or o.pickup_code <> trim(coalesce(p_code, '')) then
    update orders set pickup_attempts = pickup_attempts + 1 where id = o.id;
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Code de retrait erroné', o.number, 'Kiosques', 'Sensible');
    return 'incorrect';
  end if;
  update orders set picked_up_at = now(), status = 3 where id = o.id;
  update order_lines set fulfillment = 4, delivered_at = coalesce(delivered_at, now()), confirmed_at = coalesce(confirmed_at, now()), confirmed_via = coalesce(confirmed_via, 'staff') where order_id = o.id;
  insert into notifications (user_id, kind, title, body, data) values (o.buyer_id, 'order', 'Commande retirée', o.number, jsonb_build_object('order_number', o.number));
  return 'delivered';
end $$;
revoke all on function my_pickup_code(text), confirm_pickup(text, text) from public, anon;
grant execute on function my_pickup_code(text), confirm_pickup(text, text) to authenticated;
