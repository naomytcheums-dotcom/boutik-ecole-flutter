-- Événements payants : l'inscription à un événement dont le prix (events.price, en FCFA) est supérieur à 0 passe par un vrai paiement.
--  * event_checkout(p_event, p_provider) : vérifie l'événement (publié, à venir, payant, non complet), refuse un compte suspendu ou déjà inscrit,
--    crée la transaction avec payment_start('event', 'evt:<id>', prix lu en base, 'tara' ou 'manual') et réserve une place « en attente de paiement » 30 minutes ;
--  * expire_event_holds() (pg_cron, toutes les 10 minutes) libère les places non payées et annule la transaction ; une transaction en cours de vérification
--    (Mobile Money déclaré, vérification de la finance) garde sa place jusqu'à 48 h ;
--  * trigger on_event_paid : à la confirmation du paiement (webhook Tara ou payment_set_status par la finance, jamais le payeur) l'inscription est validée,
--    l'inscrit et l'organisateur sont notifiés et un reçu logique est créé (event_receipts) ;
--  * event_register redirige les événements payants vers ce flux et reste inchangé pour les gratuits.
-- Le montant n'est jamais fourni par le client. payment_start, payment_set_status et marketplace_checkout ne sont pas redéfinis.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (supabase/tests/marketplace_pglite/evenements_payants.mjs).
-- Retour arrière (dans cet ordre) :
--   select cron.unschedule('expire-event-holds');
--   drop trigger if exists trg_event_paid on payment_transactions;
--   drop function if exists on_event_paid(), expire_event_holds(), event_checkout(uuid, text), my_event_receipts(), _event_drop_hold(uuid, uuid, text), _event_taken(uuid);
--   drop table if exists event_receipts; drop sequence if exists event_receipt_seq;
--   alter table event_registrations drop column if exists status, drop column if exists payment_id, drop column if exists hold_expires_at, drop column if exists amount_due;
--   puis recréer events_between, events_upcoming, event_register, event_unregister et send_event_reminders depuis 20261105000000 / 20261115160000.

-- ============================================================ 1. Inscriptions : statut, paiement lié, expiration
-- Le prix est la colonne existante events.price (entier, >= 0, 0 = gratuit).
alter table event_registrations add column if not exists status text not null default 'confirmed';
alter table event_registrations add column if not exists payment_id uuid references payment_transactions(id) on delete set null;
alter table event_registrations add column if not exists hold_expires_at timestamptz;
alter table event_registrations add column if not exists amount_due integer;
do $$ begin
  alter table event_registrations add constraint event_registrations_status_check check (status in ('confirmed', 'pending_payment'));
exception when duplicate_object then null; end $$;
create index if not exists event_registrations_holds on event_registrations (hold_expires_at) where status = 'pending_payment';

create sequence if not exists event_receipt_seq start 1000;
create table if not exists event_receipts (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  payment_id uuid not null unique references payment_transactions(id) on delete cascade,
  event_id uuid references events(id) on delete set null,
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  amount integer not null check (amount > 0),
  reference text not null,
  created_at timestamptz not null default now()
);
create index if not exists event_receipts_user on event_receipts (user_id, created_at desc);
alter table event_receipts enable row level security;
revoke all on event_receipts from anon, authenticated;
grant select on event_receipts to authenticated;
drop policy if exists "reçus d'événement : le payeur ou la finance" on event_receipts;
create policy "reçus d'événement : le payeur ou la finance" on event_receipts for select
  using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance', 'direction'));

-- ============================================================ 2. Fonctions internes
-- Places occupées : inscriptions confirmées + réservations en cours (délai de 30 minutes non écoulé, ou paiement en cours de vérification).
create or replace function _event_taken(p_event uuid) returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::int from event_registrations g left join payment_transactions t on t.id = g.payment_id
  where g.event_id = p_event and (g.status = 'confirmed' or g.hold_expires_at > now() or coalesce(t.status, '') = 'pending');
$$;
revoke all on function _event_taken(uuid) from public, anon, authenticated;

