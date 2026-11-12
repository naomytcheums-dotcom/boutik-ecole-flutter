-- Innovations des communautés : points et badges IUT, SOS Cours, défis hebdomadaires, marché des compétences, communautés éphémères, mur des victoires.
-- Tout passe par des fonctions qui vérifient auth.uid() ; les points ne sont jamais écrits par le client.
-- Retour arrière : drop des fonctions listées dans chaque section puis drop table point_events, sos_answers, sos_requests, challenge_votes, challenge_entries, weekly_challenges,
--   skill_responses, skill_offers, victory_cheers, victories ; alter table communities drop column expires_at ; recréer communities_list, community_accept_answer, mentor_review depuis les migrations précédentes.

-- ================================================================ points et badges IUT
create table if not exists point_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (char_length(kind) between 2 and 40),
  points integer not null check (points between 1 and 500),
  ref text,
  created_at timestamptz not null default now()
);
create index if not exists point_events_user on point_events (user_id, created_at desc);
create unique index if not exists point_events_once on point_events (user_id, kind, ref) where ref is not null;
alter table point_events enable row level security;
revoke all on point_events from anon, authenticated;

-- Attribution interne (jamais appelée par le client) : une seule fois par (personne, type, référence), avec un plafond de points par jour et par type.
create or replace function award_points(p_user uuid, p_kind text, p_points integer, p_ref text default null, p_daily_cap integer default 100) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user is null then return; end if;
  if coalesce((select sum(points) from point_events where user_id = p_user and kind = p_kind and created_at > now() - interval '1 day'), 0) + p_points > p_daily_cap then return; end if;
  insert into point_events (user_id, kind, points, ref) values (p_user, p_kind, p_points, p_ref) on conflict do nothing;
end $$;
revoke all on function award_points(uuid, text, integer, text, integer) from public, anon, authenticated;

-- Niveaux : Aidant Bronze (50), Argent (150), Or (400), Légende IUT (1000).
create or replace function point_level(p_total integer) returns text
language sql immutable as $$
  select case when p_total >= 1000 then 'legend' when p_total >= 400 then 'gold' when p_total >= 150 then 'silver' when p_total >= 50 then 'bronze' else 'none' end
$$;

create or replace function my_points() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_total integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select coalesce(sum(points), 0)::int into v_total from point_events where user_id = auth.uid();
  return jsonb_build_object('total', v_total, 'level', point_level(v_total),
    'next_at', case when v_total >= 1000 then null when v_total >= 400 then 1000 when v_total >= 150 then 400 when v_total >= 50 then 150 else 50 end,
    'events', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'points', e.points, 'created_at', e.created_at) order by e.created_at desc) from (select * from point_events where user_id = auth.uid() order by created_at desc limit 15) e), '[]'::jsonb));
end $$;

create or replace function top_helpers(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('user_id', x.user_id, 'name', display_name(x.user_id), 'total', x.total, 'level', point_level(x.total)) order by x.total desc), '[]'::jsonb)
  from (select user_id, sum(points)::int total from point_events group by user_id order by sum(points) desc limit least(greatest(coalesce(p_limit, 10), 1), 50)) x
$$;

