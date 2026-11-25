-- H12 ATELIER EN DIRECT : préparation d'un live, Action Unique, fiches enrichies, statistiques d'audience de l'hôte.
--  * live_settings : réglages par live (catégorie, filière, secteur, hashtags, entreprises taguées (3 au plus, vérifiées), Action Unique et sa cible,
--    commentaires, participation, fréquence, durée, rappels, qualité vidéo, clips, audio seul, enregistrement du replay, message de notification) ;
--  * AUCUNE règle financière : le prix d'un live reste celui de l'événement lié (events.price, via live_configure) ; l'Action Unique ouvre les parcours existants ;
--  * _live_action_check : l'action et sa cible doivent appartenir à l'hôte du live (annonce, événement, opportunité, mission, projet) ; une action qui exige une cible la refuse absente ;
--  * live_set_settings (hôte, ou co-hôte approuvé pour les champs descriptifs), live_settings_get (lecture publique de ce que le live rend public), lives_atelier_extras (cartes de l'Atelier),
--    live_update (hôte : titre, description, date d'un live programmé), live_cancel (hôte : annule un live programmé et prévient les inscrits), live_host_stats (audience réelle de l'hôte) ;
--  * garde-fous : commentaires désactivés, participation désactivée, rappels désactivés ; send_live_reminders utilise le message de notification choisi par l'hôte.
-- Strictement additif. Retour arrière : drop trigger trg_live_settings_chat on live_messages, trg_live_settings_cohost on live_cohosts, trg_live_settings_reminders on live_reminders ;
--   drop function live_set_settings(uuid, jsonb), live_settings_get(uuid), lives_atelier_extras(uuid[]), live_update(uuid, text, text, timestamptz), live_cancel(uuid, text), live_host_stats(uuid),
--   live_orgs_search(text, integer), live_action_targets(text),
--   _live_action_check(uuid, text, text, uuid), _live_can_edit(uuid, uuid, boolean), _live_can_edit_me(uuid), _live_registered(uuid), _live_atelier_card(lives), _live_settings_guard_chat(), _live_settings_guard_cohost(),
--   _live_settings_guard_reminders() ; drop table live_settings ; recréer send_live_reminders depuis 20261115200200.

create table if not exists live_settings (
  live_id uuid primary key references lives(id) on delete cascade,
  category text check (category is null or char_length(category) <= 60),
  filiere text check (filiere is null or char_length(filiere) <= 80),
  sector text check (sector is null or char_length(sector) <= 80),
  hashtags text[] not null default '{}' check (cardinality(hashtags) <= 8),
  tagged_orgs uuid[] not null default '{}' check (cardinality(tagged_orgs) <= 3),
  main_action text check (main_action is null or main_action in ('acheter', 'soutenir', 'parrainer', 'postuler', 's_inscrire', 'voter', 'telecharger', 'noter', 'demander_devis', 'encourager', 'offrir', 'reserver')),
  action_target_kind text check (action_target_kind is null or action_target_kind in ('listing', 'event', 'opportunity', 'mission', 'project')),
  action_target_id uuid,
  comments_mode text not null default 'all' check (comments_mode in ('all', 'off')),
  participation_mode text not null default 'on_request' check (participation_mode in ('on_request', 'off')),
  frequency text not null default 'once' check (frequency in ('once', 'weekly')),
  duration_min integer check (duration_min is null or duration_min between 5 and 480),
  reminders_enabled boolean not null default true,
  video_quality text not null default 'auto' check (video_quality in ('auto', '480p', '720p', '1080p')),
  clips_allowed boolean not null default true,
  audio_only boolean not null default false,
  record_replay boolean not null default false,
  notify_message text check (notify_message is null or char_length(notify_message) <= 200),
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  check ((main_action is null and action_target_kind is null and action_target_id is null) or main_action is not null),
  check ((action_target_kind is null) = (action_target_id is null))
);
create index if not exists live_settings_filiere on live_settings (filiere) where filiere is not null;
create index if not exists live_settings_hashtags on live_settings using gin (hashtags);
alter table live_settings enable row level security;
revoke all on live_settings from anon, authenticated;

-- ------------------------------------------------------------------ droits
-- Hôte et administrateur ; le co-hôte approuvé n'a que les droits « descriptifs » (p_full = false).
create or replace function _live_can_edit(p_live uuid, p_user uuid, p_full boolean default false) returns boolean
language sql stable security definer set search_path = public as $$
  select p_user is not null and (
    exists (select 1 from lives l where l.id = p_live and l.host_id = p_user)
    or exists (select 1 from profiles where id = p_user and role::text = 'admin')
    or (not coalesce(p_full, false) and exists (select 1 from live_cohosts c where c.live_id = p_live and c.user_id = p_user and c.status = 'approved')))
$$;
revoke all on function _live_can_edit(uuid, uuid, boolean) from public, anon, authenticated;

create or replace function _live_can_edit_me(p_live uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select _live_can_edit(p_live, auth.uid(), false)
$$;
revoke all on function _live_can_edit_me(uuid) from public;
grant execute on function _live_can_edit_me(uuid) to authenticated;

grant select on live_settings to authenticated;
drop policy if exists "reglages de live : hote, co-hote, administration" on live_settings;
create policy "reglages de live : hote, co-hote, administration" on live_settings for select using (_live_can_edit_me(live_id));

-- ------------------------------------------------------------------ Action Unique : l'action et sa cible appartiennent à l'hôte
-- Retourne NULL si valide, sinon le message d'erreur lisible.
create or replace function _live_action_check(p_host uuid, p_action text, p_kind text, p_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare ok boolean := false; t text;
begin
  if p_action is null then return case when p_kind is null and p_id is null then null else 'Une cible exige une action' end; end if;
  if p_action not in ('acheter', 'soutenir', 'parrainer', 'postuler', 's_inscrire', 'voter', 'telecharger', 'noter', 'demander_devis', 'encourager', 'offrir', 'reserver') then
    return 'Action inconnue';
  end if;
  if p_action in ('parrainer', 'offrir') then
    return case when p_kind is null and p_id is null then null else 'Cette action ne prend pas de cible' end;
  end if;
  if p_kind is null or p_id is null then return 'Cette action exige une cible : choisissez l''élément concerné'; end if;
  if p_action in ('acheter', 'reserver', 'demander_devis', 'telecharger', 'noter') and p_kind <> 'listing' then return 'Cette action concerne une annonce du vendeur'; end if;
  if p_action = 'postuler' and p_kind not in ('opportunity', 'mission') then return 'Postuler concerne une opportunité ou une mission'; end if;
  if p_action = 's_inscrire' and p_kind <> 'event' then return 'S''inscrire concerne un événement'; end if;
  if p_action in ('voter', 'soutenir', 'encourager') and p_kind <> 'project' then return 'Cette action concerne un projet'; end if;

  if p_kind = 'listing' then
    select offer_type_of(l.category) into t from listings l
      where l.id = p_id and l.status = 'approved'
        and (l.seller_id = p_host or exists (select 1 from shops s where s.id = l.shop_id and s.owner_id = p_host and s.status = 'active'))
        and not exists (select 1 from shops s where s.id = l.shop_id and s.status <> 'active');
    if t is null then return 'Annonce introuvable ou qui n''appartient pas à l''hôte'; end if;
    ok := case p_action
      when 'acheter' then t in ('product', 'tech', 'project')
      when 'reserver' then t = 'service'
      when 'demander_devis' then t in ('service', 'tech', 'project')
      when 'telecharger' then t = 'tech'
      else true end;
    if not ok then return 'Cette action ne correspond pas au type de l''annonce'; end if;
  elsif p_kind = 'event' then
    if not exists (select 1 from events e where e.id = p_id and e.created_by = p_host and e.status = 'published') then return 'Événement introuvable ou qui n''appartient pas à l''hôte'; end if;
  elsif p_kind = 'opportunity' then
    if not exists (select 1 from opportunities o where o.id = p_id and o.poster_id = p_host and o.status = 'published') then return 'Opportunité introuvable ou qui n''appartient pas à l''hôte'; end if;
  elsif p_kind = 'mission' then
    if not exists (select 1 from missions m where m.id = p_id and m.client_id = p_host) then return 'Mission introuvable ou qui n''appartient pas à l''hôte'; end if;
  elsif p_kind = 'project' then
    if not exists (select 1 from projects p where p.id = p_id and p.owner_id = p_host and p.status = 'approved' and p.visibility = 'public') then return 'Projet introuvable, non publié ou qui n''appartient pas à l''hôte'; end if;
  end if;
  return null;
end $$;
revoke all on function _live_action_check(uuid, text, text, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ écriture des réglages
create or replace function live_set_settings(p_live uuid, p_settings jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  l lives%rowtype; s live_settings%rowtype; a jsonb := coalesce(p_settings, '{}'::jsonb); is_full boolean;
  v_tags text[]; v_orgs uuid[]; act text; kind text; tid uuid; err text; raw text; v text;
begin
  perform _assert_active();
  if jsonb_typeof(a) <> 'object' then raise exception 'Réglages invalides'; end if;
  select * into l from lives where id = p_live for update;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if not _live_can_edit(p_live, auth.uid(), false) then raise exception 'Action non autorisée'; end if;
  if l.status = 'ended' then raise exception 'Ce live est terminé'; end if;
  is_full := _live_can_edit(p_live, auth.uid(), true);
  if not is_full and (a ? 'tagged_orgs' or a ? 'main_action' or a ? 'action_target_kind' or a ? 'action_target_id' or a ? 'record_replay') then
    raise exception 'Réservé à l''hôte du live';
  end if;
  insert into live_settings (live_id) values (p_live) on conflict do nothing;
  select * into s from live_settings where live_id = p_live for update;

  if a ? 'category' then s.category := nullif(btrim(_clean_live_title(a->>'category')), ''); end if;
  if a ? 'filiere' then s.filiere := nullif(btrim(_clean_live_title(a->>'filiere')), ''); end if;
  if a ? 'sector' then s.sector := nullif(btrim(_clean_live_title(a->>'sector')), ''); end if;
  if char_length(coalesce(s.category, '')) > 60 then raise exception 'Catégorie : 60 caractères au plus'; end if;
  if char_length(coalesce(s.filiere, '')) > 80 or char_length(coalesce(s.sector, '')) > 80 then raise exception 'Filière et secteur : 80 caractères au plus'; end if;

  if a ? 'hashtags' then
    if jsonb_typeof(a->'hashtags') = 'null' then
      s.hashtags := '{}';
    elsif jsonb_typeof(a->'hashtags') <> 'array' then
      raise exception 'Hashtags invalides';
    else
      select coalesce(array_agg(distinct t), '{}') into v_tags
        from (select lower(regexp_replace(btrim(e), '^#+', '')) t from jsonb_array_elements_text(a->'hashtags') e) q where t <> '';
      if cardinality(v_tags) > 8 then raise exception '8 hashtags au plus'; end if;
      if exists (select 1 from unnest(v_tags) t where t !~ '^[a-z0-9_àâäçéèêëîïôöùûüœ]{2,30}$') then
        raise exception 'Hashtag invalide : 2 à 30 lettres ou chiffres, sans espace ni lien';
      end if;
      s.hashtags := v_tags;
    end if;
  end if;

  if a ? 'tagged_orgs' then
    if jsonb_typeof(a->'tagged_orgs') = 'null' then
      s.tagged_orgs := '{}';
    elsif jsonb_typeof(a->'tagged_orgs') <> 'array' then
      raise exception 'Entreprises invalides';
    else
      if jsonb_array_length(a->'tagged_orgs') > 3 then raise exception 'Trois entreprises taguées au plus'; end if;
      if exists (select 1 from jsonb_array_elements_text(a->'tagged_orgs') e where e !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'Entreprise invalide'; end if;
      select coalesce(array_agg(distinct e::uuid), '{}') into v_orgs from jsonb_array_elements_text(a->'tagged_orgs') e;
      if exists (select 1 from unnest(v_orgs) o where not exists (
           select 1 from company_profiles c join profiles p on p.id = c.owner_id where c.owner_id = o and c.status = 'approved' and not p.suspended)) then
        raise exception 'Entreprise introuvable ou non vérifiée';
      end if;
      s.tagged_orgs := v_orgs;
    end if;
  end if;

  if a ? 'main_action' or a ? 'action_target_kind' or a ? 'action_target_id' then
    act := case when a ? 'main_action' then nullif(a->>'main_action', '') else s.main_action end;
    kind := case when a ? 'action_target_kind' then nullif(a->>'action_target_kind', '') else s.action_target_kind end;
    raw := case when a ? 'action_target_id' then nullif(a->>'action_target_id', '') else s.action_target_id::text end;
    if raw is not null and raw !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'Cible invalide'; end if;
    tid := raw::uuid;
    if act is null then kind := null; tid := null; end if;
    err := _live_action_check(l.host_id, act, kind, tid);
    if err is not null then raise exception '%', err; end if;
    s.main_action := act; s.action_target_kind := kind; s.action_target_id := tid;
  end if;

  if a ? 'comments_mode' then
    if a->>'comments_mode' not in ('all', 'off') then raise exception 'Mode de commentaires inconnu'; end if;
    s.comments_mode := a->>'comments_mode';
  end if;
  if a ? 'participation_mode' then
    if a->>'participation_mode' not in ('on_request', 'off') then raise exception 'Mode de participation inconnu'; end if;
    s.participation_mode := a->>'participation_mode';
  end if;
  if a ? 'frequency' then
    if a->>'frequency' not in ('once', 'weekly') then raise exception 'Fréquence inconnue'; end if;
    s.frequency := a->>'frequency';
  end if;
  if a ? 'duration_min' then
    if jsonb_typeof(a->'duration_min') = 'null' then
      s.duration_min := null;
    else
      if jsonb_typeof(a->'duration_min') <> 'number' or (a->>'duration_min') !~ '^[0-9]{1,4}$' or (a->>'duration_min')::int not between 5 and 480 then raise exception 'Durée : 5 à 480 minutes'; end if;
      s.duration_min := (a->>'duration_min')::int;
    end if;
  end if;
  if a ? 'video_quality' then
    if a->>'video_quality' not in ('auto', '480p', '720p', '1080p') then raise exception 'Qualité vidéo inconnue'; end if;
    s.video_quality := a->>'video_quality';
  end if;
  foreach v in array array['reminders_enabled', 'clips_allowed', 'audio_only', 'record_replay'] loop
    if a ? v and jsonb_typeof(a->v) <> 'boolean' then raise exception 'Réglage % invalide', v; end if;
  end loop;
  if a ? 'reminders_enabled' then s.reminders_enabled := (a->>'reminders_enabled')::boolean; end if;
  if a ? 'clips_allowed' then s.clips_allowed := (a->>'clips_allowed')::boolean; end if;
  if a ? 'audio_only' then s.audio_only := (a->>'audio_only')::boolean; end if;
  if a ? 'record_replay' then s.record_replay := (a->>'record_replay')::boolean; end if;
  if a ? 'notify_message' then
    s.notify_message := nullif(left(_clean_live_title(a->>'notify_message'), 200), '');
  end if;

  update live_settings set category = s.category, filiere = s.filiere, sector = s.sector, hashtags = s.hashtags, tagged_orgs = s.tagged_orgs,
    main_action = s.main_action, action_target_kind = s.action_target_kind, action_target_id = s.action_target_id,
    comments_mode = s.comments_mode, participation_mode = s.participation_mode, frequency = s.frequency, duration_min = s.duration_min,
    reminders_enabled = s.reminders_enabled, video_quality = s.video_quality, clips_allowed = s.clips_allowed, audio_only = s.audio_only,
    record_replay = s.record_replay, notify_message = s.notify_message, updated_by = auth.uid(), updated_at = now()
  where live_id = p_live;
  return live_settings_get(p_live);
end $$;
revoke all on function live_set_settings(uuid, jsonb) from public, anon;
grant execute on function live_set_settings(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------------ lectures
-- Inscrits : personnes distinctes ayant activé le rappel du live ou inscrites (confirmées) à l'événement lié.
create or replace function _live_registered(p_live uuid) returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::int from (
    select user_id from live_reminders where live_id = p_live
    union
    select r.user_id from event_registrations r join lives l on l.event_id = r.event_id where l.id = p_live and r.status = 'confirmed') x
$$;
revoke all on function _live_registered(uuid) from public, anon, authenticated;

-- Fiche publique d'un live pour l'Atelier. « viewers » = spectateurs connectés en ce moment (battement < 90 s, mis à jour par le serveur) ;
-- « total_views » = personnes distinctes identifiées ayant rejoint ce live au moins une fois (une aperçu ou une impression n'est jamais comptée).
create or replace function _live_atelier_card(l lives) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s live_settings%rowtype; price integer; orgs jsonb; chk text; title text; hrole text;
begin
  select * into s from live_settings where live_id = l.id;
  if l.event_id is not null then select e.price into price from events e where e.id = l.event_id and e.status <> 'cancelled'; end if;
  orgs := coalesce((select jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'name', c.company_name, 'logo_path', c.logo_path) order by c.company_name)
                      from company_profiles c where c.owner_id = any (coalesce(s.tagged_orgs, '{}')) and c.status = 'approved'), '[]'::jsonb);
  if s.main_action is not null then chk := _live_action_check(l.host_id, s.main_action, s.action_target_kind, s.action_target_id); end if;
  select role::text into hrole from profiles where id = l.host_id;
  return jsonb_build_object(
    'id', l.id, 'status', l.status, 'host_id', l.host_id, 'host_role', hrole,
    'category', s.category, 'filiere', s.filiere, 'sector', s.sector, 'hashtags', to_jsonb(coalesce(s.hashtags, '{}')), 'tagged_orgs', orgs,
    'frequency', coalesce(s.frequency, 'once'), 'duration_min', s.duration_min, 'reminders_enabled', coalesce(s.reminders_enabled, true),
    'comments_mode', coalesce(s.comments_mode, 'all'), 'participation_mode', coalesce(s.participation_mode, 'on_request'),
    'clips_allowed', coalesce(s.clips_allowed, true), 'audio_only', coalesce(s.audio_only, false), 'record_replay', coalesce(s.record_replay, false),
    'main_action', case when s.main_action is not null and chk is null then s.main_action end,
    'action_target_kind', case when s.main_action is not null and chk is null then s.action_target_kind end,
    'action_target_id', case when s.main_action is not null and chk is null then s.action_target_id end,
    'action_available', s.main_action is not null and chk is null,
    'event_id', l.event_id, 'price', price, 'free', coalesce(price, 0) = 0,
    'registered', _live_registered(l.id),
    'viewers', case when l.status = 'live' then l.viewer_count else 0 end,
    'total_views', (select count(*)::int from live_viewers v where v.live_id = l.id));
end $$;
revoke all on function _live_atelier_card(lives) from public, anon, authenticated;

create or replace function lives_atelier_extras(p_live_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  return coalesce((select jsonb_agg(_live_atelier_card(l))
    from lives l join profiles a on a.id = l.host_id and not a.suspended
    where l.id = any (coalesce(p_live_ids[1:100], '{}')) and l.status <> 'cancelled'
      and (l.visibilite = 'public' or l.host_id = uid or _live_invited(l.id))), '[]'::jsonb);
end $$;
revoke all on function lives_atelier_extras(uuid[]) from public;
grant execute on function lives_atelier_extras(uuid[]) to anon, authenticated;

create or replace function live_settings_get(p_live uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); l lives%rowtype; s live_settings%rowtype; card jsonb; own boolean; target_title text;
begin
  select * into l from lives where id = p_live and status <> 'cancelled';
  if not found then return null; end if;
  if not coalesce(l.visibilite = 'public' or l.host_id = uid or _live_invited(l.id) or _live_can_edit(l.id, uid, false), false) then return null; end if;
  own := _live_can_edit(l.id, uid, false);
  card := _live_atelier_card(l);
  select * into s from live_settings where live_id = l.id;
  if card->>'action_available' = 'true' then
    target_title := case s.action_target_kind
      when 'listing' then (select title from listings where id = s.action_target_id)
      when 'event' then (select title from events where id = s.action_target_id)
      when 'opportunity' then (select title from opportunities where id = s.action_target_id)
      when 'mission' then (select title::text from missions where id = s.action_target_id)
      when 'project' then (select title from projects where id = s.action_target_id)
      else null end;
  end if;
  return card || jsonb_build_object(
    'title', l.title, 'description', l.description, 'scheduled_at', l.scheduled_at, 'started_at', l.started_at, 'host', _live_author(l.host_id),
    'visibilite', l.visibilite, 'live_type', l.live_type, 'mine', coalesce(l.host_id = uid, false), 'can_edit', coalesce(own, false),
    'action_target_title', target_title)
    || case when own then jsonb_build_object('video_quality', coalesce(s.video_quality, 'auto'), 'notify_message', s.notify_message,
         'main_action_raw', s.main_action, 'action_target_kind_raw', s.action_target_kind, 'action_target_id_raw', s.action_target_id, 'tagged_orgs_raw', to_jsonb(coalesce(s.tagged_orgs, '{}')))
       else '{}'::jsonb end;
end $$;
revoke all on function live_settings_get(uuid) from public;
grant execute on function live_settings_get(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ gestion d'un live programmé
create or replace function live_update(p_live uuid, p_title text, p_description text default null, p_scheduled_at timestamptz default null) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; v_title text := _clean_live_title(p_title); changed_date boolean; r record;
begin
  perform _assert_active();
  select * into l from lives where id = p_live for update;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() then raise exception 'Action non autorisée'; end if;
  if l.status <> 'scheduled' then raise exception 'Seul un live programmé peut être modifié'; end if;
  if char_length(v_title) not between 3 and 100 then raise exception 'Le titre doit contenir entre 3 et 100 caractères (sans lien)'; end if;
  if p_description is not null and char_length(_clean_live_title(p_description)) > 500 then raise exception 'La description fait 500 caractères au plus'; end if;
  if p_scheduled_at is not null and (p_scheduled_at < now() + interval '1 minute' or p_scheduled_at > now() + interval '90 days') then
    raise exception 'Choisissez une date et une heure à venir (90 jours au plus)';
  end if;
  changed_date := p_scheduled_at is not null and p_scheduled_at is distinct from l.scheduled_at;
  update lives set title = v_title, description = case when p_description is null then description else left(_clean_live_title(p_description), 500) end, scheduled_at = coalesce(p_scheduled_at, scheduled_at) where id = p_live;
  if changed_date then
    update live_reminders set notified = false where live_id = p_live;
    for r in select user_id from live_reminders where live_id = p_live limit 500 loop
      perform notify_user(r.user_id, 'live', 'Live reprogrammé', '« ' || v_title || ' » a changé d''horaire : consultez l''agenda des ateliers.', jsonb_build_object('live', p_live));
    end loop;
  end if;
  return 'ok';
end $$;
revoke all on function live_update(uuid, text, text, timestamptz) from public, anon;
grant execute on function live_update(uuid, text, text, timestamptz) to authenticated;

-- Annulation d'un live programmé : les inscrits (rappels) sont prévenus, puis le live passe à « annulé » (même règle que end_live).
create or replace function live_cancel(p_live uuid, p_reason text default null) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; r record; why text := nullif(left(_clean_live_title(p_reason), 200), '');
begin
  perform _assert_active();
  select * into l from lives where id = p_live for update;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() then raise exception 'Action non autorisée'; end if;
  if l.status <> 'scheduled' then raise exception 'Seul un live programmé peut être annulé ; un direct en cours se termine depuis la régie'; end if;
  for r in select user_id from live_reminders where live_id = p_live limit 500 loop
    perform notify_user(r.user_id, 'live', 'Live annulé', '« ' || l.title || ' » est annulé.' || coalesce(' ' || why, ''), jsonb_build_object('live', p_live));
  end loop;
  update lives set status = 'cancelled', ended_at = now(), viewer_count = 0 where id = p_live;
  return 'cancelled';
end $$;
revoke all on function live_cancel(uuid, text) from public, anon;
grant execute on function live_cancel(uuid, text) to authenticated;

-- Audience réelle d'un live de l'hôte (ou de l'administration). Aucune donnée commerciale ou financière ici.
create or replace function live_host_stats(p_live uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live;
  if not found then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and not exists (select 1 from profiles where id = auth.uid() and role::text = 'admin') then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object('live', l.id, 'status', l.status,
    'viewers_now', case when l.status = 'live' then l.viewer_count else 0 end,
    'peak_viewers', l.peak_viewers,
    'total_views', (select count(*)::int from live_viewers v where v.live_id = l.id),
    'registered', _live_registered(l.id),
    'chat_messages', (select count(*)::int from live_messages m where m.live_id = l.id and m.kind = 'chat' and not m.hidden),
    'reactions', (select count(*)::int from live_messages m where m.live_id = l.id and m.kind = 'reaction'),
    'recording', (select status from live_recordings r where r.live_id = l.id limit 1));
end $$;
revoke all on function live_host_stats(uuid) from public, anon;
grant execute on function live_host_stats(uuid) to authenticated;

-- Recherche d'entreprises vérifiées à taguer (noms publics uniquement, comme company_public).
create or replace function live_orgs_search(p_query text default '', p_limit integer default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare qq text := btrim(coalesce(p_query, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('owner_id', c.owner_id, 'name', c.company_name, 'sector', c.sector, 'logo_path', c.logo_path) order by c.company_name)
    from (select c.* from company_profiles c join profiles p on p.id = c.owner_id and not p.suspended
          where c.status = 'approved' and (qq = '' or c.company_name ilike '%' || replace(replace(replace(qq, '\', '\\'), '%', '\%'), '_', '\_') || '%')
          order by c.company_name limit least(greatest(coalesce(p_limit, 20), 1), 50)) c), '[]'::jsonb);
end $$;
revoke all on function live_orgs_search(text, integer) from public, anon;
grant execute on function live_orgs_search(text, integer) to authenticated;

-- Cibles possibles de l'Action Unique : uniquement les éléments de l'appelant qui passent _live_action_check (même règle que l'écriture).
create or replace function live_action_targets(p_kind text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if p_kind = 'listing' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'offer_type', offer_type_of(l.category), 'price', l.price) order by l.created_at desc)
      from (select * from listings x where x.status = 'approved'
              and (x.seller_id = uid or exists (select 1 from shops s where s.id = x.shop_id and s.owner_id = uid and s.status = 'active'))
              and not exists (select 1 from shops s where s.id = x.shop_id and s.status <> 'active') order by x.created_at desc limit 50) l), '[]'::jsonb);
  elsif p_kind = 'event' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'price', e.price, 'starts_at', e.starts_at) order by e.starts_at)
      from (select * from events x where x.created_by = uid and x.status = 'published' and x.starts_at > now() - interval '1 day' order by x.starts_at limit 50) e), '[]'::jsonb);
  elsif p_kind = 'opportunity' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'title', o.title) order by o.created_at desc)
      from (select * from opportunities x where x.poster_id = uid and x.status = 'published' order by x.created_at desc limit 50) o), '[]'::jsonb);
  elsif p_kind = 'mission' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title) order by m.created_at desc)
      from (select * from missions x where x.client_id = uid order by x.created_at desc limit 50) m), '[]'::jsonb);
  elsif p_kind = 'project' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'title', p.title) order by p.created_at desc)
      from (select * from projects x where x.owner_id = uid and x.status = 'approved' and x.visibility = 'public' order by x.created_at desc limit 50) p), '[]'::jsonb);
  end if;
  raise exception 'Type de cible inconnu';
