-- Commentaires, enregistrements et partages des publications (écrans 245 et 252). NON APPLIQUÉE : à tester sur une base isolée.
-- Réutilise `posts`, `post_likes` et `profiles` (migration 20261101000600) ; aucune table de publication parallèle.
-- Règles : lecture des commentaires d'une publication visible ; écriture par fonctions seulement ; 500 caractères au plus ;
-- un auteur peut supprimer son commentaire, la modération (dept, admin, support) peut tout masquer ; pas plus de 10 commentaires
-- par minute et par personne (anti-spam) ; l'enregistrement est unique par couple (publication, personne).
-- Retour arrière (manuel) : drop des 5 fonctions ci-dessous et de reels_feed(integer) v2 puis recréation de la v1 de 20261101000600 ;
-- drop table post_shares, post_saves, post_comments.

create table if not exists post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  parent_id uuid references post_comments(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  status text not null default 'visible' check (status in ('visible', 'hidden')),
  created_at timestamptz not null default now()
);
create index if not exists post_comments_post on post_comments (post_id, created_at);

create table if not exists post_saves (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- Un partage est un événement : on compte les envois de lien déclarés par des personnes connectées (une ligne par personne et par publication).
create table if not exists post_shares (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table post_comments enable row level security;
alter table post_saves enable row level security;
alter table post_shares enable row level security;
revoke all on post_comments, post_saves, post_shares from anon, authenticated;
grant select on post_comments to anon, authenticated;
grant select on post_saves, post_shares to authenticated;

drop policy if exists "commentaires visibles" on post_comments;
create policy "commentaires visibles" on post_comments for select
  using (
    (status = 'visible' and exists (select 1 from posts p where p.id = post_id and p.status = 'published'))
    or author_id = auth.uid()
    or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support')
  );
drop policy if exists "enregistrements : propriétaire" on post_saves;
create policy "enregistrements : propriétaire" on post_saves for select using (user_id = auth.uid());
drop policy if exists "partages : propriétaire" on post_shares;
create policy "partages : propriétaire" on post_shares for select using (user_id = auth.uid());

create or replace function add_post_comment(p_post uuid, p_body text, p_parent uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 500 then raise exception 'Le commentaire doit contenir entre 1 et 500 caractères'; end if;
  if p_parent is not null and not exists (select 1 from post_comments where id = p_parent and post_id = p_post and parent_id is null) then
    raise exception 'Commentaire parent introuvable';
  end if;
  if (select count(*) from post_comments where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 10 then
    raise exception 'Trop de commentaires en peu de temps. Réessayez dans une minute.';
  end if;
  insert into post_comments (post_id, author_id, parent_id, body) values (p_post, auth.uid(), p_parent, btrim(p_body)) returning id into v_id;
  return v_id;
end $$;

create or replace function delete_post_comment(p_comment uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from post_comments where id = p_comment and author_id = auth.uid()) then
    delete from post_comments where id = p_comment;
    return 'supprimé';
  end if;
  if coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then
    update post_comments set status = 'hidden' where id = p_comment;
    return 'masqué';
  end if;
  raise exception 'Action non autorisée';
end $$;

create or replace function post_comment_list(p_post uuid, p_limit integer default 50)
returns table (id uuid, parent_id uuid, author text, mine boolean, body text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.parent_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         c.author_id = auth.uid(), c.body, c.created_at
  from post_comments c join profiles a on a.id = c.author_id join posts p on p.id = c.post_id
  where c.post_id = p_post and c.status = 'visible' and p.status = 'published'
  order by c.created_at
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
$$;
grant execute on function post_comment_list(uuid, integer) to anon;

create or replace function toggle_post_save(p_post uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
  if exists (select 1 from post_saves where post_id = p_post and user_id = auth.uid()) then
    delete from post_saves where post_id = p_post and user_id = auth.uid();
    return false;
  end if;
  insert into post_saves (post_id, user_id) values (p_post, auth.uid());
  return true;
end $$;

create or replace function record_post_share(p_post uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then return; end if;
  insert into post_shares (post_id, user_id) values (p_post, auth.uid()) on conflict do nothing;
end $$;

-- reels_feed v2 : ajoute auteur (identifiant), compteurs de commentaires, d'enregistrements et de partages, et l'état « enregistré ».
drop function if exists reels_feed(integer);
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
         p.published_at,
         p.author_id,
         (select count(*)::int from post_comments c where c.post_id = p.id and c.status = 'visible'),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid())
  from posts p join profiles a on a.id = p.author_id left join listings l on l.id = p.listing_id and l.status = 'approved'
  where p.status = 'published'
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;
grant execute on function reels_feed(integer) to anon;
revoke all on function add_post_comment(uuid, text, uuid), delete_post_comment(uuid), toggle_post_save(uuid), record_post_share(uuid) from public, anon;
grant execute on function add_post_comment(uuid, text, uuid), delete_post_comment(uuid), toggle_post_save(uuid), record_post_share(uuid) to authenticated;
