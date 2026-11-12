-- Communautés : 5 types (filière, promo, centre d'intérêt, alumni, projet), badges, activité, publications avec fond design, sondages et annonces épinglées.
-- Non destructif : les communautés et publications existantes restent telles quelles (type « centre d'intérêt », sans fond).
-- Retour arrière : drop function pin_community_post(uuid, boolean), create_community_poll(uuid, text, text[], text), vote_community_poll(uuid, integer);
--   alter table posts drop column style, drop column pinned, drop column pinned_at; drop table community_poll_votes, community_polls;
--   alter table communities drop column kind, drop column promo_year, drop column interest, drop column official;
--   puis recréer create_community, create_community_post, community_feed et communities_list depuis 20261111000000_communautes_validation.sql et 20261103000100.

alter table communities add column if not exists kind text not null default 'interest' check (kind in ('filiere', 'promo', 'interest', 'alumni', 'project'));
alter table communities add column if not exists promo_year text check (promo_year is null or char_length(promo_year) <= 20);
alter table communities add column if not exists interest text check (interest is null or char_length(interest) <= 60);
alter table communities add column if not exists official boolean not null default false;   -- badge « Officiel IUT » (posé par l'équipe)

alter table posts add column if not exists style text check (style is null or style in ('sunset', 'ocean', 'forest', 'night', 'candy', 'paper', 'iut', 'fun', 'sober'));
alter table posts add column if not exists pinned boolean not null default false;
alter table posts add column if not exists pinned_at timestamptz;

-- sondages : une publication de type « poll » (la question est le texte) ; les options et les votes ont leurs tables
alter table posts drop constraint if exists posts_kind_check;
alter table posts add constraint posts_kind_check check (kind in ('media', 'text', 'poll'));
alter table posts drop constraint if exists posts_kind_contenu;
alter table posts add constraint posts_kind_contenu check (
  (kind = 'media' and media_path is not null and media_kind is not null) or (kind in ('text', 'poll') and nullif(btrim(coalesce(body, '')), '') is not null));

create table if not exists community_polls (
  post_id uuid primary key references posts(id) on delete cascade,
  options text[] not null check (cardinality(options) between 2 and 6)
);
create table if not exists community_poll_votes (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  option_index integer not null check (option_index between 0 and 5),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table community_polls enable row level security;
alter table community_poll_votes enable row level security;
revoke all on community_polls, community_poll_votes from anon, authenticated;

-- ---------------------------------------------------------------- création avec type
drop function if exists create_community(text, text, text, text, text, uuid);
create or replace function create_community(p_name text, p_description text default '', p_category text default '', p_privacy text default 'public', p_rules text default '', p_department uuid default null,
  p_kind text default 'interest', p_promo text default null, p_interest text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_words integer; r record; v_promo text := nullif(btrim(coalesce(p_promo, '')), ''); v_interest text := nullif(btrim(coalesce(p_interest, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Complétez votre profil avant cette action'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if p_kind not in ('filiere', 'promo', 'interest', 'alumni', 'project') then raise exception 'Type de communauté inconnu'; end if;
  if p_kind = 'promo' and v_promo is null then raise exception 'Indiquez la promotion (ex. Promo 2026)'; end if;
  if p_kind = 'interest' and v_interest is null then raise exception 'Indiquez le centre d''intérêt (ex. Dev Flutter)'; end if;
  if p_kind = 'filiere' and p_department is null then raise exception 'Choisissez la filière'; end if;
  v_words := case when btrim(coalesce(p_description, '')) = '' then 0 else cardinality(regexp_split_to_array(btrim(p_description), '\s+')) end;
  if v_words > 500 then raise exception 'La description ne doit pas dépasser 500 mots (% mots saisis)', v_words; end if;
  if p_department is not null and not exists (select 1 from departments where id = p_department and status = 'verified') then raise exception 'Département inconnu'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and status in ('pending', 'active')) >= 5 then raise exception 'Vous ne pouvez pas avoir plus de 5 communautés'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, category, rules, privacy, owner_id, department_id, status, kind, promo_year, interest)
    values (btrim(p_name), btrim(coalesce(p_description, '')), coalesce(p_category, ''), coalesce(p_rules, ''), p_privacy, auth.uid(), p_department, 'pending', p_kind, left(v_promo, 20), left(v_interest, 60)) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  for r in select id from profiles where role = 'admin' loop
    perform notify_user(r.id, 'community_validation', 'Communauté à valider', display_name(auth.uid()) || ' propose la communauté « ' || btrim(p_name) || ' ».', jsonb_build_object('community', v_id));
  end loop;
  return v_id;
end $$;
revoke all on function create_community(text, text, text, text, text, uuid, text, text, text) from public, anon;
grant execute on function create_community(text, text, text, text, text, uuid, text, text, text) to authenticated;

-- « Officiel IUT » : posé ou retiré par l'équipe de la plateforme
create or replace function community_set_official(p_community uuid, p_official boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  update communities set official = coalesce(p_official, false) where id = p_community;
  if not found then raise exception 'Communauté introuvable'; end if;
end $$;
revoke all on function community_set_official(uuid, boolean) from public, anon;
grant execute on function community_set_official(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------- annuaire enrichi (type, badges, activité, responsable)
drop function if exists communities_list(text, integer);
create or replace function communities_list(p_query text default '', p_limit integer default 30)
returns table (id uuid, name text, description text, category text, privacy text, members integer, my_status text, my_role text, status text, department text, decision_note text,
               kind text, promo_year text, interest text, official boolean, created_at timestamptz, last_activity timestamptz, posts_week integer, owner_kind text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.category, c.privacy,
         (select count(*)::int from community_members m where m.community_id = c.id and m.status = 'active'),
         (select m.status from community_members m where m.community_id = c.id and m.user_id = auth.uid()),
         (select m.role from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status = 'active'),
         c.status, d.name, c.decision_note,
         c.kind, c.promo_year, c.interest, c.official, c.created_at,
         (select max(p.published_at) from posts p where p.community_id = c.id and p.status = 'published'),
         (select count(*)::int from posts p where p.community_id = c.id and p.status = 'published' and p.published_at > now() - interval '7 days'),
         (select case when o.role::text in ('dept', 'direction') then 'teacher' when o.role::text = 'student' then 'student' else 'staff' end from profiles o where o.id = c.owner_id)
  from communities c left join departments d on d.id = c.department_id
  where (
      (c.status = 'active' and (c.privacy in ('public', 'approval') or exists (select 1 from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status in ('active', 'invited'))))
      or (c.owner_id = auth.uid() and c.status in ('pending', 'rejected'))
    )
    and (coalesce(btrim(p_query), '') = '' or c.name ilike '%' || btrim(p_query) || '%' or c.category ilike '%' || btrim(p_query) || '%' or d.name ilike '%' || btrim(p_query) || '%'
         or coalesce(c.interest, '') ilike '%' || btrim(p_query) || '%' or coalesce(c.promo_year, '') ilike '%' || btrim(p_query) || '%' or c.description ilike '%' || btrim(p_query) || '%')
  order by (c.status <> 'active') desc, 6 desc, c.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;
revoke all on function communities_list(text, integer) from public, anon;
grant execute on function communities_list(text, integer) to authenticated, anon;

-- ---------------------------------------------------------------- publications : fond design, épinglées, sondages
drop function if exists create_community_post(uuid, text);
create or replace function create_community_post(p_community uuid, p_body text, p_style text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 1 and 2000 then raise exception 'La publication doit contenir entre 1 et 2000 caractères'; end if;
  if p_style is not null and char_length(v_body) > 280 then raise exception 'Avec un fond design, le texte est limité à 280 caractères'; end if;
  if (select count(*) from posts where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de publications en peu de temps. Réessayez dans une minute.'; end if;
  insert into posts (author_id, kind, body, community_id, status, published_at, style) values (auth.uid(), 'text', v_body, p_community, 'published', now(), p_style) returning id into v_id;
  return v_id;
end $$;
revoke all on function create_community_post(uuid, text, text) from public, anon;
grant execute on function create_community_post(uuid, text, text) to authenticated;

create or replace function create_community_poll(p_community uuid, p_question text, p_options text[], p_style text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_q text := btrim(coalesce(p_question, '')); v_opts text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_q) not between 3 and 280 then raise exception 'La question doit contenir entre 3 et 280 caractères'; end if;
  select array_agg(btrim(o)) into v_opts from unnest(coalesce(p_options, '{}'::text[])) o where char_length(btrim(o)) between 1 and 80;
  if v_opts is null or cardinality(v_opts) not between 2 and 6 then raise exception 'Un sondage a de 2 à 6 réponses'; end if;
  if (select count(*) from posts where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de publications en peu de temps. Réessayez dans une minute.'; end if;
  insert into posts (author_id, kind, body, community_id, status, published_at, style) values (auth.uid(), 'poll', v_q, p_community, 'published', now(), p_style) returning id into v_id;
  insert into community_polls (post_id, options) values (v_id, v_opts);
  return v_id;
end $$;
revoke all on function create_community_poll(uuid, text, text[], text) from public, anon;
grant execute on function create_community_poll(uuid, text, text[], text) to authenticated;

create or replace function vote_community_poll(p_post uuid, p_option integer) returns void
language plpgsql security definer set search_path = public as $$
declare v_comm uuid; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select p.community_id, cardinality(cp.options) into v_comm, v_n from posts p join community_polls cp on cp.post_id = p.id where p.id = p_post and p.kind = 'poll' and p.status = 'published';
  if v_comm is null then raise exception 'Sondage introuvable'; end if;
  if not is_community_member(v_comm) then raise exception 'Réservé aux membres de la communauté'; end if;
  if p_option is null or p_option < 0 or p_option >= v_n then raise exception 'Réponse inconnue'; end if;
  insert into community_poll_votes (post_id, user_id, option_index) values (p_post, auth.uid(), p_option)
  on conflict (post_id, user_id) do update set option_index = excluded.option_index, created_at = now();
end $$;
revoke all on function vote_community_poll(uuid, integer) from public, anon;
grant execute on function vote_community_poll(uuid, integer) to authenticated;

-- Annonce épinglée en haut du fil : responsables seulement, 3 au plus par communauté
create or replace function pin_community_post(p_post uuid, p_pin boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_comm uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select community_id into v_comm from posts where id = p_post and kind in ('text', 'poll') and status = 'published';
  if v_comm is null then raise exception 'Publication introuvable'; end if;
  if community_rank(v_comm, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Réservé aux responsables de la communauté'; end if;
  if p_pin and (select count(*) from posts where community_id = v_comm and pinned) >= 3 then raise exception 'Trois annonces épinglées au plus : retirez-en une'; end if;
  update posts set pinned = coalesce(p_pin, false), pinned_at = case when p_pin then now() end where id = p_post;
  return case when p_pin then 'pinned' else 'unpinned' end;
end $$;
revoke all on function pin_community_post(uuid, boolean) from public, anon;
grant execute on function pin_community_post(uuid, boolean) to authenticated;

create or replace function moderate_community_post(p_post uuid, p_hide boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_comm uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select community_id into v_comm from posts where id = p_post and kind in ('text', 'poll');
  if v_comm is null then raise exception 'Publication introuvable'; end if;
  if community_rank(v_comm, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  update posts set status = case when p_hide then 'hidden' else 'published' end, review_note = case when p_hide then 'Masquée par la modération de la communauté' else null end where id = p_post;
  return case when p_hide then 'hidden' else 'published' end;
end $$;

drop function if exists community_feed(uuid, integer);
create or replace function community_feed(p_community uuid, p_limit integer default 30)
returns table (id uuid, author text, author_id uuid, body text, published_at timestamptz, mine boolean, kind text, style text, pinned boolean, poll jsonb)
language sql stable security definer set search_path = public as $$
  select p.id, display_name(p.author_id), p.author_id, p.body, p.published_at, p.author_id = auth.uid(), p.kind, p.style, p.pinned,
         case when p.kind = 'poll' then (
           select jsonb_build_object(
             'options', (select jsonb_agg(jsonb_build_object('label', o.label, 'votes', (select count(*)::int from community_poll_votes v where v.post_id = p.id and v.option_index = o.ord - 1)) order by o.ord)
                         from unnest(cp.options) with ordinality o(label, ord)),
             'total', (select count(*)::int from community_poll_votes v where v.post_id = p.id),
             'mine', (select v.option_index from community_poll_votes v where v.post_id = p.id and v.user_id = auth.uid()))
           from community_polls cp where cp.post_id = p.id) end
  from posts p join communities c on c.id = p.community_id
  where p.community_id = p_community and p.kind in ('text', 'poll') and p.status = 'published' and c.status = 'active'
    and (c.privacy = 'public' or is_community_member(c.id) or is_platform_staff())
  order by p.pinned desc, p.pinned_at desc nulls last, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;
revoke all on function community_feed(uuid, integer) from public, anon;
grant execute on function community_feed(uuid, integer) to authenticated, anon;
