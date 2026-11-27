-- H13 · Action Unique « Postuler » sur une mission : fiche ouvrable par identifiant et refus honnêtes. Strictement additif (nouvelle fonction + create or replace de _live_action_check).
--  * mission_public_card(mission) : fiche d'un besoin publié, MÊME visibilité que open_calls (besoin publié, annonceur reconnu, besoins de type « mission » réservés à leur auteur et au personnel) ;
--    renvoie aussi l'état du demandeur (sa proposition, ses tentatives) et, pour un étudiant, la raison de refus de capacité vendeur (_seller_block_reason) pour l'afficher AVANT le formulaire.
--    La décision reste serveur : propose_on_mission et le déclencheur l4_proposal_guard refusent toujours un compte non éligible.
--  * _live_action_check : pour « postuler » sur une mission, la mission doit être publiée et ouverte aux propositions (sinon le bouton est absent / le réglage refusé) ; reste identique pour les autres cas.
-- Retour arrière : recréer _live_action_check depuis 20261127500000 ; drop function mission_public_card(uuid).

create or replace function mission_public_card(p_mission uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); m missions%rowtype; pj jsonb; staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin'); prop mission_proposals%rowtype; blocked text;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or m.title is null then raise exception 'Besoin introuvable'; end if;
  if m.client_id <> uid and not staff and (m.status <> 'published' or m.kind is not distinct from 'mission') then raise exception 'Besoin introuvable'; end if;
  pj := _need_poster(m.client_id);
  if pj is null and m.client_id <> uid and not staff then raise exception 'Besoin introuvable'; end if;
  select * into prop from mission_proposals where mission_id = m.id and author_id = uid;
  if coalesce(current_role_name()::text, '') = 'student' then blocked := _seller_block_reason(uid, true); end if;
  return jsonb_build_object(
    'id', m.id, 'number', m.number, 'title', m.title, 'description', m.description, 'budget_min', m.budget_min, 'budget_max', m.budget_max, 'deadline', m.deadline,
    'company', pj ->> 'label', 'verified', coalesce((pj ->> 'verified')::boolean, false),
    'status', m.status, 'open', m.status = 'published' and pj is not null,
    'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id),
    'own', m.client_id = uid,
    'role', current_role_name()::text,
    'my_status', prop.status, 'my_attempts', coalesce(prop.attempts, 0),
    'block_reason', blocked);
end $$;
revoke all on function mission_public_card(uuid) from public, anon;
grant execute on function mission_public_card(uuid) to authenticated;

