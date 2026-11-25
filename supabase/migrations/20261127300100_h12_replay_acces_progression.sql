-- H12 LIVE-REPLAY, étape 2 : accès au replay, progression fiable côté serveur, complétion, badge « J'ai suivi », certificat de suivi, quiz facultatif.
--  * replay_settings : réglages de la progression (seuil de complétion par défaut 98 % de la durée, vitesse maximale 2x, cadence, anti-rafale) ;
--  * replay_meta : réglages par replay choisis par l'hôte (publié, certificat de suivi, partage externe, commentaires, clips) ;
--  * _replay_access(replay, user) : le replay hérite de la règle d'accès du live (_live_access : payant/billet, invités, privé, banni, suspendu) ;
--    replay_play_url(replay, piste) ne renvoie un chemin que si l'accès est « ok » (jamais d'URL pour un accès refusé) ; ticket court de 15 minutes ;
--  * replay_progress : intervalles vus (union), position, temps lu et temps réel ; replay_playback_start/stop/progress_report ne créditent un segment que s'il est plausible
--    (lecture signalée active, pas de saut, vitesse <= 2x en temps réel serveur, cadence minimale, anti-rafale, pas de rejeu, cumul borné par le temps écoulé) ;
--  * replay_completions : UNE ligne par (utilisateur, replay) à la complétion ; événement exploitable par le futur moteur Top 100 (aucun score calculé ici) ;
--  * user_badges (minimale) : badge « J'ai suivi » ; replay_certificates : certificat de suivi seulement si l'hôte l'a activé et si le quiz facultatif (s'il existe) est réussi ;
--  * replay_quizzes / replay_quiz_attempts : quiz facultatif défini par l'hôte, correction côté serveur (les bonnes réponses ne sont jamais renvoyées).
-- Strictement additif. Retour arrière : drop function des fonctions replay_* ci-dessous et _replay_* ; drop table replay_quiz_attempts, replay_quizzes, replay_certificates, user_badges,
--   replay_completions, replay_progress, replay_meta, replay_settings.

create table if not exists replay_settings (
  id boolean primary key default true check (id),
  completion_threshold numeric not null default 0.98 check (completion_threshold between 0.5 and 1),
  max_speed numeric not null default 2 check (max_speed between 1 and 4),
  min_interval_sec numeric not null default 2 check (min_interval_sec between 0.5 and 30),
  max_segment_sec numeric not null default 30 check (max_segment_sec between 5 and 120),
  burst_per_min integer not null default 40 check (burst_per_min between 5 and 300),
  idle_timeout_sec numeric not null default 30 check (idle_timeout_sec between 10 and 300),
  jump_tolerance_sec numeric not null default 1.5 check (jump_tolerance_sec between 0.5 and 5),
  rating_min_coverage numeric not null default 0.2 check (rating_min_coverage between 0 and 1),
  updated_at timestamptz not null default now()
);
insert into replay_settings (id) values (true) on conflict do nothing;
alter table replay_settings enable row level security;
revoke all on replay_settings from anon, authenticated;

create table if not exists replay_meta (
  recording_id uuid primary key references live_recordings(id) on delete cascade,
  published boolean not null default true,
  certificate_enabled boolean not null default false,
  share_enabled boolean not null default true,
  comments_enabled boolean not null default true,
  clips_allowed boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table replay_meta enable row level security;
revoke all on replay_meta from anon, authenticated;

create table if not exists replay_progress (
  user_id uuid not null references profiles(id) on delete cascade,
  recording_id uuid not null references live_recordings(id) on delete cascade,
  intervals jsonb not null default '[]'::jsonb,
  covered_sec numeric not null default 0 check (covered_sec >= 0),
  watched_sec numeric not null default 0 check (watched_sec >= 0),
  real_sec numeric not null default 0 check (real_sec >= 0),
  position_sec numeric not null default 0 check (position_sec >= 0),
  last_to numeric not null default 0,
  session_active boolean not null default false,
  session_at timestamptz,
  last_client_ts bigint,
  win_start timestamptz,
  win_count integer not null default 0,
  rejected_count integer not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, recording_id)
);
create index if not exists replay_progress_rec on replay_progress (recording_id);
alter table replay_progress enable row level security;
revoke all on replay_progress from anon, authenticated;
grant select on replay_progress to authenticated;
drop policy if exists "progression de replay : la mienne" on replay_progress;
create policy "progression de replay : la mienne" on replay_progress for select using (user_id = auth.uid());

