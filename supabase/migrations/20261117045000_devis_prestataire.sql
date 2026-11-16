-- Devis côté prestataire (profil étudiant-vendeur, lot S4 « devis-missions »).
--   S4-40  decline_quote : le prestataire décline une demande de devis (motif facultatif), le demandeur est prévenu ; nouveau statut « rejected »
--   S4-41  quote_contact : message entre le prestataire et le demandeur d'un devis (conversation de l'annonce), blocages et plafond respectés (chat_guard)
--   S4-42  answer_quote : bornes (1 à 100 000 000 FCFA), suspension, annonce encore publiée, cinq révisions au plus, validité de 14 jours (valid_until) ;
--          decide_quote refuse d'accepter un devis expiré ; expire_quotes() (cron) clôture les devis expirés et les demandes sans réponse après 30 jours
--   S4-44/S4-46/S4-47  my_quotes : demandes envoyées et reçues avec l'état de la commande née du devis, vue identique pour les deux parties
-- Retour arrière : drop function decline_quote(uuid, text), quote_contact(uuid, text), expire_quotes(), my_quotes() ;
--   select cron.unschedule('expire-quotes') ; recréer answer_quote (20261030000900) et decide_quote (20261115140000) ;
--   alter table quote_requests drop column valid_until, drop column decline_reason, drop column answers ; recréer la contrainte de statut d'origine.

alter table quote_requests add column if not exists valid_until timestamptz;
alter table quote_requests add column if not exists decline_reason text check (decline_reason is null or char_length(decline_reason) <= 500);
alter table quote_requests add column if not exists answers smallint not null default 0;

alter table quote_requests drop constraint if exists quote_requests_status_check;
alter table quote_requests add constraint quote_requests_status_check
  check (status in ('requested', 'quoted', 'accepted', 'declined', 'cancelled', 'rejected', 'expired'));

-- Devis déjà envoyés avant cette migration : quatorze jours à partir de la mise en service au plus tôt, pour ne pas les périmer d'un coup.
update quote_requests set valid_until = greatest(coalesce(quoted_at, created_at) + interval '14 days', now() + interval '7 days')
 where status = 'quoted' and valid_until is null;

-- ============================================================ S4-42 : réponse du prestataire
create or replace function answer_quote(p_id uuid, p_amount integer, p_delay_days integer, p_message text) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; t text; v_until timestamptz;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into q from quote_requests where id = p_id and provider_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status not in ('requested', 'quoted') then raise exception 'Cette demande est déjà clôturée'; end if;
  if q.status = 'requested' and q.created_at < now() - interval '30 days' then raise exception 'Cette demande a expiré (30 jours sans réponse)'; end if;
  if exists (select 1 from profiles where id = q.requester_id and coalesce(suspended, false)) then raise exception 'Le demandeur n''est plus joignable'; end if;
  select title into t from listings where id = q.listing_id and status = 'approved';
  if t is null then raise exception 'Votre annonce n''est plus publiée : republiez-la avant de répondre'; end if;
  if p_amount is null or p_amount < 1 or p_amount > 100000000 then raise exception 'Indiquez un montant entre 1 et 100 000 000 FCFA'; end if;
  if p_delay_days is null or p_delay_days < 1 or p_delay_days > 365 then raise exception 'Indiquez un délai de 1 à 365 jours'; end if;
  if q.answers >= 5 then raise exception 'Vous avez déjà modifié ce devis cinq fois : le demandeur doit se prononcer'; end if;
  v_until := now() + interval '14 days';
  update quote_requests set status = 'quoted', quote_amount = p_amount, quote_delay_days = p_delay_days,
    quote_message = nullif(left(trim(coalesce(p_message, '')), 2000), ''), quoted_at = now(), valid_until = v_until, answers = answers + 1
   where id = q.id;
  insert into notifications (user_id, kind, title, body, data)
  values (q.requester_id, 'quote', 'Devis reçu',
          'Service « ' || t || ' » : ' || p_amount || ' FCFA en ' || p_delay_days || ' jour(s), valable jusqu''au ' || to_char(v_until, 'DD/MM/YYYY') || '.',
          jsonb_build_object('quote_id', q.id));
  return 'quoted';
end $$;

-- Acceptation : le montant que le demandeur a vu est rappelé ; un devis expiré ne s'accepte plus.
create or replace function decide_quote(p_id uuid, p_accept boolean, p_amount integer default null) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; t text; s text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_id and requester_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status = 'expired' then raise exception 'Ce devis a expiré : demandez au prestataire de le renouveler'; end if;
  if q.status <> 'quoted' then raise exception 'Aucun devis à valider pour cette demande'; end if;
  if p_accept and q.valid_until is not null and q.valid_until < now() then
    raise exception 'Ce devis a expiré : demandez au prestataire de le renouveler';
  end if;
  if p_accept and p_amount is not null and p_amount is distinct from q.quote_amount then
    raise exception 'Le prestataire a modifié son devis : relisez le nouveau montant avant d''accepter';
  end if;
  s := case when p_accept then 'accepted' else 'declined' end;
  update quote_requests set status = s, decided_at = now() where id = q.id;
  select title into t from listings where id = q.listing_id;
  insert into notifications (user_id, kind, title, body, data)
  values (q.provider_id, 'quote', case when p_accept then 'Devis accepté' else 'Devis refusé' end, 'Service « ' || t || ' »', jsonb_build_object('quote_id', q.id));
  return s;
