-- Réseau social : modération réelle (S7-1, S7-2, S7-3, S7-5, S7-58).
--  1. Publications en attente / masquées / signalées : liste pour le département, l'administration et le support (moderation_posts_list) ; moderate_post prévient aussi
--     les personnes qui ont signalé ; post_reports_dismiss clôt un signalement sans masquer ; le support reçoit aussi « Publications à valider ».
--  2. Histoires : signalement (report_story), liste de modération (moderation_stories_list), masquage ou rétablissement avec motif et notification (moderate_story).
--  3. Communautés : suppression (douce) d'un message de chat, d'une question ou d'une réponse par son auteur ou par un responsable ; signalement d'un contenu par un membre ;
--     file de signalements pour les responsables ; masquage d'une publication avec motif, notification à l'auteur et rétablissement possible.
-- Aucune donnée existante n'est modifiée. Retour arrière : drop function des fonctions ci-dessous ; drop table story_reports, community_reports ;
--   alter table community_messages/questions/answers drop column removed_at, removed_by, removal_note ; recréer moderate_post (20261101000600), moderate_community_post
--   (20261114000900), community_chat_list et community_qa (20261114001000) et trg_notify_pending_post (20261115170000).

-- ------------------------------------------------------------------ 1. publications
create or replace function trg_notify_pending_post() returns trigger
language plpgsql security definer set search_path = public as $$
declare m record; n int;
begin
  select count(*) into n from posts where status = 'pending';
  for m in
    select p.id from profiles p
    where p.role::text in ('dept', 'admin', 'support') and not p.suspended
      and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'post_review' and x.read_at is null and x.created_at > now() - interval '15 minutes')
  loop
    insert into notifications (user_id, kind, title, body, data)
      values (m.id, 'post_review', 'Publications à valider', n || ' publication' || case when n > 1 then 's attendent' else ' attend' end || ' la validation du département.', jsonb_build_object('post', new.id));
  end loop;
  return null;
end $$;

-- p_status : 'pending' (à valider), 'reported' (publiées avec un signalement ouvert), 'hidden' (masquées ou refusées).
create or replace function moderation_posts_list(p_status text default 'pending', p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_status text := coalesce(p_status, 'pending');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  if v_status not in ('pending', 'reported', 'hidden') then raise exception 'Liste inconnue'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', x.id, 'status', x.status, 'created_at', x.created_at, 'published_at', x.published_at, 'note', x.review_note, 'kind', x.kind,
      'text', case when x.kind = 'text' then coalesce(x.body, '') else coalesce(x.caption, '') end, 'link_url', x.link_url, 'tags', to_jsonb(x.tags),
      'author_id', x.author_id, 'author', coalesce(nullif(btrim(a.name), ''), 'Membre'), 'author_role', a.role::text, 'author_certified', a.certification::text = 'approved',
      'community', x.community_id is not null, 'repost', x.repost_of is not null,
      'listing', (select l.title from listings l where l.id = x.listing_id),
      'media', coalesce(nullif((select jsonb_agg(jsonb_build_object('path', pm.path, 'kind', pm.kind) order by pm.pos) from post_media pm where pm.post_id = x.id), 'null'::jsonb),
                        case when x.media_path is not null then jsonb_build_array(jsonb_build_object('path', x.media_path, 'kind', x.media_kind)) else '[]'::jsonb end),
      'reports', (select count(*)::int from post_reports r where r.post_id = x.id and r.status = 'open'),
      'reasons', coalesce((select jsonb_agg(r.reason order by r.created_at desc) from post_reports r where r.post_id = x.id and r.status = 'open'), '[]'::jsonb)
    ) order by x.sort_at desc)
    from (
      select p.*, case when v_status = 'pending' then p.created_at
                       else coalesce((select max(r.created_at) from post_reports r where r.post_id = p.id and r.status = 'open'), p.created_at) end as sort_at
      from posts p
      where case v_status
              when 'pending' then p.status = 'pending'
              when 'hidden' then p.status = 'hidden'
              else p.status = 'published' and exists (select 1 from post_reports r where r.post_id = p.id and r.status = 'open') end
      order by sort_at desc
      limit least(greatest(coalesce(p_limit, 50), 1), 100)
    ) x join profiles a on a.id = x.author_id
  ), '[]'::jsonb);
