-- Réseau social : publications complètes (texte, plusieurs médias, lien, republication), commentaires avec réponses, mentions j'aime
-- et pièces jointes, histoires de 24 h, badge « certifié » dans les listes, Lives réels (salle, spectateurs, chat, réactions,
-- signalement, bannissement) et cadeaux virtuels (catalogue, crédits, transactions idempotentes, gains des créateurs).
-- ADDITIVE : aucune donnée existante n'est modifiée ni supprimée. Les anciennes fonctions (reels_feed, add_post_comment,
-- post_comment_list, create_post…) restent en place.
-- Règles d'argent : les crédits ne sont JAMAIS créés par l'application ; seul le service serveur (grant_credits, rôle service_role,
-- appelé par un webhook de paiement validé) peut en ajouter. Aucun retrait n'est ouvert ici (voir docs/transformation/RESEAU_SOCIAL_LIVE.md).
-- Retour arrière (manuel) : drop des tables/fonctions créées ci-dessous ; les colonnes ajoutées à posts/post_comments peuvent rester.

-- ------------------------------------------------------------------ publications
alter table posts add column if not exists link_url text check (link_url is null or char_length(link_url) <= 500);
alter table posts add column if not exists repost_of uuid references posts(id) on delete set null;
alter table posts drop constraint if exists posts_kind_contenu;
alter table posts add constraint posts_kind_contenu check (
  (kind = 'media' and media_path is not null and media_kind is not null)
  or (kind = 'text' and (nullif(btrim(coalesce(body, '')), '') is not null or link_url is not null or repost_of is not null)));

create table if not exists post_media (
  post_id uuid not null references posts(id) on delete cascade,
  pos smallint not null check (pos between 0 and 9),
  path text not null check (char_length(path) between 5 and 300),
  kind text not null check (kind in ('image', 'video')),
  width integer check (width is null or width between 1 and 20000),
  height integer check (height is null or height between 1 and 20000),
  primary key (post_id, pos)
);
alter table post_media enable row level security;
revoke all on post_media from anon, authenticated;

create or replace function profile_verified(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select certification::text = 'approved' from profiles where id = p_user), false)
$$;
grant execute on function profile_verified(uuid) to anon, authenticated;

