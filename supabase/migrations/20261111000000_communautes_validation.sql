-- Communautés façon « groupes » : création soumise à validation par l'administrateur, description limitée à 500 MOTS (et non 500 caractères),
-- département rattaché (référentiel `departments`), mentors, liste des membres. NON DESTRUCTIVE : aucune table ni ligne supprimée ;
-- les communautés existantes restent « active ». Retour arrière manuel en fin de fichier.

-- ---------------------------------------------------------------- colonnes et contraintes
alter table communities add column if not exists department_id uuid references departments(id) on delete set null;
alter table communities add column if not exists decided_by uuid references profiles(id) on delete set null;
alter table communities add column if not exists decided_at timestamptz;
alter table communities add column if not exists decision_note text check (decision_note is null or char_length(decision_note) <= 500);

alter table communities drop constraint if exists communities_status_check;
alter table communities add constraint communities_status_check check (status in ('pending', 'active', 'rejected', 'suspended'));

-- la limite devient 500 mots (garde-fou de taille : 6000 caractères)
alter table communities drop constraint if exists communities_description_check;
alter table communities drop constraint if exists communities_description_mots;
alter table communities add constraint communities_description_mots check (
  char_length(description) <= 6000
  and (btrim(description) = '' or cardinality(regexp_split_to_array(btrim(description), '\s+')) <= 500));

alter table community_members drop constraint if exists community_members_role_check;
alter table community_members add constraint community_members_role_check check (role in ('owner', 'admin', 'moderator', 'mentor', 'member'));

create index if not exists communities_department on communities (department_id);
create index if not exists communities_status on communities (status, created_at desc);

-- ---------------------------------------------------------------- visibilité : le créateur voit sa demande, l'équipe voit tout
drop policy if exists "communautés visibles" on communities;
create policy "communautés visibles" on communities for select
  using ((status = 'active' and (privacy in ('public', 'approval') or is_community_member(id))) or owner_id = auth.uid() or is_platform_staff());

-- ---------------------------------------------------------------- création : toujours « en attente » de validation
drop function if exists create_community(text, text, text, text, text);
create or replace function create_community(p_name text, p_description text default '', p_category text default '', p_privacy text default 'public', p_rules text default '', p_department uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_words integer; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Complétez votre profil avant cette action'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  v_words := case when btrim(coalesce(p_description, '')) = '' then 0 else cardinality(regexp_split_to_array(btrim(p_description), '\s+')) end;
  if v_words > 500 then raise exception 'La description ne doit pas dépasser 500 mots (% mots saisis)', v_words; end if;
  if char_length(coalesce(p_description, '')) > 6000 then raise exception 'La description est trop longue'; end if;
  if p_department is not null and not exists (select 1 from departments where id = p_department and status = 'verified') then raise exception 'Département inconnu'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and status in ('pending', 'active')) >= 5 then raise exception 'Vous ne pouvez pas avoir plus de 5 communautés'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, category, rules, privacy, owner_id, department_id, status)
    values (btrim(p_name), btrim(coalesce(p_description, '')), coalesce(p_category, ''), coalesce(p_rules, ''), p_privacy, auth.uid(), p_department, 'pending') returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  for r in select id from profiles where role = 'admin' loop
    perform notify_user(r.id, 'community_validation', 'Communauté à valider', display_name(auth.uid()) || ' propose la communauté « ' || btrim(p_name) || ' ».', jsonb_build_object('community', v_id));
  end loop;
  return v_id;
end $$;
revoke all on function create_community(text, text, text, text, text, uuid) from public, anon;
grant execute on function create_community(text, text, text, text, text, uuid) to authenticated;

