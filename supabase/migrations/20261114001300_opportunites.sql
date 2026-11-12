-- Opportunités : offres de stage, d'emploi, de mission, de défi, de bénévolat et de formation publiées par des entreprises, ONG, startups ou l'IUT.
-- Distinct des concours (un concours se gagne avec un jury ; une opportunité est une offre à saisir). Publication soumise à validation ; badge « Vérifié » posé par l'équipe.
-- Candidature dans l'application ou par WhatsApp, favoris, rappel 2 jours avant la date limite, alerte par filière, recrutés (avec l'accord du candidat).
-- Retour arrière : drop des fonctions opp_* ; drop table opportunity_hires, opportunity_alerts, opportunity_reminders, opportunity_saves, opportunity_applications, opportunities.

create table if not exists opportunities (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references profiles(id) on delete cascade,
  org_name text not null check (char_length(btrim(org_name)) between 2 and 100),
  kind text not null check (kind in ('stage', 'emploi', 'mission', 'defi', 'benevolat', 'formation')),
  contract text not null default '' check (char_length(contract) <= 40),         -- académique, vacances, CDD, CDI, temps partiel, job étudiant…
  title text not null check (char_length(btrim(title)) between 3 and 120),
  location text not null default '' check (char_length(location) <= 80),
  mode text not null default 'onsite' check (mode in ('onsite', 'online', 'hybrid')),
  duration text not null default '' check (char_length(duration) <= 40),
  pay_kind text not null default 'negotiable' check (pay_kind in ('paid', 'unpaid', 'negotiable')),
  pay_amount integer check (pay_amount is null or (pay_amount >= 0 and pay_amount <= 100000000)),
  pay_note text not null default '' check (char_length(pay_note) <= 120),
  deadline date,
  skills text[] not null default '{}' check (cardinality(skills) <= 12),
  description text not null default '' check (char_length(description) <= 4000),
  missions text[] not null default '{}' check (cardinality(missions) <= 12),
  profile_wanted text not null default '' check (char_length(profile_wanted) <= 1000),
  department_target text not null default '' check (char_length(department_target) <= 120),
  level text not null default '' check (char_length(level) <= 60),
  gains text[] not null default '{}' check (cardinality(gains) <= 8),
  apply_whatsapp text not null default '' check (apply_whatsapp = '' or apply_whatsapp ~ '^\+?[0-9 ]{8,20}$'),
  apply_in_app boolean not null default true,
  about_org text not null default '' check (char_length(about_org) <= 1000),
  iut_only boolean not null default false,
  verified boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'published', 'rejected', 'closed')),
  review_note text check (review_note is null or char_length(review_note) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists opportunities_status on opportunities (status, created_at desc);
create index if not exists opportunities_deadline on opportunities (deadline);

create table if not exists opportunity_applications (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  applicant_id uuid not null references profiles(id) on delete cascade,
  message text not null default '' check (char_length(message) <= 3000),
  cv_link text not null default '' check (char_length(cv_link) <= 300),
  status text not null default 'sent' check (status in ('sent', 'viewed', 'shortlisted', 'rejected', 'hired')),
  created_at timestamptz not null default now(),
  unique (opportunity_id, applicant_id)
);
create table if not exists opportunity_saves (
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (opportunity_id, user_id)
);
create table if not exists opportunity_reminders (
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  notified boolean not null default false,
  primary key (opportunity_id, user_id)
);
create table if not exists opportunity_alerts (
  user_id uuid not null references profiles(id) on delete cascade,
  department text not null check (char_length(department) between 2 and 120),
  primary key (user_id, department)
);
create table if not exists opportunity_hires (
  application_id uuid primary key references opportunity_applications(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  org_name text not null,
  role_title text not null,
  department text not null default '',
  created_at timestamptz not null default now()
);
alter table opportunities enable row level security;
alter table opportunity_applications enable row level security;
alter table opportunity_saves enable row level security;
alter table opportunity_reminders enable row level security;
alter table opportunity_alerts enable row level security;
alter table opportunity_hires enable row level security;
revoke all on opportunities, opportunity_applications, opportunity_saves, opportunity_reminders, opportunity_alerts, opportunity_hires from anon, authenticated;

-- ---------------------------------------------------------------- publication (entreprises, ONG, startups, équipe) et validation
create or replace function opp_save(p_org text, p_kind text, p_contract text, p_title text, p_location text, p_mode text, p_duration text, p_pay_kind text, p_pay_amount integer, p_pay_note text,
  p_deadline date, p_skills text[], p_description text, p_missions text[], p_profile text, p_department text, p_level text, p_gains text[], p_whatsapp text, p_in_app boolean, p_about text, p_iut_only boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_role text := coalesce(current_role_name()::text, ''); v_staff boolean; v_skills text[]; v_missions text[]; v_gains text[]; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
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
end $$;

-- Alerte filière : les personnes qui suivent la filière visée (ou toutes les filières si l'offre n'en vise pas) sont prévenues d'une nouvelle offre.
create or replace function _opp_alert_matching(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; r record;
begin
  select * into o from opportunities where id = p_id;
  if not found then return; end if;
  for r in select distinct a.user_id from opportunity_alerts a
           where a.user_id <> o.poster_id and (o.department_target = '' or lower(o.department_target) like '%' || lower(a.department) || '%' or lower(a.department) like '%' || lower(o.department_target) || '%') limit 300 loop
    perform notify_user(r.user_id, 'opportunity_alert', 'Nouvelle offre pour votre filière', o.org_name || ' : ' || o.title, jsonb_build_object('opportunity', p_id));
  end loop;
end $$;
revoke all on function _opp_alert_matching(uuid) from public, anon, authenticated;

create or replace function opp_decide(p_id uuid, p_approve boolean, p_verified boolean default false, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  select * into o from opportunities where id = p_id;
  if not found then raise exception 'Offre introuvable'; end if;
  if not p_approve and char_length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'Indiquez le motif du refus'; end if;
  update opportunities set status = case when p_approve then 'published' else 'rejected' end, verified = case when p_approve then coalesce(p_verified, false) else false end, review_note = nullif(left(btrim(coalesce(p_note, '')), 500), '') where id = p_id;
  perform notify_user(o.poster_id, 'opportunity_review', case when p_approve then 'Offre publiée' else 'Offre refusée' end,
    case when p_approve then '« ' || o.title || ' » est visible des étudiants.' else '« ' || o.title || ' » n''a pas été validée : ' || left(btrim(p_note), 300) end, jsonb_build_object('opportunity', p_id));
  if p_approve and o.status <> 'published' then perform _opp_alert_matching(p_id); end if;
  return case when p_approve then 'published' else 'rejected' end;
end $$;

create or replace function opp_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update opportunities set status = 'closed' where id = p_id and (poster_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'dept'));
  if not found then raise exception 'Offre introuvable'; end if;
end $$;

-- ---------------------------------------------------------------- lecture
create or replace function _opp_card(o opportunities, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', o.id, 'org', o.org_name, 'verified', o.verified, 'kind', o.kind, 'contract', o.contract, 'title', o.title, 'location', o.location, 'mode', o.mode, 'duration', o.duration,
    'pay_kind', o.pay_kind, 'pay_amount', o.pay_amount, 'pay_note', o.pay_note, 'deadline', o.deadline, 'skills', to_jsonb(o.skills), 'department_target', o.department_target, 'iut_only', o.iut_only,
    'status', o.status, 'created_at', o.created_at, 'logo', (select pr.avatar_url from profiles pr where pr.id = o.poster_id),
    'saved', exists (select 1 from opportunity_saves s where s.opportunity_id = o.id and s.user_id = p_user),
    'applied', exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = p_user))
$$;
revoke all on function _opp_card(opportunities, uuid) from public, anon, authenticated;

-- Liste filtrée. p_section : null (tout), 'foryou' (ma filière), 'closing' (se termine dans 3 jours), 'new' (7 derniers jours), 'iut' (réservées à l'IUT), 'saved' (mes favoris).
-- Les rappels dus (2 jours avant la date limite) de la personne connectée sont envoyés à l'ouverture de la liste.
create or replace function opps_list(p_kind text default null, p_q text default null, p_mode text default null, p_paid_only boolean default false, p_iut_only boolean default false,
  p_department text default null, p_section text default null, p_limit integer default 40) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_dept text; r record;
begin
  if uid is not null then
    for r in select o.id, o.title, o.org_name from opportunity_reminders rm join opportunities o on o.id = rm.opportunity_id
             where rm.user_id = uid and not rm.notified and o.deadline is not null and o.deadline <= current_date + 2 and o.deadline >= current_date and o.status = 'published' loop
      insert into notifications (user_id, kind, title, body, data)
      values (uid, 'opportunity_reminder', 'Rappel : la date limite approche', left(r.org_name || ' : ' || r.title || ' se termine bientôt.', 500), jsonb_build_object('opportunity', r.id));
      update opportunity_reminders set notified = true where opportunity_id = r.id and user_id = uid;
    end loop;
    select lower(coalesce(department, '')) into v_dept from profiles where id = uid;
  end if;
  return coalesce((select jsonb_agg(c order by (c->>'pay_kind' = 'paid') desc, (c->>'deadline') nulls last, c->>'created_at' desc) from (
    select _opp_card(o, uid) c from opportunities o
    where o.status = 'published' and (o.deadline is null or o.deadline >= current_date)
      and (nullif(btrim(coalesce(p_kind, '')), '') is null or o.kind = p_kind)
      and (nullif(btrim(coalesce(p_mode, '')), '') is null or o.mode = p_mode)
      and (not coalesce(p_paid_only, false) or o.pay_kind = 'paid')
      and (not coalesce(p_iut_only, false) or o.iut_only)
      and (nullif(btrim(coalesce(p_department, '')), '') is null or o.department_target = '' or lower(o.department_target) like '%' || lower(btrim(p_department)) || '%')
      and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(o.title || ' ' || o.org_name || ' ' || o.description || ' ' || array_to_string(o.skills, ' ') || ' ' || o.location) like '%' || lower(btrim(p_q)) || '%')
      and case coalesce(p_section, '')
            when 'foryou' then coalesce(v_dept, '') <> '' and (o.department_target = '' or lower(o.department_target) like '%' || v_dept || '%' or v_dept like '%' || lower(o.department_target) || '%')
            when 'closing' then o.deadline is not null and o.deadline <= current_date + 3
            when 'new' then o.created_at > now() - interval '7 days'
            when 'iut' then o.iut_only
            when 'saved' then exists (select 1 from opportunity_saves s where s.opportunity_id = o.id and s.user_id = uid)
            else true end
    limit least(greatest(coalesce(p_limit, 40), 1), 100)) x), '[]'::jsonb);
end $$;

create or replace function opp_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; uid uuid := auth.uid();
begin
  select * into o from opportunities where id = p_id;
  if not found or (o.status <> 'published' and o.poster_id is distinct from uid and coalesce(current_role_name()::text, '') not in ('admin', 'dept')) then raise exception 'Offre introuvable'; end if;
  return _opp_card(o, uid) || jsonb_build_object('description', o.description, 'missions', to_jsonb(o.missions), 'profile_wanted', o.profile_wanted, 'level', o.level, 'gains', to_jsonb(o.gains),
    'apply_whatsapp', o.apply_whatsapp, 'apply_in_app', o.apply_in_app, 'about_org', o.about_org, 'mine', o.poster_id = uid, 'review_note', o.review_note,
    'my_application', (select to_jsonb(a) - 'opportunity_id' - 'applicant_id' - 'message' from (select id, status, created_at from opportunity_applications where opportunity_id = p_id and applicant_id = uid) a),
    'reminder', exists (select 1 from opportunity_reminders r where r.opportunity_id = p_id and r.user_id = uid),
    'other_offers', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind)) from (select id, title, kind from opportunities where poster_id = o.poster_id and id <> p_id and status in ('published', 'closed') order by created_at desc limit 5) x), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------- candidature
create or replace function opp_apply(p_id uuid, p_message text, p_cv_link text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_id uuid; v_inst text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_id and status = 'published';
  if not found or (o.deadline is not null and o.deadline < current_date) then raise exception 'Cette offre n''accepte plus de candidatures'; end if;
  if not o.apply_in_app then raise exception 'Cette offre se postule uniquement par WhatsApp'; end if;
  if o.poster_id = auth.uid() then raise exception 'C''est votre propre offre'; end if;
  select coalesce(institution, '') into v_inst from profiles where id = auth.uid();
  if o.iut_only and lower(v_inst) not like '%iut%' then raise exception 'Offre réservée aux étudiants de l''IUT'; end if;
  if char_length(btrim(coalesce(p_message, ''))) < 20 then raise exception 'Écrivez votre lettre de motivation (20 caractères minimum)'; end if;
  if char_length(btrim(coalesce(p_cv_link, ''))) > 0 and btrim(p_cv_link) !~* '^https?://' then raise exception 'Le lien du CV doit commencer par http'; end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_id and applicant_id = auth.uid()) then raise exception 'Vous avez déjà postulé'; end if;
  insert into opportunity_applications (opportunity_id, applicant_id, message, cv_link) values (p_id, auth.uid(), btrim(p_message), btrim(coalesce(p_cv_link, ''))) returning id into v_id;
  perform notify_user(o.poster_id, 'opportunity_application', 'Nouvelle candidature', display_name(auth.uid()) || ' postule à « ' || left(o.title, 60) || ' ».', jsonb_build_object('opportunity', p_id, 'application', v_id));
  return v_id;
end $$;

create or replace function opp_my_applications() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'status', a.status, 'created_at', a.created_at, 'opportunity_id', o.id, 'title', o.title, 'org', o.org_name,
      'published', exists (select 1 from opportunity_hires h where h.application_id = a.id)) order by a.created_at desc), '[]'::jsonb)
  from opportunity_applications a join opportunities o on o.id = a.opportunity_id where a.applicant_id = auth.uid()
