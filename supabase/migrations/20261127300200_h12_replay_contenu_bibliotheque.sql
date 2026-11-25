-- H12 LIVE-REPLAY, étape 3 : contenu du replay (chapitres, réactions horodatées, commentaires modérés, recherche, notes, clips), bibliothèque, annuaire, partage externe.
--  * replay_chapters (par l'hôte), replay_reactions (horodatées, cadence limitée), replay_comments (+ réponses, masquage par l'hôte ou l'équipe, blocage par l'hôte, blocages entre membres respectés),
--    replay_ratings (note 1 à 5 après visionnage d'une part minimale du replay, pas de note de son propre replay), replay_transcripts (alimentée par un futur fournisseur : sinon « transcription non configurée »),
--    replay_clips (demande de clip 30 s / 1 min / 3 min : le rendu dépend du fournisseur vidéo => statut « service_a_configurer », jamais de faux fichier) ;
--  * replay_library (tri popularité / date / note / taux de complétion, agrégats serveur), replay_search (titre, chapitres, transcription si elle existe), replay_detail,
--    replay_share_info (lien public : respecte l'accès du live), replay_hosts_directory (annuaire agrégé, profils publics seulement) ;
--  * aucune lecture directe des tables par les clients : tout passe par des fonctions qui contrôlent l'accès hérité du live.
-- Strictement additif. Retour arrière : drop function des fonctions replay_* de ce fichier ; drop table replay_clips, replay_ratings, replay_transcripts, replay_comment_blocks, replay_comments, replay_reactions, replay_chapters.

create table if not exists replay_chapters (
  id uuid primary key default gen_random_uuid(),
  recording_id uuid not null references live_recordings(id) on delete cascade,
  start_sec numeric not null check (start_sec >= 0),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (recording_id, start_sec)
);
create table if not exists replay_reactions (
  id bigint generated always as identity primary key,
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  at_sec numeric not null check (at_sec >= 0),
  emoji text not null check (emoji in ('heart', 'fire', 'clap', 'laugh', 'wow')),
  created_at timestamptz not null default now()
);
create index if not exists replay_reactions_rec on replay_reactions (recording_id, at_sec);
create index if not exists replay_reactions_user on replay_reactions (user_id, recording_id, created_at desc);
create table if not exists replay_comments (
  id uuid primary key default gen_random_uuid(),
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  parent_id uuid references replay_comments(id) on delete cascade,
  at_sec numeric check (at_sec is null or at_sec >= 0),
  body text not null check (char_length(btrim(body)) between 1 and 500),
  hidden boolean not null default false,
  hidden_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists replay_comments_rec on replay_comments (recording_id, created_at);
create table if not exists replay_comment_blocks (
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  blocked_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (recording_id, user_id)
);
create table if not exists replay_transcripts (
  id bigint generated always as identity primary key,
  recording_id uuid not null references live_recordings(id) on delete cascade,
  start_sec numeric not null check (start_sec >= 0),
  end_sec numeric not null check (end_sec >= start_sec),
  lang text not null default 'fr' check (char_length(lang) between 2 and 8),
  text text not null check (char_length(text) between 1 and 1000)
);
create index if not exists replay_transcripts_rec on replay_transcripts (recording_id, start_sec);
create table if not exists replay_ratings (
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  updated_at timestamptz not null default now(),
  primary key (recording_id, user_id)
);
create table if not exists replay_clips (
  id uuid primary key default gen_random_uuid(),
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  from_sec numeric not null check (from_sec >= 0),
  len_sec integer not null check (len_sec in (30, 60, 180)),
  status text not null default 'service_a_configurer' check (status in ('service_a_configurer', 'en_cours', 'pret', 'echec')),
  storage_path text check (storage_path is null or char_length(storage_path) between 5 and 300),
  created_at timestamptz not null default now(),
  check (status <> 'pret' or storage_path is not null)
);
create index if not exists replay_clips_user on replay_clips (user_id, created_at desc);
alter table replay_chapters enable row level security;
alter table replay_reactions enable row level security;
alter table replay_comments enable row level security;
alter table replay_comment_blocks enable row level security;
alter table replay_transcripts enable row level security;
alter table replay_ratings enable row level security;
alter table replay_clips enable row level security;
revoke all on replay_chapters, replay_reactions, replay_comments, replay_comment_blocks, replay_transcripts, replay_ratings, replay_clips from anon, authenticated;

create or replace function _replay_host(p_recording uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select l.host_id from live_recordings r join lives l on l.id = r.live_id where r.id = p_recording
$$;
revoke all on function _replay_host(uuid) from public, anon, authenticated;

create or replace function _replay_like(p_q text) returns text
language sql immutable as $$
  select '%' || replace(replace(replace(btrim(coalesce(p_q, '')), '\', '\\'), '%', '\%'), '_', '\_') || '%'
$$;

-- ------------------------------------------------------------------ chapitres (hôte)
create or replace function replay_chapter_set(p_recording uuid, p_start numeric, p_title text, p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare dur numeric; cid uuid;
begin
  perform _assert_active();
  if _replay_host(p_recording) is distinct from auth.uid() then raise exception 'Action non autorisée'; end if;
  select duration_sec into dur from live_recordings where id = p_recording and status = 'pret';
  if dur is null then raise exception 'Replay introuvable ou pas encore prêt'; end if;
  if p_start is null or p_start < 0 or p_start >= dur then raise exception 'Le chapitre doit commencer dans la durée du replay'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 1 and 120 then raise exception 'Titre du chapitre : 1 à 120 caractères'; end if;
  if p_id is null and (select count(*) from replay_chapters where recording_id = p_recording) >= 50 then raise exception '50 chapitres au maximum'; end if;
  if p_id is not null then
    update replay_chapters set start_sec = round(p_start, 2), title = btrim(p_title) where id = p_id and recording_id = p_recording returning id into cid;
    if cid is null then raise exception 'Chapitre introuvable'; end if;
    return cid;
  end if;
  insert into replay_chapters (recording_id, start_sec, title, created_by) values (p_recording, round(p_start, 2), btrim(p_title), auth.uid())
    on conflict (recording_id, start_sec) do update set title = excluded.title returning id into cid;
  return cid;
end $$;
revoke all on function replay_chapter_set(uuid, numeric, text, uuid) from public, anon;
grant execute on function replay_chapter_set(uuid, numeric, text, uuid) to authenticated;

create or replace function replay_chapter_delete(p_chapter uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare rec uuid;
begin
  perform _assert_active();
  select recording_id into rec from replay_chapters where id = p_chapter;
  if rec is null then raise exception 'Chapitre introuvable'; end if;
  if _replay_host(rec) is distinct from auth.uid() then raise exception 'Action non autorisée'; end if;
  delete from replay_chapters where id = p_chapter;
  return true;
end $$;
revoke all on function replay_chapter_delete(uuid) from public, anon;
grant execute on function replay_chapter_delete(uuid) to authenticated;

-- ------------------------------------------------------------------ réactions horodatées
create or replace function replay_react(p_recording uuid, p_at numeric, p_emoji text) returns boolean
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); dur numeric; acc text;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select duration_sec into dur from live_recordings where id = p_recording;
  if p_emoji is null or p_emoji not in ('heart', 'fire', 'clap', 'laugh', 'wow') then raise exception 'Réaction inconnue'; end if;
  if p_at is null or p_at < 0 or p_at > dur then raise exception 'Instant hors de la durée du replay'; end if;
  if exists (select 1 from replay_reactions where recording_id = p_recording and user_id = uid and created_at > clock_timestamp() - interval '1 second') then raise exception 'Trop de réactions : patientez un instant'; end if;
  if (select count(*) from replay_reactions where recording_id = p_recording and user_id = uid) >= 300 then raise exception 'Limite de réactions atteinte pour ce replay'; end if;
  insert into replay_reactions (recording_id, user_id, at_sec, emoji) values (p_recording, uid, round(p_at, 2), p_emoji);
  return true;
end $$;
revoke all on function replay_react(uuid, numeric, text) from public, anon;
grant execute on function replay_react(uuid, numeric, text) to authenticated;

-- ------------------------------------------------------------------ commentaires, réponses, modération
create or replace function replay_comment_post(p_recording uuid, p_body text, p_parent uuid default null, p_at numeric default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); acc text; par replay_comments%rowtype; cid uuid; m replay_meta; dur numeric; host uuid; t text := btrim(coalesce(p_body, ''));
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  m := _replay_meta(p_recording);
  host := _replay_host(p_recording);
  if not m.comments_enabled and uid <> host then raise exception 'Les commentaires sont désactivés sur ce replay'; end if;
  if exists (select 1 from replay_comment_blocks where recording_id = p_recording and user_id = uid) then raise exception 'Vous ne pouvez plus commenter ce replay'; end if;
  if char_length(t) not between 1 and 500 then raise exception 'Commentaire : 1 à 500 caractères'; end if;
  select duration_sec into dur from live_recordings where id = p_recording;
  if p_at is not null and (p_at < 0 or p_at > dur) then raise exception 'Instant hors de la durée du replay'; end if;
  if (select count(*) from replay_comments where user_id = uid and created_at > clock_timestamp() - interval '60 seconds') >= 8 then raise exception 'Trop de commentaires : patientez un instant'; end if;
  if p_parent is not null then
    select * into par from replay_comments where id = p_parent and recording_id = p_recording and not hidden;
    if not found then raise exception 'Commentaire introuvable'; end if;
    if par.parent_id is not null then raise exception 'On ne répond qu''à un commentaire principal'; end if;
  end if;
  insert into replay_comments (recording_id, user_id, parent_id, at_sec, body) values (p_recording, uid, p_parent, case when p_parent is null then round(p_at, 2) end, t) returning id into cid;
  if p_parent is not null then
    perform notify_user(par.user_id, 'live', 'Réponse à votre commentaire', _live_author(uid) || ' a répondu à votre commentaire sur un replay.', jsonb_build_object('recording', p_recording, 'comment', cid));
  else
    perform notify_user(host, 'live', 'Nouveau commentaire sur votre replay', _live_author(uid) || ' a commenté votre replay.', jsonb_build_object('recording', p_recording, 'comment', cid));
  end if;
  return cid;
end $$;
revoke all on function replay_comment_post(uuid, text, uuid, numeric) from public, anon;
grant execute on function replay_comment_post(uuid, text, uuid, numeric) to authenticated;

create or replace function replay_comments_list(p_recording uuid, p_limit integer default 200) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); acc text := _replay_access(p_recording, auth.uid()); host uuid := _replay_host(p_recording); mod boolean;
begin
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  mod := uid = host or is_platform_staff();
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'parent_id', c.parent_id, 'at_sec', c.at_sec, 'body', c.body, 'created_at', c.created_at,
      'author', _short_name(p.name), 'author_id', c.user_id, 'mine', c.user_id = uid, 'by_host', c.user_id = host, 'hidden', c.hidden) order by c.created_at)
    from (select * from replay_comments x where x.recording_id = p_recording order by x.created_at desc limit least(greatest(coalesce(p_limit, 200), 1), 300)) c
    join profiles p on p.id = c.user_id
    where (mod or (not c.hidden and not exists (select 1 from replay_comment_blocks b where b.recording_id = p_recording and b.user_id = c.user_id)))
      and (c.user_id = uid or not exists (select 1 from user_blocks ub where (ub.blocker_id = uid and ub.blocked_id = c.user_id) or (ub.blocker_id = c.user_id and ub.blocked_id = uid)))), '[]'::jsonb);
end $$;
revoke all on function replay_comments_list(uuid, integer) from public, anon;
grant execute on function replay_comments_list(uuid, integer) to authenticated;

create or replace function replay_comment_hide(p_comment uuid, p_hidden boolean default true) returns boolean
language plpgsql security definer set search_path = public as $$
declare c replay_comments%rowtype;
begin
  perform _assert_active();
  select * into c from replay_comments where id = p_comment;
  if not found then raise exception 'Commentaire introuvable'; end if;
  if _replay_host(c.recording_id) is distinct from auth.uid() and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  update replay_comments set hidden = coalesce(p_hidden, true), hidden_by = case when coalesce(p_hidden, true) then auth.uid() end where id = p_comment;
  return true;
end $$;
revoke all on function replay_comment_hide(uuid, boolean) from public, anon;
grant execute on function replay_comment_hide(uuid, boolean) to authenticated;

create or replace function replay_comment_block(p_recording uuid, p_user uuid, p_blocked boolean default true) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform _assert_active();
  if _replay_host(p_recording) is distinct from auth.uid() then raise exception 'Action non autorisée'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous bloquer vous-même'; end if;
  if coalesce(p_blocked, true) then
    insert into replay_comment_blocks (recording_id, user_id, blocked_by) values (p_recording, p_user, auth.uid()) on conflict do nothing;
  else
    delete from replay_comment_blocks where recording_id = p_recording and user_id = p_user;
  end if;
  return true;
end $$;
revoke all on function replay_comment_block(uuid, uuid, boolean) from public, anon;
grant execute on function replay_comment_block(uuid, uuid, boolean) to authenticated;

-- ------------------------------------------------------------------ notes
create or replace function replay_rate(p_recording uuid, p_stars integer) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); acc text; s replay_settings%rowtype; pr replay_progress%rowtype; dur numeric;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  if p_stars is null or p_stars not between 1 and 5 then raise exception 'Note : de 1 à 5'; end if;
  if _replay_host(p_recording) = uid then raise exception 'Vous ne pouvez pas noter votre propre replay'; end if;
  select * into s from replay_settings where id;
  select duration_sec into dur from live_recordings where id = p_recording;
  select * into pr from replay_progress where user_id = uid and recording_id = p_recording;
  if coalesce(pr.covered_sec, 0) < s.rating_min_coverage * dur then
    raise exception 'Regardez au moins % %% du replay avant de le noter', round(s.rating_min_coverage * 100);
  end if;
  insert into replay_ratings (recording_id, user_id, stars) values (p_recording, uid, p_stars)
    on conflict (recording_id, user_id) do update set stars = excluded.stars, updated_at = now();
  return (select jsonb_build_object('avg', round(avg(stars)::numeric, 2), 'count', count(*)::int, 'mine', p_stars) from replay_ratings where recording_id = p_recording);
end $$;
revoke all on function replay_rate(uuid, integer) from public, anon;
grant execute on function replay_rate(uuid, integer) to authenticated;

-- ------------------------------------------------------------------ clips
create or replace function replay_clip_request(p_recording uuid, p_from numeric, p_len integer) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); acc text; dur numeric; m replay_meta; cid uuid;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  m := _replay_meta(p_recording);
  if not m.clips_allowed and _replay_host(p_recording) <> uid then raise exception 'L''hôte n''autorise pas les clips sur ce replay'; end if;
  if p_len is null or p_len not in (30, 60, 180) then raise exception 'Durée de clip : 30 secondes, 1 minute ou 3 minutes'; end if;
  select duration_sec into dur from live_recordings where id = p_recording;
  if p_from is null or p_from < 0 or p_from + p_len > dur then raise exception 'Le clip doit tenir entièrement dans la durée du replay'; end if;
  if (select count(*) from replay_clips where user_id = uid and created_at > now() - interval '1 day') >= 10 then raise exception 'Limite de 10 demandes de clip par jour atteinte'; end if;
  insert into replay_clips (recording_id, user_id, from_sec, len_sec) values (p_recording, uid, round(p_from, 2), p_len) returning id into cid;
  return jsonb_build_object('id', cid, 'status', 'service_a_configurer',
    'message', 'Demande enregistrée. Le rendu des clips dépend d''un fournisseur vidéo qui n''est pas encore configuré : aucun fichier n''est créé pour le moment.');
end $$;
revoke all on function replay_clip_request(uuid, numeric, integer) from public, anon;
grant execute on function replay_clip_request(uuid, numeric, integer) to authenticated;

create or replace function replay_clips_mine(p_recording uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _assert_active();
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'recording_id', c.recording_id, 'from_sec', c.from_sec, 'len_sec', c.len_sec, 'status', c.status, 'created_at', c.created_at) order by c.created_at desc)
    from (select * from replay_clips where user_id = auth.uid() and (p_recording is null or recording_id = p_recording) order by created_at desc limit 50) c), '[]'::jsonb);
