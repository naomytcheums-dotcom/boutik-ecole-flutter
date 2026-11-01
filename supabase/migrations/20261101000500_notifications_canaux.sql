-- Notifications multicanal (phase 3) : architecture commune, SANS AUCUN ENVOI.
-- Chaque notification de l'application (table notifications) est mise en file pour les canaux push, e-mail et SMS
-- selon les préférences et le consentement de l'utilisateur. Un répartiteur (Edge Function, à écrire quand les
-- fournisseurs seront choisis) lira la file ; tant qu'il n'existe pas, les lignes restent « en attente » : rien ne part.
-- Aucune donnée existante n'est modifiée.

create table if not exists notification_preferences (
  user_id uuid not null references profiles(id) on delete cascade,
  channel text not null check (channel in ('push', 'email', 'sms')),
  kind text not null default '*' check (char_length(kind) between 1 and 40),
  enabled boolean not null,
  consent_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, channel, kind)
);

create table if not exists device_tokens (
  token text primary key check (char_length(token) between 20 and 4096),
  user_id uuid not null references profiles(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index if not exists device_tokens_user on device_tokens (user_id);

create table if not exists notification_outbox (
  id bigint generated always as identity primary key,
  notification_id uuid,
  user_id uuid not null references profiles(id) on delete cascade,
  channel text not null check (channel in ('push', 'email', 'sms')),
  kind text not null,
  title text not null,
  body text,
  status text not null default 'queued' check (status in ('queued', 'sent', 'failed', 'skipped')),
  attempts smallint not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index if not exists notification_outbox_file on notification_outbox (status, created_at);

alter table notification_preferences enable row level security;
alter table device_tokens enable row level security;
alter table notification_outbox enable row level security;
revoke all on notification_preferences, device_tokens, notification_outbox from anon, authenticated;
grant select on notification_preferences, device_tokens to authenticated;
grant select on notification_outbox to authenticated;
drop policy if exists "préférences : titulaire" on notification_preferences;
create policy "préférences : titulaire" on notification_preferences for select using (user_id = auth.uid());
drop policy if exists "appareils : titulaire" on device_tokens;
create policy "appareils : titulaire" on device_tokens for select using (user_id = auth.uid());
drop policy if exists "file : titulaire et administration" on notification_outbox;
create policy "file : titulaire et administration" on notification_outbox for select
  using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'support'));

-- Consentement explicite par canal (SMS et e-mail : opt-in ; push : activé à l'enregistrement d'un appareil)
create or replace function set_notification_preference(p_channel text, p_kind text, p_enabled boolean) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_channel not in ('push', 'email', 'sms') then raise exception 'Canal inconnu'; end if;
  insert into notification_preferences (user_id, channel, kind, enabled, consent_at, updated_at)
    values (auth.uid(), p_channel, coalesce(nullif(trim(p_kind), ''), '*'), p_enabled, case when p_enabled then now() end, now())
  on conflict (user_id, channel, kind) do update set enabled = excluded.enabled,
    consent_at = case when excluded.enabled then coalesce(notification_preferences.consent_at, now()) else null end, updated_at = now();
  return case when p_enabled then 'enabled' else 'disabled' end;
end $$;

create or replace function register_device(p_token text, p_platform text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  insert into device_tokens (token, user_id, platform) values (p_token, auth.uid(), p_platform)
  on conflict (token) do update set user_id = auth.uid(), platform = excluded.platform, last_seen_at = now();
  return 'registered';
end $$;

create or replace function unregister_device(p_token text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from device_tokens where token = p_token and user_id = auth.uid();
  return 'unregistered';
end $$;

-- Mise en file : push si un appareil est enregistré et non refusé ; e-mail et SMS seulement avec consentement explicite
create or replace function enqueue_notification() returns trigger
language plpgsql security definer set search_path = public as $$
declare ch text; ok boolean;
begin
  foreach ch in array array['push', 'email', 'sms'] loop
    select enabled into ok from notification_preferences
      where user_id = new.user_id and channel = ch and kind in (new.kind, '*')
      order by (kind = new.kind) desc limit 1;
    if ch = 'push' then
      ok := coalesce(ok, true) and exists (select 1 from device_tokens where user_id = new.user_id);
    else
      ok := coalesce(ok, false);
    end if;
    if ok then
      insert into notification_outbox (notification_id, user_id, channel, kind, title, body)
        values (new.id, new.user_id, ch, new.kind, new.title, left(new.body, 500));
    end if;
  end loop;
  return null;
end $$;
drop trigger if exists trg_enqueue_notification on notifications;
create trigger trg_enqueue_notification after insert on notifications for each row execute function enqueue_notification();

revoke all on function set_notification_preference(text, text, boolean), register_device(text, text), unregister_device(text) from public, anon;
grant execute on function set_notification_preference(text, text, boolean), register_device(text, text), unregister_device(text) to authenticated;
revoke execute on function enqueue_notification() from public, anon, authenticated;

-- Retour arrière (manuel) : drop trigger trg_enqueue_notification on notifications;
-- drop function enqueue_notification(), unregister_device(text), register_device(text, text), set_notification_preference(text, text, boolean);
-- drop table notification_outbox, device_tokens, notification_preferences;
