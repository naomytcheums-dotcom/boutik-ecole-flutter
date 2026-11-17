-- Lot F4 (3/3) : négociation de devis (E2-9, E3 190, E2-19).
-- Un devis (quote_requests) n'avait ni fil d'échange ni historique : seuls existaient answer_quote (le prestataire révise son montant et son délai, cinq fois au plus),
-- decide_quote / cancel_quote (le demandeur) et quote_contact (message rangé dans la messagerie générale). Ce lot ajoute :
--   · quote_messages : le fil du devis ; lecture réservée au demandeur, au prestataire et (lecture seule) au département / à l'administration / au support ;
--     aucune écriture directe ;
--   · un déclencheur sur quote_requests qui consigne les évènements réels dans le fil (demande, devis ou contre-proposition de prix et de délai, acceptation, refus,
--     annulation, déclin, expiration) sans modifier answer_quote / decide_quote / decline_quote / cancel_quote : il ne peut jamais faire échouer ces actions ;
--   · quote_thread(devis) : le devis et son fil, avec les actions possibles selon le rôle et le statut ;
--   · quote_message_send(devis, texte) : message (1 à 1000 caractères), compte non suspendu, interlocuteur joignable et non bloqué, plafond de débit (chat_guard + 12 par
--     heure et par devis), fil limité à 200 messages, devis clos refusé ; l'autre partie reçoit une notification de type « quote » (destination : le fil de ce devis).
-- Retour arrière : drop trigger trg_quote_events on quote_requests ; drop function _quote_events(), quote_thread(uuid, integer), quote_message_send(uuid, text) ; drop table quote_messages.

create table if not exists quote_messages (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references quote_requests(id) on delete cascade,
  sender_id uuid references profiles(id) on delete set null,
  kind text not null default 'message' check (kind in ('message', 'event')),
  body text not null check (char_length(btrim(body)) between 1 and 2200),
  created_at timestamptz not null default now()
);
create index if not exists quote_messages_quote on quote_messages (quote_id, created_at);
alter table quote_messages enable row level security;
revoke all on quote_messages from anon, authenticated;
grant select on quote_messages to authenticated;
drop policy if exists "fil de devis : parties et équipe" on quote_messages;
create policy "fil de devis : parties et équipe" on quote_messages for select
  using (exists (select 1 from quote_requests q where q.id = quote_messages.quote_id
                  and (q.requester_id = auth.uid() or q.provider_id = auth.uid() or current_role_name() in ('dept', 'admin', 'support'))));

create or replace function _quote_fcfa(p integer) returns text
language sql immutable set search_path = public as $$
  select regexp_replace(p::text, '(\d)(?=(\d{3})+$)', '\1 ', 'g') || ' FCFA'
$$;

