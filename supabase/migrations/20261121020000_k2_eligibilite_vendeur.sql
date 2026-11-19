-- Lot K2 (éligibilité vendeur côté SERVEUR) : la capacité de vendre n'est plus seulement lue par l'application, elle est imposée par la base.
--   Capacité vendeur = rôle étudiant + étudiant VÉRIFIÉ (is_verified_student : pièce validée ou certification) + téléphone vérifié (phone_verified) + compte non suspendu.
--   Aucune condition commerciale (CGV) n'est imposée par le serveur : my_seller_capability (20261120050000) n'en listait aucune, l'acceptation des CGV reste une démarche de l'écran.
--   1. seller_capable(uuid) : fonction UNIQUE (stable, security definer, interne) réutilisée par my_seller_capability et par toutes les gardes ci-dessous.
--      seller_open(uuid) = seller_capable ET boutique non mise en pause (peut publier et recevoir de NOUVELLES commandes).
--   2. Gardes (déclencheurs, donc valables pour les RPC ET pour les écritures directes) :
--        annonces (création, modification, publication, validation par un valideur), boutique (création, modification, soumission), promotions / ventes flash / packs / campagnes de boutique,
--        zones de livraison et réglages vendeur, réponse à une demande de devis par le prestataire, nouvelle demande de devis adressée à un prestataire non éligible,
--        NOUVELLE ligne de commande sur l'annonce d'un vendeur non éligible ou en pause (marketplace_checkout et quote_checkout), retraits (_payout_blocker).
--      Décision pour l'existant : un vendeur devenu non éligible ne peut plus publier ni recevoir de nouvelles commandes, mais CONSERVE l'accès à ses commandes déjà engagées
--      (set_seller_order_status, seller_confirm_handover : seulement refusés aux comptes qui ne sont plus des étudiants ou qui sont suspendus), peut retirer ses annonces, fermer ou mettre en pause sa boutique,
--      désactiver ses promotions, décliner un devis, annuler une demande de retrait et lire ses relevés ; les retraits déjà demandés ou acceptés restent traités par la finance.
--      Une NOUVELLE demande de retrait exige la capacité complète (numéro vérifié, étudiant vérifié) : l'argent acquis reste sur le solde, il se retire dès que la capacité est rétablie.
--      Les administrateurs et responsables de département ne vendent pas : leurs produits de plateforme n'ont pas de vendeur (seller_id nul) et ne sont pas concernés ; créer une annonce à leur nom est désormais refusé.
--   3. Pause : seller_pause(text) / seller_resume(). La pause masque les annonces publiées (brouillon masqué, rétablies telles quelles à la reprise, sans nouvelle validation),
--      met la boutique en statut « paused », refuse toute nouvelle commande et toute nouvelle publication ; les commandes en cours se poursuivent. La reprise exige la capacité complète.
-- Additive et rejouable. Retour arrière :
--   drop trigger trg_zz_k2_seller_listing on listings ; trg_zz_k2_seller_shop on shops ; trg_zz_k2_seller_asset on promo_codes, flash_sales, shop_packs, shop_campaigns ;
--   trg_zz_k2_seller_owner on delivery_zones, seller_settings ; trg_zz_k2_quote_provider on quote_requests ; trg_k2_order_line_seller on order_lines ; trg_k2_order_line_fulfil on order_lines ;
--   drop function k2_listing_seller_guard(), k2_shop_seller_guard(), k2_shop_asset_guard(), k2_owner_guard(), k2_quote_provider_guard(), k2_order_line_seller_guard(), k2_order_line_fulfil_guard(),
--     seller_pause(text), seller_resume(), seller_open(uuid), seller_paused(uuid), _seller_block_reason(uuid, boolean), _seller_require(uuid, boolean) ;
--   rendre les annonces/boutiques de k2_pause_holds (annonces 'draft' « Boutique en pause », boutiques 'paused') à 'approved' / 'active' puis drop table k2_pause_holds, seller_pauses ;
--   recréer _payout_blocker (20261119040200), _seller_capability et my_seller_capability (20261120050000) ; remettre la contrainte shops_status_check d'origine.