end $$;
revoke all on function live_action_targets(text) from public, anon;
grant execute on function live_action_targets(text) to authenticated;
-- ------------------------------------------------------------------ garde-fous issus des réglages
create or replace function _live_settings_guard_chat() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'chat' and new.user_id is not null
     and exists (select 1 from live_settings s join lives l on l.id = s.live_id where s.live_id = new.live_id and s.comments_mode = 'off' and l.host_id <> new.user_id) then
    raise exception 'Les commentaires sont désactivés pour ce live';
  end if;
  return new;
end $$;
revoke all on function _live_settings_guard_chat() from public, anon, authenticated;
drop trigger if exists trg_live_settings_chat on live_messages;
create trigger trg_live_settings_chat before insert on live_messages for each row execute function _live_settings_guard_chat();

create or replace function _live_settings_guard_cohost() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'requested' and exists (select 1 from live_settings s where s.live_id = new.live_id and s.participation_mode = 'off') then
    raise exception 'La participation en direct est désactivée pour ce live';
  end if;
  return new;
end $$;
revoke all on function _live_settings_guard_cohost() from public, anon, authenticated;
drop trigger if exists trg_live_settings_cohost on live_cohosts;
create trigger trg_live_settings_cohost before insert or update on live_cohosts for each row execute function _live_settings_guard_cohost();

