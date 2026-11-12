-- Réseau des anciens et mentors : profil mentor (où il travaille, ce qu'il peut aider, disponibilité), demande de mentor, avis après un accompagnement,
-- histoires de réussite (« De l'IUT à Orange Cameroun ») et match automatique (« Je veux apprendre Flutter, je suis dispo le soir » -> 3 mentors).
-- Aucune écriture directe : tout passe par des fonctions qui vérifient auth.uid().
-- Retour arrière : drop function mentor_save(text, text, text[], text, text, boolean, boolean), my_mentor(), mentors_list(text, text), mentor_detail(uuid), mentor_match(text, boolean, integer),
--   mentor_request(uuid, text, text), mentor_request_decide(uuid, boolean), my_mentor_requests(text), mentor_review(uuid, integer, text), mentor_story_save(text, text, text), mentor_stories(integer);
--   drop table mentor_reviews, mentor_requests, mentor_stories, mentor_profiles;

create table if not exists mentor_profiles (
  user_id uuid primary key references profiles(id) on delete cascade,
  works_at text not null check (char_length(btrim(works_at)) between 2 and 100),
  promo text not null default '' check (char_length(promo) <= 40),
  topics text[] not null default '{}' check (cardinality(topics) between 1 and 10),
  bio text not null default '' check (char_length(bio) <= 600),
  availability text not null default 'available' check (availability in ('this_week', 'available', 'busy')),
  evening boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists mentor_requests (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references profiles(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  topic text not null check (char_length(btrim(topic)) between 2 and 100),
  message text not null default '' check (char_length(message) <= 600),
  status text not null default 'requested' check (status in ('requested', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  check (mentor_id <> student_id)
);
create index if not exists mentor_requests_mentor on mentor_requests (mentor_id, created_at desc);
create index if not exists mentor_requests_student on mentor_requests (student_id, created_at desc);
create table if not exists mentor_reviews (
  request_id uuid primary key references mentor_requests(id) on delete cascade,
  mentor_id uuid not null references profiles(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 400),
  created_at timestamptz not null default now()
);
create index if not exists mentor_reviews_mentor on mentor_reviews (mentor_id);
create table if not exists mentor_stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 120),
  body text not null check (char_length(btrim(body)) between 20 and 2000),
  company text not null default '' check (char_length(company) <= 100),
  status text not null default 'published' check (status in ('published', 'hidden')),
  created_at timestamptz not null default now()
);
alter table mentor_profiles enable row level security;
alter table mentor_requests enable row level security;
alter table mentor_reviews enable row level security;
alter table mentor_stories enable row level security;
revoke all on mentor_profiles, mentor_requests, mentor_reviews, mentor_stories from anon, authenticated;

-- Devenir mentor ou modifier son profil mentor.
create or replace function mentor_save(p_works_at text, p_promo text, p_topics text[], p_bio text, p_availability text default 'available', p_evening boolean default false, p_active boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare v_topics text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_works_at, ''))) < 2 then raise exception 'Indiquez où vous travaillez ou étudiez maintenant'; end if;
  select array_agg(btrim(t)) into v_topics from unnest(coalesce(p_topics, '{}'::text[])) t where char_length(btrim(t)) between 2 and 60;
  if v_topics is null or cardinality(v_topics) not between 1 and 10 then raise exception 'Indiquez de 1 à 10 sujets sur lesquels vous pouvez aider'; end if;
  if p_availability not in ('this_week', 'available', 'busy') then raise exception 'Disponibilité inconnue'; end if;
  insert into mentor_profiles (user_id, works_at, promo, topics, bio, availability, evening, active)
  values (auth.uid(), btrim(p_works_at), left(btrim(coalesce(p_promo, '')), 40), v_topics, left(btrim(coalesce(p_bio, '')), 600), p_availability, coalesce(p_evening, false), coalesce(p_active, true))
  on conflict (user_id) do update set works_at = excluded.works_at, promo = excluded.promo, topics = excluded.topics, bio = excluded.bio, availability = excluded.availability, evening = excluded.evening, active = excluded.active;
end $$;

create or replace function my_mentor() returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(m) - 'created_at' from mentor_profiles m where m.user_id = auth.uid()
$$;

-- Fiche publique d'un mentor : nom abrégé, filière, promo, employeur, sujets, disponibilité, note moyenne.
create or replace function _mentor_card(m mentor_profiles) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('user_id', m.user_id, 'name', display_name(m.user_id), 'avatar_url', p.avatar_url, 'department', p.department, 'promo', m.promo, 'works_at', m.works_at,
    'topics', to_jsonb(m.topics), 'bio', m.bio, 'availability', m.availability, 'evening', m.evening,
    'rating', (select round(avg(r.rating)::numeric, 1) from mentor_reviews r where r.mentor_id = m.user_id),
    'reviews', (select count(*)::int from mentor_reviews r where r.mentor_id = m.user_id),
    'helped', (select count(*)::int from mentor_requests q where q.mentor_id = m.user_id and q.status = 'accepted'))
  from profiles p where p.id = m.user_id
$$;
revoke all on function _mentor_card(mentor_profiles) from public, anon, authenticated;

create or replace function mentors_list(p_q text default null, p_topic text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(c order by (c->>'availability' = 'busy'), coalesce((c->>'rating')::numeric, 0) desc, (c->>'helped')::int desc), '[]'::jsonb) from (
    select _mentor_card(m) c from mentor_profiles m join profiles p on p.id = m.user_id
    where m.active and not coalesce(p.suspended, false) and m.user_id is distinct from auth.uid()
      and (nullif(btrim(coalesce(p_topic, '')), '') is null or exists (select 1 from unnest(m.topics) t where lower(t) like '%' || lower(btrim(p_topic)) || '%'))
      and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(m.works_at || ' ' || m.bio || ' ' || coalesce(p.department, '') || ' ' || array_to_string(m.topics, ' ') || ' ' || p.name) like '%' || lower(btrim(p_q)) || '%')
    limit 100) x
$$;

create or replace function mentor_detail(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m mentor_profiles%rowtype;
begin
  select * into m from mentor_profiles where user_id = p_user and active;
  if not found then raise exception 'Mentor introuvable'; end if;
  return _mentor_card(m) || jsonb_build_object(
    'review_list', coalesce((select jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.student_id), 'created_at', r.created_at) order by r.created_at desc)
                             from (select * from mentor_reviews where mentor_id = p_user order by created_at desc limit 20) r), '[]'::jsonb),
    'my_request', (select to_jsonb(q) - 'mentor_id' - 'student_id' from (select id, topic, status, created_at from mentor_requests where mentor_id = p_user and student_id = auth.uid() order by created_at desc limit 1) q));
