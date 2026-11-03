-- Annonces vendeur et stock réels : statut brouillon, propriété forcée, historique, mouvements de stock,
-- décrément atomique à la commande, annulation (libération du stock), images isolées par vendeur.
-- À exécuter dans l'éditeur SQL Supabase. Retour arrière : voir la fin du fichier.

-- 1. Contraintes et colonnes ----------------------------------------------------------------------------------------
alter table listings drop constraint if exists listings_status_check;
alter table listings add constraint listings_status_check check (status in ('draft', 'pending', 'approved', 'rejected', 'removed'));
alter table listings add column if not exists review_note text;
alter table listings add column if not exists updated_at timestamptz not null default now();
alter table listings add column if not exists images text[] not null default '{}';
alter table listings drop constraint if exists listings_stock_check;
alter table listings add constraint listings_stock_check check (stock >= 0 and stock <= 100000);
alter table listings drop constraint if exists listings_title_len;
alter table listings add constraint listings_title_len check (char_length(title) between 3 and 80);
alter table listings drop constraint if exists listings_price_min;
alter table listings add constraint listings_price_min check (price >= 500 and price <= 100000000);
alter table listings drop constraint if exists listings_desc_len;
alter table listings add constraint listings_desc_len check (description is null or char_length(description) <= 2000);
alter table listings drop constraint if exists listings_images_max;
alter table listings add constraint listings_images_max check (cardinality(images) <= 8);
-- le titre sert de clé de commande dans le panier : unique (insensible à la casse) hors annonces supprimées
create unique index if not exists listings_titre_unique on listings (lower(title)) where status <> 'removed';

alter table orders add column if not exists cancelled_at timestamptz;

-- 2. Historique des modifications et mouvements de stock ------------------------------------------------------------
create table if not exists listing_history (
  id bigint generated always as identity primary key,
  listing_id uuid not null references listings(id) on delete cascade,
  actor uuid,
  action text not null,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);
create table if not exists stock_movements (
  id bigint generated always as identity primary key,
  listing_id uuid not null references listings(id) on delete cascade,
  delta integer not null,
  stock_after integer not null,
  reason text not null,
  order_number text,
  actor uuid,
  created_at timestamptz not null default now()
);
alter table listing_history enable row level security;
alter table stock_movements enable row level security;
revoke all on listing_history, stock_movements from anon, authenticated;
grant select on listing_history, stock_movements to authenticated;
drop policy if exists "historique lisible par le vendeur et le departement" on listing_history;
create policy "historique lisible par le vendeur et le departement" on listing_history for select
  using (exists (select 1 from listings l where l.id = listing_id and l.seller_id = auth.uid()) or current_role_name() in ('dept', 'admin'));
drop policy if exists "mouvements lisibles par le vendeur et le departement" on stock_movements;
create policy "mouvements lisibles par le vendeur et le departement" on stock_movements for select
  using (exists (select 1 from listings l where l.id = listing_id and l.seller_id = auth.uid()) or current_role_name() in ('dept', 'admin'));

create or replace function log_listing_history() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into listing_history (listing_id, actor, action, before, after)
  values (new.id, auth.uid(), tg_op, case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return null;
end $$;
drop trigger if exists trg_listing_history on listings;
create trigger trg_listing_history after insert or update on listings for each row execute function log_listing_history();

create or replace function log_stock_movement() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into stock_movements (listing_id, delta, stock_after, reason, actor) values (new.id, new.stock, new.stock, 'stock initial', auth.uid());
  elsif new.stock is distinct from old.stock then
    insert into stock_movements (listing_id, delta, stock_after, reason, order_number, actor)
    values (new.id, new.stock - old.stock, new.stock, coalesce(nullif(current_setting('app.stock_reason', true), ''), 'ajustement'), nullif(current_setting('app.order_number', true), ''), auth.uid());
  end if;
  return null;
end $$;
drop trigger if exists trg_stock_movement on listings;
create trigger trg_stock_movement after insert or update on listings for each row execute function log_stock_movement();

-- 3. Propriété et transitions de statut -------------------------------------------------------------------------------
create or replace function protect_listing_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null or coalesce(current_setting('app.internal', true), '') = '1' then return new; end if;  -- éditeur SQL / fonctions serveur
  if r in ('dept', 'admin') then
    if tg_op = 'UPDATE' and new.status is distinct from old.status then new.reviewed_by := auth.uid(); end if;
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
drop trigger if exists trg_protect_listing on listings;
create trigger trg_protect_listing before insert or update on listings for each row execute function protect_listing_status();

-- 4. Commande : décrément atomique du stock (jamais de vente au-delà du stock) ----------------------------------------
create or replace function create_order(p_items jsonb, p_home boolean, p_method text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  sub int := 0;
  v_fee int := case when p_home then 5000 else 0 end;
  num text;
  oid uuid;
  it jsonb;
  l listings%rowtype;
  q int;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  perform set_config('app.internal', '1', true);
  perform set_config('app.stock_reason', 'commande', true);
  perform set_config('app.order_number', num, true);
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid)
    values (num, uid, 0, v_fee, coalesce(nullif(p_method, ''), 'Mobile Money'), 0, false) returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    q := coalesce((it->>'qty')::int, 1);
    if q < 1 or q > 20 then raise exception 'Quantité invalide'; end if;
    -- réservation atomique : la ligne n'est modifiée que si le stock suffit (deux commandes simultanées ne peuvent pas dépasser le stock)
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
revoke all on function create_order(jsonb, boolean, text) from public, anon;
grant execute on function create_order(jsonb, boolean, text) to authenticated;

-- 5. Annulation : seul l'acheteur, seulement avant paiement ; le stock réservé est restitué ----------------------------
create or replace function cancel_order(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; ln record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if o.paid then raise exception 'Commande déjà payée : annulation impossible'; end if;
  if o.cancelled_at is not null then raise exception 'Commande déjà annulée'; end if;
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

-- 6. Images d'annonces : lecture publique, dépôt uniquement dans son dossier <uid>/… (5 Mo, jpeg/png/webp) -------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-images', 'listing-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "images annonces : lecture" on storage.objects;
create policy "images annonces : lecture" on storage.objects for select using (bucket_id = 'listing-images');
drop policy if exists "images annonces : depot dans son dossier" on storage.objects;
create policy "images annonces : depot dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "images annonces : modification dans son dossier" on storage.objects;
create policy "images annonces : modification dans son dossier" on storage.objects for update to authenticated
  using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "images annonces : suppression dans son dossier" on storage.objects;
create policy "images annonces : suppression dans son dossier" on storage.objects for delete to authenticated
  using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = auth.uid()::text);

select (select count(*) from pg_trigger where tgname in ('trg_listing_history', 'trg_stock_movement', 'trg_protect_listing')) as declencheurs,
       (select count(*) from storage.buckets where id = 'listing-images') as bucket_images;

-- Retour arrière (manuel, si nécessaire) :
--   drop trigger trg_listing_history on listings; drop trigger trg_stock_movement on listings;
--   drop function cancel_order(text); drop table stock_movements, listing_history;
--   puis recréer create_order et protect_listing_status depuis 20261029_p0_securite.sql / 20261029b_p1_securite.sql.
