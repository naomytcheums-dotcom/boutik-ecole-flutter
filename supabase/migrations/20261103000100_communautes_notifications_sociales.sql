-- Communautés (publiques, privées sur approbation, privées sur invitation), publications texte, notifications sociales.
-- NON APPLIQUÉE en production : testée seulement sur la base locale isolée (supabase/tests/communautes_local.sql).
-- Réutilise `profiles` (membres), `posts` (publications : colonne community_id + type texte), `notifications` (événements réels :
-- le déclencheur enqueue_notification existant alimente déjà la file d'envoi, aucun envoi réel n'est branché) et `engagements`
-- (abonnements : le suivi crée une notification au suivi). Aucune écriture directe : tout passe par des fonctions qui vérifient auth.uid().
-- Retour arrière (manuel) : drop des déclencheurs et fonctions ci-dessous ; drop table community_members, communities ;
-- alter table posts drop column community_id, kind, body ; remettre media_path et media_kind en not null ; recréer la politique
-- « publications visibles » et reels_feed de 20261103000000.

create table if not exists communities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 3 and 60),
  description text not null default '' check (char_length(description) <= 500),
  category text not null default '' check (char_length(category) <= 40),
  rules text not null default '' check (char_length(rules) <= 1000),
  logo_path text check (logo_path is null or char_length(logo_path) between 5 and 300),
  cover_path text check (cover_path is null or char_length(cover_path) between 5 and 300),
  privacy text not null default 'public' check (privacy in ('public', 'approval', 'invite')),
  status text not null default 'active' check (status in ('active', 'suspended')),
  owner_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create unique index if not exists communities_name_unique on communities (lower(btrim(name)));

create table if not exists community_members (
  community_id uuid not null references communities(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'moderator', 'member')),
  status text not null default 'active' check (status in ('active', 'pending', 'invited', 'banned')),
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index if not exists community_members_user on community_members (user_id);

-- publications : texte et appartenance à une communauté (les reels restent des publications « media »)
alter table posts add column if not exists kind text not null default 'media' check (kind in ('media', 'text'));
alter table posts add column if not exists body text check (body is null or char_length(body) <= 2000);
alter table posts add column if not exists community_id uuid references communities(id) on delete set null;
alter table posts alter column media_path drop not null;
alter table posts alter column media_kind drop not null;
alter table posts drop constraint if exists posts_kind_contenu;
alter table posts add constraint posts_kind_contenu check (
  (kind = 'media' and media_path is not null and media_kind is not null) or (kind = 'text' and nullif(btrim(coalesce(body, '')), '') is not null));
create index if not exists posts_community on posts (community_id, status, published_at desc);

-- ---------------------------------------------------------------- aides de lecture (security definer : pas de récursion de politique)
create or replace function is_community_member(p_community uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from community_members where community_id = p_community and user_id = auth.uid() and status = 'active')
$$;
create or replace function community_rank(p_community uuid, p_user uuid) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((select case role when 'owner' then 4 when 'admin' then 3 when 'moderator' then 2 else 1 end
                   from community_members where community_id = p_community and user_id = p_user and status = 'active'), 0)
$$;
create or replace function is_platform_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name()::text, '') in ('admin', 'support')
$$;
revoke all on function is_community_member(uuid), community_rank(uuid, uuid), is_platform_staff() from public, anon;
grant execute on function is_community_member(uuid), community_rank(uuid, uuid), is_platform_staff() to authenticated;
-- les politiques de lecture les appellent aussi pour les visiteurs (ils renvoient faux : auth.uid() est nul)
grant execute on function is_community_member(uuid), is_platform_staff() to anon;

alter table communities enable row level security;
alter table community_members enable row level security;
revoke all on communities, community_members from anon, authenticated;
grant select on communities, community_members to authenticated;
grant select on communities to anon;

drop policy if exists "communautés visibles" on communities;
create policy "communautés visibles" on communities for select
  using (status = 'active' and (privacy in ('public', 'approval') or is_community_member(id) or owner_id = auth.uid()) or is_platform_staff());
drop policy if exists "membres : soi-même et co-membres" on community_members;
create policy "membres : soi-même et co-membres" on community_members for select
  using (user_id = auth.uid() or (status = 'active' and is_community_member(community_id)) or is_platform_staff());

