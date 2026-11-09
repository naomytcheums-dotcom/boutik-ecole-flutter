-- Marketplace multi-boutiques (écrans 102 Vitrine, 248, 57-62 espace vendeur, 24 profil vendeur, 61 catalogue) : migration NON destructive.
-- Principe : on étend l'existant (profiles, listings, orders, order_lines, reviews, claims, notifications, messagerie, paiement), on n'en crée pas un second.
--   * une boutique (shops) appartient à un profil ; ses annonces (listings.shop_id) restent modérées comme avant ;
--   * une commande peut contenir des lignes de plusieurs boutiques : chaque ligne porte sa boutique, chaque vendeur ne voit et ne fait avancer que les siennes
--     (seller_orders / set_seller_order_status existants) ; my_order_split() présente à l'acheteur une commande séparée par boutique ;
--   * prix figé à la commande (order_lines.unit_price), stock décrémenté atomiquement, vente flash à stock réservé, clé d'idempotence par commande.
-- Retour arrière : voir la fin du fichier.

-- 1. Catégories gérées par l'administration ---------------------------------------------------------------------------------
create table if not exists marketplace_categories (
  slug text primary key check (slug ~ '^[a-z0-9-]{2,40}$'),
  label text not null check (char_length(label) between 2 and 40),
  position integer not null default 0,
  active boolean not null default true
);
insert into marketplace_categories (slug, label, position) values
  ('maison', 'Maison', 1), ('tech', 'Tech', 2), ('mode', 'Mode', 3), ('art', 'Art', 4), ('alimentation', 'Alimentation', 5), ('services', 'Services', 6)
on conflict (slug) do nothing;

-- 2. Boutiques --------------------------------------------------------------------------------------------------------------
create table if not exists shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references profiles(id) on delete cascade,
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{2,39}$'),
  name text not null check (char_length(name) between 3 and 60),
  description text check (description is null or char_length(description) <= 1000),
  logo_url text,
  banner_url text,
  categories text[] not null default '{}' check (cardinality(categories) <= 5),
  city text,
  delivery_info text check (delivery_info is null or char_length(delivery_info) <= 500),
  terms text check (terms is null or char_length(terms) <= 1500),
  socials jsonb not null default '{}'::jsonb check (jsonb_typeof(socials) = 'object'),
  color_primary text not null default '#111015' check (color_primary ~ '^#[0-9A-Fa-f]{6}$'),
  color_secondary text not null default '#5A3FE0' check (color_secondary ~ '^#[0-9A-Fa-f]{6}$'),
  status text not null default 'draft' check (status in ('draft', 'pending', 'active', 'suspended', 'closed')),
  review_note text,
  reviewed_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists shops_name_unique on shops (lower(name));
create index if not exists shops_status_idx on shops (status);

alter table listings add column if not exists shop_id uuid references shops(id) on delete set null;
alter table listings add column if not exists video_url text;
alter table listings add column if not exists price_before integer;
alter table listings add column if not exists variants jsonb not null default '[]'::jsonb;
alter table listings add column if not exists specs jsonb not null default '{}'::jsonb;
alter table listings drop constraint if exists listings_price_before_check;
alter table listings add constraint listings_price_before_check check (price_before is null or price_before > price);
alter table listings drop constraint if exists listings_variants_check;
alter table listings add constraint listings_variants_check check (jsonb_typeof(variants) = 'array' and jsonb_array_length(variants) <= 5);
alter table listings drop constraint if exists listings_specs_check;
alter table listings add constraint listings_specs_check check (jsonb_typeof(specs) = 'object');
create index if not exists listings_shop_idx on listings (shop_id) where shop_id is not null;

alter table order_lines add column if not exists shop_id uuid references shops(id) on delete set null;
alter table order_lines add column if not exists variant text;
alter table orders add column if not exists discount integer not null default 0 check (discount >= 0);
alter table orders add column if not exists promo_code text;
alter table orders add column if not exists idem_key text;
create unique index if not exists orders_idem_unique on orders (buyer_id, idem_key) where idem_key is not null;

-- Une annonce ne peut être rattachée qu'à la boutique de son vendeur ; une annonce créée par un vendeur qui a une boutique y est rattachée.
create or replace function listing_shop_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_shop uuid;
begin
  if new.shop_id is null and tg_op = 'INSERT' and new.seller_id is not null then
    select id into v_shop from shops where owner_id = new.seller_id and status <> 'closed';
    new.shop_id := v_shop;
  end if;
  if new.shop_id is not null and not exists (select 1 from shops where id = new.shop_id and owner_id = new.seller_id) then
    raise exception 'Cette boutique n''appartient pas au vendeur de l''annonce';
  end if;
  return new;
end $$;
drop trigger if exists trg_z_listing_shop on listings;
create trigger trg_z_listing_shop before insert or update of shop_id, seller_id on listings for each row execute function listing_shop_guard();

-- Statut de boutique : jamais modifiable directement (fonctions ci-dessous uniquement).
create or replace function shops_protect() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('app.internal', true), '') = '1' then new.updated_at := now(); return new; end if;
  if auth.uid() is not null then raise exception 'Utilisez les fonctions de la boutique'; end if;  -- éditeur SQL autorisé
  return new;
end $$;
drop trigger if exists trg_shops_protect on shops;
create trigger trg_shops_protect before insert or update on shops for each row execute function shops_protect();

-- 3. Suivi, avis, questions, alertes, signalements ----------------------------------------------------------------------------
create table if not exists shop_follows (
  user_id uuid not null references profiles(id) on delete cascade,
  shop_id uuid not null references shops(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, shop_id)
);
create table if not exists shop_reviews (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  reviewer_id uuid not null references profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 1000),
  created_at timestamptz not null default now(),
  unique (shop_id, reviewer_id)
);
create table if not exists product_questions (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  asker_id uuid not null references profiles(id) on delete cascade,
  question text not null check (char_length(question) between 5 and 500),
  answer text check (answer is null or char_length(answer) <= 1000),
  answered_by uuid references profiles(id) on delete set null,
  answered_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists product_questions_listing_idx on product_questions (listing_id, created_at desc);
create table if not exists price_alerts (
  user_id uuid not null references profiles(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  kind text not null check (kind in ('price', 'stock')),
  target_price integer check (target_price is null or target_price > 0),
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id, kind)
);
create table if not exists shop_reports (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (reason in ('fraud', 'counterfeit', 'abuse', 'other')),
  details text check (details is null or char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now(),
  unique (shop_id, reporter_id)
);
create table if not exists listing_views (
  listing_id uuid not null references listings(id) on delete cascade,
  day date not null default current_date,
  views integer not null default 0,
  primary key (listing_id, day)
);
create table if not exists shop_views (
  shop_id uuid not null references shops(id) on delete cascade,
  day date not null default current_date,
  views integer not null default 0,
  primary key (shop_id, day)
);

-- 4. Promotions : codes, ventes flash, campagnes, packs ------------------------------------------------------------------------
create table if not exists promo_codes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid references shops(id) on delete cascade,            -- nul : code de la plateforme (administration)
  code text not null check (code ~ '^[A-Z0-9]{3,20}$'),
  kind text not null check (kind in ('percent', 'fixed')),
  value integer not null check (value > 0),
  min_amount integer not null default 0 check (min_amount >= 0),
  max_uses integer check (max_uses is null or max_uses > 0),
  used_count integer not null default 0,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (kind <> 'percent' or value <= 90)
);
create unique index if not exists promo_codes_code_unique on promo_codes (code);
create table if not exists promo_redemptions (
  code_id uuid not null references promo_codes(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  order_id uuid not null unique references orders(id) on delete cascade,
  primary key (code_id, user_id)
);
create table if not exists flash_sales (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  shop_id uuid references shops(id) on delete cascade,
  sale_price integer not null check (sale_price >= 500),
  stock integer not null check (stock between 1 and 100000),      -- stock réservé à la vente flash
  sold integer not null default 0 check (sold >= 0 and sold <= stock),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  cancelled boolean not null default false,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at and ends_at <= starts_at + interval '7 days')
);
create index if not exists flash_sales_listing_idx on flash_sales (listing_id, ends_at);
create table if not exists shop_campaigns (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 80),
  description text check (description is null or char_length(description) <= 500),
  banner_url text,
  listing_ids uuid[] not null default '{}' check (cardinality(listing_ids) <= 12),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists shop_packs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 80),
  description text check (description is null or char_length(description) <= 500),
  price integer not null check (price >= 500),
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 2 and 6),   -- [{"listing": uuid, "qty": n}]
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table order_lines add column if not exists flash_id uuid references flash_sales(id) on delete set null;

