-- Lot G6 (1/2) : réseau social, histoires, niveaux et classement — visibilité du profil, comptes suspendus, blocages, compteurs, faux succès.
--  1. S2-85 (décision) : author_posts, reels_feed, circle_feed, stories_active, user_level, community_levels et top_helpers respectent profile_visible()
--     (profil « membres » masqué aux visiteurs, profil « privé » masqué à tous sauf à son titulaire et à l'équipe) et n'exposent jamais un compte suspendu.
--     Les points d'un profil non visible ne sont donc plus lisibles par identifiant ni classés publiquement ; le titulaire voit toujours les siens.
--  2. Blocages réels : le message « vous ne verrez plus ses publications » devient vrai pour les Reels, le profil public, les histoires et le fil des communautés
--     (jusqu'ici seul circle_feed filtrait). block_user refuse une personne inconnue au lieu d'une erreur technique.
--  3. Compteurs : le nombre de commentaires d'une publication ne compte plus les commentaires que la liste ne montre pas (auteur suspendu ou bloqué).
--  4. Histoires : story_results n'affiche plus le nom complet des répondants (nom abrégé) ; answer_story refuse compte suspendu, histoire d'un auteur bloqué ou masqué ;
--     hide_story et delete_post_comment ne répondent plus « masquée / masqué » quand rien n'existe (faux succès).
--  5. report_post : motif de 3 caractères au moins, pas de signalement de sa propre publication, compte suspendu refusé (message clair au lieu d'une erreur technique).
--  6. Comptes suspendus : aucune écriture dans le chat, les questions, les réponses de communauté, le portfolio, les projets, les équipes de concours
--     (même garde que 20261114004200, par déclencheur).
-- Retour arrière : recréer author_posts (20261104000400), reels_feed (20261103000100), circle_feed (20261117070000), post_comment_list* inchangés, community_feed (20261114001700),
--   stories_active (20261113000000), story_results / answer_story (20261113000000), hide_story (20261110000000), delete_post_comment (20261103000000), report_post (20261117070000),
--   user_level / community_levels (20261115190000), top_helpers (20261117050400), block_user (20261106000100) ;
--   drop function _post_comments_visible(uuid) ; drop trigger trg_block_suspended sur les tables listées en 6 (community_messages, community_questions, community_answers,
--   portfolio_items, projects, contest_teams, contest_members, talent_skills, comment_likes, comment_reports, story_reports, community_reports).

-- ============================================================ 3. Compteur de commentaires cohérent avec la liste
create or replace function _post_comments_visible(p_post uuid) returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::int from post_comments c join profiles a on a.id = c.author_id
  where c.post_id = p_post and c.status = 'visible' and not coalesce(a.suspended, false) and not is_blocked_between(auth.uid(), c.author_id)
$$;
revoke all on function _post_comments_visible(uuid) from public, anon, authenticated;

-- ============================================================ 1-2. Profil public : publications
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
         _post_comments_visible(p.id),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid())
  from posts p
  join profiles a on a.id = p.author_id and not coalesce(a.suspended, false)
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  where p.author_id = p_author and p.status = 'published' and p.kind = 'media' and p.community_id is null
    and profile_visible(p.author_id) and not is_blocked_between(auth.uid(), p.author_id)
  order by p.published_at desc nulls last
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
revoke all on function author_posts(uuid, integer) from public;
grant execute on function author_posts(uuid, integer) to anon, authenticated;

-- ============================================================ Reels
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
         _post_comments_visible(p.id),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid())
  from posts p join profiles a on a.id = p.author_id and not coalesce(a.suspended, false)
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  where p.status = 'published' and p.kind = 'media' and p.community_id is null
    and profile_visible(p.author_id) and not is_blocked_between(auth.uid(), p.author_id)
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;
grant execute on function reels_feed(integer) to anon, authenticated;

create or replace function circle_feed(p_limit integer default 30)
returns table (id uuid, kind text, author text, author_id uuid, author_avatar text, author_verified boolean,
               media_path text, media_kind text, caption text, tags text[], listing_title text, link_url text,
               likes integer, liked boolean, boosted boolean, published_at timestamptz,
               comments integer, saves integer, shares integer, saved boolean, reposts integer,
               media jsonb, repost_id uuid, repost_author text, repost_author_id uuid, repost_caption text, repost_media_path text, repost_media_kind text)
language sql stable security definer set search_path = public as $$
  select p.id, p.kind,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), case when a.role::text = 'student' then 'Étudiant' else 'Membre' end),
         p.author_id, a.avatar_url, a.certification::text = 'approved',
         p.media_path, p.media_kind, case when p.kind = 'text' then coalesce(p.body, '') else p.caption end, p.tags, l.title, p.link_url,
         (select count(*)::int from post_likes k where k.post_id = p.id),
         exists (select 1 from post_likes k where k.post_id = p.id and k.user_id = auth.uid()),
         exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at),
         p.published_at,
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
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
grant execute on function circle_feed(integer) to anon, authenticated;

