-- Lot MONEY (6/6) : S4-117 — visibilité de la table missions.
-- Avant : tout compte connecté lisait TOUS les besoins publiés (titre, description, budget, échéance, client_id), y compris les briefs « mission sur mesure » adressés au département.
-- Après : la table missions n'est lisible que par son client, les participants (prestataire retenu) et le département / l'administration (is_mission_participant).
-- Les besoins à pourvoir passent par open_needs_list() : aucun identifiant du client, aucun brief adressé au département (kind = 'mission') pour les autres comptes ; le nom d'affichage
-- du demandeur reste celui de l'appel (open_calls, écran des appels à entreprises) ; open_calls (4 paramètres, 20261114001900) reçoit le même filtre.
-- Retour arrière : drop function open_needs_list(text, integer) ; recréer open_calls (20261114001900) ;
--   drop policy "missions : propriétaire et participants" on missions ; create policy "missions : visibilité restreinte" on missions for select
--   using (client_id = auth.uid() or (status = 'published' and auth.uid() is not null) or is_mission_participant(id));

drop policy if exists "missions : visibilité restreinte" on missions;
drop policy if exists "missions : propriétaire et participants" on missions;
create policy "missions : propriétaire et participants" on missions for select
  using (client_id = auth.uid() or is_mission_participant(id));

create or replace function open_needs_list(p_q text default null, p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_q text := nullif(trim(coalesce(p_q, '')), ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'number', m.number, 'title', m.title, 'description', m.description, 'budget_min', m.budget_min, 'budget_max', m.budget_max,
      'deadline', m.deadline, 'created_at', m.created_at,
      'company', coalesce(nullif(trim(c.name), ''), 'Entreprise'),
      'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id),
      'own', m.client_id = uid,
      'proposed', exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = uid and p.status = 'submitted')
    ) order by m.created_at desc)
    from missions m left join profiles c on c.id = m.client_id
    where m.status = 'published' and m.title is not null
      and (m.kind is distinct from 'mission' or m.client_id = uid or v_staff)
      and (v_q is null or m.title ilike '%' || v_q || '%' or coalesce(m.description, '') ilike '%' || v_q || '%')
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ), '[]'::jsonb);
end $$;

-- Écran des appels à entreprises : même fonction (dernière définition : 20261114001900, quatre paramètres) avec le même filtre sur les briefs adressés au département.
create or replace function open_calls(p_q text default null, p_limit integer default 30, p_sort text default 'recent', p_department text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_q text := nullif(trim(coalesce(p_q, '')), ''); v_dept text := nullif(trim(coalesce(p_department, '')), ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');
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
        and (m.kind is distinct from 'mission' or m.client_id = uid or v_staff)
        and (v_q is null or m.title ilike '%' || v_q || '%' or coalesce(m.description, '') ilike '%' || v_q || '%')
        and (v_dept is null or m.title ilike '%' || v_dept || '%' or coalesce(m.description, '') ilike '%' || v_dept || '%')
      limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function open_needs_list(text, integer), open_calls(text, integer, text, text) from public, anon;
grant execute on function open_needs_list(text, integer), open_calls(text, integer, text, text) to authenticated;