-- 5. Accès : lecture contrôlée, aucune écriture directe -------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['marketplace_categories','shops','shop_follows','shop_reviews','product_questions','price_alerts','shop_reports','listing_views','shop_views','promo_codes','promo_redemptions','flash_sales','shop_campaigns','shop_packs'] loop
    execute format('alter table %I enable row level security', t);
    execute format('revoke all on %I from anon, authenticated', t);
  end loop;
end $$;
grant select on marketplace_categories, shop_reviews, product_questions to anon, authenticated;
grant select on shops, shop_campaigns, shop_packs, flash_sales to anon, authenticated;
grant select on shop_follows, price_alerts, shop_reports, listing_views, shop_views, promo_codes, promo_redemptions to authenticated;

drop policy if exists "categories : lecture" on marketplace_categories;
create policy "categories : lecture" on marketplace_categories for select using (true);
drop policy if exists "boutiques : actives, propriétaire, équipe" on shops;
create policy "boutiques : actives, propriétaire, équipe" on shops for select
  using (status = 'active' or owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'dept', 'support'));
drop policy if exists "avis boutiques : lecture" on shop_reviews;
create policy "avis boutiques : lecture" on shop_reviews for select using (true);
drop policy if exists "questions : lecture" on product_questions;
create policy "questions : lecture" on product_questions for select using (true);
drop policy if exists "suivis : les miens, le propriétaire de la boutique" on shop_follows;
create policy "suivis : les miens, le propriétaire de la boutique" on shop_follows for select
  using (user_id = auth.uid() or exists (select 1 from shops s where s.id = shop_id and s.owner_id = auth.uid()));
drop policy if exists "alertes : les miennes" on price_alerts;
create policy "alertes : les miennes" on price_alerts for select using (user_id = auth.uid());
drop policy if exists "signalements boutiques : auteur, équipe" on shop_reports;
create policy "signalements boutiques : auteur, équipe" on shop_reports for select
  using (reporter_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'dept', 'support'));
drop policy if exists "vues annonces : vendeur" on listing_views;
create policy "vues annonces : vendeur" on listing_views for select
  using (exists (select 1 from listings l where l.id = listing_id and l.seller_id = auth.uid()));
drop policy if exists "vues boutiques : propriétaire" on shop_views;
create policy "vues boutiques : propriétaire" on shop_views for select
  using (exists (select 1 from shops s where s.id = shop_id and s.owner_id = auth.uid()));
drop policy if exists "codes promo : boutique propriétaire, administration" on promo_codes;
create policy "codes promo : boutique propriétaire, administration" on promo_codes for select
  using (exists (select 1 from shops s where s.id = shop_id and s.owner_id = auth.uid()) or coalesce(current_role_name()::text, '') = 'admin');
drop policy if exists "utilisations de codes : les miennes" on promo_redemptions;
create policy "utilisations de codes : les miennes" on promo_redemptions for select using (user_id = auth.uid());
drop policy if exists "ventes flash : publiques tant qu'elles ne sont pas annulées" on flash_sales;
create policy "ventes flash : publiques tant qu'elles ne sont pas annulées" on flash_sales for select
  using (not cancelled or exists (select 1 from shops s where s.id = shop_id and s.owner_id = auth.uid()));
drop policy if exists "campagnes : actives ou propriétaire" on shop_campaigns;
create policy "campagnes : actives ou propriétaire" on shop_campaigns for select
  using ((active and exists (select 1 from shops s where s.id = shop_id and s.status = 'active')) or exists (select 1 from shops s where s.id = shop_id and s.owner_id = auth.uid()));
drop policy if exists "packs : actifs ou propriétaire" on shop_packs;
create policy "packs : actifs ou propriétaire" on shop_packs for select
  using ((active and exists (select 1 from shops s where s.id = shop_id and s.status = 'active')) or exists (select 1 from shops s where s.id = shop_id and s.owner_id = auth.uid()));

-- Les annonces d'une boutique suspendue, fermée ou non validée disparaissent de la vitrine publique (politique restrictive : s'ajoute aux règles existantes).
drop policy if exists "annonces : boutique active" on listings;
create policy "annonces : boutique active" on listings as restrictive for select
  using (shop_id is null or seller_id = auth.uid() or exists (select 1 from shops s where s.id = shop_id and s.status = 'active')
         or coalesce(current_role_name()::text, '') in ('admin', 'dept', 'support'));

-- Vidéo de produit : compartiment public, dépôt dans son dossier, mp4/webm, 30 Mo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-videos', 'listing-videos', true, 31457280, array['video/mp4', 'video/webm'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "videos annonces : lecture" on storage.objects;
create policy "videos annonces : lecture" on storage.objects for select using (bucket_id = 'listing-videos');
drop policy if exists "videos annonces : depot dans son dossier" on storage.objects;
create policy "videos annonces : depot dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'listing-videos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "videos annonces : suppression dans son dossier" on storage.objects;
create policy "videos annonces : suppression dans son dossier" on storage.objects for delete to authenticated
  using (bucket_id = 'listing-videos' and (storage.foldername(name))[1] = auth.uid()::text);