create or replace function _live_settings_guard_reminders() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from live_settings s where s.live_id = new.live_id and not s.reminders_enabled) then
    raise exception 'Les rappels sont désactivés pour ce live';
  end if;
  return new;
end $$;
revoke all on function _live_settings_guard_reminders() from public, anon, authenticated;
drop trigger if exists trg_live_settings_reminders on live_reminders;
create trigger trg_live_settings_reminders before insert on live_reminders for each row execute function _live_settings_guard_reminders();

-- Reprend 20261115200200 : le message de notification choisi par l'hôte (200 caractères, sans lien) remplace le texte par défaut du rappel.
create or replace function send_live_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select rm.live_id, rm.user_id, l.title, l.status, l.scheduled_at, s.notify_message
    from live_reminders rm join lives l on l.id = rm.live_id left join live_settings s on s.live_id = l.id
    where not rm.notified
      and ((l.status = 'scheduled' and l.scheduled_at <= now() + interval '30 minutes') or l.status = 'live')
    limit 500
  loop
    insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'live_reminder', case when r.status = 'live' then 'Le live a commencé' else 'Un live commence bientôt' end,
            left('« ' || r.title || ' »' || case when r.status = 'live' then ' est en direct.' else ' commence dans moins de 30 minutes.' end || coalesce(' ' || r.notify_message, ''), 500),
            jsonb_build_object('live', r.live_id));
    update live_reminders set notified = true where live_id = r.live_id and user_id = r.user_id;
    n := n + 1;
  end loop;
  delete from live_reminders rm using lives l where l.id = rm.live_id and (l.status in ('ended', 'cancelled') or l.created_at < now() - interval '90 days');
  return n;
end $$;
revoke all on function send_live_reminders() from public, anon, authenticated;
