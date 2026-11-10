-- Réseau social, deuxième série : histoires de 24 / 48 / 72 h avec question ou sondage, réactions autres que le cœur,
-- publications programmées (jusqu'à 6 mois). Non destructif : colonnes et tables ajoutées, aucune donnée existante modifiée.
-- Retour arrière : drop table story_answers, post_reactions, scheduled_posts ; alter table stories drop column sticker ;
--                  drop function create_story(text, text, text, int, jsonb), answer_story, story_results, react_post,
--                  schedule_post, cancel_scheduled_post, publish_due_posts ; rejouer stories_active de 20261110000000.

-- ------------------------------------------------------------------ histoires : durée, question, sondage
alter table stories add column if not exists sticker jsonb;

create table if not exists story_answers (
  story_id uuid not null references stories(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  choice int,
  answer text check (answer is null or char_length(answer) <= 300),
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
alter table story_answers enable row level security;
revoke all on story_answers from anon, authenticated;

create or replace function create_story(p_path text, p_kind text, p_caption text, p_hours int, p_sticker jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; sid uuid; h int; st jsonb := null; t text; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended or me.role::text not in ('student', 'dept', 'admin') then raise exception 'Histoires réservées aux étudiants et au département'; end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  if coalesce(p_kind, '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  if (select count(*) from stories where author_id = auth.uid() and created_at > now() - interval '24 hours') >= 30 then raise exception '30 histoires par jour au plus'; end if;
  h := case when p_hours in (24, 48, 72) then p_hours else 24 end;
  if p_sticker is not null and jsonb_typeof(p_sticker) = 'object' then
    t := p_sticker->>'type';
    if t not in ('poll', 'question') then raise exception 'Autocollant invalide'; end if;
    if char_length(coalesce(p_sticker->>'text', '')) not between 1 and 120 then raise exception 'La question doit faire de 1 à 120 caractères'; end if;
    if t = 'poll' then
      n := coalesce(jsonb_array_length(p_sticker->'options'), 0);
      if n not between 2 and 4 then raise exception 'Un sondage propose de 2 à 4 choix'; end if;
      if exists (select 1 from jsonb_array_elements_text(p_sticker->'options') o where char_length(o) not between 1 and 40) then raise exception 'Chaque choix fait de 1 à 40 caractères'; end if;
      st := jsonb_build_object('type', 'poll', 'text', left(btrim(p_sticker->>'text'), 120), 'options', p_sticker->'options');
    else
      st := jsonb_build_object('type', 'question', 'text', left(btrim(p_sticker->>'text'), 120));
    end if;
  end if;
  insert into stories (author_id, media_path, media_kind, caption, sticker, expires_at)
  values (auth.uid(), p_path, p_kind, left(btrim(coalesce(p_caption, '')), 200), st, now() + make_interval(hours => h)) returning id into sid;
  return sid;
end $$;
revoke all on function create_story(text, text, text, int, jsonb) from public, anon;
grant execute on function create_story(text, text, text, int, jsonb) to authenticated;

drop function if exists stories_active(uuid);
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
  from stories s join profiles a on a.id = s.author_id and not a.suspended
  where s.status = 'visible' and s.expires_at > now() and (p_author is null or s.author_id = p_author)
  order by s.author_id, s.created_at
  limit 300
$$;
grant execute on function stories_active(uuid) to anon, authenticated;

create or replace function answer_story(p_story uuid, p_choice int, p_answer text) returns text
language plpgsql security definer set search_path = public as $$
declare s stories%rowtype; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from stories where id = p_story and status = 'visible' and expires_at > now();
  if not found or s.sticker is null then raise exception 'Cette histoire n''accepte pas de réponse'; end if;
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

-- Résultats : réservés à l'auteur de l'histoire (votes par choix, ou réponses reçues).
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
    select jsonb_agg(jsonb_build_object('name', coalesce(p.name, 'Étudiant'), 'answer', a.answer) order by a.created_at desc)
    from story_answers a join profiles p on p.id = a.user_id where a.story_id = p_story and a.answer is not null), '[]'::jsonb));
end $$;
revoke all on function story_results(uuid) from public, anon;
grant execute on function story_results(uuid) to authenticated;

-- ------------------------------------------------------------------ réactions autres que le cœur
create table if not exists post_reactions (
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('like', 'love', 'haha', 'wow', 'sad', 'fire', 'clap')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table post_reactions enable row level security;
revoke all on post_reactions from anon, authenticated;
grant select on post_reactions to authenticated;
drop policy if exists "réactions : les miennes" on post_reactions;
create policy "réactions : les miennes" on post_reactions for select to authenticated using (user_id = auth.uid());

-- Choisit (ou retire, si c'est la même) une réaction. Toute réaction compte aussi comme un « j'aime » pour les compteurs existants.
create or replace function react_post(p_post uuid, p_kind text) returns text
language plpgsql security definer set search_path = public as $$
declare cur text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('like', 'love', 'haha', 'wow', 'sad', 'fire', 'clap') then raise exception 'Réaction invalide'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
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
revoke all on function react_post(uuid, text) from public, anon;
grant execute on function react_post(uuid, text) to authenticated;

-- ------------------------------------------------------------------ publications programmées (jusqu'à 6 mois)
create table if not exists scheduled_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  caption text not null default '' check (char_length(caption) <= 5000),
  media jsonb not null default '[]'::jsonb,
  link text,
  tags text[] not null default '{}',
  publish_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'published', 'cancelled', 'failed')),
  error text,
  created_at timestamptz not null default now()
);
create index if not exists scheduled_posts_dues on scheduled_posts (status, publish_at);
alter table scheduled_posts enable row level security;
revoke all on scheduled_posts from anon, authenticated;
grant select on scheduled_posts to authenticated;
drop policy if exists "programmées : les miennes" on scheduled_posts;
create policy "programmées : les miennes" on scheduled_posts for select to authenticated using (author_id = auth.uid());

create or replace function schedule_post(p_caption text, p_media jsonb, p_link text, p_tags text[], p_at timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; sid uuid; m jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended or me.role::text not in ('student', 'dept', 'admin') then raise exception 'Publication réservée aux étudiants et au département'; end if;
  if p_at is null or p_at < now() + interval '1 minute' then raise exception 'Choisissez une date et une heure à venir'; end if;
  if p_at > now() + interval '6 months' then raise exception 'La programmation est limitée à 6 mois'; end if;
  if char_length(btrim(coalesce(p_caption, ''))) = 0 and coalesce(jsonb_array_length(p_media), 0) = 0 and coalesce(p_link, '') = '' then raise exception 'Rien à publier'; end if;
  for m in select * from jsonb_array_elements(coalesce(p_media, '[]'::jsonb)) loop
    if split_part(coalesce(m->>'path', ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  end loop;
  if (select count(*) from scheduled_posts where author_id = auth.uid() and status = 'pending') >= 200 then raise exception '200 publications programmées au plus'; end if;
  insert into scheduled_posts (author_id, caption, media, link, tags, publish_at)
  values (auth.uid(), left(btrim(coalesce(p_caption, '')), 5000), coalesce(p_media, '[]'::jsonb), nullif(btrim(coalesce(p_link, '')), ''), coalesce(p_tags, '{}'), p_at) returning id into sid;
  return sid;
end $$;
revoke all on function schedule_post(text, jsonb, text, text[], timestamptz) from public, anon;
grant execute on function schedule_post(text, jsonb, text, text[], timestamptz) to authenticated;

create or replace function cancel_scheduled_post(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update scheduled_posts set status = 'cancelled' where id = p_id and author_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Publication programmée introuvable'; end if;
  return 'annulée';
end $$;
revoke all on function cancel_scheduled_post(uuid) from public, anon;
grant execute on function cancel_scheduled_post(uuid) to authenticated;

-- Publie les publications arrivées à échéance, au nom de leur auteur. Appelée chaque minute par pg_cron quand l'extension est active,
-- et aussi à l'ouverture du fil (une publication échue ne reste jamais en attente).
create or replace function publish_due_posts() returns int
language plpgsql security definer set search_path = public as $$
declare r scheduled_posts%rowtype; done int := 0; old_claims text := current_setting('request.jwt.claims', true); old_sub text := current_setting('request.jwt.claim.sub', true);
begin
  for r in select * from scheduled_posts where status = 'pending' and publish_at <= now() order by publish_at limit 50 for update skip locked loop
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', r.author_id, 'role', 'authenticated')::text, true);
      perform set_config('request.jwt.claim.sub', r.author_id::text, true);
      perform create_post_v2(r.caption, r.media, r.link, r.tags, null, null);
      update scheduled_posts set status = 'published' where id = r.id;
      done := done + 1;
    exception when others then
      update scheduled_posts set status = 'failed', error = left(sqlerrm, 300) where id = r.id;
    end;
  end loop;
  perform set_config('request.jwt.claims', coalesce(old_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(old_sub, ''), true);
  return done;
end $$;
revoke all on function publish_due_posts() from public, anon;
grant execute on function publish_due_posts() to authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('publish-due-posts', '* * * * *', 'select public.publish_due_posts()');
exception when others then
  raise notice 'pg_cron indisponible : les publications programmées sont publiées à l''ouverture du fil (%).', sqlerrm;
end $$;