$$;

-- Offres que j'ai publiées, avec le nombre de candidatures ; l'équipe voit aussi les offres à valider.
create or replace function opp_my_posted() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(_opp_card(o, auth.uid()) || jsonb_build_object('applications', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id),
      'review_note', o.review_note, 'description', o.description, 'poster', display_name(o.poster_id)) order by (o.status = 'pending') desc, o.created_at desc)
    from opportunities o where o.poster_id = auth.uid() or (v_staff and o.status = 'pending')), '[]'::jsonb);
end $$;

create or replace function opp_applications_for(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from opportunities where id = p_id and poster_id = auth.uid()) then raise exception 'Offre introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'applicant_id', a.applicant_id, 'name', display_name(a.applicant_id), 'department', pr.department, 'message', a.message, 'cv_link', a.cv_link,
      'status', a.status, 'created_at', a.created_at) order by a.created_at desc)
    from opportunity_applications a join profiles pr on pr.id = a.applicant_id where a.opportunity_id = p_id), '[]'::jsonb);
end $$;

create or replace function opp_application_decide(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status not in ('viewed', 'shortlisted', 'rejected', 'hired') then raise exception 'Statut inconnu'; end if;
  select * into a from opportunity_applications where id = p_id;
  if not found then raise exception 'Candidature introuvable'; end if;
  select * into o from opportunities where id = a.opportunity_id and poster_id = auth.uid();
  if not found then raise exception 'Candidature introuvable'; end if;
  update opportunity_applications set status = p_status where id = p_id;
  perform notify_user(a.applicant_id, 'opportunity_application', case p_status when 'hired' then 'Félicitations !' when 'shortlisted' then 'Candidature retenue' when 'rejected' then 'Candidature non retenue' else 'Candidature consultée' end,
    o.org_name || ' : ' || left(o.title, 60), jsonb_build_object('opportunity', o.id, 'application', p_id));
end $$;

-- ---------------------------------------------------------------- favoris, rappel, alerte filière
create or replace function opp_save_toggle(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from opportunities where id = p_id and status = 'published') then raise exception 'Offre introuvable'; end if;
  if exists (select 1 from opportunity_saves where opportunity_id = p_id and user_id = auth.uid()) then
    delete from opportunity_saves where opportunity_id = p_id and user_id = auth.uid();
    return false;
  end if;
  insert into opportunity_saves (opportunity_id, user_id) values (p_id, auth.uid());
  return true;
end $$;

create or replace function opp_remind(p_id uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_on, true) then
    if not exists (select 1 from opportunities where id = p_id and status = 'published' and deadline is not null) then raise exception 'Cette offre n''a pas de date limite'; end if;
    insert into opportunity_reminders (opportunity_id, user_id) values (p_id, auth.uid()) on conflict do nothing;
  else
    delete from opportunity_reminders where opportunity_id = p_id and user_id = auth.uid();
  end if;
end $$;

create or replace function opp_alert_set(p_department text, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_department, ''))) < 2 then raise exception 'Indiquez votre filière dans votre profil'; end if;
  if coalesce(p_on, true) then insert into opportunity_alerts (user_id, department) values (auth.uid(), btrim(p_department)) on conflict do nothing;
  else delete from opportunity_alerts where user_id = auth.uid() and lower(department) = lower(btrim(p_department));
  end if;
