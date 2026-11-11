-- Devis sur toute offre qui n'est pas un produit physique (solution technique ou numérique, service, projet à vendre ou licence).
-- Réutilise la table et les réponses existantes (quote_requests, answer_quote, decide_quote, cancel_quote, « Mes devis ») : seule la demande change,
-- puisqu'elle désigne l'offre par son identifiant au lieu de son titre.
-- Retour arrière : drop function request_quote_offer(uuid, text, integer, text);

create or replace function request_quote_offer(p_listing uuid, p_brief text, p_budget integer default null, p_deadline text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; qid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found or exists (select 1 from shops s where s.id = l.shop_id and s.status <> 'active') then raise exception 'Cette offre n''est plus disponible'; end if;
  if offer_type_of(l.category) = 'product' then raise exception 'Ce produit s''achète directement : le devis concerne les services, solutions et projets'; end if;
  if l.seller_id is null then raise exception 'Cette offre ne reçoit pas de demande de devis'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas demander un devis pour votre propre offre'; end if;
  if p_brief is null or char_length(trim(p_brief)) < 10 then raise exception 'Décrivez votre besoin en 10 caractères minimum'; end if;
  if p_budget is not null and p_budget < 0 then raise exception 'Budget invalide'; end if;
  if exists (select 1 from quote_requests where listing_id = l.id and requester_id = auth.uid() and status in ('requested', 'quoted')) then
    raise exception 'Une demande est déjà en cours pour cette offre';
  end if;
  insert into quote_requests (listing_id, requester_id, provider_id, brief, budget, deadline)
  values (l.id, auth.uid(), l.seller_id, left(trim(p_brief), 2000), p_budget, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
  returning id into qid;
  insert into notifications (user_id, kind, title, body, data)
  values (l.seller_id, 'quote', 'Nouvelle demande de devis', 'Offre « ' || l.title || ' »', jsonb_build_object('quote_id', qid));
  return qid;
end $$;

revoke all on function request_quote_offer(uuid, text, integer, text) from public, anon;
grant execute on function request_quote_offer(uuid, text, integer, text) to authenticated;
