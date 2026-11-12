-- Annonces de concours, bourses, hackathons et appels à projets (français, africains ou internationaux) : fiche complète pour décider en 10 secondes.
-- Distinct des hackathons organisés par l'IUT (tables contests*, équipes et jury) et des opportunités (offres de stage ou d'emploi).
-- Publication par l'équipe, les départements, les entreprises et ONG, après validation ; badge « Vérifié » posé par l'équipe ; rappel 3 jours avant la date limite ;
-- section « Ils ont gagné » : un étudiant de l'IUT déclare son prix avec une preuve, l'équipe valide avant publication.
-- Retour arrière : drop function ann_* ; drop table contest_ann_wins, contest_ann_reminders, contest_ann_saves, contest_announcements.

create table if not exists contest_announcements (
  id uuid primary key default gen_random_uuid(),
  poster_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 140),
  organizer text not null check (char_length(btrim(organizer)) between 2 and 100),
  organizer_kind text not null default 'other' check (organizer_kind in ('university', 'company', 'ngo', 'government', 'other')),
  country text not null default '' check (char_length(country) <= 60),       -- Cameroun, Afrique, International…
  place_kind text not null default 'online' check (place_kind in ('online', 'onsite', 'hybrid')),
  place text not null default '' check (char_length(place) <= 100),
  domain text not null default 'tech' check (domain in ('tech', 'entrepreneurship', 'design', 'agriculture', 'health', 'environment', 'scholarship', 'other')),
  kind text not null check (kind in ('contest', 'scholarship', 'hackathon', 'call', 'internship', 'job', 'training')),
  description text not null default '' check (char_length(description) <= 4000),
  why text not null default '' check (char_length(why) <= 1000),             -- pourquoi ça existe, quel problème ça résout
  conditions text[] not null default '{}' check (cardinality(conditions) <= 12),
  documents text[] not null default '{}' check (cardinality(documents) <= 10),
  steps text[] not null default '{}' check (cardinality(steps) <= 10),
  criteria text[] not null default '{}' check (cardinality(criteria) <= 10),
  opens_on date,
  deadline date,
  results_on date,
  program_start date,
  reward text not null default '' check (char_length(reward) <= 200),        -- « 500 000 FCFA », « Bourse complète », « Voyage », « Matériel »…
  eligible_level text not null default '' check (char_length(eligible_level) <= 80),
  eligible_age text not null default '' check (char_length(eligible_age) <= 40),
  eligible_department text not null default '' check (char_length(eligible_department) <= 120),
  eligible_country text not null default '' check (char_length(eligible_country) <= 80),
  iut_only boolean not null default false,
  free boolean not null default true,
  cost_amount integer check (cost_amount is null or (cost_amount >= 0 and cost_amount <= 100000000)),
  cost_currency text not null default 'FCFA' check (cost_currency in ('FCFA', 'EUR', 'USD')),
  official_url text not null check (official_url ~* '^https?://[^ ]+\.[^ ]+'),
  verified boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'published', 'rejected', 'closed')),
  review_note text check (review_note is null or char_length(review_note) <= 500),
  views integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists contest_ann_status on contest_announcements (status, created_at desc);
create index if not exists contest_ann_deadline on contest_announcements (deadline);