-- Libère la réservation en attente d'une personne et annule sa transaction non aboutie.
create or replace function _event_drop_hold(p_event uuid, p_user uuid, p_reason text) returns boolean
language plpgsql security definer set search_path = public as $$
declare g event_registrations%rowtype;
begin
  select * into g from event_registrations where event_id = p_event and user_id = p_user and status = 'pending_payment' for update;
  if not found then return false; end if;
  delete from event_registrations where event_id = p_event and user_id = p_user;
  if g.payment_id is not null then
    update payment_transactions set status = 'cancelled', decided_at = now(), note = left(p_reason, 300)
      where id = g.payment_id and status in ('created', 'pending', 'failed');
    if found then
      insert into payment_messages (transaction_id, sender, body) values (g.payment_id, 'system', 'Réservation libérée : ce paiement est annulé.');
    end if;
  end if;
  return true;
end $$;
revoke all on function _event_drop_hold(uuid, uuid, text) from public, anon, authenticated;

-- Réservations non payées : libérées après 30 minutes (une transaction « pending » déclarée garde sa place 48 h au plus).
create or replace function expire_event_holds() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0; v_title text;
begin
  for r in
    select g.event_id, g.user_id from event_registrations g left join payment_transactions t on t.id = g.payment_id
    where g.status = 'pending_payment' and g.hold_expires_at < now()
      and (t.id is null or t.status in ('created', 'failed', 'cancelled') or (t.status = 'pending' and t.created_at < now() - interval '48 hours'))
    order by g.hold_expires_at limit 500
  loop
    if _event_drop_hold(r.event_id, r.user_id, 'Réservation expirée : paiement non reçu à temps') then
      select title into v_title from events where id = r.event_id;
      insert into notifications (user_id, kind, title, body, data)
        values (r.user_id, 'event', 'Réservation expirée', left('Votre place pour « ' || coalesce(v_title, 'l''événement') || ' » a été libérée : le paiement n''a pas été reçu à temps. Vous pouvez recommencer l''inscription.', 500), jsonb_build_object('event', r.event_id));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
revoke all on function expire_event_holds() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('expire-event-holds') where exists (select 1 from cron.job where jobname = 'expire-event-holds');
  perform cron.schedule('expire-event-holds', '*/10 * * * *', 'select public.expire_event_holds()');
exception when others then
  raise notice 'pg_cron indisponible : les réservations d''événements non payées ne sont pas libérées tant que expire_event_holds() n''est pas planifiée (%).', sqlerrm;
end $$;

-- ============================================================ 3. Lecture : places réservées et état de la personne connectée
create or replace function events_between(p_from timestamptz, p_to timestamptz, p_kind text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'title', e.title, 'description', coalesce(e.description, ''), 'kind', e.kind, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
      'place', coalesce(e.place, ''), 'price', e.price, 'capacity', e.capacity,
      'registered', (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed'),
      'held', _event_taken(e.id) - (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed'),
      'mine', exists (select 1 from event_registrations r where r.event_id = e.id and r.user_id = auth.uid() and r.status = 'confirmed'),
      'my_status', (select case when g.status = 'confirmed' then 'confirmed' when g.hold_expires_at > now() or coalesce(t.status, '') = 'pending' then 'pending_payment' end
                    from event_registrations g left join payment_transactions t on t.id = g.payment_id where g.event_id = e.id and g.user_id = auth.uid()),
      'payment_status', (select t.status from event_registrations g join payment_transactions t on t.id = g.payment_id
                         where g.event_id = e.id and g.user_id = auth.uid() and g.status = 'pending_payment')
    ) order by e.starts_at), '[]'::jsonb)
  from events e
  where e.status = 'published' and e.starts_at >= p_from and e.starts_at < p_to
    and (p_kind is null or p_kind = '' or e.kind = p_kind);
$$;
revoke all on function events_between(timestamptz, timestamptz, text) from public, anon;
grant execute on function events_between(timestamptz, timestamptz, text) to anon, authenticated;

