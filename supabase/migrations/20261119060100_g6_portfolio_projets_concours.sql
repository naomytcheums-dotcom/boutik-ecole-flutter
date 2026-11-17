-- Lot G6 (2/2) : portfolio, projets, concours, compétences et réussites — comptes suspendus, annuaire, énumération d'adresses, modifications après validation.
--  1. Portfolio : la lecture par un tiers exclut un propriétaire suspendu (en plus de la visibilité du profil) ; portfolio_save refuse un compte suspendu (y compris en modification).
--  2. Projets : public_projects et public_project_get ne montrent plus les projets d'un porteur suspendu (le porteur et le département les lisent toujours) ;
--     project_member_search respecte l'annuaire consenti (profile_in_directory : un profil privé n'y figure plus) ; project_member_invite refuse une personne en blocage.
--  3. Concours : invite_contest_member ne révèle plus si une adresse correspond à un compte étudiant (réponse identique, tentatives bornées, blocages respectés) ;
--     answer_contest_invite n'accepte plus une invitation après la clôture des inscriptions ni une fois le projet déposé ;
--     submit_contest_project vérifie le fichier de présentation (dossier du capitaine) et dit clairement ce qui manque au lieu d'une erreur technique.
--  4. Compétences et réussites : skills_list et victories_list ne listent plus les comptes suspendus ni les personnes bloquées.
--  5. Défis : une réalisation d'un compte suspendu n'est plus listée, votable ni désignée gagnante.
--  6. public_project_get : un visiteur (sans compte) ne lit plus un brouillon, un projet privé ou en cours d'examen (condition nulle pour un visiteur : le contrôle ne refusait pas).
-- Retour arrière : recréer portfolio_save (20261116120000) et la politique « portfolio : selon la visibilité du profil » (20261117020100), public_projects (20261114004200),
--   public_project_get (20261115190000), project_member_search / project_member_invite (20261117050200), invite_contest_member / answer_contest_invite / submit_contest_project
--   (20261101000200), skills_list (20261114001200), victories_list (20261115190000) ; drop table contest_invite_attempts.

-- ============================================================ 1. Portfolio
-- Le compte est-il actif (non suspendu) ? Lisible par la politique même pour un visiteur (la table profiles ne l'est pas).
create or replace function _account_active(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = p_user and not coalesce(suspended, false))
$$;
revoke all on function _account_active(uuid) from public;
grant execute on function _account_active(uuid) to anon, authenticated;

drop policy if exists "portfolio : selon la visibilité du profil" on portfolio_items;
create policy "portfolio : selon la visibilité du profil" on portfolio_items for select
  using (owner_id = auth.uid() or (profile_visible(owner_id) and _account_active(owner_id)));

create or replace function portfolio_save(p_id uuid, p_kind text, p_title text, p_description text, p_category text, p_date text, p_url text, p_media_path text, p_featured boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; u text := trim(coalesce(p_url, '')); v_limit integer; v_plans text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : modification du portfolio impossible'; end if;
  if p_kind not in ('realisation', 'image', 'video', 'link') then raise exception 'Type invalide'; end if;
  if char_length(trim(coalesce(p_title, ''))) < 2 then raise exception 'Donnez un titre (2 caractères minimum)'; end if;
  if u <> '' and u !~* '^https?://[^ ]+$' then raise exception 'Le lien doit commencer par http:// ou https://'; end if;
  if p_kind = 'link' and u = '' then raise exception 'Saisissez le lien'; end if;
  if p_kind in ('image', 'video') and p_media_path is null and u = '' and p_id is null then raise exception 'Ajoutez un fichier ou un lien'; end if;
  if p_media_path is not null and (storage.foldername(p_media_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  if coalesce(p_featured, false) then update portfolio_items set featured = false where owner_id = auth.uid() and featured and id is distinct from p_id; end if;
  if p_id is null then
    v_limit := case when feature_granted(auth.uid(), 'portfolio_enrichi') then 300 else 100 end;
    if (select count(*) from portfolio_items where owner_id = auth.uid()) >= v_limit then
      select string_agg(name, ' ou ' order by name) into v_plans from plans where 'portfolio_enrichi' = any(features) and active and sellable and price_xaf > 0;
      raise exception 'Limite de % éléments atteinte%', v_limit, case when v_limit = 100 and v_plans is not null then ' (300 avec l''offre ' || v_plans || ')' else '' end;
    end if;
    insert into portfolio_items (owner_id, kind, title, description, category, happened_on, url, media_path, featured)
    values (auth.uid(), p_kind, trim(p_title), left(trim(coalesce(p_description, '')), 2000), left(trim(coalesce(p_category, '')), 80), left(trim(coalesce(p_date, '')), 40), u, p_media_path, coalesce(p_featured, false)) returning id into v;
  else
    update portfolio_items set kind = p_kind, title = trim(p_title), description = left(trim(coalesce(p_description, '')), 2000), category = left(trim(coalesce(p_category, '')), 80),
      happened_on = left(trim(coalesce(p_date, '')), 40), url = u, media_path = coalesce(p_media_path, media_path), featured = coalesce(p_featured, false)
    where id = p_id and owner_id = auth.uid() returning id into v;
    if v is null then raise exception 'Élément introuvable'; end if;
  end if;
  return v;
end $$;
revoke all on function portfolio_save(uuid, text, text, text, text, text, text, text, boolean) from public, anon;
grant execute on function portfolio_save(uuid, text, text, text, text, text, text, text, boolean) to authenticated;

-- ============================================================ 2. Projets
create or replace function public_projects(p_kind text default null, p_limit integer default 50) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'title', p.title, 'summary', p.summary, 'department', p.department,
      'details', coalesce(p.details, '{}'::jsonb) - 'contact_email' - 'contact_phone', 'media', p.media, 'status', p.status, 'created_at', p.created_at)
    order by p.created_at desc), '[]'::jsonb)
  from (select * from projects pr where pr.status = 'approved' and pr.visibility = 'public' and (nullif(trim(coalesce(p_kind, '')), '') is null or pr.kind = p_kind)
          and not exists (select 1 from profiles z where z.id = pr.owner_id and coalesce(z.suspended, false))
        order by pr.created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 100)) p