create table if not exists contest_ann_saves (
  announcement_id uuid not null references contest_announcements(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (announcement_id, user_id)
);
create table if not exists contest_ann_reminders (
  announcement_id uuid not null references contest_announcements(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  notified boolean not null default false,
  primary key (announcement_id, user_id)
);
create table if not exists contest_ann_wins (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  contest_title text not null check (char_length(btrim(contest_title)) between 3 and 140),
  announcement_id uuid references contest_announcements(id) on delete set null,
  prize text not null default '' check (char_length(prize) <= 120),
  year integer check (year is null or year between 2000 and 2100),
  proof_url text not null check (proof_url ~* '^https?://[^ ]+\.[^ ]+'),
  status text not null default 'pending' check (status in ('pending', 'published', 'rejected')),
  created_at timestamptz not null default now()
);
alter table contest_announcements enable row level security;
alter table contest_ann_saves enable row level security;
alter table contest_ann_reminders enable row level security;
alter table contest_ann_wins enable row level security;
revoke all on contest_announcements, contest_ann_saves, contest_ann_reminders, contest_ann_wins from anon, authenticated;

-- ---------------------------------------------------------------- publication et validation
create or replace function ann_save(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept'); v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
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
end $$;

create or replace function ann_decide(p_id uuid, p_approve boolean, p_verified boolean default false, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  select * into a from contest_announcements where id = p_id;
  if not found then raise exception 'Annonce introuvable'; end if;
  if not p_approve and char_length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'Indiquez le motif du refus'; end if;
  update contest_announcements set status = case when p_approve then 'published' else 'rejected' end, verified = case when p_approve then coalesce(p_verified, false) else false end,
    review_note = nullif(left(btrim(coalesce(p_note, '')), 500), '') where id = p_id;
  perform notify_user(a.poster_id, 'contest_review', case when p_approve then 'Annonce publiée' else 'Annonce refusée' end,
    case when p_approve then '« ' || a.title || ' » est visible des étudiants.' else '« ' || a.title || ' » n''a pas été validée : ' || left(btrim(p_note), 300) end, jsonb_build_object('announcement', p_id));
  return case when p_approve then 'published' else 'rejected' end;
end $$;

create or replace function ann_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update contest_announcements set status = 'closed' where id = p_id and (poster_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'dept'));
  if not found then raise exception 'Annonce introuvable'; end if;
end $$;

-- ---------------------------------------------------------------- lecture
create or replace function _ann_card(a contest_announcements, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', a.id, 'title', a.title, 'organizer', a.organizer, 'organizer_kind', a.organizer_kind, 'country', a.country, 'place_kind', a.place_kind, 'place', a.place, 'domain', a.domain, 'kind', a.kind,
    'deadline', a.deadline, 'reward', a.reward, 'eligible_level', a.eligible_level, 'eligible_age', a.eligible_age, 'eligible_department', a.eligible_department, 'eligible_country', a.eligible_country, 'iut_only', a.iut_only,
    'free', a.free, 'cost_amount', a.cost_amount, 'cost_currency', a.cost_currency, 'verified', a.verified, 'status', a.status, 'created_at', a.created_at,
    'popular', (select count(*) from contest_ann_saves s where s.announcement_id = a.id) >= 5 or a.views >= 100,
    'saved', exists (select 1 from contest_ann_saves s where s.announcement_id = a.id and s.user_id = p_user))
$$;
revoke all on function _ann_card(contest_announcements, uuid) from public, anon, authenticated;

-- Filtres : pays (texte), domaine, gratuit ou payant, en ligne ou présentiel, date limite (jours), mot-clé ; p_saved = mes enregistrés.
create or replace function anns_list(p_q text default null, p_country text default null, p_domain text default null, p_free text default null, p_place text default null,
  p_within_days integer default null, p_kind text default null, p_saved boolean default false, p_limit integer default 40) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); r record;
begin
  if uid is not null then
    for r in select a.id, a.title from contest_ann_reminders rm join contest_announcements a on a.id = rm.announcement_id
             where rm.user_id = uid and not rm.notified and a.deadline is not null and a.deadline <= current_date + 3 and a.deadline >= current_date and a.status = 'published' loop
      insert into notifications (user_id, kind, title, body, data)
      values (uid, 'contest_reminder', 'Rappel : la date limite approche', left('« ' || r.title || ' » se termine dans moins de 3 jours.', 500), jsonb_build_object('announcement', r.id));
      update contest_ann_reminders set notified = true where announcement_id = r.id and user_id = uid;
    end loop;
  end if;
  return coalesce((select jsonb_agg(c order by (c->>'deadline') nulls last, c->>'created_at' desc) from (
    select _ann_card(a, uid) c from contest_announcements a
    where a.status = 'published' and (a.deadline is null or a.deadline >= current_date)
      and (nullif(btrim(coalesce(p_kind, '')), '') is null or a.kind = p_kind)
      and (nullif(btrim(coalesce(p_domain, '')), '') is null or a.domain = p_domain)
      and (nullif(btrim(coalesce(p_place, '')), '') is null or a.place_kind = p_place)
      and (nullif(btrim(coalesce(p_country, '')), '') is null or lower(a.country) like '%' || lower(btrim(p_country)) || '%')
      and (nullif(btrim(coalesce(p_free, '')), '') is null or a.free = (p_free = 'free'))
      and (p_within_days is null or (a.deadline is not null and a.deadline <= current_date + p_within_days))
      and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(a.title || ' ' || a.organizer || ' ' || a.description || ' ' || a.country || ' ' || a.reward) like '%' || lower(btrim(p_q)) || '%')
      and (not coalesce(p_saved, false) or exists (select 1 from contest_ann_saves s where s.announcement_id = a.id and s.user_id = uid))
    limit least(greatest(coalesce(p_limit, 40), 1), 100)) x), '[]'::jsonb);
end $$;

create or replace function ann_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype; uid uuid := auth.uid();
begin
  select * into a from contest_announcements where id = p_id;
  if not found or (a.status <> 'published' and a.poster_id is distinct from uid and coalesce(current_role_name()::text, '') not in ('admin', 'dept')) then raise exception 'Annonce introuvable'; end if;
  if a.status = 'published' then update contest_announcements set views = views + 1 where id = p_id; end if;
  return _ann_card(a, uid) || jsonb_build_object('description', a.description, 'why', a.why, 'conditions', to_jsonb(a.conditions), 'documents', to_jsonb(a.documents), 'steps', to_jsonb(a.steps), 'criteria', to_jsonb(a.criteria),
    'opens_on', a.opens_on, 'results_on', a.results_on, 'program_start', a.program_start, 'official_url', a.official_url, 'mine', a.poster_id = uid, 'review_note', a.review_note,
    'reminder', exists (select 1 from contest_ann_reminders r where r.announcement_id = p_id and r.user_id = uid));
end $$;

create or replace function ann_my_posted() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(_ann_card(a, auth.uid()) || jsonb_build_object('poster', display_name(a.poster_id), 'review_note', a.review_note) order by (a.status = 'pending') desc, a.created_at desc)
    from contest_announcements a where a.poster_id = auth.uid() or (v_staff and a.status = 'pending')), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------- enregistrer, rappel
