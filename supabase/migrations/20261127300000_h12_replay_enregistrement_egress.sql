-- H12 LIVE-REPLAY, étape 1 : enregistrement LiveKit (Room Composite Egress) et accès signé au replay.
--  * live_recordings : suivi de l'egress (egress_id, egress_status, erreur) et pistes déclarées (tracks : complete | presenter | screen | dual | audio) ;
--  * bucket privé « live-replays » (aucune lecture directe : seul un ticket court, créé par replay_play_url après contrôle d'accès, ouvre une URL signée) ;
--  * fonctions réservées au serveur (service_role), appelées par les Edge Functions « live-record » et « live-egress-webhook » :
--      live_recording_start_check / live_recording_stop_check : le serveur CONFIRME (live en cours, hôte ou co-hôte, enregistrement demandé par l'hôte,
--        enregistreur configuré, consentement de chaque co-hôte approuvé) avant tout démarrage ; jamais d'enregistrement simulé ;
--      live_recording_egress_claim / _started / _stopping / _failed, live_recording_egress_event (webhook : complete -> live_recording_mark_ready existant) ;
--      live_recording_declare_track (pistes supplémentaires fournies plus tard par l'enregistreur) ;
--  * live_replay_host_state(live), my_replays() : état pour l'hôte (not_configured, not_requested, declined, awaiting_consent, waiting, recording, processing, ready, failed).
-- Strictement additif. Retour arrière : drop function live_recording_start_check(uuid, uuid), live_recording_stop_check(uuid, uuid), live_recording_egress_claim(uuid),
--   live_recording_egress_started(uuid, text), live_recording_egress_stopping(uuid), live_recording_egress_failed(uuid, text), live_recording_egress_event(text, text, text, integer, text),
--   live_recording_declare_track(uuid, text, text), live_replay_host_state(uuid), my_replays(), replay_storage_read_ok(text) ; drop table replay_play_tickets ;
--   alter table live_recordings drop column egress_id, drop column egress_status, drop column egress_error, drop column egress_started_at, drop column tracks.

alter table live_recordings add column if not exists egress_id text;
alter table live_recordings add column if not exists egress_status text;
alter table live_recordings add column if not exists egress_error text;
alter table live_recordings add column if not exists egress_started_at timestamptz;
alter table live_recordings add column if not exists tracks jsonb not null default '[]'::jsonb;
do $$ begin
  alter table live_recordings add constraint live_recordings_egress_status_check check (egress_status is null or egress_status in ('starting', 'active', 'stopping', 'complete', 'failed'));
exception when duplicate_object then null; end $$;
create unique index if not exists live_recordings_egress_un on live_recordings (egress_id) where egress_id is not null;

-- ------------------------------------------------------------------ stockage privé et tickets de lecture
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('live-replays', 'live-replays', false, 5368709120, array['video/mp4', 'audio/mp4', 'audio/ogg', 'video/webm', 'video/ogg'])
on conflict (id) do nothing;

create table if not exists replay_play_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  recording_id uuid not null references live_recordings(id) on delete cascade,
  storage_path text not null,
  expires_at timestamptz not null
);
create index if not exists replay_play_tickets_idx on replay_play_tickets (user_id, storage_path, expires_at);
alter table replay_play_tickets enable row level security;
revoke all on replay_play_tickets from anon, authenticated;

create or replace function replay_storage_read_ok(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (select 1 from replay_play_tickets t where t.user_id = auth.uid() and t.storage_path = p_name and t.expires_at > now())
$$;
revoke all on function replay_storage_read_ok(text) from public, anon;
grant execute on function replay_storage_read_ok(text) to authenticated;

drop policy if exists "replays : lecture avec ticket valable" on storage.objects;
create policy "replays : lecture avec ticket valable" on storage.objects for select to authenticated
  using (bucket_id = 'live-replays' and replay_storage_read_ok(name));

-- ------------------------------------------------------------------ contrôles serveur avant egress
create or replace function _live_recording_actor(p_live uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from lives l where l.id = p_live and l.host_id = p_user)
      or exists (select 1 from live_cohosts c where c.live_id = p_live and c.user_id = p_user and c.status = 'approved')
$$;
revoke all on function _live_recording_actor(uuid, uuid) from public, anon, authenticated;

create or replace function live_recording_start_check(p_live uuid, p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l lives%rowtype; r live_recordings%rowtype; u profiles%rowtype;
begin
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then return jsonb_build_object('ok', false, 'reason', 'introuvable', 'message', 'Live introuvable.'); end if;
  select * into u from profiles where id = p_user;
  if not found or u.suspended or not _live_recording_actor(p_live, p_user) then
    return jsonb_build_object('ok', false, 'reason', 'non_autorise', 'message', 'Seuls l''hôte et les co-hôtes approuvés peuvent piloter l''enregistrement.');
  end if;
  if l.status <> 'live' then return jsonb_build_object('ok', false, 'reason', 'pas_en_direct', 'message', 'Le live doit être en cours pour démarrer l''enregistrement.'); end if;
  if not live_recording_enabled() then return jsonb_build_object('ok', false, 'reason', 'non_configure', 'message', 'Enregistrement non configuré sur ce serveur.'); end if;
  select * into r from live_recordings where live_id = p_live;
  if not found then return jsonb_build_object('ok', false, 'reason', 'enregistrement_non_demande', 'message', 'L''hôte n''a pas activé l''enregistrement de ce live.'); end if;
  if r.status = 'pret' then return jsonb_build_object('ok', false, 'reason', 'deja_termine', 'message', 'L''enregistrement est déjà terminé.'); end if;
  if r.status = 'non_disponible' then return jsonb_build_object('ok', false, 'reason', 'enregistrement_refuse', 'message', coalesce(nullif(r.note, ''), 'Enregistrement non disponible.')); end if;
  if exists (select 1 from live_recording_consents where recording_id = r.id and status <> 'accepted')
     or exists (select 1 from live_cohosts c where c.live_id = p_live and c.status = 'approved'
                and not exists (select 1 from live_recording_consents k where k.recording_id = r.id and k.user_id = c.user_id and k.status = 'accepted')) then
    return jsonb_build_object('ok', false, 'reason', 'consentement_manquant', 'message', 'Tous les intervenants doivent consentir à l''enregistrement.');
  end if;
  if r.egress_status in ('starting', 'active') then
    return jsonb_build_object('ok', false, 'reason', 'deja_demarre', 'message', 'L''enregistrement est déjà en cours.', 'egress_id', r.egress_id);
  end if;
  return jsonb_build_object('ok', true, 'recording_id', r.id, 'live_id', p_live, 'room_name', l.room_name);
end $$;
revoke all on function live_recording_start_check(uuid, uuid) from public, anon, authenticated;
grant execute on function live_recording_start_check(uuid, uuid) to service_role;

create or replace function live_recording_stop_check(p_live uuid, p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r live_recordings%rowtype;
begin
  if not _live_recording_actor(p_live, p_user) then
    return jsonb_build_object('ok', false, 'reason', 'non_autorise', 'message', 'Seuls l''hôte et les co-hôtes approuvés peuvent piloter l''enregistrement.');
  end if;
  select * into r from live_recordings where live_id = p_live;
  if not found or r.egress_id is null or r.egress_status not in ('starting', 'active') then
    return jsonb_build_object('ok', false, 'reason', 'aucun_enregistrement_en_cours', 'message', 'Aucun enregistrement en cours pour ce live.');
  end if;
  return jsonb_build_object('ok', true, 'recording_id', r.id, 'egress_id', r.egress_id);
end $$;
revoke all on function live_recording_stop_check(uuid, uuid) from public, anon, authenticated;
grant execute on function live_recording_stop_check(uuid, uuid) to service_role;

-- Verrou de démarrage : un seul egress à la fois par enregistrement.
create or replace function live_recording_egress_claim(p_recording uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update live_recordings set egress_status = 'starting', egress_error = null, egress_id = null, egress_started_at = now()
   where id = p_recording and status = 'en_attente' and (egress_status is null or egress_status in ('failed', 'complete') or (egress_status = 'starting' and egress_started_at < now() - interval '2 minutes'));
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke all on function live_recording_egress_claim(uuid) from public, anon, authenticated;
grant execute on function live_recording_egress_claim(uuid) to service_role;

create or replace function live_recording_egress_started(p_recording uuid, p_egress text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_egress is null or char_length(btrim(p_egress)) < 3 or char_length(p_egress) > 200 then raise exception 'Identifiant d''egress invalide'; end if;
  update live_recordings set egress_id = p_egress, egress_status = 'active' where id = p_recording and egress_status = 'starting';
  if not found then raise exception 'Démarrage non attendu'; end if;
end $$;
revoke all on function live_recording_egress_started(uuid, text) from public, anon, authenticated;
grant execute on function live_recording_egress_started(uuid, text) to service_role;

create or replace function live_recording_egress_stopping(p_recording uuid) returns void
language sql security definer set search_path = public as $$
  update live_recordings set egress_status = 'stopping' where id = p_recording and egress_status in ('starting', 'active')
$$;
revoke all on function live_recording_egress_stopping(uuid) from public, anon, authenticated;
grant execute on function live_recording_egress_stopping(uuid) to service_role;

create or replace function live_recording_egress_failed(p_recording uuid, p_error text) returns void
language sql security definer set search_path = public as $$
  update live_recordings set egress_status = 'failed', egress_error = left(coalesce(p_error, 'Échec de l''enregistreur'), 300), note = 'L''enregistrement a échoué'
   where id = p_recording and status = 'en_attente'
$$;
revoke all on function live_recording_egress_failed(uuid, text) from public, anon, authenticated;
grant execute on function live_recording_egress_failed(uuid, text) to service_role;

-- Retour du webhook LiveKit (signature déjà vérifiée par la fonction). complete : fichier livré -> « prêt » (consentements revérifiés par live_recording_mark_ready) ; failed : état « échec ».
create or replace function live_recording_egress_event(p_egress text, p_status text, p_path text, p_duration integer, p_error text) returns text
language plpgsql security definer set search_path = public as $$
declare r live_recordings%rowtype;
begin
  select * into r from live_recordings where egress_id = p_egress for update;
  if not found then return 'inconnu'; end if;
  if r.status = 'pret' then return 'pret'; end if;
  if p_status = 'active' then
    update live_recordings set egress_status = 'active' where id = r.id and egress_status in ('starting', 'active');
    return 'active';
  elsif p_status = 'complete' then
    if p_path is null or char_length(p_path) < 5 or p_duration is null or p_duration <= 0 then
      update live_recordings set egress_status = 'failed', egress_error = 'Fichier ou durée absents du retour de l''enregistreur', note = 'L''enregistrement a échoué' where id = r.id;
      return 'failed';
    end if;
    begin
      perform live_recording_mark_ready(r.id, p_path, p_duration);
    exception when others then
      update live_recordings set egress_status = 'failed', egress_error = left(sqlerrm, 300), note = 'L''enregistrement a échoué' where id = r.id;
      return 'failed';
    end;
    update live_recordings set egress_status = 'complete', egress_error = null,
      tracks = case when tracks = '[]'::jsonb then jsonb_build_array(jsonb_build_object('kind', 'complete', 'path', p_path)) else tracks end
     where id = r.id;
    return 'pret';
  elsif p_status = 'failed' then
    update live_recordings set egress_status = 'failed', egress_error = left(coalesce(p_error, 'Échec de l''enregistreur'), 300), note = 'L''enregistrement a échoué' where id = r.id;
    return 'failed';
  end if;
  return 'ignore';
end $$;
revoke all on function live_recording_egress_event(text, text, text, integer, text) from public, anon, authenticated;
grant execute on function live_recording_egress_event(text, text, text, integer, text) to service_role;

-- Pistes déclarées : sans piste supplémentaire, seul le mode « complete » (vidéo intégrale) est proposé au lecteur.
create or replace function live_recording_declare_track(p_recording uuid, p_kind text, p_path text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_kind not in ('presenter', 'screen', 'dual', 'audio') then raise exception 'Type de piste inconnu'; end if;
  if p_path is null or char_length(p_path) not between 5 and 300 then raise exception 'Chemin de piste invalide'; end if;
  update live_recordings
     set tracks = (select coalesce(jsonb_agg(t), '[]'::jsonb) from jsonb_array_elements(tracks) t where t->>'kind' <> p_kind) || jsonb_build_array(jsonb_build_object('kind', p_kind, 'path', p_path))
   where id = p_recording and status = 'pret';
  if not found then raise exception 'Enregistrement prêt introuvable'; end if;
end $$;
revoke all on function live_recording_declare_track(uuid, text, text) from public, anon, authenticated;
grant execute on function live_recording_declare_track(uuid, text, text) to service_role;

-- ------------------------------------------------------------------ état pour l'hôte
create or replace function _live_replay_state(p_live uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l lives%rowtype; r live_recordings%rowtype; en boolean := live_recording_enabled(); st text; msg text; consents jsonb;
begin
  select * into l from lives where id = p_live;
  select * into r from live_recordings where live_id = p_live;
  if not found then
    st := case when not en then 'not_configured' else 'not_requested' end;
    msg := case when not en then 'Enregistrement non configuré sur ce serveur : aucun replay ne sera créé.' else 'Enregistrement non demandé pour ce live.' end;
    return jsonb_build_object('state', st, 'message', msg, 'configured', en, 'live_status', l.status, 'consents', '[]'::jsonb);
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('user_id', k.user_id, 'name', _live_author(k.user_id), 'status', k.status) order by k.user_id), '[]'::jsonb) into consents
    from live_recording_consents k where k.recording_id = r.id;
  if r.status = 'pret' then st := 'ready'; msg := 'Replay prêt.';
  elsif r.status = 'non_disponible' then
    st := case when not en then 'not_configured' else 'declined' end;
    msg := case when not en then 'Enregistrement non configuré sur ce serveur.' else coalesce(nullif(r.note, ''), 'Enregistrement non disponible.') end;
  elsif r.egress_status = 'failed' then st := 'failed'; msg := coalesce(nullif(r.egress_error, ''), 'L''enregistrement a échoué.');
  elsif exists (select 1 from live_recording_consents k where k.recording_id = r.id and k.status = 'requested') then st := 'awaiting_consent'; msg := 'En attente du consentement des intervenants.';
  elsif r.egress_status in ('starting', 'active') and l.status = 'live' then st := 'recording'; msg := 'Enregistrement en cours.';
  elsif r.egress_status in ('starting', 'active', 'stopping') then st := 'processing'; msg := 'Traitement du fichier en cours.';
  else st := 'waiting'; msg := 'Prêt à démarrer l''enregistrement.'; end if;
  return jsonb_build_object('state', st, 'message', msg, 'configured', en, 'live_status', l.status, 'recording_id', r.id, 'duration_sec', r.duration_sec,
    'egress_status', r.egress_status, 'consents', consents, 'tracks', r.tracks);
end $$;
revoke all on function _live_replay_state(uuid) from public, anon, authenticated;

create or replace function live_replay_host_state(p_live uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l lives%rowtype;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and not exists (select 1 from profiles where id = auth.uid() and role::text = 'admin') then raise exception 'Action non autorisée'; end if;
  return _live_replay_state(p_live);
end $$;
revoke all on function live_replay_host_state(uuid) from public, anon;
grant execute on function live_replay_host_state(uuid) to authenticated;

create or replace function my_replays() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _assert_active();
  return coalesce((select jsonb_agg(x order by (x->>'created_at') desc) from (
    select jsonb_build_object('live_id', l.id, 'title', l.title, 'status', l.status, 'created_at', l.created_at, 'started_at', l.started_at, 'ended_at', l.ended_at, 'replay', _live_replay_state(l.id)) x
      from lives l where l.host_id = auth.uid() and l.status in ('live', 'ended') order by l.created_at desc limit 50) s), '[]'::jsonb);
end $$;
revoke all on function my_replays() from public, anon;
grant execute on function my_replays() to authenticated;
