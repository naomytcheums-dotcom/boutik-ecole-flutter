-- Services et devis. Un service est une annonce validée de catégorie « Services » ; le devis est un échange entre
-- le demandeur et le prestataire (le vendeur de l'annonce). Aucune écriture directe : tout passe par des fonctions serveur.

create table if not exists quote_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  provider_id uuid not null references profiles(id) on delete cascade,
  brief text not null check (char_length(brief) between 10 and 2000),
  budget integer check (budget is null or budget >= 0),
  deadline text check (deadline is null or char_length(deadline) <= 60),
  status text not null default 'requested' check (status in ('requested', 'quoted', 'accepted', 'declined', 'cancelled')),
  quote_amount integer check (quote_amount is null or quote_amount > 0),
  quote_delay_days integer check (quote_delay_days is null or quote_delay_days between 1 and 365),
  quote_message text check (quote_message is null or char_length(quote_message) <= 2000),
  created_at timestamptz not null default now(),
  quoted_at timestamptz,
  decided_at timestamptz
);
alter table quote_requests enable row level security;
revoke all on quote_requests from anon, authenticated;
grant select on quote_requests to authenticated;
drop policy if exists "devis : demandeur et prestataire" on quote_requests;
create policy "devis : demandeur et prestataire" on quote_requests for select
  using (requester_id = auth.uid() or provider_id = auth.uid() or current_role_name() in ('dept', 'admin', 'support'));

-- Demande de devis sur un service validé ; jamais sur son propre service ; une seule demande en cours par service et par personne.
create or replace function request_quote(p_service text, p_brief text, p_budget integer, p_deadline text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; qid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from listings where title = p_service and category = 'Services' and status = 'approved' order by (seller_id is null) limit 1;
  if not found then raise exception 'Service introuvable'; end if;
  if l.seller_id is null then raise exception 'Ce service ne reçoit pas de demande de devis'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas demander un devis pour votre propre service'; end if;
  if p_brief is null or char_length(trim(p_brief)) < 10 then raise exception 'Décrivez votre besoin en 10 caractères minimum'; end if;
  if p_budget is not null and p_budget < 0 then raise exception 'Budget invalide'; end if;
  if exists (select 1 from quote_requests where listing_id = l.id and requester_id = auth.uid() and status in ('requested', 'quoted')) then
    raise exception 'Une demande est déjà en cours pour ce service';
  end if;
  insert into quote_requests (listing_id, requester_id, provider_id, brief, budget, deadline)
  values (l.id, auth.uid(), l.seller_id, left(trim(p_brief), 2000), p_budget, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
  returning id into qid;
  insert into notifications (user_id, kind, title, body, data)
  values (l.seller_id, 'quote', 'Nouvelle demande de devis', 'Service « ' || l.title || ' »', jsonb_build_object('quote_id', qid));
  return qid;
end $$;

-- Le prestataire répond avec un montant, un délai et un message ; la réponse peut être corrigée tant que le demandeur n'a pas décidé.
create or replace function answer_quote(p_id uuid, p_amount integer, p_delay_days integer, p_message text) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; t text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_id and provider_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status not in ('requested', 'quoted') then raise exception 'Cette demande est déjà clôturée'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Indiquez un montant supérieur à 0'; end if;
  if p_delay_days is null or p_delay_days < 1 or p_delay_days > 365 then raise exception 'Indiquez un délai de 1 à 365 jours'; end if;
  update quote_requests set status = 'quoted', quote_amount = p_amount, quote_delay_days = p_delay_days,
    quote_message = nullif(left(trim(coalesce(p_message, '')), 2000), ''), quoted_at = now() where id = q.id;
  select title into t from listings where id = q.listing_id;
  insert into notifications (user_id, kind, title, body, data)
  values (q.requester_id, 'quote', 'Devis reçu', 'Service « ' || t || ' » : ' || p_amount || ' FCFA en ' || p_delay_days || ' jour(s).', jsonb_build_object('quote_id', q.id));
  return 'quoted';
end $$;

-- Le demandeur accepte ou refuse le devis reçu ; le prestataire est notifié.
create or replace function decide_quote(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; t text; s text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_id and requester_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'quoted' then raise exception 'Aucun devis à valider pour cette demande'; end if;
  s := case when p_accept then 'accepted' else 'declined' end;
  update quote_requests set status = s, decided_at = now() where id = q.id;
  select title into t from listings where id = q.listing_id;
  insert into notifications (user_id, kind, title, body, data)
  values (q.provider_id, 'quote', case when p_accept then 'Devis accepté' else 'Devis refusé' end, 'Service « ' || t || ' »', jsonb_build_object('quote_id', q.id));
  return s;
end $$;

-- Le demandeur annule sa demande tant qu'elle n'est pas acceptée.
create or replace function cancel_quote(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_id and requester_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status not in ('requested', 'quoted') then raise exception 'Cette demande est déjà clôturée'; end if;
  update quote_requests set status = 'cancelled', decided_at = now() where id = q.id;
  return 'cancelled';
end $$;

revoke all on function request_quote(text, text, integer, text), answer_quote(uuid, integer, integer, text), decide_quote(uuid, boolean), cancel_quote(uuid) from public, anon;
grant execute on function request_quote(text, text, integer, text), answer_quote(uuid, integer, integer, text), decide_quote(uuid, boolean), cancel_quote(uuid) to authenticated;
