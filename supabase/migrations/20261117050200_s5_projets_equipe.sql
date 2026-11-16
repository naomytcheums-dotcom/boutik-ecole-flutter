-- Lot S5 — projets et équipes : le membre accepté retrouve ses projets (journal, fichiers, « Quitter l'équipe »), validation serveur de la fiche,
-- relecture cloisonnée par département, modification d'un projet publié avec revalidation notifiée, anti-harcèlement des invitations, plafonds de dépôt.
-- Corrige S5-1, S5-5, S5-6, S5-7, S5-9 (partiel : dépôt visible de l'équipe), S5-19, S5-22, S5-23, S5-24, S5-27, S5-41.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (etu_s5.mjs).
-- Retour arrière : recréer project_save_full, project_member_invite, project_member_search, project_member_remove, add_project_step, my_project_steps, project_step_update,
--   project_step_delete, project_files_list, project_file_remove, register_file, storage_file_allowed, review_project, project_upvote_toggle depuis 20261115190000 / 20261031000200 / 20261031000100 / 20261031000000 ;
--   drop function if exists my_member_projects(), _project_reviewers(text), _can_review_dept(text), _project_member_ok(uuid, uuid), _project_details_clean(jsonb);
--   drop table if exists project_member_searches; alter table project_steps drop column if exists created_by.

alter table project_steps add column if not exists created_by uuid references profiles(id) on delete set null;
create table if not exists project_member_searches (user_id uuid not null references profiles(id) on delete cascade, at timestamptz not null default now());
create index if not exists project_member_searches_user on project_member_searches (user_id, at desc);
alter table project_member_searches enable row level security;
revoke all on project_member_searches from anon, authenticated;

-- ============================================================ 1. Outils internes
create or replace function _project_member_ok(p_project uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from project_members where project_id = p_project and user_id = p_user and status = 'accepted')
$$;
revoke all on function _project_member_ok(uuid, uuid) from public, anon, authenticated;

-- Responsables qui relisent un projet : l'administration et les responsables du département du projet (à défaut de correspondance, tous les responsables de département).
create or replace function _project_reviewers(p_dept text) returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from profiles where role::text = 'admin' and not coalesce(suspended, false)
  union
  select d.id from profiles d where d.role::text = 'dept' and not coalesce(d.suspended, false) and (
    nullif(lower(btrim(coalesce(p_dept, ''))), '') is null
    or lower(btrim(coalesce(d.department, ''))) = lower(btrim(p_dept))
    or not exists (select 1 from profiles x where x.role::text = 'dept' and not coalesce(x.suspended, false) and lower(btrim(coalesce(x.department, ''))) = lower(btrim(p_dept))))
$$;
revoke all on function _project_reviewers(text) from public, anon, authenticated;

create or replace function _can_review_dept(p_dept text) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (select 1 from _project_reviewers(p_dept) r where r = auth.uid())
$$;
revoke all on function _can_review_dept(text) from public, anon, authenticated;

-- Fiche : clés connues seulement, liens http(s), montant en chiffres, tailles bornées.
create or replace function _project_details_clean(d jsonb) returns jsonb
language plpgsql immutable set search_path = public as $$
declare out jsonb := '{}'::jsonb; k text; v jsonb; t jsonb;
begin
  if jsonb_typeof(d) <> 'object' then raise exception 'Fiche invalide'; end if;
  for k, v in select * from jsonb_each(d) loop
    if k in ('domain', 'progress', 'problem', 'solution', 'done_steps', 'objectives', 'support_needs', 'contact_email', 'contact_phone') then
      if jsonb_typeof(v) <> 'string' or char_length(v #>> '{}') > 4000 then raise exception 'Fiche : « % » invalide (texte de 4000 caractères au plus)', k; end if;
      if k = 'domain' and char_length(v #>> '{}') > 80 then raise exception 'Domaine : 80 caractères au plus'; end if;
      if k in ('contact_email', 'contact_phone') and char_length(v #>> '{}') > 120 then raise exception 'Contact : 120 caractères au plus'; end if;
      out := out || jsonb_build_object(k, v);
    elsif k in ('prototype_url', 'demo_url', 'doc_url', 'video_url') then
      if jsonb_typeof(v) <> 'string' or ((v #>> '{}') <> '' and ((v #>> '{}') !~* '^https?://\S{3,}$' or char_length(v #>> '{}') > 300)) then
        raise exception 'Lien invalide : une adresse commençant par http:// ou https:// est attendue';
      end if;
      out := out || jsonb_build_object(k, v);
    elsif k = 'funding_xaf' then
      if jsonb_typeof(v) not in ('string', 'number') or (v #>> '{}') !~ '^[0-9]{0,12}$' then raise exception 'Besoin de financement : un nombre de FCFA (12 chiffres au plus) est attendu'; end if;
      out := out || jsonb_build_object(k, v);
    elsif k = 'team' then
      if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) > 20 then raise exception 'Équipe : 20 contributeurs au plus'; end if;
      for t in select * from jsonb_array_elements(v) loop
        if jsonb_typeof(t) <> 'object' or char_length(coalesce(t->>'name', '')) > 80 or char_length(coalesce(t->>'role', '')) > 80 then raise exception 'Équipe : nom et rôle de 80 caractères au plus'; end if;
      end loop;
      out := out || jsonb_build_object(k, v);
    elsif k = 'ip' then
      out := out || jsonb_build_object(k, v);
    end if; -- toute autre clé est ignorée
  end loop;
  return out;
end $$;
revoke all on function _project_details_clean(jsonb) from public, anon, authenticated;

-- ============================================================ 2. Fiche : validation serveur, relecture cloisonnée, modification d'un projet publié avec revalidation
create or replace function project_save_full(p_id uuid, p_kind text, p_title text, p_summary text, p_department text, p_details jsonb, p_media jsonb, p_visibility text, p_publish boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; d jsonb := coalesce(p_details, '{}'::jsonb); m jsonb := coalesce(p_media, '[]'::jsonb); miss text[] := '{}'; e jsonb; k text; v jsonb; v_dept text := nullif(left(trim(coalesce(p_department, '')), 120), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_kind not in ('innovation', 'projet') then raise exception 'Type invalide'; end if;
  if p_visibility not in ('private', 'public') then raise exception 'Visibilité invalide'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(d) <> 'object' or pg_column_size(d) > 40000 then raise exception 'Fiche trop volumineuse'; end if;
  if jsonb_typeof(m) <> 'array' or pg_column_size(m) > 12000 then raise exception 'Trop de médias'; end if;
  d := _project_details_clean(d);
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
    values (auth.uid(), p_kind, trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), v_dept, d, m, p_visibility, case when p_publish then 'submitted' else 'draft' end) returning id into pid;
  else
    select * into p from projects where id = p_id and owner_id = auth.uid() for update;
    if not found then raise exception 'Projet introuvable'; end if;
    if p.status = 'submitted' then raise exception 'Ce projet est en cours d''examen : il ne peut plus être modifié jusqu''à la décision'; end if;
    if p.status = 'approved' and not p_publish then raise exception 'Un projet publié ne se modifie qu''en le renvoyant en validation (il quitte le catalogue jusqu''à la décision)'; end if;
    update projects set kind = p_kind, title = trim(p_title), summary = nullif(left(trim(coalesce(p_summary, '')), 4000), ''), department = v_dept,
      details = d, media = m, visibility = p_visibility,
      status = case when p_publish then 'submitted' when p.status = 'rejected' then 'draft' else p.status end, updated_at = now()
    where id = p.id;
    pid := p.id;
  end if;
  if p_publish then
    insert into notifications (user_id, kind, title, body, data)
    select r, 'project', case when p.status = 'approved' then 'Projet modifié à revalider' else 'Projet à examiner' end, trim(p_title), jsonb_build_object('project_id', pid)
    from _project_reviewers(v_dept) r where r <> auth.uid();
    if p.status = 'approved' then
      insert into notifications (user_id, kind, title, body, data)
      values (auth.uid(), 'project', 'Projet renvoyé en validation',
              left('« ' || trim(p_title) || ' » n''est plus dans le catalogue public jusqu''à la décision du département. Sa campagne éventuelle reste ouverte.', 500), jsonb_build_object('project_id', pid));
    end if;
  end if;
  return pid;
end $$;
revoke all on function project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean) from public, anon;
grant execute on function project_save_full(uuid, text, text, text, text, jsonb, jsonb, text, boolean) to authenticated;

-- Écran 278 : le projet modifié est signalé aux responsables concernés (pas seulement « dept ») et le porteur est prévenu du retrait du catalogue.
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
      elsif jsonb_typeof(v) <> 'string' or ((v #>> '{}') <> '' and ((v #>> '{}') !~* '^https?://\S{3,}$' or char_length(v #>> '{}') > 300)) then
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
    select r, 'project', 'Projet modifié à revalider', trim(p_title), jsonb_build_object('project_id', p.id) from _project_reviewers(p.department) r where r <> auth.uid();
    insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'project', 'Projet renvoyé en validation',
            left('« ' || trim(p_title) || ' » n''est plus dans le catalogue public jusqu''à la décision du département. Sa campagne éventuelle reste ouverte.', 500), jsonb_build_object('project_id', p.id));
  end if;
  return p.id;
end $$;
revoke all on function save_project(uuid, text, text, text, jsonb, boolean, jsonb) from public, anon;
grant execute on function save_project(uuid, text, text, text, jsonb, boolean, jsonb) to authenticated;

-- Un responsable de département ne valide que les projets de son département (à défaut de correspondance : tout responsable ; l'administration valide toujours).
create or replace function review_project(p_id uuid, p_approve boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into p from projects where id = p_id;
  if not found or p.status <> 'submitted' then raise exception 'Aucun projet à examiner'; end if;
  if not _can_review_dept(p.department) then raise exception 'Ce projet relève d''un autre département'; end if;
  if not p_approve and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  update projects set status = case when p_approve then 'approved' else 'rejected' end, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), updated_at = now() where id = p.id;
  insert into notifications (user_id, kind, title, body, data) values (p.owner_id, 'project', case when p_approve then 'Projet accepté' else 'Projet refusé' end, p.title, jsonb_build_object('project_id', p.id));
  return case when p_approve then 'approved' else 'rejected' end;
end $$;

-- ============================================================ 3. Équipe : annuaire limité, ré-invitation encadrée, retrait notifié
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
          where role::text = 'student' and coalesce(suspended, false) = false and coalesce(directory_listed, true) and id <> auth.uid() and name ilike '%' || q || '%'
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

-- Retire un membre (le porteur) ou quitte l'équipe (le membre) : l'autre partie est prévenue.
create or replace function project_member_remove(p_project uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; v_status text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from projects where id = p_project;
  if not found then raise exception 'Projet introuvable'; end if;
  if p_user is distinct from auth.uid() and p.owner_id is distinct from auth.uid() then raise exception 'Projet introuvable'; end if;
  delete from project_members where project_id = p_project and user_id = p_user returning status into v_status;
  if not found then raise exception 'Membre introuvable'; end if;
  if v_status = 'accepted' or p_user is distinct from auth.uid() then
    if p_user = auth.uid() then
      perform notify_user(p.owner_id, 'project', 'Un membre a quitté l''équipe', display_name(auth.uid()) || ' a quitté l''équipe de « ' || left(p.title, 80) || ' ».', jsonb_build_object('project_id', p.id));
    else
      perform notify_user(p_user, 'project', 'Retiré d''une équipe de projet', 'Vous ne faites plus partie de l''équipe de « ' || left(p.title, 80) || ' ».', jsonb_build_object('project_id', p.id));
    end if;
  end if;
end $$;
revoke all on function project_member_remove(uuid, uuid) from public, anon;
grant execute on function project_member_remove(uuid, uuid) to authenticated;

-- Projets où la personne est membre accepté (lecture seule de la fiche, journal, fichiers, sortie de l'équipe).
create or replace function my_member_projects() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'title', p.title, 'status', p.status, 'department', p.department, 'owner', display_name(p.owner_id),
      'role', m.role, 'joined_at', m.responded_at, 'updated_at', p.updated_at, 'member', true) order by p.updated_at desc)
    from project_members m join projects p on p.id = m.project_id where m.user_id = auth.uid() and m.status = 'accepted'
  ), '[]'::jsonb);
end $$;
revoke all on function my_member_projects() from public, anon;
grant execute on function my_member_projects() to authenticated;

-- ============================================================ 4. Journal : le porteur et les membres acceptés contribuent
create or replace function add_project_step(p_project uuid, p_title text, p_on date default current_date) returns bigint
language plpgsql security definer set search_path = public as $$
declare sid bigint;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not (exists (select 1 from projects where id = p_project and owner_id = auth.uid()) or _project_member_ok(p_project, auth.uid())) then raise exception 'Projet introuvable'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 160 then raise exception 'Étape : 3 à 160 caractères'; end if;
  if p_on > current_date + 1 then raise exception 'Une étape ne peut pas être datée dans le futur'; end if;
  insert into project_steps (project_id, title, happened_on, created_by) values (p_project, trim(p_title), coalesce(p_on, current_date), auth.uid()) returning id into sid;
  return sid;
end $$;
revoke all on function add_project_step(uuid, text, date) from public, anon;
grant execute on function add_project_step(uuid, text, date) to authenticated;

create or replace function my_project_steps(p_project uuid default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'project_id', s.project_id, 'project', s.ptitle, 'title', s.title, 'happened_on', s.happened_on, 'created_at', s.created_at,
                                               'author', case when s.created_by is null then null else display_name(s.created_by) end, 'mine', s.created_by = auth.uid() or s.owner_id = auth.uid())
                            order by s.happened_on desc, s.id desc), '[]'::jsonb)
  from (select st.*, p.title ptitle, p.owner_id from project_steps st join projects p on p.id = st.project_id
        where (p.owner_id = auth.uid() or _project_member_ok(p.id, auth.uid())) and (p_project is null or st.project_id = p_project)
        order by st.happened_on desc, st.id desc limit 200) s
$$;

create or replace function project_step_update(p_id bigint, p_title text, p_on date default current_date) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 160 then raise exception 'Étape : 3 à 160 caractères'; end if;
  if p_on > current_date + 1 then raise exception 'Une étape ne peut pas être datée dans le futur'; end if;
  update project_steps s set title = trim(p_title), happened_on = coalesce(p_on, current_date)
  where s.id = p_id and (s.created_by = auth.uid() or exists (select 1 from projects p where p.id = s.project_id and p.owner_id = auth.uid()));
  if not found then raise exception 'Étape introuvable'; end if;
end $$;

create or replace function project_step_delete(p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from project_steps s where s.id = p_id and (s.created_by = auth.uid() or exists (select 1 from projects p where p.id = s.project_id and p.owner_id = auth.uid()));
  if not found then raise exception 'Étape introuvable'; end if;
end $$;

-- ============================================================ 5. Fichiers : équipe, plafonds, lecture par l'équipe
create or replace function storage_file_allowed(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select (storage.foldername(p_name))[1] = auth.uid()::text
      or coalesce(current_role_name()::text, '') in ('dept', 'admin')
      or exists (select 1 from files f where f.path = p_name and f.scope = 'mission' and f.ref is not null and is_mission_participant(f.ref))
      or exists (select 1 from files f join projects p on p.id = f.ref where f.path = p_name and f.scope = 'project' and (p.owner_id = auth.uid() or _project_member_ok(p.id, auth.uid())));
$$;

create or replace function register_file(p_scope text, p_ref uuid, p_path text, p_name text, p_mime text, p_size integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare fid uuid; lim integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if (storage.foldername(p_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier invalide'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'project-files' and name = p_path) then raise exception 'Fichier non déposé'; end if;
  if p_name ~* '\.(exe|bat|cmd|com|msi|scr|js|vbs|ps1|sh|jar|apk|dll)$' then raise exception 'Type de fichier refusé'; end if;
  lim := case when p_mime like 'image/%' then 5242880 else 52428800 end;
  if p_size is null or p_size < 1 or p_size > lim then raise exception 'Fichier trop lourd (5 Mo par image, 50 Mo sinon)'; end if;
  if p_scope = 'media' and coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Médiathèque réservée au département'; end if;
  if p_scope = 'project' then
    if p_ref is null or not (exists (select 1 from projects where id = p_ref and owner_id = auth.uid()) or _project_member_ok(p_ref, auth.uid())) then raise exception 'Projet introuvable'; end if;
    if (select count(*) from files where scope = 'project' and ref = p_ref) >= 50 then raise exception 'Cinquante fichiers au plus par projet'; end if;
    if coalesce((select sum(size_bytes) from files where scope = 'project' and ref = p_ref), 0) + p_size > 524288000 then raise exception 'Volume maximal du projet atteint (500 Mo)'; end if;
  end if;
  if p_scope = 'mission' and (p_ref is null or not is_mission_party(p_ref)) then raise exception 'Dossier introuvable'; end if;
  insert into files (owner_id, scope, ref, path, name, mime, size_bytes) values (auth.uid(), p_scope, p_ref, p_path, left(p_name, 160), p_mime, p_size) returning id into fid;
  return fid;
end $$;
revoke all on function register_file(text, uuid, text, text, text, integer) from public, anon;
grant execute on function register_file(text, uuid, text, text, text, integer) to authenticated;

create or replace function project_files_list(p_project uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from projects where id = p_project and (owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin'))) and not _project_member_ok(p_project, auth.uid()) then raise exception 'Projet introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'mime', f.mime, 'size_bytes', f.size_bytes, 'path', f.path, 'created_at', f.created_at,
                                                         'author', display_name(f.owner_id), 'mine', f.owner_id = auth.uid()) order by f.created_at desc)
                   from files f where f.scope = 'project' and f.ref = p_project), '[]'::jsonb);
end $$;

-- Retire l'enregistrement d'un fichier : son auteur, ou le porteur du projet.
create or replace function project_file_remove(p_file uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v files%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from files f where f.id = p_file and f.scope = 'project' and (f.owner_id = auth.uid() or exists (select 1 from projects p where p.id = f.ref and p.owner_id = auth.uid())) returning * into v;
  if v.id is null then raise exception 'Fichier introuvable'; end if;
  return v.path;
end $$;

-- ============================================================ 6. Soutien reçu : le porteur est prévenu (une fois par soutien)
create or replace function project_upvote_toggle(p_project uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from projects where id = p_project and status = 'approved' and visibility = 'public';
  if not found then raise exception 'Projet introuvable'; end if;
  if p.owner_id = auth.uid() then raise exception 'Vous ne pouvez pas soutenir votre propre projet'; end if;
  delete from project_upvotes where project_id = p_project and user_id = auth.uid();
  if found then return false; end if;
  insert into project_upvotes (project_id, user_id) values (p_project, auth.uid());
  if not exists (select 1 from notifications where user_id = p.owner_id and kind = 'project' and title = 'Nouveau soutien' and data->>'project_id' = p.id::text and data->>'voter' = auth.uid()::text) then
    perform notify_user(p.owner_id, 'project', 'Nouveau soutien', 'Un étudiant soutient « ' || left(p.title, 80) || ' ».', jsonb_build_object('project_id', p.id, 'voter', auth.uid()));
  end if;
  return true;
end $$;
revoke all on function project_upvote_toggle(uuid) from public, anon;
grant execute on function project_upvote_toggle(uuid) to authenticated;
-- Note : l'ancienne expression \S{3,300} dépassait la limite de répétition des expressions régulières PostgreSQL (255) et faisait échouer tout enregistrement de lien non vide (écran 278).
