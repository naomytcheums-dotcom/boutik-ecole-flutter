-- Lot S5 — innovations : points « Aidant » cohérents, SOS réservé aux étudiants (et au département / à l'administration) sans spam, défis hebdomadaires créés et clos automatiquement
-- avec notification du gagnant, mur des victoires moins manipulable, communauté éphémère dont la durée court à partir de la validation.
-- Corrige S5-81, S5-83 (+ S5-84 côté Flutter), S5-87, S5-88, S5-89, S5-90, S5-91 (partiel : filière comparée sans casse ni espaces), S5-92, S5-94, S5-96, S5-98, S5-100.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (etu_s5.mjs).
-- Retour arrière :
--   select cron.unschedule('weekly-challenge'); select cron.unschedule('settle-challenges');
--   drop function if exists sos_close(uuid), challenge_auto_create(), _challenges_settle(), _dept_key(text), _communities_ephemeral_expiry() cascade ;
--   alter table communities drop column if exists ephemeral_days ; alter table sos_requests drop constraint if exists sos_requests_status_check ;
--   alter table sos_requests add constraint sos_requests_status_check check (status in ('open', 'solved')) ;
--   puis recréer points_total, my_points, top_helpers, sos_create, sos_answer, sos_solve, sos_list, challenges_list, victory_report, victory_cheer, create_ephemeral_community depuis
--   20261115190000 / 20261114001200 / 20261115000100.

create or replace function _dept_key(p text) returns text
language sql immutable set search_path = public as $$ select lower(btrim(coalesce(p, ''))) $$;
revoke all on function _dept_key(text) from public, anon, authenticated;

-- ============================================================ 1. Points : le niveau « Aidant » ne compte plus les 200 points hebdomadaires du défi de publications
create or replace function points_total(p_user uuid) returns integer
language sql stable security definer set search_path = public as $$
  select (coalesce((select sum(points) from point_events where user_id = p_user), 0)
        + coalesce((select sum(points) from points_ledger where user_id = p_user and source not like 'challenge:%'), 0))::int
$$;
revoke all on function points_total(uuid) from public, anon, authenticated;

create or replace function my_points() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_total integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_total := points_total(auth.uid());
  return jsonb_build_object('total', v_total, 'level', point_level(v_total),
    'next_at', case when v_total >= 1000 then null when v_total >= 400 then 1000 when v_total >= 150 then 400 when v_total >= 50 then 150 else 50 end,
    'bonus', coalesce((select sum(points) from points_ledger where user_id = auth.uid() and source like 'challenge:%'), 0)::int,
    'events', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'points', e.points, 'created_at', e.created_at) order by e.created_at desc)
                        from (select kind, points, created_at from point_events where user_id = auth.uid()
                              union all select source, points, created_at from points_ledger where user_id = auth.uid()
                              order by created_at desc limit 15) e), '[]'::jsonb));
end $$;

create or replace function top_helpers(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('user_id', x.user_id, 'name', display_name(x.user_id), 'total', x.total, 'level', point_level(x.total)) order by x.total desc), '[]'::jsonb)
  from (select u.user_id, sum(u.points)::int total
        from (select user_id, points from point_events union all select user_id, points from points_ledger where source not like 'challenge:%') u
        group by u.user_id having sum(u.points) > 0 order by sum(u.points) desc limit least(greatest(coalesce(p_limit, 10), 1), 50)) x
$$;

-- ============================================================ 2. SOS Cours : étudiants (et département / administration), 30 destinataires au plus, 5 SOS par jour et par personne, clôture par l'auteur
do $$ begin
  alter table sos_requests drop constraint if exists sos_requests_status_check;
  alter table sos_requests add constraint sos_requests_status_check check (status in ('open', 'solved', 'closed'));
exception when others then raise notice 'sos_requests_status_check : %', sqlerrm; end $$;