end $$;

-- Valider ou refuser (motif obligatoire) ; l'auteur est prévenu, les signalements ouverts sont clos et leurs auteurs informés.
create or replace function moderate_post(p_post uuid, p_publish boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare p posts%rowtype; r record; v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  select * into p from posts where id = p_post for update;
  if not found then raise exception 'Publication introuvable'; end if;
  if not p_publish and char_length(coalesce(v_note, '')) < 3 then raise exception 'Motif obligatoire'; end if;
  update posts set status = case when p_publish then 'published' else 'hidden' end, published_at = case when p_publish then coalesce(p.published_at, now()) else p.published_at end,
    review_note = v_note where id = p.id;
  for r in select reporter_id from post_reports where post_id = p.id and status = 'open' loop
    perform notify_user(r.reporter_id, 'moderation', 'Signalement examiné',
      case when p_publish then 'La publication signalée a été examinée : elle reste en ligne.' else 'La publication signalée a été masquée. Merci de votre vigilance.' end,
      jsonb_build_object('post', p.id));
  end loop;
  update post_reports set status = 'closed' where post_id = p.id and status = 'open';
  insert into notifications (user_id, kind, title, body, data)
    values (p.author_id, 'post', case when p_publish then 'Publication en ligne' else 'Publication masquée' end, coalesce(v_note, left(p.caption, 120)),
            jsonb_build_object('post_id', p.id, 'post', p.id, 'status', case when p_publish then 'published' else 'hidden' end));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case when p_publish then 'Publication validée' else 'Publication masquée' end, p.id::text, 'Modération', 'Normal');
  return case when p_publish then 'published' else 'hidden' end;
end $$;

-- Classer les signalements d'une publication sans la masquer.
create or replace function post_reports_dismiss(p_post uuid, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare r record; n int := 0;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  if not exists (select 1 from posts where id = p_post) then raise exception 'Publication introuvable'; end if;
  for r in select reporter_id from post_reports where post_id = p_post and status = 'open' loop
    perform notify_user(r.reporter_id, 'moderation', 'Signalement examiné', 'La publication signalée a été examinée : elle respecte les règles et reste en ligne.', jsonb_build_object('post', p_post));
    n := n + 1;
  end loop;
  update post_reports set status = 'closed' where post_id = p_post and status = 'open';
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Signalements de publication classés', p_post::text, 'Modération', 'Normal');
  return 'closed';
end $$;

-- ------------------------------------------------------------------ 2. histoires
create table if not exists story_reports (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 3 and 300),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  unique (story_id, reporter_id)
);
alter table story_reports enable row level security;
revoke all on story_reports from anon, authenticated;

create or replace function report_story(p_story uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare s stories%rowtype; m record; ins int; v_reason text := btrim(coalesce(p_reason, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if char_length(v_reason) not between 3 and 300 then raise exception 'Indiquez un motif de 3 à 300 caractères'; end if;
  select * into s from stories where id = p_story and status = 'visible' and expires_at > now();
  if not found then raise exception 'Histoire introuvable'; end if;
  if s.author_id = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre histoire'; end if;
  insert into story_reports (story_id, reporter_id, reason) values (p_story, auth.uid(), v_reason) on conflict (story_id, reporter_id) do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select p.id from profiles p where p.role::text in ('dept', 'admin', 'support') and not p.suspended
             and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'report' and x.read_at is null and x.created_at > now() - interval '15 minutes') loop
      perform notify_user(m.id, 'report', 'Histoire signalée', 'Une histoire a été signalée et attend un examen.', jsonb_build_object('story', p_story));
    end loop;
  end if;
  return 'reported';
end $$;

-- Histoires actives, les plus signalées d'abord (la modération peut aussi masquer une histoire non signalée).
create or replace function moderation_stories_list(p_limit integer default 60) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', x.id, 'author_id', x.author_id, 'author', coalesce(nullif(btrim(a.name), ''), 'Membre'), 'media_path', x.media_path, 'media_kind', x.media_kind,
      'caption', x.caption, 'created_at', x.created_at, 'expires_at', x.expires_at, 'status', x.status,
      'reports', (select count(*)::int from story_reports r where r.story_id = x.id and r.status = 'open'),
      'reasons', coalesce((select jsonb_agg(r.reason order by r.created_at desc) from story_reports r where r.story_id = x.id and r.status = 'open'), '[]'::jsonb)
    ) order by x.nb desc, x.created_at desc)
    from (select s.*, (select count(*) from story_reports r where r.story_id = s.id and r.status = 'open') nb
          from stories s where s.expires_at > now() and (s.status = 'visible' or exists (select 1 from story_reports r where r.story_id = s.id and r.status = 'open'))
          order by nb desc, s.created_at desc limit least(greatest(coalesce(p_limit, 60), 1), 100)) x
    join profiles a on a.id = x.author_id
  ), '[]'::jsonb);