create or replace function events_upcoming(p_limit integer default 30, p_kind text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'title', e.title, 'description', coalesce(e.description, ''), 'kind', e.kind, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
      'place', coalesce(e.place, ''), 'price', e.price, 'capacity', e.capacity,
      'registered', (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed'),
      'held', _event_taken(e.id) - (select count(*)::int from event_registrations r where r.event_id = e.id and r.status = 'confirmed'),
      'mine', exists (select 1 from event_registrations r where r.event_id = e.id and r.user_id = auth.uid() and r.status = 'confirmed'),
      'my_status', (select case when g.status = 'confirmed' then 'confirmed' when g.hold_expires_at > now() or coalesce(t.status, '') = 'pending' then 'pending_payment' end
                    from event_registrations g left join payment_transactions t on t.id = g.payment_id where g.event_id = e.id and g.user_id = auth.uid()),
      'payment_status', (select t.status from event_registrations g join payment_transactions t on t.id = g.payment_id
                         where g.event_id = e.id and g.user_id = auth.uid() and g.status = 'pending_payment')
    ) order by e.starts_at), '[]'::jsonb)
  from (select * from events where status = 'published' and starts_at >= now() and (p_kind is null or p_kind = '' or kind = p_kind)
        order by starts_at limit least(greatest(p_limit, 1), 100)) e;
$$;
revoke all on function events_upcoming(integer, text) from public, anon;
grant execute on function events_upcoming(integer, text) to anon, authenticated;

-- Rappel la veille : seulement les inscriptions confirmées.
create or replace function send_event_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select g.user_id, e.id, e.title, e.starts_at, e.place from event_registrations g join events e on e.id = g.event_id
           where g.status = 'confirmed' and g.reminded_at is null and e.status = 'published' and e.starts_at > now() and e.starts_at <= now() + interval '24 hours' loop
    insert into notifications (user_id, kind, title, body, data)
      values (r.user_id, 'event', 'Rappel : événement demain',
              left('« ' || r.title || ' » · ' || to_char(r.starts_at at time zone 'Africa/Douala', 'DD/MM/YYYY "à" HH24"h"MI') || coalesce(' · ' || r.place, ''), 500),
              jsonb_build_object('event', r.id));
    update event_registrations set reminded_at = now() where event_id = r.id and user_id = r.user_id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function send_event_reminders() from public, anon, authenticated;

-- ============================================================ 4. Inscription simple : gratuit seulement ; payant -> event_checkout
create or replace function event_register(p_event uuid) returns text
language plpgsql security definer set search_path = public as $$
declare e events; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
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
  insert into event_registrations (event_id, user_id) values (p_event, auth.uid());
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'event', 'Inscription enregistrée',
            left('« ' || e.title || ' » · ' || to_char(e.starts_at at time zone 'Africa/Douala', 'DD/MM/YYYY "à" HH24"h"MI') || coalesce(' · ' || e.place, ''), 500),
            jsonb_build_object('event', e.id));
  return 'registered';
end $$;
revoke all on function event_register(uuid) from public, anon;
grant execute on function event_register(uuid) to authenticated;

