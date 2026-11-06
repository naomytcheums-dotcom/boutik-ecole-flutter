-- Offres premium (plans, abonnements) et campagnes sponsorisées (publicités du fil), reliées au paiement par messagerie (migration 20261105001200).
-- AUCUN PRIX N'EST INVENTÉ : un plan sans prix ne peut pas être souscrit ; l'administrateur fixe les prix (écran de gestion des plans).
-- Le badge vérifié reste lié à la certification par le département et n'est jamais vendu. Toute publicité diffusée porte la mention « Sponsorisé ».
-- Retour arrière : voir la fin du fichier.

-- ============================================================ plans et abonnements
create table if not exists plans (
  code text primary key check (code ~ '^[a-z_]{3,30}$'),
  name text not null check (char_length(name) between 2 and 60),
  audience text not null default '' check (char_length(audience) <= 120),
  price_xaf integer check (price_xaf is null or price_xaf >= 0),
  period_days integer not null default 30 check (period_days between 1 and 366),
  features text[] not null default '{}',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  plan_code text not null references plans(code),
  status text not null default 'pending' check (status in ('pending', 'active', 'cancel_at_period_end', 'expired')),
  payment_id uuid references payment_transactions(id) on delete set null,
  started_at timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists subscriptions_user on subscriptions (user_id, created_at desc);
alter table plans enable row level security;
alter table subscriptions enable row level security;
revoke all on plans, subscriptions from anon, authenticated;
grant select on plans to anon, authenticated;
grant select on subscriptions to authenticated;
drop policy if exists "plans : publics" on plans;
create policy "plans : publics" on plans for select using (active or coalesce(current_role_name()::text, '') in ('admin', 'direction'));
drop policy if exists "abonnements : titulaire ou gestion" on subscriptions;
create policy "abonnements : titulaire ou gestion" on subscriptions for select using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance', 'direction'));

-- Les cinq plans visés par la conception ; prix absents tant que l'administration ne les fixe pas. Les droits suivent la logique testée de l'application.
insert into plans (code, name, audience, features) values
  ('gratuit', 'Gratuit', 'Tous les comptes', '{}'),
  ('createur_pro', 'Créateur professionnel', 'Étudiants créateurs de contenu', '{stats_avancees,portfolio_enrichi,visiteurs_profil}'),
  ('vendeur_pro', 'Vendeur professionnel', 'Vendeurs réguliers', '{stats_avancees,outils_vendeur_pro,boost_campagnes}'),
  ('entreprise', 'Entreprise', 'Entreprises et partenaires', '{stats_avancees,boost_campagnes,gestion_equipe}'),
  ('admin_communaute', 'Administrateur de communauté', 'Responsables de communautés', '{gestion_communaute,stats_avancees}')
on conflict (code) do nothing;

create or replace function plan_set(p_code text, p_name text, p_price integer, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Action non autorisée'; end if;
  if p_price is not null and p_price < 0 then raise exception 'Prix invalide'; end if;
  update plans set name = coalesce(nullif(trim(p_name), ''), name), price_xaf = p_price, active = coalesce(p_active, active), updated_at = now() where code = p_code;
  if not found then raise exception 'Plan introuvable'; end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Plan modifié', p_code, 'Offres', 'Info');
end $$;

-- Souscrire : crée la demande de paiement (fil de messagerie) ; l'abonnement s'active à la confirmation du paiement par la finance.
create or replace function subscription_start(p_plan text) returns uuid
language plpgsql security definer set search_path = public as $$
declare pl plans%rowtype; pay uuid; v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into pl from plans where code = p_plan and active;
  if not found then raise exception 'Plan introuvable'; end if;
  if pl.price_xaf is null or pl.price_xaf = 0 then raise exception 'Ce plan n''est pas encore disponible à la souscription'; end if;
  if exists (select 1 from subscriptions where user_id = auth.uid() and plan_code = p_plan and status in ('pending', 'active', 'cancel_at_period_end') and (current_period_end is null or current_period_end > now())) then
    raise exception 'Vous avez déjà ce plan ou une souscription en attente';
  end if;
  pay := payment_start('subscription', 'plan:' || p_plan, pl.price_xaf, 'manual');
  insert into subscriptions (user_id, plan_code, payment_id) values (auth.uid(), p_plan, pay) returning id into v;
  return pay;
end $$;

create or replace function subscription_cancel() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update subscriptions set status = 'cancel_at_period_end' where user_id = auth.uid() and status = 'active';
  if not found then raise exception 'Aucun abonnement actif'; end if;
end $$;

create or replace function my_entitlements() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'subscriptions', coalesce((select jsonb_agg(jsonb_build_object('plan', s.plan_code, 'status', s.status, 'period_end', s.current_period_end, 'name', p.name) order by s.created_at desc)
                               from subscriptions s join plans p on p.code = s.plan_code where s.user_id = auth.uid()), '[]'::jsonb),
    'features', coalesce((select jsonb_agg(distinct f) from subscriptions s join plans p on p.code = s.plan_code, unnest(p.features) f
                          where s.user_id = auth.uid() and s.status in ('active', 'cancel_at_period_end') and s.current_period_end > now()), '[]'::jsonb));
end $$;

-- ============================================================ campagnes sponsorisées
create table if not exists ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 80),
  body text not null default '' check (char_length(body) <= 300),
  post_id uuid references posts(id) on delete set null,
  listing_id uuid references listings(id) on delete set null,
  budget_xaf integer not null check (budget_xaf between 1000 and 100000000),
  daily_budget_xaf integer check (daily_budget_xaf is null or daily_budget_xaf > 0),
  status text not null default 'draft' check (status in ('draft', 'awaiting_payment', 'pending_review', 'approved', 'active', 'paused', 'finished', 'rejected')),
  review_note text,
  payment_id uuid references payment_transactions(id) on delete set null,
  spent_xaf integer not null default 0 check (spent_xaf >= 0),
  starts_on date,
  ends_on date,
  created_at timestamptz not null default now(),
  check (post_id is not null or listing_id is not null)
);
create table if not exists ad_events (
  campaign_id uuid not null references ad_campaigns(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('impression', 'click')),
  day date not null default current_date,
  primary key (campaign_id, user_id, kind, day)
);
alter table ad_campaigns enable row level security;
alter table ad_events enable row level security;
revoke all on ad_campaigns, ad_events from anon, authenticated;
grant select on ad_campaigns to authenticated;
drop policy if exists "publicités : propriétaire ou gestion" on ad_campaigns;
create policy "publicités : propriétaire ou gestion" on ad_campaigns for select using (owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'direction', 'finance'));

