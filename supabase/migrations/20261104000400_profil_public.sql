-- Profil public (écran 247) : lecture limitée aux champs publics et publications d'une personne.
-- Les policies de `profiles` et `engagements` ne sont visibles que par leur titulaire ou la modération :
-- ces deux fonctions `security definer` exposent uniquement ce qui est nécessaire au profil public.
-- Testée sur la base locale isolée (supabase/tests/profil_public_local.sql).
-- Retour arrière : drop function author_posts(uuid, integer); drop function public_profile(uuid);

create or replace function public_profile(p_user uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'role', p.role::text,
    'city', coalesce(p.city, ''),
    'institution', coalesce(p.institution, ''),
    'department', coalesce(p.department, ''),
    'bio', coalesce(p.bio, ''),
    'skills', coalesce(p.skills, ''),
    'avatar_url', p.avatar_url,
    'certified', p.certification::text = 'approved',
    'posts_count', (
      select count(*)::int from posts x
      where x.author_id = p.id and x.status = 'published' and x.kind = 'media' and x.community_id is null
    ),
    'followers_count', (
      select count(*)::int from engagements e
      where e.kind = 'follow' and e.ref = p.id::text and e.status = 'active'
    ),
    'following_count', (
      select count(*)::int from engagements e
      where e.kind = 'follow' and e.user_id = p.id and e.status = 'active'
    ),
    'rating', coalesce((
      select round(avg(r.rating)::numeric, 2) from reviews r
      join listings l on l.id = r.listing_id
      where l.seller_id = p.id
    ), 0),
    'rating_count', (
      select count(*)::int from reviews r
      join listings l on l.id = r.listing_id
      where l.seller_id = p.id
    )
  )
  from profiles p
  where p.id = p_user and not p.suspended;
$$;
revoke all on function public_profile(uuid) from public;
grant execute on function public_profile(uuid) to anon, authenticated;

-- Publications visibles d'une personne, même forme que `reels_feed` pour réutiliser Reel.fromRow.
create or replace function author_posts(p_author uuid, p_limit int default 30)
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
  from posts p
  join profiles a on a.id = p.author_id and not a.suspended
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  where p.author_id = p_author and p.status = 'published' and p.kind = 'media' and p.community_id is null
  order by p.published_at desc nulls last
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
revoke all on function author_posts(uuid, integer) from public;
grant execute on function author_posts(uuid, integer) to anon, authenticated;