-- 6. Gestion de la boutique (propriétaire) ----------------------------------------------------------------------------------------
create or replace function _slugify(p text) returns text language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(translate(coalesce(p, ''), 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ', 'aaaeeeeiioouuucAAAEEEEIIOOUUUC')), '[^a-z0-9]+', '-', 'g'))
$$;

create or replace function shop_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); s shops%rowtype; v_slug text; v_cats text[]; v_exists boolean;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  select * into s from shops where owner_id = uid;
  v_exists := found;
  if v_exists and s.status in ('suspended', 'closed') then raise exception 'Boutique % : modification impossible', case s.status when 'suspended' then 'suspendue' else 'fermée' end; end if;
  if p ? 'categories' then
    select coalesce(array_agg(x), '{}') into v_cats from (select distinct jsonb_array_elements_text(p->'categories') x limit 5) q;
  end if;
  perform set_config('app.internal', '1', true);
  if not v_exists then
    v_slug := coalesce(nullif(_slugify(p->>'slug'), ''), _slugify(p->>'name'));
    if v_slug is null or v_slug !~ '^[a-z0-9][a-z0-9-]{2,39}$' then raise exception 'Adresse publique invalide (3 à 40 caractères : lettres, chiffres, tirets)'; end if;
    if exists (select 1 from shops where slug = v_slug) then raise exception 'Cette adresse publique est déjà prise'; end if;
    insert into shops (owner_id, slug, name, description, logo_url, banner_url, categories, city, delivery_info, terms, socials, color_primary, color_secondary)
    values (uid, v_slug, trim(p->>'name'), nullif(trim(p->>'description'), ''), nullif(p->>'logo_url', ''), nullif(p->>'banner_url', ''), coalesce(v_cats, '{}'),
            coalesce(nullif(trim(p->>'city'), ''), (select city from profiles where id = uid)), nullif(trim(p->>'delivery_info'), ''), nullif(trim(p->>'terms'), ''),
            coalesce(p->'socials', '{}'::jsonb), coalesce(nullif(p->>'color_primary', ''), '#111015'), coalesce(nullif(p->>'color_secondary', ''), '#5A3FE0'))
    returning * into s;
  else
    v_slug := s.slug;
    if s.status in ('draft') and p ? 'slug' and nullif(_slugify(p->>'slug'), '') is not null then
      v_slug := _slugify(p->>'slug');
      if v_slug !~ '^[a-z0-9][a-z0-9-]{2,39}$' then raise exception 'Adresse publique invalide (3 à 40 caractères : lettres, chiffres, tirets)'; end if;
      if exists (select 1 from shops where slug = v_slug and id <> s.id) then raise exception 'Cette adresse publique est déjà prise'; end if;
    end if;
    update shops set slug = v_slug,
      name = coalesce(nullif(trim(p->>'name'), ''), name),
      description = case when p ? 'description' then nullif(trim(p->>'description'), '') else description end,
      logo_url = case when p ? 'logo_url' then nullif(p->>'logo_url', '') else logo_url end,
      banner_url = case when p ? 'banner_url' then nullif(p->>'banner_url', '') else banner_url end,
      categories = case when p ? 'categories' then coalesce(v_cats, '{}') else categories end,
      city = case when p ? 'city' then nullif(trim(p->>'city'), '') else city end,
      delivery_info = case when p ? 'delivery_info' then nullif(trim(p->>'delivery_info'), '') else delivery_info end,
      terms = case when p ? 'terms' then nullif(trim(p->>'terms'), '') else terms end,
      socials = case when p ? 'socials' then coalesce(p->'socials', '{}'::jsonb) else socials end,
      color_primary = coalesce(nullif(p->>'color_primary', ''), color_primary),
      color_secondary = coalesce(nullif(p->>'color_secondary', ''), color_secondary)
    where id = s.id returning * into s;
  end if;
  perform set_config('app.internal', '', true);
  return to_jsonb(s);
end $$;

create or replace function shop_submit() returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where owner_id = auth.uid() for update;
  if not found then raise exception 'Créez d''abord votre boutique'; end if;
  if s.status not in ('draft', 'closed') then raise exception 'La boutique est déjà % ', case s.status when 'pending' then 'en cours de validation' when 'active' then 'active' else 'suspendue' end; end if;
  if s.description is null or s.logo_url is null or cardinality(s.categories) = 0 then raise exception 'Renseignez au moins le logo, la description et une catégorie avant de soumettre'; end if;
  perform set_config('app.internal', '1', true);
  update shops set status = 'pending', review_note = null where id = s.id;
  perform set_config('app.internal', '', true);
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Boutique soumise', s.slug, 'Marketplace', 'Normal');
  return 'pending';
end $$;

create or replace function shop_close() returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where owner_id = auth.uid() for update;
  if not found or s.status = 'suspended' then raise exception 'Fermeture impossible'; end if;
  perform set_config('app.internal', '1', true);
  update shops set status = 'closed' where id = s.id;
  perform set_config('app.internal', '', true);
  return 'closed';
end $$;

-- Décision de l'équipe : approve | reject | suspend | restore | close
create or replace function shop_decide(p_shop uuid, p_action text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; v_new text;
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') then raise exception 'Réservé à l''équipe de modération'; end if;
  select * into s from shops where id = p_shop for update;
  if not found then raise exception 'Boutique introuvable'; end if;
  v_new := case
    when p_action = 'approve' and s.status = 'pending' then 'active'
    when p_action = 'reject' and s.status = 'pending' then 'draft'
    when p_action = 'suspend' and s.status = 'active' then 'suspended'
    when p_action = 'restore' and s.status = 'suspended' then 'active'
    when p_action = 'close' and s.status <> 'closed' then 'closed'
    else null end;
  if v_new is null then raise exception 'Action % impossible pour une boutique %', p_action, s.status; end if;
  if p_action in ('reject', 'suspend') and char_length(trim(coalesce(p_note, ''))) < 3 then raise exception 'Motif obligatoire'; end if;
  perform set_config('app.internal', '1', true);
  update shops set status = v_new, review_note = nullif(trim(coalesce(p_note, '')), ''), reviewed_by = auth.uid() where id = s.id;
  perform set_config('app.internal', '', true);
  insert into notifications (user_id, kind, title, body, data)
  values (s.owner_id, 'shop', case v_new when 'active' then 'Boutique validée' when 'draft' then 'Boutique à corriger' when 'suspended' then 'Boutique suspendue' else 'Boutique fermée' end,
          s.name || coalesce(' : ' || nullif(trim(coalesce(p_note, '')), ''), ''), jsonb_build_object('shop', s.slug));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Boutique : ' || p_action, s.slug, 'Marketplace', 'Normal');
  return v_new;
end $$;

create or replace function my_shop() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select to_jsonb(s) from shops s where s.owner_id = auth.uid()), '{}'::jsonb)
$$;

-- 7. Lecture publique : recherche, boutiques, tendances, fiche, vitrine -----------------------------------------------------------
create or replace function _listing_card(l listings) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', l.id, 'title', l.title, 'price', l.price, 'price_before', l.price_before, 'category', l.category, 'stock', l.stock,
    'image', coalesce(l.images[1], l.image_url), 'created_at', l.created_at,
    'shop_id', l.shop_id, 'shop_name', s.name, 'shop_slug', s.slug, 'city', coalesce(s.city, sp.city),
    'flash_price', f.sale_price, 'flash_ends', f.ends_at, 'flash_left', f.stock - f.sold,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r where r.listing_id = l.id),
    'rating_count', (select count(*)::int from reviews r where r.listing_id = l.id),
    'sales', coalesce((select sum(ol.qty)::int from order_lines ol join orders o on o.id = ol.order_id where ol.listing_id = l.id and o.paid and o.cancelled_at is null), 0),
    'favs', (select count(*)::int from favorites fv where fv.listing_id = l.id))
  from (select 1) x
  left join shops s on s.id = l.shop_id
  left join profiles sp on sp.id = l.seller_id
  left join lateral (select * from flash_sales fs where fs.listing_id = l.id and not fs.cancelled and fs.starts_at <= now() and fs.ends_at > now() and fs.sold < fs.stock order by fs.sale_price limit 1) f on true