create or replace function sos_create(p_subject text, p_details text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_dept text; r record; v_subject text := btrim(coalesce(p_subject, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Le SOS Cours est réservé aux étudiants'; end if;
  if char_length(v_subject) < 3 then raise exception 'Indiquez la matière ou le TP qui vous bloque'; end if;
  select coalesce(btrim(department), '') into v_dept from profiles where id = auth.uid();
  if v_dept = '' then raise exception 'Renseignez votre filière dans votre profil : sans elle, personne ne peut voir votre SOS'; end if;
  if (select count(*) from sos_requests where author_id = auth.uid() and created_at > now() - interval '1 hour') >= 3 then raise exception 'Trois SOS par heure au plus'; end if;
  insert into sos_requests (author_id, subject, details, department) values (auth.uid(), left(v_subject, 100), left(btrim(coalesce(p_details, '')), 800), v_dept) returning id into v_id;
  for r in select p.id from profiles p
           where p.id <> auth.uid() and coalesce(p.suspended, false) = false and p.role::text = 'student' and _dept_key(p.department) = _dept_key(v_dept)
             and (select count(*) from notifications n where n.user_id = p.id and n.kind = 'sos' and n.title like 'SOS Cours :%' and n.created_at > now() - interval '1 day') < 5
           order by random() limit 30 loop
    perform notify_user(r.id, 'sos', 'SOS Cours : ' || left(v_subject, 60), display_name(auth.uid()) || ' est bloqué(e). Le premier qui répond gagne des points.', jsonb_build_object('sos', v_id));
  end loop;
  return v_id;
end $$;
revoke all on function sos_create(text, text) from public, anon;
grant execute on function sos_create(text, text) to authenticated;

create or replace function sos_answer(p_sos uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare s sos_requests%rowtype; v_id uuid; v_first boolean; v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Le SOS Cours est réservé aux étudiants'; end if;
  select * into s from sos_requests where id = p_sos;
  if not found then raise exception 'SOS introuvable'; end if;
  if s.author_id = auth.uid() then raise exception 'Vous ne pouvez pas répondre à votre propre SOS'; end if;
  if s.status <> 'open' then raise exception 'Ce SOS est déjà résolu ou clos'; end if;
  select department into v_dept from profiles where id = auth.uid();
  if coalesce(current_role_name()::text, '') = 'student' and _dept_key(v_dept) <> _dept_key(s.department) then raise exception 'Ce SOS est réservé à la filière de son auteur'; end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 1000 then raise exception 'Une réponse contient de 1 à 1000 caractères'; end if;
  if (select count(*) from sos_answers where sos_id = p_sos and author_id = auth.uid()) >= 3 then raise exception 'Trois réponses au plus par SOS'; end if;
  v_first := not exists (select 1 from sos_answers where sos_id = p_sos);
  insert into sos_answers (sos_id, author_id, body) values (p_sos, auth.uid(), btrim(p_body)) returning id into v_id;
  if v_first then perform award_points(auth.uid(), 'sos_first', 15, p_sos::text); end if;
  perform notify_user(s.author_id, 'sos', 'On vous répond', display_name(auth.uid()) || ' a répondu à votre SOS « ' || left(s.subject, 60) || ' ».', jsonb_build_object('sos', p_sos));
  return v_id;
end $$;
revoke all on function sos_answer(uuid, text) from public, anon;
grant execute on function sos_answer(uuid, text) to authenticated;

create or replace function sos_solve(p_sos uuid, p_answer uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s sos_requests%rowtype; a sos_answers%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from sos_requests where id = p_sos and author_id = auth.uid() for update;
  if not found then raise exception 'SOS introuvable'; end if;
  if s.status <> 'open' then raise exception 'Ce SOS est déjà résolu ou clos'; end if;
  select * into a from sos_answers where id = p_answer and sos_id = p_sos;
  if not found then raise exception 'Réponse introuvable'; end if;
  update sos_requests set status = 'solved', solved_answer = p_answer where id = p_sos;
  perform award_points(a.author_id, 'sos_solved', 10, p_answer::text);
  perform notify_user(a.author_id, 'sos', 'Votre aide a servi', display_name(auth.uid()) || ' a retenu votre réponse : +10 points.', jsonb_build_object('sos', p_sos));
end $$;
revoke all on function sos_solve(uuid, uuid) from public, anon;
grant execute on function sos_solve(uuid, uuid) to authenticated;

create or replace function sos_close(p_sos uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update sos_requests set status = 'closed' where id = p_sos and author_id = auth.uid() and status = 'open';
  if not found then raise exception 'SOS introuvable ou déjà clos'; end if;
end $$;
revoke all on function sos_close(uuid) from public, anon;
grant execute on function sos_close(uuid) to authenticated;

create or replace function sos_list(p_scope text default 'filiere') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Le SOS Cours est réservé aux étudiants'; end if;
  select coalesce(btrim(department), '') into v_dept from profiles where id = auth.uid();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', s.id, 'subject', s.subject, 'details', s.details, 'author', display_name(s.author_id), 'mine', s.author_id = auth.uid(), 'status', s.status,
      'created_at', s.created_at, 'solved_answer', s.solved_answer,
      'answers', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'body', a.body, 'author', display_name(a.author_id), 'created_at', a.created_at, 'accepted', a.id = s.solved_answer) order by a.created_at)
                           from sos_answers a where a.sos_id = s.id), '[]'::jsonb)) order by s.created_at desc)
    from (select * from sos_requests where case when p_scope = 'mine' then author_id = auth.uid() else (status = 'open' and author_id <> auth.uid() and _dept_key(department) = _dept_key(v_dept) and v_dept <> '') end
          order by created_at desc limit 50) s
  ), '[]'::jsonb);
