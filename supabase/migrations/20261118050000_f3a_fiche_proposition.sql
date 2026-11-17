-- Écran 189 (Propositions reçues) : fiche complète d'UNE proposition reçue (auteur, message, budget du besoin) pour la décider en connaissance
-- de cause. company_proposals() (liste) ne renvoie ni l'identifiant de l'auteur ni son message ; cette fonction les donne, uniquement
-- au client du besoin. Nom de l'auteur abrégé (display_name), jamais de coordonnées.
-- Lecture seule ; la décision reste decide_proposal (accepter / refuser).
-- Retour arrière : drop function company_proposal_detail(uuid);

create or replace function company_proposal_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p mission_proposals%rowtype; m missions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from mission_proposals where id = p_id;
  if not found then raise exception 'Proposition introuvable'; end if;
  select * into m from missions where id = p.mission_id;
  if not found or m.client_id is distinct from auth.uid() then raise exception 'Proposition introuvable'; end if;
  return jsonb_build_object(
    'id', p.id, 'mission_id', m.id, 'mission', m.title, 'mission_status', m.status, 'budget_min', m.budget_min, 'budget_max', m.budget_max,
    'deadline', m.deadline, 'author_id', p.author_id, 'author', display_name(p.author_id), 'message', coalesce(p.message, ''),
    'amount', p.amount, 'delay_days', p.delay_days, 'status', p.status, 'created_at', p.created_at, 'decided_at', p.decided_at);
end $$;

revoke all on function company_proposal_detail(uuid) from public, anon;
grant execute on function company_proposal_detail(uuid) to authenticated;