end $$;

create or replace function moderate_story(p_story uuid, p_hide boolean, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare s stories%rowtype; r record; v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  select * into s from stories where id = p_story for update;
  if not found then raise exception 'Histoire introuvable'; end if;
  if coalesce(p_hide, false) and char_length(coalesce(v_note, '')) < 3 then raise exception 'Motif obligatoire'; end if;
  update stories set status = case when coalesce(p_hide, false) then 'hidden' else 'visible' end where id = p_story;
  for r in select reporter_id from story_reports where story_id = p_story and status = 'open' loop
    perform notify_user(r.reporter_id, 'moderation', 'Signalement examiné',
      case when coalesce(p_hide, false) then 'L''histoire signalée a été retirée. Merci de votre vigilance.' else 'L''histoire signalée a été examinée : elle reste en ligne.' end,
      jsonb_build_object('story', p_story));
  end loop;
  update story_reports set status = 'closed' where story_id = p_story and status = 'open';
  if coalesce(p_hide, false) then
    perform notify_user(s.author_id, 'moderation', 'Histoire retirée', 'Votre histoire a été retirée par la modération : ' || v_note, jsonb_build_object('story', p_story));
  end if;
  insert into audit_log (actor, action, target, category, level)
    values (auth.uid()::text, case when coalesce(p_hide, false) then 'Histoire masquée' else 'Histoire conservée' end, p_story::text, 'Modération', 'Normal');
  return case when coalesce(p_hide, false) then 'hidden' else 'visible' end;
end $$;

-- ------------------------------------------------------------------ 3. communautés : chat, questions, publications
alter table community_messages add column if not exists removed_at timestamptz;
alter table community_messages add column if not exists removed_by uuid references profiles(id) on delete set null;
alter table community_messages add column if not exists removal_note text;
alter table community_questions add column if not exists removed_at timestamptz;
alter table community_questions add column if not exists removed_by uuid references profiles(id) on delete set null;
alter table community_questions add column if not exists removal_note text;
alter table community_answers add column if not exists removed_at timestamptz;
alter table community_answers add column if not exists removed_by uuid references profiles(id) on delete set null;
alter table community_answers add column if not exists removal_note text;

create or replace function community_chat_list(p_community uuid, p_after bigint default 0, p_limit integer default 60)
returns table (id bigint, sender_id uuid, author text, body text, created_at timestamptz, mine boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  return query
    select x.id, x.sender_id, display_name(x.sender_id), x.body, x.created_at, x.sender_id = auth.uid()
    from (select m.* from community_messages m where m.community_id = p_community and m.removed_at is null and (coalesce(p_after, 0) = 0 or m.id > p_after)
          order by m.id desc limit least(greatest(coalesce(p_limit, 60), 1), 200)) x
    order by x.id;
end $$;

create or replace function community_qa(p_community uuid, p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c communities%rowtype;
begin
  select * into c from communities where id = p_community and status = 'active';
  if not found then raise exception 'Communauté introuvable'; end if;
  if c.privacy <> 'public' and not is_community_member(p_community) and not is_platform_staff() then raise exception 'Réservé aux membres de la communauté'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', q.id, 'body', q.body, 'author', display_name(q.author_id), 'author_id', q.author_id, 'created_at', q.created_at, 'solved', q.accepted_answer is not null,
      'accepted_answer', q.accepted_answer, 'mine', q.author_id = auth.uid(),
      'answers', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'body', a.body, 'author', display_name(a.author_id), 'created_at', a.created_at,
                                                               'accepted', a.id = q.accepted_answer, 'mine', a.author_id = auth.uid()) order by (a.id = q.accepted_answer) desc, a.created_at)
                           from community_answers a where a.question_id = q.id and a.removed_at is null), '[]'::jsonb)
    ) order by q.created_at desc)
    from (select * from community_questions where community_id = p_community and removed_at is null order by created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 100)) q
  ), '[]'::jsonb);