end $$;
revoke all on function sos_list(text) from public, anon;
grant execute on function sos_list(text) to authenticated;

-- ============================================================ 3. Défis : clôture et gagnant désignés par une tâche planifiée (gagnant notifié), un défi créé chaque lundi s'il n'y en a pas d'actif
create or replace function _challenges_settle() returns integer
language plpgsql security definer set search_path = public as $$
declare c record; w uuid; v_author uuid; n integer := 0;
begin
  for c in select id, title from weekly_challenges where ends_at <= now() and winner_entry is null loop
    select e.id into w from challenge_entries e where e.challenge_id = c.id
      order by (select count(*) from challenge_votes v where v.entry_id = e.id) desc, e.created_at limit 1;
    if w is not null and exists (select 1 from challenge_votes where entry_id = w) then
      update weekly_challenges set winner_entry = w where id = c.id;
      select author_id into v_author from challenge_entries where id = w;
      perform award_points(v_author, 'challenge_win', 50, c.id::text);
      perform notify_user(v_author, 'challenge', 'Défi remporté !', left('Votre réalisation a gagné le défi « ' || c.title || ' » : +50 points.', 300), jsonb_build_object('challenge', c.id));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
revoke all on function _challenges_settle() from public, anon, authenticated;

create or replace function challenges_list() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform _challenges_settle();
  return coalesce((select jsonb_agg(jsonb_build_object('id', ch.id, 'title', ch.title, 'description', ch.description, 'kind', ch.kind, 'starts_at', ch.starts_at, 'ends_at', ch.ends_at,
      'ended', ch.ends_at <= now(), 'winner_entry', ch.winner_entry,
      'my_vote', (select v.entry_id from challenge_votes v where v.challenge_id = ch.id and v.user_id = auth.uid()),
      'i_entered', exists (select 1 from challenge_entries e where e.challenge_id = ch.id and e.author_id = auth.uid()),
      'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'description', e.description, 'url', e.url, 'author', display_name(e.author_id), 'mine', e.author_id = auth.uid(),
                              'votes', (select count(*)::int from challenge_votes v where v.entry_id = e.id), 'winner', e.id = ch.winner_entry)
                              order by (select count(*) from challenge_votes v where v.entry_id = e.id) desc, e.created_at)
                           from challenge_entries e where e.challenge_id = ch.id), '[]'::jsonb)) order by (ch.ends_at <= now()), ch.ends_at desc)
    from (select * from weekly_challenges order by created_at desc limit 12) ch), '[]'::jsonb);
end $$;
revoke all on function challenges_list() from public, anon;
grant execute on function challenges_list() to authenticated;

create or replace function challenge_auto_create() returns uuid
language plpgsql security definer set search_path = public as $$
declare v_week integer := extract(week from now())::int; v_id uuid; v_t text; v_kind text; v_i integer;
begin
  if exists (select 1 from weekly_challenges where ends_at > now()) then return null; end if;
  v_i := v_week % 6;
  v_t := (array[
    'Design|design|Concevez l''affiche d''un événement de votre établissement (format A3, une seule image).',
    'Code|code|Réalisez un petit outil utile aux étudiants (calculatrice de moyenne, planning, convertisseur) en moins de 100 lignes.',
    'Idée|other|Proposez une idée pour réduire les déchets sur le campus et présentez-la en trois phrases.',
    'Design|design|Redessinez le logo d''une association locale et expliquez vos choix de couleurs.',
    'Code|code|Créez une page web d''une seule page qui présente votre filière de façon claire et accessible.',
    'Idée|other|Imaginez un service qui aide un commerçant de quartier à vendre en ligne, sans jargon.'])[v_i + 1];
  v_kind := split_part(v_t, '|', 2);
  insert into weekly_challenges (title, description, kind, ends_at)
  values (left('Défi de la semaine : ' || split_part(v_t, '|', 1), 120), split_part(v_t, '|', 3), v_kind, now() + interval '7 days') returning id into v_id;
  return v_id;