$$;
revoke all on function _listing_card(listings) from public, anon, authenticated;

create or replace function marketplace_search(p_q text default null, p_category text default null, p_city text default null, p_min integer default null, p_max integer default null,
  p_sort text default 'popular', p_shop uuid default null, p_limit integer default 24, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_q text := nullif(trim(coalesce(p_q, '')), ''); r jsonb;
begin
  select coalesce(jsonb_agg(c order by
      case p_sort when 'price_asc' then (c->>'price')::numeric end asc nulls last,
      case p_sort when 'price_desc' then (c->>'price')::numeric end desc nulls last,
      case p_sort when 'recent' then c->>'created_at' end desc nulls last,
      case p_sort when 'rating' then coalesce((c->>'rating_avg')::numeric, 0) end desc nulls last,
      ((c->>'sales')::int * 3 + (c->>'favs')::int) desc, c->>'created_at' desc), '[]'::jsonb)
  into r from (
    select _listing_card(l) c from listings l
    left join shops s on s.id = l.shop_id
    left join profiles sp on sp.id = l.seller_id
    where l.status = 'approved' and (l.shop_id is null or s.status = 'active')
      and (case when p_category is null or p_category = '' then l.category <> 'Services' else lower(l.category) = lower(p_category) end)
      and (v_q is null or l.title ilike '%' || v_q || '%' or coalesce(l.description, '') ilike '%' || v_q || '%' or coalesce(s.name, '') ilike '%' || v_q || '%')
      and (p_city is null or p_city = '' or lower(coalesce(s.city, sp.city, '')) = lower(p_city))
      and (p_min is null or l.price >= p_min) and (p_max is null or l.price <= p_max)
      and (p_shop is null or l.shop_id = p_shop)
    limit least(greatest(coalesce(p_limit, 24), 1), 100) offset greatest(coalesce(p_offset, 0), 0)
  ) q;
  return r;
end $$;

create or replace function marketplace_shops(p_q text default null, p_category text default null, p_city text default null, p_sort text default 'popular', p_limit integer default 24) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by
      case p_sort when 'recent' then x->>'created_at' end desc nulls last,
      case p_sort when 'rating' then coalesce((x->>'rating_avg')::numeric, 0) end desc nulls last,
      ((x->>'followers')::int * 2 + (x->>'products')::int) desc), '[]'::jsonb)
  from (
    select jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'logo_url', s.logo_url, 'banner_url', s.banner_url, 'city', s.city, 'categories', s.categories,
      'created_at', s.created_at, 'color_primary', s.color_primary,
      'followers', (select count(*)::int from shop_follows f where f.shop_id = s.id),
      'products', (select count(*)::int from listings l where l.shop_id = s.id and l.status = 'approved'),
      'rating_avg', (select round(avg(r.rating)::numeric, 1) from shop_reviews r where r.shop_id = s.id),
      'rating_count', (select count(*)::int from shop_reviews r where r.shop_id = s.id)) x
    from shops s
    where s.status = 'active'
      and (nullif(trim(coalesce(p_q, '')), '') is null or s.name ilike '%' || trim(p_q) || '%' or coalesce(s.description, '') ilike '%' || trim(p_q) || '%')
      and (p_category is null or p_category = '' or exists (select 1 from unnest(s.categories) c where lower(c) = lower(p_category)))
      and (p_city is null or p_city = '' or lower(coalesce(s.city, '')) = lower(p_city))
    limit least(greatest(coalesce(p_limit, 24), 1), 100)
  ) q
$$;

create or replace function trending_products(p_limit integer default 12) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(c order by sc desc), '[]'::jsonb) from (
    select _listing_card(l) c,
      coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id where ol.listing_id = l.id and o.paid and o.cancelled_at is null and o.created_at > now() - interval '14 days'), 0) * 5
      + coalesce((select sum(v.views) from listing_views v where v.listing_id = l.id and v.day > current_date - 7), 0)
      + (select count(*) from favorites fv where fv.listing_id = l.id) * 2 as sc
    from listings l left join shops s on s.id = l.shop_id
    where l.status = 'approved' and l.category <> 'Services' and l.stock > 0 and (l.shop_id is null or s.status = 'active')
    order by sc desc, l.created_at desc limit least(greatest(coalesce(p_limit, 12), 1), 50)
  ) q where sc > 0
$$;

create or replace function flash_sales_active() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'listing', _listing_card(l), 'sale_price', f.sale_price, 'stock', f.stock, 'sold', f.sold,
      'starts_at', f.starts_at, 'ends_at', f.ends_at, 'live', f.starts_at <= now()) order by f.starts_at), '[]'::jsonb)
  from flash_sales f join listings l on l.id = f.listing_id left join shops s on s.id = l.shop_id
  where not f.cancelled and f.ends_at > now() and f.starts_at < now() + interval '3 days' and f.sold < f.stock
    and l.status = 'approved' and (l.shop_id is null or s.status = 'active')
$$;

create or replace function shop_public(p_slug text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s shops%rowtype; uid uuid := auth.uid();
begin
  select * into s from shops where slug = lower(trim(p_slug));
  if not found or (s.status <> 'active' and s.owner_id is distinct from uid and coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support')) then
    return jsonb_build_object('found', false);
  end if;
  return jsonb_build_object('found', true,
    'shop', jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'description', s.description, 'logo_url', s.logo_url, 'banner_url', s.banner_url,
      'categories', s.categories, 'city', s.city, 'delivery_info', s.delivery_info, 'terms', s.terms, 'socials', s.socials,
      'color_primary', s.color_primary, 'color_secondary', s.color_secondary, 'status', s.status, 'created_at', s.created_at, 'owner_id', s.owner_id),
    'followers', (select count(*)::int from shop_follows f where f.shop_id = s.id),
    'following', exists (select 1 from shop_follows f where f.shop_id = s.id and f.user_id = uid),
    'is_owner', s.owner_id = uid,
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from shop_reviews r where r.shop_id = s.id),
    'rating_count', (select count(*)::int from shop_reviews r where r.shop_id = s.id),
    'sales', (select coalesce(sum(ol.qty), 0)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = s.owner_id and o.paid and o.cancelled_at is null),
    'products', (select coalesce(jsonb_agg(_listing_card(l) order by l.created_at desc), '[]'::jsonb) from (select * from listings where shop_id = s.id and status = 'approved' order by created_at desc limit 60) l),
    'flash', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'listing', _listing_card(l), 'sale_price', f.sale_price, 'ends_at', f.ends_at, 'left', f.stock - f.sold)), '[]'::jsonb)
              from flash_sales f join listings l on l.id = f.listing_id where f.shop_id = s.id and not f.cancelled and f.starts_at <= now() and f.ends_at > now() and f.sold < f.stock and l.status = 'approved'),
    'campaigns', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'description', c.description, 'banner_url', c.banner_url, 'ends_at', c.ends_at,
                    'products', (select coalesce(jsonb_agg(_listing_card(l)), '[]'::jsonb) from listings l where l.id = any (c.listing_ids) and l.status = 'approved'))), '[]'::jsonb)
                  from shop_campaigns c where c.shop_id = s.id and c.active and c.starts_at <= now() and (c.ends_at is null or c.ends_at > now())),
    'packs', (select coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'description', k.description, 'price', k.price, 'items', k.items,
                    'normal_price', (select coalesce(sum(l.price * (i->>'qty')::int), 0) from jsonb_array_elements(k.items) i join listings l on l.id = (i->>'listing')::uuid))), '[]'::jsonb)
              from shop_packs k where k.shop_id = s.id and k.active),
    'reviews', (select coalesce(jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.reviewer_id), 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
                from (select * from shop_reviews where shop_id = s.id order by created_at desc limit 20) r));