$$;
revoke all on function public_projects(text, integer) from public;
grant execute on function public_projects(text, integer) to anon, authenticated;

create or replace function public_project_get(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p projects%rowtype; v_own boolean;
begin
  select * into p from projects where id = p_id;
  if not found then return null; end if;
  v_own := coalesce(p.owner_id = auth.uid(), false) or coalesce(current_role_name()::text, '') in ('dept', 'admin');
  if not ((p.status = 'approved' and p.visibility = 'public' and not exists (select 1 from profiles z where z.id = p.owner_id and coalesce(z.suspended, false))) or v_own) then return null; end if;
  return jsonb_build_object(
    'id', p.id, 'kind', p.kind, 'title', p.title, 'summary', p.summary, 'department', p.department,
    'details', case when v_own then coalesce(p.details, '{}'::jsonb) else coalesce(p.details, '{}'::jsonb) - 'contact_email' - 'contact_phone' end,
    'media', p.media, 'status', p.status, 'created_at', p.created_at,
    'owner', case when auth.uid() is not null then display_name(p.owner_id) end,
    'mine', p.owner_id = auth.uid(),
    'votes', (select count(*)::int from project_upvotes u where u.project_id = p.id),
    'voted', exists (select 1 from project_upvotes u where u.project_id = p.id and u.user_id = auth.uid()),
    'team', coalesce((select jsonb_agg(jsonb_build_object('name', display_name(m.user_id), 'role', m.role) order by m.created_at)
                      from project_members m where m.project_id = p.id and m.status = 'accepted'), '[]'::jsonb),
    'campaign_id', (select c.id from campaigns c where c.project_id = p.id and c.status = 'approved' and (c.ends_at is null or c.ends_at > now()) order by c.created_at desc limit 1)
  );
end $$;
revoke all on function public_project_get(uuid) from public;
grant execute on function public_project_get(uuid) to anon, authenticated;

create or replace function project_member_search(p_q text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare q text := btrim(coalesce(p_q, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if char_length(q) < 3 then return '[]'::jsonb; end if;
  delete from project_member_searches where at < now() - interval '1 day';
  if (select count(*) from project_member_searches where user_id = auth.uid() and at > now() - interval '1 hour') >= 30 then raise exception 'Trop de recherches : réessayez dans quelques minutes'; end if;
  insert into project_member_searches (user_id) values (auth.uid());
  q := replace(replace(replace(q, '\', ''), '%', ''), '_', '');
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'department', coalesce(x.department, ''), 'avatar_url', x.avatar_url) order by x.name)
    from (select id, name, department, avatar_url from profiles
          where role::text = 'student' and coalesce(suspended, false) = false and profile_in_directory(id) and id <> auth.uid() and name ilike '%' || q || '%'
            and not is_blocked_between(auth.uid(), id)
          order by name limit 10) x
  ), '[]'::jsonb);
end $$;
revoke all on function project_member_search(text) from public, anon;
grant execute on function project_member_search(text) to authenticated;

create or replace function project_member_invite(p_project uuid, p_user uuid, p_role text default '') returns void
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; m project_members%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  select * into p from projects where id = p_project and owner_id = auth.uid();
  if not found then raise exception 'Projet introuvable'; end if;
  if p_user is null or p_user = auth.uid() then raise exception 'Choisissez un autre étudiant'; end if;
  if not exists (select 1 from profiles where id = p_user and role::text = 'student' and coalesce(suspended, false) = false) then raise exception 'Seuls des étudiants peuvent rejoindre un projet'; end if;
  if is_blocked_between(auth.uid(), p_user) then raise exception 'Cette personne ne peut pas être invitée'; end if;
  select * into m from project_members where project_id = p_project and user_id = p_user;
  if found and m.status = 'accepted' then raise exception 'Cet étudiant fait déjà partie de l''équipe'; end if;
  if found and m.status = 'invited' and m.created_at > now() - interval '24 hours' then raise exception 'Une invitation est déjà en attente de réponse'; end if;
  if found and m.status = 'declined' and coalesce(m.responded_at, m.created_at) > now() - interval '30 days' then raise exception 'Cet étudiant a refusé l''invitation : vous pourrez le réinviter dans 30 jours'; end if;
  if (select count(*) from project_members where project_id = p_project and status in ('invited', 'accepted')) >= 10 and not found then raise exception 'Dix membres au plus par projet'; end if;
  insert into project_members (project_id, user_id, role, status, invited_by) values (p_project, p_user, left(btrim(coalesce(p_role, '')), 80), 'invited', auth.uid())
  on conflict (project_id, user_id) do update set role = excluded.role, status = 'invited', invited_by = auth.uid(), created_at = now(), responded_at = null;
  perform notify_user(p_user, 'project', 'Invitation à un projet', display_name(auth.uid()) || ' vous invite à rejoindre l''équipe de « ' || left(p.title, 80) || ' ».',
    jsonb_build_object('project_id', p.id, 'invitation', true));
end $$;
revoke all on function project_member_invite(uuid, uuid, text) from public, anon;
grant execute on function project_member_invite(uuid, uuid, text) to authenticated;

-- ============================================================ 3. Concours
create table if not exists contest_invite_attempts (user_id uuid not null references profiles(id) on delete cascade, at timestamptz not null default now());
create index if not exists contest_invite_attempts_user on contest_invite_attempts (user_id, at desc);
alter table contest_invite_attempts enable row level security;
revoke all on contest_invite_attempts from anon, authenticated;

-- Réponse identique que l'adresse corresponde ou non à un compte étudiant (pas d'annuaire d'adresses), tentatives bornées.
create or replace function invite_contest_member(p_team uuid, p_email text) returns text
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype; u profiles%rowtype; n int; v_mail text := lower(btrim(coalesce(p_email, '')));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or t.captain_id <> auth.uid() then raise exception 'Seul le capitaine invite'; end if;
  if t.solo then raise exception 'Inscription individuelle : pas de coéquipier'; end if;
  if not exists (select 1 from contests where id = t.contest_id and status = 'published' and now() <= reg_close_at) then raise exception 'Les inscriptions sont closes'; end if;
  if v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(v_mail) > 254 then raise exception 'Adresse e-mail invalide'; end if;
  select count(*) into n from contest_members where team_id = t.id;
  if n >= 5 then raise exception 'Équipe complète (5 membres maximum)'; end if;
  delete from contest_invite_attempts where at < now() - interval '2 days';
  if (select count(*) from contest_invite_attempts where user_id = auth.uid() and at > now() - interval '1 hour') >= 10 then raise exception 'Trop d''invitations en peu de temps. Réessayez plus tard.'; end if;
  insert into contest_invite_attempts (user_id) values (auth.uid());
  select * into u from profiles where lower(email) = v_mail and role = 'student' and not coalesce(suspended, false) and id <> auth.uid();
  if found and not is_blocked_between(auth.uid(), u.id)
     and not exists (select 1 from contest_members m join contest_teams x on x.id = m.team_id where x.contest_id = t.contest_id and m.user_id = u.id and m.status in ('captain', 'member')) then
    insert into contest_members (team_id, user_id, status) values (t.id, u.id, 'invited') on conflict do nothing;
    if found then
      perform notify_user(u.id, 'contest', 'Invitation d''équipe', t.name, jsonb_build_object('team_id', t.id));
    end if;
  end if;
  return 'invited';
end $$;
revoke all on function invite_contest_member(uuid, text) from public, anon;
grant execute on function invite_contest_member(uuid, text) to authenticated;

create or replace function answer_contest_invite(p_team uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or not exists (select 1 from contest_members where team_id = p_team and user_id = auth.uid() and status = 'invited') then raise exception 'Invitation introuvable'; end if;
  if not p_accept then delete from contest_members where team_id = p_team and user_id = auth.uid(); return 'declined'; end if;
  if not exists (select 1 from contests where id = t.contest_id and status = 'published' and now() <= reg_close_at) then raise exception 'Les inscriptions sont closes : cette invitation n''est plus valable'; end if;
  if t.hidden then raise exception 'Cette équipe n''est plus disponible'; end if;
  if exists (select 1 from contest_submissions where team_id = t.id and submitted) then raise exception 'Le projet de cette équipe est déjà déposé'; end if;
  if (select count(*) from contest_members where team_id = t.id and status in ('captain', 'member')) >= 5 then raise exception 'Équipe complète (5 membres maximum)'; end if;
  if exists (select 1 from contest_members m join contest_teams x on x.id = m.team_id where x.contest_id = t.contest_id and m.user_id = auth.uid() and m.status in ('captain', 'member')) then
    raise exception 'Vous êtes déjà dans une équipe de ce concours';
  end if;
  update contest_members set status = 'member' where team_id = p_team and user_id = auth.uid();
  return 'member';
end $$;
revoke all on function answer_contest_invite(uuid, boolean) from public, anon;
grant execute on function answer_contest_invite(uuid, boolean) to authenticated;

create or replace function submit_contest_project(p_team uuid, p_title text, p_description text, p_demo text, p_video text, p_deck text,
  p_original boolean, p_final boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype; c contests%rowtype; sid uuid; v_demo text := nullif(trim(coalesce(p_demo, '')), ''); v_video text := nullif(trim(coalesce(p_video, '')), ''); v_deck text := nullif(trim(coalesce(p_deck, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or t.captain_id <> auth.uid() then raise exception 'Seul le capitaine dépose le projet'; end if;
  if t.hidden then raise exception 'Équipe écartée par la modération'; end if;
  select * into c from contests where id = t.contest_id;
  if c.status <> 'published' or now() > c.submit_close_at then raise exception 'Le dépôt est clos'; end if;
  if not coalesce(p_original, false) then raise exception 'Certifiez que le projet est original'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 3 and 120 then raise exception 'Titre du projet : 3 à 120 caractères'; end if;
  if char_length(trim(coalesce(p_description, ''))) not between 30 and 4000 then raise exception 'Description du projet : 30 à 4 000 caractères'; end if;
  if (v_demo is not null and v_demo !~ '^https?://[^\s]+\.[^\s]+') or (v_video is not null and v_video !~ '^https?://[^\s]+\.[^\s]+') then raise exception 'Les liens de démonstration et de vidéo doivent commencer par http:// ou https://'; end if;
  if v_deck is not null and (char_length(v_deck) > 300 or split_part(v_deck, '/', 1) <> auth.uid()::text or v_deck like '%..%') then raise exception 'Fichier de présentation invalide : déposez-le d''abord dans votre dossier'; end if;
  if exists (select 1 from contest_submissions where team_id = t.id and submitted) then raise exception 'Projet déjà soumis'; end if;
  insert into contest_submissions (team_id, title, description, demo_url, video_url, deck_path, original_certified, submitted, updated_at)
    values (t.id, trim(p_title), trim(p_description), v_demo, v_video, v_deck, true, coalesce(p_final, false), now())
  on conflict (team_id) do update set title = excluded.title, description = excluded.description, demo_url = excluded.demo_url, video_url = excluded.video_url,
    deck_path = excluded.deck_path, submitted = excluded.submitted, updated_at = now()
  returning id into sid;
  return sid;
end $$;
revoke all on function submit_contest_project(uuid, text, text, text, text, text, boolean, boolean) from public, anon;
grant execute on function submit_contest_project(uuid, text, text, text, text, text, boolean, boolean) to authenticated;

-- ============================================================ 4. Compétences et réussites
create or replace function skills_list(p_kind text default null, p_q text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'kind', s.kind, 'title', s.title, 'description', s.description, 'price', s.price, 'swap_for', s.swap_for,
      'author', display_name(s.author_id), 'author_id', s.author_id, 'mine', s.author_id = auth.uid(), 'created_at', s.created_at,
      'responses', case when s.author_id = auth.uid() then (select count(*)::int from skill_responses r where r.skill_id = s.id) end,
      'responded', exists (select 1 from skill_responses r where r.skill_id = s.id and r.user_id = auth.uid())) order by s.created_at desc), '[]'::jsonb)
  from (select * from skill_offers o where o.status = 'open'
          and (nullif(btrim(coalesce(p_kind, '')), '') is null or o.kind = p_kind)
          and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(o.title || ' ' || o.description || ' ' || o.swap_for) like '%' || lower(btrim(p_q)) || '%')
          and not exists (select 1 from profiles z where z.id = o.author_id and coalesce(z.suspended, false))
          and not is_blocked_between(auth.uid(), o.author_id)
        order by o.created_at desc limit 60) s
$$;
revoke all on function skills_list(text, text) from public;
grant execute on function skills_list(text, text) to anon, authenticated;

create or replace function victories_list(p_community uuid default null, p_limit integer default 40, p_hidden boolean default false) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'support');
begin
  if p_community is not null and not exists (select 1 from communities c where c.id = p_community and c.status = 'active' and (c.privacy = 'public' or is_community_member(c.id))) then raise exception 'Réservé aux membres de la communauté'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'kind', v.kind, 'body', v.body, 'author', display_name(v.author_id), 'mine', v.author_id = auth.uid(), 'created_at', v.created_at,
      'status', v.status,
      'cheers', (select count(*)::int from victory_cheers c where c.victory_id = v.id),
      'cheered', exists (select 1 from victory_cheers c where c.victory_id = v.id and c.user_id = auth.uid()),
      'reports', case when v_staff then (select count(*)::int from victory_reports r where r.victory_id = v.id) end,
      'reported', exists (select 1 from victory_reports r where r.victory_id = v.id and r.user_id = auth.uid())) order by v.created_at desc)
    from (select * from victories x where x.status = case when coalesce(p_hidden, false) and v_staff then 'hidden' else 'published' end and x.community_id is not distinct from p_community
            and not exists (select 1 from profiles z where z.id = x.author_id and coalesce(z.suspended, false))
            and not is_blocked_between(auth.uid(), x.author_id)
          order by x.created_at desc limit least(greatest(coalesce(p_limit, 40), 1), 100)) v), '[]'::jsonb);
