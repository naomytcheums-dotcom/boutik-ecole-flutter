-- Appel à entreprises et projets de l'IUT dans la marketplace.
-- Un appel est un besoin publié (table missions, statut « published ») : l'entreprise écrit « Je cherche une solution pour X », les étudiants répondent
-- avec un montant, un délai et un message (propose_on_mission existe déjà). Cette migration ne fait que présenter ces besoins et les projets validés.
-- Retour arrière : drop function open_calls(text, integer); drop function iut_projects(text, integer);

-- Besoins publiés à pourvoir, avec le nom du demandeur, le nombre de propositions reçues et la proposition éventuelle de la personne connectée.
create or replace function open_calls(p_q text default null, p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_q text := nullif(trim(coalesce(p_q, '')), '');
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
      and (v_q is null or m.title ilike '%' || v_q || '%' or coalesce(m.description, '') ilike '%' || v_q || '%')
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ), '[]'::jsonb);
end $$;
revoke all on function open_calls(text, integer) from public, anon;
grant execute on function open_calls(text, integer) to authenticated;

-- Projets validés par l'IUT, par filière : publics (aucune donnée privée), les plus récents d'abord.
create or replace function iut_projects(p_department text default null, p_limit integer default 40) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id, 'title', p.title, 'summary', p.summary, 'department', coalesce(nullif(trim(p.department), ''), 'Autres filières'), 'created_at', p.created_at,
      'owner_id', p.owner_id, 'owner', display_name(p.owner_id), 'avatar_url', o.avatar_url) order by p.created_at desc), '[]'::jsonb)
  from (select * from projects where status = 'approved'
          and (nullif(trim(coalesce(p_department, '')), '') is null or lower(coalesce(department, '')) like '%' || lower(trim(p_department)) || '%')
        order by created_at desc limit least(greatest(coalesce(p_limit, 40), 1), 100)) p
  left join profiles o on o.id = p.owner_id
$$;
revoke all on function iut_projects(text, integer) from public;
grant execute on function iut_projects(text, integer) to anon, authenticated;
