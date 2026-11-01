-- Concours et hackathons réels (écrans 160 à 169, 178), selon REGLES_METIER_PROPOSEES.md § 1.
-- Publication par le département ou l'administrateur ; inscription des étudiants (individuelle ou équipe de 2 à 5) ;
-- dépôt par le capitaine avant l'échéance ; jurés désignés par concours, notes sur 4 critères (/10, total /40) ;
-- résultats publiés seulement si chaque projet a au moins 2 notes. Aucun prix n'est « payé » par la plateforme.
-- Aucune donnée existante n'est modifiée.

-- 1. Tables ---------------------------------------------------------------------------------------------------------
create table if not exists contests (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '' check (char_length(description) <= 4000),
  theme text not null default '' check (char_length(theme) <= 200),
  rules text not null default '' check (char_length(rules) <= 8000),
  city text not null default 'En ligne' check (char_length(city) between 2 and 80),
  reg_close_at timestamptz not null,
  submit_close_at timestamptz not null,
  starts_on date,
  ends_on date,
  prize integer not null default 0 check (prize between 0 and 1000000000),
  places integer not null check (places between 1 and 1000),
  status text not null default 'draft' check (status in ('draft', 'published', 'judging', 'results', 'cancelled')),
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint contests_dates check (submit_close_at >= reg_close_at and (ends_on is null or starts_on is null or ends_on >= starts_on))
);

create table if not exists contest_teams (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references contests(id) on delete cascade,
  name text not null check (char_length(name) between 3 and 60),
  theme text not null default '' check (char_length(theme) <= 120),
  captain_id uuid not null references profiles(id) on delete cascade,
  solo boolean not null default false,
  rules_accepted_at timestamptz not null,
  hidden boolean not null default false,
  hidden_reason text,
  created_at timestamptz not null default now()
);
create unique index if not exists contest_teams_nom on contest_teams (contest_id, lower(name));

