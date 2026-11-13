-- Forfaits des entreprises, accueil entreprise et obligation d'être vérifiée avant de publier.
-- Les forfaits sont définis et modifiables par l'administrateur (prix, durée, quotas) ; les valeurs de départ sont PROVISOIRES.
-- Le paiement du forfait est confirmé à la main par l'administrateur (aucune clé de paiement n'est touchée) : l'entreprise demande un forfait, paie hors application,
-- l'administrateur active le forfait pour la durée choisie.
-- Seules les entreprises (rôle « company ») sont concernées : les organisations non commerciales (rôle « other » : universités, ONG, gouvernement) et l'équipe ne le sont pas.
-- Retour arrière : recréer save_mission, opp_save et ann_save depuis 20261031000000, 20261114001300 et 20261114001400 ;
--   drop function company_gate(text, uuid), company_plans_list(), company_plan_save(jsonb), company_plan_status(), company_subscription_request(text),
--   company_subscriptions_pending(), company_subscription_activate(uuid, text, integer, text), company_dashboard(); drop table company_subscriptions, company_plans.

create table if not exists company_plans (
  code text primary key check (code ~ '^[a-z0-9_]{2,30}$'),
  name text not null check (char_length(btrim(name)) between 2 and 60),
  price_fcfa integer not null default 0 check (price_fcfa >= 0),
  period_days integer not null default 30 check (period_days between 0 and 366),
  max_needs integer not null default 1 check (max_needs between 0 and 999),
  max_offers integer not null default 1 check (max_offers between 0 and 999),
  max_contests integer not null default 0 check (max_contests between 0 and 999),
  perks text not null default '' check (char_length(perks) <= 400),
  position integer not null default 0,
  active boolean not null default true
);
create table if not exists company_subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references company_profiles(owner_id) on delete cascade,
  plan_code text not null references company_plans(code),
  status text not null default 'requested' check (status in ('requested', 'active', 'expired', 'cancelled')),
  requested_at timestamptz not null default now(),
  starts_at timestamptz,
  ends_at timestamptz,
  note text check (note is null or char_length(note) <= 300),
  activated_by uuid references profiles(id) on delete set null
);
create unique index if not exists company_subscriptions_one_request on company_subscriptions (owner_id) where status = 'requested';
create index if not exists company_subscriptions_owner on company_subscriptions (owner_id, requested_at desc);
alter table company_plans enable row level security;
alter table company_subscriptions enable row level security;
revoke all on company_plans, company_subscriptions from anon, authenticated;

insert into company_plans (code, name, price_fcfa, period_days, max_needs, max_offers, max_contests, perks, position) values
  ('free', 'Découverte', 0, 0, 1, 1, 0, 'Un besoin et une offre actifs. Idéal pour essayer la plateforme.', 1),
  ('pro', 'Entreprise', 25000, 30, 10, 10, 2, 'Jusqu''à 10 besoins, 10 offres et 2 concours actifs en même temps.', 2),
  ('partner', 'Partenaire', 75000, 30, 999, 999, 20, 'Besoins et offres illimités, concours et défis d''innovation, mise en avant.', 3)
on conflict (code) do nothing;

-- Forfait en cours d'une entreprise : l'abonnement actif non expiré, sinon « Découverte ».
create or replace function company_current_plan(p_owner uuid) returns company_plans
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select p from company_subscriptions s join company_plans p on p.code = s.plan_code where s.owner_id = p_owner and s.status = 'active' and s.ends_at > now() order by s.ends_at desc limit 1),
    (select p from company_plans p where p.code = 'free'))
$$;

