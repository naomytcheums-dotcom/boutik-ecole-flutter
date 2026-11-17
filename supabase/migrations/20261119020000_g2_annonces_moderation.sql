-- Lot G2 (publication, annonces, boutique, stock, modération) : corrections de bout en bout, reprises de la DERNIÈRE définition de
-- protect_listing_status (20261117000100_securite_etudiant.sql) dont toutes les gardes sont conservées.
--  1. Modération : un responsable de département ne décide que pour son département (ou pour un département sans responsable actif) ;
--     transitions du valideur limitées (en validation -> validée/refusée, validée <-> refusée, retrait par l'administrateur) ; motif de refus obligatoire (5 caractères) ;
--     jamais de validation pour un vendeur suspendu ; un responsable ne modifie QUE le statut et le motif d'une annonce vendeur (contenu, prix, stock restent au vendeur).
--  2. Vendeur : titre normalisé (espaces) pour que le contrôle de doublon fonctionne ; compte suspendu refusé ; une annonce de produit ne peut pas être
--     envoyée en validation (ni rester en validation après retrait de sa dernière photo) sans photo ; le vendeur est prévenu quand une modification
--     renvoie son annonce publiée en validation (elle n'est plus visible des acheteurs).
--  3. File de validation : listing_review_queue() renvoie le nom du vendeur, la description, les photos et le département (le valideur voit ce qu'il décide).
--  4. Brouillons privés : un brouillon n'est lisible que de son vendeur et de l'administrateur (plus du département).
--  5. Vendeur suspendu : ses annonces publiées passent en « brouillon masqué » et sa boutique active en « suspendue » (invisibles des acheteurs et visiteurs,
--     quel que soit le chemin de lecture) ; elles sont rétablies telles quelles à la levée de la suspension.
--  6. Prix : une baisse de prix annule les ventes flash devenues plus chères que le prix normal, désactive les packs devenus sans remise, et
--     efface un « prix avant promotion » devenu inférieur ou égal au prix.
--  7. Stock : l'annulation d'une commande rend aussi les unités réservées à une vente flash (le stock de l'annonce était déjà rendu).
-- Additive et rejouable. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Périmètre du valideur
create or replace function _listing_staff_scope(p_dept text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); d text;
begin
  if auth.uid() is null then return false; end if;
  if r = 'admin' then return true; end if;
  if r <> 'dept' then return false; end if;
  select lower(trim(coalesce(department, ''))) into d from profiles where id = auth.uid();
  if d = '' or d = lower(trim(coalesce(p_dept, ''))) then return true; end if;
  -- département sans responsable actif : n'importe quel responsable peut décider (sinon l'annonce resterait bloquée)
  return not exists (select 1 from profiles p where p.role::text = 'dept' and not coalesce(p.suspended, false) and lower(trim(coalesce(p.department, ''))) = lower(trim(coalesce(p_dept, ''))));
end $$;
revoke all on function _listing_staff_scope(text) from public, anon, authenticated;

-- ============================================================ 2. protect_listing_status
create or replace function protect_listing_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r text := coalesce(current_role_name()::text, '');
  v_media text := '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/';
  v_u text;
  v_recheck boolean := false;
  v_ping boolean := false;
  v record;
begin
  if auth.uid() is null or coalesce(current_setting('app.internal', true), '') = '1' then return new; end if;  -- éditeur SQL / fonctions serveur
  if r in ('dept', 'admin') then
    if tg_op = 'UPDATE' then
      new.seller_id := old.seller_id;                               -- un produit de la plateforme reste à la plateforme
      if old.seller_id is not null then
        if r = 'dept' and (new.title is distinct from old.title or new.description is distinct from old.description or new.category is distinct from old.category
             or new.price is distinct from old.price or new.stock is distinct from old.stock or new.image_url is distinct from old.image_url
             or new.images is distinct from old.images or new.video_url is distinct from old.video_url or new.specs is distinct from old.specs
             or new.variants is distinct from old.variants or new.department is distinct from old.department or new.price_before is distinct from old.price_before
             or new.supervisor is distinct from old.supervisor or new.shop_id is distinct from old.shop_id) then
          raise exception 'Un responsable de département ne modifie que le statut et le motif d''une annonce de vendeur';
        end if;
        if new.status is distinct from old.status then
          if not ((old.status = 'pending' and new.status in ('approved', 'rejected'))
               or (old.status = 'approved' and new.status = 'rejected')
               or (old.status = 'rejected' and new.status = 'approved')
               or (r = 'admin' and old.status <> 'removed' and new.status = 'removed')) then
            raise exception 'Transition de statut non autorisée (% vers %)', old.status, new.status;
          end if;
          if not _listing_staff_scope(old.department) then raise exception 'Cette annonce relève d''un autre département'; end if;
          if new.status = 'approved' and exists (select 1 from profiles p where p.id = old.seller_id and coalesce(p.suspended, false)) then
            raise exception 'Le vendeur est suspendu : validation impossible';
          end if;
          if new.status = 'rejected' and char_length(trim(coalesce(new.review_note, ''))) < 5 then
            raise exception 'Indiquez le motif du refus (5 caractères minimum)';
          end if;
          if new.status = 'approved' and new.review_note is not distinct from old.review_note then new.review_note := null; end if;
        end if;
      end if;
      if new.status is distinct from old.status then new.reviewed_by := auth.uid(); end if;
    end if;
    new.updated_at := now();
    return new;
  end if;
  if exists (select 1 from profiles p where p.id = auth.uid() and coalesce(p.suspended, false)) then raise exception 'Compte suspendu : modification impossible'; end if;
  if tg_op = 'INSERT' then
    new.seller_id := auth.uid();                                   -- une annonce appartient toujours à son créateur
    if new.status not in ('draft', 'pending') then new.status := 'pending'; end if;
    new.reviewed_by := null;
    new.review_note := null;
    new.showcase := false;
    v_ping := new.status = 'pending';
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
    new.created_at := old.created_at;
    new.showcase := old.showcase;
    new.reviewed_by := old.reviewed_by;
    new.review_note := case when new.status = 'pending' and old.status <> 'pending' then null else old.review_note end;
    -- Une annonce validée ne change pas de contenu sans nouvelle validation (le prix, le stock et les variantes restent libres).
    if old.status = 'approved' and new.status = 'approved'
       and (new.title is distinct from old.title or new.description is distinct from old.description or new.category is distinct from old.category
            or new.image_url is distinct from old.image_url or new.images is distinct from old.images or new.video_url is distinct from old.video_url
            or new.specs is distinct from old.specs or new.supervisor is distinct from old.supervisor or new.department is distinct from old.department) then
      v_recheck := true;
      new.status := 'pending';
      new.reviewed_by := null;
      new.review_note := null;
    end if;
    v_ping := v_recheck or (new.status = 'pending' and old.status <> 'pending');
  end if;
  new.title := btrim(regexp_replace(coalesce(new.title, ''), '\s+', ' ', 'g'));
  -- Une annonce de produit envoyée en validation (ou renvoyée en validation) doit avoir au moins une photo.
  if new.status = 'pending' and (tg_op = 'INSERT' or old.status is distinct from 'pending' or v_recheck)
     and offer_type_of(new.category) <> 'service' and cardinality(coalesce(new.images, '{}')) = 0 and coalesce(new.image_url, '') = '' then
    raise exception 'Ajoutez au moins une photo : une annonce sans photo ne peut pas être envoyée en validation';
  end if;
  -- Médias : uniquement des fichiers du stockage public de l'application (https).
  if tg_op = 'INSERT' or new.image_url is distinct from old.image_url then
    if coalesce(new.image_url, '') <> '' and new.image_url !~ v_media then raise exception 'La photo de l''annonce doit provenir du téléversement de l''application'; end if;
  end if;
  if tg_op = 'INSERT' or new.video_url is distinct from old.video_url then
    if coalesce(new.video_url, '') <> '' and new.video_url !~ v_media then raise exception 'La vidéo de l''annonce doit provenir du téléversement de l''application'; end if;
  end if;
  if tg_op = 'INSERT' or new.images is distinct from old.images then
    foreach v_u in array coalesce(new.images, '{}') loop
      if coalesce(v_u, '') <> '' and v_u !~ v_media then raise exception 'Les photos de l''annonce doivent provenir du téléversement de l''application'; end if;
    end loop;
  end if;
  new.updated_at := now();
  if v_recheck then
    -- insertion directe : notify_user ignore l'auteur de l'action, or ici le vendeur doit garder une trace de ce retrait de la vente
    insert into notifications (user_id, kind, title, body, data)
    values (new.seller_id, 'listing', 'Annonce renvoyée en validation',
            left('« ' || new.title || ' » a été modifiée : elle n''est plus visible des acheteurs jusqu''à sa nouvelle validation par le département.', 300),
            jsonb_build_object('listing_id', new.id, 'status', 'pending'));
  end if;
  if v_ping then
    for v in select p.id from profiles p
             where not coalesce(p.suspended, false)
               and (p.role::text = 'admin' or (p.role::text = 'dept' and lower(coalesce(p.department, '')) = lower(coalesce(new.department, ''))))
               and not exists (select 1 from notifications n where n.user_id = p.id and n.kind = 'listing_review' and n.read_at is null
                               and n.created_at > now() - interval '15 minutes' and n.data ->> 'listing' = new.id::text) loop
      perform notify_user(v.id, 'listing_review', case when v_recheck then 'Annonce modifiée à revalider' else 'Annonce à valider' end,
                          left('« ' || coalesce(new.title, 'Annonce') || ' » attend votre validation.', 300), jsonb_build_object('listing', new.id));
    end loop;
  end if;
  return new;
end $$;
revoke execute on function protect_listing_status() from public, anon, authenticated;

-- ============================================================ 3. File de validation (département / administrateur)
create or replace function listing_review_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé aux valideurs d''annonces'; end if;
  return coalesce((
    select jsonb_agg(q.x order by q.u desc) from (
      select jsonb_build_object('id', l.id, 'title', l.title, 'category', l.category, 'price', l.price, 'stock', l.stock, 'status', l.status, 'review_note', l.review_note,
               'description', l.description, 'images', to_jsonb(l.images), 'video_url', l.video_url, 'department', l.department,
               'seller_id', l.seller_id, 'seller_name', coalesce(nullif(trim(p.name), ''), 'Étudiant-vendeur'), 'seller_certified', p.certification::text = 'approved',
               'created_at', l.created_at, 'updated_at', l.updated_at) x, l.updated_at u
      from listings l left join profiles p on p.id = l.seller_id
      where l.seller_id is not null and l.status in ('pending', 'approved', 'rejected') and _listing_staff_scope(l.department)
      order by l.updated_at desc limit 200) q), '[]'::jsonb);
end $$;
revoke all on function listing_review_queue() from public, anon;
grant execute on function listing_review_queue() to authenticated;

-- ============================================================ 4. Brouillons privés
drop policy if exists "annonces : brouillons privés" on listings;
create policy "annonces : brouillons privés" on listings as restrictive for select
  using (status <> 'draft' or seller_id is null or seller_id = auth.uid() or coalesce(current_role_name()::text, '') = 'admin');

-- ============================================================ 5. Vendeur suspendu : annonces et boutique masquées, rétablies à la levée
create table if not exists g2_suspension_holds (
  kind text not null check (kind in ('listing', 'shop')),
  ref uuid not null,
  owner_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (kind, ref)
);
alter table g2_suspension_holds enable row level security;
revoke all on g2_suspension_holds from anon, authenticated;

create or replace function g2_suspension_sync() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_prev text := coalesce(current_setting('app.internal', true), '');
begin
  -- vendeur inactif : compte suspendu, ou rôle qui n'est plus celui d'un vendeur (étudiant, équipe)
  if (coalesce(new.suspended, false) or new.role::text in ('client', 'company', 'other', 'visitor')) is not distinct from (coalesce(old.suspended, false) or old.role::text in ('client', 'company', 'other', 'visitor')) then return null; end if;
  perform set_config('app.internal', '1', true);
  if coalesce(new.suspended, false) or new.role::text in ('client', 'company', 'other', 'visitor') then
    insert into g2_suspension_holds (kind, ref, owner_id) select 'listing', id, new.id from listings where seller_id = new.id and status = 'approved' on conflict do nothing;
    update listings set status = 'draft', review_note = 'Annonce masquée : compte vendeur suspendu ou inactif.' where seller_id = new.id and id in (select ref from g2_suspension_holds where kind = 'listing' and owner_id = new.id) and status = 'approved';
    insert into g2_suspension_holds (kind, ref, owner_id) select 'shop', id, new.id from shops where owner_id = new.id and status = 'active' on conflict do nothing;
    update shops set status = 'suspended', review_note = 'Compte suspendu.' where owner_id = new.id and id in (select ref from g2_suspension_holds where kind = 'shop' and owner_id = new.id) and status = 'active';
  else
    update listings set status = 'approved', review_note = null where seller_id = new.id and status = 'draft' and id in (select ref from g2_suspension_holds where kind = 'listing' and owner_id = new.id);
    update shops set status = 'active', review_note = null where owner_id = new.id and status = 'suspended' and id in (select ref from g2_suspension_holds where kind = 'shop' and owner_id = new.id);
    delete from g2_suspension_holds where owner_id = new.id;
  end if;
  perform set_config('app.internal', v_prev, true);
  return null;
end $$;
revoke all on function g2_suspension_sync() from public, anon, authenticated;
drop trigger if exists trg_g2_suspension_sync on profiles;
create trigger trg_g2_suspension_sync after update of suspended, role on profiles for each row execute function g2_suspension_sync();

-- Rattrapage : les annonces et boutiques déjà actives d'un compte suspendu sont masquées maintenant.
do $$
declare p record;
begin
  for p in select id from profiles where coalesce(suspended, false) and (exists (select 1 from listings where seller_id = profiles.id and status = 'approved') or exists (select 1 from shops where owner_id = profiles.id and status = 'active')) loop
    perform set_config('app.internal', '1', true);
    insert into g2_suspension_holds (kind, ref, owner_id) select 'listing', id, p.id from listings where seller_id = p.id and status = 'approved' on conflict do nothing;
    update listings set status = 'draft', review_note = 'Annonce masquée : compte suspendu.' where seller_id = p.id and status = 'approved';
    insert into g2_suspension_holds (kind, ref, owner_id) select 'shop', id, p.id from shops where owner_id = p.id and status = 'active' on conflict do nothing;
    update shops set status = 'suspended', review_note = 'Compte suspendu.' where owner_id = p.id and status = 'active';
    perform set_config('app.internal', '', true);
  end loop;
end $$;

-- ============================================================ 6. Prix : promotions devenues incohérentes
create or replace function g2_price_before() returns trigger
language plpgsql as $$
begin
  if new.price_before is not null and new.price_before <= new.price then new.price_before := null; end if;
  return new;
end $$;
drop trigger if exists trg_g2_price_before on listings;
create trigger trg_g2_price_before before update of price on listings for each row execute function g2_price_before();

create or replace function g2_price_promos() returns trigger
language plpgsql security definer set search_path = public as $$
declare n integer := 0; m integer := 0;
begin
  if new.price is not distinct from old.price then return null; end if;
  update flash_sales set cancelled = true where listing_id = new.id and not cancelled and ends_at > now() and sale_price >= new.price;
  get diagnostics n = row_count;
  update shop_packs k set active = false
    where k.active and exists (select 1 from jsonb_array_elements(k.items) i where i->>'listing' = new.id::text)
      and k.price >= (select coalesce(sum(l.price * (i->>'qty')::int), 0) from jsonb_array_elements(k.items) i join listings l on l.id = (i->>'listing')::uuid);
  get diagnostics m = row_count;
  if (n > 0 or m > 0) and new.seller_id is not null then
    insert into notifications (user_id, kind, title, body, data)
    values (new.seller_id, 'listing', 'Promotion désactivée',
            left('Le prix de « ' || new.title || ' » a changé : ' || case when n > 0 then n || ' vente(s) flash annulée(s)' else '' end
                 || case when n > 0 and m > 0 then ' et ' else '' end || case when m > 0 then m || ' pack(s) désactivé(s)' else '' end || ' (plus de remise réelle).', 300),
            jsonb_build_object('listing_id', new.id));
  end if;
  return null;
end $$;
revoke all on function g2_price_promos() from public, anon, authenticated;
drop trigger if exists trg_g2_price_promos on listings;
create trigger trg_g2_price_promos after update of price on listings for each row execute function g2_price_promos();

-- ============================================================ 7. Annulation : les unités d'une vente flash sont rendues avec le stock
create or replace function g2_flash_restock() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.cancelled_at is null and new.cancelled_at is not null then
    update flash_sales f set sold = greatest(f.sold - x.q, 0)
      from (select flash_id, sum(qty)::int q from order_lines where order_id = new.id and flash_id is not null group by flash_id) x
      where f.id = x.flash_id;
  end if;
  return null;
end $$;
revoke all on function g2_flash_restock() from public, anon, authenticated;
drop trigger if exists trg_g2_flash_restock on orders;
create trigger trg_g2_flash_restock after update of cancelled_at on orders for each row execute function g2_flash_restock();

-- Retour arrière : drop trigger trg_g2_flash_restock on orders; trg_g2_price_promos et trg_g2_price_before on listings; trg_g2_suspension_sync on profiles ;
--   drop function g2_flash_restock(), g2_price_promos(), g2_price_before(), g2_suspension_sync(), listing_review_queue(), _listing_staff_scope(text) ; drop table g2_suspension_holds
--   (avant : rétablir à la main les annonces « Annonce masquée : compte suspendu. » en 'approved' et les boutiques 'suspended' correspondantes) ;
--   drop policy "annonces : brouillons privés" on listings ; recréer protect_listing_status depuis 20261117000100_securite_etudiant.sql.