-- Publications : une publication de communauté privée n'est visible que par ses membres actifs.
drop policy if exists "publications visibles" on posts;
create policy "publications visibles" on posts for select
  using (
    (status = 'published' and (community_id is null
        or exists (select 1 from communities c where c.id = community_id and c.privacy = 'public' and c.status = 'active')
        or is_community_member(community_id)))
    or author_id = auth.uid()
    or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support')
  );

-- ---------------------------------------------------------------- notifications d'événements réels
create or replace function notify_user(p_user uuid, p_kind text, p_title text, p_body text, p_data jsonb) returns void
language sql security definer set search_path = public as $$
  insert into notifications (user_id, kind, title, body, data) select p_user, p_kind, p_title, left(p_body, 500), coalesce(p_data, '{}'::jsonb)
  where p_user is not null and p_user <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
$$;
revoke all on function notify_user(uuid, text, text, text, jsonb) from public, anon, authenticated;

create or replace function display_name(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim(split_part(name, ' ', 1) || ' ' || case when split_part(name, ' ', 2) <> '' then left(split_part(name, ' ', 2), 1) || '.' else '' end), ''), 'Un membre')
  from profiles where id = p_user
$$;
revoke all on function display_name(uuid) from public, anon;
grant execute on function display_name(uuid) to authenticated;

-- nouveau commentaire : notification à l'auteur de la publication (jamais à soi-même)
create or replace function trg_notify_comment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  select author_id into v_author from posts where id = new.post_id;
  perform notify_user(v_author, 'comment', 'Nouveau commentaire', display_name(new.author_id) || ' a commenté votre publication.', jsonb_build_object('post', new.post_id, 'comment', new.id));
  return null;
end $$;
drop trigger if exists notify_comment on post_comments;
create trigger notify_comment after insert on post_comments for each row execute function trg_notify_comment();

-- nouvel abonné (engagements.kind = 'follow', ref = identifiant du profil suivi)
create or replace function trg_notify_follow() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_target uuid;
begin
  if new.kind <> 'follow' or new.status <> 'active' then return null; end if;
  begin v_target := new.ref::uuid; exception when others then return null; end;
  if v_target = new.user_id or not exists (select 1 from profiles where id = v_target) then return null; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return null; end if;
  insert into notifications (user_id, kind, title, body, data)
    values (v_target, 'follow', 'Nouvel abonné', display_name(new.user_id) || ' vous suit.', jsonb_build_object('user', new.user_id));
  return null;
end $$;
drop trigger if exists notify_follow on engagements;
create trigger notify_follow after insert or update on engagements for each row execute function trg_notify_follow();