-- Porte de publication (interne) : une entreprise doit être vérifiée, puis rester dans les quotas de son forfait.
create or replace function company_gate(p_kind text, p_ignore uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_status text; pl company_plans%rowtype; v_used integer; v_max integer; v_label text;
begin
  if v_role <> 'company' then return; end if;
  select status into v_status from company_profiles where owner_id = auth.uid();
  if v_status is distinct from 'approved' then
    raise exception 'Votre entreprise doit être vérifiée par l''administrateur avant de publier : complétez votre fiche entreprise et envoyez vos pièces justificatives.';
  end if;
  select * into pl from company_current_plan(auth.uid());
  if p_kind = 'need' then
    select count(*) into v_used from missions where client_id = auth.uid() and status in ('published', 'assigned', 'in_progress') and (p_ignore is null or id <> p_ignore);
    v_max := pl.max_needs; v_label := 'besoins';
  elsif p_kind = 'offer' then
    select count(*) into v_used from opportunities where poster_id = auth.uid() and status in ('pending', 'published');
    v_max := pl.max_offers; v_label := 'offres';
  else
    select count(*) into v_used from contest_announcements where poster_id = auth.uid() and status in ('pending', 'published') and (p_ignore is null or id <> p_ignore);
    v_max := pl.max_contests; v_label := 'concours';
  end if;
  if v_used >= v_max then
    raise exception 'Votre forfait « % » est atteint : % % actifs sur %. Passez à un forfait supérieur ou clôturez une publication.', pl.name, v_used, v_label, v_max;
  end if;
end $$;
revoke all on function company_current_plan(uuid), company_gate(text, uuid) from public, anon, authenticated;

create or replace function company_plans_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(p) order by p.position, p.price_fcfa), '[]'::jsonb) from company_plans p where p.active or coalesce(current_role_name()::text, '') = 'admin'
$$;

create or replace function company_plan_save(p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare v_code text := lower(btrim(coalesce(p->>'code', '')));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if v_code !~ '^[a-z0-9_]{2,30}$' then raise exception 'Code du forfait : lettres minuscules, chiffres ou _ (2 à 30)'; end if;
  insert into company_plans (code, name, price_fcfa, period_days, max_needs, max_offers, max_contests, perks, position, active)
  values (v_code, btrim(coalesce(p->>'name', '')), coalesce((p->>'price_fcfa')::int, 0), coalesce((p->>'period_days')::int, 30), coalesce((p->>'max_needs')::int, 1), coalesce((p->>'max_offers')::int, 1),
          coalesce((p->>'max_contests')::int, 0), left(btrim(coalesce(p->>'perks', '')), 400), coalesce((p->>'position')::int, 0), coalesce((p->>'active')::boolean, true))
  on conflict (code) do update set name = excluded.name, price_fcfa = excluded.price_fcfa, period_days = excluded.period_days, max_needs = excluded.max_needs, max_offers = excluded.max_offers,
    max_contests = excluded.max_contests, perks = excluded.perks, position = excluded.position, active = excluded.active;
  return v_code;
end $$;

-- Situation de l'entreprise : forfait en cours, quotas utilisés, demande en attente.
create or replace function company_plan_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pl company_plans%rowtype; s company_subscriptions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into pl from company_current_plan(auth.uid());
  select * into s from company_subscriptions where owner_id = auth.uid() and status = 'active' and ends_at > now() order by ends_at desc limit 1;
  return jsonb_build_object('plan', to_jsonb(pl), 'ends_at', s.ends_at,
    'requested', (select plan_code from company_subscriptions where owner_id = auth.uid() and status = 'requested'),
    'used_needs', (select count(*)::int from missions where client_id = auth.uid() and status in ('published', 'assigned', 'in_progress')),
    'used_offers', (select count(*)::int from opportunities where poster_id = auth.uid() and status in ('pending', 'published')),
    'used_contests', (select count(*)::int from contest_announcements where poster_id = auth.uid() and status in ('pending', 'published')));
end $$;

create or replace function company_subscription_request(p_plan text) returns text
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; c company_profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = auth.uid();
  if not found or c.status <> 'approved' then raise exception 'Faites d''abord vérifier votre entreprise'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa = 0 then raise exception 'Forfait introuvable'; end if;
  begin
    insert into company_subscriptions (owner_id, plan_code) values (auth.uid(), pl.code);
  exception when unique_violation then
    update company_subscriptions set plan_code = pl.code, requested_at = now() where owner_id = auth.uid() and status = 'requested';
  end;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'company_plan', 'Forfait demandé', c.company_name || ' demande le forfait « ' || pl.name || ' » (' || pl.price_fcfa || ' FCFA).', jsonb_build_object('owner', auth.uid(), 'plan', pl.code) from profiles a where a.role::text = 'admin';
  return 'requested';
end $$;

create or replace function company_subscriptions_pending() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('owner_id', s.owner_id, 'company_name', c.company_name, 'plan_code', s.plan_code, 'plan_name', p.name, 'price_fcfa', p.price_fcfa, 'period_days', p.period_days,
      'requested_at', s.requested_at, 'phone', c.phone, 'email', (select email from auth.users where id = s.owner_id)) order by s.requested_at)
    from company_subscriptions s join company_profiles c on c.owner_id = s.owner_id join company_plans p on p.code = s.plan_code where s.status = 'requested'), '[]'::jsonb);
