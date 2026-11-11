-- Livraison par ville : chaque vendeur (ou l'administrateur pour toute la plateforme) fixe ses frais de livraison selon la ville du client ;
-- les frais peuvent être de 0 (« Gratuit »). Les quartiers saisis par les clients sont enregistrés et proposés aux suivants.
-- Ordre de recherche des frais : tarif du vendeur pour la ville > tarif de la plateforme pour la ville > frais de l'IUT si la livraison reste dans la ville de départ.
-- Sans tarif pour une ville, la livraison vers cette ville n'est pas proposée par ce vendeur.
-- Retour arrière : drop function delivery_quote(text, jsonb), my_delivery_zones(boolean), delivery_zone_save(text, integer, text, boolean, uuid), delivery_zone_delete(uuid), suggest_districts(text, text, integer),
--                   _delivery_fee_for(uuid, text, text), _seller_city(listings); drop table delivery_zones, neighborhoods; puis recréer marketplace_checkout et save_address depuis les migrations précédentes.

create table if not exists delivery_zones (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid references profiles(id) on delete cascade,        -- nul : tarif de la plateforme (administrateur)
  from_city text check (from_city is null or char_length(from_city) between 2 and 60),  -- nul : depuis n'importe quelle ville
  to_city text not null check (char_length(to_city) between 2 and 60),
  fee integer not null check (fee between 0 and 1000000),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists delivery_zones_unique on delivery_zones (coalesce(seller_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(coalesce(from_city, '')), lower(to_city));
alter table delivery_zones enable row level security;
revoke all on delivery_zones from anon, authenticated;

create table if not exists neighborhoods (
  id uuid primary key default gen_random_uuid(),
  city text not null check (char_length(city) between 2 and 60),
  name text not null check (char_length(name) between 2 and 80),
  official boolean not null default false,        -- vrai : carte officielle ; faux : saisi par des clients
  uses integer not null default 1,
  created_at timestamptz not null default now()
);
create unique index if not exists neighborhoods_unique on neighborhoods (lower(city), lower(name));
alter table neighborhoods enable row level security;
revoke all on neighborhoods from anon, authenticated;

insert into neighborhoods (city, name, official, uses) values
  ('Douala', 'Akwa', true, 0), ('Douala', 'Bonanjo', true, 0), ('Douala', 'Bonapriso', true, 0), ('Douala', 'Deido', true, 0), ('Douala', 'Bali', true, 0),
  ('Douala', 'Bonabéri', true, 0), ('Douala', 'Makepe', true, 0), ('Douala', 'Bonamoussadi', true, 0), ('Douala', 'Logpom', true, 0), ('Douala', 'Ndokoti', true, 0),
  ('Douala', 'Kotto', true, 0), ('Douala', 'Logbaba', true, 0), ('Douala', 'Bépanda', true, 0), ('Douala', 'New Bell', true, 0), ('Douala', 'Nyalla', true, 0),
  ('Douala', 'Yassa', true, 0), ('Douala', 'Cité des Palmiers', true, 0), ('Douala', 'Bonaberi Petit Pays', true, 0), ('Douala', 'PK 14', true, 0),
  ('Yaoundé', 'Bastos', true, 0), ('Yaoundé', 'Mvan', true, 0), ('Yaoundé', 'Mokolo', true, 0), ('Yaoundé', 'Essos', true, 0), ('Yaoundé', 'Biyem-Assi', true, 0),
  ('Yaoundé', 'Melen', true, 0), ('Yaoundé', 'Ngoa-Ekelle', true, 0), ('Yaoundé', 'Nlongkak', true, 0), ('Yaoundé', 'Mvog-Mbi', true, 0), ('Yaoundé', 'Emana', true, 0),
  ('Yaoundé', 'Odza', true, 0), ('Yaoundé', 'Obili', true, 0), ('Yaoundé', 'Etoudi', true, 0), ('Yaoundé', 'Tsinga', true, 0), ('Yaoundé', 'Omnisports', true, 0)
on conflict do nothing;

-- Ville d'origine d'une annonce : celle de la boutique, sinon celle du vendeur, sinon Douala.
create or replace function _seller_city(l listings) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim((select s.city from shops s where s.id = l.shop_id)), ''), nullif(trim((select p.city from profiles p where p.id = l.seller_id)), ''), 'Douala')
$$;
revoke all on function _seller_city(listings) from public, anon, authenticated;

create or replace function _zone_fee(p_seller uuid, p_from text, p_to text) returns integer
language sql stable security definer set search_path = public as $$
  select z.fee from delivery_zones z
  where z.active and lower(z.to_city) = lower(trim(p_to)) and z.seller_id is not distinct from p_seller
    and (z.from_city is null or lower(z.from_city) = lower(trim(p_from)))
  order by (z.from_city is not null) desc limit 1
$$;
revoke all on function _zone_fee(uuid, text, text) from public, anon, authenticated;

-- Frais d'un vendeur vers une ville : null si la livraison n'est pas proposée.
create or replace function _delivery_fee_for(p_seller uuid, p_from text, p_to text) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(
    _zone_fee(p_seller, p_from, p_to),
    _zone_fee(null, p_from, p_to),
    case when lower(trim(p_from)) = lower(trim(p_to)) then (select home_delivery_fee from institution_settings where id = 'iut-douala') end)
$$;
revoke all on function _delivery_fee_for(uuid, text, text) from public, anon, authenticated;

create or replace function marketplace_checkout(p_items jsonb, p_home boolean, p_method text, p_address uuid default null, p_code text default null, p_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  o orders%rowtype; st institution_settings%rowtype; adr addresses%rowtype;
  v_fee int := 0; num text; oid uuid; it jsonb; l listings%rowtype; fs flash_sales%rowtype; pk shop_packs%rowtype; pc promo_codes%rowtype; comp jsonb;
  rec record; v_f int; q int; sub int := 0; v_price int; v_reserved int; v_base int; v_disc int := 0; v_normal int; v_unit int; v_cq int; v_share int; v_flash uuid;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_key is not null then
    if char_length(p_key) not between 8 and 80 then raise exception 'Clé d''idempotence invalide'; end if;
    select * into o from orders where buyer_id = uid and idem_key = p_key;
    if found then return jsonb_build_object('number', o.number, 'subtotal', o.subtotal, 'fee', o.fee, 'discount', o.discount, 'replayed', true); end if;
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if jsonb_array_length(p_items) > 30 then raise exception 'Panier trop volumineux'; end if;
  if coalesce(p_home, false) then
    select * into st from institution_settings where id = 'iut-douala';
    if not found or not st.home_delivery_enabled then raise exception 'Livraison à domicile non proposée pour le moment : choisissez le retrait sur campus'; end if;
    select * into adr from addresses where id = p_address and user_id = uid;
    if not found then raise exception 'Choisissez une adresse de livraison'; end if;
    -- les frais dépendent de la ville de livraison et de chaque vendeur : ils sont calculés une fois les lignes de commande créées
  end if;
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  perform set_config('app.internal', '1', true);
  perform set_config('app.stock_reason', 'commande', true);
  perform set_config('app.order_number', num, true);
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery, delivery_address, idem_key)
    values (num, uid, 0, v_fee, coalesce(nullif(p_method, ''), 'Mobile Money'), 0, false, coalesce(p_home, false),
            case when coalesce(p_home, false) then jsonb_build_object('recipient', adr.recipient, 'phone', adr.phone, 'city', adr.city, 'district', adr.district, 'line', adr.line, 'landmark', adr.landmark) end,
            p_key)
    returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    q := coalesce((it->>'qty')::int, 1);
    if q < 1 or q > 20 then raise exception 'Quantité invalide'; end if;
    if it ? 'pack' then
      select * into pk from shop_packs where id = (it->>'pack')::uuid and active;
      if not found or not exists (select 1 from shops where id = pk.shop_id and status = 'active') then raise exception 'Pack indisponible'; end if;
      select sum(x.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(pk.items) i join listings x on x.id = (i->>'listing')::uuid;
      for comp in select * from jsonb_array_elements(pk.items) loop
        v_cq := (comp->>'qty')::int;
        select * into l from listings where id = (comp->>'listing')::uuid and status = 'approved' for update;
        if not found then raise exception 'Pack indisponible : composant retiré'; end if;
        if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
        select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
        if l.stock - q * v_cq < v_reserved then raise exception 'Stock insuffisant : %', l.title; end if;
        update listings set stock = stock - q * v_cq where id = l.id and stock >= q * v_cq;
        if not found then raise exception 'Stock insuffisant : %', l.title; end if;
        v_share := (pk.price::bigint * (l.price * v_cq) / v_normal)::int;           -- part du prix du pack, au prorata (arrondi au franc inférieur)
        v_unit := greatest(v_share / v_cq, 1);
        insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id) values (oid, l.id, l.title, v_unit, q * v_cq, l.shop_id);
        sub := sub + v_unit * q * v_cq;
      end loop;
      continue;
    end if;
    if it ? 'id' then
      select * into l from listings where id = (it->>'id')::uuid and status = 'approved' for update;
    else
      select * into l from listings where id = (select id from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1) for update;
    end if;
    if not found then raise exception 'Produit indisponible : %', coalesce(it->>'title', it->>'id'); end if;
    if l.seller_id = uid then raise exception 'Vous ne pouvez pas acheter votre propre produit'; end if;
    if l.shop_id is not null and not exists (select 1 from shops where id = l.shop_id and status = 'active') then raise exception 'Boutique indisponible : %', l.title; end if;
    if l.stock < q then raise exception 'Stock insuffisant : %', l.title; end if;
    v_price := l.price; v_flash := null;
    select * into fs from flash_sales where listing_id = l.id and not cancelled and starts_at <= now() and ends_at > now() and sold + q <= stock order by sale_price limit 1 for update;
    if found then
      v_price := fs.sale_price; v_flash := fs.id;
      update flash_sales set sold = sold + q where id = fs.id;
    else
      select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
      if l.stock - q < v_reserved then raise exception 'Stock insuffisant : % (le reste est réservé à une vente flash)', l.title; end if;
    end if;
    update listings set stock = stock - q where id = l.id and stock >= q;
    if not found then raise exception 'Stock insuffisant : %', l.title; end if;
    insert into order_lines (order_id, listing_id, title, unit_price, qty, shop_id, variant, flash_id)
      values (oid, l.id, l.title, v_price, q, l.shop_id, nullif(left(coalesce(it->>'variant', ''), 80), ''), v_flash);
    sub := sub + v_price * q;
  end loop;
  if coalesce(p_home, false) then
    for rec in select l2.seller_id as sid, _seller_city(l2) as from_city, coalesce(sh.name, display_name(l2.seller_id), 'Boutik-École') as nm
               from order_lines ol join listings l2 on l2.id = ol.listing_id left join shops sh on sh.id = l2.shop_id
               where ol.order_id = oid group by l2.seller_id, _seller_city(l2), coalesce(sh.name, display_name(l2.seller_id), 'Boutik-École') loop
      v_f := _delivery_fee_for(rec.sid, rec.from_city, adr.city);
      if v_f is null then raise exception 'Livraison vers % non proposée par % : choisissez le retrait ou une autre adresse', adr.city, rec.nm; end if;
      v_fee := v_fee + v_f;
    end loop;
    update orders set fee = v_fee where id = oid;
  end if;
  if nullif(trim(coalesce(p_code, '')), '') is not null then
    select * into pc from promo_codes where code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g')) for update;
    if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
      raise exception 'Code promo invalide ou expiré';
    end if;
    if not pc.auto_apply and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = uid) then raise exception 'Code promo déjà utilisé'; end if;
    select coalesce(sum(unit_price * qty), 0) into v_base from order_lines where order_id = oid and flash_id is null and (pc.shop_id is null or shop_id = pc.shop_id);
    if v_base = 0 or v_base < pc.min_amount then raise exception 'Ce code ne s''applique pas à votre panier (montant minimum % FCFA sur la boutique concernée)', pc.min_amount; end if;
    v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
    v_disc := least(v_disc, greatest(sub - 500, 0));
    if not pc.auto_apply then
      update promo_codes set used_count = used_count + 1 where id = pc.id;
      insert into promo_redemptions (code_id, user_id, order_id) values (pc.id, uid, oid);
    end if;
  end if;
  update orders set subtotal = sub - v_disc, discount = v_disc, promo_code = pc.code where id = oid;
  perform set_config('app.internal', '', true);
  perform set_config('app.stock_reason', '', true);
  perform set_config('app.order_number', '', true);
  return jsonb_build_object('number', num, 'subtotal', sub - v_disc, 'fee', v_fee, 'discount', v_disc, 'replayed', false);
