-- H10 SOCIAL, étape 3 : analytics créateur réels.
--  * post_views : une ligne par compte, par publication et par jour (anti-doublon) ; jamais enregistrée sur sa propre publication ni sur une publication non publiée ;
--    seules les personnes connectées sont comptées (les visites anonymes ne sont pas mesurées : l'écran le dit) ;
--  * post_view_record(post) : appelée à l'affichage d'une publication par une personne connectée ;
--  * creator_analytics(jours) : chiffres du seul appelant (aucun paramètre d'identité). Vues, portée, engagement, abonnés, lives (pic, durée de visionnage), cadeaux reçus (en crédits,
--    jamais convertis). Les données non mesurées (durée de visionnage des publications, conversions, revenus en argent) sont déclarées « non_disponible », jamais 0.
-- Aucune règle financière modifiée. Retour arrière : drop function creator_analytics(integer), post_view_record(uuid) ; drop table post_views.

create table if not exists post_views (
  post_id uuid not null references posts(id) on delete cascade,
  viewer_id uuid not null references profiles(id) on delete cascade,
  day date not null default ((now() at time zone 'Africa/Douala')::date),
  created_at timestamptz not null default now(),
  primary key (post_id, viewer_id, day)
);
create index if not exists post_views_post on post_views (post_id, created_at);
alter table post_views enable row level security;
revoke all on post_views from anon, authenticated;

create or replace function post_view_record(p_post uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); a uuid; inserted integer;
begin
  perform _assert_active();
  select author_id into a from posts where id = p_post and status = 'published';
  if not found or a = me then return false; end if;
  insert into post_views (post_id, viewer_id) values (p_post, me) on conflict do nothing;
  get diagnostics inserted = row_count;
  return inserted = 1;
end $$;
revoke all on function post_view_record(uuid) from public, anon;
grant execute on function post_view_record(uuid) to authenticated;

create or replace function creator_analytics(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); d integer := least(greatest(coalesce(p_days, 30), 1), 365); since timestamptz;
  posts_total integer; posts_period integer; views_total bigint; views_p bigint; reach_p bigint; likes_p bigint; comments_p bigint; shares_p bigint; saves_p bigint;
  fol_total bigint; fol_gain bigint; lives_n integer; lives_peak integer; watch_min numeric; gifts_credits bigint; gifts_n bigint; top jsonb;
begin
  perform _assert_active();
  since := now() - make_interval(days => d);
  select count(*) filter (where status = 'published'), count(*) filter (where status = 'published' and published_at >= since) into posts_total, posts_period from posts where author_id = me;
  select count(*), count(distinct v.viewer_id) into views_p, reach_p from post_views v join posts p on p.id = v.post_id where p.author_id = me and v.created_at >= since;
  select count(*) into views_total from post_views v join posts p on p.id = v.post_id where p.author_id = me;
  select count(*) into likes_p from post_likes x join posts p on p.id = x.post_id where p.author_id = me and x.created_at >= since and x.user_id <> me;
  select count(*) into comments_p from post_comments x join posts p on p.id = x.post_id where p.author_id = me and x.created_at >= since and x.author_id <> me and x.status = 'visible';
  select count(*) into shares_p from post_shares x join posts p on p.id = x.post_id where p.author_id = me and x.created_at >= since and x.user_id <> me;
  select count(*) into saves_p from post_saves x join posts p on p.id = x.post_id where p.author_id = me and x.created_at >= since and x.user_id <> me;
  select count(*), count(*) filter (where created_at >= since) into fol_total, fol_gain from engagements where kind = 'follow' and ref = me::text and status = 'active';
  select count(*), coalesce(max(peak_viewers), 0) into lives_n, lives_peak from lives where host_id = me and status in ('live', 'ended') and coalesce(started_at, created_at) >= since;
  select coalesce(round(sum(extract(epoch from (coalesce(x.left_at, x.last_seen_at) - x.joined_at))) / 60), 0) into watch_min
    from live_viewers x join lives l on l.id = x.live_id where l.host_id = me and x.joined_at >= since and x.user_id <> me;
  select coalesce(sum(creator_credits), 0), count(*) into gifts_credits, gifts_n from gift_sends where receiver_id = me and created_at >= since;
  select coalesce(jsonb_agg(t order by (t->>'views')::int desc, (t->>'published_at') desc), '[]'::jsonb) into top from (
    select jsonb_build_object('id', p.id, 'title', left(coalesce(nullif(btrim(p.caption), ''), nullif(btrim(p.body), ''), 'Publication'), 80), 'published_at', p.published_at,
      'views', (select count(*) from post_views v where v.post_id = p.id and v.created_at >= since),
      'likes', (select count(*) from post_likes x where x.post_id = p.id and x.user_id <> me),
      'comments', (select count(*) from post_comments x where x.post_id = p.id and x.status = 'visible' and x.author_id <> me)) t
    from posts p where p.author_id = me and p.status = 'published' order by (select count(*) from post_views v where v.post_id = p.id and v.created_at >= since) desc, p.published_at desc limit 5) s;
  return jsonb_build_object(
    'days', d, 'generated_at', now(), 'has_activity', posts_total > 0 or lives_n > 0 or fol_total > 0,
    'posts', jsonb_build_object('published_total', posts_total, 'published_period', posts_period),
    'views', jsonb_build_object('period', views_p, 'total', views_total, 'reach_period', reach_p, 'logged_in_only', true),
    'engagement', jsonb_build_object('likes', likes_p, 'comments', comments_p, 'shares', shares_p, 'saves', saves_p, 'total', likes_p + comments_p + shares_p + saves_p,
      'rate_pct', case when views_p > 0 then round((likes_p + comments_p + shares_p + saves_p)::numeric * 100 / views_p, 1) else null end),
    'followers', jsonb_build_object('total', fol_total, 'gained_period', fol_gain),
    'lives', jsonb_build_object('count', lives_n, 'peak_viewers', lives_peak, 'watch_minutes', watch_min),
    'gifts', jsonb_build_object('credits_received', gifts_credits, 'count', gifts_n),
    'top_posts', top,
    'unavailable', jsonb_build_array('post_watch_time', 'conversions', 'revenue_money'));
end $$;
revoke all on function creator_analytics(integer) from public, anon;
grant execute on function creator_analytics(integer) to authenticated;