end $$;

-- L'administrateur confirme le paiement reçu et active le forfait pour la durée choisie (celle du forfait par défaut).
create or replace function company_subscription_activate(p_owner uuid, p_plan text, p_days integer default null, p_note text default '') returns timestamptz
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; v_days integer; v_end timestamptz;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into pl from company_plans where code = p_plan;
  if not found then raise exception 'Forfait introuvable'; end if;
  if not exists (select 1 from company_profiles where owner_id = p_owner and status = 'approved') then raise exception 'Entreprise non vérifiée'; end if;
  v_days := coalesce(p_days, nullif(pl.period_days, 0), 30);
  if v_days < 1 or v_days > 366 then raise exception 'Durée de 1 à 366 jours'; end if;
  v_end := now() + make_interval(days => v_days);
  update company_subscriptions set status = 'expired' where owner_id = p_owner and status = 'active';
  delete from company_subscriptions where owner_id = p_owner and status = 'requested';
  insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at, note, activated_by) values (p_owner, pl.code, 'active', now(), v_end, nullif(left(btrim(coalesce(p_note, '')), 300), ''), auth.uid());
  insert into notifications (user_id, kind, title, body, data)
    values (p_owner, 'company_plan', 'Forfait activé', 'Votre forfait « ' || pl.name || ' » est actif jusqu''au ' || to_char(v_end, 'DD/MM/YYYY') || '.', jsonb_build_object('plan', pl.code));
  return v_end;
end $$;

-- Accueil de l'entreprise : vérification, forfait et chiffres clés.
create or replace function company_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c company_profiles%rowtype; pl company_plans%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = auth.uid();
  select * into pl from company_current_plan(auth.uid());
  return jsonb_build_object(
    'company_name', c.company_name, 'status', coalesce(c.status, 'none'), 'review_note', c.review_note, 'plan_name', pl.name,
    'plan_ends_at', (select max(ends_at) from company_subscriptions where owner_id = auth.uid() and status = 'active' and ends_at > now()),
    'needs_open', (select count(*)::int from missions where client_id = auth.uid() and status in ('published', 'assigned', 'in_progress')),
    'needs_draft', (select count(*)::int from missions where client_id = auth.uid() and status = 'draft'),
    'proposals_new', (select count(*)::int from mission_proposals mp join missions m on m.id = mp.mission_id where m.client_id = auth.uid() and mp.status = 'submitted'),
    'offers_active', (select count(*)::int from opportunities where poster_id = auth.uid() and status in ('pending', 'published')),
    'applications_new', (select count(*)::int from opportunity_applications a join opportunities o on o.id = a.opportunity_id where o.poster_id = auth.uid() and a.status = 'sent'),
    'recruits', (select count(*)::int from opportunity_applications a join opportunities o on o.id = a.opportunity_id where o.poster_id = auth.uid() and a.status = 'hired'),
    'contests_active', (select count(*)::int from contest_announcements where poster_id = auth.uid() and status in ('pending', 'published')));
end $$;

revoke all on function company_plans_list(), company_plan_save(jsonb), company_plan_status(), company_subscription_request(text), company_subscriptions_pending(),
  company_subscription_activate(uuid, text, integer, text), company_dashboard() from public, anon;
grant execute on function company_plans_list(), company_plan_save(jsonb), company_plan_status(), company_subscription_request(text), company_subscriptions_pending(),
  company_subscription_activate(uuid, text, integer, text), company_dashboard() to authenticated;

-- ---------------------------------------------------------------- publication : porte « entreprise vérifiée + forfait »