-- Les flux existants rapportent des points : réponse retenue (+10), avis de 4 étoiles ou plus (+10 au mentor), fichier partagé (+5).
create or replace function community_accept_answer(p_answer uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a community_answers%rowtype; q community_questions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from community_answers where id = p_answer;
  if not found then raise exception 'Réponse introuvable'; end if;
  select * into q from community_questions where id = a.question_id;
  if q.author_id <> auth.uid() then raise exception 'Seul l''auteur de la question choisit la meilleure réponse'; end if;
  update community_questions set accepted_answer = p_answer where id = q.id;
  perform notify_user(a.author_id, 'community_answer', 'Votre réponse a aidé', display_name(auth.uid()) || ' a retenu votre réponse.', jsonb_build_object('community', q.community_id, 'question', q.id));
  if a.author_id <> auth.uid() then perform award_points(a.author_id, 'qa_accepted', 10, p_answer::text); end if;
end $$;

create or replace function mentor_review(p_request uuid, p_rating integer, p_comment text default '') returns void
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from mentor_requests where id = p_request and student_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'accepted' then raise exception 'Vous pouvez noter un mentor une fois sa demande acceptée'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'La note va de 1 à 5 étoiles'; end if;
  insert into mentor_reviews (request_id, mentor_id, student_id, rating, comment) values (p_request, q.mentor_id, auth.uid(), p_rating, left(btrim(coalesce(p_comment, '')), 400))
  on conflict (request_id) do update set rating = excluded.rating, comment = excluded.comment;
  perform notify_user(q.mentor_id, 'mentor_request', 'Nouvel avis', display_name(auth.uid()) || ' vous a mis ' || p_rating || ' étoile' || case when p_rating > 1 then 's' else '' end || '.', jsonb_build_object('request', p_request));
  if p_rating >= 4 then perform award_points(q.mentor_id, 'mentor_review', 10, p_request::text); end if;
end $$;

-- ================================================================ SOS Cours en 1 clic
create table if not exists sos_requests (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  subject text not null check (char_length(btrim(subject)) between 3 and 100),
  details text not null default '' check (char_length(details) <= 800),
  department text not null default '',
  status text not null default 'open' check (status in ('open', 'solved')),
  solved_answer uuid,
  created_at timestamptz not null default now()
);
create table if not exists sos_answers (
  id uuid primary key default gen_random_uuid(),
  sos_id uuid not null references sos_requests(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists sos_requests_dept on sos_requests (department, status, created_at desc);
create index if not exists sos_answers_sos on sos_answers (sos_id, created_at);
alter table sos_requests enable row level security;
alter table sos_answers enable row level security;
revoke all on sos_requests, sos_answers from anon, authenticated;

-- L'étudiant bloqué choisit sa matière : tous les étudiants de sa filière sont prévenus ; le premier qui répond gagne des points.
create or replace function sos_create(p_subject text, p_details text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_dept text; r record; v_subject text := btrim(coalesce(p_subject, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_subject) < 3 then raise exception 'Indiquez la matière ou le TP qui vous bloque'; end if;
  if (select count(*) from sos_requests where author_id = auth.uid() and created_at > now() - interval '1 hour') >= 3 then raise exception 'Trois SOS par heure au plus'; end if;
  select coalesce(department, '') into v_dept from profiles where id = auth.uid();
  insert into sos_requests (author_id, subject, details, department) values (auth.uid(), left(v_subject, 100), left(btrim(coalesce(p_details, '')), 800), v_dept) returning id into v_id;
  for r in select id from profiles where id <> auth.uid() and coalesce(suspended, false) = false and v_dept <> '' and department = v_dept limit 100 loop
    perform notify_user(r.id, 'sos', 'SOS Cours : ' || left(v_subject, 60), display_name(auth.uid()) || ' est bloqué(e). Le premier qui répond gagne des points.', jsonb_build_object('sos', v_id));
  end loop;
  return v_id;
end $$;

create or replace function sos_answer(p_sos uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s sos_requests%rowtype; v_id uuid; v_first boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from sos_requests where id = p_sos;
  if not found then raise exception 'SOS introuvable'; end if;
  if s.author_id = auth.uid() then raise exception 'Vous ne pouvez pas répondre à votre propre SOS'; end if;
  if s.status <> 'open' then raise exception 'Ce SOS est déjà résolu'; end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 1000 then raise exception 'Une réponse contient de 1 à 1000 caractères'; end if;
  v_first := not exists (select 1 from sos_answers where sos_id = p_sos);
  insert into sos_answers (sos_id, author_id, body) values (p_sos, auth.uid(), btrim(p_body)) returning id into v_id;
  if v_first then perform award_points(auth.uid(), 'sos_first', 15, p_sos::text); end if;
  perform notify_user(s.author_id, 'sos', 'On vous répond', display_name(auth.uid()) || ' a répondu à votre SOS « ' || left(s.subject, 60) || ' ».', jsonb_build_object('sos', p_sos));
  return v_id;
end $$;

create or replace function sos_solve(p_sos uuid, p_answer uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s sos_requests%rowtype; a sos_answers%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from sos_requests where id = p_sos and author_id = auth.uid();
  if not found then raise exception 'SOS introuvable'; end if;
  select * into a from sos_answers where id = p_answer and sos_id = p_sos;
  if not found then raise exception 'Réponse introuvable'; end if;
  update sos_requests set status = 'solved', solved_answer = p_answer where id = p_sos;
  perform award_points(a.author_id, 'sos_solved', 10, p_answer::text);
  perform notify_user(a.author_id, 'sos', 'Votre aide a servi', display_name(auth.uid()) || ' a retenu votre réponse : +10 points.', jsonb_build_object('sos', p_sos));
end $$;

-- p_scope : 'filiere' (SOS ouverts de ma filière, hors les miens) ou 'mine' (les miens).
create or replace function sos_list(p_scope text default 'filiere') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select coalesce(department, '') into v_dept from profiles where id = auth.uid();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', s.id, 'subject', s.subject, 'details', s.details, 'author', display_name(s.author_id), 'mine', s.author_id = auth.uid(), 'status', s.status,
      'created_at', s.created_at, 'solved_answer', s.solved_answer,
      'answers', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'body', a.body, 'author', display_name(a.author_id), 'created_at', a.created_at, 'accepted', a.id = s.solved_answer) order by a.created_at)
                           from sos_answers a where a.sos_id = s.id), '[]'::jsonb)) order by s.created_at desc)
    from (select * from sos_requests where case when p_scope = 'mine' then author_id = auth.uid() else (status = 'open' and author_id <> auth.uid() and department = v_dept and v_dept <> '') end
          order by created_at desc limit 50) s
  ), '[]'::jsonb);
