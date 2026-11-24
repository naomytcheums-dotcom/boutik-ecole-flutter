-- H10 SOCIAL, étape 4 : enregistrements de live (Live Replay Studio, socle).
--  * live_recording_config : interrupteur unique « enregistrement configuré » (faux par défaut : aucun enregistreur LiveKit/egress n'est branché). Modifié par l'administration ou le serveur seulement ;
--  * live_recordings : un enregistrement demandé par l'hôte d'un live, statut non_disponible | en_attente | pret ;
--    « pret » n'est posé que par le serveur (service_role : live_recording_mark_ready) quand l'enregistreur a réellement livré le fichier ET que tous les intervenants ont consenti ;
--  * live_recording_consents : consentement de chaque intervenant (co-diffuseur approuvé) ; un refus empêche l'enregistrement ;
--  * live_replay_get(live) : état honnête du replay pour une personne ayant accès au live. Aucun replay simulé.
-- Retour arrière : drop function live_replay_get(uuid), live_recording_request(uuid), live_recording_consent(uuid, boolean), live_recording_mark_ready(uuid, text, integer), live_recording_enabled() ;
--   drop table live_recording_consents, live_recordings, live_recording_config.

create table if not exists live_recording_config (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into live_recording_config (id) values (true) on conflict do nothing;
alter table live_recording_config enable row level security;
revoke all on live_recording_config from anon, authenticated;

create table if not exists live_recordings (
  id uuid primary key default gen_random_uuid(),
  live_id uuid not null references lives(id) on delete cascade,
  requested_by uuid not null references profiles(id) on delete cascade,
  status text not null default 'non_disponible' check (status in ('non_disponible', 'en_attente', 'pret')),
  note text not null default '' check (char_length(note) <= 300),
  storage_path text check (storage_path is null or char_length(storage_path) between 5 and 300),
  duration_sec integer check (duration_sec is null or duration_sec > 0),
  created_at timestamptz not null default now(),
  ready_at timestamptz,
  check (status <> 'pret' or (storage_path is not null and ready_at is not null))
);
create unique index if not exists live_recordings_un_par_live on live_recordings (live_id);

create table if not exists live_recording_consents (
  recording_id uuid not null references live_recordings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'requested' check (status in ('requested', 'accepted', 'declined')),
  decided_at timestamptz,
  primary key (recording_id, user_id)
);
alter table live_recordings enable row level security;
alter table live_recording_consents enable row level security;
revoke all on live_recordings, live_recording_consents from anon, authenticated;
grant select on live_recordings, live_recording_consents to authenticated;
drop policy if exists "enregistrements : l'hôte ou l'administration" on live_recordings;
create policy "enregistrements : l'hôte ou l'administration" on live_recordings for select
  using (requested_by = auth.uid() or exists (select 1 from profiles where id = auth.uid() and role::text = 'admin'));
drop policy if exists "consentements d'enregistrement : le mien ou l'hôte" on live_recording_consents;
create policy "consentements d'enregistrement : le mien ou l'hôte" on live_recording_consents for select
  using (user_id = auth.uid() or exists (select 1 from live_recordings r where r.id = recording_id and r.requested_by = auth.uid()));

create or replace function live_recording_enabled() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select enabled from live_recording_config where id), false)
$$;
revoke all on function live_recording_enabled() from public, anon;
grant execute on function live_recording_enabled() to authenticated, service_role;

