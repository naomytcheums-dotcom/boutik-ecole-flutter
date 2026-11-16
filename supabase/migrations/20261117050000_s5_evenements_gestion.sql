-- Lot S5 (profil étudiant) — cycle de vie des événements officiels : création contrôlée, modification, annulation avec prévenance des inscrits,
-- suivi des remboursements des inscriptions payées, « Mes événements » (inscriptions et reçus), compte suspendu refusé à l'inscription gratuite.
-- Corrige S5-49, S5-50, S5-51, S5-52, S5-56 (et S5-53 : texte du rappel). Le prix reste events.price (FCFA) : event_checkout, trg_event_paid, expire_event_holds
-- et payment_start ne sont pas redéfinis (on_event_paid l'est uniquement pour refuser un paiement tardif sur un événement annulé).
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (supabase/tests/marketplace_pglite/etu_s5.mjs).
-- Retour arrière :
--   drop function if exists event_update(uuid, text, text, text, timestamptz, timestamptz, text, integer, integer), event_cancel(uuid, text), events_managed(),
--     event_registrants(uuid), event_refund_done(uuid, uuid), my_event_registrations();
--   alter table event_registrations drop constraint if exists event_registrations_status_check;
--   alter table event_registrations add constraint event_registrations_status_check check (status in ('confirmed', 'pending_payment'));
--   alter table event_registrations drop column if exists refund_status, drop column if exists refunded_at;
--   alter table events drop column if exists cancel_reason, drop column if exists cancelled_at, drop column if exists updated_at;
--   puis recréer event_create, event_register, on_event_paid et send_event_reminders depuis 20261105000000 / 20261116100000.

-- ============================================================ 1. Colonnes
alter table events add column if not exists cancel_reason text check (cancel_reason is null or char_length(cancel_reason) <= 300);
alter table events add column if not exists cancelled_at timestamptz;
alter table events add column if not exists updated_at timestamptz;
alter table event_registrations add column if not exists refund_status text;
alter table event_registrations add column if not exists refunded_at timestamptz;
do $$ begin
  alter table event_registrations drop constraint if exists event_registrations_status_check;
  alter table event_registrations add constraint event_registrations_status_check check (status in ('confirmed', 'pending_payment', 'cancelled'));
  alter table event_registrations add constraint event_registrations_refund_check check (refund_status is null or refund_status in ('to_refund', 'refunded'));
exception when duplicate_object then null; end $$;

-- ============================================================ 2. Création (contrôles de dates, de prix et de capacité)
create or replace function event_create(p_title text, p_description text, p_kind text, p_starts timestamptz, p_ends timestamptz, p_place text, p_price int, p_capacity int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 140 then raise exception 'Titre : 3 à 140 caractères'; end if;
  if char_length(coalesce(p_description, '')) > 2000 then raise exception 'Description : 2000 caractères au plus'; end if;
  if char_length(coalesce(p_place, '')) > 140 then raise exception 'Lieu : 140 caractères au plus'; end if;
  if p_kind is null or p_kind not in ('exposition', 'atelier', 'conference', 'salon', 'autre') then p_kind := 'autre'; end if;
  if p_starts is null or p_starts <= now() then raise exception 'La date de début doit être dans le futur'; end if;
  if p_ends is not null and p_ends < p_starts then raise exception 'La fin ne peut pas précéder le début'; end if;
  if coalesce(p_price, 0) < 0 or coalesce(p_price, 0) > 5000000 then raise exception 'Tarif : de 0 (gratuit) à 5 000 000 FCFA'; end if;
  if p_capacity is not null and p_capacity < 1 then raise exception 'Capacité : au moins une place (laissez vide pour illimité)'; end if;
  insert into events (title, description, kind, starts_at, ends_at, place, price, capacity, created_by)
  values (trim(p_title), nullif(trim(coalesce(p_description, '')), ''), p_kind, p_starts, p_ends, nullif(trim(coalesce(p_place, '')), ''), coalesce(p_price, 0), p_capacity, auth.uid())
  returning id into v_id;
  return v_id;
end $$;
revoke all on function event_create(text, text, text, timestamptz, timestamptz, text, int, int) from public, anon;
grant execute on function event_create(text, text, text, timestamptz, timestamptz, text, int, int) to authenticated;

-- ============================================================ 3. Modification : l'organisateur (ou l'administration) ; les inscrits sont prévenus d'un changement de date ou de lieu
create or replace function event_update(p_id uuid, p_title text, p_description text, p_kind text, p_starts timestamptz, p_ends timestamptz, p_place text, p_price integer, p_capacity integer) returns integer
language plpgsql security definer set search_path = public as $$
declare e events%rowtype; v_role text := coalesce(current_role_name()::text, ''); v_changed boolean; r record; n integer := 0; v_what text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into e from events where id = p_id for update;
  if not found or not (e.created_by = auth.uid() or v_role in ('direction', 'admin')) then raise exception 'Événement introuvable'; end if;
  if e.status = 'cancelled' then raise exception 'Cet événement est annulé : il ne peut plus être modifié'; end if;
  if e.starts_at <= now() then raise exception 'Cet événement a déjà commencé : il ne peut plus être modifié'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 140 then raise exception 'Titre : 3 à 140 caractères'; end if;
  if char_length(coalesce(p_description, '')) > 2000 then raise exception 'Description : 2000 caractères au plus'; end if;
  if char_length(coalesce(p_place, '')) > 140 then raise exception 'Lieu : 140 caractères au plus'; end if;
  if p_kind is null or p_kind not in ('exposition', 'atelier', 'conference', 'salon', 'autre') then p_kind := e.kind; end if;
  if p_starts is null or p_starts <= now() then raise exception 'La date de début doit être dans le futur'; end if;
  if p_ends is not null and p_ends < p_starts then raise exception 'La fin ne peut pas précéder le début'; end if;
  if coalesce(p_price, 0) < 0 or coalesce(p_price, 0) > 5000000 then raise exception 'Tarif : de 0 (gratuit) à 5 000 000 FCFA'; end if;
  if p_capacity is not null and p_capacity < 1 then raise exception 'Capacité : au moins une place (laissez vide pour illimité)'; end if;
  if p_capacity is not null and p_capacity < _event_taken(e.id) then raise exception 'Capacité inférieure au nombre de places déjà prises (%)', _event_taken(e.id); end if;
  if coalesce(p_price, 0) <> e.price and exists (select 1 from event_registrations where event_id = e.id and payment_id is not null and status in ('confirmed', 'pending_payment')) then
    raise exception 'Des inscriptions payées ou en cours de paiement existent : le tarif ne peut plus changer. Annulez l''événement et créez-en un nouveau.';
  end if;
  v_changed := p_starts is distinct from e.starts_at or p_ends is distinct from e.ends_at or coalesce(nullif(trim(coalesce(p_place, '')), ''), '') is distinct from coalesce(e.place, '');
  update events set title = trim(p_title), description = nullif(trim(coalesce(p_description, '')), ''), kind = p_kind, starts_at = p_starts, ends_at = p_ends,
    place = nullif(trim(coalesce(p_place, '')), ''), price = coalesce(p_price, 0), capacity = p_capacity, updated_at = now() where id = e.id;
  if v_changed then
    v_what := to_char(p_starts at time zone 'Africa/Douala', 'DD/MM/YYYY "à" HH24"h"MI') || coalesce(' · ' || nullif(trim(coalesce(p_place, '')), ''), '');
    for r in select user_id from event_registrations where event_id = e.id and status in ('confirmed', 'pending_payment') loop
      perform notify_user(r.user_id, 'event', 'Événement modifié', left('« ' || trim(p_title) || ' » a changé : ' || v_what || '. Si cela ne vous convient plus, annulez votre inscription.', 500), jsonb_build_object('event', e.id));
      n := n + 1;
    end loop;
  end if;
  return n;
end $$;
revoke all on function event_update(uuid, text, text, text, timestamptz, timestamptz, text, integer, integer) from public, anon;
grant execute on function event_update(uuid, text, text, text, timestamptz, timestamptz, text, integer, integer) to authenticated;

-- ============================================================ 4. Annulation : inscrits prévenus, réservations libérées, remboursements signalés à la finance
create or replace function event_cancel(p_id uuid, p_reason text default '') returns integer
language plpgsql security definer set search_path = public as $$
declare e events%rowtype; v_role text := coalesce(current_role_name()::text, ''); g event_registrations%rowtype; t payment_transactions%rowtype; n integer := 0; v_refunds integer := 0;
  v_reason text := left(btrim(coalesce(p_reason, '')), 300);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('dept', 'direction', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into e from events where id = p_id for update;
  if not found or not (e.created_by = auth.uid() or v_role in ('direction', 'admin')) then raise exception 'Événement introuvable'; end if;
  if e.status = 'cancelled' then raise exception 'Cet événement est déjà annulé'; end if;
  if e.starts_at <= now() then raise exception 'Cet événement a déjà commencé : il ne peut plus être annulé'; end if;
  if char_length(v_reason) < 5 then raise exception 'Indiquez le motif de l''annulation (5 caractères au moins)'; end if;
  update events set status = 'cancelled', cancel_reason = v_reason, cancelled_at = now(), updated_at = now() where id = e.id;
  for g in select * from event_registrations where event_id = e.id and status in ('confirmed', 'pending_payment') for update loop
    t := null;
    if g.payment_id is not null then select * into t from payment_transactions where id = g.payment_id; end if;
    if g.status = 'pending_payment' and (t.id is null or t.status in ('created', 'failed', 'cancelled')) then
      perform _event_drop_hold(e.id, g.user_id, 'Événement annulé');
      perform notify_user(g.user_id, 'event', 'Événement annulé', left('« ' || e.title || ' » est annulé : ' || v_reason || '. Votre réservation est libérée, rien n''est débité.', 500), jsonb_build_object('event', e.id));
    elsif t.id is not null and t.status in ('pending', 'confirmed') then
      update event_registrations set status = 'cancelled', hold_expires_at = null, refund_status = 'to_refund' where event_id = e.id and user_id = g.user_id;
      perform notify_user(g.user_id, 'event', 'Événement annulé : remboursement', left('« ' || e.title || ' » est annulé : ' || v_reason || '. Votre paiement de ' || t.amount || ' FCFA (' || t.reference || ') sera remboursé par la finance.', 500),
        jsonb_build_object('event', e.id, 'payment_id', t.id));
      v_refunds := v_refunds + 1;
    else
      update event_registrations set status = 'cancelled', hold_expires_at = null where event_id = e.id and user_id = g.user_id;
      perform notify_user(g.user_id, 'event', 'Événement annulé', left('« ' || e.title || ' » est annulé : ' || v_reason || '.', 500), jsonb_build_object('event', e.id));
    end if;
    n := n + 1;
  end loop;
  if v_refunds > 0 then
    insert into notifications (user_id, kind, title, body, data)
      select f.id, 'payment', 'Remboursements à traiter', left(v_refunds || ' inscription(s) payée(s) à rembourser : événement « ' || e.title || ' » annulé.', 500), jsonb_build_object('event', e.id)
      from profiles f where f.role::text in ('finance', 'admin') and f.id <> auth.uid();
  end if;
  return n;
end $$;
revoke all on function event_cancel(uuid, text) from public, anon;
grant execute on function event_cancel(uuid, text) to authenticated;

-- ============================================================ 5. Paiement tardif sur un événement annulé : jamais d'inscription, remboursement signalé (reste identique sinon)
create or replace function on_event_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare e events; g event_registrations%rowtype; v_num text; v_ok boolean := false; v_why text;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'event' and new.subject like 'evt:%' then
    select * into e from events where id::text = substr(new.subject, 5) for update;
    if not found then return null; end if;
    select * into g from event_registrations where event_id = e.id and user_id = new.payer_id for update;
    if e.status = 'cancelled' then
      v_why := 'événement annulé';
      if found then update event_registrations set status = 'cancelled', hold_expires_at = null, refund_status = 'to_refund', payment_id = new.id where event_id = e.id and user_id = new.payer_id; end if;
    elsif found and g.status = 'confirmed' then
      v_why := 'déjà inscrit(e) : paiement en double';
    elsif new.amount < e.price and new.amount < coalesce(g.amount_due, e.price) then
      v_why := 'montant inférieur au prix';
    elsif found then
      update event_registrations set status = 'confirmed', payment_id = new.id, hold_expires_at = null where event_id = e.id and user_id = new.payer_id;
      v_ok := true;
    elsif e.status = 'published' and e.starts_at > now() and (e.capacity is null or _event_taken(e.id) < e.capacity) then
      -- réservation déjà libérée (paiement tardif) : la place est reprise si elle est encore disponible
      insert into event_registrations (event_id, user_id, status, payment_id, amount_due) values (e.id, new.payer_id, 'confirmed', new.id, new.amount);
      v_ok := true;
    else
      v_why := 'plus de place ou événement clos';
    end if;
    if v_ok then
      v_num := 'REC-EV-' || nextval('event_receipt_seq');
      insert into event_receipts (number, payment_id, event_id, user_id, title, amount, reference)
        values (v_num, new.id, e.id, new.payer_id, e.title, new.amount, new.reference) on conflict (payment_id) do nothing;
      insert into notifications (user_id, kind, title, body, data)
        values (new.payer_id, 'event', 'Inscription confirmée',
                left('Paiement de ' || new.amount || ' FCFA reçu pour « ' || e.title || ' » · ' || to_char(e.starts_at at time zone 'Africa/Douala', 'DD/MM/YYYY "à" HH24"h"MI') || coalesce(' · ' || e.place, '') || ' · reçu ' || v_num, 500),
                jsonb_build_object('event', e.id, 'payment_id', new.id, 'receipt', v_num));
      if e.created_by is not null and e.created_by <> new.payer_id then
        insert into notifications (user_id, kind, title, body, data)
          values (e.created_by, 'event', 'Nouvelle inscription payée', left(display_name(new.payer_id) || ' s''est inscrit(e) à « ' || e.title || ' » (' || new.amount || ' FCFA).', 500),
                  jsonb_build_object('event', e.id));
      end if;
    else
      insert into notifications (user_id, kind, title, body, data)
        values (new.payer_id, 'event', 'Paiement reçu, inscription impossible',
                left('Votre paiement ' || new.reference || ' pour « ' || e.title || ' » a bien été reçu mais votre place n''a pas pu être validée (' || v_why || '). La finance vous contactera pour le remboursement.', 500),
                jsonb_build_object('event', e.id, 'payment_id', new.id));
      insert into notifications (user_id, kind, title, body, data)
        select f.id, 'payment', 'Remboursement à traiter', new.reference || ' · ' || new.amount || ' FCFA · ' || e.title || ' (' || v_why || ')', jsonb_build_object('payment_id', new.id)
        from profiles f where f.role::text in ('finance', 'admin');
    end if;
  end if;
  return null;
end $$;
revoke all on function on_event_paid() from public, anon, authenticated;

-- ============================================================ 6. Remboursement effectué (finance ou administration) : l'inscrit est prévenu
create or replace function event_refund_done(p_event uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g event_registrations%rowtype; e events%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into g from event_registrations where event_id = p_event and user_id = p_user and refund_status = 'to_refund' for update;
  if not found then raise exception 'Aucun remboursement en attente pour cette inscription'; end if;
  update event_registrations set refund_status = 'refunded', refunded_at = now() where event_id = p_event and user_id = p_user;
  select * into e from events where id = p_event;
  perform notify_user(p_user, 'event', 'Remboursement effectué', left('Votre paiement pour « ' || coalesce(e.title, 'l''événement') || ' » a été remboursé.', 500), jsonb_build_object('event', p_event));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Remboursement événement', coalesce(e.title, p_event::text), 'Finance', 'Info');
end $$;
revoke all on function event_refund_done(uuid, uuid) from public, anon;
grant execute on function event_refund_done(uuid, uuid) to authenticated;

-- ============================================================ 7. Lectures : événements gérés, inscrits d'un événement, mes inscriptions
create or replace function events_managed() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('dept', 'direction', 'finance', 'admin') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', e.id, 'title', e.title, 'description', coalesce(e.description, ''), 'kind', e.kind, 'starts_at', e.starts_at, 'ends_at', e.ends_at, 'place', coalesce(e.place, ''),
      'price', e.price, 'capacity', e.capacity, 'status', e.status, 'cancel_reason', e.cancel_reason, 'mine', e.created_by = auth.uid(),
      'registered', (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed'),
      'held', _event_taken(e.id) - (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed'),
      'paid', (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed' and r.payment_id is not null),
      'to_refund', (select count(*)::int from event_registrations r where r.event_id = e.id and r.refund_status = 'to_refund'))
      order by e.starts_at desc)
    from (select * from events where created_by = auth.uid() or v_role in ('direction', 'finance', 'admin') order by starts_at desc limit 100) e
  ), '[]'::jsonb);
end $$;
revoke all on function events_managed() from public, anon;
grant execute on function events_managed() to authenticated;

-- Inscrits d'un événement : l'organisateur, l'administration et la finance (noms abrégés).
create or replace function event_registrants(p_event uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('dept', 'direction', 'finance', 'admin') or not exists (select 1 from events where id = p_event and (created_by = auth.uid() or v_role in ('direction', 'finance', 'admin'))) then
    raise exception 'Événement introuvable';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('user_id', g.user_id, 'name', display_name(g.user_id), 'status', g.status, 'paid', g.payment_id is not null and g.status in ('confirmed', 'cancelled'),
      'amount', g.amount_due, 'refund_status', g.refund_status, 'created_at', g.created_at) order by g.created_at)
    from event_registrations g where g.event_id = p_event
  ), '[]'::jsonb);
