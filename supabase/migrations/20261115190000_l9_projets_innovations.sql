-- Lot L9 « Projets et innovations » (profil Client) : fiche projet réelle, équipe liée à des comptes, journal du projet, fichiers relus,
-- liens et propriété intellectuelle enregistrés là où la fiche les lit, campagnes de financement (contribution par le flux de paiement,
-- jalons), points unifiés, SOS honnête, défis, réponses aux annonces, signalement et masquage des victoires.
-- Aucune donnée existante n'est supprimée. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Équipe d'un projet : des comptes réels invités, qui acceptent ou refusent
create table if not exists project_members (
  project_id uuid not null references projects(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default '' check (char_length(role) <= 80),
  status text not null default 'invited' check (status in ('invited', 'accepted', 'declined')),
  invited_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (project_id, user_id)
);
create index if not exists project_members_user on project_members (user_id, status);
alter table project_members enable row level security;
revoke all on project_members from anon, authenticated;

-- Étudiants dont le nom contient la saisie (invitation d'un membre).
create or replace function project_member_search(p_q text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare q text := btrim(coalesce(p_q, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if char_length(q) < 2 then return '[]'::jsonb; end if;
  q := replace(replace(replace(q, '\', ''), '%', ''), '_', '');
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'department', coalesce(x.department, ''), 'avatar_url', x.avatar_url) order by x.name)
    from (select id, name, department, avatar_url from profiles
          where role::text = 'student' and coalesce(suspended, false) = false and id <> auth.uid() and name ilike '%' || q || '%'
          order by name limit 15) x
  ), '[]'::jsonb);
end $$;

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
  select * into m from project_members where project_id = p_project and user_id = p_user;
  if found and m.status = 'accepted' then raise exception 'Cet étudiant fait déjà partie de l''équipe'; end if;
  if (select count(*) from project_members where project_id = p_project and status in ('invited', 'accepted')) >= 10 and not found then raise exception 'Dix membres au plus par projet'; end if;
  insert into project_members (project_id, user_id, role, status, invited_by) values (p_project, p_user, left(btrim(coalesce(p_role, '')), 80), 'invited', auth.uid())
  on conflict (project_id, user_id) do update set role = excluded.role, status = 'invited', invited_by = auth.uid(), created_at = now(), responded_at = null;
  perform notify_user(p_user, 'project', 'Invitation à un projet', display_name(auth.uid()) || ' vous invite à rejoindre l''équipe de « ' || left(p.title, 80) || ' ».',
    jsonb_build_object('project_id', p.id, 'invitation', true));
end $$;

create or replace function project_member_respond(p_project uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update project_members set status = case when coalesce(p_accept, false) then 'accepted' else 'declined' end, responded_at = now()
  where project_id = p_project and user_id = auth.uid() and status = 'invited';
  if not found then raise exception 'Invitation introuvable'; end if;
  select * into p from projects where id = p_project;
  perform notify_user(p.owner_id, 'project', case when coalesce(p_accept, false) then 'Nouveau membre dans l''équipe' else 'Invitation refusée' end,
    display_name(auth.uid()) || case when coalesce(p_accept, false) then ' a rejoint « ' else ' a refusé de rejoindre « ' end || left(p.title, 80) || ' ».', jsonb_build_object('project_id', p.id));
end $$;

-- Retire un membre (le porteur) ou quitte l'équipe (le membre).
create or replace function project_member_remove(p_project uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_user is distinct from auth.uid() and not exists (select 1 from projects where id = p_project and owner_id = auth.uid()) then raise exception 'Projet introuvable'; end if;
  delete from project_members where project_id = p_project and user_id = p_user;
  if not found then raise exception 'Membre introuvable'; end if;
end $$;

-- Équipe d'un projet, visible du porteur et des membres invités ou acceptés.
create or replace function project_members_list(p_project uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p projects%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from projects where id = p_project;
  if not found or not (p.owner_id = auth.uid() or exists (select 1 from project_members where project_id = p_project and user_id = auth.uid()) or coalesce(current_role_name()::text, '') in ('dept', 'admin')) then
    raise exception 'Projet introuvable';
  end if;
  return coalesce((
    select jsonb_agg(x.j order by x.ord, x.ts)
    from (
      select 0 ord, p.created_at ts, jsonb_build_object('user_id', p.owner_id, 'name', display_name(p.owner_id), 'role', 'Porteur du projet', 'status', 'owner') j
      union all
      select 1, m.created_at, jsonb_build_object('user_id', m.user_id, 'name', display_name(m.user_id), 'role', m.role, 'status', m.status)
      from project_members m where m.project_id = p_project and m.status <> 'declined'
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function my_project_invitations() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('project_id', p.id, 'title', p.title, 'role', m.role, 'from', display_name(m.invited_by), 'created_at', m.created_at) order by m.created_at desc)
    from project_members m join projects p on p.id = m.project_id where m.user_id = auth.uid() and m.status = 'invited'
  ), '[]'::jsonb);
end $$;

-- ============================================================ 2. Fiche d'un projet publié (sans coordonnées de contact) et soutien
create or replace function public_project_get(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p projects%rowtype; v_own boolean;
begin
  select * into p from projects where id = p_id;
  if not found then return null; end if;
  v_own := p.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin');
  if not ((p.status = 'approved' and p.visibility = 'public') or v_own) then return null; end if;
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

-- Soutenir un projet validé et public (ou retirer son soutien) ; on ne soutient pas son propre projet.
create or replace function project_upvote_toggle(p_project uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from projects where id = p_project and status = 'approved' and visibility = 'public') then raise exception 'Projet introuvable'; end if;
  if exists (select 1 from projects where id = p_project and owner_id = auth.uid()) then raise exception 'Vous ne pouvez pas soutenir votre propre projet'; end if;
  delete from project_upvotes where project_id = p_project and user_id = auth.uid();
  if found then return false; end if;
  insert into project_upvotes (project_id, user_id) values (p_project, auth.uid());
  return true;
end $$;

-- ============================================================ 3. Journal du projet : celui de l'utilisateur, modifiable
create or replace function my_project_steps(p_project uuid default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'project_id', s.project_id, 'project', s.ptitle, 'title', s.title, 'happened_on', s.happened_on, 'created_at', s.created_at)
                            order by s.happened_on desc, s.id desc), '[]'::jsonb)
  from (select st.*, p.title ptitle from project_steps st join projects p on p.id = st.project_id
        where p.owner_id = auth.uid() and (p_project is null or st.project_id = p_project)
        order by st.happened_on desc, st.id desc limit 200) s
$$;

create or replace function project_step_update(p_id bigint, p_title text, p_on date default current_date) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 160 then raise exception 'Étape : 3 à 160 caractères'; end if;
  if p_on > current_date + 1 then raise exception 'Une étape ne peut pas être datée dans le futur'; end if;
  update project_steps s set title = trim(p_title), happened_on = coalesce(p_on, current_date)
  where s.id = p_id and exists (select 1 from projects p where p.id = s.project_id and p.owner_id = auth.uid());
  if not found then raise exception 'Étape introuvable'; end if;
end $$;

create or replace function project_step_delete(p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from project_steps s where s.id = p_id and exists (select 1 from projects p where p.id = s.project_id and p.owner_id = auth.uid());
  if not found then raise exception 'Étape introuvable'; end if;
end $$;

-- ============================================================ 4. Fichiers déposés d'un projet : liste et retrait
create or replace function project_files_list(p_project uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from projects where id = p_project and (owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin'))) then raise exception 'Projet introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'mime', f.mime, 'size_bytes', f.size_bytes, 'path', f.path, 'created_at', f.created_at) order by f.created_at desc)
                   from files f where f.scope = 'project' and f.ref = p_project), '[]'::jsonb);
end $$;

-- Supprime l'enregistrement d'un fichier du porteur et renvoie son chemin (l'application retire ensuite l'objet du stockage).
create or replace function project_file_remove(p_file uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v files%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from files where id = p_file and owner_id = auth.uid() and scope = 'project' returning * into v;
  if v.id is null then raise exception 'Fichier introuvable'; end if;
  return v.path;
end $$;

-- ============================================================ 5. Projets : propriété intellectuelle (details.ip), médias contrôlés, liens lus par la fiche
create or replace function project_save_full(p_id uuid, p_kind text, p_title text, p_summary text, p_department text, p_details jsonb, p_media jsonb, p_visibility text, p_publish boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; d jsonb := coalesce(p_details, '{}'::jsonb); m jsonb := coalesce(p_media, '[]'::jsonb); miss text[] := '{}'; e jsonb; k text; v jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_kind not in ('innovation', 'projet') then raise exception 'Type invalide'; end if;
  if p_visibility not in ('private', 'public') then raise exception 'Visibilité invalide'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(d) <> 'object' or pg_column_size(d) > 40000 then raise exception 'Fiche trop volumineuse'; end if;
  if jsonb_typeof(m) <> 'array' or pg_column_size(m) > 12000 then raise exception 'Trop de médias'; end if;
  for e in select * from jsonb_array_elements(m) loop
    if jsonb_typeof(e) <> 'object' or coalesce(e->>'type', '') not in ('image', 'video') or coalesce(e->>'path', '') not like auth.uid()::text || '/%' or char_length(e->>'path') > 300 then
      raise exception 'Média invalide : seuls vos propres fichiers peuvent être joints';
    end if;
  end loop;
  if d ? 'ip' then
    if jsonb_typeof(d->'ip') <> 'object' or pg_column_size(d->'ip') > 4000 then raise exception 'Propriété intellectuelle : fiche invalide'; end if;
    for k, v in select * from jsonb_each(d->'ip') loop
      if jsonb_typeof(v) <> 'string' or char_length(v #>> '{}') > 500 then raise exception 'Propriété intellectuelle : « % » invalide (500 caractères au plus)', k; end if;
    end loop;
  end if;
  if p_publish then
    if char_length(trim(coalesce(p_summary, ''))) < 30 then miss := array_append(miss, 'description (30 caractères minimum)'); end if;
    if char_length(trim(coalesce(d->>'domain', ''))) < 2 then miss := array_append(miss, 'domaine'); end if;
    if char_length(trim(coalesce(d->>'problem', ''))) < 10 then miss := array_append(miss, 'problème résolu'); end if;
    if char_length(trim(coalesce(d->>'solution', ''))) < 10 then miss := array_append(miss, 'solution proposée'); end if;
    if char_length(trim(coalesce(d->>'progress', ''))) < 2 then miss := array_append(miss, 'état d''avancement'); end if;
    if char_length(trim(coalesce(d->>'contact_email', ''))) + char_length(trim(coalesce(d->>'contact_phone', ''))) < 5 then miss := array_append(miss, 'un contact'); end if;
    if array_length(miss, 1) > 0 then raise exception 'Pour publier, complétez : %', array_to_string(miss, ', '); end if;
  end if;
  if p_id is null then
    insert into projects (owner_id, kind, title, summary, department, details, media, visibility, status)
    values (auth.uid(), p_kind, trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), nullif(left(trim(coalesce(p_department, '')), 120), ''), d, m, p_visibility,
      case when p_publish then 'submitted' else 'draft' end) returning id into pid;
  else
    select * into p from projects where id = p_id and owner_id = auth.uid();
    if not found then raise exception 'Projet introuvable'; end if;
    if p.status in ('submitted', 'approved') then raise exception 'Ce projet est en cours d''examen ou déjà publié : il ne peut plus être modifié ici'; end if;
    update projects set kind = p_kind, title = trim(p_title), summary = nullif(left(trim(coalesce(p_summary, '')), 4000), ''), department = nullif(left(trim(coalesce(p_department, '')), 120), ''),
      details = d, media = m, visibility = p_visibility,
      status = case when p_publish then 'submitted' when p.status = 'rejected' then 'draft' else p.status end, updated_at = now()
    where id = p.id;
    pid := p.id;
  end if;
  if p_publish then
    insert into notifications (user_id, kind, title, body, data)
    select a.id, 'project', 'Projet à examiner', trim(p_title), jsonb_build_object('project_id', pid) from profiles a where a.role::text in ('dept', 'admin') and a.id <> auth.uid();
  end if;
  return pid;
end $$;

-- save_project (écran 278) : les liens et la propriété intellectuelle sont aussi écrits dans « details », là où la fiche publique les lit.
drop function if exists save_project(uuid, text, text, text, jsonb, boolean);
create or replace function save_project(p_id uuid, p_title text, p_summary text, p_department text, p_links jsonb, p_submit boolean, p_details jsonb default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; l jsonb := coalesce(p_links, '{}'::jsonb); next_status text; dd jsonb := '{}'::jsonb; k text; v jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(l) <> 'object' or pg_column_size(l) > 4000 then raise exception 'Liens invalides'; end if;
  if p_details is not null then
    if jsonb_typeof(p_details) <> 'object' then raise exception 'Fiche invalide'; end if;
    select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into dd from jsonb_each(p_details) where key in ('prototype_url', 'demo_url', 'doc_url', 'video_url', 'ip');
    for k, v in select * from jsonb_each(dd) loop
      if k = 'ip' then
        if jsonb_typeof(v) <> 'object' or pg_column_size(v) > 4000 then raise exception 'Propriété intellectuelle : fiche invalide'; end if;
        if exists (select 1 from jsonb_each(v) x where jsonb_typeof(x.value) <> 'string' or char_length(x.value #>> '{}') > 500) then raise exception 'Propriété intellectuelle : chaque champ contient 500 caractères au plus'; end if;
      elsif jsonb_typeof(v) <> 'string' or ((v #>> '{}') <> '' and (v #>> '{}') !~* '^https?://\S{3,300}$') then
        raise exception 'Lien invalide : une adresse commençant par http:// ou https:// est attendue';
      end if;
    end loop;
  end if;
  if p_id is null then
    if p_submit and char_length(trim(coalesce(p_summary, ''))) < 30 then raise exception 'Présentez le projet en 30 caractères minimum avant de l''envoyer'; end if;
    insert into projects (owner_id, title, summary, department, links, details, status)
    values (auth.uid(), trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), nullif(left(trim(coalesce(p_department, '')), 120), ''), l, dd, case when p_submit then 'submitted' else 'draft' end)
    returning id into pid;
    return pid;
  end if;
  select * into p from projects where id = p_id and owner_id = auth.uid() for update;
  if not found then raise exception 'Projet introuvable'; end if;
  if p.status = 'submitted' then raise exception 'Projet en cours d''examen : modification impossible jusqu''à la décision'; end if;
  if p_submit and p.status not in ('draft', 'rejected') then raise exception 'Ce projet est déjà envoyé'; end if;
  if p_submit and char_length(trim(coalesce(nullif(trim(coalesce(p_summary, '')), ''), p.summary, ''))) < 30 then
    raise exception 'Présentez le projet en 30 caractères minimum avant de l''envoyer';
  end if;
  next_status := case when p_submit or p.status = 'approved' then 'submitted' else p.status end;
  update projects set title = trim(p_title), summary = coalesce(nullif(left(trim(coalesce(p_summary, '')), 4000), ''), summary),
    department = coalesce(nullif(left(trim(coalesce(p_department, '')), 120), ''), department), links = links || l, details = coalesce(details, '{}'::jsonb) || dd,
    status = next_status, updated_at = now() where id = p.id;
  if p.status = 'approved' then
    insert into notifications (user_id, kind, title, body, data)
    select id, 'project', 'Projet modifié à revalider', trim(p_title), jsonb_build_object('project_id', p.id) from profiles where role = 'dept';
  end if;
  return p.id;
end $$;
revoke all on function save_project(uuid, text, text, text, jsonb, boolean, jsonb) from public, anon;
grant execute on function save_project(uuid, text, text, text, jsonb, boolean, jsonb) to authenticated;

-- ============================================================ 6. Campagnes de financement : projet réel, fin, contributions, jalons
alter table campaigns add column if not exists project_id uuid references projects(id) on delete set null;
alter table campaigns add column if not exists ends_at timestamptz;
update campaigns set ends_at = updated_at + make_interval(days => duration_days) where status = 'approved' and ends_at is null and duration_days is not null;

drop function if exists save_campaign(uuid, text, text, integer, integer, text, text, boolean);
create or replace function save_campaign(p_id uuid, p_kind text, p_project text, p_goal integer, p_duration_days integer, p_presentation text, p_rewards text, p_submit boolean, p_project_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype; cid uuid; v_title text := trim(coalesce(p_project, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux porteurs de projet étudiants'; end if;
  if p_kind not in ('project', 'preorder', 'sponsoring') then raise exception 'Type de campagne inconnu'; end if;
  if p_project_id is not null then
    select title into v_title from projects where id = p_project_id and owner_id = auth.uid() and status = 'approved';
    if not found then raise exception 'Choisissez l''un de vos projets validés'; end if;
  elsif p_submit then
    raise exception 'Choisissez l''un de vos projets validés pour envoyer la campagne';
  end if;
  if v_title is null or char_length(v_title) not between 3 and 120 then raise exception 'Projet : 3 à 120 caractères'; end if;
  if p_submit and (p_goal is null or p_goal < 1000 or p_duration_days is null or char_length(trim(coalesce(p_presentation, ''))) < 30) then
    raise exception 'Objectif (1 000 FCFA minimum), durée et présentation (30 caractères) sont nécessaires pour envoyer la campagne';
  end if;
  if p_goal is not null and p_goal not between 1000 and 1000000000 or p_duration_days is not null and p_duration_days not between 7 and 90 then raise exception 'Valeurs invalides'; end if;
  if p_id is null then
    insert into campaigns (owner_id, kind, project, project_id, goal, duration_days, presentation, rewards, status)
    values (auth.uid(), p_kind, v_title, p_project_id, p_goal, p_duration_days, nullif(left(trim(coalesce(p_presentation, '')), 4000), ''), nullif(left(trim(coalesce(p_rewards, '')), 2000), ''),
            case when p_submit then 'submitted' else 'draft' end) returning id into cid;
  else
    select * into c from campaigns where id = p_id and owner_id = auth.uid();
    if not found then raise exception 'Campagne introuvable'; end if;
    if c.status not in ('draft', 'rejected') then raise exception 'Cette campagne est déjà en validation ou publiée'; end if;
    update campaigns set kind = p_kind, project = v_title, project_id = p_project_id, goal = p_goal, duration_days = p_duration_days, presentation = nullif(left(trim(coalesce(p_presentation, '')), 4000), ''),
      rewards = nullif(left(trim(coalesce(p_rewards, '')), 2000), ''), status = case when p_submit then 'submitted' else 'draft' end, updated_at = now() where id = c.id returning id into cid;
  end if;
  if p_submit then
    insert into notifications (user_id, kind, title, body, data)
    select a.id, 'campaign', 'Campagne à examiner', v_title, jsonb_build_object('campaign_id', cid) from profiles a where a.role::text in ('dept', 'admin') and a.id <> auth.uid();
  end if;
  return cid;
end $$;
revoke all on function save_campaign(uuid, text, text, integer, integer, text, text, boolean, uuid) from public, anon;
grant execute on function save_campaign(uuid, text, text, integer, integer, text, text, boolean, uuid) to authenticated;

-- La validation fixe la date de fin de la collecte (durée choisie par le porteur, à partir de la validation).
create or replace function review_campaign(p_id uuid, p_approve boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into c from campaigns where id = p_id;
  if not found or c.status <> 'submitted' then raise exception 'Aucune campagne à valider'; end if;
  if not p_approve and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  update campaigns set status = case when p_approve then 'approved' else 'rejected' end, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), reviewed_by = auth.uid(), updated_at = now(),
    ends_at = case when p_approve then now() + make_interval(days => coalesce(c.duration_days, 30)) else null end where id = c.id;
  insert into notifications (user_id, kind, title, body, data) values (c.owner_id, 'campaign', case when p_approve then 'Campagne validée' else 'Campagne refusée' end, c.project, jsonb_build_object('campaign_id', c.id));
  return case when p_approve then 'approved' else 'rejected' end;
end $$;

create table if not exists campaign_contributions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete restrict,
  payment_id uuid not null unique references payment_transactions(id) on delete restrict,
  amount integer not null check (amount between 500 and 100000000),
  created_at timestamptz not null default now()
);
create index if not exists campaign_contributions_campaign on campaign_contributions (campaign_id);
alter table campaign_contributions enable row level security;
revoke all on campaign_contributions from anon, authenticated;

create table if not exists campaign_milestones (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 3 and 120),
  target_xaf integer check (target_xaf is null or target_xaf between 1 and 1000000000),
  due_on date,
  done_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists campaign_milestones_campaign on campaign_milestones (campaign_id);
alter table campaign_milestones enable row level security;
revoke all on campaign_milestones from anon, authenticated;

-- Campagnes publiques (validées) ou, avec p_mine, celles du porteur ; somme collectée = contributions dont le paiement est confirmé par la finance ou le prestataire.
create or replace function campaigns_overview(p_mine boolean default false, p_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(p_mine, false) and auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'kind', c.kind, 'project', c.project, 'project_id', c.project_id, 'goal', c.goal, 'duration_days', c.duration_days,
      'presentation', c.presentation, 'rewards', c.rewards, 'status', c.status, 'review_note', case when c.owner_id = auth.uid() then c.review_note end,
      'created_at', c.created_at, 'ends_at', c.ends_at, 'mine', c.owner_id = auth.uid(),
      'open', c.status = 'approved' and (c.ends_at is null or c.ends_at > now()),
      'raised', coalesce(x.raised, 0), 'backers', coalesce(x.backers, 0),
      'milestones', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title, 'target_xaf', m.target_xaf, 'due_on', m.due_on, 'done', m.done_at is not null)
                                               order by m.due_on nulls last, m.created_at) from campaign_milestones m where m.campaign_id = c.id), '[]'::jsonb)
    ) order by c.created_at desc)
    from (select * from campaigns where (case when coalesce(p_mine, false) then owner_id = auth.uid() else status = 'approved' end) and (p_id is null or id = p_id)
          order by created_at desc limit 100) c
    left join lateral (select sum(k.amount)::bigint raised, count(distinct k.user_id)::int backers from campaign_contributions k
                       join payment_transactions t on t.id = k.payment_id where k.campaign_id = c.id and t.status = 'confirmed') x on true
  ), '[]'::jsonb);
end $$;
revoke all on function campaigns_overview(boolean, uuid) from public;
grant execute on function campaigns_overview(boolean, uuid) to anon, authenticated;

-- Contribuer : ouvre une demande de paiement par le flux existant (payment_start) puis la rattache à la campagne ; la confirmation vient de la finance ou du prestataire.
create or replace function campaign_contribute(p_campaign uuid, p_amount integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype; pid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu : paiement impossible'; end if;
  select * into c from campaigns where id = p_campaign and status = 'approved';
  if not found then raise exception 'Campagne introuvable ou non ouverte'; end if;
  if c.ends_at is not null and c.ends_at <= now() then raise exception 'Cette campagne est terminée'; end if;
  if c.owner_id = auth.uid() then raise exception 'Vous ne pouvez pas contribuer à votre propre campagne'; end if;
  if p_amount is null or p_amount < 500 or p_amount > 100000000 then raise exception 'Contribution : 500 FCFA minimum'; end if;
  pid := payment_start('campaign', 'Contribution : ' || left(c.project, 90), p_amount, 'manual');
  insert into campaign_contributions (campaign_id, user_id, payment_id, amount) values (c.id, auth.uid(), pid, p_amount);
  return pid;
end $$;

create or replace function campaign_milestone_save(p_campaign uuid, p_id uuid, p_title text, p_target integer default null, p_due date default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from campaigns where id = p_campaign and owner_id = auth.uid() and status <> 'closed') then raise exception 'Campagne introuvable'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 120 then raise exception 'Jalon : 3 à 120 caractères'; end if;
  if p_target is not null and p_target not between 1 and 1000000000 then raise exception 'Montant du jalon invalide'; end if;
  if p_id is null then
    if (select count(*) from campaign_milestones where campaign_id = p_campaign) >= 12 then raise exception 'Douze jalons au plus par campagne'; end if;
    insert into campaign_milestones (campaign_id, title, target_xaf, due_on) values (p_campaign, btrim(p_title), p_target, p_due) returning id into mid;
  else
    update campaign_milestones set title = btrim(p_title), target_xaf = p_target, due_on = p_due where id = p_id and campaign_id = p_campaign returning id into mid;
    if mid is null then raise exception 'Jalon introuvable'; end if;
  end if;
  return mid;
end $$;

create or replace function campaign_milestone_done(p_id uuid, p_done boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update campaign_milestones m set done_at = case when coalesce(p_done, true) then now() else null end
  where m.id = p_id and exists (select 1 from campaigns c where c.id = m.campaign_id and c.owner_id = auth.uid());
  if not found then raise exception 'Jalon introuvable'; end if;
end $$;

create or replace function campaign_milestone_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from campaign_milestones m where m.id = p_id and exists (select 1 from campaigns c where c.id = m.campaign_id and c.owner_id = auth.uid());
  if not found then raise exception 'Jalon introuvable'; end if;
end $$;

-- ============================================================ 7. Points : un seul total (point_events + points_ledger)
create or replace function points_total(p_user uuid) returns integer
language sql stable security definer set search_path = public as $$
  select (coalesce((select sum(points) from point_events where user_id = p_user), 0) + coalesce((select sum(points) from points_ledger where user_id = p_user), 0))::int
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
    'events', coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'points', e.points, 'created_at', e.created_at) order by e.created_at desc)
                        from (select kind, points, created_at from point_events where user_id = auth.uid()
                              union all select source, points, created_at from points_ledger where user_id = auth.uid()
                              order by created_at desc limit 15) e), '[]'::jsonb));
end $$;

create or replace function top_helpers(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('user_id', x.user_id, 'name', display_name(x.user_id), 'total', x.total, 'level', point_level(x.total)) order by x.total desc), '[]'::jsonb)
  from (select u.user_id, sum(u.points)::int total
        from (select user_id, points from point_events union all select user_id, points from points_ledger) u
        group by u.user_id order by sum(u.points) desc limit least(greatest(coalesce(p_limit, 10), 1), 50)) x
$$;

create or replace function user_level(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('total', t.total, 'level', point_level(t.total)) from (select points_total(p_user) total) t
$$;

create or replace function community_levels(p_community uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(x.user_id, jsonb_build_object('total', x.total, 'level', point_level(x.total))), '{}'::jsonb)
  from (
    select m.user_id, points_total(m.user_id) total
    from community_members m
    join communities c on c.id = m.community_id
    where m.community_id = p_community and m.status = 'active' and c.status = 'active'
      and (c.privacy in ('public', 'approval') or is_community_member(c.id) or is_platform_staff())
  ) x
  where point_level(x.total) <> 'none'
$$;

-- ============================================================ 8. SOS : refus honnête sans filière (personne ne serait prévenu)
create or replace function sos_create(p_subject text, p_details text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_dept text; r record; v_subject text := btrim(coalesce(p_subject, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_subject) < 3 then raise exception 'Indiquez la matière ou le TP qui vous bloque'; end if;
  select coalesce(btrim(department), '') into v_dept from profiles where id = auth.uid();
  if v_dept = '' then raise exception 'Renseignez votre filière dans votre profil : sans elle, personne ne peut voir votre SOS'; end if;
  if (select count(*) from sos_requests where author_id = auth.uid() and created_at > now() - interval '1 hour') >= 3 then raise exception 'Trois SOS par heure au plus'; end if;
  insert into sos_requests (author_id, subject, details, department) values (auth.uid(), left(v_subject, 100), left(btrim(coalesce(p_details, '')), 800), v_dept) returning id into v_id;
  for r in select id from profiles where id <> auth.uid() and coalesce(suspended, false) = false and department = v_dept limit 100 loop
    perform notify_user(r.id, 'sos', 'SOS Cours : ' || left(v_subject, 60), display_name(auth.uid()) || ' est bloqué(e). Le premier qui répond gagne des points.', jsonb_build_object('sos', v_id));
  end loop;
  return v_id;
end $$;

-- ============================================================ 9. Défis : participation avec les points réellement attribués
create or replace function challenge_enter(p_challenge uuid, p_title text, p_description text default '', p_url text default '') returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_had boolean; v_has boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select exists (select 1 from point_events where user_id = auth.uid() and kind = 'challenge_entry' and ref = p_challenge::text) into v_had;
  v_id := challenge_submit(p_challenge, p_title, p_description, p_url);
  select exists (select 1 from point_events where user_id = auth.uid() and kind = 'challenge_entry' and ref = p_challenge::text) into v_has;
  return jsonb_build_object('id', v_id, 'points', case when v_has and not v_had then 5 else 0 end, 'updated', v_had);
end $$;

-- ============================================================ 10. Mur des victoires : signalement, masquage, suppression par l'auteur
create table if not exists victory_reports (
  victory_id uuid not null references victories(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  reason text not null default '' check (char_length(reason) <= 300),
  created_at timestamptz not null default now(),
  primary key (victory_id, user_id)
);
alter table victory_reports enable row level security;
revoke all on victory_reports from anon, authenticated;

create or replace function victory_report(p_id uuid, p_reason text default '') returns void
language plpgsql security definer set search_path = public as $$
declare v victories%rowtype; n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into v from victories where id = p_id and status = 'published';
  if not found then raise exception 'Réussite introuvable'; end if;
  if v.author_id = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre réussite'; end if;
  insert into victory_reports (victory_id, user_id, reason) values (p_id, auth.uid(), left(btrim(coalesce(p_reason, '')), 300)) on conflict do nothing;
  select count(*) into n from victory_reports where victory_id = p_id;
  if n >= 3 then update victories set status = 'hidden' where id = p_id; end if;
  insert into notifications (user_id, kind, title, body, data)
  select a.id, 'victory', 'Réussite signalée', left(v.body, 120), jsonb_build_object('victory', p_id) from profiles a where a.role::text in ('admin', 'support') and a.id <> auth.uid() limit 20;
end $$;

create or replace function victory_moderate(p_id uuid, p_hide boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé au support ou à l''administrateur'; end if;
  update victories set status = case when coalesce(p_hide, true) then 'hidden' else 'published' end where id = p_id;
  if not found then raise exception 'Réussite introuvable'; end if;
  if not coalesce(p_hide, true) then delete from victory_reports where victory_id = p_id; end if;
end $$;

create or replace function victory_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from victories where id = p_id and author_id = auth.uid();
  if not found then raise exception 'Réussite introuvable'; end if;
end $$;

-- p_hidden : le personnel de modération lit les réussites masquées (pour les rétablir).
drop function if exists victories_list(uuid, integer);
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
    from (select * from victories where status = case when coalesce(p_hidden, false) and v_staff then 'hidden' else 'published' end and community_id is not distinct from p_community
          order by created_at desc limit least(greatest(coalesce(p_limit, 40), 1), 100)) v), '[]'::jsonb);
end $$;

-- ============================================================ 11. Comptes suspendus : les nouvelles écritures de contenu sont refusées
do $$
declare t record;
begin
  for t in
    select * from (values
      ('victories', 'author_id'), ('victory_reports', 'user_id'), ('sos_requests', 'author_id'), ('sos_answers', 'author_id'), ('skill_offers', 'author_id'),
      ('skill_responses', 'user_id'), ('challenge_entries', 'author_id'), ('challenge_votes', 'user_id'), ('project_upvotes', 'user_id'),
      ('project_members', 'invited_by'), ('campaign_contributions', 'user_id')
    ) v(tbl, col)
  loop
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = t.tbl and column_name = t.col) then
      execute format('drop trigger if exists trg_block_suspended on %I', t.tbl);
      execute format('create trigger trg_block_suspended before insert on %I for each row execute function block_suspended_author(%L)', t.tbl, t.col);
    end if;
  end loop;
end $$;

-- ============================================================ droits d'appel
revoke all on function project_member_search(text), project_member_invite(uuid, uuid, text), project_member_respond(uuid, boolean), project_member_remove(uuid, uuid),
  project_members_list(uuid), my_project_invitations(), my_project_steps(uuid), project_step_update(bigint, text, date), project_step_delete(bigint),
  project_files_list(uuid), project_file_remove(uuid), campaign_contribute(uuid, integer), campaign_milestone_save(uuid, uuid, text, integer, date),
  campaign_milestone_done(uuid, boolean), campaign_milestone_delete(uuid), challenge_enter(uuid, text, text, text), victory_report(uuid, text),
  victory_moderate(uuid, boolean), victory_delete(uuid) from public, anon;
grant execute on function project_member_search(text), project_member_invite(uuid, uuid, text), project_member_respond(uuid, boolean), project_member_remove(uuid, uuid),
  project_members_list(uuid), my_project_invitations(), my_project_steps(uuid), project_step_update(bigint, text, date), project_step_delete(bigint),
  project_files_list(uuid), project_file_remove(uuid), campaign_contribute(uuid, integer), campaign_milestone_save(uuid, uuid, text, integer, date),
  campaign_milestone_done(uuid, boolean), campaign_milestone_delete(uuid), challenge_enter(uuid, text, text, text), victory_report(uuid, text),
  victory_moderate(uuid, boolean), victory_delete(uuid) to authenticated;
revoke all on function victories_list(uuid, integer, boolean), top_helpers(integer), user_level(uuid), community_levels(uuid) from public;
grant execute on function victories_list(uuid, integer, boolean), top_helpers(integer), user_level(uuid), community_levels(uuid) to anon, authenticated;
revoke all on function my_points() from public, anon;
grant execute on function my_points() to authenticated;
revoke all on function sos_create(text, text), review_campaign(uuid, boolean, text), project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean), project_upvote_toggle(uuid) from public, anon;
grant execute on function sos_create(text, text), review_campaign(uuid, boolean, text), project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean), project_upvote_toggle(uuid) to authenticated;

-- Retour arrière (les tables créées ici ne sont supprimées que volontairement) :
--   drop function project_member_search(text), project_member_invite(uuid, uuid, text), project_member_respond(uuid, boolean), project_member_remove(uuid, uuid), project_members_list(uuid),
--     my_project_invitations(), public_project_get(uuid), my_project_steps(uuid), project_step_update(bigint, text, date), project_step_delete(bigint), project_files_list(uuid),
--     project_file_remove(uuid), campaigns_overview(boolean, uuid), campaign_contribute(uuid, integer), campaign_milestone_save(uuid, uuid, text, integer, date),
--     campaign_milestone_done(uuid, boolean), campaign_milestone_delete(uuid), points_total(uuid), challenge_enter(uuid, text, text, text), victory_report(uuid, text),
--     victory_moderate(uuid, boolean), victory_delete(uuid), victories_list(uuid, integer, boolean);
--   recréer depuis les migrations précédentes : save_project(uuid, text, text, text, jsonb, boolean), save_campaign(uuid, text, text, integer, integer, text, text, boolean), review_campaign,
--     project_save_full, project_upvote_toggle, my_points, top_helpers, user_level, community_levels, sos_create, victories_list(uuid, integer) ;
--   drop table campaign_milestones, campaign_contributions, victory_reports, project_members ; alter table campaigns drop column project_id, drop column ends_at.