end $$;

-- ================================================================ défis hebdomadaires
create table if not exists weekly_challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 3 and 120),
  description text not null default '' check (char_length(description) <= 1000),
  kind text not null default 'other' check (kind in ('design', 'code', 'other')),
  created_by uuid references profiles(id) on delete set null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  winner_entry uuid,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create table if not exists challenge_entries (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references weekly_challenges(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 120),
  description text not null default '' check (char_length(description) <= 800),
  url text not null default '' check (char_length(url) <= 300 and (url = '' or url ~* '^https?://')),
  created_at timestamptz not null default now(),
  unique (challenge_id, author_id)
);
create table if not exists challenge_votes (
  challenge_id uuid not null references weekly_challenges(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  entry_id uuid not null references challenge_entries(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);
alter table weekly_challenges enable row level security;
alter table challenge_entries enable row level security;
alter table challenge_votes enable row level security;
revoke all on weekly_challenges, challenge_entries, challenge_votes from anon, authenticated;

create or replace function challenge_create(p_title text, p_description text, p_kind text default 'other', p_days integer default 7) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'dept') then raise exception 'Réservé à l''équipe de la plateforme et au département'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Donnez un titre au défi'; end if;
  if p_kind not in ('design', 'code', 'other') then raise exception 'Type de défi inconnu'; end if;
  if p_days is null or p_days not between 1 and 30 then raise exception 'La durée va de 1 à 30 jours'; end if;
  insert into weekly_challenges (title, description, kind, created_by, ends_at) values (btrim(p_title), left(btrim(coalesce(p_description, '')), 1000), p_kind, auth.uid(), now() + make_interval(days => p_days)) returning id into v_id;
  return v_id;
end $$;

create or replace function challenge_submit(p_challenge uuid, p_title text, p_description text default '', p_url text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare c weekly_challenges%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from weekly_challenges where id = p_challenge;
  if not found then raise exception 'Défi introuvable'; end if;
  if c.ends_at <= now() then raise exception 'Ce défi est terminé'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 2 then raise exception 'Donnez un titre à votre réalisation'; end if;
  insert into challenge_entries (challenge_id, author_id, title, description, url) values (p_challenge, auth.uid(), btrim(p_title), left(btrim(coalesce(p_description, '')), 800), btrim(coalesce(p_url, '')))
  on conflict (challenge_id, author_id) do update set title = excluded.title, description = excluded.description, url = excluded.url returning id into v_id;
  perform award_points(auth.uid(), 'challenge_entry', 5, p_challenge::text);
  return v_id;
end $$;

create or replace function challenge_vote(p_entry uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e challenge_entries%rowtype; c weekly_challenges%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from challenge_entries where id = p_entry;
  if not found then raise exception 'Réalisation introuvable'; end if;
  select * into c from weekly_challenges where id = e.challenge_id;
  if c.ends_at <= now() then raise exception 'Les votes sont clos'; end if;
  if e.author_id = auth.uid() then raise exception 'Vous ne pouvez pas voter pour votre propre réalisation'; end if;
  insert into challenge_votes (challenge_id, user_id, entry_id) values (e.challenge_id, auth.uid(), p_entry)
  on conflict (challenge_id, user_id) do update set entry_id = excluded.entry_id, created_at = now();
end $$;

-- Liste des défis ; les défis terminés sans gagnant en désignent un (le plus voté, à égalité le plus ancien) et lui donnent 50 points.
create or replace function challenges_list() returns jsonb
language plpgsql security definer set search_path = public as $$
declare c record; w uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  for c in select id from weekly_challenges where ends_at <= now() and winner_entry is null loop
    select e.id into w from challenge_entries e where e.challenge_id = c.id
      order by (select count(*) from challenge_votes v where v.entry_id = e.id) desc, e.created_at limit 1;
    if w is not null and exists (select 1 from challenge_votes where entry_id = w) then
      update weekly_challenges set winner_entry = w where id = c.id;
      perform award_points((select author_id from challenge_entries where id = w), 'challenge_win', 50, c.id::text);
    end if;
  end loop;
  return coalesce((select jsonb_agg(jsonb_build_object('id', ch.id, 'title', ch.title, 'description', ch.description, 'kind', ch.kind, 'starts_at', ch.starts_at, 'ends_at', ch.ends_at,
      'ended', ch.ends_at <= now(), 'winner_entry', ch.winner_entry,
      'my_vote', (select v.entry_id from challenge_votes v where v.challenge_id = ch.id and v.user_id = auth.uid()),
      'i_entered', exists (select 1 from challenge_entries e where e.challenge_id = ch.id and e.author_id = auth.uid()),
      'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'description', e.description, 'url', e.url, 'author', display_name(e.author_id), 'mine', e.author_id = auth.uid(),
                              'votes', (select count(*)::int from challenge_votes v where v.entry_id = e.id), 'winner', e.id = ch.winner_entry)
                              order by (select count(*) from challenge_votes v where v.entry_id = e.id) desc, e.created_at)
                           from challenge_entries e where e.challenge_id = ch.id), '[]'::jsonb)) order by (ch.ends_at <= now()), ch.ends_at desc)
    from (select * from weekly_challenges order by created_at desc limit 12) ch), '[]'::jsonb);
