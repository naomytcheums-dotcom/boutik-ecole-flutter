-- Communautés : chat du groupe, questions et réponses, événements du groupe, fichiers partagés.
-- Tout est réservé aux membres de la communauté (sauf la lecture des questions d'une communauté publique) ; aucune écriture directe, tout passe par des fonctions.
-- Retour arrière : drop function community_chat_send(uuid, text), community_chat_list(uuid, bigint, integer), community_ask(uuid, text), community_answer(uuid, text), community_accept_answer(uuid), community_qa(uuid, integer),
--   community_event_create(uuid, text, text, timestamptz, text, text), community_events_list(uuid), community_event_rsvp(uuid, boolean), community_event_delete(uuid),
--   community_file_add(uuid, text, text, text, integer, text), community_files_list(uuid), community_file_delete(uuid);
--   drop table community_event_rsvps, community_events, community_answers, community_questions, community_messages, community_files; delete du compartiment community-files.

-- ---------------------------------------------------------------- chat du groupe
create table if not exists community_messages (
  id bigint generated always as identity primary key,
  community_id uuid not null references communities(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists community_messages_idx on community_messages (community_id, id desc);
alter table community_messages enable row level security;
revoke all on community_messages from anon, authenticated;

create or replace function community_chat_send(p_community uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_id bigint; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 1 and 1000 then raise exception 'Un message contient de 1 à 1000 caractères'; end if;
  if (select count(*) from community_messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then raise exception 'Trop de messages en peu de temps. Réessayez dans une minute.'; end if;
  insert into community_messages (community_id, sender_id, body) values (p_community, auth.uid(), v_body) returning id into v_id;
  return v_id;
end $$;

-- Derniers messages (p_after = 0) ou messages arrivés après l'identifiant donné ; du plus ancien au plus récent.
create or replace function community_chat_list(p_community uuid, p_after bigint default 0, p_limit integer default 60)
returns table (id bigint, sender_id uuid, author text, body text, created_at timestamptz, mine boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  return query
    select x.id, x.sender_id, display_name(x.sender_id), x.body, x.created_at, x.sender_id = auth.uid()
    from (select m.* from community_messages m where m.community_id = p_community and (coalesce(p_after, 0) = 0 or m.id > p_after)
          order by m.id desc limit least(greatest(coalesce(p_limit, 60), 1), 200)) x
    order by x.id;
end $$;

-- ---------------------------------------------------------------- questions et réponses
create table if not exists community_questions (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 5 and 600),
  accepted_answer uuid,
  created_at timestamptz not null default now()
);
create table if not exists community_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references community_questions(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists community_questions_idx on community_questions (community_id, created_at desc);
create index if not exists community_answers_idx on community_answers (question_id, created_at);
alter table community_questions enable row level security;
alter table community_answers enable row level security;
revoke all on community_questions, community_answers from anon, authenticated;

create or replace function community_ask(p_community uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 5 and 600 then raise exception 'Posez votre question en 5 à 600 caractères'; end if;
  if (select count(*) from community_questions where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de questions en peu de temps. Réessayez dans une minute.'; end if;
  insert into community_questions (community_id, author_id, body) values (p_community, auth.uid(), v_body) returning id into v_id;
  return v_id;
end $$;

create or replace function community_answer(p_question uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare q community_questions%rowtype; v_id uuid; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from community_questions where id = p_question;
  if not found then raise exception 'Question introuvable'; end if;
  if not is_community_member(q.community_id) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 1 and 1000 then raise exception 'Une réponse contient de 1 à 1000 caractères'; end if;
  insert into community_answers (question_id, author_id, body) values (p_question, auth.uid(), v_body) returning id into v_id;
  perform notify_user(q.author_id, 'community_answer', 'Réponse à votre question', display_name(auth.uid()) || ' a répondu à votre question.', jsonb_build_object('community', q.community_id, 'question', p_question));
  return v_id;
end $$;

-- L'auteur de la question marque la réponse qui l'a aidé (une seule) ; la question est alors « résolue ».
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
end $$;

create or replace function community_qa(p_community uuid, p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c communities%rowtype;
begin
  select * into c from communities where id = p_community and status = 'active';
  if not found then raise exception 'Communauté introuvable'; end if;
  if c.privacy <> 'public' and not is_community_member(p_community) and not is_platform_staff() then raise exception 'Réservé aux membres de la communauté'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', q.id, 'body', q.body, 'author', display_name(q.author_id), 'author_id', q.author_id, 'created_at', q.created_at, 'solved', q.accepted_answer is not null,
      'accepted_answer', q.accepted_answer, 'mine', q.author_id = auth.uid(),
      'answers', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'body', a.body, 'author', display_name(a.author_id), 'created_at', a.created_at,
                                                               'accepted', a.id = q.accepted_answer, 'mine', a.author_id = auth.uid()) order by (a.id = q.accepted_answer) desc, a.created_at)
                           from community_answers a where a.question_id = q.id), '[]'::jsonb)
    ) order by q.created_at desc)
    from (select * from community_questions where community_id = p_community order by created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 100)) q
  ), '[]'::jsonb);
end $$;

-- ---------------------------------------------------------------- événements du groupe
create table if not exists community_events (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  creator_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 100),
  kind text not null default 'meeting' check (kind in ('meeting', 'live', 'revision', 'other')),
  starts_at timestamptz not null,
  place text not null default '' check (char_length(place) <= 100),
  description text not null default '' check (char_length(description) <= 500),
  created_at timestamptz not null default now()
);
create table if not exists community_event_rsvps (
  event_id uuid not null references community_events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index if not exists community_events_idx on community_events (community_id, starts_at);
alter table community_events enable row level security;
alter table community_event_rsvps enable row level security;
revoke all on community_events, community_event_rsvps from anon, authenticated;

create or replace function community_event_create(p_community uuid, p_title text, p_kind text, p_starts timestamptz, p_place text default '', p_description text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 100 then raise exception 'Le titre contient de 3 à 100 caractères'; end if;
  if p_kind not in ('meeting', 'live', 'revision', 'other') then raise exception 'Type d''événement inconnu'; end if;
  if p_starts is null or p_starts < now() - interval '1 hour' then raise exception 'La date doit être dans le futur'; end if;
  if (select count(*) from community_events where creator_id = auth.uid() and created_at > now() - interval '1 hour') >= 5 then raise exception 'Trop d''événements créés en peu de temps'; end if;
  insert into community_events (community_id, creator_id, title, kind, starts_at, place, description)
    values (p_community, auth.uid(), btrim(p_title), p_kind, p_starts, left(btrim(coalesce(p_place, '')), 100), left(btrim(coalesce(p_description, '')), 500)) returning id into v_id;
  insert into community_event_rsvps (event_id, user_id) values (v_id, auth.uid());
  for r in select user_id from community_members where community_id = p_community and status = 'active' and user_id <> auth.uid() limit 200 loop
    perform notify_user(r.user_id, 'community_event', 'Nouvel événement', btrim(p_title) || ' · ' || to_char(p_starts at time zone 'Africa/Douala', 'DD/MM HH24:MI'), jsonb_build_object('community', p_community, 'event', v_id));
  end loop;
  return v_id;
end $$;

create or replace function community_events_list(p_community uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c communities%rowtype;
begin
  select * into c from communities where id = p_community and status = 'active';
  if not found then raise exception 'Communauté introuvable'; end if;
  if c.privacy <> 'public' and not is_community_member(p_community) and not is_platform_staff() then raise exception 'Réservé aux membres de la communauté'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'kind', e.kind, 'starts_at', e.starts_at, 'place', e.place, 'description', e.description,
      'creator', display_name(e.creator_id), 'mine', e.creator_id = auth.uid(),
      'going', (select count(*)::int from community_event_rsvps r where r.event_id = e.id),
      'i_go', exists (select 1 from community_event_rsvps r where r.event_id = e.id and r.user_id = auth.uid())) order by e.starts_at)
    from community_events e where e.community_id = p_community and e.starts_at >= now() - interval '2 hours'
  ), '[]'::jsonb);
