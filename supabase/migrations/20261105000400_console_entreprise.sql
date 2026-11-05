-- Espace entreprise (écrans 93 Propositions reçues, 98 Collaborations, 99 Historique des besoins) : lecture des besoins publiés par la
-- personne connectée et des propositions reçues, avec le nom public des auteurs (la politique de lecture des profils ne le permet pas
-- directement). Lecture seule, limitée aux besoins dont la personne est le client.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale (supabase/tests/console_entreprise_local.sql).
-- Retour arrière : drop function company_proposals(), company_missions();

create or replace function company_proposals() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'mission', m.title, 'author', coalesce(a.name, 'Candidat'), 'amount', p.amount, 'delay_days', p.delay_days,
      'status', p.status, 'created_at', p.created_at
    ) order by p.created_at desc)
    from mission_proposals p join missions m on m.id = p.mission_id left join profiles a on a.id = p.author_id
    where m.client_id = auth.uid()
  ), '[]'::jsonb);
end $$;

create or replace function company_missions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'number', m.number, 'title', m.title, 'status', m.status, 'created_at', m.created_at, 'deadline', m.deadline,
      'budget_min', m.budget_min, 'budget_max', m.budget_max, 'team', coalesce(m.assigned_team, ''),
      'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id)
    ) order by m.created_at desc)
    from missions m where m.client_id = auth.uid()
  ), '[]'::jsonb);
end $$;

revoke all on function company_proposals(), company_missions() from public, anon;
grant execute on function company_proposals(), company_missions() to authenticated;
