-- 1. Devis accepté -> commande au prix convenu (service, solution ou projet) : la commande se paie ensuite comme les autres (Mobile Money ou à la remise).
-- 2. Refus de payer à la remise : le vendeur ouvre un litige, l'acheteur répond, l'équipe tranche (clore ou annuler la commande et remettre le stock).
-- 3. Annonce épinglée dans une communauté : les membres actifs sont notifiés.
-- Retour arrière : drop function quote_checkout(uuid, text), dispute_open(text, text), dispute_reply(uuid, text), dispute_decide(uuid, text, text), my_disputes();
--   drop table order_disputes; alter table quote_requests drop column order_number ; recréer pin_community_post depuis 20261114000900.

-- ---------------------------------------------------------------- 1. devis -> commande
alter table quote_requests add column if not exists order_number text;

create or replace function quote_checkout(p_quote uuid, p_method text default 'Mobile Money') returns jsonb
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; l listings%rowtype; num text; oid uuid; v_method text := coalesce(nullif(btrim(p_method), ''), 'Mobile Money');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_quote and requester_id = auth.uid() for update;
  if not found then raise exception 'Devis introuvable'; end if;
  if q.status <> 'accepted' then raise exception 'Acceptez d''abord le devis pour commander'; end if;
  if q.order_number is not null then return jsonb_build_object('number', q.order_number, 'subtotal', q.quote_amount, 'fee', 0, 'existing', true); end if;
  if q.quote_amount is null or q.quote_amount <= 0 then raise exception 'Ce devis n''a pas de montant'; end if;
  select * into l from listings where id = q.listing_id;
  if not found then raise exception 'Offre introuvable'; end if;
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  perform set_config('app.internal', '1', true);
  perform set_config('app.order_number', num, true);
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery)
    values (num, auth.uid(), q.quote_amount, 0, v_method, 0, false, false) returning id into oid;
  insert into order_lines (order_id, listing_id, title, unit_price, qty) values (oid, l.id, l.title, q.quote_amount, 1);
  perform set_config('app.internal', '', true);
  perform set_config('app.order_number', '', true);
  update quote_requests set order_number = num where id = q.id;
  insert into notifications (user_id, kind, title, body, data)
    values (q.provider_id, 'order', 'Commande au prix du devis', 'Commande ' || num || ' pour « ' || l.title || ' » : ' || q.quote_amount || ' FCFA, à préparer dès le paiement.', jsonb_build_object('order_number', num, 'quote_id', q.id));
  return jsonb_build_object('number', num, 'subtotal', q.quote_amount, 'fee', 0, 'existing', false);
end $$;
revoke all on function quote_checkout(uuid, text) from public, anon;
grant execute on function quote_checkout(uuid, text) to authenticated;

-- ---------------------------------------------------------------- 2. litige : refus de payer à la remise
create table if not exists order_disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  opened_by uuid not null references profiles(id) on delete cascade,
  buyer_id uuid not null references profiles(id) on delete cascade,
  note text not null check (char_length(note) between 10 and 1000),
  buyer_reply text check (buyer_reply is null or char_length(buyer_reply) between 3 and 1000),
  status text not null default 'open' check (status in ('open', 'resolved')),
  decision text check (decision is null or decision in ('close', 'cancel')),
  decision_note text check (decision_note is null or char_length(decision_note) <= 500),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create unique index if not exists order_disputes_one_open on order_disputes (order_id) where status = 'open';
alter table order_disputes enable row level security;
revoke all on order_disputes from anon, authenticated;