end $$;

create or replace function community_event_rsvp(p_event uuid, p_going boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_comm uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select community_id into v_comm from community_events where id = p_event;
  if v_comm is null then raise exception 'Événement introuvable'; end if;
  if not is_community_member(v_comm) then raise exception 'Réservé aux membres de la communauté'; end if;
  if coalesce(p_going, true) then
    insert into community_event_rsvps (event_id, user_id) values (p_event, auth.uid()) on conflict do nothing;
  else
    delete from community_event_rsvps where event_id = p_event and user_id = auth.uid();
  end if;
end $$;

create or replace function community_event_delete(p_event uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e community_events%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from community_events where id = p_event;
  if not found then raise exception 'Événement introuvable'; end if;
  if e.creator_id <> auth.uid() and community_rank(e.community_id, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  delete from community_events where id = p_event;
end $$;

-- ---------------------------------------------------------------- fichiers partagés (cours, PDF, anciens sujets, modèles de CV)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-files', 'community-files', false, 20971520, array[
  'application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'text/plain', 'application/zip',
  'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
-- dépôt et lecture : seulement dans le dossier d'une communauté dont on est membre (chemin « <communauté>/<fichier> »)
drop policy if exists "fichiers communauté : dépôt par les membres" on storage.objects;
create policy "fichiers communauté : dépôt par les membres" on storage.objects for insert to authenticated
  with check (bucket_id = 'community-files' and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$' and is_community_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "fichiers communauté : lecture par les membres" on storage.objects;
create policy "fichiers communauté : lecture par les membres" on storage.objects for select to authenticated
  using (bucket_id = 'community-files' and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$' and is_community_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "fichiers communauté : suppression par le déposant" on storage.objects;
create policy "fichiers communauté : suppression par le déposant" on storage.objects for delete to authenticated
  using (bucket_id = 'community-files' and owner = auth.uid());

create table if not exists community_files (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  uploader_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 120),
  kind text not null default 'other' check (kind in ('course', 'pdf', 'exam', 'template', 'other')),
  path text not null check (char_length(path) between 10 and 300),
  size_bytes integer not null default 0 check (size_bytes >= 0 and size_bytes <= 20971520),
  mime text not null default '' check (char_length(mime) <= 120),
  created_at timestamptz not null default now()
);
create index if not exists community_files_idx on community_files (community_id, created_at desc);
alter table community_files enable row level security;
revoke all on community_files from anon, authenticated;

create or replace function community_file_add(p_community uuid, p_title text, p_kind text, p_path text, p_size integer, p_mime text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 2 and 120 then raise exception 'Le titre contient de 2 à 120 caractères'; end if;
  if p_kind not in ('course', 'pdf', 'exam', 'template', 'other') then raise exception 'Type de fichier inconnu'; end if;
  if left(coalesce(p_path, ''), 37) <> p_community::text || '/' then raise exception 'Chemin de fichier invalide'; end if;
  if (select count(*) from community_files where uploader_id = auth.uid() and created_at > now() - interval '1 hour') >= 20 then raise exception 'Trop de fichiers déposés en peu de temps'; end if;
  insert into community_files (community_id, uploader_id, title, kind, path, size_bytes, mime)
    values (p_community, auth.uid(), btrim(p_title), p_kind, p_path, greatest(coalesce(p_size, 0), 0), left(coalesce(p_mime, ''), 120)) returning id into v_id;
  return v_id;
end $$;

create or replace function community_files_list(p_community uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) and not is_platform_staff() then raise exception 'Réservé aux membres de la communauté'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'title', f.title, 'kind', f.kind, 'path', f.path, 'size', f.size_bytes, 'mime', f.mime,
      'uploader', display_name(f.uploader_id), 'mine', f.uploader_id = auth.uid(), 'created_at', f.created_at) order by f.created_at desc)
    from community_files f where f.community_id = p_community), '[]'::jsonb);
end $$;

create or replace function community_file_delete(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare f community_files%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into f from community_files where id = p_id;
  if not found then raise exception 'Fichier introuvable'; end if;
  if f.uploader_id <> auth.uid() and community_rank(f.community_id, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  delete from community_files where id = p_id;
  return f.path;   -- le client supprime ensuite l'objet du stockage
end $$;

revoke all on function community_chat_send(uuid, text), community_chat_list(uuid, bigint, integer), community_ask(uuid, text), community_answer(uuid, text), community_accept_answer(uuid),
  community_event_create(uuid, text, text, timestamptz, text, text), community_event_rsvp(uuid, boolean), community_event_delete(uuid),
  community_file_add(uuid, text, text, text, integer, text), community_files_list(uuid), community_file_delete(uuid) from public, anon;
grant execute on function community_chat_send(uuid, text), community_chat_list(uuid, bigint, integer), community_ask(uuid, text), community_answer(uuid, text), community_accept_answer(uuid),
  community_event_create(uuid, text, text, timestamptz, text, text), community_event_rsvp(uuid, boolean), community_event_delete(uuid),
  community_file_add(uuid, text, text, text, integer, text), community_files_list(uuid), community_file_delete(uuid) to authenticated;
revoke all on function community_qa(uuid, integer), community_events_list(uuid) from public;
grant execute on function community_qa(uuid, integer), community_events_list(uuid) to anon, authenticated;