end $$;

-- ================================================================ marché des compétences
create table if not exists skill_offers (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('seek', 'offer', 'swap')),
  title text not null check (char_length(btrim(title)) between 3 and 100),
  description text not null default '' check (char_length(description) <= 500),
  price integer check (price is null or (price >= 0 and price <= 1000000)),
  swap_for text not null default '' check (char_length(swap_for) <= 100),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now()
);
create table if not exists skill_responses (
  skill_id uuid not null references skill_offers(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  message text not null default '' check (char_length(message) <= 500),
  created_at timestamptz not null default now(),
  primary key (skill_id, user_id)
);
create index if not exists skill_offers_idx on skill_offers (status, created_at desc);
alter table skill_offers enable row level security;
alter table skill_responses enable row level security;
revoke all on skill_offers, skill_responses from anon, authenticated;

-- « Je cherche quelqu'un qui sait faire un poster, je paie 5 000 FCFA » (seek), « Je fais des posters » (offer), « Je t'aide en maths, tu m'aides en anglais » (swap).
create or replace function skill_post(p_kind text, p_title text, p_description text default '', p_price integer default null, p_swap_for text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('seek', 'offer', 'swap') then raise exception 'Type d''annonce inconnu'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Décrivez la compétence en quelques mots'; end if;
  if p_kind = 'swap' and char_length(btrim(coalesce(p_swap_for, ''))) < 2 then raise exception 'Indiquez ce que vous attendez en échange'; end if;
  if p_price is not null and (p_price < 0 or p_price > 1000000) then raise exception 'Prix invalide'; end if;
  if (select count(*) from skill_offers where author_id = auth.uid() and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq annonces par jour au plus'; end if;
  insert into skill_offers (author_id, kind, title, description, price, swap_for) values (auth.uid(), p_kind, btrim(p_title), left(btrim(coalesce(p_description, '')), 500), p_price, left(btrim(coalesce(p_swap_for, '')), 100)) returning id into v_id;
  return v_id;
end $$;

create or replace function skill_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update skill_offers set status = 'closed' where id = p_id and author_id = auth.uid();
  if not found then raise exception 'Annonce introuvable'; end if;
end $$;

create or replace function skills_list(p_kind text default null, p_q text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'kind', s.kind, 'title', s.title, 'description', s.description, 'price', s.price, 'swap_for', s.swap_for,
      'author', display_name(s.author_id), 'author_id', s.author_id, 'mine', s.author_id = auth.uid(), 'created_at', s.created_at,
      'responses', case when s.author_id = auth.uid() then (select count(*)::int from skill_responses r where r.skill_id = s.id) end,
      'responded', exists (select 1 from skill_responses r where r.skill_id = s.id and r.user_id = auth.uid())) order by s.created_at desc), '[]'::jsonb)
  from (select * from skill_offers where status = 'open'
          and (nullif(btrim(coalesce(p_kind, '')), '') is null or kind = p_kind)
          and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(title || ' ' || description || ' ' || swap_for) like '%' || lower(btrim(p_q)) || '%')
        order by created_at desc limit 60) s
