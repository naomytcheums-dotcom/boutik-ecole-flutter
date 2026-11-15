-- Lot L11 (profil Client) : missions, offres premium, campagnes sponsorisées, invitations d'équipe.
--   · company_invite : même réponse que le compte existe ou non (plus de fuite d'existence d'un compte) ;
--   · save_mission : plafond de 5 publications par 24 h (hors équipe et comptes de test), le département est prévenu à la publication ;
--   · mission_cancel : le client retire un besoin non attribué, les proposants sont prévenus ; my_needs : besoins, propositions (avec auteur) et jalons du client ;
--   · propose_on_mission : trois propositions au plus par talent et par besoin (redépôt après refus limité) ;
--   · plans : audience par rôle et indicateur « vendable » ; subscription_start refuse l'audience non concernée et les offres sans contenu réel,
--     relance possible après un paiement échoué ou annulé ; subscription_cancel(p_plan) ; expire_subscriptions() (à planifier) ; my_entitlements expose le paiement ;
--   · campagnes : droit boost_campagnes exigé côté serveur, erreurs de saisie lisibles, ad_campaign_cancel (annulation avant diffusion).
-- Retour arrière : voir la fin du fichier.

-- ============================================================ 1. invitations d'équipe : réponse identique que le compte existe ou non
create or replace function company_invite(p_email text, p_role text default 'viewer', p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_target uuid; v_name text; v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if company_role_of(v_owner) not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
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

-- ============================================================ 2. missions
alter table mission_proposals add column if not exists attempts smallint not null default 1;

-- Enregistre un besoin (brouillon ou publication). Seul le propriétaire modifie, et seulement avant attribution.
-- Publication : au plus 5 par 24 h pour un compte hors équipe ; le département et l'administration sont prévenus.
create or replace function save_mission(p_id uuid, p_title text, p_description text, p_budget_min integer, p_budget_max integer, p_deadline text, p_publish boolean, p_kind text default 'besoin') returns uuid
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid uuid; st text; v_role text := coalesce(current_role_name()::text, ''); r record; v_new boolean := false;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_publish then perform company_gate('need', p_id); end if;
  if v_role not in ('client', 'company', 'other', 'student', 'dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if p_publish and (p_description is null or char_length(trim(p_description)) < 20) then raise exception 'Décrivez le besoin en 20 caractères minimum'; end if;
  if char_length(coalesce(p_description, '')) > 4000 then raise exception 'Description trop longue'; end if;
  if p_budget_min is not null and p_budget_min < 0 or p_budget_max is not null and p_budget_max < coalesce(p_budget_min, 0) then raise exception 'Budget invalide'; end if;
  if p_kind not in ('besoin', 'mission') then raise exception 'Type inconnu'; end if;
  st := case when p_publish then 'published' else 'draft' end;
  if p_publish and v_role not in ('dept', 'admin') and not exists (select 1 from profiles where id = auth.uid() and is_test) then
    if (select count(*) from missions where client_id = auth.uid() and status <> 'draft' and created_at > now() - interval '24 hours' and id is distinct from p_id) >= 5 then
      raise exception 'Limite atteinte : 5 besoins publiés par jour. Retirez un besoin ou réessayez demain.';
    end if;
  end if;
  if p_id is null then
    insert into missions (number, client_id, kind, title, description, total, status, budget_min, budget_max, deadline)
    values ('#BR-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 1000000))::text, 6, '0'), auth.uid(), p_kind, trim(p_title),
            coalesce(trim(p_description), ''), coalesce(p_budget_max, p_budget_min, 0), st, p_budget_min, p_budget_max, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
    returning id into mid;
    v_new := p_publish;
  else
    select * into m from missions where id = p_id and client_id = auth.uid();
    if not found then raise exception 'Besoin introuvable'; end if;
    if m.status not in ('draft', 'published') then raise exception 'Ce besoin est déjà attribué'; end if;
    update missions set title = trim(p_title), description = coalesce(trim(p_description), ''), budget_min = p_budget_min, budget_max = p_budget_max,
      total = coalesce(p_budget_max, p_budget_min, 0), deadline = nullif(left(trim(coalesce(p_deadline, '')), 60), ''), status = st, updated_at = now()
    where id = m.id;
    mid := m.id;
    v_new := p_publish and m.status = 'draft';
  end if;
  if v_new then
    for r in select id from profiles where role::text in ('dept', 'admin') and not suspended and id <> auth.uid() loop
      perform notify_user(r.id, 'mission', 'Nouveau besoin à qualifier', display_name(auth.uid()) || ' a publié « ' || trim(p_title) || ' ».', jsonb_build_object('mission_id', mid));
    end loop;
  end if;
  return mid;
end $$;

-- Le client retire un besoin qui n'est pas encore attribué ; les propositions en attente sont déclinées et leurs auteurs prévenus.
create or replace function mission_cancel(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_id and client_id = auth.uid() for update;
  if not found then raise exception 'Besoin introuvable'; end if;
  if m.status = 'cancelled' then return 'cancelled'; end if;
  if m.status not in ('draft', 'published') then raise exception 'Ce besoin est déjà attribué : contactez le département pour l''arrêter'; end if;
  update missions set status = 'cancelled', updated_at = now() where id = m.id;
  for r in select author_id from mission_proposals where mission_id = m.id and status = 'submitted' loop
    perform notify_user(r.author_id, 'mission', 'Besoin retiré', 'Le besoin « ' || coalesce(m.title, m.number) || ' » a été retiré par son auteur.', jsonb_build_object('mission_id', m.id));
  end loop;
  update mission_proposals set status = 'declined', decided_at = now() where mission_id = m.id and status = 'submitted';
  return 'cancelled';
end $$;

-- Besoins du client avec les propositions reçues (nom abrégé de l'auteur) et les jalons.
create or replace function my_needs() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'kind', m.kind, 'status', m.status,
      'budget_min', m.budget_min, 'budget_max', m.budget_max, 'deadline', m.deadline, 'created_at', m.created_at,
      'proposals', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'amount', p.amount, 'delay_days', p.delay_days, 'message', p.message, 'status', p.status,
          'author_id', p.author_id, 'author_name', display_name(p.author_id), 'attempts', p.attempts, 'created_at', p.created_at) order by p.created_at desc)
        from mission_proposals p where p.mission_id = m.id), '[]'::jsonb),
      'milestones', coalesce((select jsonb_agg(jsonb_build_object('position', j.position, 'title', j.title, 'amount', j.amount, 'status', j.status, 'note', j.note) order by j.position)
        from mission_milestones j where j.mission_id = m.id), '[]'::jsonb)) order by m.updated_at desc)
    from (select * from missions where client_id = auth.uid() order by updated_at desc limit 50) m), '[]'::jsonb);
