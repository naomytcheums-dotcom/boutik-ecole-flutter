-- Lot S3 : boutique (S3-15, S3-17 pour les boutiques, S3-8).
--  * shop_save : logo et bannière limités au stockage public Supabase, réseaux sociaux = liens https (ou numéro pour WhatsApp) ;
--    toute modification de l'identité publique (nom, description, logo, bannière, réseaux) d'une boutique ACTIVE est signalée aux valideurs
--    pour post-modération, sans dépublier la boutique (une boutique « pending » masquerait toutes ses annonces).
--  * shop_submit : les valideurs sont notifiés de la soumission (ou de la réouverture) d'une boutique.
--  * Les annonces sans boutique du vendeur sont rattachées à la boutique à l'enregistrement et à la soumission.
-- Repart de la dernière définition (20261107000000_marketplace.sql). Fichier additif et rejouable.

create or replace function _shop_url_ok(p text) returns boolean
language sql immutable as $$
  select p is null or p = '' or (char_length(p) <= 500 and p ~* '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/[^[:space:]]+$')
$$;

create or replace function _shop_social_ok(p_key text, p_val text) returns boolean
language sql immutable as $$
  select p_key in ('instagram', 'facebook', 'whatsapp', 'tiktok', 'website')
     and char_length(coalesce(p_val, '')) between 1 and 200
     and (p_val ~* '^https://[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(/[^[:space:]]*)?$'
          or (p_key = 'whatsapp' and p_val ~ '^\+?[0-9 ]{8,16}$'))
$$;
revoke all on function _shop_url_ok(text), _shop_social_ok(text, text) from public, anon, authenticated;

-- Prévient les valideurs d'un événement boutique (une seule alerte par boutique et par heure pour une modification).
create or replace function _notify_shop_validators(p_shop shops, p_title text, p_body text, p_dedupe boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select id from profiles where role::text in ('admin', 'dept', 'support') and not coalesce(suspended, false) limit 100 loop
    if p_dedupe and exists (select 1 from notifications n where n.user_id = r.id and n.kind = 'shop' and n.title = p_title and n.data->>'shop' = p_shop.slug and n.created_at > now() - interval '1 hour') then
      continue;
    end if;
    perform notify_user(r.id, 'shop', p_title, p_body, jsonb_build_object('shop', p_shop.slug, 'shop_id', p_shop.id));
  end loop;
end $$;
revoke all on function _notify_shop_validators(shops, text, text, boolean) from public, anon, authenticated;

create or replace function shop_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); s shops%rowtype; prev shops%rowtype; v_slug text; v_cats text[]; v_exists boolean; k text; v text; v_changed boolean := false;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  select * into s from shops where owner_id = uid;
  v_exists := found;
  if v_exists and s.status in ('suspended', 'closed') then raise exception 'Boutique % : modification impossible', case s.status when 'suspended' then 'suspendue' else 'fermée' end; end if;
  if p ? 'categories' then
    select coalesce(array_agg(x), '{}') into v_cats from (select distinct jsonb_array_elements_text(p->'categories') x limit 5) q;
  end if;
  -- identité publique : adresses d'images dans le stockage Supabase, réseaux = liens https
  if p ? 'logo_url' and (not v_exists or s.logo_url is distinct from nullif(p->>'logo_url', '')) and not _shop_url_ok(p->>'logo_url') then raise exception 'Logo : utilisez le bouton « Ajouter le logo » (image hébergée par la plateforme)'; end if;
  if p ? 'banner_url' and (not v_exists or s.banner_url is distinct from nullif(p->>'banner_url', '')) and not _shop_url_ok(p->>'banner_url') then raise exception 'Bannière : utilisez le bouton « Ajouter la bannière » (image hébergée par la plateforme)'; end if;
  if p ? 'socials' then
    if jsonb_typeof(p->'socials') <> 'object' then raise exception 'Réseaux sociaux invalides'; end if;
    for k, v in select key, value #>> '{}' from jsonb_each(p->'socials') loop
      if (not v_exists or s.socials ->> k is distinct from v) and not _shop_social_ok(k, v) then
        raise exception 'Réseau « % » : saisissez un lien commençant par https://%', k, case when k = 'whatsapp' then ' (ou un numéro)' else '' end;
      end if;
    end loop;
  end if;
  prev := s;
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
    v_changed := prev.status = 'active' and (s.name is distinct from prev.name or s.description is distinct from prev.description or s.logo_url is distinct from prev.logo_url
                 or s.banner_url is distinct from prev.banner_url or s.socials is distinct from prev.socials);
  end if;
  perform set_config('app.internal', '', true);
  if v_changed then
    -- post-modération : la boutique reste publiée, les valideurs sont prévenus et peuvent la suspendre
    perform _notify_shop_validators(s, 'Boutique modifiée', s.name || ' : identité publique modifiée (nom, description, logo, bannière ou réseaux), à vérifier.', true);
    insert into audit_log (actor, action, target, category, level) values (uid::text, 'Boutique modifiée (post-modération)', s.slug, 'Marketplace', 'Normal');
  end if;
  perform _attach_seller_listings(uid);
  return to_jsonb(s);
end $$;

create or replace function shop_submit() returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; v_was text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where owner_id = auth.uid() for update;
  if not found then raise exception 'Créez d''abord votre boutique'; end if;
  if s.status not in ('draft', 'closed') then raise exception 'La boutique est déjà % ', case s.status when 'pending' then 'en cours de validation' when 'active' then 'active' else 'suspendue' end; end if;
  if s.description is null or s.logo_url is null or cardinality(s.categories) = 0 then raise exception 'Renseignez au moins le logo, la description et une catégorie avant de soumettre'; end if;
  v_was := s.status;
  perform set_config('app.internal', '1', true);
  update shops set status = 'pending', review_note = null where id = s.id returning * into s;
  perform set_config('app.internal', '', true);
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Boutique soumise', s.slug, 'Marketplace', 'Normal');
  perform _notify_shop_validators(s, case when v_was = 'closed' then 'Boutique rouverte à valider' else 'Boutique à valider' end, s.name || ' attend votre validation.');
  perform _attach_seller_listings(auth.uid());
  return 'pending';
end $$;

revoke all on function shop_save(jsonb), shop_submit() from public, anon;
grant execute on function shop_save(jsonb), shop_submit() to authenticated;

-- Retour arrière : recréer shop_save(jsonb) et shop_submit() depuis 20261107000000_marketplace.sql ; drop function _notify_shop_validators(shops, text, text, boolean), _shop_url_ok(text), _shop_social_ok(text, text).
