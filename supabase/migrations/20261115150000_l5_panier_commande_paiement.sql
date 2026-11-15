-- Lot L5 (profil Client) : panier, commande, paiement, suivi.
-- 1. Carnet d'adresses : adresse « pour cette commande seulement » (colonne transient) qui ne compte pas dans la limite de 5 ; validations claires.
-- 2. promo_preview et delivery_quote comprennent les lignes « Pack » (clé pack), comme marketplace_checkout.
-- 3. delivery_zone_save : réservé aux vendeurs (student, dept, admin) pour les tarifs personnels ; plafond de villes ; modification par p_id.
-- 4. submit_claim : refuse une commande annulée ou non payée ; prévient tous les vendeurs concernés, le support, l'administration et le département.
-- 5. dispute_reply : l'équipe (admin, support) est prévenue de la réponse de l'acheteur.
-- 6. payment_instructions() : numéro marchand du paiement manuel, lu dans les réglages de la plateforme (clé payments.manual_number, définie par l'administrateur).
-- Retour arrière : voir la fin du fichier.

-- ============================================================ 1. carnet d'adresses
alter table addresses add column if not exists transient boolean not null default false;

drop function if exists save_address(uuid, text, text, text, text, text, text);
create or replace function save_address(p_id uuid, p_recipient text, p_phone text, p_city text, p_district text, p_line text, p_landmark text, p_transient boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare aid uuid; v_name text := trim(coalesce(p_recipient, '')); v_phone text := trim(coalesce(p_phone, '')); v_city text := trim(coalesce(p_city, ''));
  v_district text := coalesce(trim(p_district), ''); v_line text := trim(coalesce(p_line, '')); v_landmark text := left(coalesce(trim(p_landmark), ''), 160);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_name) not between 2 and 80 then raise exception 'Nom du destinataire : 2 à 80 caractères'; end if;
  if v_phone !~ '^\+?[0-9 ]{8,20}$' then raise exception 'Téléphone invalide : 8 à 20 chiffres (ex. 690 11 22 33)'; end if;
  if char_length(v_city) not between 2 and 60 then raise exception 'Indiquez la ville (2 à 60 caractères)'; end if;
  if char_length(v_line) not between 3 and 160 then raise exception 'Adresse précise : 3 à 160 caractères'; end if;
  if v_district <> '' and (char_length(v_district) not between 2 and 60 or v_district ~ '[<>{}\[\]\\|@#$%^*=+~`"]') then raise exception 'Quartier invalide (2 à 60 caractères, sans symboles)'; end if;
  if p_id is null then
    if coalesce(p_transient, false) then
      delete from addresses where user_id = auth.uid() and transient;
      insert into addresses (user_id, recipient, phone, city, district, line, landmark, transient)
        values (auth.uid(), v_name, v_phone, v_city, v_district, v_line, v_landmark, true) returning id into aid;
      return aid;
    end if;
    if (select count(*) from addresses where user_id = auth.uid() and not transient) >= 5 then raise exception 'Carnet complet : 5 adresses au maximum'; end if;
    insert into addresses (user_id, recipient, phone, city, district, line, landmark)
      values (auth.uid(), v_name, v_phone, v_city, v_district, v_line, v_landmark) returning id into aid;
  else
    update addresses set recipient = v_name, phone = v_phone, city = v_city, district = v_district, line = v_line, landmark = v_landmark
    where id = p_id and user_id = auth.uid() returning id into aid;
    if aid is null then raise exception 'Adresse introuvable'; end if;
  end if;
  if char_length(v_district) >= 2 and char_length(v_city) >= 2 then
    insert into neighborhoods (city, name, official, uses) values (v_city, v_district, false, 1)
    on conflict (lower(city), lower(name)) do update set uses = neighborhoods.uses + 1;
  end if;
  return aid;
end $$;
revoke all on function save_address(uuid, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function save_address(uuid, text, text, text, text, text, text, boolean) to authenticated;

-- ============================================================ 2. promo_preview et delivery_quote : lignes « Pack »
create or replace function promo_preview(p_code text, p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pc promo_codes%rowtype; it jsonb; comp jsonb; l listings%rowtype; pk shop_packs%rowtype;
  v_base int := 0; v_disc int; v_sub int := 0; q int; v_normal bigint; v_cq int; v_unit int;
begin
  select * into pc from promo_codes where code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
    return jsonb_build_object('valid', false, 'message', 'Code promo invalide ou expiré');
  end if;
  if not pc.auto_apply and auth.uid() is not null and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = auth.uid()) then return jsonb_build_object('valid', false, 'message', 'Code promo déjà utilisé'); end if;
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it->>'qty')::int, 1), 1), 20);
    if it ? 'pack' then
      select * into pk from shop_packs where id = (it->>'pack')::uuid and active;
      if found then
        select sum(x.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(pk.items) i join listings x on x.id = (i->>'listing')::uuid;
        if coalesce(v_normal, 0) > 0 then
          for comp in select * from jsonb_array_elements(pk.items) loop
            v_cq := (comp->>'qty')::int;
            select * into l from listings where id = (comp->>'listing')::uuid;
            if found and v_cq > 0 then
              v_unit := greatest((pk.price::bigint * (l.price * v_cq) / v_normal)::int / v_cq, 1);
              v_sub := v_sub + v_unit * q * v_cq;
              if pc.shop_id is null or l.shop_id = pc.shop_id then v_base := v_base + v_unit * q * v_cq; end if;
            end if;
          end loop;
        end if;
      end if;
      continue;
    end if;
    select * into l from listings where status = 'approved' and ((it ? 'id' and id = (it->>'id')::uuid) or (not it ? 'id' and title = it->>'title')) limit 1;
    if found then
      v_sub := v_sub + l.price * q;
      if (pc.shop_id is null or l.shop_id = pc.shop_id) and not exists (select 1 from flash_sales f where f.listing_id = l.id and not f.cancelled and f.starts_at <= now() and f.ends_at > now()) then v_base := v_base + l.price * q; end if;
    end if;
  end loop;
  if v_base = 0 or v_base < pc.min_amount then return jsonb_build_object('valid', false, 'message', 'Ce code ne s''applique pas à votre panier'); end if;
  v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
  return jsonb_build_object('valid', true, 'discount', least(v_disc, greatest(v_sub - 500, 0)), 'code', pc.code);
end $$;

create or replace function delivery_quote(p_city text, p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare it jsonb; comp jsonb; pk shop_packs%rowtype; v_lid uuid; v_ids uuid[] := '{}'; v_lines jsonb := '[]'::jsonb; v_total int := 0; v_f int; rec record; v_unserved text[] := '{}';
begin
  if nullif(trim(coalesce(p_city, '')), '') is null then return jsonb_build_object('fee', null, 'lines', '[]'::jsonb, 'unserved', '[]'::jsonb); end if;
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    if it ? 'pack' then
      select * into pk from shop_packs where id = (it->>'pack')::uuid and active;
      if found then
        for comp in select * from jsonb_array_elements(pk.items) loop
          v_ids := v_ids || (comp->>'listing')::uuid;
        end loop;
      end if;
    elsif it ? 'id' then
      v_ids := v_ids || (it->>'id')::uuid;
    else
      select id into v_lid from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1;
      if found then v_ids := v_ids || v_lid; end if;
    end if;
  end loop;
  for rec in
    select x.sid, x.from_city, x.nm from (
      select distinct l2.seller_id as sid, _seller_city(l2) as from_city, coalesce(sh.name, display_name(l2.seller_id), 'Boutik-École') as nm
      from listings l2 left join shops sh on sh.id = l2.shop_id
      where l2.id = any(v_ids) and l2.status = 'approved') x
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
revoke all on function promo_preview(text, jsonb), delivery_quote(text, jsonb) from public;
grant execute on function promo_preview(text, jsonb), delivery_quote(text, jsonb) to anon, authenticated;

-- ============================================================ 3. tarifs de livraison : réservés aux vendeurs
create or replace function delivery_zone_save(p_to_city text, p_fee integer, p_from_city text default null, p_platform boolean default false, p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_seller uuid := case when coalesce(p_platform, false) then null else auth.uid() end; v_id uuid; v_to text := trim(coalesce(p_to_city, '')); v_from text := nullif(trim(coalesce(p_from_city, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_platform, false) then
    if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  elsif coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then
    raise exception 'Les tarifs de livraison sont réservés aux étudiants-vendeurs';
  end if;
  if char_length(v_to) not between 2 and 60 then raise exception 'Indiquez la ville de livraison (2 à 60 caractères)'; end if;
  if v_from is not null and char_length(v_from) not between 2 and 60 then raise exception 'Ville de départ invalide (2 à 60 caractères)'; end if;
  if p_fee is null or p_fee < 0 or p_fee > 1000000 then raise exception 'Frais invalides (0 pour une livraison gratuite)'; end if;
  if p_id is not null then
    begin
      update delivery_zones set from_city = v_from, to_city = v_to, fee = p_fee, active = true
      where id = p_id and seller_id is not distinct from v_seller returning id into v_id;
    exception when unique_violation then raise exception 'Un tarif existe déjà pour cette ville';
    end;
    if v_id is null then raise exception 'Tarif introuvable'; end if;
    return v_id;
  end if;
  if (select count(*) from delivery_zones where seller_id is not distinct from v_seller) >= 60
     and not exists (select 1 from delivery_zones where seller_id is not distinct from v_seller and lower(coalesce(from_city, '')) = lower(coalesce(v_from, '')) and lower(to_city) = lower(v_to)) then
    raise exception 'Limite de 60 villes atteinte : supprimez un tarif avant d''en ajouter un autre';
  end if;
  insert into delivery_zones (seller_id, from_city, to_city, fee) values (v_seller, v_from, v_to, p_fee)
  on conflict (coalesce(seller_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(coalesce(from_city, '')), lower(to_city)) do update set fee = excluded.fee, active = true
  returning id into v_id;
  return v_id;
end $$;
revoke all on function delivery_zone_save(text, integer, text, boolean, uuid) from public, anon;
grant execute on function delivery_zone_save(text, integer, text, boolean, uuid) to authenticated;

-- ============================================================ 4. réclamation
create or replace function submit_claim(p_order text, p_reason text, p_details text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; seller uuid; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_order and buyer_id = auth.uid();
  if not found then raise exception 'Commande introuvable'; end if;
  if o.cancelled_at is not null or o.cancelled then raise exception 'Cette commande est annulée : aucune réclamation n''est possible'; end if;
  if not o.paid and not o.cod then raise exception 'Cette commande n''est pas encore payée : annulez-la depuis « Annuler la commande » si vous n''en voulez plus'; end if;
  if p_reason not in ('not_received', 'damaged', 'cancel_before_prep', 'refund') then raise exception 'Motif invalide'; end if;
  if p_details is null or char_length(trim(p_details)) < 10 then raise exception 'Décrivez le problème en 10 caractères minimum'; end if;
  if exists (select 1 from claims where order_id = o.id and status = 'open') then raise exception 'Une réclamation est déjà ouverte pour cette commande'; end if;
  select l.seller_id into seller from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null order by ol.id limit 1;
  insert into claims (order_id, claimant_id, seller_id, reason, details) values (o.id, auth.uid(), seller, p_reason, left(trim(p_details), 2000)) returning id into cid;
  insert into notifications (user_id, kind, title, body, data)
    select distinct l.seller_id, 'claim', 'Réclamation reçue', 'Commande ' || o.number || ' : une réclamation a été déposée.', jsonb_build_object('order_number', o.number, 'claim_id', cid)
    from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'claim', 'Réclamation à suivre', 'Commande ' || o.number || ' : une réclamation vient d''être déposée.', jsonb_build_object('order_number', o.number, 'claim_id', cid)
    from profiles p
    where not coalesce(p.suspended, false) and (p.role::text in ('admin', 'support')
      or (p.role::text = 'dept' and p.department is not null and p.department in (select sp.department from order_lines ol join listings l on l.id = ol.listing_id join profiles sp on sp.id = l.seller_id where ol.order_id = o.id and sp.department is not null)));
  return cid;
end $$;

-- ============================================================ 5. litige : l'équipe est prévenue de la réponse de l'acheteur
create or replace function dispute_reply(p_id uuid, p_reply text) returns void
language plpgsql security definer set search_path = public as $$
declare v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_reply, ''))) < 3 then raise exception 'Écrivez votre réponse'; end if;
  update order_disputes set buyer_reply = left(btrim(p_reply), 1000) where id = p_id and buyer_id = auth.uid() and status = 'open';
  if not found then raise exception 'Litige introuvable ou déjà tranché'; end if;
  select o.number into v_num from order_disputes d join orders o on o.id = d.order_id where d.id = p_id;
  insert into notifications (user_id, kind, title, body, data)
    select d.opened_by, 'dispute', 'Réponse de l''acheteur', 'L''acheteur a répondu au litige sur la commande ' || v_num || '.', jsonb_build_object('dispute', d.id, 'order_number', v_num)
    from order_disputes d where d.id = p_id;
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'dispute', 'Réponse de l''acheteur à examiner', 'Commande ' || v_num || ' : l''acheteur a répondu au litige.', jsonb_build_object('dispute', p_id, 'order_number', v_num)
    from profiles p where p.role::text in ('admin', 'support') and not coalesce(p.suspended, false);
end $$;

-- ============================================================ 6. instructions du paiement manuel
create or replace function payment_instructions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_num text; v_op text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select trim(both '"' from value::text) into v_num from platform_settings where key = 'payments.manual_number';
  select trim(both '"' from value::text) into v_op from platform_settings where key = 'payments.manual_operator';
  return jsonb_build_object('merchant_number', nullif(v_num, ''), 'operator', nullif(v_op, ''));
end $$;
revoke all on function payment_instructions() from public, anon;
grant execute on function payment_instructions() to authenticated;

-- Retour arrière :
--   drop function if exists payment_instructions();
--   recopier les versions précédentes : dispute_reply (20261114002000), submit_claim (20261030000800), delivery_zone_save et delivery_quote (20261114000800), promo_preview (20261114000700) ;
--   drop function save_address(uuid, text, text, text, text, text, text, boolean); puis recréer la version de 20261114000800 ; alter table addresses drop column transient;
