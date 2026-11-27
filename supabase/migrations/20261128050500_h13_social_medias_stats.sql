-- H13 SOCIAL 6/6 : médias et droits d'accès (post-media), statistiques créateur cohérentes.
--  * lecture storage.objects de post-media : le fichier d'une publication non publiée / retirée / masquée, d'une communauté fermée (pour un non-membre), d'une story expirée ou masquée,
--    ou d'un commentaire d'une publication inaccessible n'est lisible (liste, téléchargement authentifié) que par son propriétaire (dossier <uid>/) ou la modération ;
--    les autres fichiers gardent la lecture ouverte. Limite : le compartiment reste « public » (URL directe) tant que l'application sert des URL publiques : l'URL exacte d'un fichier
--    non référencé reste lisible, le nom ne peut simplement plus être énuméré (liste) par un tiers pour les contenus non publics ;
--  * post_media : type (JPG, PNG, WebP, GIF, MP4, MOV), cohérence image/vidéo et, si le fichier est déjà déposé, taille (50 Mo) et type MIME contrôlés côté serveur ;
--  * creator_analytics : seules les publications PUBLIÉES comptent (vues, j'aime, commentaires, partages, enregistrements), classement des meilleures publications sur la même période,
--    abonnés comptés sans comptes suspendus ; même contrat JSON qu'avant.
-- Strictement additif. Retour arrière : recréer la politique « médias de publication : lecture » depuis 20261101000600 ; drop trigger trg_h13_post_media_check on post_media ;
--   drop function _post_media_readable(text), _h13_post_media_check() ; recréer creator_analytics depuis sa version précédente.

create index if not exists post_media_h13_path on post_media (path);
create index if not exists posts_h13_media_path on posts (media_path) where media_path is not null;
create index if not exists post_comments_h13_attach on post_comments (attachment_path) where attachment_path is not null;
create index if not exists stories_h13_media on stories (media_path) where media_path is not null;
create index if not exists community_files_h13_path on community_files (path);

create or replace function _post_media_readable(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid()::text = (string_to_array(p_name, '/'))[1]
    or _staff_perm(array['security.moderation', 'security.reports']) or coalesce(current_role_name()::text, '') = 'dept'
    or not (
      exists (select 1 from post_media pm join posts p on p.id = pm.post_id where pm.path = p_name and not _post_accessible(p.id))
      or exists (select 1 from posts p where p.media_path = p_name and not _post_accessible(p.id))
      or exists (select 1 from post_comments c where c.attachment_path = p_name and not _post_accessible(c.post_id))
      or exists (select 1 from stories s where s.media_path = p_name and not (s.status = 'visible' and s.expires_at > now()))
      or exists (select 1 from community_files f join communities cm on cm.id = f.community_id where f.path = p_name
                 and not ((cm.privacy = 'public' and cm.status = 'active') or is_community_member(cm.id))))
$$;
revoke all on function _post_media_readable(text) from public;
grant execute on function _post_media_readable(text) to anon, authenticated;

drop policy if exists "médias de publication : lecture" on storage.objects;
create policy "médias de publication : lecture" on storage.objects for select using (bucket_id = 'post-media' and _post_media_readable(name));

create or replace function _h13_post_media_check() returns trigger language plpgsql security definer set search_path = public as $$
declare v_ext text := lower(substring(coalesce(new.path, '') from '\.([a-z0-9]+)$')); v_md jsonb; v_img boolean;
begin
  if v_ext is null or v_ext not in ('jpg', 'jpeg', 'png', 'webp', 'gif', 'mp4', 'mov') then raise exception 'Type de fichier non accepté (JPG, PNG, WebP, GIF, MP4 ou MOV)'; end if;
  v_img := v_ext in ('jpg', 'jpeg', 'png', 'webp', 'gif');
  if new.kind is distinct from (case when v_img then 'image' else 'video' end) then raise exception 'Le type du fichier ne correspond pas à sa nature (image ou vidéo)'; end if;
  select metadata into v_md from storage.objects where bucket_id = 'post-media' and name = new.path limit 1;
  if v_md is not null then
    if coalesce(nullif(v_md->>'size', '')::bigint, 0) > 52428800 then raise exception 'Fichier trop lourd : 50 Mo au plus'; end if;
    if nullif(v_md->>'mimetype', '') is not null and (v_md->>'mimetype' like 'image/%') is distinct from v_img then raise exception 'Le contenu du fichier ne correspond pas à son type'; end if;
  end if;
  return new;
end $$;
revoke all on function _h13_post_media_check() from public, anon, authenticated;
drop trigger if exists trg_h13_post_media_check on post_media;
create trigger trg_h13_post_media_check before insert on post_media for each row execute function _h13_post_media_check();

-- ------------------------------------------------------------------ statistiques créateur
create or replace function creator_analytics(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); d integer := least(greatest(coalesce(p_days, 30), 1), 365); since timestamptz;
  posts_total integer; posts_period integer; views_total bigint; views_p bigint; reach_p bigint; likes_p bigint; comments_p bigint; shares_p bigint; saves_p bigint;
  fol_total bigint; fol_gain bigint; lives_n integer; lives_peak integer; watch_min numeric; gifts_credits bigint; gifts_n bigint; top jsonb;
begin
  perform _assert_active();
  since := now() - make_interval(days => d);
  select count(*) filter (where status = 'published'), count(*) filter (where status = 'published' and published_at >= since) into posts_total, posts_period from posts where author_id = me;
  select count(*), count(distinct v.viewer_id) into views_p, reach_p from post_views v join posts p on p.id = v.post_id where p.author_id = me and p.status = 'published' and v.created_at >= since;
  select count(*) into views_total from post_views v join posts p on p.id = v.post_id where p.author_id = me and p.status = 'published';
  select count(*) into likes_p from post_likes x join posts p on p.id = x.post_id where p.author_id = me and p.status = 'published' and x.created_at >= since and x.user_id <> me;
  select count(*) into comments_p from post_comments x join posts p on p.id = x.post_id where p.author_id = me and p.status = 'published' and x.created_at >= since and x.author_id <> me and x.status = 'visible';
  select count(*) into shares_p from post_shares x join posts p on p.id = x.post_id where p.author_id = me and p.status = 'published' and x.created_at >= since and x.user_id <> me;
  select count(*) into saves_p from post_saves x join posts p on p.id = x.post_id where p.author_id = me and p.status = 'published' and x.created_at >= since and x.user_id <> me;
  select count(*), count(*) filter (where e.created_at >= since) into fol_total, fol_gain from engagements e join profiles f on f.id = e.user_id and not coalesce(f.suspended, false)
    where e.kind = 'follow' and e.ref = me::text and e.status = 'active' and e.user_id <> me;
  select count(*), coalesce(max(peak_viewers), 0) into lives_n, lives_peak from lives where host_id = me and status in ('live', 'ended') and coalesce(started_at, created_at) >= since;
  select coalesce(round(sum(extract(epoch from (coalesce(x.left_at, x.last_seen_at) - x.joined_at))) / 60), 0) into watch_min
    from live_viewers x join lives l on l.id = x.live_id where l.host_id = me and x.joined_at >= since and x.user_id <> me;
  select coalesce(sum(creator_credits), 0), count(*) into gifts_credits, gifts_n from gift_sends where receiver_id = me and created_at >= since;
  select coalesce(jsonb_agg(t order by (t->>'views')::int desc, (t->>'published_at') desc), '[]'::jsonb) into top from (
    select jsonb_build_object('id', p.id, 'title', left(coalesce(nullif(btrim(p.caption), ''), nullif(btrim(p.body), ''), 'Publication'), 80), 'published_at', p.published_at,
      'views', (select count(*) from post_views v where v.post_id = p.id and v.created_at >= since),
      'likes', (select count(*) from post_likes x where x.post_id = p.id and x.user_id <> me and x.created_at >= since),
      'comments', (select count(*) from post_comments x where x.post_id = p.id and x.status = 'visible' and x.author_id <> me and x.created_at >= since)) t
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
