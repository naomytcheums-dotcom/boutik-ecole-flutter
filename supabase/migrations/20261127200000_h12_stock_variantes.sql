-- Lot H12 STOCK (1/2) : stock par variante (couleur, taille, ...) pour les annonces de produits.
--  1. listing_variants : libellé, attributs (jsonb), SKU optionnel unique par vendeur, stock, seuil d'alerte, actif. AUCUN prix par variante :
--     toutes les variantes d'une annonce se vendent au prix de l'annonce (prix, ventes flash, codes promo, commissions et séquestre inchangés).
--  2. Une annonce SANS variante active garde exactement le comportement actuel (stock global listings.stock).
--     Une annonce AVEC variantes actives : listings.stock = somme des stocks des variantes actives (maintenu par trigger), si bien que toutes les
--     lectures existantes (cartes, filtres « en stock », ventes flash, alertes « me prévenir ») restent exactes. Le stock global ne se modifie plus
--     à la main tant que des variantes sont actives (message clair) ; une décrémentation interne d'une annonce à variantes est refusée.
--  3. stock_movements : colonnes variant_id et stock_before ; chaque changement de stock d'une variante est journalisé (raison, commande, avant/après).
--  4. Alerte de stock bas : notification au vendeur UNE fois par franchissement de seuil (ok -> bas, ok/bas -> épuisé), jamais répétée tant que l'état ne s'améliore pas.
--  5. RPC : variant_save, variant_set_active, variant_adjust (audité), seller_variants_list (stock exact, propriétaire), listing_variants_public (état seulement).
-- Additive et rejouable. Retour arrière (manuel) : voir le bas du fichier.

