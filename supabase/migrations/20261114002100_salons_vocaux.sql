-- Salons vocaux (« Live Étude ») d'une communauté : micro, écoute, partage d'écran et tableau blanc.
-- Ce fichier ne gère que l'existence des salons et leur accès (membres seulement) ; le son, l'écran et le tableau passent directement entre les appareils
-- (WebRTC, signalisation par Supabase Realtime) : aucune clé de service tierce n'est nécessaire.
-- Retour arrière : drop function study_room_create(uuid, text, text), study_room_close(uuid), study_rooms_list(uuid), study_room_enter(uuid); drop table study_rooms.

create table if not exists study_rooms (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  host_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 80),
  topic text not null default '' check (char_length(topic) <= 200),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);
create index if not exists study_rooms_open on study_rooms (community_id) where status = 'open';
alter table study_rooms enable row level security;
revoke all on study_rooms from anon, authenticated;

-- Un salon oublié ouvert se ferme tout seul après 12 heures.
create or replace function study_rooms_sweep() returns void
language sql security definer set search_path = public as $$
  update study_rooms set status = 'closed', closed_at = now() where status = 'open' and created_at < now() - interval '12 hours'
$$;
revoke all on function study_rooms_sweep() from public, anon, authenticated;

create or replace function study_room_create(p_community uuid, p_title text, p_topic text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if not exists (select 1 from communities where id = p_community and status = 'active') then raise exception 'Communauté indisponible'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Donnez un titre au salon (3 lettres au moins)'; end if;
  perform study_rooms_sweep();
  if (select count(*) from study_rooms where community_id = p_community and status = 'open') >= 3 then raise exception 'Trois salons ouverts au plus : fermez-en un d''abord'; end if;
  insert into study_rooms (community_id, host_id, title, topic) values (p_community, auth.uid(), left(btrim(p_title), 80), left(btrim(coalesce(p_topic, '')), 200)) returning id into v_id;
  select name into v_name from communities where id = p_community;
  insert into notifications (user_id, kind, title, body, data)
    select m.user_id, 'study_room', 'Salon vocal ouvert', display_name(auth.uid()) || ' ouvre « ' || left(btrim(p_title), 80) || ' » dans « ' || v_name || ' ».', jsonb_build_object('community', p_community, 'room', v_id)
    from community_members m where m.community_id = p_community and m.status = 'active' and m.user_id <> auth.uid();
  return v_id;
end $$;

create or replace function study_room_close(p_room uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r study_rooms%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into r from study_rooms where id = p_room and status = 'open';
  if not found then raise exception 'Salon introuvable ou déjà fermé'; end if;
  if r.host_id <> auth.uid() and community_rank(r.community_id, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Seul l''organisateur ou un responsable ferme le salon'; end if;
  update study_rooms set status = 'closed', closed_at = now() where id = p_room;
end $$;

create or replace function study_rooms_list(p_community uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) and not is_platform_staff() then raise exception 'Réservé aux membres de la communauté'; end if;
  perform study_rooms_sweep();
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'title', r.title, 'topic', r.topic, 'host_id', r.host_id, 'host', display_name(r.host_id), 'created_at', r.created_at,
      'mine', r.host_id = auth.uid(), 'can_close', r.host_id = auth.uid() or community_rank(r.community_id, auth.uid()) >= 2 or is_platform_staff()) order by r.created_at desc)
    from study_rooms r where r.community_id = p_community and r.status = 'open'), '[]'::jsonb);
end $$;

-- Entrée dans un salon : membres de la communauté seulement, salon ouvert. Renvoie ce qu'il faut pour se connecter (nom affiché compris).
create or replace function study_room_enter(p_room uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r study_rooms%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform study_rooms_sweep();
  select * into r from study_rooms where id = p_room and status = 'open';
  if not found then raise exception 'Ce salon est fermé'; end if;
  if not is_community_member(r.community_id) then raise exception 'Réservé aux membres de la communauté'; end if;
  return jsonb_build_object('id', r.id, 'title', r.title, 'topic', r.topic, 'community_id', r.community_id, 'host_id', r.host_id, 'self_id', auth.uid(), 'name', display_name(auth.uid()),
    'can_close', r.host_id = auth.uid() or community_rank(r.community_id, auth.uid()) >= 2);
end $$;

revoke all on function study_room_create(uuid, text, text), study_room_close(uuid), study_rooms_list(uuid), study_room_enter(uuid) from public, anon;
grant execute on function study_room_create(uuid, text, text), study_room_close(uuid), study_rooms_list(uuid), study_room_enter(uuid) to authenticated;
