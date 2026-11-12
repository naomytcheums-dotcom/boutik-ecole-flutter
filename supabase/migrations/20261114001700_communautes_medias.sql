-- Communautés : photo, vidéo ou lien dans une publication (bouton « joindre »), et photo + couverture de la communauté.
-- Les médias sont déposés par l'application dans post-media/<uid>/… (compartiment existant, 50 Mo, image JPG/PNG/WebP/GIF ou vidéo MP4/MOV).
-- Retour arrière : recréer create_community_post(uuid, text, text) et community_feed(uuid, integer) depuis 20261114000900 ;
--   drop function create_community_post(uuid, text, text, text, text, text), community_images(uuid), community_set_images(uuid, text, text, boolean, boolean).

-- ---------------------------------------------------------------- publication avec pièce jointe
drop function if exists create_community_post(uuid, text, text);
create or replace function create_community_post(p_community uuid, p_body text, p_style text default null, p_media_path text default null, p_media_kind text default null, p_link text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_body text := btrim(coalesce(p_body, '')); v_link text := nullif(btrim(coalesce(p_link, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 1 and 2000 then raise exception 'La publication doit contenir entre 1 et 2000 caractères'; end if;
  if p_style is not null and char_length(v_body) > 280 then raise exception 'Avec un fond design, le texte est limité à 280 caractères'; end if;
  if p_media_path is not null then
    if split_part(p_media_path, '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
    if coalesce(p_media_kind, '') not in ('image', 'video') then raise exception 'Type de média inconnu'; end if;
    if p_style is not null then raise exception 'Un fond design ne se combine pas avec une photo ou une vidéo'; end if;
  end if;
  if v_link is not null and (v_link !~* '^https?://[^ ]+$' or char_length(v_link) > 500) then raise exception 'Le lien doit commencer par https:// et ne pas contenir d''espace'; end if;
  if (select count(*) from posts where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de publications en peu de temps. Réessayez dans une minute.'; end if;
  insert into posts (author_id, kind, body, community_id, status, published_at, style, media_path, media_kind, link_url)
    values (auth.uid(), 'text', v_body, p_community, 'published', now(), p_style, p_media_path, case when p_media_path is null then null else p_media_kind end, v_link) returning id into v_id;
  return v_id;
end $$;
revoke all on function create_community_post(uuid, text, text, text, text, text) from public, anon;
grant execute on function create_community_post(uuid, text, text, text, text, text) to authenticated;

drop function if exists community_feed(uuid, integer);
create or replace function community_feed(p_community uuid, p_limit integer default 30)
returns table (id uuid, author text, author_id uuid, body text, published_at timestamptz, mine boolean, kind text, style text, pinned boolean, poll jsonb, media_path text, media_kind text, link_url text)
language sql stable security definer set search_path = public as $$
  select p.id, display_name(p.author_id), p.author_id, p.body, p.published_at, p.author_id = auth.uid(), p.kind, p.style, p.pinned,
         case when p.kind = 'poll' then (
           select jsonb_build_object(
             'options', (select jsonb_agg(jsonb_build_object('label', o.label, 'votes', (select count(*)::int from community_poll_votes v where v.post_id = p.id and v.option_index = o.ord - 1)) order by o.ord)
                         from unnest(cp.options) with ordinality o(label, ord)),
             'total', (select count(*)::int from community_poll_votes v where v.post_id = p.id),
             'mine', (select v.option_index from community_poll_votes v where v.post_id = p.id and v.user_id = auth.uid()))
           from community_polls cp where cp.post_id = p.id) end,
         p.media_path, p.media_kind, p.link_url
  from posts p join communities c on c.id = p.community_id
  where p.community_id = p_community and p.kind in ('text', 'poll') and p.status = 'published' and c.status = 'active'
    and (c.privacy = 'public' or is_community_member(c.id) or is_platform_staff())
  order by p.pinned desc, p.pinned_at desc nulls last, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;
revoke all on function community_feed(uuid, integer) from public, anon;
grant execute on function community_feed(uuid, integer) to authenticated, anon;

-- ---------------------------------------------------------------- photo et couverture de la communauté
create or replace function community_images(p_community uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('logo_path', c.logo_path, 'cover_path', c.cover_path)
  from communities c
  where c.id = p_community and (c.status = 'active' or c.owner_id = auth.uid() or is_platform_staff())
    and (c.privacy in ('public', 'approval') or is_community_member(c.id) or is_platform_staff())
$$;
revoke all on function community_images(uuid) from public, anon;
grant execute on function community_images(uuid) to authenticated, anon;

-- Réservé au propriétaire et aux administrateurs de la communauté ; l'image doit être dans le dossier de la personne.
create or replace function community_set_images(p_community uuid, p_logo text default null, p_cover text default null, p_clear_logo boolean default false, p_clear_cover boolean default false) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 3 and not is_platform_staff() then raise exception 'Réservé au propriétaire et aux administrateurs de la communauté'; end if;
  if p_logo is not null and split_part(p_logo, '/', 1) <> auth.uid()::text then raise exception 'Image invalide : déposez-la d''abord dans votre dossier'; end if;
  if p_cover is not null and split_part(p_cover, '/', 1) <> auth.uid()::text then raise exception 'Image invalide : déposez-la d''abord dans votre dossier'; end if;
  update communities set
      logo_path = case when coalesce(p_clear_logo, false) then null else coalesce(p_logo, logo_path) end,
      cover_path = case when coalesce(p_clear_cover, false) then null else coalesce(p_cover, cover_path) end
    where id = p_community;
  if not found then raise exception 'Communauté introuvable'; end if;
end $$;
revoke all on function community_set_images(uuid, text, text, boolean, boolean) from public, anon;
grant execute on function community_set_images(uuid, text, text, boolean, boolean) to authenticated;
