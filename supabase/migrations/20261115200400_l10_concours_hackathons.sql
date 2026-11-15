-- Lot L10 (5/5) : hackathons et concours (écrans 160 à 166) et annonces de concours (/concours, /concours/publier, /concours/mes).
--  1. coéquipiers : l'acceptation d'une invitation (teammate_invite_decide) ajoute l'étudiant aux équipes de concours encore ouvertes de son capitaine,
--     et register_contest_team ajoute les invitations déjà acceptées ; recherche et invitation réservées aux étudiants (et au département) ;
--  2. inscription individuelle (p_solo) possible sans nom d'équipe ;
--  3. espace d'équipe réel : tâches simples (contest_tasks) et contest_team_space (équipe, membres, tâches, dépôt, échéances) ;
--  4. dépôt : messages de validation exacts, pièce jointe et vidéo contrôlées ;
--  5. résultats : certificats « Concours … — place » émis par issue_certificate aux membres des trois premières équipes à la publication des résultats ;
--  6. concours payants : colonne entry_fee (0 = gratuit) pour un filtre « Gratuits » réel ;
--  7. annonces : ann_save refuse client et étudiant ; ann_win_submit réservée aux étudiants.
-- Retour arrière : voir le bas du fichier.

alter table contests add column if not exists entry_fee integer not null default 0 check (entry_fee between 0 and 100000000);

-- ============================================================ coéquipiers
create or replace function mates_search(p_query text default '', p_category uuid default null, p_department text default '', p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_kw text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'La recherche de coéquipiers est réservée aux étudiants'; end if;
  if p_category is not null then select keywords into v_kw from mate_categories where id = p_category and active; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', display_name(t.id), 'department', coalesce(t.department, ''), 'skills', coalesce(t.skills, ''), 'avatar_url', t.avatar_url,
      'certified', t.certification::text = 'approved',
      'invite', (select i.status from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1),
      'invite_id', (select i.id from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1)) order by (t.certification::text = 'approved') desc, t.created_at desc)
    from (select * from profiles
          where role::text = 'student' and not coalesce(suspended, false) and id <> auth.uid() and nullif(btrim(coalesce(skills, '')), '') is not null
            and (nullif(btrim(coalesce(p_query, '')), '') is null or name ilike '%' || btrim(p_query) || '%' or skills ilike '%' || btrim(p_query) || '%' or coalesce(department, '') ilike '%' || btrim(p_query) || '%')
            and (nullif(btrim(coalesce(p_department, '')), '') is null or coalesce(department, '') ilike '%' || btrim(p_department) || '%')
            and (v_kw is null or exists (select 1 from unnest(v_kw) k where lower(skills || ' ' || coalesce(department, '')) ~ ('(^|[^a-zà-ÿ0-9])' || regexp_replace(k, '([.*+?^$()\[\]{}|\\])', '\\\1', 'g'))))
          order by created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) t), '[]'::jsonb);
end $$;