create table if not exists contest_members (
  team_id uuid not null references contest_teams(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'invited' check (status in ('captain', 'member', 'invited')),
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create table if not exists contest_submissions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null unique references contest_teams(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  description text not null check (char_length(description) between 30 and 4000),
  demo_url text check (demo_url is null or demo_url ~ '^https?://[^\s]+\.[^\s]+'),
  video_url text check (video_url is null or video_url ~ '^https?://[^\s]+\.[^\s]+'),
  deck_path text check (deck_path is null or char_length(deck_path) <= 300),
  original_certified boolean not null check (original_certified),
  submitted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists contest_jurors (
  contest_id uuid not null references contests(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (contest_id, user_id)
);

create table if not exists contest_scores (
  submission_id uuid not null references contest_submissions(id) on delete cascade,
  juror_id uuid not null references profiles(id) on delete cascade,
  innovation smallint not null check (innovation between 0 and 10),
  feasibility smallint not null check (feasibility between 0 and 10),
  impact smallint not null check (impact between 0 and 10),
  pitch smallint not null check (pitch between 0 and 10),
  comment text check (comment is null or char_length(comment) <= 2000),
  updated_at timestamptz not null default now(),
  primary key (submission_id, juror_id)
);

-- 2. Fonctions d'appartenance (SECURITY DEFINER : utilisées par la RLS sans récursion) --------------------------------
create or replace function is_contest_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and coalesce(current_role_name()::text, '') in ('dept', 'admin')
$$;

create or replace function is_contest_member(p_team uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from contest_members where team_id = p_team and user_id = auth.uid() and status in ('captain', 'member'))
$$;

create or replace function is_contest_juror(p_contest uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from contest_jurors where contest_id = p_contest and user_id = auth.uid())
$$;

-- 3. RLS : lecture seulement ; toute écriture passe par les fonctions ci-dessous ------------------------------------------
alter table contests enable row level security;
alter table contest_teams enable row level security;
alter table contest_members enable row level security;
alter table contest_submissions enable row level security;
alter table contest_jurors enable row level security;
alter table contest_scores enable row level security;
revoke all on contests, contest_teams, contest_members, contest_submissions, contest_jurors, contest_scores from anon, authenticated;
grant select on contests to anon, authenticated;
grant select on contest_teams, contest_members, contest_submissions, contest_jurors, contest_scores to authenticated;

drop policy if exists "concours visibles" on contests;
create policy "concours visibles" on contests for select using (status <> 'draft' or is_contest_staff());
drop policy if exists "équipes visibles" on contest_teams;
create policy "équipes visibles" on contest_teams for select using (not hidden or captain_id = auth.uid() or is_contest_staff());
drop policy if exists "membres visibles" on contest_members;
create policy "membres visibles" on contest_members for select using (user_id = auth.uid() or is_contest_member(team_id) or is_contest_staff());
drop policy if exists "dépôts : équipe, jury, département" on contest_submissions;
create policy "dépôts : équipe, jury, département" on contest_submissions for select
  using (is_contest_member(team_id) or is_contest_staff()
         or (submitted and is_contest_juror((select t.contest_id from contest_teams t where t.id = team_id))));
drop policy if exists "jurés visibles du département et d'eux-mêmes" on contest_jurors;
create policy "jurés visibles du département et d'eux-mêmes" on contest_jurors for select using (user_id = auth.uid() or is_contest_staff());
drop policy if exists "notes : juré, département, équipe après résultats" on contest_scores;
create policy "notes : juré, département, équipe après résultats" on contest_scores for select
  using (juror_id = auth.uid() or is_contest_staff()
         or exists (select 1 from contest_submissions s join contest_teams t on t.id = s.team_id join contests c on c.id = t.contest_id
                    where s.id = submission_id and c.status = 'results' and is_contest_member(t.id)));

-- 4. Classement : moyenne des jurés ; départage Innovation, Impact, heure du dépôt -------------------------------------
create or replace function contest_ranking(p_contest uuid)
returns table (rank integer, team_name text, project text, total numeric, innovation numeric, impact numeric, notes integer)
language sql stable security definer set search_path = public as $$
  with agg as (
    select t.name, s.title, s.updated_at,
           avg(sc.innovation + sc.feasibility + sc.impact + sc.pitch)::numeric(5,2) as total,
           avg(sc.innovation)::numeric(4,2) as innovation, avg(sc.impact)::numeric(4,2) as impact, count(sc.juror_id)::int as notes
    from contest_submissions s
    join contest_teams t on t.id = s.team_id and not t.hidden
    left join contest_scores sc on sc.submission_id = s.id
    where t.contest_id = p_contest and s.submitted
    group by t.name, s.title, s.updated_at
  )
  select (row_number() over (order by total desc nulls last, innovation desc nulls last, impact desc nulls last, updated_at))::int,
         name, title, total, innovation, impact, notes
  from agg
  where exists (select 1 from contests c where c.id = p_contest and (c.status = 'results' or is_contest_staff() or is_contest_juror(c.id)))
  order by 1
$$;

-- 5. Publication et modification (département, administrateur) -----------------------------------------------------
create or replace function save_contest(p_id uuid, p_title text, p_description text, p_theme text, p_rules text, p_city text,
  p_reg_close timestamptz, p_submit_close timestamptz, p_starts date, p_ends date, p_prize integer, p_places integer, p_publish boolean)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c contests%rowtype; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_contest_staff() then raise exception 'Publication réservée au département ou à l''administrateur'; end if;
  if p_reg_close is null or p_submit_close is null then raise exception 'Dates de clôture obligatoires'; end if;
  if p_publish and (p_reg_close <= now()) then raise exception 'La clôture des inscriptions doit être future'; end if;
  if p_publish and char_length(coalesce(trim(p_description), '')) < 30 then raise exception 'Décrivez le concours (30 caractères minimum)'; end if;
  if p_id is null then
    insert into contests (title, description, theme, rules, city, reg_close_at, submit_close_at, starts_on, ends_on, prize, places, status, created_by)
    values (trim(p_title), coalesce(trim(p_description), ''), coalesce(trim(p_theme), ''), coalesce(trim(p_rules), ''), coalesce(nullif(trim(p_city), ''), 'En ligne'),
            p_reg_close, p_submit_close, p_starts, p_ends, coalesce(p_prize, 0), p_places, case when p_publish then 'published' else 'draft' end, auth.uid())
    returning id into cid;
  else
    select * into c from contests where id = p_id for update;
    if not found then raise exception 'Concours introuvable'; end if;
    if c.status in ('results', 'cancelled') then raise exception 'Concours terminé : modification impossible'; end if;
    if c.status <> 'draft' then
      -- après publication : dates seulement prolongées, dotation et places seulement augmentées
      if p_reg_close < c.reg_close_at or p_submit_close < c.submit_close_at then raise exception 'Après publication, les dates ne peuvent qu''être prolongées'; end if;
      if coalesce(p_prize, 0) < c.prize then raise exception 'Après publication, la dotation ne peut qu''augmenter'; end if;
      if p_places < c.places then raise exception 'Après publication, le nombre de places ne peut qu''augmenter'; end if;
    end if;
    update contests set title = trim(p_title), description = coalesce(trim(p_description), ''), theme = coalesce(trim(p_theme), ''), rules = coalesce(trim(p_rules), ''),
      city = coalesce(nullif(trim(p_city), ''), 'En ligne'), reg_close_at = p_reg_close, submit_close_at = p_submit_close, starts_on = p_starts, ends_on = p_ends,
      prize = coalesce(p_prize, 0), places = p_places, status = case when c.status = 'draft' and p_publish then 'published' else c.status end, updated_at = now()
    where id = c.id;
    cid := c.id;
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case when p_id is null then 'Concours créé' else 'Concours modifié' end, trim(p_title), 'Concours', 'Sensible');
  return cid;
end $$;

create or replace function set_contest_status(p_contest uuid, p_status text) returns text
language plpgsql security definer set search_path = public as $$
declare c contests%rowtype; missing int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_contest_staff() then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into c from contests where id = p_contest for update;
  if not found then raise exception 'Concours introuvable'; end if;
  if not ((c.status = 'published' and p_status in ('judging', 'cancelled'))
       or (c.status = 'judging' and p_status in ('results', 'cancelled'))
       or (c.status = 'draft' and p_status = 'cancelled')) then
    raise exception 'Transition non autorisée (% vers %)', c.status, p_status;
  end if;
  if p_status = 'judging' and now() < c.submit_close_at then raise exception 'Le jury commence après la clôture des dépôts'; end if;
  if p_status = 'results' then
    select count(*) into missing from contest_submissions s join contest_teams t on t.id = s.team_id
      where t.contest_id = c.id and s.submitted and not t.hidden and (select count(*) from contest_scores x where x.submission_id = s.id) < 2;
    if missing > 0 then raise exception 'Résultats impossibles : % projet(s) ont moins de 2 notes', missing; end if;
  end if;
  update contests set status = p_status, updated_at = now() where id = c.id;
  insert into notifications (user_id, kind, title, body, data)
    select distinct m.user_id, 'contest',
      case p_status when 'results' then 'Résultats publiés' when 'cancelled' then 'Concours annulé' else 'Délibération du jury' end,
      c.title, jsonb_build_object('contest_id', c.id, 'status', p_status)
    from contest_members m join contest_teams t on t.id = m.team_id where t.contest_id = c.id and m.status in ('captain', 'member');
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Concours : ' || c.status || ' → ' || p_status, c.title, 'Concours', 'Sensible');
  return p_status;
end $$;

create or replace function assign_contest_juror(p_contest uuid, p_email text, p_add boolean) returns text
language plpgsql security definer set search_path = public as $$
declare u profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_contest_staff() then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if not exists (select 1 from contests where id = p_contest and status in ('draft', 'published', 'judging')) then raise exception 'Concours introuvable ou terminé'; end if;
  select * into u from profiles where lower(email) = lower(trim(coalesce(p_email, ''))) and not suspended;
  if not found then raise exception 'Compte introuvable'; end if;
  if p_add then
    insert into contest_jurors (contest_id, user_id) values (p_contest, u.id) on conflict do nothing;
    insert into notifications (user_id, kind, title, body, data) values (u.id, 'contest', 'Vous êtes juré', (select title from contests where id = p_contest), jsonb_build_object('contest_id', p_contest));
  else
    delete from contest_jurors where contest_id = p_contest and user_id = u.id;
  end if;
  return case when p_add then 'added' else 'removed' end;
end $$;

-- 6. Inscription et équipe (étudiants) ---------------------------------------------------------------------------------
create or replace function register_contest_team(p_contest uuid, p_name text, p_theme text, p_solo boolean, p_rules boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare c contests%rowtype; tid uuid; taken int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Inscription réservée aux étudiants'; end if;
  if not coalesce(p_rules, false) then raise exception 'Acceptez le règlement du concours'; end if;
  if p_name is null or char_length(trim(p_name)) not between 3 and 60 then raise exception 'Nom d''équipe : 3 à 60 caractères'; end if;
  select * into c from contests where id = p_contest for update;
  if not found or c.status <> 'published' then raise exception 'Ce concours ne reçoit pas d''inscriptions'; end if;
  if now() > c.reg_close_at then raise exception 'Les inscriptions sont closes'; end if;
  if exists (select 1 from contest_members m join contest_teams t on t.id = m.team_id where t.contest_id = c.id and m.user_id = auth.uid() and m.status in ('captain', 'member')) then
    raise exception 'Vous êtes déjà inscrit à ce concours';
  end if;
  select count(*) into taken from contest_teams where contest_id = c.id and not hidden;
  if taken >= c.places then raise exception 'Plus de places disponibles'; end if;
  insert into contest_teams (contest_id, name, theme, captain_id, solo, rules_accepted_at)
    values (c.id, trim(p_name), coalesce(trim(p_theme), ''), auth.uid(), coalesce(p_solo, false), now()) returning id into tid;
  insert into contest_members (team_id, user_id, status) values (tid, auth.uid(), 'captain');
  return tid;
end $$;

create or replace function invite_contest_member(p_team uuid, p_email text) returns text
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype; u profiles%rowtype; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or t.captain_id <> auth.uid() then raise exception 'Seul le capitaine invite'; end if;
  if t.solo then raise exception 'Inscription individuelle : pas de coéquipier'; end if;
  if not exists (select 1 from contests where id = t.contest_id and status = 'published' and now() <= reg_close_at) then raise exception 'Les inscriptions sont closes'; end if;
  select * into u from profiles where lower(email) = lower(trim(coalesce(p_email, ''))) and role = 'student' and not suspended;
  if not found then raise exception 'Étudiant introuvable'; end if;
  select count(*) into n from contest_members where team_id = t.id;
  if n >= 5 then raise exception 'Équipe complète (5 membres maximum)'; end if;
  insert into contest_members (team_id, user_id, status) values (t.id, u.id, 'invited') on conflict do nothing;
  insert into notifications (user_id, kind, title, body, data) values (u.id, 'contest', 'Invitation d''équipe', t.name, jsonb_build_object('team_id', t.id));
  return 'invited';
end $$;

create or replace function answer_contest_invite(p_team uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or not exists (select 1 from contest_members where team_id = p_team and user_id = auth.uid() and status = 'invited') then raise exception 'Invitation introuvable'; end if;
  if not p_accept then delete from contest_members where team_id = p_team and user_id = auth.uid(); return 'declined'; end if;
  if exists (select 1 from contest_members m join contest_teams x on x.id = m.team_id where x.contest_id = t.contest_id and m.user_id = auth.uid() and m.status in ('captain', 'member')) then
    raise exception 'Vous êtes déjà dans une équipe de ce concours';
  end if;
  update contest_members set status = 'member' where team_id = p_team and user_id = auth.uid();
  return 'member';
end $$;

-- 7. Dépôt (capitaine, avant l'échéance) ------------------------------------------------------------------------------
create or replace function submit_contest_project(p_team uuid, p_title text, p_description text, p_demo text, p_video text, p_deck text,
  p_original boolean, p_final boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype; c contests%rowtype; sid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or t.captain_id <> auth.uid() then raise exception 'Seul le capitaine dépose le projet'; end if;
  if t.hidden then raise exception 'Équipe écartée par la modération'; end if;
  select * into c from contests where id = t.contest_id;
  if c.status <> 'published' or now() > c.submit_close_at then raise exception 'Le dépôt est clos'; end if;
  if not coalesce(p_original, false) then raise exception 'Certifiez que le projet est original'; end if;
  if exists (select 1 from contest_submissions where team_id = t.id and submitted) then raise exception 'Projet déjà soumis'; end if;
  insert into contest_submissions (team_id, title, description, demo_url, video_url, deck_path, original_certified, submitted, updated_at)
    values (t.id, trim(p_title), trim(p_description), nullif(trim(coalesce(p_demo, '')), ''), nullif(trim(coalesce(p_video, '')), ''), nullif(trim(coalesce(p_deck, '')), ''),
            true, coalesce(p_final, false), now())
  on conflict (team_id) do update set title = excluded.title, description = excluded.description, demo_url = excluded.demo_url, video_url = excluded.video_url,
    deck_path = excluded.deck_path, submitted = excluded.submitted, updated_at = now()
  returning id into sid;
  return sid;
end $$;

-- 8. Notation (jurés désignés, hors de leur propre équipe) ------------------------------------------------------------
create or replace function score_contest_submission(p_submission uuid, p_innovation smallint, p_feasibility smallint, p_impact smallint, p_pitch smallint, p_comment text)
returns integer
language plpgsql security definer set search_path = public as $$
declare s contest_submissions%rowtype; t contest_teams%rowtype; c contests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from contest_submissions where id = p_submission;
  if not found or not s.submitted then raise exception 'Projet introuvable'; end if;
  select * into t from contest_teams where id = s.team_id;
  select * into c from contests where id = t.contest_id;
  if not is_contest_juror(c.id) then raise exception 'Réservé aux jurés de ce concours'; end if;
  if exists (select 1 from contest_members where team_id = t.id and user_id = auth.uid()) then raise exception 'Conflit d''intérêts : vous êtes membre de cette équipe'; end if;
  if c.status <> 'judging' then raise exception 'La notation n''est pas ouverte'; end if;
  insert into contest_scores (submission_id, juror_id, innovation, feasibility, impact, pitch, comment)
    values (s.id, auth.uid(), p_innovation, p_feasibility, p_impact, p_pitch, nullif(left(trim(coalesce(p_comment, '')), 2000), ''))
  on conflict (submission_id, juror_id) do update set innovation = excluded.innovation, feasibility = excluded.feasibility, impact = excluded.impact,
    pitch = excluded.pitch, comment = excluded.comment, updated_at = now();
  return p_innovation + p_feasibility + p_impact + p_pitch;
end $$;

-- 9. Modération -------------------------------------------------------------------------------------------------------
create or replace function moderate_contest_team(p_team uuid, p_hidden boolean, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_contest_staff() then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_hidden and char_length(trim(coalesce(p_reason, ''))) < 5 then raise exception 'Motif obligatoire (5 caractères minimum)'; end if;
  select * into t from contest_teams where id = p_team for update;
  if not found then raise exception 'Équipe introuvable'; end if;
  update contest_teams set hidden = p_hidden, hidden_reason = case when p_hidden then trim(p_reason) end where id = t.id;
  insert into notifications (user_id, kind, title, body, data) values (t.captain_id, 'contest', case when p_hidden then 'Équipe écartée' else 'Équipe rétablie' end,
    coalesce(trim(p_reason), t.name), jsonb_build_object('team_id', t.id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case when p_hidden then 'Équipe de concours écartée' else 'Équipe de concours rétablie' end, t.name, 'Modération', 'Sensible');
  return case when p_hidden then 'hidden' else 'visible' end;
end $$;

-- 10. Droits d'exécution ----------------------------------------------------------------------------------------------
revoke all on function is_contest_staff(), is_contest_member(uuid), is_contest_juror(uuid), contest_ranking(uuid),
  save_contest(uuid, text, text, text, text, text, timestamptz, timestamptz, date, date, integer, integer, boolean), set_contest_status(uuid, text),
  assign_contest_juror(uuid, text, boolean), register_contest_team(uuid, text, text, boolean, boolean), invite_contest_member(uuid, text),
  answer_contest_invite(uuid, boolean), submit_contest_project(uuid, text, text, text, text, text, boolean, boolean),
  score_contest_submission(uuid, smallint, smallint, smallint, smallint, text), moderate_contest_team(uuid, boolean, text) from public, anon;
grant execute on function is_contest_staff(), is_contest_member(uuid), is_contest_juror(uuid), contest_ranking(uuid),
  save_contest(uuid, text, text, text, text, text, timestamptz, timestamptz, date, date, integer, integer, boolean), set_contest_status(uuid, text),
  assign_contest_juror(uuid, text, boolean), register_contest_team(uuid, text, text, boolean, boolean), invite_contest_member(uuid, text),
  answer_contest_invite(uuid, boolean), submit_contest_project(uuid, text, text, text, text, text, boolean, boolean),
  score_contest_submission(uuid, smallint, smallint, smallint, smallint, text), moderate_contest_team(uuid, boolean, text) to authenticated;
-- la politique « concours visibles » appelle is_contest_staff : les visiteurs doivent pouvoir l'évaluer (faux sans compte)
grant execute on function is_contest_staff() to anon;

-- Retour arrière (manuel) : drop function des 12 fonctions ci-dessus ;
-- drop table contest_scores, contest_jurors, contest_submissions, contest_members, contest_teams, contests;
