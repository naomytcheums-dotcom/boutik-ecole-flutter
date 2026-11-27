-- H13.1 · Multi-boutiques (1/3) : plusieurs boutiques par propriétaire, boutique active, équipe de boutique, création / identité / activation.
--  · shops.owner_id n'est plus unique (levée de contrainte uniquement : aucune donnée supprimée ni modifiée) ; limite réglable : platform_settings « shops.max_per_owner »
--    (3 par défaut, de 1 à 50, modifiable par l'administration via setting_set ; les boutiques fermées ne comptent pas).
--  · règle de création INCHANGÉE : compte étudiant vendeur éligible (déclencheurs shops_owner_must_be_student et k2_shop_seller_guard) ; les organisations restent exclues.
--  · shop_active(user_id, shop_id) : boutique active persistée côté serveur (propriétaire ou membre ; table à part car seller_settings est réservée aux vendeurs éligibles) ; les RPC vendeur sans paramètre boutique suivent la boutique active.
--  · shop_members(shop_id, user_id, role manager|staff|viewer) : droits bornés (viewer : lecture ; staff : + préparation des commandes ; manager : + promotions, produits mis en avant,
--    identité de la boutique) ; seul le propriétaire gère les membres, l'ouverture, la fermeture et l'activation de la boutique.
--  · shop_save / shop_submit / shop_close / my_shop deviennent multi-boutiques (compatibles : sans identifiant, ils agissent sur la boutique active).
-- Strictement additive. Retour arrière : voir la fin du fichier.

-- 1. Schéma ---------------------------------------------------------------------------------------------------------------------------
do $$
declare c record;
begin
  for c in select con.conname from pg_constraint con
           where con.conrelid = 'public.shops'::regclass and con.contype = 'u'
             and con.conkey = array[(select a.attnum from pg_attribute a where a.attrelid = 'public.shops'::regclass and a.attname = 'owner_id')]
  loop
    execute format('alter table shops drop constraint %I', c.conname);
  end loop;
end $$;
create index if not exists shops_owner_idx on shops (owner_id, created_at);

create table if not exists shop_active (
  user_id uuid primary key references profiles(id) on delete cascade,
  shop_id uuid not null references shops(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index if not exists shop_active_shop_idx on shop_active (shop_id);
alter table shop_active enable row level security;
revoke all on shop_active from anon, authenticated;

insert into platform_settings (key, value) values ('shops.max_per_owner', '3'::jsonb) on conflict (key) do nothing;

create table if not exists shop_members (
  shop_id uuid not null references shops(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null check (role in ('manager', 'staff', 'viewer')),
  invited_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (shop_id, user_id)
);
create index if not exists shop_members_user_idx on shop_members (user_id);
create index if not exists shop_members_invited_idx on shop_members (invited_by);
alter table shop_members enable row level security;
revoke all on shop_members from anon, authenticated;
grant select on shop_members to authenticated;

-- 2. Outils de droits -----------------------------------------------------------------------------------------------------------------
create or replace function _shop_rank(p_role text) returns integer language sql immutable as $$
  select case p_role when 'owner' then 4 when 'manager' then 3 when 'staff' then 2 when 'viewer' then 1 else 0 end
$$;

create or replace function _shop_role(p_shop uuid, p_uid uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when s.owner_id = p_uid then 'owner'
              else (select m.role from shop_members m join profiles pm on pm.id = m.user_id
                    where m.shop_id = s.id and m.user_id = p_uid and not coalesce(pm.suspended, false)) end
  from shops s where s.id = p_shop and p_uid is not null
$$;
revoke all on function _shop_rank(text), _shop_role(uuid, uuid) from public, anon, authenticated;

-- Variante pour les politiques RLS : toujours l'identité de l'appelant, jamais un identifiant arbitraire.
create or replace function _my_shop_role(p_shop uuid) returns text
language sql stable security definer set search_path = public as $$
  select _shop_role(p_shop, auth.uid())
$$;
revoke all on function _my_shop_role(uuid) from public;
grant execute on function _my_shop_role(uuid) to anon, authenticated;

drop policy if exists "boutiques : actives, propriétaire, équipe" on shops;
create policy "boutiques : actives, propriétaire, équipe" on shops for select
  using (status = 'active' or owner_id = auth.uid() or _my_shop_role(id) is not null
         or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(owner_id)));

drop policy if exists "membres de boutique : propriétaire et intéressé" on shop_members;
create policy "membres de boutique : propriétaire et intéressé" on shop_members for select
  using (user_id = auth.uid() or _my_shop_role(shop_id) = 'owner');

create or replace function shops_max_per_owner() returns integer
language sql stable security definer set search_path = public as $$
  select least(greatest(coalesce((select case when jsonb_typeof(value) = 'number' then (value #>> '{}')::numeric::integer end from platform_settings where key = 'shops.max_per_owner'), 3), 1), 50)
$$;
revoke all on function shops_max_per_owner() from public, anon;
grant execute on function shops_max_per_owner() to authenticated;

-- Boutique par défaut d'un propriétaire : sa boutique active enregistrée, sinon la plus ancienne (hors fermées sauf demande).
create or replace function _shop_default_owned(p_owner uuid, p_open_only boolean default true) returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.id from shop_active ss join shops s on s.id = ss.shop_id
      where ss.user_id = p_owner and s.owner_id = p_owner and (s.status <> 'closed' or not p_open_only)),
    (select s.id from shops s where s.owner_id = p_owner and (s.status <> 'closed' or not p_open_only) order by s.created_at, s.id limit 1))
$$;
revoke all on function _shop_default_owned(uuid, boolean) from public, anon, authenticated;

-- Boutique active d'un compte (propriétaire ou membre) : choix enregistré si encore accessible, sinon la plus ancienne boutique ouverte.
create or replace function _shop_active_id(p_uid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.id from shop_active ss join shops s on s.id = ss.shop_id
      where ss.user_id = p_uid and s.status <> 'closed' and _shop_rank(_shop_role(s.id, p_uid)) >= 1),
    (select s.id from shops s where s.owner_id = p_uid and s.status <> 'closed' order by s.created_at, s.id limit 1),
    (select m.shop_id from shop_members m join shops s on s.id = m.shop_id where m.user_id = p_uid and s.status <> 'closed' order by m.created_at, m.shop_id limit 1),
    (select s.id from shop_active ss join shops s on s.id = ss.shop_id where ss.user_id = p_uid and _shop_rank(_shop_role(s.id, p_uid)) >= 1),
    (select s.id from shops s where s.owner_id = p_uid order by s.created_at, s.id limit 1))
$$;
revoke all on function _shop_active_id(uuid) from public, anon, authenticated;

-- Périmètre d'une lecture vendeur : la boutique demandée (droit minimum exigé), sinon la boutique active ; sans aucune boutique : toutes les annonces du vendeur (compatibilité).
create or replace function _shop_scope(p_shop uuid default null, p_min text default 'viewer') returns table (scope_shop uuid, scope_owner uuid)
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v uuid; o uuid;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if p_shop is not null then
    select s.id, s.owner_id into v, o from shops s where s.id = p_shop;
    if v is null or _shop_rank(_shop_role(v, uid)) < _shop_rank(p_min) then raise exception 'Boutique introuvable'; end if;
  else
    v := _shop_active_id(uid);
    if v is null then
      scope_shop := null; scope_owner := uid; return next; return;
    end if;
    select s.owner_id into o from shops s where s.id = v;
    if _shop_rank(_shop_role(v, uid)) < _shop_rank(p_min) then raise exception 'Droits insuffisants sur la boutique active'; end if;
  end if;
  scope_shop := v; scope_owner := o; return next;
end $$;
revoke all on function _shop_scope(uuid, text) from public, anon;
grant execute on function _shop_scope(uuid, text) to authenticated;

-- Boutique sur laquelle on agit (promotions, produits mis en avant) : droit « manager » minimum ; le vendeur propriétaire doit rester éligible.
create or replace function _shop_manage(p_shop uuid default null, p_need_active boolean default true) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v uuid; s shops%rowtype; r text;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  v := coalesce(p_shop, _shop_active_id(uid));
  if v is not null then select * into s from shops where id = v; end if;
  r := case when s.id is not null then _shop_role(s.id, uid) end;
  if s.id is null or _shop_rank(r) < 3 then
    if p_shop is null then raise exception 'Votre boutique doit être active (validée) pour cette action'; end if;
    raise exception 'Boutique introuvable';
  end if;
  if p_need_active and s.status <> 'active' then raise exception 'Votre boutique doit être active (validée) pour cette action'; end if;
  if r <> 'owner' then perform _seller_require(s.owner_id, true); end if;
  return s.id;
end $$;
revoke all on function _shop_manage(uuid, boolean) from public, anon, authenticated;

create or replace function _my_shop_id(p_active boolean default true) returns uuid
language sql stable security definer set search_path = public as $$
  select _shop_manage(null, p_active)
$$;

-- 3. Boutique active ------------------------------------------------------------------------------------------------------------------
create or replace function shop_set_active(p_shop uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s shops%rowtype;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if p_shop is not null then
    select * into s from shops where id = p_shop;
    if not found or _shop_rank(_shop_role(s.id, uid)) < 1 then raise exception 'Boutique introuvable'; end if;
  end if;
  if p_shop is null then delete from shop_active where user_id = uid;
  else insert into shop_active (user_id, shop_id) values (uid, p_shop) on conflict (user_id) do update set shop_id = excluded.shop_id, updated_at = now(); end if;
  s := null;
  select * into s from shops where id = _shop_active_id(uid);
  return jsonb_build_object('active_shop_id', s.id, 'name', s.name, 'status', s.status, 'role', case when s.id is not null then _shop_role(s.id, uid) end);
end $$;

create or replace function my_shop() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select to_jsonb(s) || jsonb_build_object('my_role', _shop_role(s.id, auth.uid())) from shops s where s.id = _shop_active_id(auth.uid())), '{}'::jsonb)
$$;

-- 4. Création et modification (identité visuelle comprise) ------------------------------------------------------------------------
-- p : { id? (modifier une boutique précise), create? (true : créer une nouvelle boutique), name, slug, description, logo_url, banner_url, color_primary, color_secondary, ... }
-- Sans id ni create : modifie la boutique active (ou crée la première) comme avant.
create or replace function shop_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); s shops%rowtype; prev shops%rowtype; v_slug text; v_cats text[]; v_exists boolean := false; k text; v text; v_changed boolean := false;
  v_id uuid; v_role text; v_max integer := shops_max_per_owner();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  begin v_id := nullif(coalesce(p->>'id', p->>'shop_id'), '')::uuid; exception when others then raise exception 'Identifiant de boutique invalide'; end;
  if v_id is not null then
    select * into s from shops where id = v_id;
    v_exists := found;
    v_role := case when v_exists then _shop_role(v_id, uid) end;
    if not v_exists or _shop_rank(v_role) < 3 then raise exception 'Boutique introuvable'; end if;
  elsif not coalesce((nullif(p->>'create', ''))::boolean, false) then
    v_id := _shop_default_owned(uid, false);
    if v_id is not null then
      select * into s from shops where id = v_id;
      v_exists := true; v_role := 'owner';
    end if;
  end if;
  if v_exists and s.status in ('suspended', 'closed') then raise exception 'Boutique % : modification impossible', case s.status when 'suspended' then 'suspendue' else 'fermée' end; end if;
  if not v_exists and (select count(*) from shops where owner_id = uid and status <> 'closed') >= v_max then
    raise exception 'Limite atteinte : % boutique(s) au maximum par compte', v_max;
  end if;
  if p ? 'name' and char_length(btrim(coalesce(p->>'name', ''))) > 0
     and exists (select 1 from shops x where lower(x.name) = lower(btrim(p->>'name')) and x.id is distinct from s.id) then
    raise exception 'Ce nom de boutique est déjà pris';
  end if;
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
    insert into shop_active (user_id, shop_id) values (uid, s.id) on conflict (user_id) do update set shop_id = excluded.shop_id, updated_at = now();
  else
    v_slug := s.slug;
    if s.status in ('draft') and v_role = 'owner' and p ? 'slug' and nullif(_slugify(p->>'slug'), '') is not null then
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
  perform _attach_seller_listings(s.owner_id);
  return to_jsonb(s);
end $$;

drop function if exists shop_submit();
create or replace function shop_submit(p_shop uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; v_was text; uid uuid := auth.uid(); v_id uuid;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  v_id := coalesce(p_shop, _shop_default_owned(uid, false));
  select * into s from shops where id = v_id for update;
  if not found then raise exception 'Créez d''abord votre boutique'; end if;
  if s.owner_id <> uid then raise exception 'Boutique introuvable'; end if;
  if s.status not in ('draft', 'closed') then raise exception 'La boutique est déjà % ', case s.status when 'pending' then 'en cours de validation' when 'active' then 'active' else 'suspendue' end; end if;
  if s.status = 'closed' and (select count(*) from shops where owner_id = uid and status <> 'closed') >= shops_max_per_owner() then
    raise exception 'Limite atteinte : % boutique(s) au maximum par compte', shops_max_per_owner();
  end if;
  if s.description is null or s.logo_url is null or cardinality(s.categories) = 0 then raise exception 'Renseignez au moins le logo, la description et une catégorie avant de soumettre'; end if;
  v_was := s.status;
  perform set_config('app.internal', '1', true);
  update shops set status = 'pending', review_note = null where id = s.id returning * into s;
  perform set_config('app.internal', '', true);
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Boutique soumise', s.slug, 'Marketplace', 'Normal');
  perform _notify_shop_validators(s, case when v_was = 'closed' then 'Boutique rouverte à valider' else 'Boutique à valider' end, s.name || ' attend votre validation.');
  perform _attach_seller_listings(uid);
  return 'pending';
end $$;
revoke all on function shop_submit(uuid) from public, anon;
grant execute on function shop_submit(uuid) to authenticated;

drop function if exists shop_close();
create or replace function shop_close(p_shop uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where id = coalesce(p_shop, _shop_default_owned(uid, true)) and owner_id = uid for update;
  if not found or s.status = 'suspended' then raise exception 'Fermeture impossible'; end if;
  perform set_config('app.internal', '1', true);
  update shops set status = 'closed' where id = s.id;
  perform set_config('app.internal', '', true);
  return 'closed';
end $$;
revoke all on function shop_close(uuid) from public, anon;
grant execute on function shop_close(uuid) to authenticated;

-- Désactiver / réactiver UNE boutique (les autres boutiques du propriétaire ne changent pas) : une boutique désactivée disparaît de la vitrine et refuse de nouvelles commandes ;
-- ses commandes en cours se poursuivent. Différent de la pause globale du vendeur (seller_pause). La réactivation exige un vendeur éligible et non en pause.
create or replace function shop_set_enabled(p_shop uuid, p_enabled boolean) returns text
language plpgsql security definer set search_path = public as $$
declare s shops%rowtype; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where id = p_shop and owner_id = uid for update;
  if not found then raise exception 'Boutique introuvable'; end if;
  if coalesce(p_enabled, false) then
    if s.status = 'active' then return 'active'; end if;
    if s.status <> 'paused' then raise exception 'Seule une boutique désactivée peut être réactivée (statut actuel : %)', s.status; end if;
    if seller_paused(uid) then raise exception 'Votre espace vendeur est en pause : reprenez-le d''abord'; end if;
    perform _seller_require(uid, true);
    perform set_config('app.internal', '1', true);
    update shops set status = 'active' where id = s.id;
    perform set_config('app.internal', '', true);
    insert into audit_log (actor, action, target, category, level) values (uid::text, 'Boutique réactivée', s.slug, 'Marketplace', 'Normal');
    return 'active';
  end if;
  if s.status = 'paused' then return 'paused'; end if;
  if s.status <> 'active' then raise exception 'Seule une boutique active peut être désactivée (statut actuel : %)', s.status; end if;
  perform set_config('app.internal', '1', true);
  update shops set status = 'paused' where id = s.id;
  perform set_config('app.internal', '', true);
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Boutique désactivée', s.slug, 'Marketplace', 'Normal');
  return 'paused';
end $$;

-- 5. Équipe de boutique -----------------------------------------------------------------------------------------------------------------
-- Cible : identifiant de profil ou adresse e-mail exacte. Réservé au propriétaire.
create or replace function shop_member_set(p_shop uuid, p_user uuid default null, p_role text default 'viewer', p_email text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s shops%rowtype; v_target uuid := p_user; v_email text := lower(nullif(btrim(coalesce(p_email, '')), '')); t profiles%rowtype;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where id = p_shop;
  if not found or _shop_role(s.id, uid) is null then raise exception 'Boutique introuvable'; end if;
  if s.owner_id <> uid then raise exception 'Réservé au propriétaire de la boutique : seul lui gère les membres'; end if;
  if p_role is null or p_role not in ('manager', 'staff', 'viewer') then raise exception 'Rôle inconnu (manager, staff ou viewer)'; end if;
  if v_target is null and v_email is not null then select id into v_target from profiles where lower(email) = v_email; end if;
  if v_target is null then raise exception 'Utilisateur introuvable'; end if;
  select * into t from profiles where id = v_target;
  if not found then raise exception 'Utilisateur introuvable'; end if;
  if v_target = s.owner_id then raise exception 'Le propriétaire n''est pas un membre'; end if;
  if coalesce(t.suspended, false) then raise exception 'Ce compte est suspendu : ajout impossible'; end if;
  if not exists (select 1 from shop_members where shop_id = s.id and user_id = v_target) and (select count(*) from shop_members where shop_id = s.id) >= 20 then
    raise exception 'Équipe limitée à 20 membres par boutique';
  end if;
  insert into shop_members (shop_id, user_id, role, invited_by) values (s.id, v_target, p_role, uid)
  on conflict (shop_id, user_id) do update set role = excluded.role, updated_at = now();
  perform notify_user(v_target, 'shop', 'Équipe de boutique', 'Vous êtes ' || case p_role when 'manager' then 'gestionnaire' when 'staff' then 'préparateur' else 'lecteur' end || ' de la boutique ' || s.name || '.',
                      jsonb_build_object('shop', s.slug, 'shop_id', s.id));
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Membre de boutique : ' || p_role, s.slug, 'Marketplace', 'Normal');
  return jsonb_build_object('shop_id', s.id, 'user_id', v_target, 'role', p_role, 'name', display_name(v_target));
end $$;

-- Le propriétaire retire un membre ; un membre peut quitter l'équipe (se retirer lui-même).
create or replace function shop_member_remove(p_shop uuid, p_user uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s shops%rowtype; n integer;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into s from shops where id = p_shop;
  if not found or _shop_role(s.id, uid) is null then raise exception 'Boutique introuvable'; end if;
  if s.owner_id <> uid and p_user is distinct from uid then raise exception 'Réservé au propriétaire de la boutique : seul lui retire un membre'; end if;
  delete from shop_members where shop_id = s.id and user_id = p_user;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'Membre introuvable'; end if;
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Membre de boutique retiré', s.slug, 'Marketplace', 'Normal');
  return true;
end $$;

create or replace function shop_members_list(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if _shop_role(p_shop, uid) is distinct from 'owner' then raise exception 'Boutique introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'name', display_name(m.user_id), 'role', m.role, 'since', m.created_at) order by m.created_at, m.user_id)
                   from shop_members m where m.shop_id = p_shop), '[]'::jsonb);
end $$;

revoke all on function shop_set_active(uuid), shop_save(jsonb), shop_set_enabled(uuid, boolean), shop_member_set(uuid, uuid, text, text), shop_member_remove(uuid, uuid), shop_members_list(uuid), my_shop() from public, anon;
grant execute on function shop_set_active(uuid), shop_save(jsonb), shop_set_enabled(uuid, boolean), shop_member_set(uuid, uuid, text, text), shop_member_remove(uuid, uuid), shop_members_list(uuid), my_shop() to authenticated;

-- Retour arrière : drop function shop_set_active(uuid), shop_set_enabled(uuid, boolean), shop_member_set(uuid, uuid, text, text), shop_member_remove(uuid, uuid), shop_members_list(uuid), _shop_scope(uuid, text),
--   _shop_manage(uuid, boolean), _shop_active_id(uuid), _shop_default_owned(uuid, boolean), _my_shop_role(uuid), _shop_role(uuid, uuid), _shop_rank(text), shops_max_per_owner() ;
--   recréer shop_save, shop_submit(), shop_close(), my_shop(), _my_shop_id(boolean) depuis 20261117030200, 20261107000000 ; recréer la politique « boutiques : actives, propriétaire, équipe » depuis 20261120020400 ;
--   drop table shop_members, shop_active ; delete from platform_settings where key = 'shops.max_per_owner' ;
--   remise de la contrainte d'unicité : possible seulement si aucun propriétaire n'a plus d'une boutique (alter table shops add constraint shops_owner_id_key unique (owner_id)).
