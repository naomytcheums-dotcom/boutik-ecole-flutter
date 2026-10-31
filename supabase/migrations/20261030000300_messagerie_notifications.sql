-- Messagerie persistante et notifications réelles. À exécuter dans l'éditeur SQL Supabase.
-- Retour arrière : drop table notifications, messages, conversation_participants, conversations cascade; (+ fonctions listées en fin de fichier).

create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references listings(id) on delete set null,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create table if not exists conversation_participants (
  conversation_id uuid not null references conversations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create table if not exists messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists messages_conv_idx on messages (conversation_id, created_at);
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  data jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on notifications (user_id, created_at desc);

alter table conversations enable row level security;
alter table conversation_participants enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;
revoke all on conversations, conversation_participants, messages, notifications from anon, authenticated;
grant select on conversations, conversation_participants, messages, notifications to authenticated;
grant insert on messages to authenticated;
grant update (last_read_at) on conversation_participants to authenticated;   -- seule la date de lecture est modifiable
grant update (read_at) on notifications to authenticated;                    -- seule la lecture est modifiable

create or replace function is_participant(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from conversation_participants where conversation_id = cid and user_id = auth.uid())
$$;

drop policy if exists "conversations : participants" on conversations;
create policy "conversations : participants" on conversations for select using (is_participant(id));
drop policy if exists "participants : ceux de mes conversations" on conversation_participants;
create policy "participants : ceux de mes conversations" on conversation_participants for select using (user_id = auth.uid() or is_participant(conversation_id));
drop policy if exists "participants : ma date de lecture" on conversation_participants;
create policy "participants : ma date de lecture" on conversation_participants for update using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "messages : lecture par les participants" on messages;
create policy "messages : lecture par les participants" on messages for select using (is_participant(conversation_id));
drop policy if exists "messages : envoi par un participant" on messages;
create policy "messages : envoi par un participant" on messages for insert with check (sender_id = auth.uid() and is_participant(conversation_id));
drop policy if exists "notifications : les miennes" on notifications;
create policy "notifications : les miennes" on notifications for select using (user_id = auth.uid());
drop policy if exists "notifications : marquer les miennes comme lues" on notifications;
create policy "notifications : marquer les miennes comme lues" on notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Démarrer (ou retrouver) la conversation avec le vendeur d'une annonce, avec un premier message.
create or replace function start_conversation(p_listing uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found then raise exception 'Annonce introuvable'; end if;
  if l.seller_id is null then raise exception 'Annonce de la plateforme : contactez le support'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  select c.id into cid from conversations c
    where c.listing_id = l.id
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = l.seller_id)
    limit 1;
  if cid is null then
    insert into conversations (listing_id, created_by) values (l.id, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id) values (cid, auth.uid()), (cid, l.seller_id);
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;
revoke all on function start_conversation(uuid, text) from public, anon;
grant execute on function start_conversation(uuid, text) to authenticated;

-- Un nouveau message met à jour la conversation et notifie les autres participants.
create or replace function on_message_inserted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update conversations set last_message_at = new.created_at where id = new.conversation_id;
  update conversation_participants set last_read_at = new.created_at where conversation_id = new.conversation_id and user_id = new.sender_id;
  insert into notifications (user_id, kind, title, body, data)
    select p.user_id, 'message', 'Nouveau message', left(new.body, 120), jsonb_build_object('conversation_id', new.conversation_id)
    from conversation_participants p where p.conversation_id = new.conversation_id and p.user_id <> new.sender_id;
  return null;
end $$;
drop trigger if exists trg_message_inserted on messages;
create trigger trg_message_inserted after insert on messages for each row execute function on_message_inserted();

-- Décision du département sur une annonce : le vendeur est notifié.
create or replace function on_listing_decided() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.seller_id is not null and new.status is distinct from old.status and new.status in ('approved', 'rejected') then
    insert into notifications (user_id, kind, title, body, data)
    values (new.seller_id, 'listing', case when new.status = 'approved' then 'Annonce validée' else 'Annonce refusée' end,
            case when new.status = 'approved' then '« ' || new.title || ' » est publiée.' else '« ' || new.title || ' » a été refusée' || coalesce(' : ' || new.review_note, '.') end,
            jsonb_build_object('listing_id', new.id, 'status', new.status));
  end if;
  return null;
end $$;
drop trigger if exists trg_listing_decided on listings;
create trigger trg_listing_decided after update on listings for each row execute function on_listing_decided();

-- Paiement confirmé : l'acheteur et les vendeurs concernés sont notifiés.
create or replace function on_order_paid() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.paid and not old.paid then
    insert into notifications (user_id, kind, title, body, data)
    values (new.buyer_id, 'order', 'Paiement confirmé', 'Votre commande ' || new.number || ' est payée.', jsonb_build_object('order_number', new.number));
    insert into notifications (user_id, kind, title, body, data)
    select distinct l.seller_id, 'order', 'Nouvelle commande', 'Commande ' || new.number || ' à préparer.', jsonb_build_object('order_number', new.number)
    from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = new.id and l.seller_id is not null;
  end if;
  return null;
end $$;
drop trigger if exists trg_order_paid on orders;
create trigger trg_order_paid after update on orders for each row execute function on_order_paid();

-- Compteurs de non-lus et lecture.
create or replace function unread_counts() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'notifications', (select count(*) from notifications where user_id = auth.uid() and read_at is null),
    'messages', (select count(*) from messages m join conversation_participants p on p.conversation_id = m.conversation_id and p.user_id = auth.uid()
                  where m.sender_id <> auth.uid() and m.created_at > p.last_read_at))
$$;
revoke all on function unread_counts() from public, anon;
grant execute on function unread_counts() to authenticated;

create or replace function mark_conversation_read(cid uuid) returns void
language sql security definer set search_path = public as $$
  update conversation_participants set last_read_at = now() where conversation_id = cid and user_id = auth.uid()
$$;
revoke all on function mark_conversation_read(uuid) from public, anon;
grant execute on function mark_conversation_read(uuid) to authenticated;

create or replace function mark_notifications_read() returns void
language sql security definer set search_path = public as $$
  update notifications set read_at = now() where user_id = auth.uid() and read_at is null
$$;
revoke all on function mark_notifications_read() from public, anon;
grant execute on function mark_notifications_read() to authenticated;

select (select count(*) from pg_tables where tablename in ('conversations', 'conversation_participants', 'messages', 'notifications')) as tables_creees,
       (select count(*) from pg_trigger where tgname in ('trg_message_inserted', 'trg_listing_decided', 'trg_order_paid')) as declencheurs;