create or replace function teammate_invite(p_user uuid, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Les invitations d''équipe sont réservées aux étudiants'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous inviter vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user and role::text = 'student' and not coalesce(suspended, false)) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from teammate_invites where from_user = auth.uid() and to_user = p_user and status = 'pending') then raise exception 'Une invitation est déjà en attente pour cet étudiant'; end if;
  if (select count(*) from teammate_invites where from_user = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix invitations par jour au plus'; end if;
  insert into teammate_invites (from_user, to_user, message) values (auth.uid(), p_user, left(btrim(coalesce(p_message, '')), 500)) returning id into v_id;
  perform notify_user(p_user, 'teammate_invite', 'Invitation d''équipe', display_name(auth.uid()) || ' vous invite à rejoindre son équipe.', jsonb_build_object('invite', v_id));
  return v_id;
end $$;

-- Accepter une invitation rattache l'étudiant aux équipes de concours encore ouvertes de celui qui l'invite (5 membres au plus, une équipe par concours).
create or replace function teammate_invite_decide(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare i teammate_invites%rowtype; t record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into i from teammate_invites where id = p_id and to_user = auth.uid();
  if not found then raise exception 'Invitation introuvable'; end if;
  if i.status <> 'pending' then raise exception 'Cette invitation a déjà reçu une réponse'; end if;
  update teammate_invites set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where id = p_id;
  if p_accept then
    for t in
      select ct.id, ct.name from contest_teams ct join contests c on c.id = ct.contest_id
      where ct.captain_id = i.from_user and not ct.solo and not ct.hidden and c.status = 'published' and now() <= c.reg_close_at
        and (select count(*) from contest_members m where m.team_id = ct.id) < 5
        and not exists (select 1 from contest_members m join contest_teams x on x.id = m.team_id where x.contest_id = ct.contest_id and m.user_id = auth.uid() and m.status in ('captain', 'member'))
    loop
      insert into contest_members (team_id, user_id, status) values (t.id, auth.uid(), 'member') on conflict (team_id, user_id) do update set status = 'member';
      perform notify_user(auth.uid(), 'contest', 'Vous avez rejoint une équipe', left('Équipe « ' || t.name || ' ».', 500), jsonb_build_object('team_id', t.id));
    end loop;
  end if;
  perform notify_user(i.from_user, 'teammate_invite', case when p_accept then 'Invitation acceptée' else 'Invitation déclinée' end,
    display_name(auth.uid()) || case when p_accept then ' rejoint votre équipe : écrivez-lui pour vous organiser.' else ' ne peut pas rejoindre votre équipe.' end, jsonb_build_object('invite', p_id));
  return case when p_accept then 'accepted' else 'declined' end;
end $$;

-- ============================================================ inscription (individuelle ou en équipe)
create or replace function register_contest_team(p_contest uuid, p_name text, p_theme text, p_solo boolean, p_rules boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare c contests%rowtype; tid uuid; taken int; v_name text; r record; v_solo boolean := coalesce(p_solo, false);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Inscription réservée aux étudiants'; end if;
  if not coalesce(p_rules, false) then raise exception 'Acceptez le règlement du concours'; end if;
  v_name := trim(coalesce(p_name, ''));
  if v_solo and char_length(v_name) = 0 then v_name := left(display_name(auth.uid()), 40) || ' (individuel)'; end if;
  if char_length(v_name) not between 3 and 60 then raise exception 'Nom d''équipe : 3 à 60 caractères'; end if;
  select * into c from contests where id = p_contest for update;
  if not found or c.status <> 'published' then raise exception 'Ce concours ne reçoit pas d''inscriptions'; end if;
  if now() > c.reg_close_at then raise exception 'Les inscriptions sont closes'; end if;
  if exists (select 1 from contest_members m join contest_teams t on t.id = m.team_id where t.contest_id = c.id and m.user_id = auth.uid() and m.status in ('captain', 'member')) then
    raise exception 'Vous êtes déjà inscrit à ce concours';
  end if;
  select count(*) into taken from contest_teams where contest_id = c.id and not hidden;
  if taken >= c.places then raise exception 'Plus de places disponibles'; end if;
  begin
    insert into contest_teams (contest_id, name, theme, captain_id, solo, rules_accepted_at)
      values (c.id, v_name, left(coalesce(trim(p_theme), ''), 120), auth.uid(), v_solo, now()) returning id into tid;
  exception when unique_violation then
    raise exception 'Ce nom d''équipe est déjà pris pour ce concours';
  end;
  insert into contest_members (team_id, user_id, status) values (tid, auth.uid(), 'captain');
  if not v_solo then
    for r in
      select i.to_user from teammate_invites i join profiles p on p.id = i.to_user
      where i.from_user = auth.uid() and i.status = 'accepted' and i.decided_at > now() - interval '30 days' and p.role::text = 'student' and not coalesce(p.suspended, false)
        and not exists (select 1 from contest_members m join contest_teams x on x.id = m.team_id where x.contest_id = c.id and m.user_id = i.to_user and m.status in ('captain', 'member'))
      order by i.decided_at limit 4
    loop
      insert into contest_members (team_id, user_id, status) values (tid, r.to_user, 'member') on conflict do nothing;
      perform notify_user(r.to_user, 'contest', 'Vous avez rejoint une équipe', left('Équipe « ' || v_name || ' » · ' || c.title, 500), jsonb_build_object('team_id', tid));
    end loop;
  end if;
  return tid;
end $$;

-- ============================================================ espace d'équipe
create table if not exists contest_tasks (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references contest_teams(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 120),
  assignee_id uuid references profiles(id) on delete set null,
  done boolean not null default false,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists contest_tasks_team on contest_tasks (team_id, created_at);
alter table contest_tasks enable row level security;
revoke all on contest_tasks from anon, authenticated;
grant select on contest_tasks to authenticated;
drop policy if exists "tâches d'équipe : membres et département" on contest_tasks;
create policy "tâches d'équipe : membres et département" on contest_tasks for select using (is_contest_member(team_id) or is_contest_staff());

create or replace function contest_task_save(p_team uuid, p_id uuid, p_title text, p_done boolean default false, p_assignee uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; t contest_teams%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or not is_contest_member(p_team) then raise exception 'Réservé aux membres de l''équipe'; end if;
  if t.hidden then raise exception 'Équipe écartée par la modération'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 2 and 120 then raise exception 'Tâche : 2 à 120 caractères'; end if;
  if p_assignee is not null and not exists (select 1 from contest_members where team_id = p_team and user_id = p_assignee and status in ('captain', 'member')) then raise exception 'Cette personne ne fait pas partie de l''équipe'; end if;
  if p_id is null then
    if (select count(*) from contest_tasks where team_id = p_team) >= 30 then raise exception 'Trente tâches au plus par équipe'; end if;
    insert into contest_tasks (team_id, title, assignee_id, done, created_by) values (p_team, btrim(p_title), p_assignee, coalesce(p_done, false), auth.uid()) returning id into v;
  else
    update contest_tasks set title = btrim(p_title), assignee_id = p_assignee, done = coalesce(p_done, false) where id = p_id and team_id = p_team returning id into v;
    if v is null then raise exception 'Tâche introuvable'; end if;
  end if;
  return v;
end $$;

create or replace function contest_task_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t contest_tasks%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_tasks where id = p_id;
  if not found or not is_contest_member(t.team_id) then raise exception 'Tâche introuvable'; end if;
  delete from contest_tasks where id = p_id;
end $$;

create or replace function contest_team_space(p_contest uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t contest_teams%rowtype; c contests%rowtype; s contest_submissions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select ct.* into t from contest_teams ct join contest_members m on m.team_id = ct.id where ct.contest_id = p_contest and m.user_id = auth.uid() and m.status in ('captain', 'member') limit 1;
  if not found then return null; end if;
  select * into c from contests where id = p_contest;
  select * into s from contest_submissions where team_id = t.id;
  return jsonb_build_object(
    'team', jsonb_build_object('id', t.id, 'name', t.name, 'theme', t.theme, 'solo', t.solo, 'captain', t.captain_id = auth.uid(), 'hidden', t.hidden, 'hidden_reason', t.hidden_reason),
    'contest', jsonb_build_object('id', c.id, 'title', c.title, 'status', c.status, 'reg_close_at', c.reg_close_at, 'submit_close_at', c.submit_close_at),
    'members', coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'name', display_name(m.user_id), 'status', m.status, 'me', m.user_id = auth.uid(),
          'invite_id', (select i.id from teammate_invites i where i.status = 'accepted' and ((i.from_user = auth.uid() and i.to_user = m.user_id) or (i.to_user = auth.uid() and i.from_user = m.user_id)) order by i.created_at desc limit 1))
          order by (m.status = 'captain') desc, m.created_at)
        from contest_members m where m.team_id = t.id), '[]'::jsonb),
    'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'title', k.title, 'done', k.done, 'assignee_id', k.assignee_id, 'assignee', case when k.assignee_id is not null then display_name(k.assignee_id) end) order by k.created_at)
        from contest_tasks k where k.team_id = t.id), '[]'::jsonb),
    'submission', case when s.id is null then null else jsonb_build_object('title', s.title, 'submitted', s.submitted, 'has_deck', s.deck_path is not null, 'updated_at', s.updated_at) end);
end $$;

-- ============================================================ dépôt : messages exacts, pièce jointe et vidéo contrôlées
create or replace function submit_contest_project(p_team uuid, p_title text, p_description text, p_demo text, p_video text, p_deck text,
  p_original boolean, p_final boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype; c contests%rowtype; sid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or t.captain_id <> auth.uid() then raise exception 'Seul le capitaine dépose le projet'; end if;
  if t.hidden then raise exception 'Équipe écartée par la modération'; end if;
  select * into c from contests where id = t.contest_id;
  if c.status <> 'published' or now() > c.submit_close_at then raise exception 'Le dépôt est clos'; end if;
  if not coalesce(p_original, false) then raise exception 'Certifiez que le projet est original'; end if;
  if exists (select 1 from contest_submissions where team_id = t.id and submitted) then raise exception 'Projet déjà soumis'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 3 and 120 then raise exception 'Titre du projet : 3 à 120 caractères'; end if;
  if char_length(trim(coalesce(p_description, ''))) not between 30 and 4000 then raise exception 'Description : 30 à 4 000 caractères'; end if;
  if nullif(trim(coalesce(p_demo, '')), '') is not null and trim(p_demo) !~ '^https?://[^\s]+\.[^\s]+' then raise exception 'Le lien de démonstration doit commencer par http:// ou https://'; end if;
  if nullif(trim(coalesce(p_video, '')), '') is not null and trim(p_video) !~ '^https?://[^\s]+\.[^\s]+' then raise exception 'Le lien de la vidéo doit commencer par http:// ou https://'; end if;
  if nullif(trim(coalesce(p_deck, '')), '') is not null and ((storage.foldername(trim(p_deck)))[1] is distinct from auth.uid()::text or char_length(trim(p_deck)) > 300) then raise exception 'Pièce jointe invalide : déposez-la depuis l''application'; end if;
  insert into contest_submissions (team_id, title, description, demo_url, video_url, deck_path, original_certified, submitted, updated_at)
    values (t.id, trim(p_title), trim(p_description), nullif(trim(coalesce(p_demo, '')), ''), nullif(trim(coalesce(p_video, '')), ''), nullif(trim(coalesce(p_deck, '')), ''),
            true, coalesce(p_final, false), now())
  on conflict (team_id) do update set title = excluded.title, description = excluded.description, demo_url = excluded.demo_url, video_url = excluded.video_url,
    deck_path = coalesce(excluded.deck_path, contest_submissions.deck_path), submitted = excluded.submitted, updated_at = now()
  returning id into sid;
  return sid;
end $$;

-- ============================================================ résultats : podium et certificats
create or replace function _contest_podium(p_contest uuid) returns table (rank integer, team_id uuid, team_name text, project text, total numeric)
language sql stable security definer set search_path = public as $$
  with agg as (
    select t.id as team_id, t.name, s.title, s.updated_at, avg(sc.innovation + sc.feasibility + sc.impact + sc.pitch)::numeric(5, 2) as total,
           avg(sc.innovation) as innovation, avg(sc.impact) as impact
    from contest_submissions s join contest_teams t on t.id = s.team_id and not t.hidden left join contest_scores sc on sc.submission_id = s.id
    where t.contest_id = p_contest and s.submitted
    group by t.id, t.name, s.title, s.updated_at)
  select (row_number() over (order by total desc nulls last, innovation desc nulls last, impact desc nulls last, updated_at))::int, team_id, name, title, total from agg
$$;
revoke all on function _contest_podium(uuid) from public, anon, authenticated;

create or replace function set_contest_status(p_contest uuid, p_status text) returns text
language plpgsql security definer set search_path = public as $$
declare c contests%rowtype; missing int; pod record; mem record; v_label text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_contest_staff() then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into c from contests where id = p_contest for update;
  if not found then raise exception 'Concours introuvable'; end if;
  if not ((c.status = 'published' and p_status in ('judging', 'cancelled'))
       or (c.status = 'judging' and p_status in ('results', 'cancelled'))
       or (c.status = 'draft' and p_status = 'cancelled')) then
    raise exception 'Transition non autorisée (% vers %)', c.status, p_status;
  end if;
  if p_status = 'judging' and now() < c.submit_close_at then raise exception 'Le jury commence après la clôture des dépôts'; end if;
  if p_status = 'results' then
    select count(*) into missing from contest_submissions s join contest_teams t on t.id = s.team_id
      where t.contest_id = c.id and s.submitted and not t.hidden and (select count(*) from contest_scores x where x.submission_id = s.id) < 2;
    if missing > 0 then raise exception 'Résultats impossibles : % projet(s) ont moins de 2 notes', missing; end if;
  end if;
  update contests set status = p_status, updated_at = now() where id = c.id;
  insert into notifications (user_id, kind, title, body, data)
    select distinct m.user_id, 'contest',
      case p_status when 'results' then 'Résultats publiés' when 'cancelled' then 'Concours annulé' else 'Délibération du jury' end,
      c.title, jsonb_build_object('contest_id', c.id, 'status', p_status)
    from contest_members m join contest_teams t on t.id = m.team_id where t.contest_id = c.id and m.status in ('captain', 'member');
  if p_status = 'results' then
    for pod in select * from _contest_podium(c.id) where rank <= 3 and total is not null loop
      v_label := case pod.rank when 1 then '1re place' when 2 then '2e place' else '3e place' end;
      for mem in select p.email, p.name, p.department from contest_members m join profiles p on p.id = m.user_id
                 where m.team_id = pod.team_id and m.status in ('captain', 'member') and not coalesce(p.suspended, false) loop
        begin
          perform issue_certificate('talent', 'Concours « ' || left(c.title, 90) || ' » — ' || v_label, mem.email, mem.name, mem.department);
        exception when others then
          raise warning 'Certificat de concours non émis pour % : %', mem.email, sqlerrm;
        end;
      end loop;
    end loop;
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Concours : ' || c.status || ' → ' || p_status, c.title, 'Concours', 'Sensible');
  return p_status;
end $$;

-- ============================================================ annonces de concours : rôles
create or replace function ann_save(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept'); v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform company_gate('contest', nullif(p->>'id', '')::uuid);
  if v_role not in ('admin', 'dept', 'direction', 'support', 'finance', 'company', 'other') then raise exception 'Réservé à l''équipe, aux départements, aux entreprises et aux ONG'; end if;
  if char_length(btrim(coalesce(p->>'title', ''))) < 3 then raise exception 'Indiquez le titre du concours'; end if;
  if char_length(btrim(coalesce(p->>'organizer', ''))) < 2 then raise exception 'Indiquez l''organisateur'; end if;
  if coalesce(p->>'kind', '') not in ('contest', 'scholarship', 'hackathon', 'call', 'internship', 'job', 'training') then raise exception 'Type inconnu'; end if;
  if coalesce(p->>'official_url', '') !~* '^https?://[^ ]+\.[^ ]+' then raise exception 'Indiquez le lien officiel (commençant par http)'; end if;
  begin
    if nullif(p->>'deadline', '') is not null and (p->>'deadline')::date < current_date then raise exception 'La date limite doit être dans le futur'; end if;
    perform nullif(p->>'opens_on', '')::date, nullif(p->>'results_on', '')::date, nullif(p->>'program_start', '')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception 'Une des dates est invalide : utilisez le format AAAA-MM-JJ';
  end;
  if nullif(p->>'cost_amount', '') is not null and (p->>'cost_amount') !~ '^[0-9]{1,9}$' then raise exception 'Le coût doit être un nombre entier de 9 chiffres au plus'; end if;
  if (select count(*) from contest_announcements where poster_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix annonces par jour au plus'; end if;
  insert into contest_announcements (poster_id, title, organizer, organizer_kind, country, place_kind, place, domain, kind, description, why, conditions, documents, steps, criteria,
      opens_on, deadline, results_on, program_start, reward, eligible_level, eligible_age, eligible_department, eligible_country, iut_only, free, cost_amount, cost_currency, official_url, verified, status)
  values (auth.uid(), btrim(p->>'title'), btrim(p->>'organizer'), coalesce(nullif(p->>'organizer_kind', ''), 'other'), left(coalesce(p->>'country', ''), 60), coalesce(nullif(p->>'place_kind', ''), 'online'), left(coalesce(p->>'place', ''), 100),
      coalesce(nullif(p->>'domain', ''), 'other'), p->>'kind', left(coalesce(p->>'description', ''), 4000), left(coalesce(p->>'why', ''), 1000),
      coalesce(array(select jsonb_array_elements_text(coalesce(p->'conditions', '[]'::jsonb))), '{}'), coalesce(array(select jsonb_array_elements_text(coalesce(p->'documents', '[]'::jsonb))), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(p->'steps', '[]'::jsonb))), '{}'), coalesce(array(select jsonb_array_elements_text(coalesce(p->'criteria', '[]'::jsonb))), '{}'),
      nullif(p->>'opens_on', '')::date, nullif(p->>'deadline', '')::date, nullif(p->>'results_on', '')::date, nullif(p->>'program_start', '')::date,
      left(coalesce(p->>'reward', ''), 200), left(coalesce(p->>'eligible_level', ''), 80), left(coalesce(p->>'eligible_age', ''), 40), left(coalesce(p->>'eligible_department', ''), 120), left(coalesce(p->>'eligible_country', ''), 80),
      coalesce((p->>'iut_only')::boolean, false), coalesce((p->>'free')::boolean, true), nullif(p->>'cost_amount', '')::integer, coalesce(nullif(p->>'cost_currency', ''), 'FCFA'), btrim(p->>'official_url'),
      v_staff, case when v_staff then 'published' else 'pending' end)
  returning id into v_id;
  if not v_staff then
    for r in select id from profiles where role::text = 'admin' loop
      perform notify_user(r.id, 'contest_review', 'Concours à valider', btrim(p->>'organizer') || ' propose « ' || btrim(p->>'title') || ' ».', jsonb_build_object('announcement', v_id));
    end loop;
  end if;
  return v_id;
end $$;

create or replace function ann_win_submit(p_title text, p_prize text, p_year integer, p_proof text, p_announcement uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Seuls les étudiants peuvent déclarer une victoire'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Indiquez le nom du concours gagné'; end if;
  if coalesce(p_proof, '') !~* '^https?://[^ ]+\.[^ ]+' then raise exception 'Joignez un lien de preuve (article, photo, page officielle)'; end if;
  if (select count(*) from contest_ann_wins where student_id = auth.uid() and created_at > now() - interval '1 day') >= 3 then raise exception 'Trois déclarations par jour au plus'; end if;
  insert into contest_ann_wins (student_id, contest_title, announcement_id, prize, year, proof_url) values (auth.uid(), btrim(p_title), p_announcement, left(btrim(coalesce(p_prize, '')), 120), p_year, btrim(p_proof)) returning id into v_id;
  for r in select id from profiles where role::text = 'admin' loop
    perform notify_user(r.id, 'contest_review', 'Victoire à valider', display_name(auth.uid()) || ' déclare avoir gagné « ' || btrim(p_title) || ' ».', jsonb_build_object('win', v_id));
  end loop;
  return v_id;
end $$;

revoke all on function mates_search(text, uuid, text, integer), teammate_invite(uuid, text), teammate_invite_decide(uuid, boolean), register_contest_team(uuid, text, text, boolean, boolean),
  contest_task_save(uuid, uuid, text, boolean, uuid), contest_task_delete(uuid), contest_team_space(uuid), submit_contest_project(uuid, text, text, text, text, text, boolean, boolean),
  set_contest_status(uuid, text), ann_save(jsonb), ann_win_submit(text, text, integer, text, uuid) from public, anon;
grant execute on function mates_search(text, uuid, text, integer), teammate_invite(uuid, text), teammate_invite_decide(uuid, boolean), register_contest_team(uuid, text, text, boolean, boolean),
  contest_task_save(uuid, uuid, text, boolean, uuid), contest_task_delete(uuid), contest_team_space(uuid), submit_contest_project(uuid, text, text, text, text, text, boolean, boolean),
  set_contest_status(uuid, text), ann_save(jsonb), ann_win_submit(text, text, integer, text, uuid) to authenticated;

-- Retour arrière : recréer depuis leurs migrations d'origine mates_search (20261114002200), teammate_invite et teammate_invite_decide (20261114001500), register_contest_team,
--   submit_contest_project et set_contest_status (20261101000200), ann_save et ann_win_submit (20261114001400) ;
--   drop function contest_task_save(uuid, uuid, text, boolean, uuid), contest_task_delete(uuid), contest_team_space(uuid), _contest_podium(uuid) ;
--   drop table contest_tasks ; alter table contests drop column entry_fee.