-- ============================================================ Communautés : fil sans comptes suspendus ni personnes bloquées
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
    and not exists (select 1 from profiles z where z.id = p.author_id and coalesce(z.suspended, false))
    and not is_blocked_between(auth.uid(), p.author_id)
  order by p.pinned desc, p.pinned_at desc nulls last, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;
revoke all on function community_feed(uuid, integer) from public, anon;
grant execute on function community_feed(uuid, integer) to authenticated, anon;

-- ============================================================ S2-85 : niveau et classement
create or replace function user_level(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('total', t.total, 'level', point_level(t.total))
  from (select points_total(p_user) total) t
  where exists (select 1 from profiles p where p.id = p_user and not coalesce(p.suspended, false)) and profile_visible(p_user)
$$;

create or replace function community_levels(p_community uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(x.user_id, jsonb_build_object('total', x.total, 'level', point_level(x.total))), '{}'::jsonb)
  from (
    select m.user_id, points_total(m.user_id) total
    from community_members m
    join communities c on c.id = m.community_id
    join profiles u on u.id = m.user_id and not coalesce(u.suspended, false)
    where m.community_id = p_community and m.status = 'active' and c.status = 'active'
      and (c.privacy in ('public', 'approval') or is_community_member(c.id) or is_platform_staff())
      and profile_visible(m.user_id)
  ) x
  where point_level(x.total) <> 'none'
$$;

create or replace function top_helpers(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('user_id', x.user_id, 'name', display_name(x.user_id), 'total', x.total, 'level', point_level(x.total)) order by x.total desc), '[]'::jsonb)
  from (select u.user_id, sum(u.points)::int total
        from (select user_id, points from point_events union all select user_id, points from points_ledger where source not like 'challenge:%') u
        join profiles a on a.id = u.user_id and not coalesce(a.suspended, false)
        where profile_visible(u.user_id)
        group by u.user_id having sum(u.points) > 0 order by sum(u.points) desc limit least(greatest(coalesce(p_limit, 10), 1), 50)) x
$$;

revoke all on function user_level(uuid), community_levels(uuid), top_helpers(integer) from public;
grant execute on function user_level(uuid), community_levels(uuid), top_helpers(integer) to anon, authenticated;

-- ============================================================ Histoires
create or replace function stories_active(p_author uuid default null)
returns table (id uuid, author_id uuid, author text, author_avatar text, author_verified boolean, media_path text, media_kind text, caption text, created_at timestamptz, seen boolean,
               sticker jsonb, expires_at timestamptz, my_choice int, my_answer text)
language sql stable security definer set search_path = public as $$
  select s.id, s.author_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         a.avatar_url, a.certification::text = 'approved', s.media_path, s.media_kind, s.caption, s.created_at,
         exists (select 1 from story_views v where v.story_id = s.id and v.user_id = auth.uid()),
         s.sticker, s.expires_at,
         (select ar.choice from story_answers ar where ar.story_id = s.id and ar.user_id = auth.uid()),
         (select ar.answer from story_answers ar where ar.story_id = s.id and ar.user_id = auth.uid())
  from stories s join profiles a on a.id = s.author_id and not coalesce(a.suspended, false)
  where s.status = 'visible' and s.expires_at > now() and (p_author is null or s.author_id = p_author)
    and profile_visible(s.author_id) and not is_blocked_between(auth.uid(), s.author_id)
  order by s.author_id, s.created_at
  limit 300
$$;
grant execute on function stories_active(uuid) to anon, authenticated;

create or replace function answer_story(p_story uuid, p_choice int, p_answer text) returns text
language plpgsql security definer set search_path = public as $$
declare s stories%rowtype; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : cette action est impossible'; end if;
  select * into s from stories where id = p_story and status = 'visible' and expires_at > now();
  if not found or s.sticker is null
     or exists (select 1 from profiles z where z.id = s.author_id and coalesce(z.suspended, false))
     or is_blocked_between(auth.uid(), s.author_id) or not profile_visible(s.author_id) then
    raise exception 'Cette histoire n''accepte pas de réponse';
  end if;
  if s.author_id = auth.uid() then raise exception 'Vous ne pouvez pas répondre à votre propre histoire'; end if;
  if s.sticker->>'type' = 'poll' then
    n := jsonb_array_length(s.sticker->'options');
    if p_choice is null or p_choice < 0 or p_choice >= n then raise exception 'Choix invalide'; end if;
    insert into story_answers (story_id, user_id, choice) values (p_story, auth.uid(), p_choice)
    on conflict (story_id, user_id) do update set choice = excluded.choice;
  else
    if char_length(btrim(coalesce(p_answer, ''))) not between 1 and 300 then raise exception 'La réponse fait de 1 à 300 caractères'; end if;
    insert into story_answers (story_id, user_id, answer) values (p_story, auth.uid(), btrim(p_answer))
    on conflict (story_id, user_id) do update set answer = excluded.answer;
  end if;
  return 'enregistrée';
