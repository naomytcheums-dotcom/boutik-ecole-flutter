-- Lot L6 (profil Client) : aide et support réels, notifications (lecture individuelle, catégories, canaux, numéro WhatsApp, appareils),
-- messagerie (non-lus, signalements lisibles par le support, pièces jointes), événements (inscription, rappels), département, vitrine.
-- Aucune donnée existante n'est modifiée ni supprimée. Retour arrière : voir le bas du fichier.
-- Objets réservés (non redéfinis ici) : start_conversation, start_order_conversation, start_direct_conversation, is_blocked_between,
-- dispatch-notifications, tâches pg_cron.

-- ============================================================ 1. Support : tickets réels
create table if not exists support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  subject text not null check (char_length(subject) between 3 and 120),
  message text not null check (char_length(message) between 10 and 2000),
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  reply text check (reply is null or char_length(reply) <= 2000),
  replied_by uuid references profiles(id) on delete set null,
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists support_tickets_user on support_tickets (user_id, created_at desc);
create index if not exists support_tickets_status on support_tickets (status, created_at);
alter table support_tickets enable row level security;
revoke all on support_tickets from anon, authenticated;
grant select on support_tickets to authenticated;
drop policy if exists "demandes d'aide : les miennes et le support" on support_tickets;
create policy "demandes d'aide : les miennes et le support" on support_tickets for select
  using (user_id = auth.uid() or is_platform_staff());