end $$;

-- Frais de livraison d'un panier vers une ville, vendeur par vendeur (affichés avant le paiement ; le serveur les recalcule à la commande).
create or replace function delivery_quote(p_city text, p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare it jsonb; l listings%rowtype; v_lines jsonb := '[]'::jsonb; v_total int := 0; v_f int; rec record; v_unserved text[] := '{}';
begin
  if nullif(trim(coalesce(p_city, '')), '') is null then return jsonb_build_object('fee', null, 'lines', '[]'::jsonb, 'unserved', '[]'::jsonb); end if;
  for rec in
    select x.sid, x.from_city, x.nm from (
      select distinct l2.seller_id as sid, _seller_city(l2) as from_city, coalesce(sh.name, display_name(l2.seller_id), 'Boutik-École') as nm
      from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) i
      join listings l2 on l2.status = 'approved' and ((i ? 'id' and l2.id = (i->>'id')::uuid) or (not i ? 'id' and l2.title = i->>'title'))
      left join shops sh on sh.id = l2.shop_id) x
  loop
    v_f := _delivery_fee_for(rec.sid, rec.from_city, p_city);
    if v_f is null then
      v_unserved := v_unserved || rec.nm;
    else
      v_total := v_total + v_f;
      v_lines := v_lines || jsonb_build_object('seller', rec.nm, 'from_city', rec.from_city, 'fee', v_f);
    end if;
  end loop;
  return jsonb_build_object('fee', case when cardinality(v_unserved) > 0 then null else v_total end, 'lines', v_lines, 'unserved', to_jsonb(v_unserved));