-- Demande de l'hôte. Sans enregistreur configuré, l'enregistrement reste « non_disponible » (aucune promesse). Les co-diffuseurs approuvés doivent consentir.
create or replace function live_recording_request(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; rid uuid; en boolean := live_recording_enabled(); c record;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() then raise exception 'Action non autorisée'; end if;
  if l.status = 'ended' then raise exception 'Ce live est terminé : il n''a pas pu être enregistré'; end if;
  if exists (select 1 from live_recordings where live_id = p_live) then
    return (select status from live_recordings where live_id = p_live);
  end if;
  insert into live_recordings (live_id, requested_by, status, note)
    values (p_live, auth.uid(), case when en then 'en_attente' else 'non_disponible' end, case when en then '' else 'Enregistrement non configuré sur ce serveur' end) returning id into rid;
  if en then
    for c in select user_id from live_cohosts where live_id = p_live and status = 'approved' loop
      insert into live_recording_consents (recording_id, user_id) values (rid, c.user_id) on conflict do nothing;
      perform notify_user(c.user_id, 'live', 'Consentement à l''enregistrement', _live_author(l.host_id) || ' souhaite enregistrer ce live : acceptez-vous d''y figurer ?', jsonb_build_object('live', p_live, 'recording', rid));
    end loop;
  end if;
  return case when en then 'en_attente' else 'non_disponible' end;
end $$;
revoke all on function live_recording_request(uuid) from public, anon;
grant execute on function live_recording_request(uuid) to authenticated;

create or replace function live_recording_consent(p_live uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare r live_recordings%rowtype;
begin
  perform _assert_active();
  select * into r from live_recordings where live_id = p_live;
  if not found or not exists (select 1 from live_recording_consents where recording_id = r.id and user_id = auth.uid()) then raise exception 'Demande de consentement introuvable'; end if;
  if r.status = 'pret' then raise exception 'L''enregistrement est déjà terminé'; end if;
  update live_recording_consents set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where recording_id = r.id and user_id = auth.uid();
  if not p_accept then
    update live_recordings set status = 'non_disponible', note = 'Un intervenant a refusé l''enregistrement' where id = r.id;
  end if;
  return case when p_accept then 'accepted' else 'declined' end;
end $$;
revoke all on function live_recording_consent(uuid, boolean) from public, anon;
grant execute on function live_recording_consent(uuid, boolean) to authenticated;

-- Réservée au serveur (retour de l'enregistreur) : refuse si non configuré ou si un intervenant n'a pas consenti.
create or replace function live_recording_mark_ready(p_recording uuid, p_path text, p_duration integer) returns text
language plpgsql security definer set search_path = public as $$
declare r live_recordings%rowtype;
begin
  select * into r from live_recordings where id = p_recording for update;
  if not found then raise exception 'Enregistrement introuvable'; end if;
  if not live_recording_enabled() then raise exception 'Enregistrement non configuré'; end if;
  if exists (select 1 from live_recording_consents where recording_id = r.id and status <> 'accepted') then raise exception 'Consentement des intervenants manquant'; end if;
  if r.status <> 'en_attente' then raise exception 'Enregistrement non attendu'; end if;
  update live_recordings set status = 'pret', storage_path = p_path, duration_sec = p_duration, ready_at = now(), note = '' where id = r.id;
  return 'pret';
end $$;
revoke all on function live_recording_mark_ready(uuid, text, integer) from public, anon, authenticated;
grant execute on function live_recording_mark_ready(uuid, text, integer) to service_role;

create or replace function live_replay_get(p_live uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r live_recordings%rowtype; acc text := _live_access(p_live, auth.uid());
begin
  if acc <> 'ok' then return jsonb_build_object('status', 'refuse', 'reason', acc); end if;
  select * into r from live_recordings where live_id = p_live;
  if not found or r.status = 'non_disponible' then
    return jsonb_build_object('status', 'non_disponible', 'configured', live_recording_enabled(),
      'message', case when live_recording_enabled() then coalesce(nullif(r.note, ''), 'Aucun enregistrement pour ce live.') else 'Replay non disponible : enregistrement non configuré.' end);
  end if;
  if r.status = 'en_attente' then return jsonb_build_object('status', 'en_attente', 'configured', true, 'message', 'Enregistrement en cours de traitement.'); end if;
  return jsonb_build_object('status', 'pret', 'configured', true, 'path', r.storage_path, 'duration_sec', r.duration_sec, 'ready_at', r.ready_at);
end $$;
revoke all on function live_replay_get(uuid) from public, anon;
grant execute on function live_replay_get(uuid) to authenticated;