end $$;
revoke all on function victories_list(uuid, integer, boolean) from public;
grant execute on function victories_list(uuid, integer, boolean) to anon, authenticated;

-- ============================================================ 5. Défis : réalisations d'un compte suspendu ni votables, ni listées, ni gagnantes
create or replace function challenge_vote(p_entry uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e challenge_entries%rowtype; c weekly_challenges%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from challenge_entries where id = p_entry;
  if not found or not _account_active(e.author_id) or is_blocked_between(auth.uid(), e.author_id) then raise exception 'Réalisation introuvable'; end if;
  select * into c from weekly_challenges where id = e.challenge_id;
  if c.ends_at <= now() then raise exception 'Les votes sont clos'; end if;
  if e.author_id = auth.uid() then raise exception 'Vous ne pouvez pas voter pour votre propre réalisation'; end if;
  insert into challenge_votes (challenge_id, user_id, entry_id) values (e.challenge_id, auth.uid(), p_entry)
  on conflict (challenge_id, user_id) do update set entry_id = excluded.entry_id, created_at = now();
end $$;
revoke all on function challenge_vote(uuid) from public, anon;
grant execute on function challenge_vote(uuid) to authenticated;

create or replace function _challenges_settle() returns integer
language plpgsql security definer set search_path = public as $$
declare c record; w uuid; v_author uuid; n integer := 0;
begin
  for c in select id, title from weekly_challenges where ends_at <= now() and winner_entry is null loop
    select e.id into w from challenge_entries e where e.challenge_id = c.id and _account_active(e.author_id)
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
                           from challenge_entries e where e.challenge_id = ch.id and _account_active(e.author_id) and not is_blocked_between(auth.uid(), e.author_id)), '[]'::jsonb)) order by (ch.ends_at <= now()), ch.ends_at desc)
    from (select * from weekly_challenges order by created_at desc limit 12) ch), '[]'::jsonb);
end $$;
revoke all on function challenges_list() from public, anon;
grant execute on function challenges_list() to authenticated;