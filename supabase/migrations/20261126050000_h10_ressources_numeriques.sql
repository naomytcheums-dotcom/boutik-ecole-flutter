-- Lot H10 COMMERCE (A-032, A-033, A-034, A-120, A-241, A-242) : ressources numériques livrables, sous droits d'accès.
--   Modèle : une annonce devient « ressource numérique » quand le vendeur lui rattache une fiche digital_listings (licence choisie parmi personnelle / commerciale / éducative,
--   LIBELLÉ saisi par le vendeur : la plateforme ne rédige aucun texte juridique ; limite de téléchargements par achat) et au moins un fichier (digital_assets, version) déposé
--   dans le compartiment PRIVÉ « digital-files » (dossier <vendeur>/<annonce>/…). Aucune lecture directe des fichiers par un tiers.
--   Droit de téléchargement (digital_entitlements) : créé UNIQUEMENT par trigger quand orders.paid passe à vrai (circuit existant : confirmation serveur du paiement ;
--   money_order_paid, montants, commissions, séquestre et règles ne sont pas touchés), jamais pour une commande annulée ; un droit par ligne de commande (rejeu sans effet).
--   Licence et limite sont COPIÉES dans le droit à l'achat : modifier l'annonce ensuite ne change pas ce que l'acheteur a obtenu.
--   digital_download_url(ligne, fichier) : vérifie (acheteur de la ligne, commande payée, non annulée, non remboursée, droit non révoqué, limite non atteinte), compte et journalise le
--   téléchargement, dépose un TICKET de 60 s et renvoie le chemin ; la lecture du compartiment n'est permise (politique de stockage) qu'au vendeur propriétaire du dossier ou à
--   l'acheteur porteur d'un ticket valable : le client crée alors l'URL signée courte. Révocation automatique : commande annulée, remboursement TOTAL accepté (le remboursement
--   partiel laisse l'accès ouvert : décision métier à confirmer).
--   Paiement à la livraison refusé pour une commande contenant une ressource numérique (rien à remettre en main propre).
--   Publication (pending/approved) refusée tant que la ressource n'a ni licence ni fichier actif ; capacité vendeur (seller_capable) exigée par les RPC et par la garde K2 des annonces.
-- Additive et rejouable. Retour arrière :
--   drop trigger trg_h10_digital_grant, trg_h10_digital_cancel, trg_h10_digital_cod on orders ; trg_h10_digital_refund on order_refunds ; trg_h10_digital_publish on listings ;
--   drop function digital_listing_save(uuid, text, text, integer), my_digital_listing(uuid), digital_asset_register(uuid, text, text, text, bigint, text, uuid), digital_asset_remove(uuid),
--     seller_digital_sales(), product_digital_info(uuid), my_downloads(), digital_download_url(uuid, uuid), _digital_grant_order(uuid), _digital_revoke_order(uuid, text),
--     _digital_order_state(uuid), _digital_mimes(), digital_storage_read_ok(text), digital_storage_write_ok(text), h10_digital_* ;
--   drop policy "ressources numériques : …" on storage.objects ; drop table digital_download_log, digital_download_tickets, digital_entitlements, digital_assets, digital_listings ;
--   supprimer le compartiment digital-files depuis le tableau de bord après vidage.