end $$;

-- Proposition d'un talent : une proposition en attente à la fois, trois au plus par besoin (redépôt après refus limité).
create or replace function propose_on_mission(p_mission uuid, p_amount integer, p_delay_days integer, p_message text) returns uuid
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; pid uuid; prev mission_proposals%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Seuls les talents peuvent proposer'; end if;
  select * into m from missions where id = p_mission;
  if not found or m.status <> 'published' then raise exception 'Ce besoin ne reçoit plus de propositions'; end if;
  if m.client_id = auth.uid() then raise exception 'Vous ne pouvez pas répondre à votre propre besoin'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Indiquez un montant supérieur à 0'; end if;
  if p_delay_days is null or p_delay_days not between 1 and 365 then raise exception 'Indiquez un délai de 1 à 365 jours'; end if;
  select * into prev from mission_proposals where mission_id = m.id and author_id = auth.uid();
  if found then
    if prev.status = 'submitted' then raise exception 'Vous avez déjà proposé'; end if;
    if prev.status = 'accepted' then raise exception 'Votre proposition a déjà été acceptée'; end if;
    if prev.attempts >= 3 then raise exception 'Vous avez déjà fait trois propositions sur ce besoin'; end if;
  end if;
  insert into mission_proposals (mission_id, author_id, amount, delay_days, message)
  values (m.id, auth.uid(), p_amount, p_delay_days, nullif(left(trim(coalesce(p_message, '')), 2000), ''))
  on conflict (mission_id, author_id) do update set amount = excluded.amount, delay_days = excluded.delay_days, message = excluded.message, status = 'submitted', created_at = now(), decided_at = null,
    attempts = mission_proposals.attempts + 1
  returning id into pid;
  insert into notifications (user_id, kind, title, body, data)
  values (m.client_id, 'mission', 'Nouvelle proposition', 'Besoin « ' || coalesce(m.title, m.number) || ' » : ' || p_amount || ' FCFA en ' || p_delay_days || ' jour(s).', jsonb_build_object('mission_id', m.id, 'proposal_id', pid));
  return pid;