create table if not exists replay_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  recording_id uuid not null references live_recordings(id) on delete cascade,
  live_id uuid not null references lives(id) on delete cascade,
  completed_at timestamptz not null default now(),
  coverage numeric not null check (coverage between 0 and 1.0001),
  watched_sec numeric not null,
  unique (user_id, recording_id)
);
create index if not exists replay_completions_user on replay_completions (user_id, completed_at desc);
alter table replay_completions enable row level security;
revoke all on replay_completions from anon, authenticated;
grant select on replay_completions to authenticated;
drop policy if exists "complétions de replay : les miennes" on replay_completions;
create policy "complétions de replay : les miennes" on replay_completions for select using (user_id = auth.uid());

create table if not exists user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  code text not null check (char_length(code) between 2 and 60),
  label text not null check (char_length(label) between 2 and 120),
  ref_kind text not null default '' check (char_length(ref_kind) <= 40),
  ref_id uuid not null,
  awarded_at timestamptz not null default now(),
  unique (user_id, code, ref_kind, ref_id)
);
create index if not exists user_badges_user on user_badges (user_id, awarded_at desc);
alter table user_badges enable row level security;
revoke all on user_badges from anon, authenticated;
grant select on user_badges to authenticated;
drop policy if exists "badges : les miens" on user_badges;
create policy "badges : les miens" on user_badges for select using (user_id = auth.uid());

create table if not exists replay_certificates (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^BE-SUIVI-[0-9A-F]{8}$'),
  user_id uuid not null references profiles(id) on delete cascade,
  recording_id uuid not null references live_recordings(id) on delete cascade,
  holder_name text not null,
  title text not null,
  issued_at timestamptz not null default now(),
  fingerprint text not null,
  revoked boolean not null default false,
  unique (user_id, recording_id)
);
alter table replay_certificates enable row level security;
revoke all on replay_certificates from anon, authenticated;
grant select on replay_certificates to authenticated;
drop policy if exists "certificats de suivi : les miens" on replay_certificates;
create policy "certificats de suivi : les miens" on replay_certificates for select using (user_id = auth.uid());

create table if not exists replay_quizzes (
  recording_id uuid primary key references live_recordings(id) on delete cascade,
  title text not null default 'Quiz' check (char_length(title) between 1 and 120),
  pass_pct integer not null default 70 check (pass_pct between 50 and 100),
  questions jsonb not null check (jsonb_typeof(questions) = 'array' and jsonb_array_length(questions) between 1 and 20),
  updated_at timestamptz not null default now()
);
create table if not exists replay_quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  score_pct integer not null check (score_pct between 0 and 100),
  passed boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists replay_quiz_attempts_idx on replay_quiz_attempts (user_id, recording_id, created_at desc);
alter table replay_quizzes enable row level security;
alter table replay_quiz_attempts enable row level security;
revoke all on replay_quizzes, replay_quiz_attempts from anon, authenticated;
grant select on replay_quiz_attempts to authenticated;
drop policy if exists "tentatives de quiz : les miennes" on replay_quiz_attempts;
create policy "tentatives de quiz : les miennes" on replay_quiz_attempts for select using (user_id = auth.uid());

-- ------------------------------------------------------------------ accès hérité du live
create or replace function _replay_is_admin(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = p_user and role::text = 'admin')
$$;
revoke all on function _replay_is_admin(uuid) from public, anon, authenticated;

