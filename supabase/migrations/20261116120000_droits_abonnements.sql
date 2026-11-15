-- Droits des abonnements (table plans) : chaque droit annoncé a désormais un effet réel côté serveur, ou il est retiré de la promesse du plan.
--   · stats_avancees   : RÉEL. seller_advanced_stats(p_days) (30 ou 90 jours) : par produit, vues, favoris, ventes, commandes et conversion ; réservé au titulaire du droit.
--   · portfolio_enrichi: RÉEL. portfolio_save : 100 éléments au plus sans le droit, 300 avec le droit (la limite de 100 existait déjà ; aucun compte n'est restreint).
--   · gestion_equipe   : RÉEL. company_invite exige le droit (abonnement « Entreprise ») ou un forfait d'entreprise payant ; les membres existants gardent leur accès.
--   · boost_campagnes  : déjà réel (20261115210000).
--   · visiteurs_profil : RETIRÉ de createur_pro : aucune vue nominative de profil n'est enregistrée (seules existent des vues agrégées de boutiques et de fiches produit).
--   · outils_vendeur_pro : RETIRÉ de vendeur_pro : codes promo, ventes flash, packs et campagnes de boutique sont déjà ouverts à toute boutique active, sans limite à relever.
--   · gestion_communaute : RETIRÉ de admin_communaute : la gestion de communauté (membres, événements, fichiers) est déjà ouverte à son responsable, sans limite à relever.
--   · stats_avancees retiré de entreprise : les statistiques avancées portent sur les produits d'un vendeur ; les entreprises ont déjà leurs statistiques d'offres.
-- Offres : createur_pro devient vendable (son droit a un effet réel) ; admin_communaute, sans aucun droit réel, reste non vendable.
-- Les comptes de test (profiles.is_test) gardent leurs accès. Les abonnés en cours dont l'offre perd un droit sont prévenus par notification.
-- Ne touche ni subscription_start, ni on_subscription_paid, ni payment_*, ni marketplace_checkout : le plan ne s'active toujours que par paiement confirmé.
-- Retour arrière : voir la fin du fichier.

-- ============================================================ 1. droit effectif d'un compte (usage interne)
create or replace function feature_granted(p_user uuid, p_feature text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_user is not null and (
    exists (select 1 from profiles where id = p_user and is_test)
    or exists (select 1 from subscriptions s join plans p on p.code = s.plan_code
               where s.user_id = p_user and s.status in ('active', 'cancel_at_period_end') and s.current_period_end > now() and p_feature = any(p.features)))
$$;
revoke all on function feature_granted(uuid, text) from public, anon, authenticated;

-- ============================================================ 2. promesses des plans : retrait des droits sans effet, abonnés prévenus
do $$
declare r record;
begin
  for r in
    select distinct s.user_id, p.name, array(select f from unnest(p.features) f where f = any(d.retires)) as perdus
    from subscriptions s join plans p on p.code = s.plan_code
    join (values ('createur_pro', '{stats_avancees,visiteurs_profil}'::text[]), ('vendeur_pro', '{outils_vendeur_pro}'::text[]),
                 ('entreprise', '{stats_avancees}'::text[]), ('admin_communaute', '{gestion_communaute,stats_avancees}'::text[])) d(plan_code, retires) on d.plan_code = p.code
    where s.status in ('active', 'cancel_at_period_end') and s.current_period_end > now() and p.features && d.retires
  loop
    perform notify_user(r.user_id, 'subscription', 'Votre offre évolue',
      'L''offre « ' || r.name || ' » ne comporte plus : ' || array_to_string(array(select case f
          when 'stats_avancees' then 'statistiques avancées' when 'visiteurs_profil' then 'visiteurs du profil'
          when 'outils_vendeur_pro' then 'outils vendeur professionnel' when 'gestion_communaute' then 'gestion de communauté' else f end from unnest(r.perdus) f), ', ')
      || ' (fonction qui n''existait pas). Contactez le support si vous aviez souscrit pour ce droit.', jsonb_build_object('plan', r.name));
  end loop;
  update plans p set features = array(select f from unnest(p.features) f where f <> all(d.retires)), updated_at = now()
    from (values ('createur_pro', '{stats_avancees,visiteurs_profil}'::text[]), ('vendeur_pro', '{outils_vendeur_pro}'::text[]),
                 ('entreprise', '{stats_avancees}'::text[]), ('admin_communaute', '{gestion_communaute,stats_avancees}'::text[])) d(plan_code, retires)
    where d.plan_code = p.code and p.features && d.retires;
end $$;

update plans set sellable = true where code = 'createur_pro';
update plans set sellable = false where code = 'admin_communaute';

-- ============================================================ 3. stats_avancees : statistiques détaillées par produit
create or replace function seller_advanced_stats(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_days integer := coalesce(p_days, 30); v_start date; v_plans text;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if v_days not in (30, 90) then raise exception 'Période : 30 ou 90 jours'; end if;
  if not feature_granted(uid, 'stats_avancees') then
    select string_agg(name, ' ou ' order by name) into v_plans from plans where 'stats_avancees' = any(features) and active and sellable;
    raise exception 'Réservé au forfait %', coalesce(v_plans, 'Vendeur professionnel');
  end if;
  v_start := current_date - (v_days - 1);
  return jsonb_build_object(
    'days', v_days,
    'since', v_start,
    'products', coalesce((select jsonb_agg(x order by (x->>'revenue')::bigint desc, (x->>'views')::bigint desc, x->>'title') from (
      select jsonb_build_object('id', l.id, 'title', l.title, 'status', l.status,
        'views', coalesce(v.n, 0), 'favorites', coalesce(f.n, 0), 'units', coalesce(s.units, 0), 'orders', coalesce(s.orders, 0), 'revenue', coalesce(s.revenue, 0),
        'conversion', case when coalesce(v.n, 0) > 0 then least(100, round(coalesce(s.orders, 0) * 100.0 / v.n, 1)) else null end) x
      from listings l
      left join lateral (select sum(lv.views)::bigint n from listing_views lv where lv.listing_id = l.id and lv.day >= v_start) v on true
      left join lateral (select count(*)::bigint n from favorites fv where fv.listing_id = l.id and fv.created_at >= v_start) f on true
      left join lateral (select sum(ol.qty)::bigint units, count(distinct o.id)::bigint orders, sum(ol.unit_price::bigint * ol.qty)::bigint revenue
                         from order_lines ol join orders o on o.id = ol.order_id
                         where ol.listing_id = l.id and o.paid and o.cancelled_at is null and o.created_at >= v_start) s on true
      where l.seller_id = uid
      order by coalesce(s.revenue, 0) desc, coalesce(v.n, 0) desc, l.title
      limit 200) q), '[]'::jsonb),
    'series', coalesce((select jsonb_agg(jsonb_build_object('day', d::date,
        'views', coalesce((select sum(lv.views) from listing_views lv join listings l on l.id = lv.listing_id where l.seller_id = uid and lv.day = d::date), 0)::int,
        'units', coalesce((select sum(ol.qty) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
                           where l.seller_id = uid and o.paid and o.cancelled_at is null and o.created_at::date = d::date), 0)::int) order by d)
      from generate_series(v_start, current_date, interval '1 day') d), '[]'::jsonb));
end $$;

revoke all on function seller_advanced_stats(integer) from public, anon;
grant execute on function seller_advanced_stats(integer) to authenticated;

-- ============================================================ 4. portfolio_enrichi : 100 éléments au plus, 300 avec le droit
create or replace function portfolio_save(p_id uuid, p_kind text, p_title text, p_description text, p_category text, p_date text, p_url text, p_media_path text, p_featured boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; u text := trim(coalesce(p_url, '')); v_limit integer; v_plans text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('realisation', 'image', 'video', 'link') then raise exception 'Type invalide'; end if;
  if char_length(trim(coalesce(p_title, ''))) < 2 then raise exception 'Donnez un titre (2 caractères minimum)'; end if;
  if u <> '' and u !~* '^https?://[^ ]+$' then raise exception 'Le lien doit commencer par http:// ou https://'; end if;
  if p_kind = 'link' and u = '' then raise exception 'Saisissez le lien'; end if;
  if p_kind in ('image', 'video') and p_media_path is null and u = '' and p_id is null then raise exception 'Ajoutez un fichier ou un lien'; end if;
  if p_media_path is not null and (storage.foldername(p_media_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  if coalesce(p_featured, false) then update portfolio_items set featured = false where owner_id = auth.uid() and featured and id is distinct from p_id; end if;
  if p_id is null then
    v_limit := case when feature_granted(auth.uid(), 'portfolio_enrichi') then 300 else 100 end;
    if (select count(*) from portfolio_items where owner_id = auth.uid()) >= v_limit then
      select string_agg(name, ' ou ' order by name) into v_plans from plans where 'portfolio_enrichi' = any(features) and active and sellable and price_xaf > 0;
      raise exception 'Limite de % éléments atteinte%', v_limit, case when v_limit = 100 and v_plans is not null then ' (300 avec l''offre ' || v_plans || ')' else '' end;
    end if;
    insert into portfolio_items (owner_id, kind, title, description, category, happened_on, url, media_path, featured)
    values (auth.uid(), p_kind, trim(p_title), left(trim(coalesce(p_description, '')), 2000), left(trim(coalesce(p_category, '')), 80), left(trim(coalesce(p_date, '')), 40), u, p_media_path, coalesce(p_featured, false)) returning id into v;
  else
    update portfolio_items set kind = p_kind, title = trim(p_title), description = left(trim(coalesce(p_description, '')), 2000), category = left(trim(coalesce(p_category, '')), 80),
      happened_on = left(trim(coalesce(p_date, '')), 40), url = u, media_path = coalesce(p_media_path, media_path), featured = coalesce(p_featured, false)
    where id = p_id and owner_id = auth.uid() returning id into v;
    if v is null then raise exception 'Élément introuvable'; end if;
  end if;
  return v;
end $$;
revoke all on function portfolio_save(uuid, text, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function portfolio_save(uuid, text, text, text, text, text, text, text, boolean) to authenticated;

-- ============================================================ 5. gestion_equipe : inviter des collègues exige le droit (ou un forfait d'entreprise payant)
-- Le droit s'apprécie sur le propriétaire de l'entreprise (un administrateur membre invite au nom de l'entreprise). Les membres déjà invités ou actifs restent en place.
create or replace function company_team_allowed(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select feature_granted(p_owner, 'gestion_equipe') or coalesce((select (company_current_plan(p_owner)).price_fcfa > 0), false)
$$;
revoke all on function company_team_allowed(uuid) from public, anon, authenticated;

create or replace function company_team_access(p_owner uuid default null) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner);
begin
  return company_team_allowed(v_owner);
end $$;
revoke all on function company_team_access(uuid) from public, anon;
grant execute on function company_team_access(uuid) to authenticated;

create or replace function company_invite(p_email text, p_role text default 'viewer', p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_target uuid; v_name text; v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if company_role_of(v_owner) not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if not company_team_allowed(v_owner) then
    raise exception 'L''invitation de collègues fait partie de l''offre Entreprise (ou d''un forfait d''entreprise payant). Les membres déjà dans l''équipe gardent leur accès.';
  end if;
  if p_role not in ('admin', 'finance', 'viewer') then raise exception 'Rôle inconnu'; end if;
  if v_email = '' or v_email !~ '^[^@ ]+@[^@ ]+$' then raise exception 'Saisissez l''e-mail de la personne'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if (select count(*) from company_members where owner_id = v_owner) >= 10 then raise exception 'Dix membres au plus'; end if;
  select id into v_target from profiles where lower(email) = v_email and not suspended;
  -- compte inconnu, propriétaire ou membre déjà actif : même réponse, sans invitation ni notification
  if v_target is null or v_target = v_owner or exists (select 1 from company_members where owner_id = v_owner and user_id = v_target and status = 'active') then
    return 'invited';
  end if;
  insert into company_members (owner_id, user_id, role, status, invited_by) values (v_owner, v_target, p_role, 'invited', auth.uid())
  on conflict (owner_id, user_id) do update set role = excluded.role, status = 'invited', invited_by = auth.uid(), invited_at = now();
  select company_name into v_name from company_profiles where owner_id = v_owner;
  insert into notifications (user_id, kind, title, body, data)
    values (v_target, 'company_team', 'Invitation à rejoindre une entreprise', display_name(auth.uid()) || ' vous invite à rejoindre l''équipe de « ' || v_name || ' ».', jsonb_build_object('owner', v_owner));
  return 'invited';
end $$;
revoke all on function company_invite(text, text, uuid) from public, anon;
grant execute on function company_invite(text, text, uuid) to authenticated;

-- RETOUR ARRIÈRE : drop function seller_advanced_stats(integer), company_team_access(uuid), company_team_allowed(uuid), feature_granted(uuid, text) ;
--   recréer company_invite(text, text, uuid) depuis 20261115210000 et portfolio_save(...) depuis 20261110010000 ;
--   remettre les droits : update plans set features = '{stats_avancees,portfolio_enrichi,visiteurs_profil}' where code = 'createur_pro' ; features = '{stats_avancees,outils_vendeur_pro,boost_campagnes}' where code = 'vendeur_pro' ;
--   features = '{stats_avancees,boost_campagnes,gestion_equipe}' where code = 'entreprise' ; features = '{gestion_communaute,stats_avancees}' where code = 'admin_communaute' ;
--   update plans set sellable = false where code in ('createur_pro', 'admin_communaute').
