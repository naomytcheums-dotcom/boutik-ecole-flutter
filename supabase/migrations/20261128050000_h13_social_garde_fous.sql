-- H13 SOCIAL 1/6 : garde-fous des publications, commentaires, réactions, partages et signalements.
--  * limites de débit serveur PAR HEURE (publications, commentaires, signalements), configurables dans platform_settings
--    (social.rate.posts_per_hour = 30, social.rate.comments_per_hour = 120, social.rate.reports_per_hour = 30 ; valeur invalide ou < 1 : défaut) ;
--    appliquées par déclencheur : couvre toutes les voies d'écriture (RPC, communautés, republication). Les écritures sans session (pg_cron, service) ne sont pas limitées.
--  * auteur bloqué : réactions, j'aime, partages, enregistrements et commentaires refusés quand un blocage existe entre la personne et l'auteur (dans les deux sens) ;
--  * cohérence j'aime / réaction : retirer un j'aime retire la réaction (et un j'aime sans réaction crée la réaction « like ») ;
--  * une publication RETIRÉE par son auteur ne peut plus être remise en ligne ni masquée par la modération (aucune résurrection) ;
--  * edit_my_post / edit_post_comment (auteur seulement, mêmes règles de longueur et de lien que la création, trop long = refusé et non tronqué ;
--    une publication déjà validée d'un compte non certifié repasse en validation) ; colonne edited_at ;
--  * react_post_set (idempotent : demander deux fois le même état ne change rien) et post_counters (compteurs lus avec les mêmes filtres que le fil).
-- Strictement additif. Retour arrière : drop trigger trg_h13_* (posts, post_comments, post_reports, comment_reports, post_reactions, post_likes, post_shares, post_saves) ;
--   drop function edit_my_post(uuid, text, text, text[]), edit_post_comment(uuid, text), react_post_set(uuid, text, boolean), post_counters(uuid), _social_rate_limit(text, integer, text, uuid),
--   _h13_rate_posts(), _h13_rate_comments(), _h13_rate_reports(), _h13_guard_blocked(), _h13_sync_like_reaction(), _h13_no_resurrection() ; alter table posts drop column edited_at ; alter table post_comments drop column edited_at.

alter table posts add column if not exists edited_at timestamptz;
alter table post_comments add column if not exists edited_at timestamptz;

insert into platform_settings (key, value) values
  ('social.rate.posts_per_hour', '30'::jsonb),
  ('social.rate.comments_per_hour', '120'::jsonb),
  ('social.rate.reports_per_hour', '30'::jsonb)
on conflict (key) do nothing;

-- ------------------------------------------------------------------ limite de débit
create or replace function _social_rate_limit(p_kind text, p_default integer, p_table text, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_max integer := p_default; v_val jsonb; v_count integer; v_since timestamptz := now() - interval '1 hour';
begin
  select value into v_val from platform_settings where key = 'social.rate.' || p_kind || '_per_hour';
  if v_val is not null and jsonb_typeof(v_val) = 'number' and (v_val #>> '{}')::numeric >= 1 then v_max := least((v_val #>> '{}')::numeric, 100000)::integer; end if;
  if p_table = 'posts' then select count(*) into v_count from posts where author_id = p_user and created_at > v_since;
  elsif p_table = 'post_comments' then select count(*) into v_count from post_comments where author_id = p_user and created_at > v_since;
  elsif p_table = 'post_reports' then
    select (select count(*) from post_reports where reporter_id = p_user and created_at > v_since) + (select count(*) from comment_reports where reporter_id = p_user and created_at > v_since) into v_count;
  else return; end if;
  if v_count >= v_max then
    raise exception 'Limite atteinte : % % par heure au plus. Réessayez plus tard.', v_max,
      case p_kind when 'posts' then 'publications' when 'comments' then 'commentaires' else 'signalements' end;
  end if;
end $$;
revoke all on function _social_rate_limit(text, integer, text, uuid) from public, anon, authenticated;

create or replace function _h13_rate_posts() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and auth.uid() = new.author_id then perform _social_rate_limit('posts', 30, 'posts', new.author_id); end if;
  return new;
end $$;
create or replace function _h13_rate_comments() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and auth.uid() = new.author_id then perform _social_rate_limit('comments', 120, 'post_comments', new.author_id); end if;
  return new;
end $$;
create or replace function _h13_rate_reports() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and auth.uid() = new.reporter_id then perform _social_rate_limit('reports', 30, 'post_reports', new.reporter_id); end if;
  return new;
end $$;
revoke all on function _h13_rate_posts(), _h13_rate_comments(), _h13_rate_reports() from public, anon, authenticated;

drop trigger if exists trg_h13_rate_posts on posts;
create trigger trg_h13_rate_posts before insert on posts for each row execute function _h13_rate_posts();
drop trigger if exists trg_h13_rate_comments on post_comments;
create trigger trg_h13_rate_comments before insert on post_comments for each row execute function _h13_rate_comments();
drop trigger if exists trg_h13_rate_post_reports on post_reports;
create trigger trg_h13_rate_post_reports before insert on post_reports for each row execute function _h13_rate_reports();
drop trigger if exists trg_h13_rate_comment_reports on comment_reports;
create trigger trg_h13_rate_comment_reports before insert on comment_reports for each row execute function _h13_rate_reports();

-- ------------------------------------------------------------------ auteur bloqué
create or replace function _h13_guard_blocked() returns trigger language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  if auth.uid() is null then return new; end if;
  select author_id into v_author from posts where id = new.post_id;
  if v_author is not null and v_author <> auth.uid() and exists (
       select 1 from user_blocks b where (b.blocker_id = v_author and b.blocked_id = auth.uid()) or (b.blocker_id = auth.uid() and b.blocked_id = v_author)) then
    raise exception 'Action impossible sur cette publication';
  end if;
  return new;
end $$;
revoke all on function _h13_guard_blocked() from public, anon, authenticated;
drop trigger if exists trg_h13_blocked_reactions on post_reactions;
create trigger trg_h13_blocked_reactions before insert on post_reactions for each row execute function _h13_guard_blocked();
drop trigger if exists trg_h13_blocked_likes on post_likes;
create trigger trg_h13_blocked_likes before insert on post_likes for each row execute function _h13_guard_blocked();
drop trigger if exists trg_h13_blocked_shares on post_shares;
create trigger trg_h13_blocked_shares before insert on post_shares for each row execute function _h13_guard_blocked();
drop trigger if exists trg_h13_blocked_saves on post_saves;
create trigger trg_h13_blocked_saves before insert on post_saves for each row execute function _h13_guard_blocked();

-- ------------------------------------------------------------------ j'aime et réaction restent cohérents
create or replace function _h13_sync_like_reaction() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into post_reactions (post_id, user_id, kind) values (new.post_id, new.user_id, 'like') on conflict (post_id, user_id) do nothing;
  else
    delete from post_reactions where post_id = old.post_id and user_id = old.user_id;
  end if;
  return null;
end $$;
revoke all on function _h13_sync_like_reaction() from public, anon, authenticated;
drop trigger if exists trg_h13_like_reaction on post_likes;
create trigger trg_h13_like_reaction after insert or delete on post_likes for each row execute function _h13_sync_like_reaction();

-- ------------------------------------------------------------------ une publication retirée ne revient jamais
create or replace function _h13_no_resurrection() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status = 'removed' and new.status <> 'removed' then
    raise exception 'Publication retirée par son auteur : elle ne peut plus être modifiée ni remise en ligne';
  end if;
  return new;
end $$;
revoke all on function _h13_no_resurrection() from public, anon, authenticated;
drop trigger if exists trg_h13_no_resurrection on posts;
create trigger trg_h13_no_resurrection before update of status on posts for each row execute function _h13_no_resurrection();

-- ------------------------------------------------------------------ modification par l'auteur
create or replace function edit_my_post(p_post uuid, p_caption text, p_link text default null, p_tags text[] default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; p posts%rowtype; txt text := btrim(coalesce(p_caption, '')); lnk text := nullif(btrim(coalesce(p_link, '')), ''); v_status text; v_tags text[];
begin
  perform _assert_active();
  select * into me from profiles where id = auth.uid();
  select * into p from posts where id = p_post and author_id = auth.uid() and status in ('pending', 'published', 'hidden') for update;
  if not found then raise exception 'Publication introuvable'; end if;
  if p.status = 'hidden' then raise exception 'Publication masquée par la modération : modification impossible'; end if;
  if p.community_id is not null and not is_community_member(p.community_id) then raise exception 'Publication introuvable'; end if;
  if lnk is not null and (lnk !~* '^https?://[^[:space:]]+$' or char_length(lnk) > 480) then raise exception 'Lien invalide : il doit commencer par http:// ou https://'; end if;
  if p.kind = 'text' then
    if char_length(txt) > 2000 then raise exception 'La publication ne peut dépasser 2000 caractères'; end if;
    if txt = '' and lnk is null and p.repost_of is null then raise exception 'Écrivez un texte ou ajoutez un lien'; end if;
  else
    if char_length(txt) > 300 then raise exception 'La légende ne peut dépasser 300 caractères'; end if;
  end if;
  if p_tags is not null then
    if cardinality(p_tags) > 10 then raise exception '10 étiquettes au plus'; end if;
    v_tags := coalesce((select array_agg(distinct lower(left(trim(t), 30))) from unnest(p_tags) t where trim(t) <> ''), '{}');
  end if;
  v_status := case when p.status = 'published' and not (me.certification = 'approved' or me.role::text in ('dept', 'admin')) then 'pending' else p.status end;
  update posts set caption = case when p.kind = 'text' then '' else txt end, body = case when p.kind = 'text' then nullif(txt, '') else body end,
    link_url = lnk, tags = coalesce(v_tags, tags), status = v_status, edited_at = now(),
    review_note = case when v_status <> p.status then 'Modifiée : en attente de nouvelle validation' else review_note end
  where id = p.id;
  return jsonb_build_object('id', p.id, 'status', v_status, 'edited', true);
end $$;
revoke all on function edit_my_post(uuid, text, text, text[]) from public, anon;
grant execute on function edit_my_post(uuid, text, text, text[]) to authenticated;

create or replace function edit_post_comment(p_comment uuid, p_body text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c post_comments%rowtype; v_body text := btrim(coalesce(p_body, ''));
begin
  perform _assert_active();
  select * into c from post_comments where id = p_comment and author_id = auth.uid() and status = 'visible' for update;
  if not found then raise exception 'Commentaire introuvable'; end if;
  if not _post_accessible(c.post_id) then raise exception 'Publication introuvable'; end if;
  if is_blocked_between(auth.uid(), (select author_id from posts where id = c.post_id)) then raise exception 'Commentaire impossible sur cette publication'; end if;
  if char_length(v_body) > 500 then raise exception 'Le commentaire ne peut dépasser 500 caractères'; end if;
  if v_body = '' and c.attachment_path is null then raise exception 'Écrivez un commentaire'; end if;
  if v_body <> c.body then update post_comments set body = v_body, edited_at = now() where id = c.id; end if;
  return jsonb_build_object('id', c.id, 'body', v_body, 'edited', v_body <> c.body or c.edited_at is not null);
end $$;
revoke all on function edit_post_comment(uuid, text) from public, anon;
grant execute on function edit_post_comment(uuid, text) to authenticated;

-- ------------------------------------------------------------------ réaction idempotente et compteurs
create or replace function react_post_set(p_post uuid, p_kind text, p_on boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_kind text; v_likes integer;
begin
  perform _assert_active();
  if coalesce(p_kind, '') not in ('like', 'love', 'haha', 'wow', 'sad', 'fire', 'clap') then raise exception 'Réaction invalide'; end if;
  if not _post_accessible(p_post) then raise exception 'Publication introuvable'; end if;
  if coalesce(p_on, true) then
    insert into post_reactions (post_id, user_id, kind) values (p_post, auth.uid(), p_kind)
      on conflict (post_id, user_id) do update set kind = excluded.kind, created_at = case when post_reactions.kind = excluded.kind then post_reactions.created_at else now() end;
    insert into post_likes (post_id, user_id) values (p_post, auth.uid()) on conflict do nothing;
    v_kind := p_kind;
  else
    delete from post_reactions where post_id = p_post and user_id = auth.uid() and kind = p_kind;
    if not exists (select 1 from post_reactions where post_id = p_post and user_id = auth.uid()) then
      delete from post_likes where post_id = p_post and user_id = auth.uid();
    else
      select kind into v_kind from post_reactions where post_id = p_post and user_id = auth.uid();
    end if;
  end if;
  select count(*)::int into v_likes from post_likes where post_id = p_post;
  return jsonb_build_object('post', p_post, 'kind', v_kind, 'reacted', v_kind is not null, 'likes', v_likes);
end $$;
revoke all on function react_post_set(uuid, text, boolean) from public, anon;
grant execute on function react_post_set(uuid, text, boolean) to authenticated;

create or replace function post_counters(p_post uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not _post_accessible(p_post) then null else jsonb_build_object(
    'post', p_post,
    'likes', (select count(*)::int from post_likes k where k.post_id = p_post),
    'comments', _post_comments_visible(p_post),
    'saves', (select count(*)::int from post_saves s where s.post_id = p_post),
    'shares', (select count(*)::int from post_shares h where h.post_id = p_post),
    'reposts', (select count(*)::int from posts r where r.repost_of = p_post and r.status = 'published'),
    'mine', jsonb_build_object(
      'kind', (select kind from post_reactions x where x.post_id = p_post and x.user_id = auth.uid()),
      'liked', exists (select 1 from post_likes k where k.post_id = p_post and k.user_id = auth.uid()),
      'saved', exists (select 1 from post_saves s where s.post_id = p_post and s.user_id = auth.uid()))) end
$$;
revoke all on function post_counters(uuid) from public;
grant execute on function post_counters(uuid) to anon, authenticated;