end $$;
revoke all on function replay_clips_mine(uuid) from public, anon;
grant execute on function replay_clips_mine(uuid) to authenticated;

-- Retour du futur fournisseur de rendu vidéo.
create or replace function replay_clip_mark(p_clip uuid, p_status text, p_path text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_status not in ('en_cours', 'pret', 'echec') then raise exception 'Statut de clip invalide'; end if;
  update replay_clips set status = p_status, storage_path = case when p_status = 'pret' then p_path else storage_path end where id = p_clip;
  if not found then raise exception 'Clip introuvable'; end if;
end $$;
revoke all on function replay_clip_mark(uuid, text, text) from public, anon, authenticated;
grant execute on function replay_clip_mark(uuid, text, text) to service_role;

-- Transcription : alimentée par un futur fournisseur (service_role). Sans elle, la recherche ne porte que sur le titre et les chapitres.
create or replace function replay_transcript_store(p_recording uuid, p_lang text, p_segments jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare e jsonb; n integer := 0;
begin
  if not exists (select 1 from live_recordings where id = p_recording and status = 'pret') then raise exception 'Replay prêt introuvable'; end if;
  if p_segments is null or jsonb_typeof(p_segments) <> 'array' or jsonb_array_length(p_segments) > 5000 then raise exception 'Segments invalides'; end if;
  delete from replay_transcripts where recording_id = p_recording and lang = coalesce(p_lang, 'fr');
  for e in select * from jsonb_array_elements(p_segments) loop
    insert into replay_transcripts (recording_id, start_sec, end_sec, lang, text)
      values (p_recording, (e->>'start')::numeric, (e->>'end')::numeric, coalesce(p_lang, 'fr'), left(btrim(e->>'text'), 1000));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function replay_transcript_store(uuid, text, jsonb) from public, anon, authenticated;
grant execute on function replay_transcript_store(uuid, text, jsonb) to service_role;

-- ------------------------------------------------------------------ bibliothèque et recherche
-- Vues qualifiées = personnes ayant réellement lu au moins 10 % du replay (30 s au minimum) ; taux de complétion = complétions / personnes ayant ouvert une session de lecture.
create or replace function replay_library(p_query text default '', p_sort text default 'date', p_limit integer default 30, p_offset integer default 0, p_host uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); q text := _replay_like(p_query); has_q boolean := btrim(coalesce(p_query, '')) <> ''; srt text := coalesce(p_sort, 'date');
  lim integer := least(greatest(coalesce(p_limit, 30), 1), 50); off integer := greatest(coalesce(p_offset, 0), 0);
begin
  if srt not in ('date', 'popularity', 'rating', 'completion') then srt := 'date'; end if;
  return coalesce((select jsonb_agg(z.j order by z.rn) from (
    select y.j, row_number() over (order by
        case when srt = 'popularity' then y.views end desc nulls last,
        case when srt = 'rating' then y.rating_avg end desc nulls last,
        case when srt = 'rating' then y.rating_count end desc nulls last,
        case when srt = 'completion' then y.completion_rate end desc nulls last,
        y.ready_at desc, y.id) rn
    from (
      select x.*, jsonb_build_object('id', x.id, 'live_id', x.live_id, 'title', x.title, 'description', x.description, 'host_id', x.host_id, 'host', x.host_name, 'host_avatar', x.host_avatar,
          'duration_sec', x.duration_sec, 'ready_at', x.ready_at, 'access', x.acc, 'locked', x.acc <> 'ok', 'message', _replay_msg(x.acc),
          'views', x.views, 'viewers', x.viewers, 'completions', x.completions, 'completion_rate', x.completion_rate, 'rating_avg', x.rating_avg, 'rating_count', x.rating_count,
          'comments_count', x.comments_count, 'chapters_count', x.chapters_count) j
      from (
        select r.id, r.live_id, l.title, l.description, l.host_id, _short_name(p.name) host_name, p.avatar_url host_avatar, r.duration_sec, r.ready_at, a.acc,
          (select count(*)::int from replay_progress g where g.recording_id = r.id and g.covered_sec >= greatest(30, 0.1 * r.duration_sec)) views,
          (select count(*)::int from replay_progress g where g.recording_id = r.id) viewers,
          (select count(*)::int from replay_completions c where c.recording_id = r.id) completions,
          (select case when count(*) > 0 then round(100.0 * (select count(*) from replay_completions c where c.recording_id = r.id) / count(*), 1) end from replay_progress g where g.recording_id = r.id) completion_rate,
          (select round(avg(stars)::numeric, 2) from replay_ratings t where t.recording_id = r.id) rating_avg,
          (select count(*)::int from replay_ratings t where t.recording_id = r.id) rating_count,
          (select count(*)::int from replay_comments t where t.recording_id = r.id and not t.hidden) comments_count,
          (select count(*)::int from replay_chapters t where t.recording_id = r.id) chapters_count
        from live_recordings r
        join lives l on l.id = r.live_id
        join profiles p on p.id = l.host_id and not coalesce(p.suspended, false)
        cross join lateral (select _replay_listing_access(r.id, uid) acc) a
        where r.status = 'pret' and a.acc is not null and (p_host is null or l.host_id = p_host)
          and (not has_q or l.title ilike q or l.description ilike q or p.name ilike q
               or (a.acc = 'ok' and (exists (select 1 from replay_chapters c where c.recording_id = r.id and c.title ilike q)
                                     or exists (select 1 from replay_transcripts t where t.recording_id = r.id and t.text ilike q))))
      ) x
    ) y
  ) z where z.rn > off and z.rn <= off + lim), '[]'::jsonb);
end $$;
revoke all on function replay_library(text, text, integer, integer, uuid) from public;
grant execute on function replay_library(text, text, integer, integer, uuid) to anon, authenticated;

create or replace function replay_search(p_query text, p_limit integer default 40) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); q text := _replay_like(p_query); transcribed boolean := exists (select 1 from replay_transcripts limit 1);
begin
  if char_length(btrim(coalesce(p_query, ''))) < 2 then raise exception 'Saisissez au moins 2 caractères'; end if;
  return jsonb_build_object('transcription_configured', transcribed,
    'message', case when transcribed then '' else 'Transcription non configurée : la recherche porte sur les titres et les chapitres.' end,
    'hits', coalesce((select jsonb_agg(h.j order by h.ord) from (
      select h0.j, row_number() over (order by h0.rank, h0.title, h0.at_sec) ord from (
        select 0 rank, v.title, 0::numeric at_sec, jsonb_build_object('recording_id', v.id, 'title', v.title, 'kind', 'title', 'at_sec', 0, 'snippet', v.title, 'locked', v.acc <> 'ok') j
          from (select r.id, l.title, _replay_listing_access(r.id, uid) acc from live_recordings r join lives l on l.id = r.live_id where r.status = 'pret') v where v.acc is not null and v.title ilike q
        union all
        select 1, v.title, c.start_sec, jsonb_build_object('recording_id', v.id, 'title', v.title, 'kind', 'chapter', 'at_sec', c.start_sec, 'snippet', c.title, 'locked', false)
          from (select r.id, l.title, _replay_listing_access(r.id, uid) acc from live_recordings r join lives l on l.id = r.live_id where r.status = 'pret') v
          join replay_chapters c on c.recording_id = v.id where v.acc = 'ok' and c.title ilike q
        union all
        select 2, v.title, t.start_sec, jsonb_build_object('recording_id', v.id, 'title', v.title, 'kind', 'transcript', 'at_sec', t.start_sec, 'snippet', left(t.text, 200), 'locked', false)
          from (select r.id, l.title, _replay_listing_access(r.id, uid) acc from live_recordings r join lives l on l.id = r.live_id where r.status = 'pret') v
          join replay_transcripts t on t.recording_id = v.id where v.acc = 'ok' and t.text ilike q
      ) h0 limit least(greatest(coalesce(p_limit, 40), 1), 100)) h), '[]'::jsonb));
end $$;
revoke all on function replay_search(text, integer) from public;
grant execute on function replay_search(text, integer) to anon, authenticated;

-- ------------------------------------------------------------------ fiche du replay (lecteur)
create or replace function replay_detail(p_recording uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); r live_recordings%rowtype; l lives%rowtype; acc text; m replay_meta; modes jsonb; host_name text; only_complete boolean; ok boolean;
begin
  acc := _replay_listing_access(p_recording, uid);
  if acc is null then return jsonb_build_object('available', false, 'reason', 'introuvable', 'message', 'Replay introuvable ou inaccessible.'); end if;
  ok := acc = 'ok';
  select * into r from live_recordings where id = p_recording;
  select * into l from lives where id = r.live_id;
  select _short_name(name) into host_name from profiles where id = l.host_id;
  m := _replay_meta(p_recording);
  modes := (select jsonb_agg(jsonb_build_object('kind', k.kind, 'label', k.label,
      'available', ok and case when k.kind = 'complete' then r.storage_path is not null else exists (select 1 from jsonb_array_elements(r.tracks) t where t->>'kind' = k.kind) end,
      'reason', case when k.kind = 'complete' then '' when exists (select 1 from jsonb_array_elements(r.tracks) t where t->>'kind' = k.kind) then '' else 'Piste non enregistrée pour ce replay' end) order by k.ord)
    from (values (1, 'complete', 'Vidéo intégrale'), (2, 'presenter', 'Vue Animateur'), (3, 'screen', 'Vue Écran'), (4, 'dual', 'Vue Double'), (5, 'audio', 'Audio seul')) as k(ord, kind, label));
  only_complete := not exists (select 1 from jsonb_array_elements(r.tracks) t where t->>'kind' in ('presenter', 'screen', 'dual', 'audio'));
  return jsonb_build_object('available', true, 'id', r.id, 'live_id', r.live_id, 'title', l.title, 'description', l.description, 'host_id', l.host_id, 'host', host_name,
    'duration_sec', r.duration_sec, 'ready_at', r.ready_at, 'access', acc, 'locked', not ok, 'message', _replay_msg(acc), 'mine', l.host_id = uid,
    'modes', modes, 'modes_message', case when only_complete then 'Un seul enregistrement est disponible : les vues Animateur, Écran, Double et l''Audio seul ne sont pas proposés pour ce replay.' else '' end,
    'chapters', case when ok then coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'start_sec', c.start_sec, 'title', c.title) order by c.start_sec) from replay_chapters c where c.recording_id = r.id), '[]'::jsonb) else '[]'::jsonb end,
    'meta', jsonb_build_object('certificate_enabled', m.certificate_enabled, 'share_enabled', m.share_enabled, 'comments_enabled', m.comments_enabled, 'clips_allowed', m.clips_allowed, 'published', m.published),
    'transcript_available', exists (select 1 from replay_transcripts t where t.recording_id = r.id),
    'rating_avg', (select round(avg(stars)::numeric, 2) from replay_ratings t where t.recording_id = r.id),
    'rating_count', (select count(*)::int from replay_ratings t where t.recording_id = r.id),
    'my_rating', (select stars from replay_ratings t where t.recording_id = r.id and t.user_id = uid),
    'comments_count', (select count(*)::int from replay_comments t where t.recording_id = r.id and not t.hidden),
    'reactions', case when ok then coalesce((select jsonb_agg(jsonb_build_object('t', b.t, 'emoji', b.emoji, 'n', b.n) order by b.t, b.emoji)
        from (select (floor(at_sec / 10) * 10) t, emoji, count(*)::int n from replay_reactions where recording_id = r.id group by 1, 2 order by 1 limit 400) b), '[]'::jsonb) else '[]'::jsonb end);