end $$;

-- Match automatique : les 3 mentors qui correspondent le mieux (sujet, filière, disponibilité, soir).
create or replace function mentor_match(p_topic text, p_evening boolean default null, p_limit integer default 3) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_dept text; v_words text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select lower(coalesce(department, '')) into v_dept from profiles where id = auth.uid();
  select array_agg(distinct w) into v_words from unnest(regexp_split_to_array(lower(btrim(coalesce(p_topic, ''))), '[^a-zà-ÿ0-9+#]+')) w where char_length(w) >= 3;
  if v_words is null then raise exception 'Dites ce que vous voulez apprendre (ex. Flutter)'; end if;
  return coalesce((select jsonb_agg(c || jsonb_build_object('score', s) order by s desc, coalesce((c->>'rating')::numeric, 0) desc) from (
    select _mentor_card(m) c,
      (select count(*)::int * 10 from unnest(v_words) w where lower(array_to_string(m.topics, ' ') || ' ' || m.bio) like '%' || w || '%')
      + case when v_dept <> '' and lower(coalesce(p.department, '')) = v_dept then 5 else 0 end
      + case m.availability when 'this_week' then 4 when 'available' then 2 else -20 end
      + case when coalesce(p_evening, false) and m.evening then 3 else 0 end
      + coalesce((select round(avg(r.rating))::int from mentor_reviews r where r.mentor_id = m.user_id), 0) as s
    from mentor_profiles m join profiles p on p.id = m.user_id
    where m.active and m.availability <> 'busy' and not coalesce(p.suspended, false) and m.user_id <> auth.uid()
      and exists (select 1 from unnest(v_words) w where lower(array_to_string(m.topics, ' ') || ' ' || m.bio) like '%' || w || '%')
    order by 2 desc limit least(greatest(coalesce(p_limit, 3), 1), 10)) z(c, s)), '[]'::jsonb);
end $$;