-- Création : 5 demandes par 24 h au plus ; les comptes support et administrateur sont notifiés.
create or replace function support_ticket_create(p_subject text, p_message text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record; v_subject text := btrim(coalesce(p_subject, '')); v_msg text := btrim(coalesce(p_message, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_subject) < 3 or char_length(v_subject) > 120 then raise exception 'Le sujet doit comporter de 3 à 120 caractères'; end if;
  if char_length(v_msg) < 10 then raise exception 'Décrivez votre demande en au moins 10 caractères'; end if;
  if char_length(v_msg) > 2000 then raise exception 'Votre message est trop long (2000 caractères maximum)'; end if;
  if (select count(*) from support_tickets where user_id = auth.uid() and created_at > now() - interval '24 hours') >= 5 then
    raise exception 'Limite atteinte : 5 demandes par jour. Réessayez demain.';
  end if;
  insert into support_tickets (user_id, subject, message) values (auth.uid(), v_subject, v_msg) returning id into v_id;
  for r in select id from profiles where role::text in ('admin', 'support') and not coalesce(suspended, false) loop
    perform notify_user(r.id, 'support_ticket', 'Nouvelle demande d''aide', display_name(auth.uid()) || ' : ' || v_subject, jsonb_build_object('ticket', v_id));
  end loop;
  return v_id;
end $$;

-- Réponse du support (lisible par la personne dans « Mes demandes », avec une notification).
create or replace function support_ticket_reply(p_id uuid, p_reply text) returns void
language plpgsql security definer set search_path = public as $$
declare t support_tickets;
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_reply is null or char_length(btrim(p_reply)) < 2 or char_length(p_reply) > 2000 then raise exception 'Réponse invalide (2 à 2000 caractères)'; end if;
  select * into t from support_tickets where id = p_id;
  if t.id is null then raise exception 'Demande introuvable'; end if;
  update support_tickets set reply = btrim(p_reply), status = 'answered', replied_by = auth.uid(), replied_at = now() where id = p_id;
  insert into notifications (user_id, kind, title, body, data)
    values (t.user_id, 'support', 'Le support a répondu', left(t.subject || ' : ' || btrim(p_reply), 500), jsonb_build_object('ticket', t.id));
end $$;

-- Clôture : par la personne elle-même ou par le support.
create or replace function support_ticket_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update support_tickets set status = 'closed' where id = p_id and (user_id = auth.uid() or is_platform_staff());
  if not found then raise exception 'Demande introuvable'; end if;
end $$;

revoke all on function support_ticket_create(text, text), support_ticket_reply(uuid, text), support_ticket_close(uuid) from public, anon;
grant execute on function support_ticket_create(text, text), support_ticket_reply(uuid, text), support_ticket_close(uuid) to authenticated;

-- ============================================================ 2. Notifications : lecture individuelle, catégories
create or replace function mark_notification_read(p_id uuid) returns void
language sql security definer set search_path = public as $$
  update notifications set read_at = now() where id = p_id and user_id = auth.uid() and read_at is null
$$;
revoke all on function mark_notification_read(uuid) from public, anon;
grant execute on function mark_notification_read(uuid) to authenticated;

-- Catégorie d'un type de notification (réglages de l'écran 56 et filtres de l'écran 50).
create or replace function notification_category(p_kind text) returns text
language sql immutable set search_path = public as $$
  select case
    when p_kind in ('order', 'payment', 'claim', 'dispute', 'money', 'quote') then 'orders'
    when p_kind in ('message', 'teammate_message') then 'messages'
    when p_kind in ('review', 'company_review', 'question') then 'reviews'
    when p_kind in ('alert', 'campaign', 'ads', 'opportunity_alert') then 'promotions'
    else 'other' end
$$;

-- Le canal « inapp » enregistre les catégories (cat:orders, cat:messages, cat:promotions, cat:reviews) que la personne ne veut plus recevoir.
alter table notification_preferences drop constraint if exists notification_preferences_channel_check;
alter table notification_preferences add constraint notification_preferences_channel_check check (channel in ('push', 'email', 'sms', 'whatsapp', 'inapp'));

create or replace function notification_filter() returns trigger
language plpgsql security definer set search_path = public as $$
declare cat text := notification_category(new.kind);
begin
  if cat <> 'other' and exists (select 1 from notification_preferences
       where user_id = new.user_id and channel = 'inapp' and kind = 'cat:' || cat and not enabled) then
    return null;
  end if;
  return new;
end $$;
drop trigger if exists trg_notification_filter on notifications;
create trigger trg_notification_filter before insert on notifications for each row execute function notification_filter();

-- ============================================================ 3. Numéro WhatsApp et adresses d'envoi
-- Numéro normalisé au format international (+237…), ou null s'il est invalide.
create or replace function normalize_msisdn(p text) returns text
language sql immutable set search_path = public as $$
  with c as (select regexp_replace(coalesce(p, ''), '[\s.\-()]', '', 'g') as v)
  select case
    when v ~ '^\+[1-9][0-9]{7,14}$' then v
    when v ~ '^00[1-9][0-9]{7,14}$' then '+' || substr(v, 3)
    when v ~ '^2376[0-9]{8}$' then '+' || v
    when v ~ '^6[0-9]{8}$' then '+237' || v
    else null end
  from c
$$;

create table if not exists notification_contacts (
  user_id uuid primary key references profiles(id) on delete cascade,
  whatsapp_number text not null check (whatsapp_number ~ '^\+[1-9][0-9]{7,14}$'),
  updated_at timestamptz not null default now()
);
alter table notification_contacts enable row level security;
revoke all on notification_contacts from anon, authenticated;
grant select on notification_contacts to authenticated;
drop policy if exists "contacts de notification : titulaire" on notification_contacts;
create policy "contacts de notification : titulaire" on notification_contacts for select using (user_id = auth.uid());

-- Enregistre (ou efface, si vide) le numéro WhatsApp utilisé pour les envois ; renvoie le numéro normalisé.
create or replace function set_whatsapp_number(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if nullif(btrim(coalesce(p_number, '')), '') is null then
    delete from notification_contacts where user_id = auth.uid();
    return '';
  end if;
  v := normalize_msisdn(p_number);
  if v is null then raise exception 'Numéro WhatsApp invalide : utilisez le format +237 6XX XX XX XX'; end if;
  insert into notification_contacts (user_id, whatsapp_number) values (auth.uid(), v)
  on conflict (user_id) do update set whatsapp_number = excluded.whatsapp_number, updated_at = now();
  return v;
end $$;
revoke all on function set_whatsapp_number(text) from public, anon;
grant execute on function set_whatsapp_number(text) to authenticated;

-- Adresse de destination du message : le répartiteur l'utilise en priorité (colonne to_address), sinon la coordonnée du profil.
alter table notification_outbox add column if not exists to_address text;

-- Un canal d'envoi (e-mail, SMS, WhatsApp) exige un consentement explicite ET une coordonnée valide ; l'application de messagerie
-- (notifications 'message') n'est plus envoyée par SMS, WhatsApp ni e-mail sauf choix explicite de la personne pour ce type.
create or replace function set_notification_preference(p_channel text, p_kind text, p_enabled boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_kind text := coalesce(nullif(trim(p_kind), ''), '*'); pr profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_channel not in ('push', 'email', 'sms', 'whatsapp', 'inapp') then raise exception 'Canal inconnu'; end if;
  if p_channel = 'inapp' and v_kind not in ('cat:orders', 'cat:messages', 'cat:promotions', 'cat:reviews') then raise exception 'Catégorie inconnue'; end if;
  if p_enabled and p_channel in ('email', 'sms', 'whatsapp') then
    select * into pr from profiles where id = auth.uid();
    if p_channel = 'email' and coalesce(pr.email, '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Aucune adresse e-mail valide enregistrée'; end if;
    if p_channel = 'sms' and normalize_msisdn(pr.phone) is null then raise exception 'Aucun numéro de téléphone valide enregistré : ajoutez-le à votre profil'; end if;
    if p_channel = 'whatsapp' and normalize_msisdn(coalesce((select whatsapp_number from notification_contacts where user_id = auth.uid()), pr.phone)) is null then
      raise exception 'Aucun numéro WhatsApp valide enregistré : saisissez-le avant d''activer ce canal';
    end if;
  end if;
  insert into notification_preferences (user_id, channel, kind, enabled, consent_at, updated_at)
    values (auth.uid(), p_channel, v_kind, p_enabled, case when p_enabled and p_channel <> 'inapp' then now() end, now())
  on conflict (user_id, channel, kind) do update set enabled = excluded.enabled,
    consent_at = case when excluded.enabled and notification_preferences.channel <> 'inapp' then coalesce(notification_preferences.consent_at, now()) else notification_preferences.consent_at end, updated_at = now();
  return case when p_enabled then 'enabled' else 'disabled' end;
end $$;
revoke all on function set_notification_preference(text, text, boolean) from public, anon;
grant execute on function set_notification_preference(text, text, boolean) to authenticated;

create or replace function enqueue_notification() returns trigger
language plpgsql security definer set search_path = public as $$
declare ch text; ok boolean; v_explicit boolean; v_star boolean; pr profiles%rowtype; addr text; wa text;
  important boolean := new.kind in ('order', 'payment', 'claim', 'dispute', 'quote', 'money', 'mission', 'listing', 'support');
begin
  select * into pr from profiles where id = new.user_id;
  select whatsapp_number into wa from notification_contacts where user_id = new.user_id;
  foreach ch in array array['push', 'email', 'sms', 'whatsapp'] loop
    select enabled into v_explicit from notification_preferences where user_id = new.user_id and channel = ch and kind = new.kind;
    select enabled into v_star from notification_preferences where user_id = new.user_id and channel = ch and kind = '*';
    addr := null;
    if ch = 'push' then
      ok := coalesce(v_explicit, v_star, true) and exists (select 1 from device_tokens where user_id = new.user_id);
    else
      ok := coalesce(v_explicit, case when important then v_star end, false);
      if ch = 'email' then
        addr := case when coalesce(pr.email, '') ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then pr.email end;
      elsif ch = 'sms' then
        addr := normalize_msisdn(pr.phone);
      else
        addr := normalize_msisdn(coalesce(wa, pr.phone));
      end if;
      ok := ok and addr is not null;
    end if;
    if ok then
      insert into notification_outbox (notification_id, user_id, channel, kind, title, body, to_address)
        values (new.id, new.user_id, ch, new.kind, new.title, left(new.body, 500), addr);
    end if;
  end loop;
  return null;
end $$;
revoke execute on function enqueue_notification() from public, anon, authenticated;

-- ============================================================ 4. Appareils : seuls les services de notification connus sont acceptés
create or replace function register_device(p_token text, p_platform text) returns text
language plpgsql security definer set search_path = public as $$
declare v_ep text; v_host text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_platform not in ('android', 'ios', 'web') then raise exception 'Plateforme inconnue'; end if;
  if p_token is null or char_length(p_token) not between 20 and 4096 then raise exception 'Jeton d''appareil invalide'; end if;
  if p_platform = 'web' then
    begin
      v_ep := (p_token::jsonb) ->> 'endpoint';
    exception when others then
      v_ep := null;
    end;
    v_host := lower(substring(coalesce(v_ep, '') from '^https://([^/:?#@]+)(:[0-9]+)?/'));
    if v_host is null or not (v_host = 'fcm.googleapis.com' or v_host = 'updates.push.services.mozilla.com' or v_host like '%.push.services.mozilla.com'
        or v_host like '%.notify.windows.com' or v_host = 'web.push.apple.com' or v_host like '%.push.apple.com') then
      raise exception 'Service de notifications du navigateur non reconnu';
    end if;
  end if;
  insert into device_tokens (token, user_id, platform) values (p_token, auth.uid(), p_platform)
  on conflict (token) do update set user_id = auth.uid(), platform = excluded.platform, last_seen_at = now();
  return 'registered';
end $$;
revoke all on function register_device(text, text) from public, anon;
grant execute on function register_device(text, text) to authenticated;

-- ============================================================ 5. Messagerie : non-lus, pièces jointes, signalements
-- Le premier message d'une conversation créée dans la même transaction que ses participants porte la même date que leur lecture : il compte comme non lu.
create or replace function unread_counts() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'notifications', (select count(*) from notifications where user_id = auth.uid() and read_at is null),
    'messages', (select count(*) from messages m join conversation_participants p on p.conversation_id = m.conversation_id and p.user_id = auth.uid()
                  where m.sender_id <> auth.uid() and m.created_at >= p.last_read_at))
$$;
revoke all on function unread_counts() from public, anon;
grant execute on function unread_counts() to authenticated;

create or replace function my_conversations()
returns table (id uuid, listing_title text, other_name text, last_body text, last_at timestamptz, unread integer, order_number text)
language sql stable security definer set search_path = public as $$
  select c.id, l.title, coalesce(op.name, 'Utilisateur'),
         (select case when m.kind = 'text' then m.body when m.kind = 'image' then 'Photo' when m.kind = 'voice' then 'Message vocal' else 'Fichier : ' || coalesce(m.attachment_name, '') end
            from messages m where m.conversation_id = c.id order by m.id desc limit 1),
         c.last_message_at,
         (select count(*)::int from messages m where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.created_at >= p.last_read_at),
         c.order_number
  from conversations c
  join conversation_participants p on p.conversation_id = c.id and p.user_id = auth.uid()
  left join listings l on l.id = c.listing_id
  left join conversation_participants q on q.conversation_id = c.id and q.user_id <> auth.uid()
  left join profiles op on op.id = q.user_id
  order by c.last_message_at desc
$$;
revoke all on function my_conversations() from public, anon;
grant execute on function my_conversations() to authenticated;

-- Envoi : participant, sans blocage entre les deux personnes, pièce jointe dans le dossier de LA conversation.
drop policy if exists "messages : envoi par un participant" on messages;
create policy "messages : envoi par un participant" on messages for insert
  with check (sender_id = auth.uid() and is_participant(conversation_id)
              and (attachment_path is null or attachment_path like conversation_id::text || '/%')
              and not exists (select 1 from conversation_participants p where p.conversation_id = messages.conversation_id and p.user_id <> auth.uid() and is_blocked_between(p.user_id, auth.uid())));

-- Signalement d'une conversation : le support et les administrateurs sont notifiés.
create or replace function report_conversation(p_conversation uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_participant(p_conversation) then raise exception 'Conversation introuvable'; end if;
  if p_reason is null or char_length(trim(p_reason)) < 3 then raise exception 'Motif trop court'; end if;
  insert into message_reports (conversation_id, reporter_id, reason) values (p_conversation, auth.uid(), left(trim(p_reason), 500))
  on conflict (conversation_id, reporter_id) do update set reason = excluded.reason, status = 'open'
  returning id into v_id;
  for r in select id from profiles where role::text in ('admin', 'support') and not coalesce(suspended, false) loop
    perform notify_user(r.id, 'message_report', 'Conversation signalée', display_name(auth.uid()) || ' : ' || left(trim(p_reason), 200), jsonb_build_object('report', v_id, 'conversation', p_conversation));
  end loop;
end $$;
revoke all on function report_conversation(uuid, text) from public, anon;
grant execute on function report_conversation(uuid, text) to authenticated;

-- Lecture des signalements par le support et les administrateurs, avec les 10 derniers messages de la conversation signalée.
create or replace function message_reports_list(p_status text default 'open', p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', x.id, 'conversation', x.conversation_id, 'reason', x.reason, 'status', x.status, 'created_at', x.created_at,
      'reporter', (select name from profiles where id = x.reporter_id),
      'messages', coalesce((select jsonb_agg(jsonb_build_object('sender', (select name from profiles where id = m.sender_id), 'kind', m.kind, 'body', m.body, 'at', m.created_at) order by m.id)
                            from (select * from messages where conversation_id = x.conversation_id order by id desc limit 10) m), '[]'::jsonb)
    ) order by x.created_at desc)
    from (select * from message_reports where (nullif(p_status, '') is null or status = p_status) order by created_at desc limit least(greatest(p_limit, 1), 200)) x
  ), '[]'::jsonb);
end $$;

create or replace function message_report_set_status(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_status not in ('open', 'closed') then raise exception 'Statut inconnu'; end if;
  update message_reports set status = p_status where id = p_id;
  if not found then raise exception 'Signalement introuvable'; end if;
end $$;
revoke all on function message_reports_list(text, integer), message_report_set_status(uuid, text) from public, anon;
grant execute on function message_reports_list(text, integer), message_report_set_status(uuid, text) to authenticated;

-- ============================================================ 6. Événements : inscription sans course, confirmation, à venir, rappels
alter table event_registrations add column if not exists reminded_at timestamptz;

create or replace function event_register(p_event uuid) returns text
language plpgsql security definer set search_path = public as $$
declare e events; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from events where id = p_event and status = 'published' for update;
  if e.id is null then raise exception 'Événement introuvable'; end if;
  if e.starts_at < now() then raise exception 'Événement terminé'; end if;
  if exists (select 1 from event_registrations where event_id = p_event and user_id = auth.uid()) then return 'already'; end if;
  select count(*) into n from event_registrations where event_id = p_event;
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

-- Événements à venir, sans limite de grille de calendrier.
create or replace function events_upcoming(p_limit integer default 30, p_kind text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'title', e.title, 'description', coalesce(e.description, ''), 'kind', e.kind, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
      'place', coalesce(e.place, ''), 'price', e.price, 'capacity', e.capacity,
      'registered', (select count(*)::int from event_registrations r where r.event_id = e.id),
      'mine', exists (select 1 from event_registrations r where r.event_id = e.id and r.user_id = auth.uid())
    ) order by e.starts_at), '[]'::jsonb)
  from (select * from events where status = 'published' and starts_at >= now() and (p_kind is null or p_kind = '' or kind = p_kind)
        order by starts_at limit least(greatest(p_limit, 1), 100)) e;
$$;
revoke all on function events_upcoming(integer, text) from public, anon;
grant execute on function events_upcoming(integer, text) to anon, authenticated;

-- Rappel la veille : à planifier (pg_cron, toutes les 15 minutes) : select public.send_event_reminders();
create or replace function send_event_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select g.user_id, e.id, e.title, e.starts_at, e.place from event_registrations g join events e on e.id = g.event_id
           where g.reminded_at is null and e.status = 'published' and e.starts_at > now() and e.starts_at <= now() + interval '24 hours' loop
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

-- ============================================================ 7. Département, vitrine
-- Fiche d'un département vérifié : établissement, effectifs réels, étudiants à la une (compétences renseignées, comptes connectés seulement).
create or replace function department_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d departments; i institutions;
begin
  select * into d from departments where id = p_id and status = 'verified';
  if d.id is null then return null; end if;
  select * into i from institutions where id = d.institution_id;
  return jsonb_build_object(
    'id', d.id, 'name', d.name, 'institution', coalesce(i.name, ''), 'institution_short', coalesce(i.short_name, ''), 'city', coalesce(i.city, ''),
    'students', (select count(*)::int from profiles p where p.department_id = d.id and p.role::text = 'student' and not coalesce(p.suspended, false)),
    'listings', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = d.id and l.status = 'approved'),
    'projects', (select count(*)::int from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.status = 'approved' and pr.visibility = 'public'),
    'featured', case when auth.uid() is null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'skills', coalesce(s.skills, ''), 'avatar_url', s.avatar_url, 'certified', s.certification::text = 'approved'))
      from (select * from profiles p where p.department_id = d.id and p.role::text = 'student' and not coalesce(p.suspended, false)
                and nullif(trim(coalesce(p.skills, '')), '') is not null
            order by (p.certification::text = 'approved') desc, p.created_at desc limit 4) s), '[]'::jsonb) end
  );
