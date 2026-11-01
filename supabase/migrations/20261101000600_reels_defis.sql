-- Reels et défis (écrans 245, 250, P4, 250b, 253, 253b), selon REGLES_METIER_PROPOSEES.md § 2.1 et § 4.
-- Publication par les étudiants, le département et l'administrateur ; immédiate si le compte est certifié, sinon après
-- validation par le département. Lien « Boutique » seulement vers une annonce approuvée de l'auteur. Signalement.
-- Points et boosts de visibilité : jamais convertibles en argent. « Propulser » (payant) reste indisponible.
-- Aucune donnée existante n'est modifiée.

create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  media_path text not null check (char_length(media_path) between 5 and 300),
  media_kind text not null check (media_kind in ('video', 'image')),
  caption text not null default '' check (char_length(caption) <= 300),
  tags text[] not null default '{}' check (cardinality(tags) <= 10),
  listing_id uuid references listings(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'published', 'hidden')),
  review_note text,
  created_at timestamptz not null default now(),
  published_at timestamptz
);
create index if not exists posts_fil on posts (status, published_at desc);

create table if not exists post_likes (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists post_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 300),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  unique (post_id, reporter_id)
);

create table if not exists daily_checkins (
  user_id uuid not null references profiles(id) on delete cascade,
  day date not null,
  primary key (user_id, day)
);

create table if not exists points_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  source text not null check (char_length(source) between 3 and 60),
  ref text not null default '',
  points integer not null check (points > 0),
  created_at timestamptz not null default now(),
  unique (user_id, source, ref)
);

create table if not exists post_boosts (
  id bigint generated always as identity primary key,
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null default now() + interval '24 hours',
  reason text not null default 'série de 6 jours'
);

