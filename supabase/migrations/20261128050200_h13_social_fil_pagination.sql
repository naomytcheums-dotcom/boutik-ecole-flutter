-- H13 SOCIAL 3/6 : fil d'actualité paginé par curseur.
--  * circle_feed_page(p_limit, p_before_at, p_before_id, p_scope) : même contenu et mêmes filtres que circle_feed (publié, hors communautés, auteur visible, non suspendu, non bloqué,
--    republication visible), ordre stable (date de publication puis identifiant, du plus récent au plus ancien) : le curseur (published_at, id) de la dernière ligne donne la page suivante
--    sans doublon ni trou, même si des publications arrivent entre deux pages ;
--  * p_scope = 'following' : seulement les auteurs suivis (onglet « Abonnements ») ; anonyme : vide ;
--  * les publications mises en avant ne passent plus devant dans cette variante (incompatible avec un curseur stable) ; le drapeau boosted reste fourni ;
--  * index de pagination posts (published_at desc, id desc) pour le fil public.
-- Strictement additif. Retour arrière : drop function circle_feed_page(integer, timestamptz, uuid, text) ; drop index posts_h13_feed_idx.

create index if not exists posts_h13_feed_idx on posts ((coalesce(published_at, created_at)) desc, id desc) where status = 'published' and community_id is null;

create or replace function circle_feed_page(p_limit integer default 20, p_before_at timestamptz default null, p_before_id uuid default null, p_scope text default 'all')
returns table(id uuid, kind text, author text, author_id uuid, author_avatar text, author_verified boolean, media_path text, media_kind text, caption text, tags text[], listing_title text, link_url text,
  likes integer, liked boolean, boosted boolean, published_at timestamptz, comments integer, saves integer, shares integer, saved boolean, reposts integer, media jsonb,
  repost_id uuid, repost_author text, repost_author_id uuid, repost_caption text, repost_media_path text, repost_media_kind text)
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(p_scope, 'all') not in ('all', 'following') then raise exception 'Fil inconnu'; end if;
  if p_before_at is null and p_before_id is not null then raise exception 'Curseur invalide'; end if;
  return query
  select p.id, p.kind,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), case when a.role::text = 'student' then 'Étudiant' else 'Membre' end),
         p.author_id, a.avatar_url, a.certification::text = 'approved',
         p.media_path, p.media_kind, case when p.kind = 'text' then coalesce(p.body, '') else p.caption end, p.tags, l.title, p.link_url,
         (select count(*)::int from post_likes k where k.post_id = p.id),
         exists (select 1 from post_likes k where k.post_id = p.id and k.user_id = auth.uid()),
         exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at),
         coalesce(p.published_at, p.created_at),
         _post_comments_visible(p.id),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid()),
         (select count(*)::int from posts r where r.repost_of = p.id and r.status = 'published'),
         coalesce((select jsonb_agg(jsonb_build_object('path', pm.path, 'kind', pm.kind, 'w', pm.width, 'h', pm.height) order by pm.pos) from post_media pm where pm.post_id = p.id), '[]'::jsonb),
         rp.id,
         case when rp.id is not null then coalesce(nullif(trim(split_part(ra.name, ' ', 1) || ' ' || case when split_part(ra.name, ' ', 2) <> '' then left(split_part(ra.name, ' ', 2), 1) || '.' else '' end), ''), case when ra.role::text = 'student' then 'Étudiant' else 'Membre' end) end,
         rp.author_id,
         case when rp.id is not null then case when rp.kind = 'text' then coalesce(rp.body, '') else rp.caption end end,
         rp.media_path, rp.media_kind
  from posts p
  join profiles a on a.id = p.author_id and not coalesce(a.suspended, false)
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  left join posts rp on rp.id = p.repost_of and rp.status = 'published' and rp.community_id is null
    and profile_visible(rp.author_id) and not is_blocked_between(auth.uid(), rp.author_id)
    and not exists (select 1 from profiles z where z.id = rp.author_id and coalesce(z.suspended, false))
  left join profiles ra on ra.id = rp.author_id
  where p.status = 'published' and p.community_id is null
    and not exists (select 1 from posts o where o.id = p.repost_of and o.community_id is not null)
    and (p.repost_of is null or rp.id is not null or nullif(btrim(coalesce(p.body, '')), '') is not null or p.link_url is not null)
    and profile_visible(p.author_id)
    and not is_blocked_between(auth.uid(), p.author_id)
    and (coalesce(p_scope, 'all') = 'all' or exists (select 1 from engagements e where e.user_id = auth.uid() and e.kind = 'follow' and e.ref = p.author_id::text and e.status = 'active'))
    and (p_before_at is null or (coalesce(p.published_at, p.created_at), p.id) < (p_before_at, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
  order by coalesce(p.published_at, p.created_at) desc, p.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 60);
end $$;
revoke all on function circle_feed_page(integer, timestamptz, uuid, text) from public;
grant execute on function circle_feed_page(integer, timestamptz, uuid, text) to anon, authenticated;