-- ============================================================ 1. compartiment privé
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('digital-files', 'digital-files', false, 52428800,
        array['application/pdf', 'application/zip', 'image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'audio/mpeg', 'text/plain', 'text/csv', 'model/gltf-binary',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'application/vnd.openxmlformats-officedocument.presentationml.presentation'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function _digital_mimes() returns text[]
language sql immutable as $$
  select array['application/pdf', 'application/zip', 'image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'audio/mpeg', 'text/plain', 'text/csv', 'model/gltf-binary',
               'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
               'application/vnd.openxmlformats-officedocument.presentationml.presentation']
$$;
revoke all on function _digital_mimes() from public, anon, authenticated;

-- ============================================================ 2. tables (aucun accès direct : tout passe par les fonctions)
create table if not exists digital_listings (
  listing_id uuid primary key references listings(id) on delete cascade,
  seller_id uuid not null references profiles(id) on delete cascade,
  license_kind text not null check (license_kind in ('personal', 'commercial', 'educational')),
  license_label text not null check (char_length(btrim(license_label)) between 3 and 500),
  max_downloads integer not null default 5 check (max_downloads between 1 and 50),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists digital_assets (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references digital_listings(listing_id) on delete cascade,
  seller_id uuid not null references profiles(id) on delete cascade,
  storage_path text not null unique check (char_length(storage_path) between 10 and 300),
  file_name text not null check (char_length(file_name) between 1 and 120),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 52428800),
  version text not null default '1.0' check (char_length(btrim(version)) between 1 and 30),
  active boolean not null default true,
  replaces uuid references digital_assets(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists digital_assets_listing_idx on digital_assets (listing_id) where active;

create table if not exists digital_entitlements (
  id uuid primary key default gen_random_uuid(),
  order_line_id uuid not null unique references order_lines(id) on delete cascade,
  order_id uuid not null references orders(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  buyer_id uuid not null references profiles(id) on delete cascade,
  seller_id uuid not null references profiles(id) on delete cascade,
  license_kind text not null,
  license_label text not null,
  max_downloads integer not null check (max_downloads between 1 and 50),
  downloads_used integer not null default 0 check (downloads_used >= 0),
  status text not null default 'active' check (status in ('active', 'revoked')),
  revoked_at timestamptz,
  revoked_reason text,
  granted_at timestamptz not null default now()
);
create index if not exists digital_entitlements_buyer_idx on digital_entitlements (buyer_id, granted_at desc);
create index if not exists digital_entitlements_seller_idx on digital_entitlements (seller_id, granted_at desc);
create index if not exists digital_entitlements_order_idx on digital_entitlements (order_id);

create table if not exists digital_download_log (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references digital_entitlements(id) on delete cascade,
  asset_id uuid references digital_assets(id) on delete set null,
  buyer_id uuid not null references profiles(id) on delete cascade,
  file_name text not null,
  downloaded_at timestamptz not null default now()
);
create index if not exists digital_download_log_ent_idx on digital_download_log (entitlement_id, downloaded_at desc);

create table if not exists digital_download_tickets (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null references digital_entitlements(id) on delete cascade,
  buyer_id uuid not null references profiles(id) on delete cascade,
  storage_path text not null,
  expires_at timestamptz not null
);
create index if not exists digital_download_tickets_idx on digital_download_tickets (buyer_id, storage_path, expires_at);

alter table digital_listings enable row level security;
alter table digital_assets enable row level security;
alter table digital_entitlements enable row level security;
alter table digital_download_log enable row level security;
alter table digital_download_tickets enable row level security;
revoke all on digital_listings, digital_assets, digital_entitlements, digital_download_log, digital_download_tickets from anon, authenticated;

-- ============================================================ 3. politiques de stockage
create or replace function digital_storage_write_ok(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (storage.foldername(p_name))[1] = auth.uid()::text and seller_capable(auth.uid())
$$;
revoke all on function digital_storage_write_ok(text) from public, anon;
grant execute on function digital_storage_write_ok(text) to authenticated;

create or replace function digital_storage_read_ok(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    (storage.foldername(p_name))[1] = auth.uid()::text
    or exists (select 1 from digital_download_tickets t where t.buyer_id = auth.uid() and t.storage_path = p_name and t.expires_at > now()))
$$;
revoke all on function digital_storage_read_ok(text) from public, anon;
grant execute on function digital_storage_read_ok(text) to authenticated;

create or replace function digital_storage_delete_ok(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (storage.foldername(p_name))[1] = auth.uid()::text
     and not exists (select 1 from digital_assets a where a.storage_path = p_name and a.active)
$$;
revoke all on function digital_storage_delete_ok(text) from public, anon;
grant execute on function digital_storage_delete_ok(text) to authenticated;

drop policy if exists "ressources numériques : dépôt par le vendeur éligible" on storage.objects;
create policy "ressources numériques : dépôt par le vendeur éligible" on storage.objects for insert to authenticated
  with check (bucket_id = 'digital-files' and digital_storage_write_ok(name));
drop policy if exists "ressources numériques : lecture propriétaire ou ticket valable" on storage.objects;
create policy "ressources numériques : lecture propriétaire ou ticket valable" on storage.objects for select to authenticated
  using (bucket_id = 'digital-files' and digital_storage_read_ok(name));
drop policy if exists "ressources numériques : suppression d'un fichier retiré" on storage.objects;
create policy "ressources numériques : suppression d'un fichier retiré" on storage.objects for delete to authenticated
  using (bucket_id = 'digital-files' and digital_storage_delete_ok(name));

-- ============================================================ 4. vendeur : licence, fichiers
create or replace function digital_listing_save(p_listing uuid, p_kind text, p_label text, p_max integer default 5) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); l listings%rowtype; v_label text := btrim(coalesce(p_label, ''));
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  perform _seller_require(uid, true);
  select * into l from listings where id = p_listing for update;
  if not found or l.seller_id is distinct from uid then raise exception 'Annonce introuvable'; end if;
  if l.status = 'removed' then raise exception 'Annonce retirée'; end if;
  if offer_type_of(l.category) = 'service' then raise exception 'Un service se commande sur devis : il ne peut pas être une ressource numérique'; end if;
  if p_kind is null or p_kind not in ('personal', 'commercial', 'educational') then raise exception 'Choisissez le type de licence : personnelle, commerciale ou éducative'; end if;
  if char_length(v_label) < 3 or char_length(v_label) > 500 then raise exception 'Décrivez votre licence en 3 à 500 caractères (vos conditions d''utilisation, saisies par vous)'; end if;
  if p_max is null or p_max < 1 or p_max > 50 then raise exception 'La limite de téléchargements doit être comprise entre 1 et 50'; end if;
  if not exists (select 1 from digital_listings where listing_id = l.id) and exists (select 1 from order_lines where listing_id = l.id) then
    raise exception 'Cette annonce a déjà été commandée : elle ne peut plus devenir une ressource numérique';
  end if;
  insert into digital_listings (listing_id, seller_id, license_kind, license_label, max_downloads)
  values (l.id, uid, p_kind, v_label, p_max)
  on conflict (listing_id) do update set license_kind = excluded.license_kind, license_label = excluded.license_label, max_downloads = excluded.max_downloads, updated_at = now();
  return my_digital_listing(l.id);
end $$;
revoke all on function digital_listing_save(uuid, text, text, integer) from public, anon;
grant execute on function digital_listing_save(uuid, text, text, integer) to authenticated;

create or replace function my_digital_listing(p_listing uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); d digital_listings%rowtype;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into d from digital_listings where listing_id = p_listing and seller_id = uid;
  if not found then return jsonb_build_object('digital', false); end if;
  return jsonb_build_object('digital', true, 'listing_id', d.listing_id, 'license_kind', d.license_kind, 'license_label', d.license_label, 'max_downloads', d.max_downloads,
    'assets', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'file_name', a.file_name, 'mime_type', a.mime_type, 'size_bytes', a.size_bytes, 'version', a.version, 'created_at', a.created_at)
                                         order by a.created_at) from digital_assets a where a.listing_id = d.listing_id and a.active), '[]'::jsonb));
end $$;
revoke all on function my_digital_listing(uuid) from public, anon;
grant execute on function my_digital_listing(uuid) to authenticated;

create or replace function digital_asset_register(p_listing uuid, p_path text, p_name text, p_mime text, p_size bigint, p_version text default '1.0', p_replaces uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); d digital_listings%rowtype; v_id uuid; v_name text := btrim(coalesce(p_name, '')); v_version text := coalesce(nullif(btrim(coalesce(p_version, '')), ''), '1.0');
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  perform _seller_require(uid, true);
  select * into d from digital_listings where listing_id = p_listing and seller_id = uid for update;
  if not found then raise exception 'Définissez d''abord la licence de cette ressource numérique'; end if;
  if p_path is null or (storage.foldername(p_path))[1] is distinct from uid::text or (storage.foldername(p_path))[2] is distinct from p_listing::text then raise exception 'Chemin de fichier invalide'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'digital-files' and name = p_path) then raise exception 'Fichier non déposé'; end if;
  if char_length(v_name) not between 1 and 120 then raise exception 'Nom de fichier invalide'; end if;
  if v_name ~* '\.(exe|bat|cmd|com|msi|scr|js|vbs|ps1|sh|jar|apk|dll|html|htm|svg)$' then raise exception 'Type de fichier refusé'; end if;
  if p_mime is null or not (p_mime = any (_digital_mimes())) then raise exception 'Type de fichier refusé (PDF, ZIP, images, vidéo MP4, audio MP3, texte, documents Office, modèle 3D GLB)'; end if;
  if p_size is null or p_size < 1 or p_size > 52428800 then raise exception 'Fichier trop lourd (50 Mo au maximum)'; end if;
  if char_length(v_version) > 30 then raise exception 'Version trop longue (30 caractères)'; end if;
  if p_replaces is not null and not exists (select 1 from digital_assets where id = p_replaces and listing_id = p_listing and active) then raise exception 'Fichier à remplacer introuvable'; end if;
  if p_replaces is null and (select count(*) from digital_assets where listing_id = p_listing and active) >= 10 then raise exception '10 fichiers au maximum par ressource'; end if;
  if exists (select 1 from digital_assets where storage_path = p_path) then raise exception 'Fichier déjà enregistré'; end if;
  insert into digital_assets (listing_id, seller_id, storage_path, file_name, mime_type, size_bytes, version, replaces)
  values (p_listing, uid, p_path, left(v_name, 120), p_mime, p_size, v_version, p_replaces) returning id into v_id;
  if p_replaces is not null then update digital_assets set active = false where id = p_replaces; end if;
  return v_id;
end $$;
revoke all on function digital_asset_register(uuid, text, text, text, bigint, text, uuid) from public, anon;
grant execute on function digital_asset_register(uuid, text, text, text, bigint, text, uuid) to authenticated;

create or replace function digital_asset_remove(p_asset uuid) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); a digital_assets%rowtype; l listings%rowtype;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into a from digital_assets where id = p_asset and seller_id = uid and active for update;
  if not found then raise exception 'Fichier introuvable'; end if;
  select * into l from listings where id = a.listing_id;
  if l.status in ('pending', 'approved') and not exists (select 1 from digital_assets where listing_id = a.listing_id and active and id <> a.id) then
    raise exception 'C''est le dernier fichier d''une annonce publiée : retirez d''abord l''annonce ou ajoutez-en un autre';
  end if;
  update digital_assets set active = false where id = a.id;
