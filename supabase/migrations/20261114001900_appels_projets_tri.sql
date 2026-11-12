-- Appels aux entreprises : tri (récents, budget, moins de propositions) et filière mentionnée.
-- Projets de l'IUT : « Soutenir » un projet (un soutien par personne) et classement des meilleurs (soutiens, puis plus récents).
-- Retour arrière : recréer open_calls(text, integer) et iut_projects(text, integer) depuis 20261114000600 ;
--   drop function open_calls(text, integer, text, text), iut_projects(text, integer, text), project_upvote_toggle(uuid); drop table project_upvotes.

create table if not exists project_upvotes (
  project_id uuid not null references projects(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);
alter table project_upvotes enable row level security;
revoke all on project_upvotes from anon, authenticated;

drop function if exists open_calls(text, integer);
create or replace function open_calls(p_q text default null, p_limit integer default 30, p_sort text default 'recent', p_department text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_q text := nullif(trim(coalesce(p_q, '')), ''); v_dept text := nullif(trim(coalesce(p_department, '')), '');
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_sort, 'recent') not in ('recent', 'budget', 'fewest') then raise exception 'Tri inconnu'; end if;
  return coalesce((
    select jsonb_agg(x.j order by
        case when coalesce(p_sort, 'recent') = 'budget' then x.budget end desc nulls last,
        case when p_sort = 'fewest' then x.props end asc,
        x.created_at desc)
    from (
      select jsonb_build_object(
        'id', m.id, 'number', m.number, 'title', m.title, 'description', m.description, 'budget_min', m.budget_min, 'budget_max', m.budget_max,
        'deadline', m.deadline, 'created_at', m.created_at,
        'company', coalesce(nullif(trim(c.name), ''), 'Entreprise'),
        'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id),
        'own', m.client_id = uid,
        'proposed', exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = uid and p.status = 'submitted')) j,
        coalesce(m.budget_max, m.budget_min) budget,
        (select count(*)::int from mission_proposals p where p.mission_id = m.id) props,
        m.created_at
      from missions m left join profiles c on c.id = m.client_id
      where m.status = 'published' and m.title is not null
        and (v_q is null or m.title ilike '%' || v_q || '%' or coalesce(m.description, '') ilike '%' || v_q || '%')
        and (v_dept is null or m.title ilike '%' || v_dept || '%' or coalesce(m.description, '') ilike '%' || v_dept || '%')
      limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) x
  ), '[]'::jsonb);
end $$;
revoke all on function open_calls(text, integer, text, text) from public, anon;
grant execute on function open_calls(text, integer, text, text) to authenticated;

drop function if exists iut_projects(text, integer);
create or replace function iut_projects(p_department text default null, p_limit integer default 40, p_sort text default 'best') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'title', p.title, 'summary', p.summary, 'department', coalesce(nullif(trim(p.department), ''), 'Autres filières'), 'created_at', p.created_at,
      'owner_id', p.owner_id, 'owner', display_name(p.owner_id), 'avatar_url', o.avatar_url,
      'votes', p.votes, 'voted', exists (select 1 from project_upvotes u where u.project_id = p.id and u.user_id = auth.uid()))
    order by case when coalesce(p_sort, 'best') = 'best' then p.votes end desc nulls last, p.created_at desc), '[]'::jsonb)
  from (select pr.*, (select count(*)::int from project_upvotes u where u.project_id = pr.id) votes
        from projects pr
        where pr.status = 'approved'
          and (nullif(trim(coalesce(p_department, '')), '') is null or lower(coalesce(pr.department, '')) like '%' || lower(trim(p_department)) || '%')
        order by pr.created_at desc limit least(greatest(coalesce(p_limit, 40), 1), 100)) p
  left join profiles o on o.id = p.owner_id
$$;
revoke all on function iut_projects(text, integer, text) from public;
grant execute on function iut_projects(text, integer, text) to anon, authenticated;

-- Soutenir un projet validé (ou retirer son soutien) ; renvoie vrai quand le soutien est posé. On ne soutient pas son propre projet.
create or replace function project_upvote_toggle(p_project uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from projects where id = p_project and status = 'approved') then raise exception 'Projet introuvable'; end if;
  if exists (select 1 from projects where id = p_project and owner_id = auth.uid()) then raise exception 'Vous ne pouvez pas soutenir votre propre projet'; end if;
  delete from project_upvotes where project_id = p_project and user_id = auth.uid();
  if found then return false; end if;
  insert into project_upvotes (project_id, user_id) values (p_project, auth.uid());
  return true;
end $$;
revoke all on function project_upvote_toggle(uuid) from public, anon;
grant execute on function project_upvote_toggle(uuid) to authenticated;