-- ============================================================ 1. table
create table if not exists listing_variants (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  seller_id uuid,
  label text not null check (char_length(btrim(label)) between 1 and 80),
  attributes jsonb not null default '{}'::jsonb check (jsonb_typeof(attributes) = 'object'),
  sku text check (sku is null or char_length(sku) between 1 and 40),
  stock integer not null default 0 check (stock >= 0 and stock <= 100000),
  low_threshold integer not null default 3 check (low_threshold between 0 and 100000),
  alert_state text not null default 'ok' check (alert_state in ('ok', 'low', 'out')),
  active boolean not null default true,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists listing_variants_label_uniq on listing_variants (listing_id, lower(btrim(label)));
create unique index if not exists listing_variants_sku_seller_uniq on listing_variants (seller_id, lower(sku)) where sku is not null and seller_id is not null;
create unique index if not exists listing_variants_sku_platform_uniq on listing_variants (lower(sku)) where sku is not null and seller_id is null;
create index if not exists listing_variants_listing_idx on listing_variants (listing_id) where active;

alter table listing_variants enable row level security;
revoke all on listing_variants from anon, authenticated;
grant select on listing_variants to authenticated;
drop policy if exists "variantes lisibles par le vendeur et le departement" on listing_variants;
create policy "variantes lisibles par le vendeur et le departement" on listing_variants for select
  using (seller_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin'));

alter table order_lines add column if not exists variant_id uuid references listing_variants(id) on delete set null;
alter table order_lines add column if not exists variant_restocked_at timestamptz;
create index if not exists order_lines_variant_idx on order_lines (variant_id) where variant_id is not null;

alter table stock_movements add column if not exists variant_id uuid references listing_variants(id) on delete set null;
alter table stock_movements add column if not exists stock_before integer;

-- ============================================================ 2. synchronisation du stock de l'annonce (somme des variantes actives)
create or replace function _variant_sync_listing(p_listing uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_sum bigint; v_n integer; v_int text := coalesce(current_setting('app.internal', true), ''); v_sync text := coalesce(current_setting('app.variant_sync', true), '');
begin
  select count(*), coalesce(sum(stock) filter (where active), 0) into v_n, v_sum from listing_variants where listing_id = p_listing;
  if v_n = 0 then return; end if;
  perform set_config('app.internal', '1', true);
  perform set_config('app.variant_sync', '1', true);
  update listings set stock = least(v_sum, 100000)::int where id = p_listing and stock is distinct from least(v_sum, 100000)::int;
  perform set_config('app.variant_sync', v_sync, true);
  perform set_config('app.internal', v_int, true);
end $$;
revoke all on function _variant_sync_listing(uuid) from public, anon, authenticated;

create or replace function _variant_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _variant_sync_listing(case when tg_op = 'DELETE' then old.listing_id else new.listing_id end);
  return null;
end $$;
revoke all on function _variant_after_change() from public, anon, authenticated;
drop trigger if exists trg_h12_variant_sync on listing_variants;
create trigger trg_h12_variant_sync after insert or update of stock, active or delete on listing_variants for each row execute function _variant_after_change();

-- ============================================================ 3. alerte de seuil (une fois par franchissement) et journal des mouvements
create or replace function _variant_state_before() returns trigger
language plpgsql set search_path = public as $$
begin
  new.alert_state := case when new.stock = 0 then 'out' when new.stock <= new.low_threshold then 'low' else 'ok' end;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_h12_variant_state on listing_variants;
create trigger trg_h12_variant_state before insert or update of stock, low_threshold on listing_variants for each row execute function _variant_state_before();

create or replace function _variant_alert_after() returns trigger
language plpgsql security definer set search_path = public as $$
declare s seller_settings%rowtype; v_low boolean := true; v_out boolean := true; l listings%rowtype;
begin
  if new.alert_state = old.alert_state or not new.active or new.seller_id is null then return null; end if;
  if new.alert_state = 'ok' or (new.alert_state = 'low' and old.alert_state = 'out') then return null; end if;   -- amélioration : l'état est réarmé en silence
  select * into s from seller_settings where user_id = new.seller_id;
  if found then v_low := s.notify_low; v_out := s.notify_out; end if;
  select * into l from listings where id = new.listing_id;
  if new.alert_state = 'out' and v_out then
    perform notify_user(new.seller_id, 'listing', 'Variante épuisée', l.title || ' — ' || new.label || ' est épuisée.', jsonb_build_object('listing', new.listing_id, 'variant', new.id));
  elsif new.alert_state = 'low' and v_low then
    perform notify_user(new.seller_id, 'listing', 'Stock bas (variante)', l.title || ' — ' || new.label || ' : plus que ' || new.stock || ' en stock.', jsonb_build_object('listing', new.listing_id, 'variant', new.id));
  end if;
  return null;
end $$;
revoke all on function _variant_alert_after() from public, anon, authenticated;
drop trigger if exists trg_h12_variant_alert on listing_variants;
create trigger trg_h12_variant_alert after update of stock, low_threshold on listing_variants for each row execute function _variant_alert_after();

create or replace function _variant_log_movement() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into stock_movements (listing_id, variant_id, delta, stock_before, stock_after, reason, order_number, actor)
    values (new.listing_id, new.id, new.stock, 0, new.stock, coalesce(nullif(current_setting('app.stock_reason', true), ''), 'stock initial'), nullif(current_setting('app.order_number', true), ''), auth.uid());
  elsif new.stock is distinct from old.stock then
    insert into stock_movements (listing_id, variant_id, delta, stock_before, stock_after, reason, order_number, actor)
    values (new.listing_id, new.id, new.stock - old.stock, old.stock, new.stock, coalesce(nullif(current_setting('app.stock_reason', true), ''), 'ajustement'), nullif(current_setting('app.order_number', true), ''), auth.uid());
  end if;
  return null;
end $$;
revoke all on function _variant_log_movement() from public, anon, authenticated;
drop trigger if exists trg_h12_variant_movement on listing_variants;
create trigger trg_h12_variant_movement after insert or update of stock on listing_variants for each row execute function _variant_log_movement();

-- Le journal et l'alerte de l'annonce ne doublonnent pas ceux des variantes : un changement de stock issu de la somme des variantes n'est journalisé qu'au niveau variante.
create or replace function log_stock_movement() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('app.variant_sync', true), '') = '1' then return null; end if;
  if tg_op = 'INSERT' then
    insert into stock_movements (listing_id, delta, stock_after, reason, actor) values (new.id, new.stock, new.stock, 'stock initial', auth.uid());
  elsif new.stock is distinct from old.stock then
    insert into stock_movements (listing_id, delta, stock_before, stock_after, reason, order_number, actor)
    values (new.id, new.stock - old.stock, old.stock, new.stock, coalesce(nullif(current_setting('app.stock_reason', true), ''), 'ajustement'), nullif(current_setting('app.order_number', true), ''), auth.uid());
  end if;
  return null;
end $$;

create or replace function s3_stock_alert() returns trigger
language plpgsql security definer set search_path = public as $$
declare s seller_settings%rowtype; v_thr integer := 30; v_low boolean := true; v_out boolean := true;
begin
  if coalesce(current_setting('app.variant_sync', true), '') = '1' then return null; end if;   -- annonce à variantes : alertes par variante
  if new.seller_id is null or new.status <> 'approved' or offer_type_of(new.category) <> 'product' or new.stock is not distinct from old.stock then return null; end if;
  select * into s from seller_settings where user_id = new.seller_id;
  if found then v_thr := s.stock_threshold; v_low := s.notify_low; v_out := s.notify_out; end if;
  if new.stock = 0 and old.stock > 0 then
    if v_out then perform notify_user(new.seller_id, 'listing', 'Rupture de stock', new.title || ' est épuisé.', jsonb_build_object('listing', new.id)); end if;
  elsif new.stock > 0 and new.stock <= v_thr and old.stock > v_thr then
    if v_low then perform notify_user(new.seller_id, 'listing', 'Stock bas', new.title || ' : plus que ' || new.stock || ' en stock.', jsonb_build_object('listing', new.id)); end if;
  end if;
  return null;
end $$;

-- ============================================================ 4. garde du stock global d'une annonce à variantes
create or replace function _h12_listing_stock_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.stock is not distinct from old.stock or coalesce(current_setting('app.variant_sync', true), '') = '1' then return new; end if;
  if not exists (select 1 from listing_variants v where v.listing_id = new.id and v.active) then return new; end if;
  if auth.uid() is not null and coalesce(current_setting('app.internal', true), '') <> '1' then
    raise exception 'Le stock de cette annonce se gère par variante : ajustez le stock de chaque variante';
  end if;
  -- chemin interne : une restitution est appliquée aux variantes (trigger de commande), jamais au stock global ; une vente globale est refusée
  if new.stock < old.stock then raise exception 'Cette annonce se vend par variante : choisissez une variante (variant_required)'; end if;
  new.stock := old.stock;
  return new;
end $$;
revoke all on function _h12_listing_stock_guard() from public, anon, authenticated;
drop trigger if exists trg_h12_listing_stock_guard on listings;
create trigger trg_h12_listing_stock_guard before update of stock on listings for each row execute function _h12_listing_stock_guard();

-- ============================================================ 5. RPC vendeur
create or replace function _variant_owner_listing(p_listing uuid) returns listings
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); l listings%rowtype;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into l from listings where id = p_listing for update;
  if not found then raise exception 'Annonce introuvable'; end if;
  if l.seller_id is null then
    if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Annonce introuvable'; end if;
  else
    if l.seller_id <> uid then raise exception 'Annonce introuvable'; end if;
    perform _seller_require(uid, false);
  end if;
  if l.status = 'removed' then raise exception 'Annonce retirée'; end if;
  if offer_type_of(l.category) <> 'product' then raise exception 'Seul un produit a du stock : une variante ne s''ajoute pas à un service ou à une autre offre'; end if;
  return l;
end $$;
revoke all on function _variant_owner_listing(uuid) from public, anon, authenticated;

create or replace function _variant_json(v listing_variants, p_exact boolean) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('id', v.id, 'listing_id', v.listing_id, 'label', v.label, 'attributes', v.attributes, 'active', v.active,
           'state', case when v.stock = 0 then 'out' when v.stock <= v.low_threshold then 'low' else 'available' end)
         || case when p_exact then jsonb_build_object('sku', v.sku, 'stock', v.stock, 'low_threshold', v.low_threshold, 'position', v.position) else '{}'::jsonb end
$$;
revoke all on function _variant_json(listing_variants, boolean) from public, anon, authenticated;

create or replace function variant_save(p_listing uuid, p_label text, p_attributes jsonb default '{}'::jsonb, p_sku text default null, p_stock integer default null, p_threshold integer default 3, p_id uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; v listing_variants%rowtype; v_label text := btrim(regexp_replace(coalesce(p_label, ''), '\s+', ' ', 'g')); v_sku text := nullif(btrim(coalesce(p_sku, '')), '');
        v_attr jsonb := coalesce(p_attributes, '{}'::jsonb); v_stock integer; v_k text; v_val jsonb;
begin
  l := _variant_owner_listing(p_listing);
  if char_length(v_label) < 1 or char_length(v_label) > 80 then raise exception 'Indiquez le libellé de la variante (1 à 80 caractères)'; end if;
  if jsonb_typeof(v_attr) <> 'object' or (select count(*) from jsonb_object_keys(v_attr)) > 6 then raise exception 'Attributs : un objet de 6 critères au plus (taille, couleur...)'; end if;
  for v_k, v_val in select * from jsonb_each(v_attr) loop
    if char_length(v_k) > 30 or jsonb_typeof(v_val) <> 'string' or char_length(v_val #>> '{}') > 60 then raise exception 'Attribut invalide : un nom de 30 caractères et une valeur texte de 60 caractères au plus'; end if;
  end loop;
  if v_sku is not null and (char_length(v_sku) > 40 or v_sku !~ '^[A-Za-z0-9._/-]+$') then raise exception 'SKU : 40 caractères au plus (lettres, chiffres, . _ / -)'; end if;
  if p_threshold is null or p_threshold < 0 or p_threshold > 100000 then raise exception 'Seuil d''alerte : un entier de 0 à 100 000'; end if;
  if p_id is null then
    if (select count(*) from listing_variants where listing_id = l.id and active) >= 30 then raise exception '30 variantes actives au maximum par annonce'; end if;
    if not exists (select 1 from listing_variants where listing_id = l.id and active)
       and exists (select 1 from order_lines ol join orders o on o.id = ol.order_id
                   where ol.listing_id = l.id and ol.variant_id is null and o.cancelled_at is null and not coalesce(o.cancelled, false) and not o.paid) then
      raise exception 'Des commandes non payées réservent encore cet article : attendez leur paiement ou leur expiration avant de créer des variantes';
    end if;
    v_stock := coalesce(p_stock, case when exists (select 1 from listing_variants where listing_id = l.id) then 0 else l.stock end);
    if v_stock < 0 or v_stock > 100000 then raise exception 'Stock : un entier de 0 à 100 000'; end if;
    if (select coalesce(sum(stock), 0) from listing_variants where listing_id = l.id and active) + v_stock > 100000 then raise exception 'Le stock total de l''annonce est limité à 100 000'; end if;
    perform set_config('app.stock_reason', 'stock initial', true);
    begin
      insert into listing_variants (listing_id, seller_id, label, attributes, sku, stock, low_threshold, position)
      values (l.id, l.seller_id, v_label, v_attr, v_sku, v_stock, p_threshold, (select coalesce(max(position), 0) + 1 from listing_variants where listing_id = l.id)) returning * into v;
    exception when unique_violation then
      perform set_config('app.stock_reason', '', true);
      if exists (select 1 from listing_variants where listing_id = l.id and lower(btrim(label)) = lower(v_label)) then raise exception 'Cette annonce a déjà une variante « % »', v_label; end if;
      raise exception 'Ce SKU est déjà utilisé par une autre de vos variantes';
    end;
    perform set_config('app.stock_reason', '', true);
  else
    select * into v from listing_variants where id = p_id and listing_id = l.id for update;
    if not found then raise exception 'Variante introuvable'; end if;
    begin
      update listing_variants set label = v_label, attributes = v_attr, sku = v_sku, low_threshold = p_threshold where id = v.id returning * into v;
    exception when unique_violation then
      if exists (select 1 from listing_variants where listing_id = l.id and id <> v.id and lower(btrim(label)) = lower(v_label)) then raise exception 'Cette annonce a déjà une variante « % »', v_label; end if;
      raise exception 'Ce SKU est déjà utilisé par une autre de vos variantes';
    end;
  end if;
  return _variant_json(v, true);
end $$;
revoke all on function variant_save(uuid, text, jsonb, text, integer, integer, uuid) from public, anon;
grant execute on function variant_save(uuid, text, jsonb, text, integer, integer, uuid) to authenticated;

create or replace function variant_set_active(p_id uuid, p_active boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v listing_variants%rowtype; l listings%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select listing_id into v.listing_id from listing_variants where id = p_id;
  if not found then raise exception 'Variante introuvable'; end if;
  l := _variant_owner_listing(v.listing_id);
  select * into v from listing_variants where id = p_id for update;
  if p_active is null then raise exception 'Choix invalide'; end if;
  if p_active and not v.active and (select count(*) from listing_variants where listing_id = l.id and active) >= 30 then raise exception '30 variantes actives au maximum par annonce'; end if;
  update listing_variants set active = p_active where id = v.id returning * into v;
  return _variant_json(v, true);
end $$;
revoke all on function variant_set_active(uuid, boolean) from public, anon;
grant execute on function variant_set_active(uuid, boolean) to authenticated;

-- Ajustement manuel du stock : valeur exacte (p_set) OU variation (p_delta), motif obligatoire, journalisé (mouvement + audit).
create or replace function variant_adjust(p_id uuid, p_set integer default null, p_delta integer default null, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v listing_variants%rowtype; l listings%rowtype; v_new integer; v_reason text := btrim(coalesce(p_reason, '')); v_who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select listing_id into v.listing_id from listing_variants where id = p_id;
  if not found then raise exception 'Variante introuvable'; end if;
  l := _variant_owner_listing(v.listing_id);
  select * into v from listing_variants where id = p_id for update;
  if (p_set is null) = (p_delta is null) then raise exception 'Indiquez soit le nouveau stock, soit la variation'; end if;
  if char_length(v_reason) < 3 or char_length(v_reason) > 200 then raise exception 'Indiquez le motif de l''ajustement (3 à 200 caractères)'; end if;
  v_new := coalesce(p_set, v.stock + p_delta);
  if v_new < 0 then raise exception 'Stock insuffisant : il ne reste que % exemplaire(s), le stock ne peut pas devenir négatif', v.stock; end if;
  if v_new > 100000 then raise exception 'Stock : un entier de 0 à 100 000'; end if;
  if v.active and (select coalesce(sum(stock), 0) from listing_variants where listing_id = l.id and active and id <> v.id) + v_new > 100000 then raise exception 'Le stock total de l''annonce est limité à 100 000'; end if;
  perform set_config('app.stock_reason', 'ajustement vendeur : ' || v_reason, true);
  update listing_variants set stock = v_new where id = v.id returning * into v;
  perform set_config('app.stock_reason', '', true);
  select name into v_who from profiles where id = auth.uid();
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(v_who, 'Utilisateur'), auth.uid(), left('Stock ajusté : ' || l.title || ' — ' || v.label || ' → ' || v_new, 120), v.id::text, 'Marketplace', 'Normal');
  return _variant_json(v, true);
end $$;
revoke all on function variant_adjust(uuid, integer, integer, text) from public, anon;
grant execute on function variant_adjust(uuid, integer, integer, text) to authenticated;

create or replace function seller_variants_list(p_listing uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); l listings%rowtype;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into l from listings where id = p_listing;
  if not found or l.seller_id is distinct from uid then raise exception 'Annonce introuvable'; end if;
  return coalesce((select jsonb_agg(_variant_json(v, true) order by v.position, v.created_at) from listing_variants v where v.listing_id = l.id), '[]'::jsonb);
end $$;
revoke all on function seller_variants_list(uuid) from public, anon;
grant execute on function seller_variants_list(uuid) to authenticated;

-- Lecture publique : variantes actives d'une annonce publiée, avec un état (available / low / out) ; le stock exact n'est jamais renvoyé,
-- seul le nombre restant l'est quand il est bas (« derniers exemplaires »).
create or replace function listing_variants_public(p_listing uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l listings%rowtype;
begin
  select * into l from listings where id = p_listing;
  if not found or (l.status <> 'approved' and l.seller_id is distinct from auth.uid()) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(_variant_json(v, false) || case when v.stock > 0 and v.stock <= v.low_threshold then jsonb_build_object('left', v.stock) else '{}'::jsonb end order by v.position, v.created_at)
                   from listing_variants v where v.listing_id = l.id and v.active), '[]'::jsonb);
end $$;
revoke all on function listing_variants_public(uuid) from public;
grant execute on function listing_variants_public(uuid) to anon, authenticated;

-- Retour arrière (manuel) :
--   drop trigger trg_h12_variant_sync, trg_h12_variant_state, trg_h12_variant_alert, trg_h12_variant_movement on listing_variants ; drop trigger trg_h12_listing_stock_guard on listings ;
--   drop function variant_save(uuid, text, jsonb, text, integer, integer, uuid), variant_set_active(uuid, boolean), variant_adjust(uuid, integer, integer, text), seller_variants_list(uuid),
--     listing_variants_public(uuid), _variant_json(listing_variants, boolean), _variant_owner_listing(uuid), _variant_sync_listing(uuid), _variant_after_change(), _variant_state_before(),
--     _variant_alert_after(), _variant_log_movement(), _h12_listing_stock_guard() ;
--   recréer log_stock_movement (20261030000200) et s3_stock_alert (20261117030000) ; alter table order_lines drop column variant_id, variant_restocked_at ; alter table stock_movements drop column variant_id, stock_before ; drop table listing_variants.