create or replace function ann_save_toggle(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from contest_announcements where id = p_id and status = 'published') then raise exception 'Annonce introuvable'; end if;
  if exists (select 1 from contest_ann_saves where announcement_id = p_id and user_id = auth.uid()) then
    delete from contest_ann_saves where announcement_id = p_id and user_id = auth.uid();
    return false;
  end if;
  insert into contest_ann_saves (announcement_id, user_id) values (p_id, auth.uid());
  return true;
end $$;

create or replace function ann_remind(p_id uuid, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_on, true) then
    if not exists (select 1 from contest_announcements where id = p_id and status = 'published' and deadline is not null) then raise exception 'Cette annonce n''a pas de date limite'; end if;
    insert into contest_ann_reminders (announcement_id, user_id) values (p_id, auth.uid()) on conflict do nothing;
  else
    delete from contest_ann_reminders where announcement_id = p_id and user_id = auth.uid();
  end if;
end $$;

-- ---------------------------------------------------------------- « Ils ont gagné »
create or replace function ann_win_submit(p_title text, p_prize text, p_year integer, p_proof text, p_announcement uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Indiquez le nom du concours gagné'; end if;
  if coalesce(p_proof, '') !~* '^https?://[^ ]+\.[^ ]+' then raise exception 'Joignez un lien de preuve (article, photo, page officielle)'; end if;
  if (select count(*) from contest_ann_wins where student_id = auth.uid() and created_at > now() - interval '1 day') >= 3 then raise exception 'Trois déclarations par jour au plus'; end if;
  insert into contest_ann_wins (student_id, contest_title, announcement_id, prize, year, proof_url) values (auth.uid(), btrim(p_title), p_announcement, left(btrim(coalesce(p_prize, '')), 120), p_year, btrim(p_proof)) returning id into v_id;
  for r in select id from profiles where role::text = 'admin' loop
    perform notify_user(r.id, 'contest_review', 'Victoire à valider', display_name(auth.uid()) || ' déclare avoir gagné « ' || btrim(p_title) || ' ».', jsonb_build_object('win', v_id));
  end loop;
  return v_id;
end $$;

create or replace function ann_win_decide(p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
declare w contest_ann_wins%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  select * into w from contest_ann_wins where id = p_id;
  if not found then raise exception 'Déclaration introuvable'; end if;
  update contest_ann_wins set status = case when p_approve then 'published' else 'rejected' end where id = p_id;
  perform notify_user(w.student_id, 'contest_review', case when p_approve then 'Victoire publiée' else 'Victoire non retenue' end, '« ' || w.contest_title || ' »', jsonb_build_object('win', p_id));
end $$;

create or replace function ann_wins_list(p_limit integer default 10, p_pending boolean default false) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(p_pending, false) and coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'name', display_name(w.student_id), 'department', (select department from profiles where id = w.student_id), 'title', w.contest_title, 'prize', w.prize,
      'year', w.year, 'proof_url', w.proof_url, 'created_at', w.created_at) order by w.created_at desc)
    from (select * from contest_ann_wins where status = case when coalesce(p_pending, false) then 'pending' else 'published' end order by created_at desc limit least(greatest(coalesce(p_limit, 10), 1), 50)) w), '[]'::jsonb);
end $$;

revoke all on function ann_save(jsonb), ann_decide(uuid, boolean, boolean, text), ann_close(uuid), ann_my_posted(), ann_save_toggle(uuid), ann_remind(uuid, boolean), ann_win_submit(text, text, integer, text, uuid), ann_win_decide(uuid, boolean) from public, anon;
grant execute on function ann_save(jsonb), ann_decide(uuid, boolean, boolean, text), ann_close(uuid), ann_my_posted(), ann_save_toggle(uuid), ann_remind(uuid, boolean), ann_win_submit(text, text, integer, text, uuid), ann_win_decide(uuid, boolean) to authenticated;
revoke all on function anns_list(text, text, text, text, text, integer, text, boolean, integer), ann_detail(uuid), ann_wins_list(integer, boolean) from public;
grant execute on function anns_list(text, text, text, text, text, integer, text, boolean, integer), ann_detail(uuid), ann_wins_list(integer, boolean) to anon, authenticated;