create or replace function ad_campaign_save(p_id uuid, p_title text, p_body text, p_post uuid, p_listing uuid, p_budget int, p_daily int, p_starts date, p_ends date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
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

-- Soumission : le budget doit être payé (fil de messagerie) avant la validation ; aucun débit sans paiement confirmé.
create or replace function ad_campaign_submit(p_id uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype; pay uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from ad_campaigns where id = p_id and owner_id = auth.uid() and status in ('draft', 'rejected');
  if not found then raise exception 'Campagne non soumissible'; end if;
  pay := payment_start('campaign', 'campagne:' || c.id::text, c.budget_xaf, 'manual');
  update ad_campaigns set status = 'awaiting_payment', payment_id = pay where id = c.id;
  return pay;
end $$;

create or replace function ad_campaign_review(p_id uuid, p_approve boolean, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction') then raise exception 'Action non autorisée'; end if;
  select * into c from ad_campaigns where id = p_id and status = 'pending_review';
  if not found then raise exception 'Campagne non en attente de validation'; end if;
  if p_approve then
    update ad_campaigns set status = case when coalesce(starts_on, current_date) <= current_date then 'active' else 'approved' end, review_note = left(p_note, 300) where id = c.id;
  else
    if coalesce(trim(p_note), '') = '' then raise exception 'Motif de refus obligatoire'; end if;
    update ad_campaigns set status = 'rejected', review_note = left(p_note, 300) where id = c.id;
  end if;
  insert into notifications (user_id, kind, title, body, data) values (c.owner_id, 'ads', 'Campagne ' || case when p_approve then 'validée' else 'refusée' end, c.title, jsonb_build_object('campaign_id', c.id));
end $$;

create or replace function ad_campaign_toggle(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare s text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update ad_campaigns set status = case status when 'active' then 'paused' when 'paused' then 'active' else status end
  where id = p_id and owner_id = auth.uid() and status in ('active', 'paused') returning status into s;
  if s is null then raise exception 'Campagne non modifiable'; end if;
  return s;
end $$;

-- Publicités à insérer dans le fil : actives, dans leurs dates, budget non épuisé, jamais pour son propre contenu ; toujours marquées « Sponsorisé ».
create or replace function ad_feed(p_limit int default 3) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'body', c.body, 'post_id', c.post_id, 'listing_id', c.listing_id,
         'sponsored', true, 'owner', coalesce(o.name, 'Annonceur')) order by random()), '[]'::jsonb)
  from (select * from ad_campaigns
        where status = 'active' and spent_xaf < budget_xaf and coalesce(starts_on, current_date) <= current_date and coalesce(ends_on, current_date) >= current_date
          and owner_id is distinct from auth.uid()
          and (daily_budget_xaf is null or coalesce((select count(*) from ad_events e where e.campaign_id = ad_campaigns.id and e.kind = 'click' and e.day = current_date), 0)
               * coalesce((select (value #>> '{}')::int from platform_settings where key = 'ads.cost_per_click'), 0) < daily_budget_xaf)
        limit least(greatest(p_limit, 1), 10)) c
  left join profiles o on o.id = c.owner_id;
$$;

-- Impression ou clic, dédoublonné par personne et par jour. Le coût par clic vient du réglage « ads.cost_per_click » (absent : aucun débit).
create or replace function ad_event_record(p_campaign uuid, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype; cpc int; ins int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('impression', 'click') then raise exception 'Événement invalide'; end if;
  select * into c from ad_campaigns where id = p_campaign and status = 'active';
  if not found or c.owner_id = auth.uid() then return; end if;
  insert into ad_events (campaign_id, user_id, kind) values (p_campaign, auth.uid(), p_kind) on conflict do nothing;
  get diagnostics ins = row_count;
  if ins = 1 and p_kind = 'click' then
    cpc := coalesce((select (value #>> '{}')::int from platform_settings where key = 'ads.cost_per_click'), 0);
    if cpc > 0 then
      update ad_campaigns set spent_xaf = least(spent_xaf + cpc, budget_xaf), status = case when spent_xaf + cpc >= budget_xaf then 'finished' else status end where id = p_campaign;
    end if;
  end if;
end $$;

create or replace function my_ad_campaigns() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'status', c.status, 'budget', c.budget_xaf, 'spent', c.spent_xaf, 'review_note', c.review_note, 'payment_id', c.payment_id,
      'impressions', (select count(*)::int from ad_events e where e.campaign_id = c.id and e.kind = 'impression'),
      'clicks', (select count(*)::int from ad_events e where e.campaign_id = c.id and e.kind = 'click'),
      'ctr', case when (select count(*) from ad_events e where e.campaign_id = c.id and e.kind = 'impression') = 0 then null
                  else round(100.0 * (select count(*) from ad_events e where e.campaign_id = c.id and e.kind = 'click') / (select count(*) from ad_events e where e.campaign_id = c.id and e.kind = 'impression'), 1) end)
      order by c.created_at desc) from ad_campaigns c where c.owner_id = auth.uid()), '[]'::jsonb);
end $$;

-- ============================================================ le paiement confirmé active l'abonnement ou la campagne
create or replace function payment_set_status(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype; pl plans%rowtype; v_code text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('confirmed', 'failed', 'cancelled') then raise exception 'Statut invalide'; end if;
  select * into t from payment_transactions where id = p_id;
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status = 'confirmed' then raise exception 'Paiement déjà confirmé'; end if;
  update payment_transactions set status = p_status, decided_at = now(), decided_by = auth.uid(), note = left(p_note, 300) where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'finance',
    case p_status when 'confirmed' then 'Paiement confirmé. Merci !' when 'failed' then 'Paiement non retrouvé' || coalesce(' : ' || left(p_note, 200), '') || '. Vous pouvez le redéclarer.' else 'Paiement annulé.' end);
  insert into notifications (user_id, kind, title, body, data) values (t.payer_id, 'payment', 'Paiement ' || t.reference,
    case p_status when 'confirmed' then 'Confirmé' when 'failed' then 'Non retrouvé' else 'Annulé' end, jsonb_build_object('payment_id', p_id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Paiement ' || p_status, t.reference, 'Finance', 'Info');
  if p_status = 'confirmed' and t.kind = 'subscription' and t.subject like 'plan:%' then
    v_code := substr(t.subject, 6);
    select * into pl from plans where plans.code = v_code;
    update subscriptions set status = 'active', started_at = now(), current_period_end = now() + make_interval(days => pl.period_days) where payment_id = p_id;
  elsif p_status = 'confirmed' and t.kind = 'campaign' and t.subject like 'campagne:%' then
    update ad_campaigns set status = 'pending_review' where payment_id = p_id and status = 'awaiting_payment';
  end if;
end $$;

revoke all on function plan_set(text, text, integer, boolean), subscription_start(text), subscription_cancel(), my_entitlements(), ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date),
  ad_campaign_submit(uuid), ad_campaign_review(uuid, boolean, text), ad_campaign_toggle(uuid), ad_feed(int), ad_event_record(uuid, text), my_ad_campaigns() from public, anon;
grant execute on function plan_set(text, text, integer, boolean), subscription_start(text), subscription_cancel(), my_entitlements(), ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date),
  ad_campaign_submit(uuid), ad_campaign_review(uuid, boolean, text), ad_campaign_toggle(uuid), ad_feed(int), ad_event_record(uuid, text), my_ad_campaigns() to authenticated;

-- RETOUR ARRIÈRE : drop function plan_set(text, text, integer, boolean), subscription_start(text), subscription_cancel(), my_entitlements(), ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date),
--   ad_campaign_submit(uuid), ad_campaign_review(uuid, boolean, text), ad_campaign_toggle(uuid), ad_feed(int), ad_event_record(uuid, text), my_ad_campaigns();
--   drop table ad_events, ad_campaigns, subscriptions, plans;  (puis recréer payment_set_status depuis la migration 20261105001200)