-- Évènements réels du devis dans le fil.
create or replace function _quote_events() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if tg_op = 'INSERT' then
      insert into quote_messages (quote_id, sender_id, kind, body, created_at) values (new.id, new.requester_id, 'event', 'Demande de devis envoyée.', new.created_at);
    else
      if new.status = 'quoted' and (new.quote_amount is distinct from old.quote_amount or new.quote_delay_days is distinct from old.quote_delay_days or old.status <> 'quoted') and new.quote_amount is not null then
        insert into quote_messages (quote_id, sender_id, kind, body)
          values (new.id, new.provider_id, 'event', (case when old.status = 'quoted' then 'Contre-proposition du prestataire : ' else 'Devis du prestataire : ' end)
                  || _quote_fcfa(new.quote_amount) || ' en ' || new.quote_delay_days || ' jour(s)'
                  || case when new.valid_until is null then '' else ', valable jusqu''au ' || to_char(new.valid_until, 'DD/MM/YYYY') end || '.'
                  || case when nullif(btrim(coalesce(new.quote_message, '')), '') is null then '' else E'\n' || left(btrim(new.quote_message), 1000) end);
      elsif new.status is distinct from old.status then
        insert into quote_messages (quote_id, sender_id, kind, body)
          select new.id,
                 case new.status when 'accepted' then new.requester_id when 'declined' then new.requester_id when 'cancelled' then new.requester_id when 'rejected' then new.provider_id else null end,
                 'event',
                 case new.status
                   when 'accepted' then 'Devis accepté par le demandeur' || case when new.quote_amount is null then '.' else ' : ' || _quote_fcfa(new.quote_amount) || '.' end
                   when 'declined' then 'Devis refusé par le demandeur.'
                   when 'cancelled' then 'Demande annulée par le demandeur.'
                   when 'rejected' then 'Demande déclinée par le prestataire' || case when nullif(btrim(coalesce(new.decline_reason, '')), '') is null then '.' else ' : ' || left(btrim(new.decline_reason), 500) end
                   when 'expired' then 'Devis expiré.'
                   else 'Statut modifié.' end
           where new.status in ('accepted', 'declined', 'cancelled', 'rejected', 'expired');
      end if;
    end if;
  exception when others then
    raise warning 'évènement de devis ignoré : %', sqlerrm;
  end;
  return null;
end $$;
revoke all on function _quote_events() from public, anon, authenticated;
drop trigger if exists trg_quote_events on quote_requests;
create trigger trg_quote_events after insert or update on quote_requests for each row execute function _quote_events();

-- Historique des devis existants : demande, dernier devis et décision, avec leurs dates réelles.
insert into quote_messages (quote_id, sender_id, kind, body, created_at)
  select q.id, q.requester_id, 'event', 'Demande de devis envoyée.', q.created_at from quote_requests q
   where not exists (select 1 from quote_messages m where m.quote_id = q.id);
insert into quote_messages (quote_id, sender_id, kind, body, created_at)
  select q.id, q.provider_id, 'event', 'Devis du prestataire : ' || _quote_fcfa(q.quote_amount) || ' en ' || q.quote_delay_days || ' jour(s).', coalesce(q.quoted_at, q.created_at)
    from quote_requests q
   where q.quote_amount is not null and q.quote_delay_days is not null
     and not exists (select 1 from quote_messages m where m.quote_id = q.id and m.kind = 'event' and m.body like 'Devis du prestataire%');
insert into quote_messages (quote_id, sender_id, kind, body, created_at)
  select q.id,
         case q.status when 'rejected' then q.provider_id when 'expired' then null else q.requester_id end,
         'event',
         case q.status when 'accepted' then 'Devis accepté par le demandeur.' when 'declined' then 'Devis refusé par le demandeur.' when 'cancelled' then 'Demande annulée par le demandeur.'
                       when 'rejected' then 'Demande déclinée par le prestataire.' else 'Devis expiré.' end,
         coalesce(q.decided_at, q.created_at)
    from quote_requests q
   where q.status in ('accepted', 'declined', 'cancelled', 'rejected', 'expired')
     and not exists (select 1 from quote_messages m where m.quote_id = q.id and m.kind = 'event' and m.body not like 'Demande de devis%' and m.body not like 'Devis du prestataire%');