-- Désinscription : une réservation non payée est libérée ; une inscription payée ne se supprime pas ici (remboursement par la finance).
create or replace function event_unregister(p_event uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g event_registrations%rowtype; t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into g from event_registrations where event_id = p_event and user_id = auth.uid() for update;
  if not found then return; end if;
  if g.status = 'pending_payment' then
    select * into t from payment_transactions where id = g.payment_id;
    if found and t.status = 'pending' then raise exception 'Un paiement est en cours de vérification : attendez sa confirmation ou son échec avant d''annuler'; end if;
    perform _event_drop_hold(p_event, auth.uid(), 'Réservation annulée par la personne');
    return;
  end if;
  if g.payment_id is not null then
    raise exception 'Inscription payée : pour l''annuler et demander un remboursement, contactez la finance depuis la messagerie de paiement';
  end if;
  delete from event_registrations where event_id = p_event and user_id = auth.uid();
end $$;
revoke all on function event_unregister(uuid) from public, anon;
grant execute on function event_unregister(uuid) to authenticated;

-- ============================================================ 5. Paiement d'un événement
-- Le prix est lu en base. Une réservation active est reprise (même transaction) au lieu d'en créer une seconde.
create or replace function event_checkout(p_event uuid, p_provider text default 'tara') returns jsonb
language plpgsql security definer set search_path = public as $$
declare e events; g event_registrations%rowtype; t payment_transactions%rowtype; v_id uuid; v_ref text; v_until timestamptz;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu ou introuvable : inscription impossible'; end if;
  if p_provider is null or p_provider not in ('tara', 'manual') then raise exception 'Mode de paiement invalide'; end if;
  select * into e from events where id = p_event and status = 'published' for update;
  if e.id is null then raise exception 'Événement introuvable'; end if;
  if e.starts_at < now() then raise exception 'Événement terminé'; end if;
  if e.price is null or e.price <= 0 then raise exception 'Cet événement est gratuit : utilisez l''inscription simple'; end if;
  select * into g from event_registrations where event_id = e.id and user_id = auth.uid() for update;
  if found then
    if g.status = 'confirmed' then raise exception 'Vous êtes déjà inscrit(e) à cet événement'; end if;
    select * into t from payment_transactions where id = g.payment_id;
    if found and t.status in ('created', 'failed', 'pending') and (g.hold_expires_at > now() or t.status = 'pending')
       and (t.status = 'pending' or t.provider = p_provider) then
      v_until := g.hold_expires_at;
      if t.status <> 'pending' then
        v_until := now() + interval '30 minutes';
        update event_registrations set hold_expires_at = v_until where event_id = e.id and user_id = auth.uid();
      end if;
      return jsonb_build_object('id', t.id, 'reference', t.reference, 'amount', t.amount, 'title', e.title, 'provider', t.provider,
                                'status', t.status, 'hold_expires_at', v_until, 'resumed', true);
    end if;
    perform _event_drop_hold(e.id, auth.uid(), 'Réservation remplacée ou expirée');
  end if;
  if e.capacity is not null and _event_taken(e.id) >= e.capacity then raise exception 'Plus de places'; end if;
  v_id := payment_start('event', 'evt:' || e.id, e.price, p_provider);
  v_until := now() + interval '30 minutes';
  insert into event_registrations (event_id, user_id, status, payment_id, hold_expires_at, amount_due)
    values (e.id, auth.uid(), 'pending_payment', v_id, v_until, e.price);
  select reference into v_ref from payment_transactions where id = v_id;
  return jsonb_build_object('id', v_id, 'reference', v_ref, 'amount', e.price, 'title', e.title, 'provider', p_provider,
                            'status', 'created', 'hold_expires_at', v_until, 'resumed', false);
end $$;
revoke all on function event_checkout(uuid, text) from public, anon;
grant execute on function event_checkout(uuid, text) to authenticated;

-- Paiement confirmé (webhook Tara ou finance) -> inscription validée, notifications, reçu. Une seule fois par transaction.
create or replace function on_event_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare e events; g event_registrations%rowtype; v_num text; v_ok boolean := false; v_why text;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'event' and new.subject like 'evt:%' then
    select * into e from events where id::text = substr(new.subject, 5) for update;
    if not found then return null; end if;
    select * into g from event_registrations where event_id = e.id and user_id = new.payer_id for update;
    if found and g.status = 'confirmed' then
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
drop trigger if exists trg_event_paid on payment_transactions;
create trigger trg_event_paid after update of status on payment_transactions for each row execute function on_event_paid();

-- Mes reçus d'événements.
create or replace function my_event_receipts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('number', r.number, 'title', r.title, 'amount', r.amount, 'reference', r.reference, 'event', r.event_id, 'created_at', r.created_at) order by r.created_at desc)
                   from (select * from event_receipts where user_id = auth.uid() order by created_at desc limit 50) r), '[]'::jsonb);
end $$;
revoke all on function my_event_receipts() from public, anon;
grant execute on function my_event_receipts() to authenticated;