end $$;
revoke all on function answer_story(uuid, int, text) from public, anon;
grant execute on function answer_story(uuid, int, text) to authenticated;

create or replace function story_results(p_story uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s stories%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from stories where id = p_story and author_id = auth.uid();
  if not found then raise exception 'Histoire introuvable'; end if;
  if s.sticker is null then return '{}'::jsonb; end if;
  if s.sticker->>'type' = 'poll' then
    return jsonb_build_object('type', 'poll', 'counts', coalesce((
      select jsonb_agg(coalesce(c.n, 0) order by o.i)
      from generate_series(0, jsonb_array_length(s.sticker->'options') - 1) o(i)
      left join (select choice, count(*) n from story_answers where story_id = p_story group by choice) c on c.choice = o.i), '[]'::jsonb));
  end if;
  return jsonb_build_object('type', 'question', 'answers', coalesce((
    select jsonb_agg(jsonb_build_object('name', _short_name(p.name), 'answer', a.answer) order by a.created_at desc)
    from story_answers a join profiles p on p.id = a.user_id and not coalesce(p.suspended, false)
    where a.story_id = p_story and a.answer is not null and not is_blocked_between(auth.uid(), a.user_id)), '[]'::jsonb));
end $$;
revoke all on function story_results(uuid) from public, anon;
grant execute on function story_results(uuid) to authenticated;

create or replace function hide_story(p_story uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from stories where id = p_story and author_id = auth.uid()) then
    delete from stories where id = p_story; return 'supprimée';
  end if;
  if coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then
    update stories set status = 'hidden' where id = p_story;
    if not found then raise exception 'Histoire introuvable'; end if;
    return 'masquée';
  end if;
  raise exception 'Action non autorisée';
end $$;
revoke all on function hide_story(uuid) from public, anon;
grant execute on function hide_story(uuid) to authenticated;

-- ============================================================ Commentaires, signalements, blocage
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
    if not found then raise exception 'Commentaire introuvable'; end if;
    return 'masqué';
  end if;
  raise exception 'Action non autorisée';
end $$;
revoke all on function delete_post_comment(uuid) from public, anon;
grant execute on function delete_post_comment(uuid) to authenticated;

create or replace function report_post(p_post uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare m record; ins int; v_reason text := btrim(coalesce(p_reason, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if char_length(v_reason) not between 3 and 300 then raise exception 'Indiquez un motif de 3 à 300 caractères'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  if exists (select 1 from posts where id = p_post and author_id = auth.uid()) then raise exception 'Vous ne pouvez pas signaler votre propre publication'; end if;
  insert into post_reports (post_id, reporter_id, reason) values (p_post, auth.uid(), v_reason)
  on conflict (post_id, reporter_id) do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select p.id from profiles p where p.role::text in ('dept', 'admin', 'support') and not p.suspended
             and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'report' and x.read_at is null and x.created_at > now() - interval '15 minutes') loop
      perform notify_user(m.id, 'report', 'Publication signalée', 'Une publication a été signalée et attend un examen.', jsonb_build_object('post', p_post));
    end loop;
  end if;
  return 'reported';
end $$;
revoke all on function report_post(uuid, text) from public, anon;
grant execute on function report_post(uuid, text) to authenticated;

create or replace function block_user(p_user uuid, p_block boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_user is null or p_user = auth.uid() then raise exception 'Action impossible sur votre propre compte'; end if;
  if p_block then
    if not exists (select 1 from profiles where id = p_user) then raise exception 'Personne introuvable'; end if;
    insert into user_blocks (blocker_id, blocked_id) values (auth.uid(), p_user) on conflict do nothing;
  else
    delete from user_blocks where blocker_id = auth.uid() and blocked_id = p_user;
  end if;
end $$;
revoke all on function block_user(uuid, boolean) from public, anon;
grant execute on function block_user(uuid, boolean) to authenticated;

-- ============================================================ 6. Comptes suspendus : écritures refusées (insertion)
do $$
declare t record;
begin
  for t in
    select * from (values
      ('community_messages', 'sender_id'), ('community_questions', 'author_id'), ('community_answers', 'author_id'),
      ('portfolio_items', 'owner_id'), ('projects', 'owner_id'), ('contest_teams', 'captain_id'), ('contest_members', 'user_id'),
      ('talent_skills', 'owner_id'), ('comment_likes', 'user_id'), ('comment_reports', 'reporter_id'), ('story_reports', 'reporter_id'), ('community_reports', 'reporter_id')
    ) v(tbl, col)
  loop
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = t.tbl and column_name = t.col) then
      execute format('drop trigger if exists trg_block_suspended on %I', t.tbl);
      execute format('create trigger trg_block_suspended before insert on %I for each row execute function block_suspended_author(%L)', t.tbl, t.col);
    end if;
  end loop;
end $$;