end $$;

create or replace function opp_my_alert() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from opportunity_alerts where user_id = auth.uid())
$$;

-- ---------------------------------------------------------------- « Ils ont été recrutés » (avec l'accord du candidat)
create or replace function opp_hire_publish(p_application uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from opportunity_applications where id = p_application and applicant_id = auth.uid();
  if not found then raise exception 'Candidature introuvable'; end if;
  if a.status <> 'hired' then raise exception 'Vous pourrez partager votre recrutement une fois retenu(e) par l''organisation'; end if;
  select * into o from opportunities where id = a.opportunity_id;
  select coalesce(department, '') into v_dept from profiles where id = auth.uid();
  insert into opportunity_hires (application_id, student_id, org_name, role_title, department) values (p_application, auth.uid(), o.org_name, o.title, v_dept) on conflict do nothing;
end $$;

create or replace function opp_hired_list(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', display_name(h.student_id), 'department', h.department, 'org', h.org_name, 'role', h.role_title, 'created_at', h.created_at) order by h.created_at desc), '[]'::jsonb)
  from (select * from opportunity_hires order by created_at desc limit least(greatest(coalesce(p_limit, 10), 1), 30)) h
$$;

revoke all on function opp_save(text, text, text, text, text, text, text, text, integer, text, date, text[], text, text[], text, text, text, text[], text, boolean, text, boolean),
  opp_decide(uuid, boolean, boolean, text), opp_close(uuid), opp_apply(uuid, text, text), opp_my_applications(), opp_my_posted(), opp_applications_for(uuid), opp_application_decide(uuid, text),
  opp_save_toggle(uuid), opp_remind(uuid, boolean), opp_alert_set(text, boolean), opp_my_alert(), opp_hire_publish(uuid) from public, anon;
grant execute on function opp_save(text, text, text, text, text, text, text, text, integer, text, date, text[], text, text[], text, text, text, text[], text, boolean, text, boolean),
  opp_decide(uuid, boolean, boolean, text), opp_close(uuid), opp_apply(uuid, text, text), opp_my_applications(), opp_my_posted(), opp_applications_for(uuid), opp_application_decide(uuid, text),
  opp_save_toggle(uuid), opp_remind(uuid, boolean), opp_alert_set(text, boolean), opp_my_alert(), opp_hire_publish(uuid) to authenticated;
revoke all on function opps_list(text, text, text, boolean, boolean, text, text, integer), opp_detail(uuid), opp_hired_list(integer) from public;
grant execute on function opps_list(text, text, text, boolean, boolean, text, text, integer), opp_detail(uuid), opp_hired_list(integer) to anon, authenticated;