$$;

create or replace function skill_respond(p_id uuid, p_message text default '') returns void
language plpgsql security definer set search_path = public as $$
declare s skill_offers%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from skill_offers where id = p_id and status = 'open';
  if not found then raise exception 'Annonce introuvable ou clôturée'; end if;
  if s.author_id = auth.uid() then raise exception 'C''est votre propre annonce'; end if;
  insert into skill_responses (skill_id, user_id, message) values (p_id, auth.uid(), left(btrim(coalesce(p_message, '')), 500))
  on conflict (skill_id, user_id) do update set message = excluded.message;
  perform notify_user(s.author_id, 'skill', 'Réponse à votre annonce', display_name(auth.uid()) || ' répond à « ' || left(s.title, 60) || ' ».', jsonb_build_object('skill', p_id));
end $$;

create or replace function skill_responses_list(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from skill_offers where id = p_id and author_id = auth.uid()) then raise exception 'Annonce introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', r.user_id, 'name', display_name(r.user_id), 'message', r.message, 'created_at', r.created_at) order by r.created_at desc)
                   from skill_responses r where r.skill_id = p_id), '[]'::jsonb);
end $$;

-- ================================================================ mur des victoires
create table if not exists victories (
  id uuid primary key default gen_random_uuid(),
  community_id uuid references communities(id) on delete cascade,   -- nul : mur de toute la plateforme
  author_id uuid not null references profiles(id) on delete cascade,
  kind text not null default 'other' check (kind in ('internship', 'hackathon', 'grade', 'other')),
  body text not null check (char_length(btrim(body)) between 3 and 400),
  status text not null default 'published' check (status in ('published', 'hidden')),
  created_at timestamptz not null default now()
);
create table if not exists victory_cheers (
  victory_id uuid not null references victories(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  primary key (victory_id, user_id)
);
create index if not exists victories_idx on victories (community_id, created_at desc);
alter table victories enable row level security;
alter table victory_cheers enable row level security;
revoke all on victories, victory_cheers from anon, authenticated;

create or replace function victory_post(p_kind text, p_body text, p_community uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('internship', 'hackathon', 'grade', 'other') then raise exception 'Type de réussite inconnu'; end if;
  if char_length(btrim(coalesce(p_body, ''))) < 3 then raise exception 'Racontez votre réussite en quelques mots'; end if;
  if p_community is not null and not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if (select count(*) from victories where author_id = auth.uid() and created_at > now() - interval '1 day') >= 3 then raise exception 'Trois réussites par jour au plus'; end if;
  insert into victories (community_id, author_id, kind, body) values (p_community, auth.uid(), p_kind, btrim(p_body)) returning id into v_id;
  perform award_points(auth.uid(), 'victory', 5, v_id::text, 15);
  return v_id;
end $$;

create or replace function victory_cheer(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare v victories%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into v from victories where id = p_id and status = 'published';
  if not found then raise exception 'Réussite introuvable'; end if;
  if exists (select 1 from victory_cheers where victory_id = p_id and user_id = auth.uid()) then
    delete from victory_cheers where victory_id = p_id and user_id = auth.uid();
    return false;
  end if;
  insert into victory_cheers (victory_id, user_id) values (p_id, auth.uid());
  if v.author_id <> auth.uid() then perform notify_user(v.author_id, 'victory', 'Bravo !', display_name(auth.uid()) || ' félicite votre réussite.', jsonb_build_object('victory', p_id)); end if;
  return true;
end $$;

create or replace function victories_list(p_community uuid default null, p_limit integer default 40) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if p_community is not null and not exists (select 1 from communities c where c.id = p_community and c.status = 'active' and (c.privacy = 'public' or is_community_member(c.id))) then raise exception 'Réservé aux membres de la communauté'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'kind', v.kind, 'body', v.body, 'author', display_name(v.author_id), 'mine', v.author_id = auth.uid(), 'created_at', v.created_at,
      'cheers', (select count(*)::int from victory_cheers c where c.victory_id = v.id),
      'cheered', exists (select 1 from victory_cheers c where c.victory_id = v.id and c.user_id = auth.uid())) order by v.created_at desc)
    from (select * from victories where status = 'published' and community_id is not distinct from p_community order by created_at desc limit least(greatest(coalesce(p_limit, 40), 1), 100)) v), '[]'::jsonb);
