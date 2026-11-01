-- Livraison (écrans 07, 27, 41, 46), selon REGLES_METIER_PROPOSEES.md § 5.
-- Retrait sur campus par défaut. La livraison à domicile est DÉSACTIVÉE tant que l'administrateur ne l'active pas
-- (équipe logistique disponible) : le serveur la refuse alors, aucun frais n'est facturé.
-- Carnet d'adresses (5 au plus), adresse figée sur la commande, remise confirmée par le code à 6 chiffres existant.
-- Aucune donnée existante n'est modifiée (colonnes ajoutées avec des valeurs par défaut neutres).

-- 1. Réglage de la livraison à domicile -------------------------------------------------------------------------------
alter table institution_settings add column if not exists home_delivery_enabled boolean not null default false;
alter table institution_settings add column if not exists home_delivery_city text not null default 'Douala';
alter table institution_settings add column if not exists home_delivery_fee integer not null default 5000 check (home_delivery_fee between 0 and 100000);

create or replace function set_home_delivery(p_enabled boolean, p_city text, p_fee integer) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_city is null or char_length(trim(p_city)) not between 2 and 60 then raise exception 'Ville invalide'; end if;
  if p_fee is null or p_fee not between 0 and 100000 then raise exception 'Frais invalides'; end if;
  update institution_settings set home_delivery_enabled = p_enabled, home_delivery_city = trim(p_city), home_delivery_fee = p_fee, updated_by = auth.uid(), updated_at = now()
  where id = 'iut-douala';
  insert into audit_log (actor, action, target, category, level)
    values (auth.uid()::text, case when p_enabled then 'Livraison à domicile activée' else 'Livraison à domicile désactivée' end, trim(p_city) || ' · ' || p_fee || ' FCFA', 'Paramètres', 'Sensible');
  return case when p_enabled then 'enabled' else 'disabled' end;
end $$;

-- 2. Carnet d'adresses --------------------------------------------------------------------------------------------------
create table if not exists addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  recipient text not null check (char_length(recipient) between 2 and 80),
  phone text not null check (phone ~ '^\+?[0-9 ]{8,20}$'),
  city text not null check (char_length(city) between 2 and 60),
  district text not null default '' check (char_length(district) <= 80),
  line text not null check (char_length(line) between 3 and 160),
  landmark text not null default '' check (char_length(landmark) <= 120),
  created_at timestamptz not null default now()
);
create index if not exists addresses_user on addresses (user_id);
alter table addresses enable row level security;
revoke all on addresses from anon, authenticated;
grant select on addresses to authenticated;
drop policy if exists "adresses : titulaire" on addresses;
create policy "adresses : titulaire" on addresses for select using (user_id = auth.uid());

create or replace function save_address(p_id uuid, p_recipient text, p_phone text, p_city text, p_district text, p_line text, p_landmark text) returns uuid
language plpgsql security definer set search_path = public as $$
declare aid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_id is null then
    if (select count(*) from addresses where user_id = auth.uid()) >= 5 then raise exception 'Carnet complet : 5 adresses au maximum'; end if;
    insert into addresses (user_id, recipient, phone, city, district, line, landmark)
      values (auth.uid(), trim(p_recipient), trim(p_phone), trim(p_city), coalesce(trim(p_district), ''), trim(p_line), coalesce(trim(p_landmark), ''))
      returning id into aid;
  else
    update addresses set recipient = trim(p_recipient), phone = trim(p_phone), city = trim(p_city), district = coalesce(trim(p_district), ''),
      line = trim(p_line), landmark = coalesce(trim(p_landmark), '')
    where id = p_id and user_id = auth.uid() returning id into aid;
    if aid is null then raise exception 'Adresse introuvable'; end if;
  end if;
  return aid;
end $$;