-- Le vendeur d'une commande à payer à la livraison, prête ou livrée mais non encaissée, signale que le client refuse de payer.
create or replace function dispute_open(p_order text, p_note text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_order and cod and not paid and cancelled_at is null and not cancelled;
  if not found then raise exception 'Seule une commande à payer à la livraison, non encaissée, peut faire l''objet d''un litige'; end if;
  if not exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = auth.uid()) then raise exception 'Commande introuvable'; end if;
  if char_length(btrim(coalesce(p_note, ''))) < 10 then raise exception 'Expliquez ce qui s''est passé en 10 caractères minimum'; end if;
  begin
    insert into order_disputes (order_id, opened_by, buyer_id, note) values (o.id, auth.uid(), o.buyer_id, left(btrim(p_note), 1000)) returning id into v_id;
  exception when unique_violation then raise exception 'Un litige est déjà ouvert pour cette commande';
  end;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'dispute', 'Litige sur votre commande', 'Le vendeur signale un problème de paiement sur la commande ' || o.number || '. Répondez depuis « Mes litiges ».', jsonb_build_object('dispute', v_id, 'order_number', o.number));
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'dispute', 'Litige à trancher', 'Commande ' || o.number || ' : refus de payer à la remise signalé.', jsonb_build_object('dispute', v_id, 'order_number', o.number)
    from profiles p where p.role::text in ('admin', 'support');
  return v_id;
end $$;

create or replace function dispute_reply(p_id uuid, p_reply text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_reply, ''))) < 3 then raise exception 'Écrivez votre réponse'; end if;
  update order_disputes set buyer_reply = left(btrim(p_reply), 1000) where id = p_id and buyer_id = auth.uid() and status = 'open';
  if not found then raise exception 'Litige introuvable ou déjà tranché'; end if;
  insert into notifications (user_id, kind, title, body, data)
    select d.opened_by, 'dispute', 'Réponse de l''acheteur', 'L''acheteur a répondu au litige sur la commande ' || (select number from orders where id = d.order_id) || '.', jsonb_build_object('dispute', d.id)
    from order_disputes d where d.id = p_id;
end $$;

-- Décision de l'équipe : « close » clôt le litige sans changer la commande ; « cancel » annule la commande et remet le stock.
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
  insert into notifications (user_id, kind, title, body, data)
    select u, 'dispute', 'Litige tranché', 'Commande ' || o.number || (case when p_decision = 'cancel' then ' : annulée par l''équipe.' else ' : litige clos.' end), jsonb_build_object('dispute', d.id)
    from unnest(array[d.opened_by, d.buyer_id]) u;
  return p_decision;
end $$;

create or replace function my_disputes() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'order_number', o.number, 'note', d.note, 'buyer_reply', d.buyer_reply, 'status', d.status, 'decision', d.decision,
      'decision_note', d.decision_note, 'created_at', d.created_at, 'as', case when d.buyer_id = auth.uid() then 'buyer' when d.opened_by = auth.uid() then 'seller' else 'staff' end) order by d.created_at desc), '[]'::jsonb)
  from order_disputes d join orders o on o.id = d.order_id
  where d.buyer_id = auth.uid() or d.opened_by = auth.uid() or is_platform_staff()
$$;

revoke all on function dispute_open(text, text), dispute_reply(uuid, text), dispute_decide(uuid, text, text), my_disputes() from public, anon;
grant execute on function dispute_open(text, text), dispute_reply(uuid, text), dispute_decide(uuid, text, text), my_disputes() to authenticated;

-- ---------------------------------------------------------------- 3. annonce épinglée : les membres sont notifiés
create or replace function pin_community_post(p_post uuid, p_pin boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_comm uuid; v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select community_id into v_comm from posts where id = p_post and kind in ('text', 'poll') and status = 'published';
  if v_comm is null then raise exception 'Publication introuvable'; end if;
  if community_rank(v_comm, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Réservé aux responsables de la communauté'; end if;
  if p_pin and (select count(*) from posts where community_id = v_comm and pinned) >= 3 then raise exception 'Trois annonces épinglées au plus : retirez-en une'; end if;
  update posts set pinned = coalesce(p_pin, false), pinned_at = case when p_pin then now() end where id = p_post;
  if p_pin then
    select name into v_name from communities where id = v_comm;
    insert into notifications (user_id, kind, title, body, data)
      select m.user_id, 'community_announcement', 'Nouvelle annonce', 'Une annonce a été épinglée dans « ' || v_name || ' ».', jsonb_build_object('community', v_comm, 'post', p_post)
      from community_members m where m.community_id = v_comm and m.status = 'active' and m.user_id <> auth.uid();
  end if;
  return case when p_pin then 'pinned' else 'unpinned' end;
end $$;
revoke all on function pin_community_post(uuid, boolean) from public, anon;
grant execute on function pin_community_post(uuid, boolean) to authenticated;