alter table posts enable row level security;
alter table post_likes enable row level security;
alter table post_reports enable row level security;
alter table daily_checkins enable row level security;
alter table points_ledger enable row level security;
alter table post_boosts enable row level security;
revoke all on posts, post_likes, post_reports, daily_checkins, points_ledger, post_boosts from anon, authenticated;
grant select on posts, post_likes, post_boosts to anon, authenticated;
grant select on post_reports, daily_checkins, points_ledger to authenticated;
drop policy if exists "publications visibles" on posts;
create policy "publications visibles" on posts for select
  using (status = 'published' or author_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support'));
drop policy if exists "mentions j'aime visibles" on post_likes;
create policy "mentions j'aime visibles" on post_likes for select using (true);
drop policy if exists "boosts visibles" on post_boosts;
create policy "boosts visibles" on post_boosts for select using (true);
drop policy if exists "signalements : auteur du signalement et modération" on post_reports;
create policy "signalements : auteur du signalement et modération" on post_reports for select
  using (reporter_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support'));
drop policy if exists "présences : titulaire" on daily_checkins;
create policy "présences : titulaire" on daily_checkins for select using (user_id = auth.uid());
drop policy if exists "points : titulaire" on points_ledger;
create policy "points : titulaire" on points_ledger for select using (user_id = auth.uid());

-- Médias : lecture publique (contenu publié), dépôt dans son dossier, 50 Mo, vidéo MP4/MOV ou image
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-media', 'post-media', true, 52428800, array['video/mp4', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;
drop policy if exists "médias de publication : lecture" on storage.objects;
create policy "médias de publication : lecture" on storage.objects for select using (bucket_id = 'post-media');
drop policy if exists "médias de publication : dépôt dans son dossier" on storage.objects;
create policy "médias de publication : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "médias de publication : suppression dans son dossier" on storage.objects;
create policy "médias de publication : suppression dans son dossier" on storage.objects for delete to authenticated
  using (bucket_id = 'post-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- Publication
create or replace function create_post(p_media_path text, p_media_kind text, p_caption text, p_tags text[], p_listing uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; pid uuid; st text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended or me.role::text not in ('student', 'dept', 'admin') then raise exception 'Publication réservée aux étudiants et au département'; end if;
  if p_media_path is null or split_part(p_media_path, '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  if p_listing is not null and not exists (select 1 from listings where id = p_listing and seller_id = auth.uid() and status = 'approved') then
    raise exception 'Le lien « Boutique » ne peut viser qu''une de vos annonces validées';
  end if;
  st := case when me.certification = 'approved' or me.role::text in ('dept', 'admin') then 'published' else 'pending' end;
  insert into posts (author_id, media_path, media_kind, caption, tags, listing_id, status, published_at)
    values (auth.uid(), p_media_path, p_media_kind, left(trim(coalesce(p_caption, '')), 300),
            coalesce((select array_agg(distinct lower(left(trim(t), 30))) from unnest(coalesce(p_tags, '{}')) t where trim(t) <> ''), '{}'),
            p_listing, st, case when st = 'published' then now() end)
    returning id into pid;
  return jsonb_build_object('id', pid, 'status', st);
end $$;

create or replace function moderate_post(p_post uuid, p_publish boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare p posts%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  select * into p from posts where id = p_post for update;
  if not found then raise exception 'Publication introuvable'; end if;
  if not p_publish and char_length(trim(coalesce(p_note, ''))) < 3 then raise exception 'Motif obligatoire'; end if;
  update posts set status = case when p_publish then 'published' else 'hidden' end, published_at = case when p_publish then coalesce(p.published_at, now()) else p.published_at end,
    review_note = nullif(trim(coalesce(p_note, '')), '') where id = p.id;
  update post_reports set status = 'closed' where post_id = p.id and status = 'open';
  insert into notifications (user_id, kind, title, body, data)
    values (p.author_id, 'post', case when p_publish then 'Publication en ligne' else 'Publication masquée' end, coalesce(nullif(trim(coalesce(p_note, '')), ''), left(p.caption, 120)), jsonb_build_object('post_id', p.id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case when p_publish then 'Publication validée' else 'Publication masquée' end, p.id::text, 'Modération', 'Normal');
  return case when p_publish then 'published' else 'hidden' end;
end $$;

create or replace function report_post(p_post uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
  insert into post_reports (post_id, reporter_id, reason) values (p_post, auth.uid(), trim(p_reason))
  on conflict (post_id, reporter_id) do nothing;
  return 'reported';
end $$;

create or replace function toggle_post_like(p_post uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
  if exists (select 1 from post_likes where post_id = p_post and user_id = auth.uid()) then
    delete from post_likes where post_id = p_post and user_id = auth.uid();
    return false;
  end if;
  insert into post_likes (post_id, user_id) values (p_post, auth.uid());
  return true;
end $$;

-- Fil des reels : publiés, boostés d'abord ; auteur abrégé ; compteurs réels
create or replace function reels_feed(p_limit integer default 20)
returns table (id uuid, author text, media_path text, media_kind text, caption text, tags text[], listing_title text, likes integer, liked boolean, boosted boolean, published_at timestamptz)
language sql stable security definer set search_path = public as $$
  select p.id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), 'Étudiant'),
         p.media_path, p.media_kind, p.caption, p.tags, l.title,
         (select count(*)::int from post_likes k where k.post_id = p.id),
         exists (select 1 from post_likes k where k.post_id = p.id and k.user_id = auth.uid()),
         exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at),
         p.published_at
  from posts p join profiles a on a.id = p.author_id left join listings l on l.id = p.listing_id and l.status = 'approved'
  where p.status = 'published'
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;

-- Défis : présence quotidienne, série, défis de la semaine, badges calculés sur des données réelles
create or replace function daily_checkin() returns integer
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; n int := 0;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  insert into daily_checkins (user_id, day) values (auth.uid(), d) on conflict do nothing;
  while exists (select 1 from daily_checkins where user_id = auth.uid() and day = d - n) loop n := n + 1; end loop;
  return n;
end $$;

create or replace function my_challenges() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; streak int := 0; wk date := date_trunc('week', d)::date; posts_week int; pts int; rank int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  while exists (select 1 from daily_checkins where user_id = auth.uid() and day = d - streak) loop streak := streak + 1; end loop;
  select count(*) into posts_week from posts where author_id = auth.uid() and status = 'published' and published_at >= wk;
  select coalesce(sum(points), 0) into pts from points_ledger where user_id = auth.uid();
  select count(*) + 1 into rank from (select user_id, sum(points) s from points_ledger group by user_id) x where x.s > pts;
  return jsonb_build_object(
    'streak', streak, 'next_reward_in', greatest(6 - streak, 0), 'streak_reward_claimable', streak >= 6
      and not exists (select 1 from points_ledger where user_id = auth.uid() and source = 'streak6' and ref = d::text),
    'week_end_days', 7 - extract(isodow from d)::int,
    'posts_week', posts_week, 'posts_goal', 3,
    'posts_claimable', posts_week >= 3 and not exists (select 1 from points_ledger where user_id = auth.uid() and source = 'challenge:posts3' and ref = wk::text),
    'points', pts,
    'badges', jsonb_build_object(
      'first_sale', exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null),
      'followers_100', false,
      'live_star', false,
      'top10', pts > 0 and rank <= 10)
  );
end $$;

-- Défi « Publier 3 posts » : +200 points, une fois par semaine
create or replace function claim_challenge(p_code text) returns integer
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; wk date := date_trunc('week', d)::date; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_code <> 'posts3' then raise exception 'Défi indisponible'; end if;
  select count(*) into n from posts where author_id = auth.uid() and status = 'published' and published_at >= wk;
  if n < 3 then raise exception 'Défi non atteint : % publication(s) sur 3 cette semaine', n; end if;
  insert into points_ledger (user_id, source, ref, points) values (auth.uid(), 'challenge:posts3', wk::text, 200);
  return 200;
exception when unique_violation then raise exception 'Récompense déjà récupérée cette semaine';
end $$;

-- Série de 6 jours : un boost gratuit de 24 h sur la dernière publication (un boost actif à la fois)
create or replace function claim_streak_boost() returns text
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; streak int := 0; p uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  while exists (select 1 from daily_checkins where user_id = auth.uid() and day = d - streak) loop streak := streak + 1; end loop;
  if streak < 6 then raise exception 'Série de % jour(s) : la récompense arrive à 6 jours', streak; end if;
  select id into p from posts where author_id = auth.uid() and status = 'published' order by published_at desc limit 1;
  if p is null then raise exception 'Publiez d''abord un post pour recevoir le boost'; end if;
  if exists (select 1 from post_boosts where user_id = auth.uid() and now() between starts_at and ends_at) then raise exception 'Un boost est déjà actif'; end if;
  insert into points_ledger (user_id, source, ref, points) values (auth.uid(), 'streak6', d::text, 1);
  insert into post_boosts (post_id, user_id) values (p, auth.uid());
  return 'boosted';
exception when unique_violation then raise exception 'Récompense du jour déjà récupérée';
end $$;

revoke all on function create_post(text, text, text, text[], uuid), moderate_post(uuid, boolean, text), report_post(uuid, text), toggle_post_like(uuid),
  reels_feed(integer), daily_checkin(), my_challenges(), claim_challenge(text), claim_streak_boost() from public, anon;
grant execute on function create_post(text, text, text, text[], uuid), moderate_post(uuid, boolean, text), report_post(uuid, text), toggle_post_like(uuid),
  reels_feed(integer), daily_checkin(), my_challenges(), claim_challenge(text), claim_streak_boost() to authenticated;
grant execute on function reels_feed(integer) to anon;

-- Retour arrière (manuel) : drop des 9 fonctions ci-dessus ; drop table post_boosts, points_ledger, daily_checkins, post_reports, post_likes, posts ;
-- delete from storage.buckets where id = 'post-media' (après suppression de ses objets) ; drop des 3 politiques « médias de publication ».
