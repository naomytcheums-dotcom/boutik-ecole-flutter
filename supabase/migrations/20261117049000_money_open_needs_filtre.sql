-- Lot MONEY : S4-117 (suite). open_needs() (20261117045100, lot devis-missions) listait aussi les briefs « mission sur mesure » adressés au département (kind = 'mission') :
-- ils ne sont plus montrés qu'à leur auteur (exclu ici par client_id <> auth.uid()) et au département / à l'administration. Corps identique pour le reste.
-- À appliquer APRÈS 20261117045100. Retour arrière : recréer open_needs() depuis 20261117045100.
create or replace function open_needs() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux talents'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'kind', m.kind, 'description', m.description,
        'budget_min', m.budget_min, 'budget_max', m.budget_max, 'deadline', m.deadline, 'created_at', m.created_at,
        'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id and p.status in ('submitted', 'accepted')),
        'my_status', (select p.status from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid())) order by m.created_at desc)
    from (select * from missions where status = 'published' and client_id <> auth.uid()
            and (kind is distinct from 'mission' or coalesce(current_role_name()::text, '') in ('dept', 'admin')) order by created_at desc limit 100) m
  ), '[]'::jsonb);
end $$;
revoke all on function open_needs() from public, anon;
grant execute on function open_needs() to authenticated;