-- ============================================================ 1. Pause : états
create table if not exists seller_pauses (
  user_id uuid primary key references profiles(id) on delete cascade,
  reason text check (reason is null or char_length(reason) <= 200),
  paused_at timestamptz not null default now()
);
alter table seller_pauses enable row level security;
revoke all on seller_pauses from anon, authenticated;

create table if not exists k2_pause_holds (
  kind text not null check (kind in ('listing', 'shop')),
  ref uuid not null,
  owner_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (kind, ref)
);
alter table k2_pause_holds enable row level security;
revoke all on k2_pause_holds from anon, authenticated;

do $$ begin
  alter table shops drop constraint if exists shops_status_check;
  alter table shops add constraint shops_status_check check (status in ('draft', 'pending', 'active', 'suspended', 'closed', 'paused'));
exception when others then raise notice 'shops_status_check non modifiée : %', sqlerrm;
end $$;

-- ============================================================ 2. La règle unique
create or replace function seller_capable(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select p.role::text = 'student' and not coalesce(p.suspended, false) and coalesce(p.phone_verified, false) and is_verified_student(p.id)
    from profiles p where p.id = p_user), false)
$$;
revoke all on function seller_capable(uuid) from public, anon, authenticated;

create or replace function seller_paused(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from seller_pauses where user_id = p_user)
$$;
revoke all on function seller_paused(uuid) from public, anon, authenticated;