end $$;
revoke all on function department_detail(uuid) from public;
grant execute on function department_detail(uuid) to anon, authenticated;

-- Vitrine « à l'honneur » : annonces publiées les mieux notées, puis les plus consultées (seules les annonces avec au moins un avis ou une vue sont retenues).
create or replace function showcase_listings(p_limit integer default 8) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x.id order by x.score desc, x.created_at desc), '[]'::jsonb)
  from (
    select l.id, l.created_at, coalesce(rt.avg, 0) * 10 + least(coalesce(rt.n, 0), 10) + least(coalesce(v.n, 0), 50) / 10.0 as score
    from listings l
    left join lateral (select avg(r.rating) as avg, count(*) as n from reviews r where r.listing_id = l.id) rt on true
    left join lateral (select sum(lv.views) as n from listing_views lv where lv.listing_id = l.id) v on true
    where l.status = 'approved' and l.stock > 0 and not coalesce(l.showcase, false) and (coalesce(rt.n, 0) > 0 or coalesce(v.n, 0) > 0)
    order by 3 desc, l.created_at desc
    limit least(greatest(p_limit, 1), 30)
  ) x
$$;
revoke all on function showcase_listings(integer) from public;
grant execute on function showcase_listings(integer) to anon, authenticated;

-- Retour arrière (manuel) :
--   drop function if exists showcase_listings(integer), department_detail(uuid), send_event_reminders(), events_upcoming(integer, text),
--     message_report_set_status(uuid, text), message_reports_list(text, integer), set_whatsapp_number(text), normalize_msisdn(text),
--     notification_category(text), mark_notification_read(uuid), support_ticket_close(uuid), support_ticket_reply(uuid, text), support_ticket_create(text, text);
--   drop trigger if exists trg_notification_filter on notifications; drop function if exists notification_filter();
--   drop table if exists notification_contacts, support_tickets;
--   alter table notification_outbox drop column if exists to_address; alter table event_registrations drop column if exists reminded_at;
--   (rejouer ensuite les définitions précédentes de set_notification_preference, enqueue_notification, register_device : 20261106000100 et 20261101000500 ;
--    unread_counts : 20261030000300 ; my_conversations : 20261030000600 ; politique « messages : envoi par un participant » : 20261106000100 ;
--    report_conversation : 20261106000100 ; event_register : 20261105000000.)