end $$;

-- ================================================================ communautés éphémères (suppression automatique)
alter table communities add column if not exists expires_at timestamptz;

-- Une communauté éphémère (révision d'examen, projet, événement) est publiée tout de suite et se supprime seule après 7 jours (1 à 14).
create or replace function create_ephemeral_community(p_name text, p_description text default '', p_days integer default 7, p_privacy text default 'public') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Complétez votre profil avant cette action'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_days is null or p_days not between 1 and 14 then raise exception 'Une communauté éphémère dure de 1 à 14 jours'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and expires_at is not null and expires_at > now()) >= 3 then raise exception 'Trois communautés éphémères actives au plus'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, privacy, owner_id, status, kind, interest, expires_at)
    values (btrim(p_name), left(btrim(coalesce(p_description, '')), 2000), p_privacy, auth.uid(), 'active', 'project', 'Éphémère', now() + make_interval(days => p_days)) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  return v_id;
end $$;

create or replace function purge_expired_communities() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  delete from communities where expires_at is not null and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function purge_expired_communities() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('purge-expired-communities', '15 * * * *', 'select public.purge_expired_communities()');
exception when others then
  raise notice 'pg_cron indisponible : les communautés éphémères expirées sont masquées de l''annuaire (%).', sqlerrm;
end $$;

drop function if exists communities_list(text, integer);
create or replace function communities_list(p_query text default '', p_limit integer default 30)
returns table (id uuid, name text, description text, category text, privacy text, members integer, my_status text, my_role text, status text, department text, decision_note text,
               kind text, promo_year text, interest text, official boolean, created_at timestamptz, last_activity timestamptz, posts_week integer, owner_kind text, expires_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.category, c.privacy,
         (select count(*)::int from community_members m where m.community_id = c.id and m.status = 'active'),
         (select m.status from community_members m where m.community_id = c.id and m.user_id = auth.uid()),
         (select m.role from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status = 'active'),
         c.status, d.name, c.decision_note,
         c.kind, c.promo_year, c.interest, c.official, c.created_at,
         (select max(p.published_at) from posts p where p.community_id = c.id and p.status = 'published'),
         (select count(*)::int from posts p where p.community_id = c.id and p.status = 'published' and p.published_at > now() - interval '7 days'),
         (select case when o.role::text in ('dept', 'direction') then 'teacher' when o.role::text = 'student' then 'student' else 'staff' end from profiles o where o.id = c.owner_id),
         c.expires_at
  from communities c left join departments d on d.id = c.department_id
  where (c.expires_at is null or c.expires_at > now())
    and (
      (c.status = 'active' and (c.privacy in ('public', 'approval') or exists (select 1 from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status in ('active', 'invited'))))
      or (c.owner_id = auth.uid() and c.status in ('pending', 'rejected'))
    )
    and (coalesce(btrim(p_query), '') = '' or c.name ilike '%' || btrim(p_query) || '%' or c.category ilike '%' || btrim(p_query) || '%' or d.name ilike '%' || btrim(p_query) || '%'
         or coalesce(c.interest, '') ilike '%' || btrim(p_query) || '%' or coalesce(c.promo_year, '') ilike '%' || btrim(p_query) || '%' or c.description ilike '%' || btrim(p_query) || '%')
  order by (c.status <> 'active') desc, 6 desc, c.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;
revoke all on function communities_list(text, integer) from public, anon;
grant execute on function communities_list(text, integer) to authenticated, anon;

-- ================================================================ droits
revoke all on function my_points(), top_helpers(integer), sos_create(text, text), sos_answer(uuid, text), sos_solve(uuid, uuid), sos_list(text),
  challenge_create(text, text, text, integer), challenge_submit(uuid, text, text, text), challenge_vote(uuid), challenges_list(),
  skill_post(text, text, text, integer, text), skill_close(uuid), skill_respond(uuid, text), skill_responses_list(uuid),
  victory_post(text, text, uuid), victory_cheer(uuid), create_ephemeral_community(text, text, integer, text) from public, anon;
grant execute on function my_points(), sos_create(text, text), sos_answer(uuid, text), sos_solve(uuid, uuid), sos_list(text),
  challenge_create(text, text, text, integer), challenge_submit(uuid, text, text, text), challenge_vote(uuid), challenges_list(),
  skill_post(text, text, text, integer, text), skill_close(uuid), skill_respond(uuid, text), skill_responses_list(uuid),
  victory_post(text, text, uuid), victory_cheer(uuid), create_ephemeral_community(text, text, integer, text) to authenticated;
revoke all on function top_helpers(integer), skills_list(text, text), victories_list(uuid, integer), point_level(integer) from public;
grant execute on function top_helpers(integer), skills_list(text, text), victories_list(uuid, integer), point_level(integer) to anon, authenticated;