end $$;

create or replace function product_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l listings%rowtype; uid uuid := auth.uid();
begin
  select * into l from listings where id = p_id;
  if not found or (l.status <> 'approved' and l.seller_id is distinct from uid) then return jsonb_build_object('found', false); end if;
  return jsonb_build_object('found', true, 'card', _listing_card(l),
    'description', l.description, 'images', to_jsonb(l.images), 'video_url', l.video_url, 'variants', l.variants, 'specs', l.specs, 'department', l.department,
    'seller_id', l.seller_id, 'is_owner', l.seller_id = uid,
    'favorite', exists (select 1 from favorites f where f.listing_id = l.id and f.user_id = uid),
    'alerts', coalesce((select jsonb_agg(a.kind) from price_alerts a where a.listing_id = l.id and a.user_id = uid), '[]'::jsonb),
    'questions', (select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'question', q.question, 'answer', q.answer, 'author', display_name(q.asker_id), 'created_at', q.created_at) order by q.created_at desc), '[]'::jsonb)
                  from (select * from product_questions where listing_id = l.id order by created_at desc limit 30) q),
    'reviews', (select coalesce(jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.reviewer_id), 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
                from (select * from reviews where listing_id = l.id order by created_at desc limit 20) r));
end $$;

create or replace function record_view(p_kind text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_kind = 'listing' and exists (select 1 from listings where id = p_id and status = 'approved' and seller_id is distinct from auth.uid()) then
    insert into listing_views (listing_id, day, views) values (p_id, current_date, 1) on conflict (listing_id, day) do update set views = listing_views.views + 1;
  elsif p_kind = 'shop' and exists (select 1 from shops where id = p_id and status = 'active' and owner_id is distinct from auth.uid()) then
    insert into shop_views (shop_id, day, views) values (p_id, current_date, 1) on conflict (shop_id, day) do update set views = shop_views.views + 1;
  end if;
end $$;

-- 8. Interactions acheteur ----------------------------------------------------------------------------------------------------
create or replace function toggle_follow_shop(p_shop uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; v_now boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where id = p_shop and status = 'active';
  if not found then raise exception 'Boutique introuvable'; end if;
  if s.owner_id = auth.uid() then raise exception 'Vous ne pouvez pas suivre votre propre boutique'; end if;
  if exists (select 1 from shop_follows where user_id = auth.uid() and shop_id = p_shop) then
    delete from shop_follows where user_id = auth.uid() and shop_id = p_shop; v_now := false;
  else
    insert into shop_follows (user_id, shop_id) values (auth.uid(), p_shop); v_now := true;
    perform notify_user(s.owner_id, 'shop', 'Nouvel abonné', display_name(auth.uid()) || ' suit votre boutique ' || s.name || '.', jsonb_build_object('shop', s.slug));
  end if;
  return v_now;
end $$;

create or replace function my_followed_shops() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'logo_url', s.logo_url, 'city', s.city) order by f.created_at desc), '[]'::jsonb)
  from shop_follows f join shops s on s.id = f.shop_id where f.user_id = auth.uid() and s.status = 'active'
$$;

create or replace function submit_shop_review(p_shop uuid, p_rating integer, p_comment text default null) returns void
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_rating not between 1 and 5 then raise exception 'Note de 1 à 5'; end if;
  select * into s from shops where id = p_shop and status = 'active';
  if not found then raise exception 'Boutique introuvable'; end if;
  if not exists (select 1 from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                 where o.buyer_id = auth.uid() and o.paid and o.cancelled_at is null and l.seller_id = s.owner_id) then
    raise exception 'Seuls les clients ayant acheté dans cette boutique peuvent la noter';
  end if;
  insert into shop_reviews (shop_id, reviewer_id, rating, comment) values (p_shop, auth.uid(), p_rating, nullif(trim(coalesce(p_comment, '')), ''))
  on conflict (shop_id, reviewer_id) do update set rating = excluded.rating, comment = excluded.comment, created_at = now();
end $$;