end $$;

revoke all on function mission_cancel(uuid), my_needs() from public, anon;
grant execute on function mission_cancel(uuid), my_needs() to authenticated;

-- ============================================================ 3. offres premium
-- audience_roles : rôles concernés (vide = tous) ; sellable : l'offre ne se vend que si ses fonctions existent réellement.
alter table plans add column if not exists audience_roles text[] not null default '{}';
alter table plans add column if not exists sellable boolean not null default true;
update plans set audience_roles = '{student,admin}' where code in ('createur_pro', 'vendeur_pro') and audience_roles = '{}';
update plans set audience_roles = '{company,other,admin}' where code = 'entreprise' and audience_roles = '{}';
-- Aucune fonction n'est encore livrée pour ces deux offres : elles ne sont ni affichées ni vendues.
update plans set sellable = false where code in ('createur_pro', 'admin_communaute');

-- Droit en vigueur (abonnement actif non échu) du compte connecté ; usage interne.
create or replace function user_has_feature(p_feature text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from subscriptions s join plans p on p.code = s.plan_code
                 where s.user_id = auth.uid() and s.status in ('active', 'cancel_at_period_end') and s.current_period_end > now() and p_feature = any(p.features))
$$;
revoke all on function user_has_feature(text) from public, anon, authenticated;

create or replace function subscription_start(p_plan text) returns uuid
language plpgsql security definer set search_path = public as $$
declare pl plans%rowtype; pay uuid; v uuid; v_role text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role = '' then raise exception 'Action non autorisée'; end if;
  select * into pl from plans where code = p_plan and active;
  if not found then raise exception 'Plan introuvable'; end if;
  if not pl.sellable then raise exception 'Cette offre n''est pas encore disponible : ses fonctions ne sont pas encore ouvertes'; end if;
  if cardinality(pl.audience_roles) > 0 and not (v_role = any(pl.audience_roles)) then raise exception 'Cette offre ne concerne pas votre type de compte'; end if;
  if pl.price_xaf is null or pl.price_xaf = 0 then raise exception 'Ce plan n''est pas encore disponible à la souscription'; end if;
  -- demande en attente dont le paiement a échoué ou a été annulé : abandonnée, on peut recommencer
  update subscriptions s set status = 'expired'
    where s.user_id = auth.uid() and s.plan_code = p_plan and s.status = 'pending'
      and exists (select 1 from payment_transactions t where t.id = s.payment_id and t.status in ('failed', 'cancelled'));
  if exists (select 1 from subscriptions where user_id = auth.uid() and plan_code = p_plan and status in ('pending', 'active', 'cancel_at_period_end') and (current_period_end is null or current_period_end > now())) then
    raise exception 'Vous avez déjà ce plan ou une souscription en attente';
  end if;
  pay := payment_start('subscription', 'plan:' || p_plan, pl.price_xaf, 'manual');
  insert into subscriptions (user_id, plan_code, payment_id) values (auth.uid(), p_plan, pay) returning id into v;
  return pay;
end $$;