-- ---------------------------------------------------------------- fonctions de communauté
create or replace function create_community(p_name text, p_description text default '', p_category text default '', p_privacy text default 'public', p_rules text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Complétez votre profil avant cette action'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if (select count(*) from communities where owner_id = auth.uid()) >= 5 then raise exception 'Vous ne pouvez pas créer plus de 5 communautés'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, category, rules, privacy, owner_id)
    values (btrim(p_name), coalesce(p_description, ''), coalesce(p_category, ''), coalesce(p_rules, ''), p_privacy, auth.uid()) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  return v_id;
end $$;

create or replace function join_community(p_community uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c communities%rowtype; m community_members%rowtype; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from communities where id = p_community and status = 'active';
  if not found then raise exception 'Communauté introuvable'; end if;
  select * into m from community_members where community_id = p_community and user_id = auth.uid();
  if found then
    if m.status = 'banned' then raise exception 'Accès refusé à cette communauté'; end if;
    if m.status = 'active' then return 'already'; end if;
    if m.status = 'pending' then return 'pending'; end if;
    update community_members set status = 'active' where community_id = p_community and user_id = auth.uid(); -- invitation acceptée
    return 'joined';
  end if;
  if c.privacy = 'invite' then raise exception 'Cette communauté est accessible sur invitation seulement'; end if;
  if c.privacy = 'approval' then
    insert into community_members (community_id, user_id, role, status) values (p_community, auth.uid(), 'member', 'pending');
    for r in select user_id from community_members where community_id = p_community and status = 'active' and role in ('owner', 'admin', 'moderator') loop
      perform notify_user(r.user_id, 'community_request', 'Demande d’adhésion', display_name(auth.uid()) || ' demande à rejoindre « ' || c.name || ' ».', jsonb_build_object('community', p_community, 'user', auth.uid()));
    end loop;
    return 'pending';
  end if;
  insert into community_members (community_id, user_id, role, status) values (p_community, auth.uid(), 'member', 'active');
  return 'joined';
end $$;

create or replace function leave_community(p_community uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from community_members where community_id = p_community and user_id = auth.uid() and role = 'owner') then
    raise exception 'Le propriétaire ne peut pas quitter la communauté';
  end if;
  -- un membre banni reste banni : on ne supprime que les autres états
  delete from community_members where community_id = p_community and user_id = auth.uid() and status <> 'banned';
  return 'left';
end $$;

create or replace function decide_join_request(p_community uuid, p_user uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c communities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  select * into c from communities where id = p_community;
  if not found then raise exception 'Communauté introuvable'; end if;
  if not exists (select 1 from community_members where community_id = p_community and user_id = p_user and status = 'pending') then raise exception 'Aucune demande en attente'; end if;
  if p_accept then
    update community_members set status = 'active' where community_id = p_community and user_id = p_user;
    perform notify_user(p_user, 'community_accept', 'Demande acceptée', 'Vous avez rejoint « ' || c.name || ' ».', jsonb_build_object('community', p_community));
    return 'accepted';
  end if;
  delete from community_members where community_id = p_community and user_id = p_user and status = 'pending';
  perform notify_user(p_user, 'community_reject', 'Demande refusée', 'Votre demande pour « ' || c.name || ' » n’a pas été acceptée.', jsonb_build_object('community', p_community));
  return 'rejected';
end $$;

create or replace function invite_member(p_community uuid, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c communities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 then raise exception 'Action non autorisée'; end if;
  select * into c from communities where id = p_community and status = 'active';
  if not found then raise exception 'Communauté introuvable'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'Profil introuvable'; end if;
  if exists (select 1 from community_members where community_id = p_community and user_id = p_user) then raise exception 'Cette personne est déjà liée à la communauté'; end if;
  insert into community_members (community_id, user_id, role, status) values (p_community, p_user, 'member', 'invited');
  perform notify_user(p_user, 'community_invite', 'Invitation', display_name(auth.uid()) || ' vous invite à rejoindre « ' || c.name || ' ».', jsonb_build_object('community', p_community));
  return 'invited';
end $$;

create or replace function set_member_role(p_community uuid, p_user uuid, p_role text) returns text
language plpgsql security definer set search_path = public as $$
declare mine integer; theirs integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_role not in ('admin', 'moderator', 'member') then raise exception 'Rôle inconnu'; end if;
  mine := community_rank(p_community, auth.uid()); theirs := community_rank(p_community, p_user);
  if mine < 3 then raise exception 'Action non autorisée'; end if;
  if theirs = 0 then raise exception 'Cette personne n''est pas membre'; end if;
  if theirs >= mine then raise exception 'Vous ne pouvez pas modifier le rôle d''un rang égal ou supérieur'; end if;
  if p_role = 'admin' and mine < 4 then raise exception 'Seul le propriétaire nomme un administrateur'; end if;
  update community_members set role = p_role where community_id = p_community and user_id = p_user;
  return p_role;
end $$;

create or replace function ban_member(p_community uuid, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare mine integer; theirs integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  mine := community_rank(p_community, auth.uid()); theirs := community_rank(p_community, p_user);
  if mine < 2 then raise exception 'Action non autorisée'; end if;
  if theirs >= mine then raise exception 'Vous ne pouvez pas bannir un rang égal ou supérieur'; end if;
  insert into community_members (community_id, user_id, role, status) values (p_community, p_user, 'member', 'banned')
    on conflict (community_id, user_id) do update set status = 'banned', role = 'member';
  return 'banned';
end $$;

create or replace function create_community_post(p_community uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 2000 then raise exception 'La publication doit contenir entre 1 et 2000 caractères'; end if;
  if (select count(*) from posts where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de publications en peu de temps. Réessayez dans une minute.'; end if;
  insert into posts (author_id, kind, body, community_id, status, published_at) values (auth.uid(), 'text', btrim(p_body), p_community, 'published', now()) returning id into v_id;
  return v_id;
end $$;

create or replace function moderate_community_post(p_post uuid, p_hide boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_comm uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select community_id into v_comm from posts where id = p_post and kind = 'text';
  if v_comm is null then raise exception 'Publication introuvable'; end if;
  if community_rank(v_comm, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  update posts set status = case when p_hide then 'hidden' else 'published' end, review_note = case when p_hide then 'Masquée par la modération de la communauté' else null end where id = p_post;
  return case when p_hide then 'hidden' else 'published' end;
end $$;

-- annuaire : communautés publiques et sur approbation, avec le nombre de membres et mon état
create or replace function communities_list(p_query text default '', p_limit integer default 30)
returns table (id uuid, name text, description text, category text, privacy text, members integer, my_status text, my_role text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.category, c.privacy,
         (select count(*)::int from community_members m where m.community_id = c.id and m.status = 'active'),
         (select m.status from community_members m where m.community_id = c.id and m.user_id = auth.uid()),
         (select m.role from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status = 'active')
  from communities c
  where c.status = 'active'
    and (c.privacy in ('public', 'approval') or exists (select 1 from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status in ('active', 'invited')))
    and (coalesce(btrim(p_query), '') = '' or c.name ilike '%' || btrim(p_query) || '%' or c.category ilike '%' || btrim(p_query) || '%')
  order by 6 desc, c.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;

create or replace function community_feed(p_community uuid, p_limit integer default 30)
returns table (id uuid, author text, author_id uuid, body text, published_at timestamptz, mine boolean)
language sql stable security definer set search_path = public as $$
  select p.id, display_name(p.author_id), p.author_id, p.body, p.published_at, p.author_id = auth.uid()
  from posts p join communities c on c.id = p.community_id
  where p.community_id = p_community and p.kind = 'text' and p.status = 'published' and c.status = 'active'
    and (c.privacy = 'public' or is_community_member(c.id) or is_platform_staff())
  order by p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;

create or replace function community_requests(p_community uuid)
returns table (user_id uuid, name text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select m.user_id, display_name(m.user_id), m.created_at from community_members m
  where m.community_id = p_community and m.status = 'pending' and (community_rank(p_community, auth.uid()) >= 2 or is_platform_staff())
  order by m.created_at
$$;

-- reels_feed : seulement les publications média hors communauté privée
create or replace function reels_feed(p_limit integer default 20)
returns table (id uuid, author text, media_path text, media_kind text, caption text, tags text[], listing_title text, likes integer, liked boolean, boosted boolean, published_at timestamptz,
               author_id uuid, comments integer, saves integer, shares integer, saved boolean)
language sql stable security definer set search_path = public as $$
  select p.id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         p.media_path, p.media_kind, p.caption, p.tags, l.title,
         (select count(*)::int from post_likes k where k.post_id = p.id),
         exists (select 1 from post_likes k where k.post_id = p.id and k.user_id = auth.uid()),
         exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at),
         p.published_at, p.author_id,
         (select count(*)::int from post_comments c where c.post_id = p.id and c.status = 'visible'),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid())
  from posts p join profiles a on a.id = p.author_id left join listings l on l.id = p.listing_id and l.status = 'approved'
  where p.status = 'published' and p.kind = 'media' and p.community_id is null
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;
grant execute on function reels_feed(integer) to anon;

grant execute on function communities_list(text, integer) to anon, authenticated;
revoke all on function create_community(text, text, text, text, text), join_community(uuid), leave_community(uuid), decide_join_request(uuid, uuid, boolean),
  invite_member(uuid, uuid), set_member_role(uuid, uuid, text), ban_member(uuid, uuid), create_community_post(uuid, text), moderate_community_post(uuid, boolean),
  community_feed(uuid, integer), community_requests(uuid) from public, anon;
grant execute on function create_community(text, text, text, text, text), join_community(uuid), leave_community(uuid), decide_join_request(uuid, uuid, boolean),
  invite_member(uuid, uuid), set_member_role(uuid, uuid, text), ban_member(uuid, uuid), create_community_post(uuid, text), moderate_community_post(uuid, boolean),
  community_feed(uuid, integer), community_requests(uuid) to authenticated;