create or replace function _live_action_check(p_host uuid, p_action text, p_kind text, p_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare ok boolean := false; t text;
begin
  if p_action is null then return case when p_kind is null and p_id is null then null else 'Une cible exige une action' end; end if;
  if p_action not in ('acheter', 'soutenir', 'parrainer', 'postuler', 's_inscrire', 'voter', 'telecharger', 'noter', 'demander_devis', 'encourager', 'offrir', 'reserver') then
    return 'Action inconnue';
  end if;
  if p_action in ('parrainer', 'offrir') then
    return case when p_kind is null and p_id is null then null else 'Cette action ne prend pas de cible' end;
  end if;
  if p_kind is null or p_id is null then return 'Cette action exige une cible : choisissez l''élément concerné'; end if;
  if p_action in ('acheter', 'reserver', 'demander_devis', 'telecharger', 'noter') and p_kind <> 'listing' then return 'Cette action concerne une annonce du vendeur'; end if;
  if p_action = 'postuler' and p_kind not in ('opportunity', 'mission') then return 'Postuler concerne une opportunité ou une mission'; end if;
  if p_action = 's_inscrire' and p_kind <> 'event' then return 'S''inscrire concerne un événement'; end if;
  if p_action in ('voter', 'soutenir', 'encourager') and p_kind <> 'project' then return 'Cette action concerne un projet'; end if;

  if p_kind = 'listing' then
    select offer_type_of(l.category) into t from listings l
      where l.id = p_id and l.status = 'approved'
        and (l.seller_id = p_host or exists (select 1 from shops s where s.id = l.shop_id and s.owner_id = p_host and s.status = 'active'))
        and not exists (select 1 from shops s where s.id = l.shop_id and s.status <> 'active');
    if t is null then return 'Annonce introuvable ou qui n''appartient pas à l''hôte'; end if;
    ok := case p_action
      when 'acheter' then t in ('product', 'tech', 'project')
      when 'reserver' then t = 'service'
      when 'demander_devis' then t in ('service', 'tech', 'project')
      when 'telecharger' then t = 'tech'
      else true end;
    if not ok then return 'Cette action ne correspond pas au type de l''annonce'; end if;
  elsif p_kind = 'event' then
    if not exists (select 1 from events e where e.id = p_id and e.created_by = p_host and e.status = 'published') then return 'Événement introuvable ou qui n''appartient pas à l''hôte'; end if;
  elsif p_kind = 'opportunity' then
    if not exists (select 1 from opportunities o where o.id = p_id and o.poster_id = p_host and o.status = 'published') then return 'Opportunité introuvable ou qui n''appartient pas à l''hôte'; end if;
  elsif p_kind = 'mission' then
    if not exists (select 1 from missions m where m.id = p_id and m.client_id = p_host) then return 'Mission introuvable ou qui n''appartient pas à l''hôte'; end if;
    if p_action = 'postuler' and not exists (select 1 from missions m where m.id = p_id and m.client_id = p_host and m.status = 'published' and m.title is not null and m.kind is distinct from 'mission') then
      return 'Cette mission ne reçoit pas de propositions : publiez-la comme besoin ouvert avant de choisir « Postuler »';
    end if;
  elsif p_kind = 'project' then
    if not exists (select 1 from projects p where p.id = p_id and p.owner_id = p_host and p.status = 'approved' and p.visibility = 'public') then return 'Projet introuvable, non publié ou qui n''appartient pas à l''hôte'; end if;
  end if;
  return null;
end $$;
revoke all on function _live_action_check(uuid, text, text, uuid) from public, anon, authenticated;

-- Cibles « mission » de l'Action Unique : seulement les besoins publiés et ouverts aux propositions (mêmes conditions que _live_action_check) ; le reste est identique à 20261127500000.
create or replace function live_action_targets(p_kind text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if p_kind = 'listing' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'offer_type', offer_type_of(l.category), 'price', l.price) order by l.created_at desc)
      from (select * from listings x where x.status = 'approved'
              and (x.seller_id = uid or exists (select 1 from shops s where s.id = x.shop_id and s.owner_id = uid and s.status = 'active'))
              and not exists (select 1 from shops s where s.id = x.shop_id and s.status <> 'active') order by x.created_at desc limit 50) l), '[]'::jsonb);
  elsif p_kind = 'event' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'price', e.price, 'starts_at', e.starts_at) order by e.starts_at)
      from (select * from events x where x.created_by = uid and x.status = 'published' and x.starts_at > now() - interval '1 day' order by x.starts_at limit 50) e), '[]'::jsonb);
  elsif p_kind = 'opportunity' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'title', o.title) order by o.created_at desc)
      from (select * from opportunities x where x.poster_id = uid and x.status = 'published' order by x.created_at desc limit 50) o), '[]'::jsonb);
  elsif p_kind = 'mission' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title) order by m.created_at desc)
      from (select * from missions x where x.client_id = uid and x.status = 'published' and x.title is not null and x.kind is distinct from 'mission' order by x.created_at desc limit 50) m), '[]'::jsonb);
  elsif p_kind = 'project' then
    return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'title', p.title) order by p.created_at desc)
      from (select * from projects x where x.owner_id = uid and x.status = 'approved' and x.visibility = 'public' order by x.created_at desc limit 50) p), '[]'::jsonb);
  end if;
  raise exception 'Type de cible inconnu';
end $$;
revoke all on function live_action_targets(text) from public, anon;
grant execute on function live_action_targets(text) to authenticated;