end $$;
revoke all on function delivery_quote(text, jsonb) from public;
grant execute on function delivery_quote(text, jsonb) to anon, authenticated;

-- Tarifs de livraison du vendeur (ou de la plateforme pour l'administrateur).
create or replace function my_delivery_zones(p_platform boolean default false) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_platform, false) and coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', z.id, 'from_city', z.from_city, 'to_city', z.to_city, 'fee', z.fee, 'active', z.active) order by lower(z.to_city))
    from delivery_zones z where z.seller_id is not distinct from case when coalesce(p_platform, false) then null else auth.uid() end), '[]'::jsonb);
end $$;

create or replace function delivery_zone_save(p_to_city text, p_fee integer, p_from_city text default null, p_platform boolean default false, p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_seller uuid := case when coalesce(p_platform, false) then null else auth.uid() end; v_id uuid; v_to text := trim(coalesce(p_to_city, '')); v_from text := nullif(trim(coalesce(p_from_city, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_platform, false) and coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  if char_length(v_to) < 2 then raise exception 'Indiquez la ville de livraison'; end if;
  if p_fee is null or p_fee < 0 or p_fee > 1000000 then raise exception 'Frais invalides (0 pour une livraison gratuite)'; end if;
  insert into delivery_zones (seller_id, from_city, to_city, fee) values (v_seller, v_from, v_to, p_fee)
  on conflict (coalesce(seller_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(coalesce(from_city, '')), lower(to_city)) do update set fee = excluded.fee, active = true
  returning id into v_id;
  return v_id;
end $$;

create or replace function delivery_zone_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from delivery_zones where id = p_id and (seller_id = auth.uid() or (seller_id is null and coalesce(current_role_name()::text, '') = 'admin'));
  if not found then raise exception 'Tarif introuvable'; end if;
end $$;

-- Quartiers proposés pendant la saisie : carte officielle et quartiers déjà saisis par d'autres clients, les plus utilisés d'abord.
create or replace function suggest_districts(p_city text, p_q text default null, p_limit integer default 8) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', n.name, 'official', n.official) order by (lower(n.name) like lower(coalesce(trim(p_q), '')) || '%') desc, n.official desc, n.uses desc, n.name), '[]'::jsonb)
  from (select * from neighborhoods
        where lower(city) = lower(trim(coalesce(p_city, ''))) and (nullif(trim(coalesce(p_q, '')), '') is null or lower(name) like '%' || lower(trim(p_q)) || '%')
        order by official desc, uses desc limit least(greatest(coalesce(p_limit, 8), 1), 20)) n
$$;
revoke all on function suggest_districts(text, text, integer) from public;
grant execute on function suggest_districts(text, text, integer) to anon, authenticated;

-- Enregistrement d'une adresse : un quartier inconnu de la carte est mémorisé automatiquement pour les clients suivants.
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
  if char_length(coalesce(trim(p_district), '')) >= 2 and char_length(trim(p_city)) >= 2 then
    insert into neighborhoods (city, name, official, uses) values (trim(p_city), trim(p_district), false, 1)
    on conflict (lower(city), lower(name)) do update set uses = neighborhoods.uses + 1;
  end if;
  return aid;
end $$;

revoke all on function my_delivery_zones(boolean), delivery_zone_save(text, integer, text, boolean, uuid), delivery_zone_delete(uuid) from public, anon;
grant execute on function my_delivery_zones(boolean), delivery_zone_save(text, integer, text, boolean, uuid), delivery_zone_delete(uuid) to authenticated;