end $$;

-- ============================================================ S4-40 : décliner une demande
create or replace function decline_quote(p_id uuid, p_reason text default null) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; t text; v_reason text := nullif(left(trim(coalesce(p_reason, '')), 500), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_id and provider_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status not in ('requested', 'quoted') then raise exception 'Cette demande est déjà clôturée'; end if;
  update quote_requests set status = 'rejected', decline_reason = v_reason, decided_at = now() where id = q.id;
  select title into t from listings where id = q.listing_id;
  insert into notifications (user_id, kind, title, body, data)
  values (q.requester_id, 'quote', 'Demande de devis déclinée',
          'Service « ' || coalesce(t, 'Service') || ' » : le prestataire ne peut pas donner suite' || case when v_reason is null then '.' else ' (' || v_reason || ').' end,
          jsonb_build_object('quote_id', q.id));
  return 'rejected';
end $$;

-- ============================================================ S4-42 : expiration (cron)
create or replace function expire_quotes() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0; t text;
begin
  for r in
    with e as (
      update quote_requests set status = 'expired', decided_at = now()
       where (status = 'quoted' and valid_until is not null and valid_until < now())
          or (status = 'requested' and created_at < now() - interval '30 days')
      returning id, requester_id, provider_id, listing_id, quote_amount)
    select * from e
  loop
    n := n + 1;
    select title into t from listings where id = r.listing_id;
    insert into notifications (user_id, kind, title, body, data) values
      (r.requester_id, 'quote', 'Devis expiré', 'Service « ' || coalesce(t, 'Service') || ' » : la demande a expiré, vous pouvez en faire une nouvelle.', jsonb_build_object('quote_id', r.id)),
      (r.provider_id, 'quote', 'Devis expiré', 'Service « ' || coalesce(t, 'Service') || ' » : la demande a expiré sans décision.', jsonb_build_object('quote_id', r.id));
  end loop;
  return n;
end $$;
revoke all on function expire_quotes() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('expire-quotes') where exists (select 1 from cron.job where jobname = 'expire-quotes');
  perform cron.schedule('expire-quotes', '20 * * * *', 'select public.expire_quotes()');
exception when others then
  raise notice 'pg_cron indisponible : expire_quotes() doit être planifiée autrement (%).', sqlerrm;
end $$;

-- ============================================================ S4-41 : contact lié au devis
-- Le message est rangé dans la conversation de l'annonce entre les deux parties (la même que « Contacter le vendeur »).
create or replace function quote_contact(p_quote uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; other uuid; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  select * into q from quote_requests where id = p_quote and (requester_id = auth.uid() or provider_id = auth.uid());
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status = 'cancelled' then raise exception 'Cette demande a été annulée'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  other := case when q.requester_id = auth.uid() then q.provider_id else q.requester_id end;
  if not exists (select 1 from profiles where id = other and not coalesce(suspended, false)) then raise exception 'Destinataire introuvable'; end if;
  perform chat_guard(other);
  select c.id into cid from conversations c
    where c.listing_id = q.listing_id
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = other)
    limit 1;
  if cid is null then
    if (select count(*) from conversations where created_by = auth.uid() and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Trop de nouvelles conversations aujourd''hui';
    end if;
    insert into conversations (listing_id, created_by) values (q.listing_id, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, other, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left('À propos du devis : ' || trim(p_body), 4000));
  return cid;
end $$;

-- ============================================================ lecture des devis (envoyés et reçus)
create or replace function my_quotes() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', q.id, 'requester_id', q.requester_id, 'provider_id', q.provider_id, 'brief', q.brief, 'budget', q.budget, 'deadline', q.deadline,
      'status', q.status, 'quote_amount', q.quote_amount, 'quote_delay_days', q.quote_delay_days, 'quote_message', q.quote_message,
      'order_number', q.order_number, 'created_at', q.created_at, 'valid_until', q.valid_until, 'decline_reason', q.decline_reason,
      'listings', jsonb_build_object('title', l.title),
      'requester_name', display_name(q.requester_id), 'provider_name', display_name(q.provider_id),
      'order_state', (select case when o.cancelled_at is not null or coalesce(o.cancelled, false) then 'cancelled' when o.paid then 'paid' else 'pending' end
                        from orders o where o.number = q.order_number)
    ) order by q.created_at desc)
    from (select * from quote_requests where requester_id = auth.uid() or provider_id = auth.uid() order by created_at desc limit 200) q
    join listings l on l.id = q.listing_id
  ), '[]'::jsonb);
end $$;

revoke all on function answer_quote(uuid, integer, integer, text), decide_quote(uuid, boolean, integer), decline_quote(uuid, text), quote_contact(uuid, text), my_quotes() from public, anon;
grant execute on function answer_quote(uuid, integer, integer, text), decide_quote(uuid, boolean, integer), decline_quote(uuid, text), quote_contact(uuid, text), my_quotes() to authenticated;