drop function if exists subscription_cancel();
create or replace function subscription_cancel(p_plan text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_codes text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select array_agg(distinct plan_code) into v_codes from subscriptions where user_id = auth.uid() and status = 'active';
  if v_codes is null then raise exception 'Aucun abonnement actif'; end if;
  if p_plan is null and cardinality(v_codes) > 1 then raise exception 'Précisez l''offre à annuler'; end if;
  update subscriptions set status = 'cancel_at_period_end' where user_id = auth.uid() and status = 'active' and (p_plan is null or plan_code = p_plan);
  if not found then raise exception 'Aucun abonnement actif pour cette offre'; end if;
end $$;

-- Fin de période : les abonnements échus passent à « expired » (le droit s'arrête déjà à l'échéance) ; les demandes dont le paiement
-- a échoué ou été annulé sont abandonnées. À planifier (pg_cron, par exemple chaque heure) : select expire_subscriptions();
create or replace function expire_subscriptions() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer := 0; r record;
begin
  for r in update subscriptions set status = 'expired'
           where status in ('active', 'cancel_at_period_end') and current_period_end is not null and current_period_end <= now()
           returning user_id, plan_code loop
    n := n + 1;
    perform notify_user(r.user_id, 'subscription', 'Abonnement terminé', 'Votre offre « ' || coalesce((select name from plans where code = r.plan_code), r.plan_code) || ' » est arrivée à échéance.', jsonb_build_object('plan', r.plan_code));
  end loop;
  update subscriptions s set status = 'expired'
    where s.status = 'pending' and exists (select 1 from payment_transactions t where t.id = s.payment_id and t.status in ('failed', 'cancelled'));
  return n;
end $$;
revoke all on function expire_subscriptions() from public, anon, authenticated;

create or replace function my_entitlements() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'subscriptions', coalesce((select jsonb_agg(jsonb_build_object('plan', s.plan_code, 'status', s.status, 'period_end', s.current_period_end, 'name', p.name,
                                 'payment_id', s.payment_id, 'payment_status', t.status) order by s.created_at desc)
                               from subscriptions s join plans p on p.code = s.plan_code left join payment_transactions t on t.id = s.payment_id where s.user_id = auth.uid()), '[]'::jsonb),
    'features', coalesce((select jsonb_agg(distinct f) from subscriptions s join plans p on p.code = s.plan_code, unnest(p.features) f
                          where s.user_id = auth.uid() and s.status in ('active', 'cancel_at_period_end') and s.current_period_end > now()), '[]'::jsonb));
end $$;

revoke all on function subscription_start(text), subscription_cancel(text), my_entitlements() from public, anon;
grant execute on function subscription_start(text), subscription_cancel(text), my_entitlements() to authenticated;