create or replace function _replay_access(p_recording uuid, p_user uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare r live_recordings%rowtype; l lives%rowtype; acc text; m replay_meta%rowtype;
begin
  select * into r from live_recordings where id = p_recording;
  if not found then return 'introuvable'; end if;
  select * into l from lives where id = r.live_id;
  if not found then return 'introuvable'; end if;
  acc := _live_access(r.live_id, p_user);
  if acc <> 'ok' then return acc; end if;
  if r.status <> 'pret' then return 'indisponible'; end if;
  select * into m from replay_meta where recording_id = p_recording;
  if found and not m.published and l.host_id <> p_user and not _replay_is_admin(p_user) then return 'masque'; end if;
  return 'ok';
end $$;
revoke all on function _replay_access(uuid, uuid) from public, anon, authenticated;

-- Visibilité dans une liste : 'ok', 'connexion' (visiteur), 'billet_requis' (live public à billet), ou null (non listé : privé, masqué, banni…).
create or replace function _replay_listing_access(p_recording uuid, p_user uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare r live_recordings%rowtype; l lives%rowtype; acc text; m replay_meta%rowtype;
begin
  select * into r from live_recordings where id = p_recording;
  if not found or r.status <> 'pret' then return null; end if;
  select * into l from lives where id = r.live_id;
  if not found or l.status = 'cancelled' then return null; end if;
  select * into m from replay_meta where recording_id = p_recording;
  if found and not m.published and l.host_id is distinct from p_user and not _replay_is_admin(p_user) then return null; end if;
  if p_user is null then return case when l.visibilite = 'public' then 'connexion' else null end; end if;
  if exists (select 1 from user_blocks b where (b.blocker_id = p_user and b.blocked_id = l.host_id) or (b.blocker_id = l.host_id and b.blocked_id = p_user)) then return null; end if;
  acc := _live_access(r.live_id, p_user);
  if acc = 'ok' then return 'ok'; end if;
  if acc = 'billet_requis' and l.visibilite = 'public' then return 'billet_requis'; end if;
  return null;
end $$;
revoke all on function _replay_listing_access(uuid, uuid) from public, anon, authenticated;

create or replace function _replay_msg(p_reason text) returns text
language sql immutable as $$
  select case p_reason
    when 'ok' then ''
    when 'connexion' then 'Connexion requise pour regarder ce replay.'
    when 'billet_requis' then 'Ce replay est réservé aux personnes inscrites à l''événement lié (billet).'
    when 'invitation_requise' then 'Ce replay est privé : l''accès se fait sur invitation de l''hôte.'
    when 'banni' then 'Vous ne pouvez pas accéder à ce replay.'
    when 'suspendu' then 'Votre compte est suspendu.'
    when 'indisponible' then 'Ce replay n''est pas encore disponible.'
    when 'masque' then 'Ce replay n''est pas publié.'
    when 'evenement_annule' then 'L''événement lié à ce replay est annulé.'
    else 'Accès refusé.' end
$$;

create or replace function _replay_meta(p_recording uuid) returns replay_meta
language sql stable security definer set search_path = public as $$
  select coalesce((select m from replay_meta m where m.recording_id = p_recording), row(p_recording, true, false, true, true, true, now())::replay_meta)
$$;
revoke all on function _replay_meta(uuid) from public, anon, authenticated;

-- Réglages de l'hôte pour son replay.
create or replace function replay_meta_set(p_recording uuid, p_published boolean default null, p_certificate boolean default null, p_share boolean default null,
                                           p_comments boolean default null, p_clips boolean default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r live_recordings%rowtype; l lives%rowtype; m replay_meta;
begin
  perform _assert_active();
  select * into r from live_recordings where id = p_recording;
  if not found then raise exception 'Replay introuvable'; end if;
  select * into l from lives where id = r.live_id;
  if l.host_id <> auth.uid() then raise exception 'Action non autorisée'; end if;
  insert into replay_meta (recording_id) values (p_recording) on conflict do nothing;
  update replay_meta set published = coalesce(p_published, published), certificate_enabled = coalesce(p_certificate, certificate_enabled),
    share_enabled = coalesce(p_share, share_enabled), comments_enabled = coalesce(p_comments, comments_enabled), clips_allowed = coalesce(p_clips, clips_allowed), updated_at = now()
   where recording_id = p_recording;
  m := _replay_meta(p_recording);
  return jsonb_build_object('published', m.published, 'certificate_enabled', m.certificate_enabled, 'share_enabled', m.share_enabled, 'comments_enabled', m.comments_enabled, 'clips_allowed', m.clips_allowed);
end $$;
revoke all on function replay_meta_set(uuid, boolean, boolean, boolean, boolean, boolean) from public, anon;
grant execute on function replay_meta_set(uuid, boolean, boolean, boolean, boolean, boolean) to authenticated;

-- Seuil de complétion : réglage d'administration (la valeur par défaut est 98 %).
create or replace function replay_settings_set(p_threshold numeric) returns numeric
language plpgsql security definer set search_path = public as $$
begin
  perform _assert_active();
  if not _replay_is_admin(auth.uid()) then raise exception 'Action non autorisée'; end if;
  if p_threshold is null or p_threshold < 0.5 or p_threshold > 1 then raise exception 'Seuil invalide (entre 50 %% et 100 %%)'; end if;
  update replay_settings set completion_threshold = p_threshold, updated_at = now() where id;
  return p_threshold;
end $$;
revoke all on function replay_settings_set(numeric) from public, anon;
grant execute on function replay_settings_set(numeric) to authenticated;

-- ------------------------------------------------------------------ lecture : URL signée courte
-- Renvoie le chemin du fichier et crée un ticket de 15 minutes (la politique de stockage n'ouvre l'objet qu'avec ce ticket). Jamais de chemin si l'accès est refusé.
create or replace function replay_play_url(p_recording uuid, p_kind text default 'complete') returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); r live_recordings%rowtype; acc text; path text; v_ttl constant integer := 900; k text := coalesce(nullif(btrim(p_kind), ''), 'complete');
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into r from live_recordings where id = p_recording;
  if k = 'complete' then path := r.storage_path;
  else select t->>'path' into path from jsonb_array_elements(r.tracks) t where t->>'kind' = k limit 1; end if;
  if path is null then raise exception 'Cette piste n''est pas disponible pour ce replay'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'live-replays' and name = path) then raise exception 'Le fichier du replay est introuvable sur le stockage'; end if;
  delete from replay_play_tickets where user_id = uid and expires_at <= now();
  insert into replay_play_tickets (user_id, recording_id, storage_path, expires_at) values (uid, p_recording, path, now() + make_interval(secs => v_ttl));
  return jsonb_build_object('bucket', 'live-replays', 'path', path, 'kind', k, 'expires_in', v_ttl, 'duration_sec', r.duration_sec);
end $$;
revoke all on function replay_play_url(uuid, text) from public, anon;
grant execute on function replay_play_url(uuid, text) to authenticated;

-- ------------------------------------------------------------------ progression fiable
create or replace function _replay_merge(p_iv jsonb, p_from numeric, p_to numeric) returns jsonb
language plpgsql immutable as $$
declare r record; res jsonb := '[]'::jsonb; cs numeric; ce numeric; started boolean := false;
begin
  for r in
    select (e->>0)::numeric as a, (e->>1)::numeric as b
      from jsonb_array_elements(coalesce(p_iv, '[]'::jsonb) || jsonb_build_array(jsonb_build_array(p_from, p_to))) e order by 1, 2
  loop
    if not started then cs := r.a; ce := r.b; started := true;
    elsif r.a <= ce then ce := greatest(ce, r.b);
    else res := res || jsonb_build_array(jsonb_build_array(cs, ce)); cs := r.a; ce := r.b; end if;
  end loop;
  if started then res := res || jsonb_build_array(jsonb_build_array(cs, ce)); end if;
  return res;
end $$;

create or replace function _replay_covered(p_iv jsonb) returns numeric
language sql immutable as $$
  select coalesce(sum((e->>1)::numeric - (e->>0)::numeric), 0) from jsonb_array_elements(coalesce(p_iv, '[]'::jsonb)) e
$$;

-- Ouverture d'une session de lecture (ou après un déplacement du curseur) : sans elle, aucun segment n'est crédité.
create or replace function replay_playback_start(p_recording uuid, p_position numeric default 0) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); r live_recordings%rowtype; s replay_settings%rowtype; pr replay_progress%rowtype; now_ timestamptz := clock_timestamp(); pos numeric; dur numeric; acc text;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into r from live_recordings where id = p_recording;
  select * into s from replay_settings where id;
  dur := r.duration_sec;
  pos := round(least(greatest(coalesce(p_position, 0), 0), dur), 2);
  insert into replay_progress (user_id, recording_id, session_active, session_at, last_to, position_sec, win_start, win_count)
    values (uid, p_recording, false, null, pos, pos, now_, 0) on conflict do nothing;
  select * into pr from replay_progress where user_id = uid and recording_id = p_recording for update;
  if pr.win_start is null or now_ - pr.win_start > interval '60 seconds' then pr.win_start := now_; pr.win_count := 0; end if;
  pr.win_count := pr.win_count + 1;
  if pr.win_count > s.burst_per_min or (pr.session_at is not null and extract(epoch from now_ - pr.session_at) < s.min_interval_sec) then
    update replay_progress set win_start = pr.win_start, win_count = pr.win_count, rejected_count = rejected_count + 1, updated_at = now_ where user_id = uid and recording_id = p_recording;
    return jsonb_build_object('ok', false, 'reason', 'rafale');
  end if;
  update replay_progress set session_active = true, session_at = now_, last_to = pos, position_sec = pos, win_start = pr.win_start, win_count = pr.win_count, updated_at = now_
   where user_id = uid and recording_id = p_recording;
  return jsonb_build_object('ok', true, 'position', pos, 'covered_sec', pr.covered_sec, 'duration_sec', dur,
    'coverage', case when dur > 0 then round(pr.covered_sec / dur, 4) else 0 end, 'completed', pr.completed_at is not null);
end $$;
revoke all on function replay_playback_start(uuid, numeric) from public, anon;
grant execute on function replay_playback_start(uuid, numeric) to authenticated;

-- Pause, fin, arrière-plan : la session de lecture se ferme (plus aucun crédit tant que l'application ne la rouvre pas).
create or replace function replay_playback_stop(p_recording uuid, p_position numeric default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); dur numeric;
begin
  perform _assert_active();
  select duration_sec into dur from live_recordings where id = p_recording;
  update replay_progress set session_active = false, updated_at = now(),
    position_sec = case when p_position is null or dur is null then position_sec else round(least(greatest(p_position, 0), dur), 2) end
   where user_id = uid and recording_id = p_recording;
  return found;
end $$;
revoke all on function replay_playback_stop(uuid, numeric) from public, anon;
grant execute on function replay_playback_stop(uuid, numeric) to authenticated;

create or replace function replay_progress_report(p_recording uuid, p_from numeric, p_to numeric, p_client_ts bigint) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); s replay_settings%rowtype; r live_recordings%rowtype; pr replay_progress%rowtype; now_ timestamptz := clock_timestamp();
  elapsed numeric; dur numeric; a numeric; b numeric; iv jsonb; cov numeric; reason text; ins integer := 0; expired boolean := false; acc text;
begin
  perform _assert_active();
  if p_from is null or p_to is null or p_client_ts is null then raise exception 'Paramètres invalides'; end if;
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into r from live_recordings where id = p_recording;
  select * into s from replay_settings where id;
  dur := r.duration_sec;
  select * into pr from replay_progress where user_id = uid and recording_id = p_recording for update;
  if not found or not pr.session_active or pr.session_at is null then
    return jsonb_build_object('accepted', false, 'reason', 'lecture_non_signalee');
  end if;
  if pr.win_start is null or now_ - pr.win_start > interval '60 seconds' then pr.win_start := now_; pr.win_count := 0; end if;
  pr.win_count := pr.win_count + 1;
  elapsed := extract(epoch from now_ - pr.session_at);
  if pr.win_count > s.burst_per_min then reason := 'rafale';
  elsif elapsed < s.min_interval_sec then reason := 'rafale';
  elsif p_client_ts <= coalesce(pr.last_client_ts, 0) then reason := 'rejeu';
  elsif abs(p_client_ts - (extract(epoch from now_) * 1000)::bigint) > 300000 then reason := 'horloge';
  elsif p_from < 0 or p_to <= p_from then reason := 'segment_invalide';
  elsif p_to - p_from > s.max_segment_sec then reason := 'segment_trop_long';
  elsif elapsed > s.idle_timeout_sec then reason := 'session_expiree'; expired := true;
  elsif abs(p_from - pr.last_to) > s.jump_tolerance_sec then reason := 'saut';
  elsif p_from >= dur or p_to > dur + 5 then reason := 'hors_duree';
  elsif p_to - p_from > elapsed * s.max_speed + 0.5 then reason := 'vitesse';
  elsif jsonb_array_length(pr.intervals) >= 500 then reason := 'trop_de_segments';
  end if;
  a := round(p_from, 2);
  b := round(least(p_to, dur), 2);
  if reason is null and pr.watched_sec + (b - a) > extract(epoch from now_ - pr.created_at) * s.max_speed + 30 then reason := 'vitesse_cumulee'; end if;
  if reason is not null then
    update replay_progress set win_start = pr.win_start, win_count = pr.win_count, rejected_count = rejected_count + 1, session_active = case when expired then false else session_active end, updated_at = now_
     where user_id = uid and recording_id = p_recording;
    return jsonb_build_object('accepted', false, 'reason', reason, 'covered_sec', pr.covered_sec, 'coverage', case when dur > 0 then round(pr.covered_sec / dur, 4) else 0 end);
  end if;
  iv := _replay_merge(pr.intervals, a, b);
  cov := _replay_covered(iv);
  update replay_progress set intervals = iv, covered_sec = cov, watched_sec = watched_sec + (b - a), real_sec = real_sec + least(elapsed, s.idle_timeout_sec),
    position_sec = b, last_to = b, session_at = now_, last_client_ts = p_client_ts, win_start = pr.win_start, win_count = pr.win_count, updated_at = now_
   where user_id = uid and recording_id = p_recording;
  if pr.completed_at is null and dur > 0 and cov >= s.completion_threshold * dur then
    insert into replay_completions (user_id, recording_id, live_id, coverage, watched_sec)
      values (uid, p_recording, r.live_id, least(round(cov / dur, 4), 1), pr.watched_sec + (b - a)) on conflict (user_id, recording_id) do nothing;
    get diagnostics ins = row_count;
    update replay_progress set completed_at = now_ where user_id = uid and recording_id = p_recording;
    if ins > 0 then perform _replay_award(uid, p_recording); end if;
  end if;
  return jsonb_build_object('accepted', true, 'covered_sec', cov, 'coverage', case when dur > 0 then round(cov / dur, 4) else 0 end, 'position', b,
    'completed', pr.completed_at is not null or cov >= s.completion_threshold * dur, 'newly_completed', ins > 0);
end $$;
revoke all on function replay_progress_report(uuid, numeric, numeric, bigint) from public, anon;
grant execute on function replay_progress_report(uuid, numeric, numeric, bigint) to authenticated;

-- ------------------------------------------------------------------ badge, certificat de suivi, quiz
-- Badge à la complétion ; certificat seulement si l'hôte l'a activé et si le quiz (s'il existe) est réussi. Idempotent : rejouable après un quiz réussi.
create or replace function _replay_award(p_user uuid, p_recording uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare r live_recordings%rowtype; l lives%rowtype; m replay_meta; holder text; c text;
begin
  select * into r from live_recordings where id = p_recording;
  select * into l from lives where id = r.live_id;
  if not exists (select 1 from replay_completions where user_id = p_user and recording_id = p_recording) then return; end if;
  insert into user_badges (user_id, code, label, ref_kind, ref_id) values (p_user, 'jai_suivi', 'J''ai suivi', 'replay', p_recording) on conflict do nothing;
  if found then
    insert into notifications (user_id, kind, title, body, data) values (p_user, 'live', 'Badge « J''ai suivi »', left('Vous avez suivi « ' || l.title || ' » jusqu''au bout.', 500), jsonb_build_object('recording', p_recording));
  end if;
  m := _replay_meta(p_recording);
  if m.certificate_enabled
     and (not exists (select 1 from replay_quizzes where recording_id = p_recording)
          or exists (select 1 from replay_quiz_attempts where recording_id = p_recording and user_id = p_user and passed))
     and not exists (select 1 from replay_certificates where user_id = p_user and recording_id = p_recording) then
    select name into holder from profiles where id = p_user;
    c := 'BE-SUIVI-' || upper(encode(gen_random_bytes(4), 'hex'));
    insert into replay_certificates (code, user_id, recording_id, holder_name, title, fingerprint)
      values (c, p_user, p_recording, coalesce(nullif(btrim(holder), ''), 'Membre'), l.title, encode(digest(c || '|' || p_user::text || '|' || p_recording::text || '|' || now()::text, 'sha256'), 'hex'))
      on conflict (user_id, recording_id) do nothing;
    insert into notifications (user_id, kind, title, body, data) values (p_user, 'live', 'Certificat de suivi', 'Votre certificat de suivi ' || c || ' est disponible.', jsonb_build_object('recording', p_recording, 'code', c));
  end if;
end $$;
revoke all on function _replay_award(uuid, uuid) from public, anon, authenticated;

create or replace function replay_certificate_verify(p_code text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('valide', not c.revoked, 'code', c.code, 'titre', c.title, 'delivre_le', to_char(c.issued_at, 'DD/MM/YYYY'),
           'titulaire', _short_name(c.holder_name), 'nature', 'Certificat de suivi d''un replay (non diplômant)')
         from replay_certificates c where c.code = upper(btrim(coalesce(p_code, '')))), jsonb_build_object('valide', false))
$$;
revoke all on function replay_certificate_verify(text) from public;
grant execute on function replay_certificate_verify(text) to anon, authenticated;

create or replace function replay_quiz_set(p_recording uuid, p_title text, p_pass_pct integer, p_questions jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
declare r live_recordings%rowtype; l lives%rowtype; q jsonb; n integer := 0;
begin
  perform _assert_active();
  select * into r from live_recordings where id = p_recording;
  if not found then raise exception 'Replay introuvable'; end if;
  select * into l from lives where id = r.live_id;
  if l.host_id <> auth.uid() then raise exception 'Action non autorisée'; end if;
  if p_questions is null or jsonb_typeof(p_questions) <> 'array' or jsonb_array_length(p_questions) not between 1 and 20 then raise exception 'Un quiz comporte 1 à 20 questions'; end if;
  for q in select * from jsonb_array_elements(p_questions) loop
    n := n + 1;
    if jsonb_typeof(q->'options') is distinct from 'array' or jsonb_array_length(q->'options') not between 2 and 6 or char_length(btrim(coalesce(q->>'q', ''))) not between 1 and 300
       or (q->>'correct') is null or (q->>'correct') !~ '^[0-9]+$' or (q->>'correct')::int >= jsonb_array_length(q->'options') then
      raise exception 'Question % invalide (énoncé, 2 à 6 options, bonne réponse)', n;
    end if;
  end loop;
  insert into replay_quizzes (recording_id, title, pass_pct, questions) values (p_recording, coalesce(nullif(btrim(p_title), ''), 'Quiz'), coalesce(p_pass_pct, 70), p_questions)
    on conflict (recording_id) do update set title = excluded.title, pass_pct = excluded.pass_pct, questions = excluded.questions, updated_at = now();
  return true;
end $$;
revoke all on function replay_quiz_set(uuid, text, integer, jsonb) from public, anon;
grant execute on function replay_quiz_set(uuid, text, integer, jsonb) to authenticated;

create or replace function replay_quiz_get(p_recording uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); z replay_quizzes%rowtype; acc text;
begin
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into z from replay_quizzes where recording_id = p_recording;
  if not found then return jsonb_build_object('defined', false); end if;
  return jsonb_build_object('defined', true, 'title', z.title, 'pass_pct', z.pass_pct,
    'questions', (select jsonb_agg(jsonb_build_object('q', e->>'q', 'options', e->'options') order by o) from jsonb_array_elements(z.questions) with ordinality as t(e, o)),
    'passed', exists (select 1 from replay_quiz_attempts where recording_id = p_recording and user_id = uid and passed),
    'best_pct', (select max(score_pct) from replay_quiz_attempts where recording_id = p_recording and user_id = uid));
end $$;
revoke all on function replay_quiz_get(uuid) from public, anon;
grant execute on function replay_quiz_get(uuid) to authenticated;

create or replace function replay_quiz_submit(p_recording uuid, p_answers jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); z replay_quizzes%rowtype; acc text; total integer; good integer := 0; i integer; pct integer; ok boolean;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into z from replay_quizzes where recording_id = p_recording;
  if not found then raise exception 'Ce replay n''a pas de quiz'; end if;
  if (select count(*) from replay_quiz_attempts where user_id = uid and recording_id = p_recording and created_at > now() - interval '1 day') >= 10 then raise exception 'Trop de tentatives aujourd''hui : réessayez demain'; end if;
  total := jsonb_array_length(z.questions);
  if p_answers is null or jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) <> total then raise exception 'Répondez à toutes les questions'; end if;
  for i in 0 .. total - 1 loop
    if (p_answers->>i) ~ '^[0-9]+$' and (p_answers->>i)::int = (z.questions->i->>'correct')::int then good := good + 1; end if;
  end loop;
  pct := round(100.0 * good / total);
  ok := pct >= z.pass_pct;
  insert into replay_quiz_attempts (recording_id, user_id, score_pct, passed) values (p_recording, uid, pct, ok);
  if ok then perform _replay_award(uid, p_recording); end if;
  return jsonb_build_object('score_pct', pct, 'passed', ok, 'pass_pct', z.pass_pct);
end $$;
revoke all on function replay_quiz_submit(uuid, jsonb) from public, anon;
grant execute on function replay_quiz_submit(uuid, jsonb) to authenticated;

create or replace function replay_progress_get(p_recording uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); r live_recordings%rowtype; s replay_settings%rowtype; pr replay_progress%rowtype; m replay_meta; acc text; cert text;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into r from live_recordings where id = p_recording;
  select * into s from replay_settings where id;
  select * into pr from replay_progress where user_id = uid and recording_id = p_recording;
  m := _replay_meta(p_recording);
  select code into cert from replay_certificates where user_id = uid and recording_id = p_recording and not revoked;
  return jsonb_build_object('duration_sec', r.duration_sec, 'threshold', s.completion_threshold,
    'covered_sec', coalesce(pr.covered_sec, 0), 'coverage', case when r.duration_sec > 0 then round(coalesce(pr.covered_sec, 0) / r.duration_sec, 4) else 0 end,
    'position_sec', coalesce(pr.position_sec, 0), 'watched_sec', coalesce(pr.watched_sec, 0), 'real_sec', coalesce(pr.real_sec, 0),
    'completed', exists (select 1 from replay_completions where user_id = uid and recording_id = p_recording), 'completed_at', pr.completed_at,
    'badge', exists (select 1 from user_badges where user_id = uid and code = 'jai_suivi' and ref_kind = 'replay' and ref_id = p_recording),
    'certificate_enabled', m.certificate_enabled, 'certificate', cert,
    'quiz_defined', exists (select 1 from replay_quizzes where recording_id = p_recording),
    'quiz_passed', exists (select 1 from replay_quiz_attempts where recording_id = p_recording and user_id = uid and passed));
end $$;
revoke all on function replay_progress_get(uuid) from public, anon;
grant execute on function replay_progress_get(uuid) to authenticated;
