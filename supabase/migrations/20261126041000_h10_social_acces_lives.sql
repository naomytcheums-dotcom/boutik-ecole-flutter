-- H10 SOCIAL, étape 2 : accès aux lives (type, visibilité, lien, invitations, billet).
--  * lives : live_type (public, prive, evenement, recrutement, soutenance, shopping, consultation), visibilite (public | prive),
--    liens optionnels vers un événement, une mission ou une annonce (opportunité) du créateur ;
--  * live_invites : invités nommément par l'hôte (donne accès à un live privé ou à un live à billet, sans payer) ;
--  * billet : AUCUN prix ni règle financière nouvelle. Si le live est lié à un événement payant existant (events.price > 0), l'accès exige une
--    inscription confirmée (donc payée) dans event_registrations, via le flux d'événements payants inchangé ;
--  * _live_access(live, user) : règle unique (hôte et administrateur gardent l'accès ; banni, suspendu, anonyme, privé sans invitation, billet manquant refusés) ;
--    live_can_join(live) pour l'application, live_access_for(live, user) pour l'Edge Function « live-token » (service_role) ;
--  * join_live, les messages/réactions/cadeaux (déclencheur), la liste, l'agenda, live_get et les politiques de lecture respectent cette règle.
-- Retour arrière : recréer lives_now/lives_agenda/join_live/live_get depuis 20261117060300 / 20261115200200 / 20261115170000 / 20261110000000, recréer les politiques
--   « lives visibles » et « messages de live visibles » depuis 20261110000000 ; drop trigger trg_live_message_access on live_messages ;
--   drop function live_can_join(uuid), live_access_for(uuid, uuid), live_configure(uuid, text, text, uuid, uuid, uuid), live_invite(uuid, uuid), live_uninvite(uuid, uuid),
--   live_invites_list(uuid), _live_access(uuid, uuid), _live_invited(uuid), _live_is_open(uuid), _live_access_json(uuid, uuid), _live_message_access() ; drop table live_invites ;
--   alter table lives drop column live_type, drop column visibilite, drop column event_id, drop column mission_id, drop column opportunity_id.

alter table lives add column if not exists live_type text not null default 'public';
alter table lives add column if not exists visibilite text not null default 'public';
alter table lives add column if not exists event_id uuid references events(id) on delete set null;
alter table lives add column if not exists mission_id uuid references missions(id) on delete set null;
alter table lives add column if not exists opportunity_id uuid references opportunities(id) on delete set null;
do $$ begin
  alter table lives add constraint lives_live_type_check check (live_type in ('public', 'prive', 'evenement', 'recrutement', 'soutenance', 'shopping', 'consultation'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table lives add constraint lives_visibilite_check check (visibilite in ('public', 'prive'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table lives add constraint lives_prive_coherent check (live_type <> 'prive' or visibilite = 'prive');
exception when duplicate_object then null; end $$;
create index if not exists lives_event on lives (event_id) where event_id is not null;

create table if not exists live_invites (
  live_id uuid not null references lives(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  invited_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (live_id, user_id)
);
create index if not exists live_invites_user on live_invites (user_id);
alter table live_invites enable row level security;
revoke all on live_invites from anon, authenticated;
grant select on live_invites to authenticated;
drop policy if exists "invitations de live : la mienne ou l'hôte" on live_invites;
create policy "invitations de live : la mienne ou l'hôte" on live_invites for select
  using (user_id = auth.uid() or exists (select 1 from lives l where l.id = live_id and l.host_id = auth.uid()));

-- ------------------------------------------------------------------ règle d'accès
create or replace function _live_invited(p_live uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from live_invites where live_id = p_live and user_id = auth.uid())
    or exists (select 1 from profiles where id = auth.uid() and role::text in ('admin', 'support')))
$$;
revoke all on function _live_invited(uuid) from public;
grant execute on function _live_invited(uuid) to anon, authenticated;

-- Live ouvert à tout le monde : public et sans billet exigé.
create or replace function _live_is_open(p_live uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from lives l where l.id = p_live and l.status <> 'cancelled' and l.visibilite = 'public'
    and not exists (select 1 from events e where e.id = l.event_id and coalesce(e.price, 0) > 0))
$$;
revoke all on function _live_is_open(uuid) from public;
grant execute on function _live_is_open(uuid) to anon, authenticated;

create or replace function _live_access(p_live uuid, p_user uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare l lives%rowtype; u profiles%rowtype; ev events%rowtype; reg text;
begin
  if p_user is null then return 'connexion'; end if;
  select * into u from profiles where id = p_user;
  if not found then return 'connexion'; end if;
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then return 'introuvable'; end if;
  if u.suspended then return 'suspendu'; end if;
  if l.host_id = p_user or u.role::text = 'admin' then return 'ok'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = p_user) then return 'banni'; end if;
  if exists (select 1 from live_invites where live_id = p_live and user_id = p_user)
     or exists (select 1 from live_cohosts where live_id = p_live and user_id = p_user and status = 'approved') then return 'ok'; end if;
  if l.event_id is not null then
    select * into ev from events where id = l.event_id;
    if found then
      if ev.status = 'cancelled' then return 'evenement_annule'; end if;
      select status into reg from event_registrations where event_id = ev.id and user_id = p_user;
      if coalesce(ev.price, 0) > 0 then
        if reg is distinct from 'confirmed' then return 'billet_requis'; end if;
        return 'ok';
      end if;
      if reg = 'confirmed' then return 'ok'; end if;
    end if;
  end if;
  if l.visibilite = 'prive' then return 'invitation_requise'; end if;
  return 'ok';
end $$;
revoke all on function _live_access(uuid, uuid) from public, anon, authenticated;

create or replace function _live_access_json(p_live uuid, p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := _live_access(p_live, p_user); l lives%rowtype; price integer;
begin
  select * into l from lives where id = p_live;
  if l.event_id is not null then select e.price into price from events e where e.id = l.event_id; end if;
  return jsonb_build_object('allowed', r = 'ok', 'reason', r,
    'message', case r
      when 'ok' then ''
      when 'connexion' then 'Connexion requise pour rejoindre ce live.'
      when 'introuvable' then 'Live introuvable.'
      when 'suspendu' then 'Votre compte est suspendu : le direct est inaccessible.'
      when 'banni' then 'Vous ne pouvez pas rejoindre ce live.'
      when 'invitation_requise' then 'Ce live est privé : l''accès se fait sur invitation de l''hôte.'
      when 'billet_requis' then 'Ce live est réservé aux personnes inscrites à l''événement lié (billet).'
      when 'evenement_annule' then 'L''événement lié à ce live est annulé.'
      else 'Accès refusé.' end,
    'event_id', l.event_id, 'price', price, 'live_type', l.live_type, 'visibilite', l.visibilite);
end $$;
revoke all on function _live_access_json(uuid, uuid) from public, anon, authenticated;

create or replace function live_can_join(p_live uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select _live_access_json(p_live, auth.uid())
$$;
revoke all on function live_can_join(uuid) from public;
grant execute on function live_can_join(uuid) to anon, authenticated;

-- Appelée par l'Edge Function « live-token » avec la clé de service : l'identité vient du jeton déjà vérifié.
create or replace function live_access_for(p_live uuid, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select _live_access_json(p_live, p_user)
$$;
revoke all on function live_access_for(uuid, uuid) from public, anon, authenticated;
grant execute on function live_access_for(uuid, uuid) to service_role;

-- ------------------------------------------------------------------ configuration par l'hôte
create or replace function live_configure(p_live uuid, p_type text, p_visibilite text, p_event uuid default null, p_mission uuid default null, p_opportunity uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; staff boolean; t text := coalesce(nullif(btrim(p_type), ''), 'public'); v text := coalesce(nullif(btrim(p_visibilite), ''), 'public');
begin
  perform _assert_active();
  select * into l from lives where id = p_live for update;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  staff := exists (select 1 from profiles where id = auth.uid() and role::text = 'admin');
  if l.host_id <> auth.uid() and not staff then raise exception 'Action non autorisée'; end if;
  if l.status = 'ended' then raise exception 'Ce live est terminé'; end if;
  if t not in ('public', 'prive', 'evenement', 'recrutement', 'soutenance', 'shopping', 'consultation') then raise exception 'Type de live inconnu'; end if;
  if v not in ('public', 'prive') then raise exception 'Visibilité inconnue'; end if;
  if t = 'prive' then v := 'prive'; end if;
  if p_event is not null and not exists (select 1 from events e where e.id = p_event and e.status <> 'cancelled' and (e.created_by = l.host_id or staff)) then
    raise exception 'Événement introuvable ou qui ne vous appartient pas';
  end if;
  if p_mission is not null and not exists (select 1 from missions m where m.id = p_mission and (m.client_id = l.host_id or staff)) then
    raise exception 'Mission introuvable ou qui ne vous appartient pas';
  end if;
  if p_opportunity is not null and not exists (select 1 from opportunities o where o.id = p_opportunity and (o.poster_id = l.host_id or staff)) then
    raise exception 'Annonce introuvable ou qui ne vous appartient pas';
  end if;
  update lives set live_type = t, visibilite = v, event_id = p_event, mission_id = p_mission, opportunity_id = p_opportunity where id = p_live;
  return 'ok';
end $$;
revoke all on function live_configure(uuid, text, text, uuid, uuid, uuid) from public, anon;
grant execute on function live_configure(uuid, text, text, uuid, uuid, uuid) to authenticated;

create or replace function live_invite(p_live uuid, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found or l.status in ('cancelled', 'ended') then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and not exists (select 1 from profiles where id = auth.uid() and role::text = 'admin') then raise exception 'Action non autorisée'; end if;
  if p_user = l.host_id then raise exception 'L''hôte a déjà accès à son live'; end if;
  if not exists (select 1 from profiles where id = p_user and not suspended) then raise exception 'Membre introuvable'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = p_user) then raise exception 'Ce membre est exclu de ce live'; end if;
  if (select count(*) from live_invites where live_id = p_live) >= 200 and not exists (select 1 from live_invites where live_id = p_live and user_id = p_user) then
    raise exception '200 invités au plus par live';
  end if;
  insert into live_invites (live_id, user_id, invited_by) values (p_live, p_user, auth.uid()) on conflict do nothing;
  if found then
    perform notify_user(p_user, 'live', 'Invitation à un live', _live_author(l.host_id) || ' vous invite : ' || _clean_live_title(l.title), jsonb_build_object('live', p_live, 'host', l.host_id));
  end if;
  return 'ok';
end $$;
revoke all on function live_invite(uuid, uuid) from public, anon;
grant execute on function live_invite(uuid, uuid) to authenticated;

create or replace function live_uninvite(p_live uuid, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and not exists (select 1 from profiles where id = auth.uid() and role::text = 'admin') then raise exception 'Action non autorisée'; end if;
  delete from live_invites where live_id = p_live and user_id = p_user;
  update live_viewers set left_at = now() where live_id = p_live and user_id = p_user and left_at is null
    and _live_access(p_live, p_user) <> 'ok';
  perform _live_recount(p_live);
  return 'ok';
end $$;
revoke all on function live_uninvite(uuid, uuid) from public, anon;
grant execute on function live_uninvite(uuid, uuid) to authenticated;

create or replace function live_invites_list(p_live uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live;
  if not found then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and not exists (select 1 from profiles where id = auth.uid() and role::text = 'admin') then raise exception 'Action non autorisée'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', i.user_id, 'name', _live_author(i.user_id), 'created_at', i.created_at) order by i.created_at) from live_invites i where i.live_id = p_live), '[]'::jsonb);
end $$;
revoke all on function live_invites_list(uuid) from public, anon;
grant execute on function live_invites_list(uuid) to authenticated;

-- ------------------------------------------------------------------ application de la règle
-- join_live : reprend 20261115170000 ; la vérification de bannissement devient la règle d'accès complète.
create or replace function join_live(p_live uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; n int; acc jsonb;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.status <> 'live' then raise exception 'Ce live n''est pas en direct'; end if;
  acc := _live_access_json(p_live, auth.uid());
  if not (acc->>'allowed')::boolean then raise exception '%', acc->>'message'; end if;
  insert into live_viewers (live_id, user_id) values (p_live, auth.uid())
    on conflict (live_id, user_id) do update set last_seen_at = now(), left_at = null;
  n := _live_recount(p_live);
  return jsonb_build_object('viewers', n, 'room', l.room_name, 'host', l.host_id);
end $$;

-- Messages, réactions et cadeaux : un membre sans accès ne peut pas écrire dans un live privé ou à billet.
create or replace function _live_message_access() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.user_id is not null and _live_access(new.live_id, new.user_id) <> 'ok' then
    raise exception 'Vous n''avez pas accès à ce live';
  end if;
  return new;
end $$;
revoke all on function _live_message_access() from public, anon, authenticated;
drop trigger if exists trg_live_message_access on live_messages;
create trigger trg_live_message_access before insert on live_messages for each row execute function _live_message_access();

-- Lecture : les lives privés ne sont visibles que de l'hôte, des invités et de la modération ; le fil d'un live à billet, que de ceux qui y ont accès.
drop policy if exists "lives visibles" on lives;
create policy "lives visibles" on lives for select
  using (host_id = auth.uid() or (status <> 'cancelled' and (visibilite = 'public' or _live_invited(id))));
drop policy if exists "messages de live visibles" on live_messages;
-- La politique s'exécute avec les droits de l'appelant : elle passe par une enveloppe exécutable qui n'évalue QUE l'accès de l'appelant (jamais celui d'un tiers).
create or replace function _live_can_read(p_live uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select _live_is_open(p_live) or _live_access(p_live, auth.uid()) = 'ok'
$$;
revoke all on function _live_can_read(uuid) from public;
grant execute on function _live_can_read(uuid) to anon, authenticated;
create policy "messages de live visibles" on live_messages for select
  using (not hidden and _live_can_read(live_id));

create or replace function lives_now(p_limit integer default 30)
returns table (id uuid, host_id uuid, host text, host_avatar text, host_verified boolean, title text, description text, cover_path text, status text, scheduled_at timestamptz, started_at timestamptz, viewer_count integer)
language sql stable security definer set search_path = public as $$
  select l.id, l.host_id, _live_author(l.host_id), a.avatar_url, a.certification::text = 'approved', l.title, l.description, l.cover_path, l.status, l.scheduled_at, l.started_at, l.viewer_count
  from lives l join profiles a on a.id = l.host_id and not a.suspended
  where (l.status = 'live' or (l.status = 'scheduled' and l.scheduled_at is not null and l.scheduled_at > now() - interval '3 hours'))
    and (l.visibilite = 'public' or l.host_id = auth.uid() or _live_invited(l.id))
  order by (l.status = 'live') desc, coalesce(l.started_at, l.scheduled_at, l.created_at) desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;

create or replace function lives_agenda(p_scope text default 'all', p_limit integer default 60) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); s text := coalesce(nullif(btrim(p_scope), ''), 'all');
begin
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', l.id, 'title', l.title, 'description', l.description, 'status', l.status, 'scheduled_at', l.scheduled_at, 'started_at', l.started_at,
      'host', _live_author(l.host_id), 'host_id', l.host_id, 'viewer_count', l.viewer_count,
      'live_type', l.live_type, 'visibilite', l.visibilite, 'event_id', l.event_id,
      'remind', uid is not null and exists (select 1 from live_reminders r where r.live_id = l.id and r.user_id = uid),
      'mine', uid is not null and l.host_id = uid)
      order by (l.status = 'live') desc, l.scheduled_at asc nulls last)
    from (
      select l.* from lives l join profiles a on a.id = l.host_id and not coalesce(a.suspended, false)
      where (l.status = 'live'
          or (l.status = 'scheduled' and l.scheduled_at is not null and l.scheduled_at > now() - interval '3 hours'))
        and (l.visibilite = 'public' or l.host_id = uid or _live_invited(l.id))
        and (s not in ('today') or l.status = 'live' or (l.scheduled_at at time zone 'Africa/Douala')::date = (now() at time zone 'Africa/Douala')::date)
        and (s <> 'week' or l.status = 'live' or l.scheduled_at < now() + interval '7 days')
        and (s <> 'live' or l.status = 'live')
        and (s <> 'mine' or (uid is not null and exists (select 1 from live_reminders r where r.live_id = l.id and r.user_id = uid)))
      order by (l.status = 'live') desc, l.scheduled_at asc nulls last
      limit least(greatest(coalesce(p_limit, 60), 1), 100)) l), '[]'::jsonb);
end $$;

create or replace function live_get(p_live uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', l.id, 'host_id', l.host_id, 'host', _live_author(l.host_id), 'host_avatar', a.avatar_url, 'host_verified', a.certification::text = 'approved',
    'title', l.title, 'description', l.description, 'cover_path', l.cover_path, 'status', l.status, 'room', l.room_name, 'viewer_count', l.viewer_count,
    'peak_viewers', l.peak_viewers, 'started_at', l.started_at, 'mine', l.host_id = auth.uid(),
    'live_type', l.live_type, 'visibilite', l.visibilite, 'event_id', l.event_id, 'mission_id', l.mission_id, 'opportunity_id', l.opportunity_id,
    'access', case when auth.uid() is null then 'connexion' else _live_access(l.id, auth.uid()) end)
  from lives l join profiles a on a.id = l.host_id
  where l.id = p_live and l.status <> 'cancelled' and (l.visibilite = 'public' or l.host_id = auth.uid() or _live_invited(l.id))
$$;

grant execute on function lives_now(integer), live_get(uuid), lives_agenda(text, integer) to anon, authenticated;
revoke all on function join_live(uuid) from public, anon;
grant execute on function join_live(uuid) to authenticated;