-- ============================================================ 4. campagnes sponsorisées
create or replace function ad_campaign_save(p_id uuid, p_title text, p_body text, p_post uuid, p_listing uuid, p_budget int, p_daily int, p_starts date, p_ends date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not user_has_feature('boost_campagnes') and not exists (select 1 from profiles where id = auth.uid() and is_test) then
    raise exception 'Les campagnes sponsorisées font partie des offres Vendeur professionnel et Entreprise';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 80 then raise exception 'Titre : 3 à 80 caractères'; end if;
  if char_length(coalesce(trim(p_body), '')) > 300 then raise exception 'Texte : 300 caractères au plus'; end if;
  if p_budget is null or p_budget < 1000 then raise exception 'Budget : 1 000 FCFA au minimum'; end if;
  if p_budget > 100000000 then raise exception 'Budget : 100 000 000 FCFA au plus'; end if;
  if p_daily is not null and p_daily <= 0 then raise exception 'Le budget par jour doit être supérieur à 0'; end if;
  if p_post is not null and not exists (select 1 from posts where id = p_post and author_id = auth.uid() and status = 'published') then raise exception 'Publication introuvable ou non publiée'; end if;
  if p_listing is not null and not exists (select 1 from listings where id = p_listing and seller_id = auth.uid() and status = 'approved') then raise exception 'Annonce introuvable ou non publiée'; end if;
  if p_post is null and p_listing is null then raise exception 'Choisissez une publication ou une annonce à promouvoir'; end if;
  if p_ends is not null and p_starts is not null and p_ends < p_starts then raise exception 'Dates invalides'; end if;
  if p_id is null then
    insert into ad_campaigns (owner_id, title, body, post_id, listing_id, budget_xaf, daily_budget_xaf, starts_on, ends_on)
    values (auth.uid(), trim(p_title), coalesce(trim(p_body), ''), p_post, p_listing, p_budget, p_daily, p_starts, p_ends) returning id into v;
  else
    update ad_campaigns set title = trim(p_title), body = coalesce(trim(p_body), ''), post_id = p_post, listing_id = p_listing, budget_xaf = p_budget, daily_budget_xaf = p_daily, starts_on = p_starts, ends_on = p_ends
    where id = p_id and owner_id = auth.uid() and status in ('draft', 'rejected') returning id into v;
    if v is null then raise exception 'Campagne non modifiable'; end if;
  end if;
  return v;
end $$;

create or replace function ad_campaign_submit(p_id uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype; pay uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not user_has_feature('boost_campagnes') and not exists (select 1 from profiles where id = auth.uid() and is_test) then
    raise exception 'Les campagnes sponsorisées font partie des offres Vendeur professionnel et Entreprise';
  end if;
  select * into c from ad_campaigns where id = p_id and owner_id = auth.uid() and status in ('draft', 'rejected');
  if not found then raise exception 'Campagne non soumissible'; end if;
  pay := payment_start('campaign', 'campagne:' || c.id::text, c.budget_xaf, 'manual');
  update ad_campaigns set status = 'awaiting_payment', payment_id = pay where id = c.id;
  return pay;
end $$;

-- Annule une campagne qui n'a pas encore été diffusée (brouillon, refusée, ou paiement du budget en attente) ; le paiement non déclaré est annulé.
create or replace function ad_campaign_cancel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype; t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from ad_campaigns where id = p_id and owner_id = auth.uid() for update;
  if not found then raise exception 'Campagne introuvable'; end if;
  if c.status not in ('draft', 'rejected', 'awaiting_payment') then raise exception 'Cette campagne ne peut plus être annulée'; end if;
  if c.status = 'awaiting_payment' and c.payment_id is not null then
    select * into t from payment_transactions where id = c.payment_id for update;
    if found then
      if t.status = 'pending' then raise exception 'Le paiement est déclaré : attendez la décision de la finance'; end if;
      if t.status = 'confirmed' then raise exception 'Le budget est déjà payé : la campagne est en cours de validation'; end if;
      if t.status in ('created', 'failed') then
        update payment_transactions set status = 'cancelled', decided_at = now(), note = 'Campagne annulée par son auteur' where id = t.id;
        insert into payment_messages (transaction_id, sender, body) values (t.id, 'system', 'Campagne annulée : paiement annulé.');
      end if;
    end if;
  end if;
  delete from ad_campaigns where id = c.id;
end $$;

revoke all on function ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date), ad_campaign_submit(uuid), ad_campaign_cancel(uuid) from public, anon;
grant execute on function ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date), ad_campaign_submit(uuid), ad_campaign_cancel(uuid) to authenticated;

-- RETOUR ARRIÈRE : recréer company_invite(text, text, uuid) depuis 20261114002900, save_mission(uuid, text, text, integer, integer, text, boolean, text) depuis 20261114002600,
--   propose_on_mission(uuid, integer, integer, text) depuis 20261031000000, subscription_start(text), my_entitlements(), ad_campaign_save(...) et ad_campaign_submit(uuid) depuis 20261106000000 ;
--   drop function mission_cancel(uuid), my_needs(), user_has_feature(text), subscription_cancel(text), expire_subscriptions(), ad_campaign_cancel(uuid) ; recréer subscription_cancel() depuis 20261106000000 ;
--   alter table plans drop column audience_roles, drop column sellable ; alter table mission_proposals drop column attempts.