-- ---------------------------------------------------------------- décision de l'équipe (administrateur, support)
create or replace function community_decide(p_community uuid, p_approve boolean, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c communities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_platform_staff() then raise exception 'Réservé à l''équipe de la plateforme'; end if;
  select * into c from communities where id = p_community for update;
  if not found then raise exception 'Communauté introuvable'; end if;
  if c.status not in ('pending', 'rejected') and p_approve then raise exception 'Cette communauté est déjà publiée'; end if;
  if not p_approve and char_length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'Indiquez le motif du refus'; end if;
  update communities set status = case when p_approve then 'active' else 'rejected' end, decided_by = auth.uid(), decided_at = now(),
    decision_note = nullif(left(btrim(coalesce(p_note, '')), 500), '') where id = p_community;
  perform notify_user(c.owner_id, case when p_approve then 'community_approved' else 'community_rejected' end,
    case when p_approve then 'Communauté validée' else 'Communauté refusée' end,
    case when p_approve then 'Votre communauté « ' || c.name || ' » est publiée.' else 'Votre communauté « ' || c.name || ' » n’a pas été validée : ' || left(btrim(p_note), 300) end,
    jsonb_build_object('community', p_community));
  return case when p_approve then 'active' else 'rejected' end;
end $$;
revoke all on function community_decide(uuid, boolean, text) from public, anon;
grant execute on function community_decide(uuid, boolean, text) to authenticated;

create or replace function communities_pending() returns table (id uuid, name text, description text, privacy text, department text, owner text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.privacy, d.name, display_name(c.owner_id), c.created_at
  from communities c left join departments d on d.id = c.department_id
  where c.status = 'pending' and is_platform_staff()
  order by c.created_at
$$;
revoke all on function communities_pending() from public, anon;
grant execute on function communities_pending() to authenticated;

-- ---------------------------------------------------------------- mentors
create or replace function set_member_role(p_community uuid, p_user uuid, p_role text) returns text
language plpgsql security definer set search_path = public as $$
declare mine integer; theirs integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_role not in ('admin', 'moderator', 'mentor', 'member') then raise exception 'Rôle inconnu'; end if;
  mine := community_rank(p_community, auth.uid()); theirs := community_rank(p_community, p_user);
  if mine < 3 then raise exception 'Action non autorisée'; end if;
  if theirs = 0 then raise exception 'Cette personne n''est pas membre'; end if;
  if theirs >= mine then raise exception 'Vous ne pouvez pas modifier le rôle d''un rang égal ou supérieur'; end if;
  if p_role = 'admin' and mine < 4 then raise exception 'Seul le propriétaire nomme un administrateur'; end if;
  update community_members set role = p_role where community_id = p_community and user_id = p_user;
  return p_role;
end $$;

-- ---------------------------------------------------------------- annuaire (mes demandes en attente incluses) et membres
drop function if exists communities_list(text, integer);
create or replace function communities_list(p_query text default '', p_limit integer default 30)
returns table (id uuid, name text, description text, category text, privacy text, members integer, my_status text, my_role text, status text, department text, decision_note text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.category, c.privacy,
         (select count(*)::int from community_members m where m.community_id = c.id and m.status = 'active'),
         (select m.status from community_members m where m.community_id = c.id and m.user_id = auth.uid()),
         (select m.role from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status = 'active'),
         c.status, d.name, c.decision_note
  from communities c left join departments d on d.id = c.department_id
  where (
      (c.status = 'active' and (c.privacy in ('public', 'approval') or exists (select 1 from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status in ('active', 'invited'))))
      or (c.owner_id = auth.uid() and c.status in ('pending', 'rejected'))
    )
    and (coalesce(btrim(p_query), '') = '' or c.name ilike '%' || btrim(p_query) || '%' or c.category ilike '%' || btrim(p_query) || '%' or d.name ilike '%' || btrim(p_query) || '%')
  order by (c.status <> 'active') desc, 6 desc, c.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
$$;
revoke all on function communities_list(text, integer) from public, anon;
grant execute on function communities_list(text, integer) to authenticated, anon;

create or replace function community_members_list(p_community uuid, p_limit integer default 100)
returns table (user_id uuid, name text, role text, joined_at timestamptz, mine boolean)
language sql stable security definer set search_path = public as $$
  select m.user_id, display_name(m.user_id), m.role, m.created_at, m.user_id = auth.uid()
  from community_members m join communities c on c.id = m.community_id
  where m.community_id = p_community and m.status = 'active' and c.status = 'active'
    and (c.privacy <> 'invite' or is_community_member(c.id) or is_platform_staff())
  order by case m.role when 'owner' then 0 when 'admin' then 1 when 'moderator' then 2 when 'mentor' then 3 else 4 end, m.created_at
  limit least(greatest(coalesce(p_limit, 100), 1), 300)
$$;
revoke all on function community_members_list(uuid, integer) from public, anon;
grant execute on function community_members_list(uuid, integer) to authenticated;

-- publier : seulement dans une communauté validée
create or replace function create_community_post(p_community uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from communities where id = p_community and status = 'active') then raise exception 'Cette communauté n''est pas encore validée'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 2000 then raise exception 'La publication doit contenir entre 1 et 2000 caractères'; end if;
  if (select count(*) from posts where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de publications en peu de temps. Réessayez dans une minute.'; end if;
  insert into posts (author_id, kind, body, community_id, status, published_at) values (auth.uid(), 'text', btrim(p_body), p_community, 'published', now()) returning id into v_id;
  return v_id;
end $$;

-- Retour arrière manuel : drop function community_decide, communities_pending, community_members_list ; recréer create_community / communities_list / set_member_role
-- de 20261103000100 ; alter table communities drop column department_id, decided_by, decided_at, decision_note ; rétablir les contraintes d'origine.