end $$;

-- Retrait d'un contenu de communauté (interne) : son auteur ou un responsable (propriétaire, administrateur, modérateur) ou l'équipe de la plateforme.
-- p_kind : chat | question | answer. Renvoie l'identifiant de la communauté.
create or replace function _community_content_remove(p_kind text, p_ref text, p_note text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_comm uuid; v_author uuid; v_note text := nullif(btrim(coalesce(p_note, '')), ''); v_label text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind = 'chat' then
    select community_id, sender_id into v_comm, v_author from community_messages where id = p_ref::bigint and removed_at is null;
    v_label := 'message';
  elsif p_kind = 'question' then
    select community_id, author_id into v_comm, v_author from community_questions where id = p_ref::uuid and removed_at is null;
    v_label := 'question';
  elsif p_kind = 'answer' then
    select q.community_id, a.author_id into v_comm, v_author from community_answers a join community_questions q on q.id = a.question_id where a.id = p_ref::uuid and a.removed_at is null;
    v_label := 'réponse';
  else
    raise exception 'Contenu inconnu';
  end if;
  if v_comm is null then raise exception 'Contenu introuvable'; end if;
  if v_author <> auth.uid() and community_rank(v_comm, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if v_author <> auth.uid() and char_length(coalesce(v_note, '')) < 3 then raise exception 'Indiquez le motif du retrait'; end if;
  if p_kind = 'chat' then
    update community_messages set removed_at = now(), removed_by = auth.uid(), removal_note = v_note where id = p_ref::bigint;
  elsif p_kind = 'question' then
    update community_questions set removed_at = now(), removed_by = auth.uid(), removal_note = v_note where id = p_ref::uuid;
  else
    update community_answers set removed_at = now(), removed_by = auth.uid(), removal_note = v_note where id = p_ref::uuid;
    update community_questions set accepted_answer = null where accepted_answer = p_ref::uuid;
  end if;
  if v_author <> auth.uid() then
    perform notify_user(v_author, 'community_moderation', 'Contenu retiré', 'Votre ' || v_label || ' a été retiré par la modération de la communauté : ' || v_note, jsonb_build_object('community', v_comm));
  end if;
  return v_comm;
end $$;
revoke all on function _community_content_remove(text, text, text) from public, anon, authenticated;

create or replace function community_chat_delete(p_message bigint, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
begin
  perform _community_content_remove('chat', p_message::text, p_note);
  return 'removed';
end $$;

create or replace function community_question_delete(p_question uuid, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
begin
  perform _community_content_remove('question', p_question::text, p_note);
  return 'removed';
end $$;

create or replace function community_answer_delete(p_answer uuid, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
begin
  perform _community_content_remove('answer', p_answer::text, p_note);
  return 'removed';
end $$;

-- Signalements des membres sur les contenus d'une communauté.
create table if not exists community_reports (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('chat', 'question', 'answer', 'post')),
  ref text not null check (char_length(ref) between 1 and 60),
  reason text not null check (char_length(btrim(reason)) between 3 and 300),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  unique (reporter_id, kind, ref)
);
create index if not exists community_reports_open on community_reports (community_id, status, created_at desc);
alter table community_reports enable row level security;
revoke all on community_reports from anon, authenticated;

create or replace function community_report(p_community uuid, p_kind text, p_ref text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare v_author uuid; v_comm uuid; v_reason text := btrim(coalesce(p_reason, '')); m record; ins int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_reason) not between 3 and 300 then raise exception 'Indiquez un motif de 3 à 300 caractères'; end if;
  if p_kind = 'chat' then
    select community_id, sender_id into v_comm, v_author from community_messages where id = p_ref::bigint and removed_at is null;
  elsif p_kind = 'question' then
    select community_id, author_id into v_comm, v_author from community_questions where id = p_ref::uuid and removed_at is null;
  elsif p_kind = 'answer' then
    select q.community_id, a.author_id into v_comm, v_author from community_answers a join community_questions q on q.id = a.question_id where a.id = p_ref::uuid and a.removed_at is null;
  elsif p_kind = 'post' then
    select community_id, author_id into v_comm, v_author from posts where id = p_ref::uuid and status = 'published';
  else
    raise exception 'Contenu inconnu';
  end if;
  if v_comm is distinct from p_community then raise exception 'Contenu introuvable'; end if;
  if v_author = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre contenu'; end if;
  insert into community_reports (community_id, reporter_id, kind, ref, reason) values (p_community, auth.uid(), p_kind, p_ref, v_reason) on conflict (reporter_id, kind, ref) do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select cm.user_id from community_members cm where cm.community_id = p_community and cm.status = 'active' and cm.role in ('owner', 'admin', 'moderator')
             and not exists (select 1 from notifications x where x.user_id = cm.user_id and x.kind = 'community_report' and x.read_at is null and x.created_at > now() - interval '15 minutes'
                             and x.data->>'community' = p_community::text) loop
      perform notify_user(m.user_id, 'community_report', 'Contenu signalé', 'Un contenu a été signalé dans votre communauté et attend un examen.', jsonb_build_object('community', p_community));
    end loop;
  end if;
  return 'reported';
end $$;

create or replace function community_reports_list(p_community uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id, 'kind', r.kind, 'ref', r.ref, 'reason', r.reason, 'reporter', display_name(r.reporter_id), 'created_at', r.created_at,
      'preview', case r.kind
        when 'chat' then (select left(m.body, 200) from community_messages m where m.id = r.ref::bigint and m.removed_at is null)
        when 'question' then (select left(q.body, 200) from community_questions q where q.id = r.ref::uuid and q.removed_at is null)
        when 'answer' then (select left(a.body, 200) from community_answers a where a.id = r.ref::uuid and a.removed_at is null)
        else (select left(coalesce(p.body, p.caption, ''), 200) from posts p where p.id = r.ref::uuid and p.status = 'published') end,
      'author', case r.kind
        when 'chat' then (select display_name(m.sender_id) from community_messages m where m.id = r.ref::bigint)
        when 'question' then (select display_name(q.author_id) from community_questions q where q.id = r.ref::uuid)
        when 'answer' then (select display_name(a.author_id) from community_answers a where a.id = r.ref::uuid)
        else (select display_name(p.author_id) from posts p where p.id = r.ref::uuid) end
    ) order by r.created_at desc)
    from (select * from community_reports where community_id = p_community and status = 'open' order by created_at desc limit 100) r
  ), '[]'::jsonb);
end $$;

-- Décision d'un responsable : retirer le contenu signalé (motif obligatoire) ou classer le signalement ; les signalements du même contenu sont clos ensemble.
create or replace function community_report_close(p_report uuid, p_remove boolean, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare r community_reports%rowtype; x record; v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into r from community_reports where id = p_report and status = 'open';
  if not found then raise exception 'Signalement introuvable'; end if;
  if community_rank(r.community_id, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if coalesce(p_remove, false) then
    if char_length(coalesce(v_note, '')) < 3 then raise exception 'Indiquez le motif du retrait'; end if;
    if r.kind = 'post' then
      perform moderate_community_post(r.ref::uuid, true, v_note);
    else
      perform _community_content_remove(r.kind, r.ref, v_note);
    end if;
  end if;
  for x in select reporter_id from community_reports where community_id = r.community_id and kind = r.kind and ref = r.ref and status = 'open' loop
    perform notify_user(x.reporter_id, 'moderation', 'Signalement examiné',
      case when coalesce(p_remove, false) then 'Le contenu signalé a été retiré. Merci de votre vigilance.' else 'Le contenu signalé a été examiné : il respecte les règles de la communauté.' end,
      jsonb_build_object('community', r.community_id));
  end loop;
  update community_reports set status = 'closed' where community_id = r.community_id and kind = r.kind and ref = r.ref and status = 'open';
  return case when coalesce(p_remove, false) then 'removed' else 'closed' end;
end $$;

-- Masquage (ou rétablissement) d'une publication de communauté, avec motif et notification à l'auteur.
drop function if exists moderate_community_post(uuid, boolean);
create or replace function moderate_community_post(p_post uuid, p_hide boolean, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_comm uuid; v_author uuid; v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select community_id, author_id into v_comm, v_author from posts where id = p_post and kind in ('text', 'poll');
  if v_comm is null then raise exception 'Publication introuvable'; end if;
  if community_rank(v_comm, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if coalesce(p_hide, false) and char_length(coalesce(v_note, '')) < 3 and auth.uid() <> v_author then raise exception 'Indiquez le motif du masquage'; end if;
  update posts set status = case when p_hide then 'hidden' else 'published' end,
    review_note = case when p_hide then coalesce(v_note, 'Masquée par la modération de la communauté') else null end where id = p_post;
  if p_hide then
    perform notify_user(v_author, 'community_moderation', 'Publication masquée', 'Votre publication a été masquée par la modération de la communauté : ' || coalesce(v_note, 'sans précision') || '.', jsonb_build_object('community', v_comm, 'post', p_post));
  else
    perform notify_user(v_author, 'community_moderation', 'Publication rétablie', 'Votre publication a été rétablie par la modération de la communauté.', jsonb_build_object('community', v_comm, 'post', p_post));
  end if;
  return case when p_hide then 'hidden' else 'published' end;
end $$;

-- Publications masquées d'une communauté (pour les rétablir).
create or replace function community_hidden_posts(p_community uuid, p_limit integer default 30)
returns table (id uuid, author text, body text, published_at timestamptz, note text)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return query
    select p.id, display_name(p.author_id), coalesce(p.body, ''), p.published_at, p.review_note
    from posts p where p.community_id = p_community and p.kind in ('text', 'poll') and p.status = 'hidden'
    order by p.published_at desc nulls last limit least(greatest(coalesce(p_limit, 30), 1), 100);
end $$;

revoke all on function moderation_posts_list(text, integer), moderate_post(uuid, boolean, text), post_reports_dismiss(uuid, text), report_story(uuid, text),
  moderation_stories_list(integer), moderate_story(uuid, boolean, text), community_chat_list(uuid, bigint, integer),
  community_chat_delete(bigint, text), community_question_delete(uuid, text), community_answer_delete(uuid, text), community_report(uuid, text, text, text),
  community_reports_list(uuid), community_report_close(uuid, boolean, text), moderate_community_post(uuid, boolean, text), community_hidden_posts(uuid, integer)
  from public, anon;
grant execute on function moderation_posts_list(text, integer), moderate_post(uuid, boolean, text), post_reports_dismiss(uuid, text), report_story(uuid, text),
  moderation_stories_list(integer), moderate_story(uuid, boolean, text), community_chat_list(uuid, bigint, integer),
  community_chat_delete(bigint, text), community_question_delete(uuid, text), community_answer_delete(uuid, text), community_report(uuid, text, text, text),
  community_reports_list(uuid), community_report_close(uuid, boolean, text), moderate_community_post(uuid, boolean, text), community_hidden_posts(uuid, integer)
  to authenticated;
revoke all on function community_qa(uuid, integer) from public;
grant execute on function community_qa(uuid, integer) to anon, authenticated;