create or replace function ask_question(p_listing uuid, p_question text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(trim(coalesce(p_question, ''))) < 5 then raise exception 'Question trop courte'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found then raise exception 'Produit introuvable'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas poser une question sur votre propre produit'; end if;
  if (select count(*) from product_questions where asker_id = auth.uid() and created_at > now() - interval '1 hour') >= 10 then raise exception 'Trop de questions : réessayez plus tard'; end if;
  insert into product_questions (listing_id, asker_id, question) values (p_listing, auth.uid(), trim(p_question)) returning id into v_id;
  perform notify_user(l.seller_id, 'question', 'Nouvelle question', l.title || ' : ' || left(trim(p_question), 120), jsonb_build_object('listing', l.id));
  return v_id;
end $$;

create or replace function answer_question(p_id uuid, p_answer text) returns void
language plpgsql security definer set search_path = public as $$
declare q product_questions%rowtype; l listings%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(trim(coalesce(p_answer, ''))) < 2 then raise exception 'Réponse vide'; end if;
  select * into q from product_questions where id = p_id;
  if not found then raise exception 'Question introuvable'; end if;
  select * into l from listings where id = q.listing_id;
  if l.seller_id is distinct from auth.uid() then raise exception 'Seul le vendeur peut répondre'; end if;
  update product_questions set answer = trim(p_answer), answered_by = auth.uid(), answered_at = now() where id = p_id;
  perform notify_user(q.asker_id, 'question', 'Réponse du vendeur', l.title || ' : ' || left(trim(p_answer), 120), jsonb_build_object('listing', l.id));
end $$;

create or replace function set_price_alert(p_listing uuid, p_kind text, p_target integer default null, p_on boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('price', 'stock') then raise exception 'Type d''alerte inconnu'; end if;
  if not exists (select 1 from listings where id = p_listing and status = 'approved') then raise exception 'Produit introuvable'; end if;
  if not coalesce(p_on, true) then
    delete from price_alerts where user_id = auth.uid() and listing_id = p_listing and kind = p_kind;
  else
    insert into price_alerts (user_id, listing_id, kind, target_price) values (auth.uid(), p_listing, p_kind, case when p_kind = 'price' then p_target end)
    on conflict (user_id, listing_id, kind) do update set target_price = excluded.target_price;
  end if;
end $$;

-- Alertes : baisse de prix (sous la cible, ou toute baisse sans cible) et retour en stock ; chaque alerte ne se déclenche qu'une fois.
create or replace function fire_price_alerts() returns trigger
language plpgsql security definer set search_path = public as $$
declare a record;
begin
  if new.status <> 'approved' then return null; end if;
  if new.price < old.price then
    for a in select * from price_alerts where listing_id = new.id and kind = 'price' and (target_price is null or new.price <= target_price) loop
      insert into notifications (user_id, kind, title, body, data)
      values (a.user_id, 'alert', 'Baisse de prix', new.title || ' passe à ' || new.price || ' FCFA.', jsonb_build_object('listing', new.id));
      delete from price_alerts where user_id = a.user_id and listing_id = a.listing_id and kind = 'price';
    end loop;
  end if;
  if old.stock = 0 and new.stock > 0 then
    for a in select * from price_alerts where listing_id = new.id and kind = 'stock' loop
      insert into notifications (user_id, kind, title, body, data)
      values (a.user_id, 'alert', 'De retour en stock', new.title || ' est de nouveau disponible.', jsonb_build_object('listing', new.id));
      delete from price_alerts where user_id = a.user_id and listing_id = a.listing_id and kind = 'stock';
    end loop;
  end if;
  return null;
end $$;
drop trigger if exists trg_fire_price_alerts on listings;
create trigger trg_fire_price_alerts after update of price, stock on listings for each row execute function fire_price_alerts();

create or replace function report_shop(p_shop uuid, p_reason text, p_details text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from shops where id = p_shop and status = 'active' and owner_id <> auth.uid()) then raise exception 'Boutique introuvable'; end if;
  insert into shop_reports (shop_id, reporter_id, reason, details) values (p_shop, auth.uid(), p_reason, nullif(trim(coalesce(p_details, '')), ''))
  on conflict (shop_id, reporter_id) do nothing;
end $$;

-- 9. Promotions côté vendeur --------------------------------------------------------------------------------------------------------
create or replace function _my_shop_id(p_active boolean default true) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select id into v from shops where owner_id = auth.uid() and (not p_active or status = 'active');
  if v is null then raise exception 'Votre boutique doit être active (validée) pour cette action'; end if;
  return v;
end $$;

create or replace function promo_save(p_code text, p_kind text, p_value integer, p_min integer default 0, p_max_uses integer default null, p_ends timestamptz default null, p_active boolean default true, p_platform boolean default false) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); v_id uuid;
begin
  if coalesce(p_platform, false) then
    if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  else
    v_shop := _my_shop_id(true);
  end if;
  if v_code !~ '^[A-Z0-9]{3,20}$' then raise exception 'Code de 3 à 20 lettres ou chiffres'; end if;
  insert into promo_codes (shop_id, code, kind, value, min_amount, max_uses, ends_at, active) values (v_shop, v_code, p_kind, p_value, coalesce(p_min, 0), p_max_uses, p_ends, coalesce(p_active, true))
  on conflict (code) do update set kind = excluded.kind, value = excluded.value, min_amount = excluded.min_amount, max_uses = excluded.max_uses, ends_at = excluded.ends_at, active = excluded.active
    where promo_codes.shop_id is not distinct from v_shop
  returning id into v_id;
  if v_id is null then raise exception 'Ce code existe déjà'; end if;
  return v_id;
end $$;

create or replace function flash_save(p_listing uuid, p_price integer, p_stock integer, p_starts timestamptz, p_ends timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _my_shop_id(true); l listings%rowtype; v_id uuid; v_reserved integer;
begin
  select * into l from listings where id = p_listing and seller_id = auth.uid() and shop_id = v_shop and status = 'approved' for update;
  if not found then raise exception 'Produit introuvable dans votre boutique'; end if;
  if p_price is null or p_price >= l.price then raise exception 'Le prix flash doit être inférieur au prix actuel (% FCFA)', l.price; end if;
  if p_ends <= now() then raise exception 'La vente doit se terminer dans le futur'; end if;
  select coalesce(sum(stock - sold), 0) into v_reserved from flash_sales where listing_id = l.id and not cancelled and ends_at > now();
  if p_stock is null or p_stock < 1 or p_stock + v_reserved > l.stock then raise exception 'Stock flash invalide : %  disponible(s) à réserver', l.stock - v_reserved; end if;
  insert into flash_sales (listing_id, shop_id, sale_price, stock, starts_at, ends_at) values (l.id, v_shop, p_price, p_stock, p_starts, p_ends) returning id into v_id;
  return v_id;
end $$;

create or replace function flash_cancel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update flash_sales set cancelled = true where id = p_id and shop_id = (select id from shops where owner_id = auth.uid());
  if not found then raise exception 'Vente flash introuvable'; end if;
end $$;

create or replace function campaign_save(p_title text, p_description text, p_banner text, p_listings uuid[], p_starts timestamptz, p_ends timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _my_shop_id(true); v_id uuid;
begin
  if exists (select 1 from unnest(coalesce(p_listings, '{}')) x where not exists (select 1 from listings l where l.id = x and l.shop_id = v_shop)) then raise exception 'Produit hors de votre boutique'; end if;
  insert into shop_campaigns (shop_id, title, description, banner_url, listing_ids, starts_at, ends_at) values (v_shop, trim(p_title), nullif(trim(coalesce(p_description, '')), ''), nullif(p_banner, ''), coalesce(p_listings, '{}'), coalesce(p_starts, now()), p_ends)
  returning id into v_id;
  return v_id;
end $$;

create or replace function pack_save(p_title text, p_description text, p_price integer, p_items jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := _my_shop_id(true); v_id uuid; v_normal integer;
begin
  if jsonb_typeof(p_items) <> 'array' then raise exception 'Composition invalide'; end if;
  if exists (select 1 from jsonb_array_elements(p_items) i where not exists (select 1 from listings l where l.id = (i->>'listing')::uuid and l.shop_id = v_shop and l.status = 'approved') or coalesce((i->>'qty')::int, 0) not between 1 and 10) then
    raise exception 'Chaque composant doit être un produit approuvé de votre boutique (quantité de 1 à 10)';
  end if;
  select sum(l.price * (i->>'qty')::int) into v_normal from jsonb_array_elements(p_items) i join listings l on l.id = (i->>'listing')::uuid;
  if p_price >= v_normal then raise exception 'Le prix du pack doit être inférieur à la somme des produits (% FCFA)', v_normal; end if;
  insert into shop_packs (shop_id, title, description, price, items) values (v_shop, trim(p_title), nullif(trim(coalesce(p_description, '')), ''), p_price, p_items) returning id into v_id;
  return v_id;
end $$;

create or replace function my_promotions() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'codes', coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at desc) from promo_codes c where c.shop_id = (select id from shops where owner_id = auth.uid())), '[]'::jsonb),
    'flash', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'title', l.title, 'sale_price', f.sale_price, 'stock', f.stock, 'sold', f.sold, 'starts_at', f.starts_at, 'ends_at', f.ends_at, 'cancelled', f.cancelled) order by f.starts_at desc)
                       from flash_sales f join listings l on l.id = f.listing_id where f.shop_id = (select id from shops where owner_id = auth.uid())), '[]'::jsonb),
    'campaigns', coalesce((select jsonb_agg(to_jsonb(k) order by k.created_at desc) from shop_campaigns k where k.shop_id = (select id from shops where owner_id = auth.uid())), '[]'::jsonb),
    'packs', coalesce((select jsonb_agg(to_jsonb(k) order by k.created_at desc) from shop_packs k where k.shop_id = (select id from shops where owner_id = auth.uid())), '[]'::jsonb))
