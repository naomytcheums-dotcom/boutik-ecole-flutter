-- Lot L10 (3/5) : ateliers en direct (écrans 222, 223, 224, V1).
-- Un seul système de lives : la table « lives » (celle de « Prochains lives » et de la régie LiveKit). « Programmer un live » (224) appelle create_live avec une date réelle ;
-- l'agenda (223) lit ces mêmes lives par lives_agenda ; les rappels sont réels (live_reminders + notification envoyée par send_live_reminders, tâche pg_cron).
-- create_live, start_live, save_live et end_live ne sont PAS redéfinis ici (lot L7).
-- Garde-fous ajoutés sans toucher ces fonctions : déclencheur de plafond quotidien sur « lives », et sur l'ancienne table scheduled_lives (compte suspendu refusé,
-- cinq programmations par jour, dix lives programmés au plus) puisque save_live peut encore y écrire tant que le lot L7 ne l'a pas retirée.
-- Retour arrière : voir le bas du fichier.

create table if not exists live_reminders (
  live_id uuid not null references lives(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  notified boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (live_id, user_id)
);
create index if not exists live_reminders_due on live_reminders (live_id) where not notified;
alter table live_reminders enable row level security;
revoke all on live_reminders from anon, authenticated;
grant select on live_reminders to authenticated;
drop policy if exists "rappels de live : les siens" on live_reminders;
create policy "rappels de live : les siens" on live_reminders for select using (user_id = auth.uid());

create or replace function lives_agenda(p_scope text default 'all', p_limit integer default 60) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); s text := coalesce(nullif(btrim(p_scope), ''), 'all');
begin
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', l.id, 'title', l.title, 'description', l.description, 'status', l.status, 'scheduled_at', l.scheduled_at, 'started_at', l.started_at,
      'host', _live_author(l.host_id), 'host_id', l.host_id, 'viewer_count', l.viewer_count,
      'remind', uid is not null and exists (select 1 from live_reminders r where r.live_id = l.id and r.user_id = uid),
      'mine', uid is not null and l.host_id = uid)
      order by (l.status = 'live') desc, l.scheduled_at asc nulls last)
    from (
      select l.* from lives l join profiles a on a.id = l.host_id and not coalesce(a.suspended, false)
      where (l.status = 'live'
          or (l.status = 'scheduled' and l.scheduled_at is not null and l.scheduled_at > now() - interval '3 hours'))
        and (s not in ('today') or l.status = 'live' or (l.scheduled_at at time zone 'Africa/Douala')::date = (now() at time zone 'Africa/Douala')::date)
        and (s <> 'week' or l.status = 'live' or l.scheduled_at < now() + interval '7 days')
        and (s <> 'live' or l.status = 'live')
        and (s <> 'mine' or (uid is not null and exists (select 1 from live_reminders r where r.live_id = l.id and r.user_id = uid)))
      order by (l.status = 'live') desc, l.scheduled_at asc nulls last
      limit least(greatest(coalesce(p_limit, 60), 1), 100)) l), '[]'::jsonb);
end $$;

create or replace function live_remind_set(p_live uuid, p_on boolean default true) returns boolean
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : rappel impossible'; end if;
  select * into l from lives where id = p_live;
  if not found or l.status <> 'scheduled' then raise exception 'Ce live n''est plus programmé'; end if;
  if coalesce(p_on, true) then
    if l.scheduled_at is null or l.scheduled_at <= now() then raise exception 'Ce live n''a pas de date à venir'; end if;
    if l.host_id = auth.uid() then raise exception 'Vous êtes l''hôte de ce live'; end if;
    if (select count(*) from live_reminders where user_id = auth.uid() and not notified) >= 50 then raise exception 'Cinquante rappels actifs au plus'; end if;
    insert into live_reminders (live_id, user_id) values (l.id, auth.uid()) on conflict do nothing;
  else
    delete from live_reminders where live_id = l.id and user_id = auth.uid();
  end if;
  return coalesce(p_on, true);
end $$;

-- Rappel envoyé 30 minutes avant l'heure prévue, ou au démarrage du live s'il commence avant.
create or replace function send_live_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select rm.live_id, rm.user_id, l.title, l.status, l.scheduled_at
    from live_reminders rm join lives l on l.id = rm.live_id
    where not rm.notified
      and ((l.status = 'scheduled' and l.scheduled_at <= now() + interval '30 minutes') or l.status = 'live')
    limit 500
  loop
    insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'live_reminder', case when r.status = 'live' then 'Le live a commencé' else 'Un live commence bientôt' end,
            left('« ' || r.title || ' »' || case when r.status = 'live' then ' est en direct.' else ' commence dans moins de 30 minutes.' end, 500), jsonb_build_object('live', r.live_id));
    update live_reminders set notified = true where live_id = r.live_id and user_id = r.user_id;
    n := n + 1;
  end loop;
  delete from live_reminders rm using lives l where l.id = rm.live_id and (l.status in ('ended', 'cancelled') or l.created_at < now() - interval '90 days');
  return n;
end $$;
revoke all on function send_live_reminders() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('send-live-reminders', '*/5 * * * *', 'select public.send_live_reminders()');
exception when others then
  raise notice 'pg_cron indisponible : les rappels de live ne partent pas tant que send_live_reminders() n''est pas planifiée (%).', sqlerrm;
end $$;

-- Plafond quotidien de lives créés par un compte (hors déclenchements de l'administration).
create or replace function lives_daily_quota() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from lives where host_id = new.host_id and created_at > now() - interval '1 day') >= 15 then
    raise exception 'Quinze lives par jour au plus';
  end if;
  return new;
end $$;
drop trigger if exists trg_lives_daily_quota on lives;
create trigger trg_lives_daily_quota before insert on lives for each row execute function lives_daily_quota();

create or replace function scheduled_lives_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from profiles where id = new.host_id and coalesce(suspended, false)) then raise exception 'Compte suspendu : programmation impossible'; end if;
  if (select count(*) from scheduled_lives where host_id = new.host_id and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq programmations par jour au plus'; end if;
  if new.status = 'scheduled' and (select count(*) from scheduled_lives where host_id = new.host_id and status = 'scheduled') >= 10 then raise exception 'Dix lives programmés au plus'; end if;
  return new;
end $$;
drop trigger if exists trg_scheduled_lives_guard on scheduled_lives;
create trigger trg_scheduled_lives_guard before insert on scheduled_lives for each row execute function scheduled_lives_guard();

revoke all on function lives_agenda(text, integer) from public;
grant execute on function lives_agenda(text, integer) to anon, authenticated;
revoke all on function live_remind_set(uuid, boolean) from public, anon;
grant execute on function live_remind_set(uuid, boolean) to authenticated;

-- Retour arrière : drop trigger trg_lives_daily_quota on lives ; drop trigger trg_scheduled_lives_guard on scheduled_lives ;
--   drop function lives_daily_quota(), scheduled_lives_guard(), lives_agenda(text, integer), live_remind_set(uuid, boolean), send_live_reminders() ;
--   select cron.unschedule('send-live-reminders') ; drop table live_reminders.
