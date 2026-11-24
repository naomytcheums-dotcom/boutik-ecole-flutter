-- Lot H10 / AI (2/3) : consentement audio/vidéo RÉVOCABLE et file de transcription « en attente de fournisseur » (CDC 11.3, 11.5).
-- Aucune transcription n'est produite par la base : une demande reste « en_attente_fournisseur » tant qu'aucun fournisseur « stt » n'est actif ; jamais un texte inventé.
--  1. ai_consents (un état courant par personne et type, rien d'accordé par défaut) + ai_consent_history (journal en ajout seul) ;
--  2. ai_consent_set() : accorder ou révoquer ; révoquer annule les transcriptions non terminées de la personne ;
--  3. ai_transcription_jobs : demande refusée sans consentement « transcription » + consentement du média (audio ou vidéo) ; lecture, annulation et suppression par le propriétaire ;
--  4. transcription_job_ack() : réservé au service (service_role) ; un résultat n'est accepté que d'un fournisseur actif et si le consentement est toujours accordé.
-- Le clonage vocal et l'entraînement sur des voix privées ne sont jamais activés : seul leur consentement explicite est enregistrable (aucune fonction ne l'utilise).
-- Additive et rejouable. Retour arrière :
--   drop function ai_consent_set(text, boolean), ai_consent_my(), transcription_request(text, text, text), transcription_my_list(), transcription_cancel(uuid), transcription_delete(uuid), transcription_job_ack(uuid, text, text, text, text);
--   drop table ai_transcription_jobs, ai_consent_history, ai_consents;

create table if not exists ai_consents (
  user_id uuid not null references profiles (id) on delete cascade,
  kind text not null check (kind in ('enregistrement_audio', 'enregistrement_video', 'transcription', 'clonage_vocal', 'entrainement_voix')),
  granted boolean not null default false,
  granted_at timestamptz,
  revoked_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind)
);
create table if not exists ai_consent_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  kind text not null,
  granted boolean not null,
  at timestamptz not null default now()
);
create index if not exists ai_consent_history_user on ai_consent_history (user_id, at desc);

create table if not exists ai_transcription_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles (id) on delete cascade,
  source_kind text not null check (source_kind in ('message_vocal', 'appel_audio', 'appel_video', 'live', 'conference', 'entretien', 'formation', 'evenement', 'autre')),
  source_ref text check (source_ref is null or char_length(source_ref) <= 300),
  language_hint text check (language_hint is null or _ai_lang_ok(language_hint)),
  status text not null default 'en_attente_fournisseur' check (status in ('en_attente_fournisseur', 'en_file', 'terminee', 'echouee', 'annulee')),
  provider_code text,
  result_text text check (result_text is null or char_length(result_text) <= 200000),
  status_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ai_transcription_jobs_owner on ai_transcription_jobs (owner_id, created_at desc);
create index if not exists ai_transcription_jobs_open on ai_transcription_jobs (status) where status in ('en_attente_fournisseur', 'en_file');

alter table ai_consents enable row level security;
alter table ai_consent_history enable row level security;
alter table ai_transcription_jobs enable row level security;
revoke all on ai_consents, ai_consent_history, ai_transcription_jobs from public, anon, authenticated;
grant select on ai_consents, ai_consent_history, ai_transcription_jobs to authenticated;
drop policy if exists "consentements IA : les miens" on ai_consents;
create policy "consentements IA : les miens" on ai_consents for select to authenticated using (user_id = auth.uid());
drop policy if exists "historique des consentements IA : le mien" on ai_consent_history;
create policy "historique des consentements IA : le mien" on ai_consent_history for select to authenticated using (user_id = auth.uid());
drop policy if exists "transcriptions : les miennes" on ai_transcription_jobs;
create policy "transcriptions : les miennes" on ai_transcription_jobs for select to authenticated using (owner_id = auth.uid());

-- Journal en ajout seul
create or replace function _ai_consent_history_immutable() returns trigger
language plpgsql as $$
begin raise exception 'Historique des consentements en ajout seul'; end $$;
drop trigger if exists trg_ai_consent_history_immutable on ai_consent_history;
create trigger trg_ai_consent_history_immutable before update or delete on ai_consent_history for each row execute function _ai_consent_history_immutable();

create or replace function _ai_consented(p_user uuid, p_kind text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select granted from ai_consents where user_id = p_user and kind = p_kind), false)
$$;
revoke all on function _ai_consented(uuid, text) from public, anon, authenticated;