-- p_media : [{"path":"<uid>/x.jpg","kind":"image","w":1200,"h":800}, …] (10 au plus, tous déposés dans le dossier de la personne)
create or replace function create_post_v2(p_caption text, p_media jsonb, p_link text, p_tags text[], p_listing uuid, p_repost_of uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; pid uuid; st text; m jsonb; i int := 0; n int; first_path text; first_kind text; txt text; lnk text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended or me.role::text not in ('student', 'dept', 'admin') then raise exception 'Publication réservée aux étudiants et au département'; end if;
  p_media := coalesce(p_media, '[]'::jsonb);
  if jsonb_typeof(p_media) <> 'array' then raise exception 'Médias invalides'; end if;
  n := jsonb_array_length(p_media);
  if n > 10 then raise exception '10 médias au plus par publication'; end if;
  txt := left(btrim(coalesce(p_caption, '')), 2000);
  lnk := nullif(btrim(coalesce(p_link, '')), '');
  if lnk is not null and lnk !~* '^https?://[^[:space:]]+$' or char_length(lnk) > 480 then raise exception 'Lien invalide : il doit commencer par http:// ou https://'; end if;
  if n = 0 and txt = '' and lnk is null and p_repost_of is null then raise exception 'Écrivez un texte ou ajoutez un média, un lien ou une republication'; end if;
  if p_repost_of is not null and not exists (select 1 from posts where id = p_repost_of and status = 'published') then raise exception 'Publication à republier introuvable'; end if;
  if p_listing is not null and not exists (select 1 from listings where id = p_listing and seller_id = auth.uid() and status = 'approved') then
    raise exception 'Le lien « Boutique » ne peut viser qu''une de vos annonces validées';
  end if;
  for m in select * from jsonb_array_elements(p_media) loop
    if split_part(coalesce(m->>'path', ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
    if coalesce(m->>'kind', '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  end loop;
  if n > 0 then
    first_path := p_media->0->>'path';
    first_kind := p_media->0->>'kind';
  end if;
  st := case when me.certification = 'approved' or me.role::text in ('dept', 'admin') then 'published' else 'pending' end;
  insert into posts (author_id, kind, media_path, media_kind, caption, body, link_url, repost_of, tags, listing_id, status, published_at)
    values (auth.uid(), case when n > 0 then 'media' else 'text' end, first_path, first_kind,
            case when n > 0 then left(txt, 300) else '' end, case when n = 0 then nullif(txt, '') end, lnk, p_repost_of,
            coalesce((select array_agg(distinct lower(left(trim(t), 30))) from unnest(coalesce(p_tags, '{}')) t where trim(t) <> ''), '{}'),
            p_listing, st, case when st = 'published' then now() end)
    returning id into pid;
  for m in select * from jsonb_array_elements(p_media) loop
    insert into post_media (post_id, pos, path, kind, width, height)
      values (pid, i, m->>'path', m->>'kind', nullif(m->>'w', '')::int, nullif(m->>'h', '')::int);
    i := i + 1;
  end loop;
  return jsonb_build_object('id', pid, 'status', st);
end $$;

-- Fil du Cercle et des Reels : toutes les publications visibles hors communauté privée, avec auteur certifié, photo, médias et republication.
create or replace function circle_feed(p_limit integer default 30)
returns table (id uuid, kind text, author text, author_id uuid, author_avatar text, author_verified boolean,
               media_path text, media_kind text, caption text, tags text[], listing_title text, link_url text,
               likes integer, liked boolean, boosted boolean, published_at timestamptz,
               comments integer, saves integer, shares integer, saved boolean, reposts integer,
               media jsonb, repost_id uuid, repost_author text, repost_author_id uuid, repost_caption text, repost_media_path text, repost_media_kind text)
language sql stable security definer set search_path = public as $$
  select p.id, p.kind,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         p.author_id, a.avatar_url, a.certification::text = 'approved',
         p.media_path, p.media_kind, case when p.kind = 'text' then coalesce(p.body, '') else p.caption end, p.tags, l.title, p.link_url,
         (select count(*)::int from post_likes k where k.post_id = p.id),
         exists (select 1 from post_likes k where k.post_id = p.id and k.user_id = auth.uid()),
         exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at),
         p.published_at,
         (select count(*)::int from post_comments c where c.post_id = p.id and c.status = 'visible'),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid()),
         (select count(*)::int from posts r where r.repost_of = p.id and r.status = 'published'),
         coalesce((select jsonb_agg(jsonb_build_object('path', pm.path, 'kind', pm.kind, 'w', pm.width, 'h', pm.height) order by pm.pos) from post_media pm where pm.post_id = p.id), '[]'::jsonb),
         rp.id,
         case when rp.id is not null then coalesce(nullif(trim(split_part(ra.name, ' ', 1) || ' ' || case when split_part(ra.name, ' ', 2) <> '' then left(split_part(ra.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant') end,
         rp.author_id,
         case when rp.id is not null then case when rp.kind = 'text' then coalesce(rp.body, '') else rp.caption end end,
         rp.media_path, rp.media_kind
  from posts p
  join profiles a on a.id = p.author_id and not a.suspended
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  left join posts rp on rp.id = p.repost_of and rp.status = 'published'
  left join profiles ra on ra.id = rp.author_id
  where p.status = 'published' and p.community_id is null
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
grant execute on function circle_feed(integer) to anon, authenticated;
revoke all on function create_post_v2(text, jsonb, text, text[], uuid, uuid) from public, anon;
grant execute on function create_post_v2(text, jsonb, text, text[], uuid, uuid) to authenticated;

-- ------------------------------------------------------------------ commentaires : réponses, mentions j'aime, pièce jointe
alter table post_comments add column if not exists attachment_path text check (attachment_path is null or char_length(attachment_path) between 5 and 300);
alter table post_comments add column if not exists attachment_kind text check (attachment_kind is null or attachment_kind in ('image', 'video'));
alter table post_comments drop constraint if exists post_comments_body_check;
alter table post_comments drop constraint if exists post_comments_contenu;
alter table post_comments add constraint post_comments_contenu check (
  char_length(btrim(body)) <= 500 and (char_length(btrim(body)) >= 1 or attachment_path is not null));

create table if not exists comment_likes (
  comment_id uuid not null references post_comments(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
alter table comment_likes enable row level security;
revoke all on comment_likes from anon, authenticated;

create or replace function add_post_comment_v2(p_post uuid, p_body text, p_parent uuid default null, p_attachment_path text default null, p_attachment_kind text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_root uuid := p_parent; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
  if char_length(v_body) > 500 then raise exception 'Le commentaire ne peut dépasser 500 caractères'; end if;
  if v_body = '' and p_attachment_path is null then raise exception 'Écrivez un commentaire ou joignez une image'; end if;
  if p_attachment_path is not null then
    if split_part(p_attachment_path, '/', 1) <> auth.uid()::text then raise exception 'Pièce jointe invalide'; end if;
    if coalesce(p_attachment_kind, '') not in ('image', 'video') then raise exception 'Type de pièce jointe invalide'; end if;
  end if;
  if p_parent is not null then
    select coalesce(c.parent_id, c.id) into v_root from post_comments c where c.id = p_parent and c.post_id = p_post and c.status = 'visible';
    if v_root is null then raise exception 'Commentaire parent introuvable'; end if;
  end if;
  if (select count(*) from post_comments where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 10 then
    raise exception 'Trop de commentaires en peu de temps. Réessayez dans une minute.';
  end if;
  insert into post_comments (post_id, author_id, parent_id, body, attachment_path, attachment_kind)
    values (p_post, auth.uid(), v_root, v_body, p_attachment_path, case when p_attachment_path is not null then p_attachment_kind end) returning id into v_id;
  return v_id;
end $$;

create or replace function post_comment_list_v2(p_post uuid, p_limit integer default 100)
returns table (id uuid, parent_id uuid, author text, author_id uuid, author_avatar text, author_verified boolean, mine boolean, body text, created_at timestamptz,
               likes integer, liked boolean, attachment_path text, attachment_kind text)
language sql stable security definer set search_path = public as $$
  select c.id, c.parent_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         c.author_id, a.avatar_url, a.certification::text = 'approved', c.author_id = auth.uid(), c.body, c.created_at,
         (select count(*)::int from comment_likes k where k.comment_id = c.id),
         exists (select 1 from comment_likes k where k.comment_id = c.id and k.user_id = auth.uid()),
         c.attachment_path, c.attachment_kind
  from post_comments c join profiles a on a.id = c.author_id join posts p on p.id = c.post_id
  where c.post_id = p_post and c.status = 'visible' and p.status = 'published'
  order by c.created_at
  limit least(greatest(coalesce(p_limit, 100), 1), 300)
$$;

create or replace function toggle_comment_like(p_comment uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from post_comments where id = p_comment and status = 'visible') then raise exception 'Commentaire introuvable'; end if;
  if exists (select 1 from comment_likes where comment_id = p_comment and user_id = auth.uid()) then
    delete from comment_likes where comment_id = p_comment and user_id = auth.uid();
    return false;
  end if;
  insert into comment_likes (comment_id, user_id) values (p_comment, auth.uid());
  return true;
end $$;
grant execute on function post_comment_list_v2(uuid, integer) to anon, authenticated;
revoke all on function add_post_comment_v2(uuid, text, uuid, text, text), toggle_comment_like(uuid) from public, anon;
grant execute on function add_post_comment_v2(uuid, text, uuid, text, text), toggle_comment_like(uuid) to authenticated;

-- ------------------------------------------------------------------ histoires (24 h)
create table if not exists stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  media_path text not null check (char_length(media_path) between 5 and 300),
  media_kind text not null check (media_kind in ('image', 'video')),
  caption text not null default '' check (char_length(caption) <= 200),
  status text not null default 'visible' check (status in ('visible', 'hidden')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create index if not exists stories_actives on stories (expires_at, author_id);
create table if not exists story_views (
  story_id uuid not null references stories(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
alter table stories enable row level security;
alter table story_views enable row level security;
revoke all on stories, story_views from anon, authenticated;

create or replace function create_story(p_path text, p_kind text, p_caption text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; sid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended or me.role::text not in ('student', 'dept', 'admin') then raise exception 'Histoires réservées aux étudiants et au département'; end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  if coalesce(p_kind, '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  if (select count(*) from stories where author_id = auth.uid() and created_at > now() - interval '24 hours') >= 30 then raise exception '30 histoires par jour au plus'; end if;
  insert into stories (author_id, media_path, media_kind, caption) values (auth.uid(), p_path, p_kind, left(btrim(coalesce(p_caption, '')), 200)) returning id into sid;
  return sid;
end $$;

-- Histoires actives (24 h) : toutes, ou celles d'une personne. `seen` : déjà vue par la personne connectée.
create or replace function stories_active(p_author uuid default null)
returns table (id uuid, author_id uuid, author text, author_avatar text, author_verified boolean, media_path text, media_kind text, caption text, created_at timestamptz, seen boolean)
language sql stable security definer set search_path = public as $$
  select s.id, s.author_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         a.avatar_url, a.certification::text = 'approved', s.media_path, s.media_kind, s.caption, s.created_at,
         exists (select 1 from story_views v where v.story_id = s.id and v.user_id = auth.uid())
  from stories s join profiles a on a.id = s.author_id and not a.suspended
  where s.status = 'visible' and s.expires_at > now() and (p_author is null or s.author_id = p_author)
  order by s.author_id, s.created_at
  limit 300
$$;
create or replace function mark_story_seen(p_story uuid) returns void
language sql security definer set search_path = public as $$
  insert into story_views (story_id, user_id) select p_story, auth.uid() where auth.uid() is not null and exists (select 1 from stories where id = p_story and status = 'visible' and expires_at > now())
  on conflict do nothing
$$;
create or replace function hide_story(p_story uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from stories where id = p_story and author_id = auth.uid()) then
    delete from stories where id = p_story; return 'supprimée';
  end if;
  if coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then update stories set status = 'hidden' where id = p_story; return 'masquée'; end if;
  raise exception 'Action non autorisée';
end $$;
grant execute on function stories_active(uuid) to anon, authenticated;
revoke all on function create_story(text, text, text), mark_story_seen(uuid), hide_story(uuid) from public, anon;
grant execute on function create_story(text, text, text), mark_story_seen(uuid), hide_story(uuid) to authenticated;

-- ------------------------------------------------------------------ Lives
create table if not exists lives (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 100),
  description text not null default '' check (char_length(description) <= 500),
  cover_path text check (cover_path is null or char_length(cover_path) between 5 and 300),
  status text not null default 'scheduled' check (status in ('scheduled', 'live', 'ended', 'cancelled')),
  room_name text not null unique default ('live-' || replace(gen_random_uuid()::text, '-', '')),
  scheduled_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  viewer_count integer not null default 0,
  peak_viewers integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists lives_statut on lives (status, started_at desc);
create unique index if not exists lives_un_en_cours_par_hote on lives (host_id) where status = 'live';

create table if not exists live_viewers (
  live_id uuid not null references lives(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (live_id, user_id)
);
create table if not exists live_messages (
  id bigint generated always as identity primary key,
  live_id uuid not null references lives(id) on delete cascade,
  user_id uuid references profiles(id) on delete set null,
  author text not null default '',
  kind text not null check (kind in ('chat', 'reaction', 'gift', 'system')),
  body text not null default '' check (char_length(body) <= 300),
  payload jsonb not null default '{}',
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists live_messages_fil on live_messages (live_id, id);
create table if not exists live_bans (
  live_id uuid not null references lives(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  by_user uuid references profiles(id),
  created_at timestamptz not null default now(),
  primary key (live_id, user_id)
);
create table if not exists live_reports (
  id uuid primary key default gen_random_uuid(),
  live_id uuid not null references lives(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  message_id bigint references live_messages(id) on delete set null,
  reason text not null check (char_length(btrim(reason)) between 3 and 300),
  created_at timestamptz not null default now()
);
create unique index if not exists live_reports_unique on live_reports (live_id, reporter_id, coalesce(message_id, 0));

alter table lives enable row level security;
alter table live_viewers enable row level security;
alter table live_messages enable row level security;
alter table live_bans enable row level security;
alter table live_reports enable row level security;
revoke all on lives, live_viewers, live_messages, live_bans, live_reports from anon, authenticated;
grant select on lives, live_messages to anon, authenticated;
drop policy if exists "lives visibles" on lives;
create policy "lives visibles" on lives for select using (status <> 'cancelled' or host_id = auth.uid());
drop policy if exists "messages de live visibles" on live_messages;
create policy "messages de live visibles" on live_messages for select
  using (not hidden and exists (select 1 from lives l where l.id = live_id and l.status <> 'cancelled'));

create or replace function _live_recount(p_live uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  select count(*)::int into n from live_viewers where live_id = p_live and left_at is null and last_seen_at > now() - interval '90 seconds';
  update lives set viewer_count = n, peak_viewers = greatest(peak_viewers, n) where id = p_live and (viewer_count <> n or peak_viewers < n);
  return n;
end $$;
revoke all on function _live_recount(uuid) from public, anon, authenticated;

create or replace function _live_author(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(trim(split_part(name, ' ', 1) || ' ' || case when split_part(name, ' ', 2) <> '' then left(split_part(name, ' ', 2), 1) || '.' else '' end), ''), 'Un membre') from profiles where id = p_user
$$;
revoke all on function _live_author(uuid) from public, anon, authenticated;

create or replace function create_live(p_title text, p_description text default '', p_cover_path text default null, p_scheduled_at timestamptz default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; lid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended or me.role::text not in ('student', 'dept', 'admin') then raise exception 'Les Lives sont réservés aux étudiants et au département'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 100 then raise exception 'Le titre doit contenir entre 3 et 100 caractères'; end if;
  if p_cover_path is not null and split_part(p_cover_path, '/', 1) <> auth.uid()::text then raise exception 'Couverture invalide : déposez-la d''abord dans votre dossier'; end if;
  if (select count(*) from lives where host_id = auth.uid() and status = 'scheduled') >= 10 then raise exception '10 lives programmés au plus'; end if;
  insert into lives (host_id, title, description, cover_path, scheduled_at) values (auth.uid(), btrim(p_title), left(btrim(coalesce(p_description, '')), 500), p_cover_path, p_scheduled_at) returning id into lid;
  return lid;
end $$;

-- Démarrage : le live passe « en direct » et les abonnés actifs reçoivent une notification (500 au plus).
create or replace function start_live(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; f record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live for update;
  if not found or l.host_id <> auth.uid() then raise exception 'Live introuvable'; end if;
  if l.status = 'live' then return l.room_name; end if;
  if l.status <> 'scheduled' then raise exception 'Ce live est terminé'; end if;
  if exists (select 1 from lives where host_id = auth.uid() and status = 'live') then raise exception 'Vous avez déjà un live en cours'; end if;
  update lives set status = 'live', started_at = now() where id = p_live;
  insert into live_messages (live_id, kind, body) values (p_live, 'system', 'Le live a commencé.');
  for f in select user_id from engagements where kind = 'follow' and ref = auth.uid()::text and status = 'active' limit 500 loop
    perform notify_user(f.user_id, 'live', 'Live en direct', _live_author(auth.uid()) || ' est en direct : ' || l.title, jsonb_build_object('live', p_live, 'host', auth.uid()));
  end loop;
  return l.room_name;
end $$;

create or replace function end_live(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live for update;
  if not found then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Action non autorisée'; end if;
  if l.status in ('ended', 'cancelled') then return l.status; end if;
  update lives set status = case when l.status = 'scheduled' then 'cancelled' else 'ended' end, ended_at = now(), viewer_count = 0 where id = p_live;
  update live_viewers set left_at = now() where live_id = p_live and left_at is null;
  if l.status = 'live' then insert into live_messages (live_id, kind, body) values (p_live, 'system', 'Le live est terminé.'); end if;
  return case when l.status = 'scheduled' then 'cancelled' else 'ended' end;
end $$;

create or replace function join_live(p_live uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.status <> 'live' then raise exception 'Ce live n''est pas en direct'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Vous ne pouvez pas rejoindre ce live'; end if;
  insert into live_viewers (live_id, user_id) values (p_live, auth.uid())
    on conflict (live_id, user_id) do update set last_seen_at = now(), left_at = null;
  n := _live_recount(p_live);
  return jsonb_build_object('viewers', n, 'room', l.room_name, 'host', l.host_id);
end $$;

create or replace function heartbeat_live(p_live uuid) returns integer
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return 0; end if;
  update live_viewers set last_seen_at = now() where live_id = p_live and user_id = auth.uid() and left_at is null;
  return _live_recount(p_live);
end $$;

create or replace function leave_live(p_live uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  update live_viewers set left_at = now() where live_id = p_live and user_id = auth.uid();
  perform _live_recount(p_live);
end $$;

create or replace function post_live_message(p_live uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare mid bigint; b text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(b) not between 1 and 300 then raise exception 'Message de 1 à 300 caractères'; end if;
  if not exists (select 1 from lives where id = p_live and status = 'live') then raise exception 'Ce live n''est pas en direct'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Vous ne pouvez plus écrire dans ce live'; end if;
  if (select count(*) from live_messages where live_id = p_live and user_id = auth.uid() and kind = 'chat' and created_at > now() - interval '10 seconds') >= 5 then
    raise exception 'Trop de messages en peu de temps. Ralentissez un instant.';
  end if;
  insert into live_messages (live_id, user_id, author, kind, body) values (p_live, auth.uid(), _live_author(auth.uid()), 'chat', b) returning id into mid;
  return mid;
end $$;

create or replace function react_live(p_live uuid, p_emoji text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_emoji, '') not in ('heart', 'fire', 'clap', 'laugh', 'wow') then raise exception 'Réaction inconnue'; end if;
  if not exists (select 1 from lives where id = p_live and status = 'live') then raise exception 'Ce live n''est pas en direct'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Action impossible'; end if;
  if (select count(*) from live_messages where live_id = p_live and user_id = auth.uid() and kind = 'reaction' and created_at > now() - interval '10 seconds') >= 20 then return; end if;
  insert into live_messages (live_id, user_id, author, kind, body) values (p_live, auth.uid(), _live_author(auth.uid()), 'reaction', p_emoji);
end $$;

create or replace function report_live(p_live uuid, p_message bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from lives where id = p_live) then raise exception 'Live introuvable'; end if;
  insert into live_reports (live_id, reporter_id, message_id, reason) values (p_live, auth.uid(), p_message, btrim(p_reason))
    on conflict do nothing;
  return 'reported';
end $$;

create or replace function moderate_live_viewer(p_live uuid, p_user uuid, p_message bigint default null) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from lives where id = p_live and host_id = auth.uid()) and coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Action non autorisée'; end if;
  if p_message is not null then update live_messages set hidden = true where id = p_message and live_id = p_live; end if;
  if p_user is not null and p_user <> auth.uid() then
    insert into live_bans (live_id, user_id, by_user) values (p_live, p_user, auth.uid()) on conflict do nothing;
    update live_viewers set left_at = now() where live_id = p_live and user_id = p_user;
    perform _live_recount(p_live);
  end if;
  return 'ok';
end $$;

-- Lives en direct puis programmés (titre, hôte certifié ou non, spectateurs).
create or replace function lives_now(p_limit integer default 30)
returns table (id uuid, host_id uuid, host text, host_avatar text, host_verified boolean, title text, description text, cover_path text, status text, scheduled_at timestamptz, started_at timestamptz, viewer_count integer)
language sql stable security definer set search_path = public as $$
  select l.id, l.host_id, _live_author(l.host_id), a.avatar_url, a.certification::text = 'approved', l.title, l.description, l.cover_path, l.status, l.scheduled_at, l.started_at, l.viewer_count
  from lives l join profiles a on a.id = l.host_id and not a.suspended
  where l.status in ('live', 'scheduled')
  order by (l.status = 'live') desc, coalesce(l.started_at, l.scheduled_at, l.created_at) desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
create or replace function live_get(p_live uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', l.id, 'host_id', l.host_id, 'host', _live_author(l.host_id), 'host_avatar', a.avatar_url, 'host_verified', a.certification::text = 'approved',
    'title', l.title, 'description', l.description, 'cover_path', l.cover_path, 'status', l.status, 'room', l.room_name, 'viewer_count', l.viewer_count,
    'peak_viewers', l.peak_viewers, 'started_at', l.started_at, 'mine', l.host_id = auth.uid())
  from lives l join profiles a on a.id = l.host_id where l.id = p_live and l.status <> 'cancelled'
$$;
create or replace function my_lives() returns table (id uuid, title text, status text, scheduled_at timestamptz, started_at timestamptz, ended_at timestamptz, peak_viewers integer)
language sql stable security definer set search_path = public as $$
  select id, title, status, scheduled_at, started_at, ended_at, peak_viewers from lives where host_id = auth.uid() and status <> 'cancelled' order by created_at desc limit 50
$$;
grant execute on function lives_now(integer), live_get(uuid) to anon, authenticated;
revoke all on function create_live(text, text, text, timestamptz), start_live(uuid), end_live(uuid), join_live(uuid), heartbeat_live(uuid), leave_live(uuid),
  post_live_message(uuid, text), react_live(uuid, text), report_live(uuid, bigint, text), moderate_live_viewer(uuid, uuid, bigint), my_lives() from public, anon;
grant execute on function create_live(text, text, text, timestamptz), start_live(uuid), end_live(uuid), join_live(uuid), heartbeat_live(uuid), leave_live(uuid),
  post_live_message(uuid, text), react_live(uuid, text), report_live(uuid, bigint, text), moderate_live_viewer(uuid, uuid, bigint), my_lives() to authenticated;

-- ------------------------------------------------------------------ cadeaux virtuels et crédits
create table if not exists gift_settings (
  id boolean primary key default true check (id),
  creator_share_pct integer not null default 70 check (creator_share_pct between 0 and 100),
  credit_price_fcfa integer not null default 10 check (credit_price_fcfa > 0),
  max_quantity integer not null default 50 check (max_quantity between 1 and 999)
);
insert into gift_settings (id) values (true) on conflict do nothing;

create table if not exists gift_catalog (
  code text primary key check (code ~ '^[a-z0-9_]{2,30}$'),
  name text not null,
  emoji text not null,
  credits integer not null check (credits > 0),
  sort integer not null default 0,
  active boolean not null default true
);
insert into gift_catalog (code, name, emoji, credits, sort) values
  ('rose', 'Rose', '🌹', 5, 1), ('coeur', 'Cœur', '❤️', 10, 2), ('bravo', 'Bravo', '👏', 20, 3), ('flamme', 'Flamme', '🔥', 50, 4),
  ('etoile', 'Étoile', '⭐', 100, 5), ('trophee', 'Trophée', '🏆', 500, 6)
on conflict (code) do nothing;

create table if not exists credit_wallets (
  user_id uuid primary key references profiles(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists creator_earnings (
  user_id uuid primary key references profiles(id) on delete cascade,
  credits bigint not null default 0 check (credits >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists credit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  account text not null check (account in ('wallet', 'earnings')),
  delta bigint not null check (delta <> 0),
  kind text not null check (kind in ('topup', 'gift_sent', 'gift_received', 'refund', 'adjust')),
  ref text not null,
  created_at timestamptz not null default now(),
  unique (user_id, account, kind, ref)
);
create table if not exists gift_sends (
  id uuid primary key default gen_random_uuid(),
  live_id uuid not null references lives(id) on delete restrict,
  sender_id uuid not null references profiles(id) on delete restrict,
  receiver_id uuid not null references profiles(id) on delete restrict,
  gift_code text not null references gift_catalog(code),
  quantity integer not null check (quantity between 1 and 999),
  credits_total bigint not null check (credits_total > 0),
  creator_credits bigint not null check (creator_credits >= 0),
  platform_credits bigint not null check (platform_credits >= 0),
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 64),
  created_at timestamptz not null default now(),
  unique (sender_id, idempotency_key)
);
create index if not exists gift_sends_recus on gift_sends (receiver_id, created_at desc);
create index if not exists gift_sends_envoyes on gift_sends (sender_id, created_at desc);

alter table gift_settings enable row level security;
alter table gift_catalog enable row level security;
alter table credit_wallets enable row level security;
alter table creator_earnings enable row level security;
alter table credit_ledger enable row level security;
alter table gift_sends enable row level security;
revoke all on gift_settings, gift_catalog, credit_wallets, creator_earnings, credit_ledger, gift_sends from anon, authenticated;
grant select on gift_catalog to anon, authenticated;
drop policy if exists "catalogue lisible" on gift_catalog;
create policy "catalogue lisible" on gift_catalog for select using (active);

-- Envoi d'un cadeau. Idempotent : la même clé (par expéditeur) ne débite jamais deux fois ; le solde est verrouillé pendant la transaction.
create or replace function send_gift(p_live uuid, p_gift text, p_qty integer, p_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); l lives%rowtype; g gift_catalog%rowtype; s gift_settings%rowtype; w credit_wallets%rowtype; prev gift_sends%rowtype;
        total bigint; creator bigint; sid uuid;
begin
  if me is null then raise exception 'Connexion requise'; end if;
  if char_length(coalesce(p_key, '')) not between 8 and 64 then raise exception 'Clé de transaction invalide'; end if;
  insert into credit_wallets (user_id) values (me) on conflict do nothing;
  select * into w from credit_wallets where user_id = me for update;     -- sérialise les envois d'une même personne
  select * into prev from gift_sends where sender_id = me and idempotency_key = p_key;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'id', prev.id, 'credits', prev.credits_total, 'balance', w.balance);
  end if;
  select * into s from gift_settings;
  select * into g from gift_catalog where code = p_gift and active;
  if not found then raise exception 'Cadeau indisponible'; end if;
  if coalesce(p_qty, 0) not between 1 and s.max_quantity then raise exception 'Quantité invalide (1 à % )', s.max_quantity; end if;
  select * into l from lives where id = p_live;
  if not found or l.status <> 'live' then raise exception 'Ce live n''est pas en direct'; end if;
  if l.host_id = me then raise exception 'Vous ne pouvez pas vous offrir un cadeau'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = me) then raise exception 'Action impossible'; end if;
  total := g.credits::bigint * p_qty;
  if w.balance < total then raise exception 'Crédits insuffisants : % requis, % disponibles', total, w.balance; end if;
  creator := (total * s.creator_share_pct) / 100;
  update credit_wallets set balance = balance - total, updated_at = now() where user_id = me;
  insert into creator_earnings (user_id, credits) values (l.host_id, creator)
    on conflict (user_id) do update set credits = creator_earnings.credits + excluded.credits, updated_at = now();
  insert into gift_sends (live_id, sender_id, receiver_id, gift_code, quantity, credits_total, creator_credits, platform_credits, idempotency_key)
    values (p_live, me, l.host_id, g.code, p_qty, total, creator, total - creator, p_key) returning id into sid;
  insert into credit_ledger (user_id, account, delta, kind, ref) values (me, 'wallet', -total, 'gift_sent', sid::text);
  if creator > 0 then insert into credit_ledger (user_id, account, delta, kind, ref) values (l.host_id, 'earnings', creator, 'gift_received', sid::text); end if;
  insert into live_messages (live_id, user_id, author, kind, body, payload)
    values (p_live, me, _live_author(me), 'gift', g.code, jsonb_build_object('gift', g.code, 'name', g.name, 'emoji', g.emoji, 'qty', p_qty, 'credits', total));
  return jsonb_build_object('ok', true, 'duplicate', false, 'id', sid, 'credits', total, 'balance', w.balance - total);
end $$;

-- Ajout de crédits : serveur seulement (rôle service_role, appelé par le webhook d'un paiement confirmé). Idempotent par référence de paiement.
create or replace function grant_credits(p_user uuid, p_amount bigint, p_ref text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare added integer := 0; bal bigint;
begin
  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then raise exception 'Montant invalide'; end if;
  if char_length(coalesce(p_ref, '')) < 4 then raise exception 'Référence de paiement requise'; end if;
  insert into credit_wallets (user_id) values (p_user) on conflict do nothing;
  perform 1 from credit_wallets where user_id = p_user for update;
  insert into credit_ledger (user_id, account, delta, kind, ref) values (p_user, 'wallet', p_amount, 'topup', p_ref) on conflict do nothing;
  get diagnostics added = row_count;
  if added > 0 then update credit_wallets set balance = balance + p_amount, updated_at = now() where user_id = p_user; end if;
  select balance into bal from credit_wallets where user_id = p_user;
  return jsonb_build_object('added', added > 0, 'balance', bal);
end $$;
revoke all on function grant_credits(uuid, bigint, text) from public, anon, authenticated;
grant execute on function grant_credits(uuid, bigint, text) to service_role;

create or replace function my_wallet() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'balance', coalesce((select balance from credit_wallets where user_id = auth.uid()), 0),
    'earnings', coalesce((select credits from creator_earnings where user_id = auth.uid()), 0),
    'creator_share_pct', (select creator_share_pct from gift_settings),
    'credit_price_fcfa', (select credit_price_fcfa from gift_settings))
$$;

-- Historique : sens 'sent' (envoyés) ou 'received' (reçus), du plus récent au plus ancien.
create or replace function my_gift_history(p_direction text default 'sent', p_limit integer default 50)
returns table (id uuid, live_title text, other text, gift_code text, gift_name text, emoji text, quantity integer, credits bigint, creator_credits bigint, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.id, l.title, _live_author(case when p_direction = 'received' then s.sender_id else s.receiver_id end), s.gift_code, c.name, c.emoji, s.quantity,
         s.credits_total, s.creator_credits, s.created_at
  from gift_sends s join lives l on l.id = s.live_id join gift_catalog c on c.code = s.gift_code
  where (p_direction = 'received' and s.receiver_id = auth.uid()) or (p_direction <> 'received' and s.sender_id = auth.uid())
  order by s.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
$$;

-- Tableau de bord créateur : lives, spectateurs, cadeaux reçus, part du créateur et commission de la plateforme.
create or replace function creator_dashboard() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'lives', (select count(*)::int from lives where host_id = auth.uid() and status in ('live', 'ended')),
    'peak_viewers', coalesce((select max(peak_viewers) from lives where host_id = auth.uid()), 0),
    'gifts_received', coalesce((select sum(quantity)::int from gift_sends where receiver_id = auth.uid()), 0),
    'credits_received', coalesce((select sum(credits_total) from gift_sends where receiver_id = auth.uid()), 0),
    'creator_credits', coalesce((select credits from creator_earnings where user_id = auth.uid()), 0),
    'platform_credits', coalesce((select sum(platform_credits) from gift_sends where receiver_id = auth.uid()), 0),
    'creator_share_pct', (select creator_share_pct from gift_settings),
    'credit_price_fcfa', (select credit_price_fcfa from gift_settings),
    'payout_available', false)
$$;
revoke all on function send_gift(uuid, text, integer, text), my_wallet(), my_gift_history(text, integer), creator_dashboard() from public, anon;
grant execute on function send_gift(uuid, text, integer, text), my_wallet(), my_gift_history(text, integer), creator_dashboard() to authenticated;

-- ------------------------------------------------------------------ temps réel (Supabase Realtime)
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table lives; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table live_messages; exception when duplicate_object then null; end;
  end if;
end $$;
