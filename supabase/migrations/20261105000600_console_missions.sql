-- Console des missions (écrans 198 Briefs reçus, 199 Attribution, 200 Missions et suivi des jalons) : liste de tous les besoins pour le personnel
-- (administrateur, direction, département, support, finance). Les montants de jalons sont ceux saisis sur les missions ; aucun séquestre réel
-- n'est géré en ligne : l'écran 200 affiche donc les montants de jalons, sans les appeler « bloqués ».
-- Retour arrière : drop function staff_missions(); drop function staff_mission_proposals(uuid);

create or replace function staff_missions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'dept', 'support', 'finance') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'number', m.number, 'title', m.title, 'status', m.status, 'created_at', m.created_at, 'deadline', m.deadline,
      'budget_min', m.budget_min, 'budget_max', m.budget_max, 'team', coalesce(m.assigned_team, ''), 'client', coalesce(c.name, 'Client'),
      'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id),
      'milestones_total', (select coalesce(sum(amount), 0)::bigint from mission_milestones x where x.mission_id = m.id),
      'milestones_validated', (select coalesce(sum(amount), 0)::bigint from mission_milestones x where x.mission_id = m.id and x.status = 'validated'),
      'milestones_count', (select count(*)::int from mission_milestones x where x.mission_id = m.id)
    ) order by m.created_at desc)
    from missions m left join profiles c on c.id = m.client_id where m.status <> 'draft'
  ), '[]'::jsonb);
end $$;

create or replace function staff_mission_proposals(p_mission uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'dept', 'support', 'finance') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'author', coalesce(a.name, 'Candidat'), 'amount', p.amount, 'delay_days', p.delay_days, 'status', p.status, 'department', coalesce(a.department, '')) order by p.created_at)
    from mission_proposals p left join profiles a on a.id = p.author_id where p.mission_id = p_mission
  ), '[]'::jsonb);
end $$;

revoke all on function staff_missions(), staff_mission_proposals(uuid) from public, anon;
grant execute on function staff_missions(), staff_mission_proposals(uuid) to authenticated;