CREATE OR REPLACE FUNCTION public.ann_save(p jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_role text := coalesce(current_role_name()::text, ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept'); v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform company_gate('contest', nullif(p->>'id', '')::uuid);
  if v_role in ('student', 'visitor', '') then raise exception 'Réservé à l''équipe, aux départements, aux entreprises et aux ONG'; end if;
  if char_length(btrim(coalesce(p->>'title', ''))) < 3 then raise exception 'Indiquez le titre du concours'; end if;
  if char_length(btrim(coalesce(p->>'organizer', ''))) < 2 then raise exception 'Indiquez l''organisateur'; end if;
  if coalesce(p->>'kind', '') not in ('contest', 'scholarship', 'hackathon', 'call', 'internship', 'job', 'training') then raise exception 'Type inconnu'; end if;
  if coalesce(p->>'official_url', '') !~* '^https?://[^ ]+\.[^ ]+' then raise exception 'Indiquez le lien officiel (commençant par http)'; end if;
  if nullif(p->>'deadline', '') is not null and (p->>'deadline')::date < current_date then raise exception 'La date limite doit être dans le futur'; end if;
  if (select count(*) from contest_announcements where poster_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix annonces par jour au plus'; end if;
  insert into contest_announcements (poster_id, title, organizer, organizer_kind, country, place_kind, place, domain, kind, description, why, conditions, documents, steps, criteria,
      opens_on, deadline, results_on, program_start, reward, eligible_level, eligible_age, eligible_department, eligible_country, iut_only, free, cost_amount, cost_currency, official_url, verified, status)
  values (auth.uid(), btrim(p->>'title'), btrim(p->>'organizer'), coalesce(nullif(p->>'organizer_kind', ''), 'other'), left(coalesce(p->>'country', ''), 60), coalesce(nullif(p->>'place_kind', ''), 'online'), left(coalesce(p->>'place', ''), 100),
      coalesce(nullif(p->>'domain', ''), 'other'), p->>'kind', left(coalesce(p->>'description', ''), 4000), left(coalesce(p->>'why', ''), 1000),
      coalesce(array(select jsonb_array_elements_text(coalesce(p->'conditions', '[]'::jsonb))), '{}'), coalesce(array(select jsonb_array_elements_text(coalesce(p->'documents', '[]'::jsonb))), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(p->'steps', '[]'::jsonb))), '{}'), coalesce(array(select jsonb_array_elements_text(coalesce(p->'criteria', '[]'::jsonb))), '{}'),
      nullif(p->>'opens_on', '')::date, nullif(p->>'deadline', '')::date, nullif(p->>'results_on', '')::date, nullif(p->>'program_start', '')::date,
      left(coalesce(p->>'reward', ''), 200), left(coalesce(p->>'eligible_level', ''), 80), left(coalesce(p->>'eligible_age', ''), 40), left(coalesce(p->>'eligible_department', ''), 120), left(coalesce(p->>'eligible_country', ''), 80),
      coalesce((p->>'iut_only')::boolean, false), coalesce((p->>'free')::boolean, true), nullif(p->>'cost_amount', '')::integer, coalesce(nullif(p->>'cost_currency', ''), 'FCFA'), btrim(p->>'official_url'),
      v_staff, case when v_staff then 'published' else 'pending' end)
  returning id into v_id;
  if not v_staff then
    for r in select id from profiles where role::text = 'admin' loop
      perform notify_user(r.id, 'contest_review', 'Concours à valider', btrim(p->>'organizer') || ' propose « ' || btrim(p->>'title') || ' ».', jsonb_build_object('announcement', v_id));
    end loop;
  end if;
  return v_id;
end $function$;

CREATE OR REPLACE FUNCTION public.opp_save(p_org text, p_kind text, p_contract text, p_title text, p_location text, p_mode text, p_duration text, p_pay_kind text, p_pay_amount integer, p_pay_note text, p_deadline date, p_skills text[], p_description text, p_missions text[], p_profile text, p_department text, p_level text, p_gains text[], p_whatsapp text, p_in_app boolean, p_about text, p_iut_only boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_role text := coalesce(current_role_name()::text, ''); v_staff boolean; v_skills text[]; v_missions text[]; v_gains text[]; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform company_gate('offer', null);
  if v_role in ('student', 'visitor', '') then raise exception 'Réservé aux entreprises, ONG, startups et à l''équipe de l''IUT'; end if;
  v_staff := v_role in ('admin', 'dept');
  if char_length(btrim(coalesce(p_org, ''))) < 2 then raise exception 'Indiquez le nom de l''organisation'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Indiquez le poste ou la mission'; end if;
  if p_kind not in ('stage', 'emploi', 'mission', 'defi', 'benevolat', 'formation') then raise exception 'Type d''opportunité inconnu'; end if;
  if p_mode not in ('onsite', 'online', 'hybrid') then raise exception 'Mode inconnu'; end if;
  if p_pay_kind not in ('paid', 'unpaid', 'negotiable') then raise exception 'Rémunération inconnue'; end if;
  if p_deadline is not null and p_deadline < current_date then raise exception 'La date limite doit être dans le futur'; end if;
  if char_length(btrim(coalesce(p_description, ''))) < 20 then raise exception 'Décrivez l''offre en 20 caractères minimum'; end if;
  if coalesce(p_in_app, true) = false and btrim(coalesce(p_whatsapp, '')) = '' then raise exception 'Indiquez au moins un moyen de postuler (dans l''application ou par WhatsApp)'; end if;
  if (select count(*) from opportunities where poster_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix offres par jour au plus'; end if;
  select array_agg(btrim(x)) into v_skills from unnest(coalesce(p_skills, '{}'::text[])) x where char_length(btrim(x)) between 1 and 40;
  select array_agg(btrim(x)) into v_missions from unnest(coalesce(p_missions, '{}'::text[])) x where char_length(btrim(x)) between 2 and 200;
  select array_agg(btrim(x)) into v_gains from unnest(coalesce(p_gains, '{}'::text[])) x where char_length(btrim(x)) between 2 and 60;
  insert into opportunities (poster_id, org_name, kind, contract, title, location, mode, duration, pay_kind, pay_amount, pay_note, deadline, skills, description, missions, profile_wanted,
      department_target, level, gains, apply_whatsapp, apply_in_app, about_org, iut_only, verified, status)
    values (auth.uid(), btrim(p_org), p_kind, left(btrim(coalesce(p_contract, '')), 40), btrim(p_title), left(btrim(coalesce(p_location, '')), 80), p_mode, left(btrim(coalesce(p_duration, '')), 40), p_pay_kind,
      p_pay_amount, left(btrim(coalesce(p_pay_note, '')), 120), p_deadline, coalesce(v_skills, '{}'), btrim(p_description), coalesce(v_missions, '{}'), left(btrim(coalesce(p_profile, '')), 1000),
      left(btrim(coalesce(p_department, '')), 120), left(btrim(coalesce(p_level, '')), 60), coalesce(v_gains, '{}'), btrim(coalesce(p_whatsapp, '')), coalesce(p_in_app, true), left(btrim(coalesce(p_about, '')), 1000),
      coalesce(p_iut_only, false), v_staff, case when v_staff then 'published' else 'pending' end)
    returning id into v_id;
  if v_staff then
    perform _opp_alert_matching(v_id);
  else
    for r in select id from profiles where role::text = 'admin' loop
      perform notify_user(r.id, 'opportunity_review', 'Offre à valider', btrim(p_org) || ' propose « ' || btrim(p_title) || ' ».', jsonb_build_object('opportunity', v_id));
    end loop;
  end if;
  return v_id;
end $function$;

CREATE OR REPLACE FUNCTION public.save_mission(p_id uuid, p_title text, p_description text, p_budget_min integer, p_budget_max integer, p_deadline text, p_publish boolean, p_kind text DEFAULT 'besoin'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m missions%rowtype; mid uuid; st text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_publish then perform company_gate('need', p_id); end if;
  if coalesce(current_role_name()::text, '') not in ('client', 'company', 'other', 'student', 'dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if p_publish and (p_description is null or char_length(trim(p_description)) < 20) then raise exception 'Décrivez le besoin en 20 caractères minimum'; end if;
  if char_length(coalesce(p_description, '')) > 4000 then raise exception 'Description trop longue'; end if;
  if p_budget_min is not null and p_budget_min < 0 or p_budget_max is not null and p_budget_max < coalesce(p_budget_min, 0) then raise exception 'Budget invalide'; end if;
  if p_kind not in ('besoin', 'mission') then raise exception 'Type inconnu'; end if;
  st := case when p_publish then 'published' else 'draft' end;
  if p_id is null then
    insert into missions (number, client_id, kind, title, description, total, status, budget_min, budget_max, deadline)
    values ('#BR-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 1000000))::text, 6, '0'), auth.uid(), p_kind, trim(p_title),
            coalesce(trim(p_description), ''), coalesce(p_budget_max, p_budget_min, 0), st, p_budget_min, p_budget_max, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
    returning id into mid;
    return mid;
  end if;
  select * into m from missions where id = p_id and client_id = auth.uid();
  if not found then raise exception 'Besoin introuvable'; end if;
  if m.status not in ('draft', 'published') then raise exception 'Ce besoin est déjà attribué'; end if;
  update missions set title = trim(p_title), description = coalesce(trim(p_description), ''), budget_min = p_budget_min, budget_max = p_budget_max,
    total = coalesce(p_budget_max, p_budget_min, 0), deadline = nullif(left(trim(coalesce(p_deadline, '')), 60), ''), status = st, updated_at = now()
  where id = m.id;
  return m.id;
end $function$;