end $$;
revoke all on function digital_asset_remove(uuid) from public, anon;
grant execute on function digital_asset_remove(uuid) to authenticated;

-- Ventes de ressources numériques du vendeur : jamais les fichiers, jamais ceux d'un autre vendeur.
create or replace function seller_digital_sales() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(x order by x->>'granted_at' desc) from (
    select jsonb_build_object('id', e.id, 'listing_id', e.listing_id, 'title', l.title, 'order_number', o.number, 'license_kind', e.license_kind, 'status', e.status,
      'downloads_used', e.downloads_used, 'max_downloads', e.max_downloads, 'granted_at', e.granted_at,
      'last_download_at', (select max(g.downloaded_at) from digital_download_log g where g.entitlement_id = e.id)) x
    from digital_entitlements e join listings l on l.id = e.listing_id join orders o on o.id = e.order_id
    where e.seller_id = uid order by e.granted_at desc limit 200) s), '[]'::jsonb);
end $$;
revoke all on function seller_digital_sales() from public, anon;
grant execute on function seller_digital_sales() to authenticated;

-- ============================================================ 5. fiche publique : mention ressource numérique, licence, format et taille (jamais le chemin du fichier)
create or replace function product_digital_info(p_listing uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d digital_listings%rowtype; l listings%rowtype;
begin
  select * into l from listings where id = p_listing;
  if not found then return jsonb_build_object('digital', false); end if;
  if not (l.status = 'approved' and (l.shop_id is null or exists (select 1 from shops s where s.id = l.shop_id and s.status = 'active'))) and l.seller_id is distinct from auth.uid() then
    return jsonb_build_object('digital', false);
  end if;
  select * into d from digital_listings where listing_id = p_listing;
  if not found then return jsonb_build_object('digital', false); end if;
  return jsonb_build_object('digital', true, 'license_kind', d.license_kind, 'license_label', d.license_label, 'max_downloads', d.max_downloads,
    'files', coalesce((select jsonb_agg(jsonb_build_object('format', upper(coalesce(nullif(substring(a.file_name from '\.([A-Za-z0-9]{1,6})$'), ''), split_part(a.mime_type, '/', 2))),
                                                           'mime_type', a.mime_type, 'size_bytes', a.size_bytes, 'version', a.version) order by a.created_at)
                       from digital_assets a where a.listing_id = d.listing_id and a.active), '[]'::jsonb));
end $$;
revoke all on function product_digital_info(uuid) from public;
grant execute on function product_digital_info(uuid) to anon, authenticated;

-- ============================================================ 6. droit de téléchargement : création et révocation (triggers, circuit de paiement existant)
create or replace function _digital_grant_order(p_order uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; r record; v_n integer := 0; v_id uuid;
begin
  select * into o from orders where id = p_order;
  if not found or not o.paid or o.cancelled_at is not null or coalesce(o.cancelled, false) or coalesce(o.cod, false) then return 0; end if;
  for r in select ol.id as line_id, ol.title, d.listing_id, d.seller_id, d.license_kind, d.license_label, d.max_downloads
           from order_lines ol join digital_listings d on d.listing_id = ol.listing_id where ol.order_id = o.id loop
    insert into digital_entitlements (order_line_id, order_id, listing_id, buyer_id, seller_id, license_kind, license_label, max_downloads)
    values (r.line_id, o.id, r.listing_id, o.buyer_id, r.seller_id, r.license_kind, r.license_label, r.max_downloads)
    on conflict (order_line_id) do nothing returning id into v_id;
    if v_id is not null then
      v_n := v_n + 1;
      insert into notifications (user_id, kind, title, body, data)
      values (o.buyer_id, 'order', 'Ressource numérique disponible', 'Commande ' || o.number || ' : « ' || r.title || ' » est disponible dans « Mes téléchargements ».',
              jsonb_build_object('order_number', o.number, 'order_line', r.line_id));
    end if;
    v_id := null;
  end loop;
  return v_n;
end $$;
revoke all on function _digital_grant_order(uuid) from public, anon, authenticated;

create or replace function _digital_revoke_order(p_order uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update digital_entitlements set status = 'revoked', revoked_at = now(), revoked_reason = p_reason where order_id = p_order and status = 'active';
  delete from digital_download_tickets where entitlement_id in (select id from digital_entitlements where order_id = p_order);
end $$;
revoke all on function _digital_revoke_order(uuid, text) from public, anon, authenticated;

create or replace function h10_digital_grant() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.paid then perform _digital_grant_order(new.id); end if;
  return new;
end $$;
revoke all on function h10_digital_grant() from public, anon, authenticated;
drop trigger if exists trg_h10_digital_grant on orders;
create trigger trg_h10_digital_grant after update of paid on orders for each row execute function h10_digital_grant();

create or replace function h10_digital_cancel() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.cancelled_at is not null or coalesce(new.cancelled, false) then perform _digital_revoke_order(new.id, 'Commande annulée'); end if;
  return new;
end $$;
revoke all on function h10_digital_cancel() from public, anon, authenticated;
drop trigger if exists trg_h10_digital_cancel on orders;
create trigger trg_h10_digital_cancel after update of cancelled_at, cancelled on orders for each row execute function h10_digital_cancel();

create or replace function h10_digital_refund() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('approved', 'refunded') and new.kind = 'full' then perform _digital_revoke_order(new.order_id, 'Commande remboursée'); end if;
  return new;
end $$;
revoke all on function h10_digital_refund() from public, anon, authenticated;
drop trigger if exists trg_h10_digital_refund on order_refunds;
create trigger trg_h10_digital_refund after insert or update of status, kind on order_refunds for each row execute function h10_digital_refund();

create or replace function h10_digital_cod() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.cod and not coalesce(old.cod, false) and exists (select 1 from order_lines ol join digital_listings d on d.listing_id = ol.listing_id where ol.order_id = new.id) then
    raise exception 'Une ressource numérique ne se paie pas à la livraison : payez par Mobile Money';
  end if;
  return new;
end $$;
revoke all on function h10_digital_cod() from public, anon, authenticated;
drop trigger if exists trg_h10_digital_cod on orders;
create trigger trg_h10_digital_cod before update of cod on orders for each row execute function h10_digital_cod();

-- Publication : une ressource numérique n'est soumise ou approuvée qu'avec une licence et au moins un fichier actif.
create or replace function h10_digital_publish() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('pending', 'approved') and exists (select 1 from digital_listings where listing_id = new.id)
     and not exists (select 1 from digital_assets where listing_id = new.id and active) then
    raise exception 'Ajoutez au moins un fichier à votre ressource numérique avant de la publier';
  end if;
  return new;
end $$;
revoke all on function h10_digital_publish() from public, anon, authenticated;
drop trigger if exists trg_h10_digital_publish on listings;
create trigger trg_h10_digital_publish before update of status on listings for each row execute function h10_digital_publish();

-- ============================================================ 7. acheteur : mes téléchargements et URL courte
-- État réel d'une commande vis-à-vis du téléchargement : null si ouvert, sinon la raison (texte affichable).
create or replace function _digital_order_state(p_order uuid) returns text
language sql stable security definer set search_path = public as $$
  select case
    when o.id is null then 'Commande introuvable'
    when o.cancelled_at is not null or coalesce(o.cancelled, false) then 'Commande annulée : téléchargement impossible'
    when exists (select 1 from order_refunds r where r.order_id = o.id and r.kind = 'full' and r.status in ('approved', 'refunded')) then 'Commande remboursée : téléchargement impossible'
    when not o.paid then 'Cette commande n''est pas payée : le téléchargement s''ouvre après la confirmation du paiement'
    else null end
  from (select 1) x left join orders o on o.id = p_order
$$;
revoke all on function _digital_order_state(uuid) from public, anon, authenticated;

create or replace function my_downloads() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(x order by x->>'granted_at' desc) from (
    select jsonb_build_object('order_line', e.order_line_id, 'listing_id', e.listing_id, 'title', l.title, 'order_number', o.number, 'license_kind', e.license_kind, 'license_label', e.license_label,
      'status', case when e.status = 'revoked' or _digital_order_state(e.order_id) is not null then 'revoked' else 'active' end,
      'reason', coalesce(_digital_order_state(e.order_id), e.revoked_reason),
      'downloads_used', e.downloads_used, 'max_downloads', e.max_downloads, 'granted_at', e.granted_at,
      'files', case when e.status = 'active' and _digital_order_state(e.order_id) is null
                    then coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'file_name', a.file_name, 'mime_type', a.mime_type, 'size_bytes', a.size_bytes, 'version', a.version) order by a.created_at)
                                   from digital_assets a where a.listing_id = e.listing_id and a.active), '[]'::jsonb)
                    else '[]'::jsonb end,
      'history', coalesce((select jsonb_agg(jsonb_build_object('at', g.downloaded_at, 'file_name', g.file_name) order by g.downloaded_at desc)
                           from (select * from digital_download_log where entitlement_id = e.id order by downloaded_at desc limit 5) g), '[]'::jsonb)) x
    from digital_entitlements e join listings l on l.id = e.listing_id join orders o on o.id = e.order_id
    where e.buyer_id = uid order by e.granted_at desc limit 200) s), '[]'::jsonb);