end $$;
revoke all on function event_registrants(uuid) from public, anon;
grant execute on function event_registrants(uuid) to authenticated;

-- Mes inscriptions (toutes situations) avec leur reçu éventuel.
create or replace function my_event_registrations() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'event', e.id, 'title', e.title, 'kind', e.kind, 'starts_at', e.starts_at, 'place', coalesce(e.place, ''), 'price', e.price, 'event_status', e.status, 'cancel_reason', e.cancel_reason,
      'status', g.status, 'refund_status', g.refund_status, 'amount', g.amount_due, 'receipt', r.number, 'receipt_reference', r.reference, 'registered_at', g.created_at)
      order by e.starts_at desc)
    from (select * from event_registrations where user_id = auth.uid() and (status in ('confirmed', 'cancelled') or hold_expires_at > now()) order by created_at desc limit 100) g
    join events e on e.id = g.event_id
    left join event_receipts r on r.payment_id = g.payment_id
  ), '[]'::jsonb);
end $$;
revoke all on function my_event_registrations() from public, anon;
grant execute on function my_event_registrations() to authenticated;

-- ============================================================ 8. Inscription gratuite : un compte suspendu est refusé (comme event_checkout)
create or replace function event_register(p_event uuid) returns text
language plpgsql security definer set search_path = public as $$
declare e events; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu ou introuvable : inscription impossible'; end if;
  select * into e from events where id = p_event and status = 'published' for update;
  if e.id is null then raise exception 'Événement introuvable'; end if;
  if e.starts_at < now() then raise exception 'Événement terminé'; end if;
  if exists (select 1 from event_registrations where event_id = p_event and user_id = auth.uid() and status = 'confirmed') then return 'already'; end if;
  if e.price > 0 then
    raise exception 'Cet événement est payant (% FCFA) : touchez « Payer et s''inscrire » pour régler et réserver votre place.', e.price;
  end if;
  perform _event_drop_hold(p_event, auth.uid(), 'Événement devenu gratuit');
  n := _event_taken(p_event);
  if e.capacity is not null and n >= e.capacity then raise exception 'Plus de places'; end if;
  insert into event_registrations (event_id, user_id) values (p_event, auth.uid())
  on conflict (event_id, user_id) do update set status = 'confirmed', payment_id = null, hold_expires_at = null, refund_status = null where event_registrations.status = 'cancelled';
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'event', 'Inscription enregistrée',
            left('« ' || e.title || ' » · ' || to_char(e.starts_at at time zone 'Africa/Douala', 'DD/MM/YYYY "à" HH24"h"MI') || coalesce(' · ' || e.place, ''), 500),
            jsonb_build_object('event', e.id));
  return 'registered';
end $$;
revoke all on function event_register(uuid) from public, anon;
grant execute on function event_register(uuid) to authenticated;

-- ============================================================ 9. Rappel : le texte ne prétend plus « demain » pour un événement qui a lieu dans quelques heures
create or replace function send_event_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select g.user_id, e.id, e.title, e.starts_at, e.place from event_registrations g join events e on e.id = g.event_id
           where g.status = 'confirmed' and g.reminded_at is null and e.status = 'published' and e.starts_at > now() and e.starts_at <= now() + interval '24 hours' loop
    insert into notifications (user_id, kind, title, body, data)
      values (r.user_id, 'event', case when r.starts_at > now() + interval '12 hours' then 'Rappel : événement demain' else 'Rappel : événement imminent' end,
              left('« ' || r.title || ' » · ' || to_char(r.starts_at at time zone 'Africa/Douala', 'DD/MM/YYYY "à" HH24"h"MI') || coalesce(' · ' || r.place, ''), 500),
              jsonb_build_object('event', r.id));
    update event_registrations set reminded_at = now() where event_id = r.id and user_id = r.user_id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function send_event_reminders() from public, anon, authenticated;