end $$;
revoke all on function challenge_auto_create() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('weekly-challenge') where exists (select 1 from cron.job where jobname = 'weekly-challenge');
  perform cron.unschedule('settle-challenges') where exists (select 1 from cron.job where jobname = 'settle-challenges');
  perform cron.schedule('weekly-challenge', '0 6 * * 1', 'select public.challenge_auto_create()');
  perform cron.schedule('settle-challenges', '5 * * * *', 'select public._challenges_settle()');
exception when others then
  raise notice 'pg_cron indisponible : les défis ne sont ni créés ni clos automatiquement (%).', sqlerrm;
end $$;

-- ============================================================ 4. Victoires : masquage collectif plus difficile à détourner, félicitation notifiée une seule fois par personne
create or replace function victory_report(p_id uuid, p_reason text default '') returns void
language plpgsql security definer set search_path = public as $$
declare v victories%rowtype; n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into v from victories where id = p_id and status = 'published';
  if not found then raise exception 'Réussite introuvable'; end if;
  if v.author_id = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre réussite'; end if;
  insert into victory_reports (victory_id, user_id, reason) values (p_id, auth.uid(), left(btrim(coalesce(p_reason, '')), 300)) on conflict do nothing;
  -- masquage automatique : cinq signalements de comptes de plus de sept jours ; sinon la modération décide
  select count(*) into n from victory_reports r join profiles p on p.id = r.user_id where r.victory_id = p_id and p.created_at < now() - interval '7 days';
  if n >= 5 then update victories set status = 'hidden' where id = p_id; end if;
  insert into notifications (user_id, kind, title, body, data)
  select a.id, 'victory', 'Réussite signalée', left(v.body, 120), jsonb_build_object('victory', p_id) from profiles a where a.role::text in ('admin', 'support') and a.id <> auth.uid() limit 20;
end $$;
revoke all on function victory_report(uuid, text) from public, anon;
grant execute on function victory_report(uuid, text) to authenticated;

create or replace function victory_cheer(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare v victories%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into v from victories where id = p_id and status = 'published';
  if not found then raise exception 'Réussite introuvable'; end if;
  if exists (select 1 from victory_cheers where victory_id = p_id and user_id = auth.uid()) then
    delete from victory_cheers where victory_id = p_id and user_id = auth.uid();
    return false;
  end if;
  insert into victory_cheers (victory_id, user_id) values (p_id, auth.uid());
  if v.author_id <> auth.uid() and not exists (select 1 from notifications where user_id = v.author_id and kind = 'victory' and title = 'Bravo !' and data->>'victory' = p_id::text and data->>'by' = auth.uid()::text) then
    perform notify_user(v.author_id, 'victory', 'Bravo !', display_name(auth.uid()) || ' félicite votre réussite.', jsonb_build_object('victory', p_id, 'by', auth.uid()));
  end if;
  return true;
end $$;
revoke all on function victory_cheer(uuid) from public, anon;
grant execute on function victory_cheer(uuid) to authenticated;

-- ============================================================ 5. Communauté éphémère : la durée court à partir de la validation
alter table communities add column if not exists ephemeral_days integer check (ephemeral_days is null or ephemeral_days between 1 and 14);

create or replace function create_ephemeral_community(p_name text, p_description text default '', p_days integer default 7, p_privacy text default 'public') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Compte suspendu : création de communauté impossible'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_days is null or p_days not between 1 and 14 then raise exception 'Une communauté éphémère dure de 1 à 14 jours'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and ((expires_at is not null and expires_at > now()) or (ephemeral_days is not null and status = 'pending'))) >= 3 then raise exception 'Trois communautés éphémères actives ou en attente au plus'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, privacy, owner_id, status, kind, interest, ephemeral_days)
    values (btrim(p_name), left(btrim(coalesce(p_description, '')), 2000), p_privacy, auth.uid(), 'pending', 'project', 'Éphémère', p_days) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  for r in select id from profiles where role::text in ('admin', 'support') loop
    perform notify_user(r.id, 'community_validation', 'Communauté à valider', display_name(auth.uid()) || ' propose la communauté éphémère « ' || btrim(p_name) || ' ».', jsonb_build_object('community', v_id));
  end loop;
  return v_id;
end $$;
revoke all on function create_ephemeral_community(text, text, integer, text) from public, anon;
grant execute on function create_ephemeral_community(text, text, integer, text) to authenticated;

create or replace function _communities_ephemeral_expiry() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.ephemeral_days is not null and new.status = 'active' and old.status is distinct from 'active' then
    new.expires_at := now() + make_interval(days => new.ephemeral_days);
  end if;
  return new;
end $$;
drop trigger if exists trg_communities_ephemeral_expiry on communities;
create trigger trg_communities_ephemeral_expiry before update of status on communities for each row execute function _communities_ephemeral_expiry();