create or replace function ai_consent_set(p_kind text, p_granted boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cancelled int := 0;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if p_kind is null or p_kind not in ('enregistrement_audio', 'enregistrement_video', 'transcription', 'clonage_vocal', 'entrainement_voix') then raise exception 'Type de consentement inconnu'; end if;
  if p_granted is null then raise exception 'Choix manquant'; end if;
  insert into ai_consents (user_id, kind, granted, granted_at, revoked_at, updated_at)
  values (v_uid, p_kind, p_granted, case when p_granted then now() end, case when not p_granted then now() end, now())
  on conflict (user_id, kind) do update set granted = excluded.granted,
    granted_at = case when excluded.granted then now() else ai_consents.granted_at end,
    revoked_at = case when excluded.granted then null else now() end, updated_at = now();
  insert into ai_consent_history (user_id, kind, granted) values (v_uid, p_kind, p_granted);
  if not p_granted and p_kind in ('transcription', 'enregistrement_audio', 'enregistrement_video') then
    update ai_transcription_jobs set status = 'annulee', status_note = 'Consentement révoqué', updated_at = now()
      where owner_id = v_uid and status in ('en_attente_fournisseur', 'en_file')
        and (p_kind = 'transcription' or (p_kind = 'enregistrement_video') = (source_kind in ('appel_video', 'live', 'conference', 'entretien', 'formation', 'evenement')));
    get diagnostics v_cancelled = row_count;
  end if;
  return jsonb_build_object('kind', p_kind, 'granted', p_granted, 'cancelled_jobs', v_cancelled);
end $$;

create or replace function ai_consent_my() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_object_agg(k, coalesce((select c.granted from ai_consents c where c.user_id = auth.uid() and c.kind = k), false))
    from unnest(array['enregistrement_audio', 'enregistrement_video', 'transcription', 'clonage_vocal', 'entrainement_voix']) k), '{}'::jsonb);
end $$;

create or replace function transcription_request(p_kind text, p_ref text default null, p_lang text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_media text; v_id uuid; v_status text;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if p_kind is null or p_kind not in ('message_vocal', 'appel_audio', 'appel_video', 'live', 'conference', 'entretien', 'formation', 'evenement', 'autre') then raise exception 'Source inconnue'; end if;
  if p_lang is not null and btrim(p_lang) <> '' and not _ai_lang_ok(lower(btrim(p_lang))) then raise exception 'Langue invalide'; end if;
  v_media := case when p_kind in ('appel_video', 'live', 'conference', 'entretien', 'formation', 'evenement') then 'enregistrement_video' else 'enregistrement_audio' end;
  if not _ai_consented(v_uid, 'transcription') then raise exception 'Consentement à la transcription requis'; end if;
  if not _ai_consented(v_uid, v_media) then raise exception 'Consentement à l''enregistrement requis'; end if;
  v_status := case when exists (select 1 from ai_providers where capability = 'stt' and status = 'actif') then 'en_file' else 'en_attente_fournisseur' end;
  insert into ai_transcription_jobs (owner_id, source_kind, source_ref, language_hint, status)
  values (v_uid, p_kind, left(nullif(btrim(coalesce(p_ref, '')), ''), 300), nullif(lower(btrim(coalesce(p_lang, ''))), ''), v_status) returning id into v_id;
  return jsonb_build_object('id', v_id, 'status', v_status);
end $$;

create or replace function transcription_my_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', j.id, 'source_kind', j.source_kind, 'source_ref', j.source_ref, 'status', j.status, 'result_text', j.result_text,
    'status_note', j.status_note, 'created_at', j.created_at) order by j.created_at desc) from ai_transcription_jobs j where j.owner_id = auth.uid()), '[]'::jsonb);
end $$;

create or replace function transcription_cancel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update ai_transcription_jobs set status = 'annulee', status_note = 'Annulée par la personne', updated_at = now()
    where id = p_id and owner_id = auth.uid() and status in ('en_attente_fournisseur', 'en_file');
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
end $$;

-- Contrôle de conservation : la personne supprime la transcription (et la demande) quand elle veut.
create or replace function transcription_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from ai_transcription_jobs where id = p_id and owner_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
end $$;

-- Résultat de l'adaptateur serveur (service_role uniquement).
create or replace function transcription_job_ack(p_id uuid, p_outcome text, p_provider text default null, p_text text default null, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare j ai_transcription_jobs;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  select * into j from ai_transcription_jobs where id = p_id for update;
  if j.id is null then raise exception 'Demande introuvable'; end if;
  if j.status not in ('en_attente_fournisseur', 'en_file') then raise exception 'Demande déjà traitée ou annulée'; end if;
  if p_outcome not in ('terminee', 'echouee') then raise exception 'Résultat inconnu'; end if;
  if p_outcome = 'terminee' then
    if not exists (select 1 from ai_providers where capability = 'stt' and code = p_provider and status = 'actif') then raise exception 'Aucun fournisseur de transcription actif'; end if;
    if p_text is null or char_length(btrim(p_text)) = 0 then raise exception 'Transcription vide refusée'; end if;
    if not _ai_consented(j.owner_id, 'transcription') then raise exception 'Consentement révoqué'; end if;
  end if;
  update ai_transcription_jobs set status = p_outcome, provider_code = p_provider, result_text = case when p_outcome = 'terminee' then p_text end,
    status_note = left(p_note, 500), updated_at = now() where id = j.id;
end $$;

revoke all on function ai_consent_set(text, boolean), ai_consent_my(), transcription_request(text, text, text), transcription_my_list(), transcription_cancel(uuid), transcription_delete(uuid) from public, anon;
grant execute on function ai_consent_set(text, boolean), ai_consent_my(), transcription_request(text, text, text), transcription_my_list(), transcription_cancel(uuid), transcription_delete(uuid) to authenticated;
revoke all on function transcription_job_ack(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function transcription_job_ack(uuid, text, text, text, text) to service_role;