create or replace function mentor_request(p_mentor uuid, p_topic text, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare m mentor_profiles%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from mentor_profiles where user_id = p_mentor and active;
  if not found then raise exception 'Mentor introuvable'; end if;
  if p_mentor = auth.uid() then raise exception 'Vous ne pouvez pas vous choisir comme mentor'; end if;
  if m.availability = 'busy' then raise exception 'Ce mentor n''est pas disponible pour le moment'; end if;
  if char_length(btrim(coalesce(p_topic, ''))) < 2 then raise exception 'Indiquez ce que vous voulez apprendre'; end if;
  if exists (select 1 from mentor_requests where mentor_id = p_mentor and student_id = auth.uid() and status = 'requested') then raise exception 'Une demande est déjà en attente auprès de ce mentor'; end if;
  if (select count(*) from mentor_requests where student_id = auth.uid() and status = 'requested') >= 5 then raise exception 'Cinq demandes en attente au plus : attendez une réponse'; end if;
  insert into mentor_requests (mentor_id, student_id, topic, message) values (p_mentor, auth.uid(), btrim(p_topic), left(btrim(coalesce(p_message, '')), 600)) returning id into v_id;
  perform notify_user(p_mentor, 'mentor_request', 'Demande de mentor', display_name(auth.uid()) || ' souhaite votre aide : ' || btrim(p_topic), jsonb_build_object('request', v_id));
  return v_id;
end $$;

create or replace function mentor_request_decide(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from mentor_requests where id = p_id and mentor_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'requested' then raise exception 'Cette demande a déjà reçu une réponse'; end if;
  update mentor_requests set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where id = p_id;
  perform notify_user(q.student_id, 'mentor_request', case when p_accept then 'Mentor trouvé' else 'Demande déclinée' end,
    display_name(auth.uid()) || case when p_accept then ' a accepté de vous aider : écrivez-lui pour convenir d''un moment.' else ' ne peut pas vous accompagner pour le moment.' end, jsonb_build_object('request', p_id));
  return case when p_accept then 'accepted' else 'declined' end;
end $$;

-- Mes demandes : p_role = 'student' (celles que j'ai envoyées) ou 'mentor' (celles que je reçois).
create or replace function my_mentor_requests(p_role text default 'student') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'topic', q.topic, 'message', q.message, 'status', q.status, 'created_at', q.created_at,
      'other_id', case when p_role = 'mentor' then q.student_id else q.mentor_id end,
      'other', display_name(case when p_role = 'mentor' then q.student_id else q.mentor_id end),
      'reviewed', exists (select 1 from mentor_reviews r where r.request_id = q.id)) order by q.created_at desc), '[]'::jsonb)
  from mentor_requests q where case when p_role = 'mentor' then q.mentor_id = auth.uid() else q.student_id = auth.uid() end
$$;

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
end $$;

-- Histoires de réussite : écrites par les mentors, visibles de tous.
create or replace function mentor_story_save(p_title text, p_body text, p_company text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from mentor_profiles where user_id = auth.uid() and active) then raise exception 'Réservé aux mentors : créez d''abord votre profil mentor'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Donnez un titre à votre histoire'; end if;
  if char_length(btrim(coalesce(p_body, ''))) < 20 then raise exception 'Racontez votre parcours en 20 caractères minimum'; end if;
  if (select count(*) from mentor_stories where author_id = auth.uid() and created_at > now() - interval '1 day') >= 3 then raise exception 'Trois histoires par jour au plus'; end if;
  insert into mentor_stories (author_id, title, body, company) values (auth.uid(), btrim(p_title), btrim(p_body), left(btrim(coalesce(p_company, '')), 100)) returning id into v_id;
  return v_id;
end $$;

create or replace function mentor_stories(p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'title', s.title, 'body', s.body, 'company', s.company, 'author', display_name(s.author_id), 'author_id', s.author_id, 'created_at', s.created_at) order by s.created_at desc), '[]'::jsonb)
  from (select * from mentor_stories where status = 'published' order by created_at desc limit least(greatest(coalesce(p_limit, 20), 1), 50)) s
$$;

revoke all on function mentor_save(text, text, text[], text, text, boolean, boolean), my_mentor(), mentor_match(text, boolean, integer), mentor_request(uuid, text, text),
  mentor_request_decide(uuid, boolean), my_mentor_requests(text), mentor_review(uuid, integer, text), mentor_story_save(text, text, text) from public, anon;
grant execute on function mentor_save(text, text, text[], text, text, boolean, boolean), my_mentor(), mentor_match(text, boolean, integer), mentor_request(uuid, text, text),
  mentor_request_decide(uuid, boolean), my_mentor_requests(text), mentor_review(uuid, integer, text), mentor_story_save(text, text, text) to authenticated;
revoke all on function mentors_list(text, text), mentor_detail(uuid), mentor_stories(integer) from public;
grant execute on function mentors_list(text, text), mentor_detail(uuid), mentor_stories(integer) to anon, authenticated;