$$;

-- 10. Commande multi-boutiques : stock sans survente, prix figé, flash, code promo, idempotence ------------------------------------------------
create or replace function marketplace_checkout(p_items jsonb, p_home boolean, p_method text, p_address uuid default null, p_code text default null, p_key text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  o orders%rowtype; st institution_settings%rowtype; adr addresses%rowtype;
  v_fee int := 0; num text; oid uuid; it jsonb; l listings%rowtype; fs flash_sales%rowtype; pk shop_packs%rowtype; pc promo_codes%rowtype; comp jsonb;
  q int; sub int := 0; v_price int; v_reserved int; v_base int; v_disc int := 0; v_normal int; v_unit int; v_cq int; v_share int; v_flash uuid;
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
    if lower(trim(adr.city)) <> lower(trim(st.home_delivery_city)) then raise exception 'Livraison à domicile proposée seulement à %', st.home_delivery_city; end if;
    v_fee := st.home_delivery_fee;
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
  if nullif(trim(coalesce(p_code, '')), '') is not null then
    select * into pc from promo_codes where code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g')) for update;
    if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
      raise exception 'Code promo invalide ou expiré';
    end if;
    if exists (select 1 from promo_redemptions where code_id = pc.id and user_id = uid) then raise exception 'Code promo déjà utilisé'; end if;
    select coalesce(sum(unit_price * qty), 0) into v_base from order_lines where order_id = oid and flash_id is null and (pc.shop_id is null or shop_id = pc.shop_id);
    if v_base = 0 or v_base < pc.min_amount then raise exception 'Ce code ne s''applique pas à votre panier (montant minimum % FCFA sur la boutique concernée)', pc.min_amount; end if;
    v_disc := case pc.kind when 'percent' then (v_base::bigint * pc.value / 100)::int else least(pc.value, v_base) end;
    v_disc := least(v_disc, greatest(sub - 500, 0));
    update promo_codes set used_count = used_count + 1 where id = pc.id;
    insert into promo_redemptions (code_id, user_id, order_id) values (pc.id, uid, oid);
  end if;
  update orders set subtotal = sub - v_disc, discount = v_disc, promo_code = pc.code where id = oid;
  perform set_config('app.internal', '', true);
  perform set_config('app.stock_reason', '', true);
  perform set_config('app.order_number', '', true);
  return jsonb_build_object('number', num, 'subtotal', sub - v_disc, 'fee', v_fee, 'discount', v_disc, 'replayed', false);
end $$;

-- Annulation d'une commande non payée : le stock revient déjà (cancel_order) ; on rend aussi les unités de vente flash et l'utilisation du code promo.
create or replace function release_order_promos() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.cancelled_at is not null and old.cancelled_at is null then
    update flash_sales f set sold = greatest(f.sold - x.n, 0) from (select flash_id, sum(qty)::int n from order_lines where order_id = new.id and flash_id is not null group by flash_id) x where f.id = x.flash_id;
    update promo_codes c set used_count = greatest(c.used_count - 1, 0) from promo_redemptions r where r.order_id = new.id and r.code_id = c.id;
    delete from promo_redemptions where order_id = new.id;
  end if;
  return null;
end $$;
drop trigger if exists trg_release_order_promos on orders;
create trigger trg_release_order_promos after update of cancelled_at on orders for each row execute function release_order_promos();

create or replace function promo_preview(p_code text, p_items jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pc promo_codes%rowtype; it jsonb; l listings%rowtype; v_base int := 0; v_disc int; v_sub int := 0; q int;
begin
  select * into pc from promo_codes where code = upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if not found or not pc.active or pc.starts_at > now() or (pc.ends_at is not null and pc.ends_at <= now()) or (pc.max_uses is not null and pc.used_count >= pc.max_uses) then
    return jsonb_build_object('valid', false, 'message', 'Code promo invalide ou expiré');
  end if;
  if auth.uid() is not null and exists (select 1 from promo_redemptions where code_id = pc.id and user_id = auth.uid()) then return jsonb_build_object('valid', false, 'message', 'Code promo déjà utilisé'); end if;
  for it in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    q := least(greatest(coalesce((it->>'qty')::int, 1), 1), 20);
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

-- Commande séparée par boutique, vue de l'acheteur (une ligne par boutique : articles, sous-total, état de préparation).
create or replace function my_order_split(p_number text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(g order by g->>'shop_name'), '[]'::jsonb) from (
    select jsonb_build_object('shop_id', ol.shop_id, 'shop_name', coalesce(s.name, display_name(l.seller_id), 'Boutique du campus'), 'shop_slug', s.slug,
      'subtotal', sum(ol.unit_price * ol.qty)::int, 'status', min(ol.fulfillment)::int,
      'items', jsonb_agg(jsonb_build_object('title', ol.title, 'qty', ol.qty, 'unit_price', ol.unit_price, 'variant', ol.variant, 'flash', ol.flash_id is not null))) g
    from orders o join order_lines ol on ol.order_id = o.id left join listings l on l.id = ol.listing_id left join shops s on s.id = ol.shop_id
    where o.number = p_number and o.buyer_id = auth.uid()
    group by ol.shop_id, s.name, s.slug, l.seller_id
  ) q
$$;

-- 11. Tableau de bord vendeur ---------------------------------------------------------------------------------------------------------
create or replace function shop_dashboard(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_days int := least(greatest(coalesce(p_days, 30), 1), 365); v_shop uuid; v_rev int; v_orders int; v_views int; v_start date;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select id into v_shop from shops where owner_id = uid;
  v_start := current_date - (v_days - 1);
  select coalesce(sum(ol.unit_price * ol.qty), 0)::int, count(distinct o.id)::int into v_rev, v_orders
    from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
    where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at >= v_start;
  select coalesce(sum(v.views), 0)::int into v_views from listing_views v join listings l on l.id = v.listing_id where l.seller_id = uid and v.day >= v_start;
  return jsonb_build_object('days', v_days, 'shop_id', v_shop, 'revenue', v_rev, 'orders', v_orders, 'views', v_views,
    'shop_views', coalesce((select sum(views) from shop_views where shop_id = v_shop and day >= v_start), 0),
    'followers', (select count(*)::int from shop_follows where shop_id = v_shop),
    'conversion', case when v_views > 0 then round(v_orders * 100.0 / v_views, 1) else null end,
    'pending_orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                        where l.seller_id = uid and o.paid and o.cancelled_at is null and ol.fulfillment < 4),
    'top', (select coalesce(jsonb_agg(t order by (t->>'revenue')::int desc), '[]'::jsonb) from (
              select jsonb_build_object('title', ol.title, 'qty', sum(ol.qty)::int, 'revenue', sum(ol.unit_price * ol.qty)::int) t
              from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at >= v_start group by ol.title order by sum(ol.unit_price * ol.qty) desc limit 5) x),
    'series', (select jsonb_agg(jsonb_build_object('day', d::date,
                 'revenue', coalesce((select sum(ol.unit_price * ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                                       where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at::date = d::date), 0)::int,
                 'views', coalesce((select sum(v.views) from listing_views v join listings l on l.id = v.listing_id where l.seller_id = uid and v.day = d::date), 0)::int) order by d)
               from generate_series(v_start, current_date, interval '1 day') d));
end $$;

-- 12. Modération et administration ----------------------------------------------------------------------------------------------------
create or replace function marketplace_moderation() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') then raise exception 'Réservé à l''équipe de modération'; end if;
  return jsonb_build_object(
    'pending_shops', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'description', s.description, 'owner', display_name(s.owner_id), 'created_at', s.created_at) order by s.updated_at), '[]'::jsonb) from shops s where s.status = 'pending'),
    'active_shops', (select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'slug', s.slug, 'name', s.name, 'status', s.status) order by s.name), '[]'::jsonb) from shops s where s.status in ('active', 'suspended')),
    'shop_reports', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'shop', s.name, 'shop_id', s.id, 'reason', r.reason, 'details', r.details, 'status', r.status, 'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
                      from shop_reports r join shops s on s.id = r.shop_id where r.status <> 'closed'),
    'disputes', (select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'reason', c.reason, 'details', c.details, 'status', c.status, 'answer', c.answer, 'created_at', c.created_at) order by c.created_at desc), '[]'::jsonb)
                  from claims c where c.status <> 'closed'),
    'categories', (select coalesce(jsonb_agg(to_jsonb(k) order by k.position), '[]'::jsonb) from marketplace_categories k));
