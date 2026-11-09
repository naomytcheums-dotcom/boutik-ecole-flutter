-- Messagerie (blocage, signalement), assistante Kéla (limite d'usage), notifications réelles (file d'envoi e-mail / SMS / WhatsApp / push, abonnements push).
-- Aucun message n'est envoyé par la base : elle met en file ; la fonction Edge « dispatch-notifications » envoie quand les clés des services sont posées.
-- Un canal n'est utilisé que si la personne a ENREGISTRÉ ses préférences de canaux (jamais selon les valeurs affichées par défaut) et a une coordonnée valide.
-- Retour arrière : voir la fin du fichier.

-- ============================================================ blocage et signalement dans la messagerie
create table if not exists user_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create table if not exists message_reports (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (char_length(reason) between 3 and 500),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  unique (conversation_id, reporter_id)
);
alter table user_blocks enable row level security;
alter table message_reports enable row level security;
revoke all on user_blocks, message_reports from anon, authenticated;
grant select on user_blocks, message_reports to authenticated;
drop policy if exists "blocages : les miens" on user_blocks;
create policy "blocages : les miens" on user_blocks for select using (blocker_id = auth.uid());
drop policy if exists "signalements de conversation : auteur et modération" on message_reports;
create policy "signalements de conversation : auteur et modération" on message_reports for select
  using (reporter_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'support', 'dept'));

create or replace function block_user(p_user uuid, p_block boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_user = auth.uid() then raise exception 'Action impossible sur votre propre compte'; end if;
  if p_block then
    insert into user_blocks (blocker_id, blocked_id) values (auth.uid(), p_user) on conflict do nothing;
  else
    delete from user_blocks where blocker_id = auth.uid() and blocked_id = p_user;
  end if;
end $$;

create or replace function is_blocked_between(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from user_blocks where (blocker_id = p_a and blocked_id = p_b) or (blocker_id = p_b and blocked_id = p_a))
$$;

create or replace function report_conversation(p_conversation uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_participant(p_conversation) then raise exception 'Conversation introuvable'; end if;
  if p_reason is null or char_length(trim(p_reason)) < 3 then raise exception 'Motif trop court'; end if;
  insert into message_reports (conversation_id, reporter_id, reason) values (p_conversation, auth.uid(), left(trim(p_reason), 500))
  on conflict (conversation_id, reporter_id) do update set reason = excluded.reason, status = 'open';
end $$;

-- L'envoi est refusé si l'un des participants a bloqué l'autre.
drop policy if exists "messages : envoi par un participant" on messages;
create policy "messages : envoi par un participant" on messages for insert
  with check (sender_id = auth.uid() and is_participant(conversation_id)
              and not exists (select 1 from conversation_participants p where p.conversation_id = messages.conversation_id and p.user_id <> auth.uid() and is_blocked_between(p.user_id, auth.uid())));

-- ============================================================ assistante Kéla : limite d'usage (la clé de l'IA reste un secret de la fonction Edge)
create table if not exists kela_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists kela_usage_user on kela_usage (user_id, created_at desc);
alter table kela_usage enable row level security;
revoke all on kela_usage from anon, authenticated;

-- ============================================================ notifications réelles : WhatsApp ajouté à l'architecture existante (migration 20261101000500)
alter table notification_preferences drop constraint if exists notification_preferences_channel_check;
alter table notification_preferences add constraint notification_preferences_channel_check check (channel in ('push', 'email', 'sms', 'whatsapp'));
alter table notification_outbox drop constraint if exists notification_outbox_channel_check;
alter table notification_outbox add constraint notification_outbox_channel_check check (channel in ('push', 'email', 'sms', 'whatsapp'));

create or replace function set_notification_preference(p_channel text, p_kind text, p_enabled boolean) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_channel not in ('push', 'email', 'sms', 'whatsapp') then raise exception 'Canal inconnu'; end if;
  insert into notification_preferences (user_id, channel, kind, enabled, consent_at, updated_at)
    values (auth.uid(), p_channel, coalesce(nullif(trim(p_kind), ''), '*'), p_enabled, case when p_enabled then now() end, now())
  on conflict (user_id, channel, kind) do update set enabled = excluded.enabled,
    consent_at = case when excluded.enabled then coalesce(notification_preferences.consent_at, now()) else notification_preferences.consent_at end, updated_at = now();
  return case when p_enabled then 'enabled' else 'disabled' end;
end $$;

-- Mise en file : push si un appareil est enregistré et non refusé ; e-mail, SMS et WhatsApp seulement avec consentement explicite ET coordonnée valide.
create or replace function enqueue_notification() returns trigger
language plpgsql security definer set search_path = public as $$
declare ch text; ok boolean; pr profiles%rowtype;
begin
  select * into pr from profiles where id = new.user_id;
  foreach ch in array array['push', 'email', 'sms', 'whatsapp'] loop
    select enabled into ok from notification_preferences
      where user_id = new.user_id and channel = ch and kind in (new.kind, '*')
      order by (kind = new.kind) desc limit 1;
    if ch = 'push' then
      ok := coalesce(ok, true) and exists (select 1 from device_tokens where user_id = new.user_id);
    elsif ch = 'email' then
      ok := coalesce(ok, false) and coalesce(pr.email, '') ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';
    else
      ok := coalesce(ok, false) and coalesce(pr.phone, '') ~ '^\+?[0-9 ]{8,20}$';
    end if;
    if ok then
      insert into notification_outbox (notification_id, user_id, channel, kind, title, body)
        values (new.id, new.user_id, ch, new.kind, new.title, left(new.body, 500));
    end if;
  end loop;
  return null;
end $$;

-- Envoi planifié : chaque minute, la fonction Edge traite la file (elle n'accepte aucune entrée : elle n'envoie que ce qui est en file).
do $$ begin
  create extension if not exists pg_net;
  create extension if not exists pg_cron;
  perform cron.unschedule('dispatch-notifications') where exists (select 1 from cron.job where jobname = 'dispatch-notifications');
  perform cron.schedule('dispatch-notifications', '* * * * *', $cron$select net.http_post(url := 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/dispatch-notifications', body := '{}'::jsonb)$cron$);
exception when others then
  raise notice 'Planification non installée (extensions indisponibles) : %', sqlerrm;
end $$;

revoke all on function block_user(uuid, boolean), report_conversation(uuid, text), set_notification_preference(text, text, boolean) from public, anon;
grant execute on function block_user(uuid, boolean), report_conversation(uuid, text), set_notification_preference(text, text, boolean) to authenticated;
revoke all on function enqueue_notification() from public, anon, authenticated;
-- appelée par la règle d'envoi des messages (comme is_participant) : doit rester exécutable par les comptes connectés
revoke all on function is_blocked_between(uuid, uuid) from public, anon;
grant execute on function is_blocked_between(uuid, uuid) to authenticated;

-- RETOUR ARRIÈRE : select cron.unschedule('dispatch-notifications'); drop function is_blocked_between(uuid, uuid), block_user(uuid, boolean), report_conversation(uuid, text);
--   drop table kela_usage, message_reports, user_blocks;  (remettre les contraintes de canal et enqueue_notification de 20261101000500)  (puis recréer la politique « messages : envoi par un participant » de 20261030000300)
