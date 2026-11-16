-- Réseau social : gardes d'appartenance sur les publications de communautés non publiques (S7-63 / SQL1-18) et annuaire d'invitation borné (S7-64).
--  1. _post_accessible(p_post) : une publication de communauté n'est accessible qu'aux membres actifs (ou à la modération), comme la politique « publications visibles ».
--     Appliquée à : add_post_comment(_v2), post_comment_list(_v2), toggle_comment_like, toggle_post_like, toggle_post_save, react_post, record_post_share,
--     report_post, report_comment, create_post_v2 (republication), create_remix, circle_feed, post_shop_target.
--  2. Republier une publication de communauté est refusé ; le fil public n'affiche plus le contenu d'une publication de communauté republiée.
--  3. Commentaires : auteur suspendu ou bloqué non listé ; commenter un auteur qui vous a bloqué (ou l'inverse) est refusé.
--  4. community_invite_search : minimum 3 caractères, 10 résultats au plus, personnes que l'on peut légitimement inviter seulement (pas l'équipe de la plateforme,
--     ni les comptes suspendus ou bloqués ; liées à l'inviteur par une communauté commune, un abonnement ou le même département) ; invite_member : quota et blocage.
-- Retour arrière : recréer les fonctions listées depuis 20261103000000, 20261110000000, 20261113000000, 20261113000100, 20261114002400, 20261115170000, 20261115180000
--   et 20261103000100 (invite_member) ; drop function _post_accessible(uuid) ; alter table community_members drop column invited_by.

create or replace function _post_accessible(p_post uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from posts p
    where p.id = p_post and p.status = 'published'
      and (p.community_id is null
           or (exists (select 1 from communities c where c.id = p.community_id and c.privacy = 'public' and c.status = 'active')
               and not exists (select 1 from community_members m where m.community_id = p.community_id and m.user_id = auth.uid() and m.status = 'banned'))
           or is_community_member(p.community_id)
           or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support')))
$$;
revoke all on function _post_accessible(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ commentaires
create or replace function add_post_comment(p_post uuid, p_body text, p_parent uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  if is_blocked_between(auth.uid(), (select author_id from posts where id = p_post)) then raise exception 'Commentaire impossible sur cette publication'; end if;
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

create or replace function add_post_comment_v2(p_post uuid, p_body text, p_parent uuid default null, p_attachment_path text default null, p_attachment_kind text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_root uuid := p_parent; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  if is_blocked_between(auth.uid(), (select author_id from posts where id = p_post)) then raise exception 'Commentaire impossible sur cette publication'; end if;
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

create or replace function post_comment_list(p_post uuid, p_limit integer default 50)
returns table (id uuid, parent_id uuid, author text, mine boolean, body text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.parent_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         c.author_id = auth.uid(), c.body, c.created_at
  from post_comments c join profiles a on a.id = c.author_id join posts p on p.id = c.post_id
  where c.post_id = p_post and c.status = 'visible' and _post_accessible(p.id) and not coalesce(a.suspended, false) and not is_blocked_between(auth.uid(), c.author_id)
  order by c.created_at
  limit least(greatest(coalesce(p_limit, 50), 1), 200)
$$;
grant execute on function post_comment_list(uuid, integer) to anon;

create or replace function post_comment_list_v2(p_post uuid, p_limit integer default 100)
returns table (id uuid, parent_id uuid, author text, author_id uuid, author_avatar text, author_verified boolean, mine boolean, body text, created_at timestamptz,
               likes integer, liked boolean, attachment_path text, attachment_kind text)
language sql stable security definer set search_path = public as $$
  select c.id, c.parent_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), case when a.role::text = 'student' then 'Étudiant' else 'Membre' end),
         c.author_id, a.avatar_url, a.certification::text = 'approved', c.author_id = auth.uid(), c.body, c.created_at,
         (select count(*)::int from comment_likes k where k.comment_id = c.id),
         exists (select 1 from comment_likes k where k.comment_id = c.id and k.user_id = auth.uid()),
         c.attachment_path, c.attachment_kind
  from post_comments c join profiles a on a.id = c.author_id join posts p on p.id = c.post_id
  where c.post_id = p_post and c.status = 'visible' and _post_accessible(p.id) and not coalesce(a.suspended, false) and not is_blocked_between(auth.uid(), c.author_id)
  order by c.created_at
  limit least(greatest(coalesce(p_limit, 100), 1), 300)
$$;
grant execute on function post_comment_list_v2(uuid, integer) to anon, authenticated;

create or replace function toggle_comment_like(p_comment uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from post_comments c where c.id = p_comment and c.status = 'visible' and _post_accessible(c.post_id)) then raise exception 'Commentaire introuvable'; end if;
  if exists (select 1 from comment_likes where comment_id = p_comment and user_id = auth.uid()) then
    delete from comment_likes where comment_id = p_comment and user_id = auth.uid();
    return false;
  end if;
  insert into comment_likes (comment_id, user_id) values (p_comment, auth.uid());
  return true;
end $$;

-- ------------------------------------------------------------------ mentions j'aime, réactions, enregistrements, partages, signalements
create or replace function toggle_post_like(p_post uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  if exists (select 1 from post_likes where post_id = p_post and user_id = auth.uid()) then
    delete from post_likes where post_id = p_post and user_id = auth.uid();
    return false;
  end if;
  insert into post_likes (post_id, user_id) values (p_post, auth.uid());
  return true;
end $$;

create or replace function toggle_post_save(p_post uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
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
  if not _post_accessible(p_post) then return; end if;
  insert into post_shares (post_id, user_id) values (p_post, auth.uid()) on conflict do nothing;
end $$;

create or replace function react_post(p_post uuid, p_kind text) returns text
language plpgsql security definer set search_path = public as $$
declare cur text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('like', 'love', 'haha', 'wow', 'sad', 'fire', 'clap') then raise exception 'Réaction invalide'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  select kind into cur from post_reactions where post_id = p_post and user_id = auth.uid();
  if cur = p_kind then
    delete from post_reactions where post_id = p_post and user_id = auth.uid();
    delete from post_likes where post_id = p_post and user_id = auth.uid();
    return 'retirée';
  end if;
  insert into post_reactions (post_id, user_id, kind) values (p_post, auth.uid(), p_kind)
  on conflict (post_id, user_id) do update set kind = excluded.kind, created_at = now();
  insert into post_likes (post_id, user_id) values (p_post, auth.uid()) on conflict do nothing;
  return 'enregistrée';
end $$;

create or replace function report_post(p_post uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare m record; ins int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  insert into post_reports (post_id, reporter_id, reason) values (p_post, auth.uid(), trim(p_reason))
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

create or replace function report_comment(p_comment uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare c post_comments%rowtype; m record; ins int; v_reason text := btrim(coalesce(p_reason, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if char_length(v_reason) not between 3 and 300 then raise exception 'Indiquez un motif de 3 à 300 caractères'; end if;
  select * into c from post_comments where id = p_comment and status = 'visible';
  if not found or not _post_accessible(c.post_id) then raise exception 'Commentaire introuvable'; end if;
  if c.author_id = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre commentaire'; end if;
  insert into comment_reports (comment_id, reporter_id, reason) values (p_comment, auth.uid(), v_reason) on conflict (comment_id, reporter_id) do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select p.id from profiles p where p.role::text in ('dept', 'admin', 'support') and not p.suspended
             and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'report' and x.read_at is null and x.created_at > now() - interval '15 minutes') loop
      perform notify_user(m.id, 'report', 'Commentaire signalé', 'Un commentaire a été signalé et attend un examen.', jsonb_build_object('post', c.post_id, 'comment', c.id));
    end loop;
  end if;
  return 'reported';
end $$;

-- ------------------------------------------------------------------ republication, duo / remix, boutique liée
create or replace function create_post_v2(p_caption text, p_media jsonb, p_link text, p_tags text[], p_listing uuid, p_repost_of uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; pid uuid; st text; m jsonb; i int := 0; n int; first_path text; first_kind text; txt text; lnk text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Compte suspendu : publication impossible'; end if;
  p_media := coalesce(p_media, '[]'::jsonb);
  if jsonb_typeof(p_media) <> 'array' then raise exception 'Médias invalides'; end if;
  n := jsonb_array_length(p_media);
  if n > 10 then raise exception '10 médias au plus par publication'; end if;
  txt := left(btrim(coalesce(p_caption, '')), 2000);
  lnk := nullif(btrim(coalesce(p_link, '')), '');
  if lnk is not null and lnk !~* '^https?://[^[:space:]]+$' or char_length(lnk) > 480 then raise exception 'Lien invalide : il doit commencer par http:// ou https://'; end if;
  if n = 0 and txt = '' and lnk is null and p_repost_of is null then raise exception 'Écrivez un texte ou ajoutez un média, un lien ou une republication'; end if;
  if p_repost_of is not null and not exists (select 1 from posts where id = p_repost_of and status = 'published' and community_id is null) then
    raise exception 'Publication à republier introuvable ou non republiable';
  end if;
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
revoke all on function create_post_v2(text, jsonb, text, text[], uuid, uuid) from public, anon;
grant execute on function create_post_v2(text, jsonb, text, text[], uuid, uuid) to authenticated;

create or replace function create_remix(p_original uuid, p_kind text, p_path text, p_caption text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare res jsonb; orig posts%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('duet', 'remix') then raise exception 'Type invalide'; end if;
  select * into orig from posts where id = p_original and status = 'published' and media_kind = 'video' and community_id is null;
  if not found then raise exception 'La vidéo d''origine est introuvable'; end if;
  res := create_post_v2(p_caption, jsonb_build_array(jsonb_build_object('path', p_path, 'kind', 'video')), null, '{}'::text[], null, null);
  update posts set remix_of = p_original, remix_kind = p_kind where id = (res->>'id')::uuid;
  return res;
end $$;
revoke all on function create_remix(uuid, text, text, text) from public, anon;
grant execute on function create_remix(uuid, text, text, text) to authenticated;

create or replace function post_shop_target(p_post uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('listing_id', l.id, 'shop_slug', coalesce(s.slug, (select o.slug from shops o where o.owner_id = p.author_id and o.status = 'active' limit 1)), 'seller_id', p.author_id)
  from posts p
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  left join shops s on s.id = l.shop_id and s.status = 'active'
  where p.id = p_post and _post_accessible(p.id)
$$;
grant execute on function post_shop_target(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ fil public : republications de communauté masquées, auteurs bloqués filtrés
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
         (select count(*)::int from post_comments c where c.post_id = p.id and c.status = 'visible'),
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
  join profiles a on a.id = p.author_id and not a.suspended
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  left join posts rp on rp.id = p.repost_of and rp.status = 'published' and rp.community_id is null
  left join profiles ra on ra.id = rp.author_id
  where p.status = 'published' and p.community_id is null
    and not exists (select 1 from posts o where o.id = p.repost_of and o.community_id is not null)
    and (p.repost_of is null or rp.id is not null or nullif(btrim(coalesce(p.body, '')), '') is not null or p.link_url is not null)
    and not is_blocked_between(auth.uid(), p.author_id)
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
grant execute on function circle_feed(integer) to anon, authenticated;

-- ------------------------------------------------------------------ invitations : annuaire borné
alter table community_members add column if not exists invited_by uuid references profiles(id) on delete set null;

-- Personnes que l'on peut légitimement inviter : hors équipe de la plateforme, ni suspendues ni bloquées, et liées à l'inviteur (communauté commune, abonnement
-- dans un sens ou l'autre, ou même département). Minimum 3 caractères, 10 résultats au plus, noms abrégés.
create or replace function _community_invitable(p_community uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles t
    where t.id = p_user and t.id <> auth.uid() and not coalesce(t.suspended, false)
      and t.role::text in ('student', 'client', 'company', 'other')
      and not exists (select 1 from user_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = t.id) or (b.blocker_id = t.id and b.blocked_id = auth.uid()))
      and not exists (select 1 from community_members m where m.community_id = p_community and m.user_id = t.id)
      and (
        exists (select 1 from community_members a join community_members b on b.community_id = a.community_id and b.user_id = t.id and b.status = 'active'
                where a.user_id = auth.uid() and a.status = 'active')
        or exists (select 1 from engagements e where e.kind = 'follow' and e.status = 'active'
                   and ((e.user_id = auth.uid() and e.ref = t.id::text) or (e.user_id = t.id and e.ref = auth.uid()::text)))
        or (t.role::text = 'student' and nullif(btrim(coalesce(t.department, '')), '') is not null
            and exists (select 1 from profiles me where me.id = auth.uid() and lower(btrim(coalesce(me.department, ''))) = lower(btrim(t.department))))
      )
  )
$$;
revoke all on function _community_invitable(uuid, uuid) from public, anon, authenticated;

create or replace function community_invite_search(p_community uuid, p_q text, p_limit integer default 10)
returns table (user_id uuid, name text, department text)
language plpgsql stable security definer set search_path = public as $$
declare v_q text := replace(replace(replace(btrim(coalesce(p_q, '')), '\', '\\'), '%', '\%'), '_', '\_');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 then raise exception 'Action non autorisée'; end if;
  if char_length(btrim(coalesce(p_q, ''))) < 3 then return; end if;
  return query
    select p.id, display_name(p.id), coalesce(p.department, '')
    from profiles p
    where p.name ilike '%' || v_q || '%' and _community_invitable(p_community, p.id)
    order by p.name
    limit least(greatest(coalesce(p_limit, 10), 1), 10);
end $$;
revoke all on function community_invite_search(uuid, text, integer) from public, anon;
grant execute on function community_invite_search(uuid, text, integer) to authenticated;

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
  if exists (select 1 from user_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p_user) or (b.blocker_id = p_user and b.blocked_id = auth.uid())) then
    raise exception 'Cette personne ne peut pas être invitée';
  end if;
  if (select count(*) from community_members where invited_by = auth.uid() and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'Trop d''invitations en peu de temps. Réessayez plus tard.';
  end if;
  insert into community_members (community_id, user_id, role, status, invited_by) values (p_community, p_user, 'member', 'invited', auth.uid());
  perform notify_user(p_user, 'community_invite', 'Invitation', display_name(auth.uid()) || ' vous invite à rejoindre « ' || c.name || ' ».', jsonb_build_object('community', p_community));
  return 'invited';
end $$;
revoke all on function invite_member(uuid, uuid) from public, anon;
grant execute on function invite_member(uuid, uuid) to authenticated;

revoke all on function add_post_comment(uuid, text, uuid), add_post_comment_v2(uuid, text, uuid, text, text), toggle_comment_like(uuid), toggle_post_like(uuid),
  toggle_post_save(uuid), record_post_share(uuid), react_post(uuid, text), report_post(uuid, text), report_comment(uuid, text) from public, anon;
grant execute on function add_post_comment(uuid, text, uuid), add_post_comment_v2(uuid, text, uuid, text, text), toggle_comment_like(uuid), toggle_post_like(uuid),
  toggle_post_save(uuid), record_post_share(uuid), react_post(uuid, text), report_post(uuid, text), report_comment(uuid, text) to authenticated;
