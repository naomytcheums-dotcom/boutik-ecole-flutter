-- Lot S5 — « Coup de pouce startup » : vrai suivi d'accompagnement minimal des projets de l'étudiant (écran 204).
-- Un porteur demande un accompagnement (mentor, financement, matériel, compétences) pour l'un de SES projets ; le département du projet (ou l'administration) le prend en charge,
-- répond et clôt ; le porteur suit l'état et la réponse. Aucune promesse de financement : la réponse est rédigée par le département.
-- Corrige S5-44. NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (etu_s5.mjs).
-- Retour arrière : drop function if exists support_request_create(uuid, text, text), my_support_requests(), support_requests_to_handle(), support_request_handle(uuid, text, text);
--   drop table if exists project_support_requests;

create table if not exists project_support_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('mentor', 'funding', 'equipment', 'skills')),
  message text not null check (char_length(btrim(message)) between 10 and 1000),
  status text not null default 'open' check (status in ('open', 'in_progress', 'done', 'declined')),
  response text check (response is null or char_length(response) <= 1000),
  handled_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists project_support_requests_user on project_support_requests (user_id, created_at desc);
create index if not exists project_support_requests_open on project_support_requests (status, created_at) where status in ('open', 'in_progress');
alter table project_support_requests enable row level security;
revoke all on project_support_requests from anon, authenticated;

create or replace function support_request_create(p_project uuid, p_kind text, p_message text) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_kind is null or p_kind not in ('mentor', 'funding', 'equipment', 'skills') then raise exception 'Type d''accompagnement inconnu'; end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 10 and 1000 then raise exception 'Expliquez votre besoin en 10 à 1000 caractères'; end if;
  select * into p from projects where id = p_project and owner_id = auth.uid();
  if not found then raise exception 'Projet introuvable'; end if;
  if exists (select 1 from project_support_requests where project_id = p_project and kind = p_kind and status in ('open', 'in_progress')) then raise exception 'Une demande de ce type est déjà en cours pour ce projet'; end if;
  if (select count(*) from project_support_requests where user_id = auth.uid() and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq demandes par jour au plus'; end if;
  insert into project_support_requests (project_id, user_id, kind, message) values (p_project, auth.uid(), p_kind, btrim(p_message)) returning id into v_id;
  insert into notifications (user_id, kind, title, body, data)
    select r, 'project', 'Demande d''accompagnement', left(p.title || ' · ' || case p_kind when 'mentor' then 'mentor' when 'funding' then 'financement' when 'equipment' then 'matériel' else 'compétences' end, 200),
           jsonb_build_object('project_id', p.id, 'support_request', v_id)
    from _project_reviewers(p.department) r where r <> auth.uid();
  return v_id;
end $$;
revoke all on function support_request_create(uuid, text, text) from public, anon;
grant execute on function support_request_create(uuid, text, text) to authenticated;

create or replace function my_support_requests() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'project_id', s.project_id, 'project', p.title, 'kind', s.kind, 'message', s.message, 'status', s.status, 'response', s.response,
                                                       'created_at', s.created_at, 'updated_at', s.updated_at) order by s.created_at desc)
                   from (select * from project_support_requests where user_id = auth.uid() order by created_at desc limit 50) s join projects p on p.id = s.project_id), '[]'::jsonb);
end $$;
revoke all on function my_support_requests() from public, anon;
grant execute on function my_support_requests() to authenticated;

create or replace function support_requests_to_handle() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'project_id', s.project_id, 'project', p.title, 'kind', s.kind, 'message', s.message, 'status', s.status, 'owner', display_name(s.user_id),
                                                       'created_at', s.created_at) order by s.created_at)
                   from project_support_requests s join projects p on p.id = s.project_id
                   where s.status in ('open', 'in_progress') and _can_review_dept(p.department)), '[]'::jsonb);
end $$;
revoke all on function support_requests_to_handle() from public, anon;
grant execute on function support_requests_to_handle() to authenticated;

create or replace function support_request_handle(p_id uuid, p_status text, p_response text default '') returns void
language plpgsql security definer set search_path = public as $$
declare s project_support_requests%rowtype; p projects%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_status not in ('in_progress', 'done', 'declined') then raise exception 'Statut inconnu'; end if;
  select * into s from project_support_requests where id = p_id and status in ('open', 'in_progress') for update;
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  select * into p from projects where id = s.project_id;
  if not _can_review_dept(p.department) then raise exception 'Cette demande relève d''un autre département'; end if;
  if p_status in ('done', 'declined') and char_length(btrim(coalesce(p_response, ''))) < 5 then raise exception 'Rédigez une réponse (5 caractères au moins)'; end if;
  update project_support_requests set status = p_status, response = nullif(left(btrim(coalesce(p_response, '')), 1000), ''), handled_by = auth.uid(), updated_at = now() where id = p_id;
  perform notify_user(s.user_id, 'project', case p_status when 'in_progress' then 'Accompagnement pris en charge' when 'done' then 'Accompagnement : réponse' else 'Accompagnement : demande non retenue' end,
    left(p.title || coalesce(' · ' || nullif(btrim(coalesce(p_response, '')), ''), ''), 300), jsonb_build_object('project_id', p.id, 'support_request', p_id));
end $$;
revoke all on function support_request_handle(uuid, text, text) from public, anon;
grant execute on function support_request_handle(uuid, text, text) to authenticated;