end $$;
revoke all on function replay_detail(uuid) from public;
grant execute on function replay_detail(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ partage externe (lien public)
-- Le lien ouvre la fiche : titre, animateur, durée ; la lecture exige la connexion et l'accès du live (privé, invités, billet) ; un replay privé ou masqué ne révèle rien.
create or replace function replay_share_info(p_recording uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); r live_recordings%rowtype; l lives%rowtype; acc text; m replay_meta;
begin
  acc := _replay_listing_access(p_recording, uid);
  if acc is null then return jsonb_build_object('available', false, 'reason', 'introuvable', 'message', 'Replay introuvable ou privé.'); end if;
  select * into r from live_recordings where id = p_recording;
  select * into l from lives where id = r.live_id;
  m := _replay_meta(p_recording);
  if not m.share_enabled and l.host_id is distinct from uid then return jsonb_build_object('available', false, 'reason', 'partage_desactive', 'message', 'L''hôte a désactivé le partage de ce replay.'); end if;
  return jsonb_build_object('available', true, 'id', r.id, 'title', l.title, 'description', l.description, 'host', _live_author(l.host_id), 'duration_sec', r.duration_sec,
    'access', acc, 'message', _replay_msg(acc), 'path', '/replay/' || r.id::text);
end $$;
revoke all on function replay_share_info(uuid) from public;
grant execute on function replay_share_info(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ annuaire des animateurs
-- Agrégats publics : profils publics seulement, lives publics non annulés, replays prêts et publiés ; les abonnés viennent des engagements « follow ».
create or replace function replay_hosts_directory(p_query text default '', p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); q text := _replay_like(p_query); has_q boolean := btrim(coalesce(p_query, '')) <> '';
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name, 'role', d.role, 'institution', d.institution, 'avatar_url', d.avatar_url,
      'lives', d.lives, 'replays', d.replays, 'followers', d.followers) order by d.followers desc, d.replays desc, d.lives desc, d.id)
    from (
      select p.id, _short_name(p.name) name, case when p.role::text in ('student', 'company') then p.role::text else 'other' end role, coalesce(p.institution, '') institution, p.avatar_url,
        (select count(*)::int from lives l where l.host_id = p.id and l.visibilite = 'public' and l.status in ('live', 'ended')) lives,
        (select count(*)::int from live_recordings r join lives l on l.id = r.live_id where l.host_id = p.id and l.visibilite = 'public' and r.status = 'pret'
           and coalesce((select m.published from replay_meta m where m.recording_id = r.id), true)) replays,
        (select count(*)::int from engagements e where e.kind = 'follow' and e.ref = p.id::text and e.status = 'active') followers
      from profiles p
      where p.profile_visibility = 'public' and not coalesce(p.suspended, false) and p.role::text not in ('admin', 'support')
        and exists (select 1 from lives l where l.host_id = p.id and l.visibilite = 'public' and l.status in ('live', 'ended'))
        and (uid is null or not exists (select 1 from user_blocks b where (b.blocker_id = uid and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = uid)))
        and (not has_q or p.name ilike q or p.institution ilike q)
      order by 8 desc, 7 desc limit least(greatest(coalesce(p_limit, 30), 1), 50)) d), '[]'::jsonb);
end $$;
revoke all on function replay_hosts_directory(text, integer) from public;
grant execute on function replay_hosts_directory(text, integer) to anon, authenticated;