end $$;
revoke all on function my_downloads() from public, anon;
grant execute on function my_downloads() to authenticated;

create or replace function digital_download_url(p_order_line uuid, p_asset uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); e digital_entitlements%rowtype; a digital_assets%rowtype; v_state text; v_n integer; v_ttl constant integer := 60;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = uid and suspended) then raise exception 'Compte inactif'; end if;
  select * into e from digital_entitlements where order_line_id = p_order_line and buyer_id = uid for update;
  if not found then raise exception 'Ressource introuvable'; end if;
  v_state := _digital_order_state(e.order_id);
  if v_state is not null then raise exception '%', v_state; end if;
  if e.status <> 'active' then raise exception 'Accès révoqué : %', coalesce(e.revoked_reason, 'téléchargement impossible'); end if;
  if e.downloads_used >= e.max_downloads then raise exception 'Limite de téléchargements atteinte (% sur %)', e.downloads_used, e.max_downloads; end if;
  if p_asset is null then
    select count(*) into v_n from digital_assets where listing_id = e.listing_id and active;
    if v_n = 0 then raise exception 'Aucun fichier disponible pour le moment : contactez le vendeur'; end if;
    if v_n > 1 then raise exception 'Choisissez le fichier à télécharger'; end if;
    select * into a from digital_assets where listing_id = e.listing_id and active;
  else
    select * into a from digital_assets where id = p_asset and listing_id = e.listing_id and active;
    if not found then raise exception 'Fichier introuvable'; end if;
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'digital-files' and name = a.storage_path) then raise exception 'Fichier indisponible : contactez le vendeur'; end if;
  delete from digital_download_tickets where entitlement_id = e.id and expires_at <= now();
  insert into digital_download_tickets (entitlement_id, buyer_id, storage_path, expires_at) values (e.id, uid, a.storage_path, now() + make_interval(secs => v_ttl));
  update digital_entitlements set downloads_used = downloads_used + 1 where id = e.id;
  insert into digital_download_log (entitlement_id, asset_id, buyer_id, file_name) values (e.id, a.id, uid, a.file_name);
  return jsonb_build_object('bucket', 'digital-files', 'path', a.storage_path, 'file_name', a.file_name, 'expires_in', v_ttl,
                            'downloads_used', e.downloads_used + 1, 'max_downloads', e.max_downloads, 'remaining', e.max_downloads - e.downloads_used - 1);
end $$;
revoke all on function digital_download_url(uuid, uuid) from public, anon;
grant execute on function digital_download_url(uuid, uuid) to authenticated;