create or replace function seller_open(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select seller_capable(p_user) and not seller_paused(p_user)
$$;
revoke all on function seller_open(uuid) from public, anon, authenticated;

-- Ce qui empêche ce compte de vendre (null si rien) ; p_open ajoute « boutique non mise en pause ».
create or replace function _seller_block_reason(p_user uuid, p_open boolean default false) returns text
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  select * into p from profiles where id = p_user;
  if not found then return 'Compte introuvable'; end if;
  if coalesce(p.suspended, false) then return 'Compte suspendu : la vente est impossible jusqu''à la levée de la suspension'; end if;
  if p.role::text <> 'student' then return 'Réservé aux étudiants-vendeurs : ce compte ne peut pas vendre'; end if;
  if not is_verified_student(p.id) then return 'Votre statut d''étudiant n''est pas vérifié : faites valider votre carte d''étudiant ou votre certification avant de vendre'; end if;
  if not coalesce(p.phone_verified, false) then return 'Vérifiez d''abord votre numéro de téléphone (Paramètres > Informations personnelles) : la vente exige un téléphone vérifié'; end if;
  if p_open and seller_paused(p_user) then return 'Votre boutique est en pause : reprenez-la pour publier ou recevoir de nouvelles commandes'; end if;
  return null;
end $$;
revoke all on function _seller_block_reason(uuid, boolean) from public, anon, authenticated;

create or replace function _seller_require(p_user uuid, p_open boolean default false) returns void
language plpgsql stable security definer set search_path = public as $$
declare v text := _seller_block_reason(p_user, p_open);
begin
  if v is not null then raise exception '%', v; end if;
end $$;
revoke all on function _seller_require(uuid, boolean) from public, anon, authenticated;

-- ============================================================ 3. my_seller_capability s'appuie sur seller_capable
create or replace function _seller_capability(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype; c_role boolean; c_verified boolean; c_phone boolean; c_active boolean; v_missing jsonb := '[]'::jsonb; v_can boolean; v_paused boolean;
begin
  select * into p from profiles where id = p_user;
  if p.id is null then
    return jsonb_build_object('can_sell', false, 'role', null, 'can_publish', false, 'paused', false, 'can_receive_orders', false, 'missing', jsonb_build_array('profile'),
      'conditions', jsonb_build_array(jsonb_build_object('key', 'profile', 'label', 'Profil complété', 'ok', false)));
  end if;
  c_role := p.role::text = 'student';
  c_active := not coalesce(p.suspended, false);
  c_verified := c_role and is_verified_student(p.id);
  c_phone := coalesce(p.phone_verified, false);
  v_can := seller_capable(p.id);
  v_paused := seller_paused(p.id);
  if not c_role then v_missing := v_missing || '"student"'::jsonb; end if;
  if not c_verified then v_missing := v_missing || '"student_verified"'::jsonb; end if;
  if not c_phone then v_missing := v_missing || '"phone_verified"'::jsonb; end if;
  if not c_active then v_missing := v_missing || '"not_suspended"'::jsonb; end if;
  return jsonb_build_object(
    'can_sell', v_can,
    'role', p.role::text,
    'can_publish', p.certification::text = 'approved' and c_active,
    'paused', v_paused,
    'can_receive_orders', v_can and not v_paused,
    'missing', v_missing,
    'conditions', jsonb_build_array(
      jsonb_build_object('key', 'student', 'label', 'Compte étudiant', 'ok', c_role),
      jsonb_build_object('key', 'student_verified', 'label', 'Statut d''étudiant vérifié (pièce validée ou compte certifié)', 'ok', c_verified),
      jsonb_build_object('key', 'phone_verified', 'label', 'Numéro de téléphone vérifié par un code', 'ok', c_phone),
      jsonb_build_object('key', 'not_suspended', 'label', 'Compte non suspendu', 'ok', c_active)));
end $$;
revoke all on function _seller_capability(uuid) from public, anon, authenticated;

create or replace function my_seller_capability() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return _seller_capability(auth.uid());
end $$;
revoke all on function my_seller_capability() from public, anon;
grant execute on function my_seller_capability() to authenticated;

-- ============================================================ 4. Annonces
create or replace function k2_listing_seller_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return new; end if;                                  -- éditeur SQL / tâches planifiées
  if new.seller_id is null then return new; end if;                        -- produit de la plateforme
  if new.seller_id is distinct from uid then
    -- un valideur ne publie pas l'annonce d'un vendeur qui ne peut plus vendre (les rétablissements internes, ex. levée de suspension, ne sont pas des validations)
    if tg_op = 'UPDATE' and new.status = 'approved' and old.status is distinct from 'approved' and coalesce(current_setting('app.internal', true), '') <> '1' then
      if seller_paused(new.seller_id) then raise exception 'Le vendeur a mis sa boutique en pause : validation impossible'; end if;
      if not seller_capable(new.seller_id) then raise exception 'Le vendeur n''est plus éligible à la vente : validation impossible'; end if;
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' and new.status in ('draft', 'removed') then return new; end if;   -- retirer ou masquer sa propre annonce reste toujours possible
  perform _seller_require(uid, new.status in ('pending', 'approved'));
  return new;
end $$;
revoke all on function k2_listing_seller_guard() from public, anon, authenticated;
drop trigger if exists trg_zz_k2_seller_listing on listings;
create trigger trg_zz_k2_seller_listing before insert or update on listings for each row execute function k2_listing_seller_guard();

-- ============================================================ 5. Boutique et ce qui en dépend
create or replace function k2_shop_seller_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return new; end if;
  if new.owner_id is distinct from uid then
    -- un valideur n'ouvre pas la boutique d'un vendeur qui ne peut plus vendre ou qui l'a mise en pause
    if tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'active' then
      if seller_paused(new.owner_id) then raise exception 'Le vendeur a mis sa boutique en pause : validation impossible'; end if;
      if not seller_capable(new.owner_id) then raise exception 'Le vendeur n''est plus éligible à la vente : validation impossible'; end if;
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' and new.status in ('closed', 'paused') and new.status is distinct from old.status then return new; end if;   -- fermer ou mettre en pause
  perform _seller_require(uid, new.status in ('pending', 'active'));
  return new;
end $$;
revoke all on function k2_shop_seller_guard() from public, anon, authenticated;
drop trigger if exists trg_zz_k2_seller_shop on shops;
create trigger trg_zz_k2_seller_shop before insert or update on shops for each row execute function k2_shop_seller_guard();

-- Promotions, ventes flash, packs, campagnes : tout ce qui est rattaché à la boutique d'un vendeur ; la désactivation reste libre.
create or replace function k2_shop_asset_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_owner uuid; j jsonb := to_jsonb(new);
begin
  if uid is null or coalesce(j->>'shop_id', '') = '' then return new; end if;
  select owner_id into v_owner from shops where id = (j->>'shop_id')::uuid;
  if v_owner is distinct from uid then return new; end if;
  if tg_op = 'UPDATE' and (j->>'active' = 'false' or j->>'cancelled' = 'true') then return new; end if;
  perform _seller_require(uid, true);
  return new;
end $$;
revoke all on function k2_shop_asset_guard() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['promo_codes', 'flash_sales', 'shop_packs', 'shop_campaigns'] loop
    execute format('drop trigger if exists trg_zz_k2_seller_asset on %I', t);
    execute format('create trigger trg_zz_k2_seller_asset before insert or update on %I for each row execute function k2_shop_asset_guard()', t);
  end loop;
end $$;

-- Zones de livraison et réglages du vendeur (colonne propriétaire passée en argument).
create or replace function k2_owner_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_owner text := to_jsonb(new)->>tg_argv[0];
begin
  if uid is null or v_owner is null or v_owner <> uid::text then return new; end if;
  if tg_op = 'UPDATE' and to_jsonb(new)->>'active' = 'false' then return new; end if;
  perform _seller_require(uid, false);
  return new;
end $$;
revoke all on function k2_owner_guard() from public, anon, authenticated;
drop trigger if exists trg_zz_k2_seller_owner on delivery_zones;
create trigger trg_zz_k2_seller_owner before insert or update on delivery_zones for each row execute function k2_owner_guard('seller_id');
drop trigger if exists trg_zz_k2_seller_owner on seller_settings;
create trigger trg_zz_k2_seller_owner before insert or update on seller_settings for each row execute function k2_owner_guard('user_id');

-- ============================================================ 6. Devis côté prestataire
create or replace function k2_quote_provider_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return new; end if;
  if tg_op = 'INSERT' then
    if new.provider_id is distinct from uid and not seller_open(new.provider_id) then
      raise exception 'Ce prestataire n''accepte plus de demandes de devis pour le moment';
    end if;
  elsif uid = old.provider_id and new.status = 'quoted' then
    perform _seller_require(uid, true);                                     -- envoyer ou réviser un devis ; décliner reste possible
  end if;
  return new;
end $$;
revoke all on function k2_quote_provider_guard() from public, anon, authenticated;
drop trigger if exists trg_zz_k2_quote_provider on quote_requests;
create trigger trg_zz_k2_quote_provider before insert or update on quote_requests for each row execute function k2_quote_provider_guard();

-- ============================================================ 7. Commandes
-- Nouvelle ligne de commande : le vendeur doit pouvoir vendre et ne pas être en pause (les commandes déjà créées ne sont jamais touchées).
create or replace function k2_order_line_seller_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_seller uuid; v_title text;
begin
  select seller_id, title into v_seller, v_title from listings where id = new.listing_id;
  if v_seller is null then return new; end if;                              -- produit de la plateforme
  if not seller_open(v_seller) then raise exception 'Vendeur indisponible : % ne peut plus recevoir de commandes pour le moment', coalesce(v_title, 'cette annonce'); end if;
  return new;
end $$;
revoke all on function k2_order_line_seller_guard() from public, anon, authenticated;
drop trigger if exists trg_k2_order_line_seller on order_lines;
create trigger trg_k2_order_line_seller before insert on order_lines for each row execute function k2_order_line_seller_guard();

-- Avancement / remise par le vendeur : réservé à un compte étudiant non suspendu (une commande déjà engagée se termine même sans éligibilité complète).
create or replace function k2_order_line_fulfil_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_seller uuid;
begin
  if uid is null or new.fulfillment is not distinct from old.fulfillment then return new; end if;
  select seller_id into v_seller from listings where id = new.listing_id;
  if v_seller is distinct from uid then return new; end if;
  if not exists (select 1 from profiles p where p.id = uid and p.role::text = 'student' and not coalesce(p.suspended, false)) then
    raise exception 'Réservé aux étudiants-vendeurs : ce compte ne peut pas traiter cette commande';
  end if;
  return new;
end $$;
revoke all on function k2_order_line_fulfil_guard() from public, anon, authenticated;
drop trigger if exists trg_k2_order_line_fulfil on order_lines;
create trigger trg_k2_order_line_fulfil before update of fulfillment on order_lines for each row execute function k2_order_line_fulfil_guard();

-- ============================================================ 8. Retraits : même règle que la vente
create or replace function _payout_blocker(p_user uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  select * into p from profiles where id = p_user;
  if not found then return 'Compte introuvable'; end if;
  if coalesce(p.suspended, false) then return 'Compte suspendu : les retraits sont gelés jusqu''à la levée de la suspension'; end if;
  if p.role::text <> 'student' then return 'Les retraits sont réservés aux comptes étudiants-vendeurs'; end if;
  if not coalesce(p.phone_verified, false) then return 'Vérifiez d''abord votre numéro de téléphone (Paramètres > Informations personnelles) : un retrait exige un téléphone vérifié'; end if;
  if not seller_capable(p_user) then return 'Votre statut d''étudiant n''est pas vérifié : faites valider votre carte d''étudiant ou votre certification avant de retirer de l''argent'; end if;
  return null;
end $$;
revoke all on function _payout_blocker(uuid) from public, anon, authenticated;

-- ============================================================ 9. Pause / reprise de la boutique
create or replace function seller_pause(p_reason text default null) returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_prev text := coalesce(current_setting('app.internal', true), ''); n integer := 0;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles p where p.id = uid and p.role::text = 'student' and not coalesce(p.suspended, false)) then
    raise exception 'Réservé aux étudiants-vendeurs : ce compte ne peut pas mettre de boutique en pause';
  end if;
  if seller_paused(uid) then return 'already_paused'; end if;
  insert into seller_pauses (user_id, reason) values (uid, nullif(left(btrim(coalesce(p_reason, '')), 200), ''));
  perform set_config('app.internal', '1', true);
  insert into k2_pause_holds (kind, ref, owner_id) select 'listing', id, uid from listings where seller_id = uid and status = 'approved' on conflict do nothing;
  update listings set status = 'draft', review_note = 'Boutique en pause : annonce masquée.' where seller_id = uid and status = 'approved';
  get diagnostics n = row_count;
  insert into k2_pause_holds (kind, ref, owner_id) select 'shop', id, uid from shops where owner_id = uid and status = 'active' on conflict do nothing;
  update shops set status = 'paused' where owner_id = uid and status = 'active';
  perform set_config('app.internal', v_prev, true);
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Boutique mise en pause', n || ' annonce(s) masquée(s)', 'Marketplace', 'Normal');
  return 'paused';
end $$;

create or replace function seller_resume() returns text
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_prev text := coalesce(current_setting('app.internal', true), ''); n integer := 0;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not seller_paused(uid) then return 'not_paused'; end if;
  perform _seller_require(uid, false);
  delete from seller_pauses where user_id = uid;
  perform set_config('app.internal', '1', true);
  update listings set status = 'approved', review_note = null
    where seller_id = uid and status = 'draft' and id in (select ref from k2_pause_holds where kind = 'listing' and owner_id = uid);
  get diagnostics n = row_count;
  update shops set status = 'active' where owner_id = uid and status = 'paused' and id in (select ref from k2_pause_holds where kind = 'shop' and owner_id = uid);
  delete from k2_pause_holds where owner_id = uid;
  perform set_config('app.internal', v_prev, true);
  insert into audit_log (actor, action, target, category, level) values (uid::text, 'Boutique reprise', n || ' annonce(s) rétablie(s)', 'Marketplace', 'Normal');
  return 'resumed';
end $$;

revoke all on function seller_pause(text), seller_resume() from public, anon;
grant execute on function seller_pause(text), seller_resume() to authenticated;