-- Le devis et son fil.
create or replace function quote_thread(p_quote uuid, p_limit integer default 200) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare q quote_requests%rowtype; v_me uuid := auth.uid(); v_staff boolean; v_role text; v_exp boolean; v_open boolean; v_title text;
begin
  if v_me is null then raise exception 'Connexion requise'; end if;
  v_staff := coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support');
  select * into q from quote_requests where id = p_quote and (requester_id = v_me or provider_id = v_me or v_staff);
  if not found then raise exception 'Demande introuvable'; end if;
  v_role := case when q.requester_id = v_me then 'requester' when q.provider_id = v_me then 'provider' else 'staff' end;
  v_exp := q.status = 'expired' or (q.status = 'quoted' and q.valid_until is not null and q.valid_until < now());
  v_open := q.status in ('requested', 'quoted') and not v_exp;
  select title into v_title from listings where id = q.listing_id;
  return jsonb_build_object(
    'quote', jsonb_build_object(
      'id', q.id, 'requester_id', q.requester_id, 'provider_id', q.provider_id, 'brief', q.brief, 'budget', q.budget, 'deadline', q.deadline,
      'status', q.status, 'quote_amount', q.quote_amount, 'quote_delay_days', q.quote_delay_days, 'quote_message', q.quote_message,
      'order_number', q.order_number, 'created_at', q.created_at, 'valid_until', q.valid_until, 'decline_reason', q.decline_reason, 'answers', q.answers,
      'listing_title', v_title, 'requester_name', display_name(q.requester_id), 'provider_name', display_name(q.provider_id), 'expired', v_exp),
    'my_role', v_role,
    'can', jsonb_build_object(
      'write', v_role <> 'staff' and q.status in ('requested', 'quoted', 'accepted'),
      'accept', v_role = 'requester' and q.status = 'quoted' and not v_exp,
      'decline', v_role = 'requester' and q.status = 'quoted',
      'cancel', v_role = 'requester' and v_open,
      'revise', v_role = 'provider' and q.status in ('requested', 'quoted') and q.answers < 5,
      'reject', v_role = 'provider' and q.status in ('requested', 'quoted')),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object('id', m.id, 'sender_id', m.sender_id, 'sender_name', case when m.sender_id is null then null else display_name(m.sender_id) end,
                                          'kind', m.kind, 'body', m.body, 'created_at', m.created_at, 'mine', m.sender_id = v_me) order by m.created_at, m.id)
      from (select * from quote_messages where quote_id = q.id order by created_at desc, id desc limit least(greatest(coalesce(p_limit, 200), 1), 200)) m
    ), '[]'::jsonb));
end $$;

create or replace function quote_message_send(p_quote uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; v_body text := btrim(coalesce(p_body, '')); v_other uuid; v_id uuid; v_title text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_body = '' then raise exception 'Message vide'; end if;
  if char_length(v_body) > 1000 then raise exception 'Message trop long (1000 caractères au plus)'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into q from quote_requests where id = p_quote and (requester_id = auth.uid() or provider_id = auth.uid()) for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status not in ('requested', 'quoted', 'accepted') then raise exception 'Cette demande est clôturée : le fil n''accepte plus de message'; end if;
  v_other := case when q.requester_id = auth.uid() then q.provider_id else q.requester_id end;
  if not exists (select 1 from profiles where id = v_other and not coalesce(suspended, false)) then raise exception 'Votre interlocuteur n''est plus joignable'; end if;
  perform chat_guard(v_other);
  if (select count(*) from quote_messages where quote_id = q.id and sender_id = auth.uid() and kind = 'message' and created_at > now() - interval '1 hour') >= 12 then
    raise exception 'Trop de messages sur ce devis : patientez avant d''écrire de nouveau';
  end if;
  if (select count(*) from quote_messages where quote_id = q.id and kind = 'message') >= 200 then raise exception 'Ce fil est complet (200 messages)'; end if;
  insert into quote_messages (quote_id, sender_id, kind, body) values (q.id, auth.uid(), 'message', v_body) returning id into v_id;
  select title into v_title from listings where id = q.listing_id;
  insert into notifications (user_id, kind, title, body, data)
    values (v_other, 'quote', 'Nouveau message sur un devis', 'Service « ' || coalesce(v_title, 'Service') || ' » : ' || left(v_body, 120), jsonb_build_object('quote_id', q.id, 'thread', true));
  return v_id;
end $$;

revoke all on function quote_thread(uuid, integer), quote_message_send(uuid, text) from public, anon;
grant execute on function quote_thread(uuid, integer), quote_message_send(uuid, text) to authenticated;