create or replace function delete_address(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from addresses where id = p_id and user_id = auth.uid();
  if not found then raise exception 'Adresse introuvable'; end if;
  return 'deleted';
end $$;

-- 3. Commande : mode de remise, adresse figée, suivi de livraison ------------------------------------------------------
alter table orders add column if not exists home_delivery boolean not null default false;
alter table orders add column if not exists delivery_address jsonb;
alter table orders add column if not exists out_for_delivery_at timestamptz;
alter table orders add column if not exists delivery_attempts smallint not null default 0;

-- Version principale : l'adresse est obligatoire pour la livraison à domicile, qui doit être activée et dans la ville desservie.
create or replace function create_order(p_items jsonb, p_home boolean, p_method text, p_address uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  sub int := 0;
  st institution_settings%rowtype;
  adr addresses%rowtype;
  v_fee int := 0;
  num text;
  oid uuid;
  it jsonb;
  l listings%rowtype;
  q int;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if coalesce(p_home, false) then
    select * into st from institution_settings where id = 'iut-douala';
    if not found or not st.home_delivery_enabled then raise exception 'Livraison à domicile non proposée pour le moment : choisissez le retrait sur campus'; end if;
    select * into adr from addresses where id = p_address and user_id = uid;
    if not found then raise exception 'Choisissez une adresse de livraison'; end if;
    if lower(trim(adr.city)) <> lower(trim(st.home_delivery_city)) then raise exception 'Livraison à domicile proposée seulement à %', st.home_delivery_city; end if;
    v_fee := st.home_delivery_fee;
  end if;
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  perform set_config('app.internal', '1', true);
  perform set_config('app.stock_reason', 'commande', true);
  perform set_config('app.order_number', num, true);
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, delivery_address)
    values (num, uid, 0, v_fee, coalesce(nullif(p_method, ''), 'Mobile Money'), 0, false, coalesce(p_home, false),
            case when coalesce(p_home, false) then jsonb_build_object('recipient', adr.recipient, 'phone', adr.phone, 'city', adr.city,
              'district', adr.district, 'line', adr.line, 'landmark', adr.landmark) end)
    returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    q := coalesce((it->>'qty')::int, 1);
    if q < 1 or q > 20 then raise exception 'Quantité invalide'; end if;
    update listings set stock = stock - q
      where id = (select id from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1)
        and stock >= q
      returning * into l;
    if not found then
      if exists (select 1 from listings where title = it->>'title' and status = 'approved') then
        raise exception 'Stock insuffisant : %', it->>'title';
      end if;
      raise exception 'Produit indisponible : %', it->>'title';
    end if;
    sub := sub + l.price * q;
    insert into order_lines (order_id, listing_id, title, unit_price, qty) values (oid, l.id, l.title, l.price, q);
  end loop;
  update orders set subtotal = sub where id = oid;
  perform set_config('app.internal', '', true);
  perform set_config('app.stock_reason', '', true);
  perform set_config('app.order_number', '', true);
  return jsonb_build_object('number', num, 'subtotal', sub, 'fee', v_fee);
end $$;

-- Ancienne signature (client déjà déployé) : retrait sur campus inchangé ; la livraison à domicile exige désormais une adresse.
create or replace function create_order(p_items jsonb, p_home boolean, p_method text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  return create_order(p_items, p_home, p_method, null::uuid);
end $$;

-- 4. Circuit de livraison (équipe logistique : rôle support) ------------------------------------------------------------
create or replace function start_delivery(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé à l''équipe logistique'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not o.paid or o.cancelled or o.cancelled_at is not null then raise exception 'Commande introuvable ou non payée'; end if;
  if not o.home_delivery then raise exception 'Commande à retirer sur campus'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà remise'; end if;
  if exists (select 1 from order_lines where order_id = o.id and fulfillment < 3) then raise exception 'La commande n''est pas encore prête'; end if;
  update orders set out_for_delivery_at = now() where id = o.id;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'order', 'Commande en livraison', o.number || ' : préparez votre code de retrait, le livreur vous le demandera.', jsonb_build_object('order_number', o.number));
  return 'out_for_delivery';
end $$;

create or replace function delivery_failed(p_number text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé à l''équipe logistique'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not o.home_delivery or o.out_for_delivery_at is null or o.picked_up_at is not null then raise exception 'Aucune livraison en cours pour cette commande'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Motif obligatoire'; end if;
  update orders set delivery_attempts = delivery_attempts + 1, out_for_delivery_at = null,
    -- 2 tentatives sans succès : retour au kiosque, retrait sur campus
    home_delivery = case when delivery_attempts + 1 >= 2 then false else true end
  where id = o.id returning * into o;
  insert into notifications (user_id, kind, title, body, data)
    values (o.buyer_id, 'order', case when o.home_delivery then 'Livraison reportée' else 'Commande à retirer sur campus' end,
            o.number || ' : ' || trim(p_reason) || case when o.home_delivery then ' (nouvelle tentative prévue)' else ' (2 tentatives : la commande vous attend au kiosque)' end,
            jsonb_build_object('order_number', o.number, 'attempts', o.delivery_attempts));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Livraison échouée', o.number || ' · ' || trim(p_reason), 'Kiosques', 'Normal');
  return case when o.home_delivery then 'rescheduled' else 'returned_to_kiosk' end;
end $$;

-- 5. Droits d'exécution -------------------------------------------------------------------------------------------------
revoke all on function set_home_delivery(boolean, text, integer), save_address(uuid, text, text, text, text, text, text), delete_address(uuid),
  create_order(jsonb, boolean, text, uuid), create_order(jsonb, boolean, text), start_delivery(text), delivery_failed(text, text) from public, anon;
grant execute on function set_home_delivery(boolean, text, integer), save_address(uuid, text, text, text, text, text, text), delete_address(uuid),
  create_order(jsonb, boolean, text, uuid), create_order(jsonb, boolean, text), start_delivery(text), delivery_failed(text, text) to authenticated;

-- Retour arrière (manuel) : réappliquer create_order(jsonb, boolean, text) de 20261030000200_annonces_stock.sql ;
-- drop function create_order(jsonb, boolean, text, uuid), set_home_delivery(boolean, text, integer), save_address(uuid, text, text, text, text, text, text),
--   delete_address(uuid), start_delivery(text), delivery_failed(text, text); drop table addresses;
-- alter table orders drop column home_delivery, drop column delivery_address, drop column out_for_delivery_at, drop column delivery_attempts;
-- alter table institution_settings drop column home_delivery_enabled, drop column home_delivery_city, drop column home_delivery_fee;