end $$;

create or replace function shop_report_set_status(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') then raise exception 'Réservé à l''équipe de modération'; end if;
  if p_status not in ('reviewing', 'closed') then raise exception 'Statut invalide'; end if;
  update shop_reports set status = p_status where id = p_id;
end $$;

create or replace function dispute_close(p_id uuid, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à l''équipe de médiation'; end if;
  update claims set status = 'closed', answer = coalesce(nullif(trim(coalesce(p_note, '')), ''), answer) where id = p_id;
  if not found then raise exception 'Litige introuvable'; end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Litige clos', p_id::text, 'Marketplace', 'Normal');
end $$;

create or replace function category_save(p_slug text, p_label text, p_position integer default 0, p_active boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administration'; end if;
  insert into marketplace_categories (slug, label, position, active) values (lower(trim(p_slug)), trim(p_label), coalesce(p_position, 0), coalesce(p_active, true))
  on conflict (slug) do update set label = excluded.label, position = excluded.position, active = excluded.active;
end $$;

-- 12 bis. Profil public du vendeur (écran 24) : ajoute le lien vers sa boutique active (champs ajoutés, aucun retiré).
create or replace function seller_public(p_name text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_p profiles%rowtype;
begin
  select * into v_p from profiles where lower(name) = lower(trim(p_name)) order by created_at limit 1;
  if not found then return jsonb_build_object('found', false); end if;
  v_id := v_p.id;
  return jsonb_build_object(
    'found', true,
    'name', v_p.name,
    'department', coalesce(v_p.department, ''),
    'institution', coalesce(v_p.institution, ''),
    'verified', v_p.certification::text = 'approved',
    'since', v_p.created_at,
    'shop_slug', (select s.slug from shops s where s.owner_id = v_id and s.status = 'active'),
    'shop_name', (select s.name from shops s where s.owner_id = v_id and s.status = 'active'),
    'products', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category <> 'Services'),
    'services', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category = 'Services'),
    'sales', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = v_id and o.paid and o.cancelled_at is null),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'stars', (select coalesce(jsonb_object_agg(s::text, c), '{}'::jsonb) from (select r.rating s, count(*)::int c from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id group by 1) x)
  );
end $$;

-- 13. Droits d'exécution ----------------------------------------------------------------------------------------------------------------
revoke all on function _slugify(text), shop_save(jsonb), shop_submit(), shop_close(), shop_decide(uuid, text, text), my_shop(), marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer),
  marketplace_shops(text, text, text, text, integer), trending_products(integer), flash_sales_active(), shop_public(text), product_detail(uuid), record_view(text, uuid),
  toggle_follow_shop(uuid), my_followed_shops(), submit_shop_review(uuid, integer, text), ask_question(uuid, text), answer_question(uuid, text), set_price_alert(uuid, text, integer, boolean),
  report_shop(uuid, text, text), _my_shop_id(boolean), promo_save(text, text, integer, integer, integer, timestamptz, boolean, boolean), flash_save(uuid, integer, integer, timestamptz, timestamptz),
  flash_cancel(uuid), campaign_save(text, text, text, uuid[], timestamptz, timestamptz), pack_save(text, text, integer, jsonb), my_promotions(),
  marketplace_checkout(jsonb, boolean, text, uuid, text, text), promo_preview(text, jsonb), my_order_split(text), shop_dashboard(integer), marketplace_moderation(),
  shop_report_set_status(uuid, text), dispute_close(uuid, text), category_save(text, text, integer, boolean) from public, anon, authenticated;
grant execute on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer), marketplace_shops(text, text, text, text, integer), trending_products(integer),
  flash_sales_active(), shop_public(text), product_detail(uuid), record_view(text, uuid), promo_preview(text, jsonb) to anon, authenticated;
grant execute on function shop_save(jsonb), shop_submit(), shop_close(), shop_decide(uuid, text, text), my_shop(), toggle_follow_shop(uuid), my_followed_shops(), submit_shop_review(uuid, integer, text),
  ask_question(uuid, text), answer_question(uuid, text), set_price_alert(uuid, text, integer, boolean), report_shop(uuid, text, text),
  promo_save(text, text, integer, integer, integer, timestamptz, boolean, boolean), flash_save(uuid, integer, integer, timestamptz, timestamptz), flash_cancel(uuid),
  campaign_save(text, text, text, uuid[], timestamptz, timestamptz), pack_save(text, text, integer, jsonb), my_promotions(), marketplace_checkout(jsonb, boolean, text, uuid, text, text),
  my_order_split(text), shop_dashboard(integer), marketplace_moderation(), shop_report_set_status(uuid, text), dispute_close(uuid, text), category_save(text, text, integer, boolean) to authenticated;
-- Les fonctions internes (_my_shop_id, _slugify) sont appelées depuis des fonctions SECURITY DEFINER du même propriétaire.
revoke all on function listing_shop_guard(), shops_protect(), fire_price_alerts(), release_order_promos() from public, anon, authenticated;

-- Retour arrière (manuel) :
--   drop trigger trg_z_listing_shop on listings; drop trigger trg_fire_price_alerts on listings; drop trigger trg_release_order_promos on orders;
--   drop policy "annonces : boutique active" on listings;
--   drop function marketplace_checkout(jsonb, boolean, text, uuid, text, text), promo_preview(text, jsonb), my_order_split(text), shop_dashboard(integer), marketplace_moderation(), ... (fonctions ci-dessus);
--   drop table pack/campagnes/ventes flash/codes (shop_packs, shop_campaigns, flash_sales, promo_redemptions, promo_codes), listing_views, shop_views, shop_reports, price_alerts, product_questions, shop_reviews, shop_follows, shops, marketplace_categories cascade;
--   réappliquer seller_public(text) de 20261105000900_vendeur_public.sql ;
--   alter table listings drop column shop_id, video_url, price_before, variants, specs; alter table order_lines drop column shop_id, variant, flash_id; alter table orders drop column discount, promo_code, idem_key;
