-- Lot H13 / RANKING (1/5) : présence réelle aux événements (preuve de participation) branchée sur le moteur de score (famille event_attended, 20261127010100).
--  Preuve : l'organisateur de l'événement (créateur, ou direction / administration) émet un CODE de pointage (8 caractères, généré par le serveur, renouvelable) ; l'étudiant le saisit
--  (ou le scanne en QR côté application) PENDANT la fenêtre horaire de l'événement. Le serveur valide : étudiant non suspendu, inscription CONFIRMÉE (non annulée, non remboursée, paiement confirmé),
--  événement publié, fenêtre ouverte, code exact, un seul pointage par (événement, étudiant), pas de chevauchement avec un autre événement déjà pointé. La présence n'est jamais déclarée par l'étudiant seul.
--  Fenêtre = de « début - attendance_grace_minutes » (défaut 15) à « fin + attendance_grace_minutes » ; sans heure de fin : début + attendance_default_hours (défaut 4). Paramètres techniques
--  configurables (talent_score_settings, ajoutés en 20261128010400), valeurs de repli codées dans _talent_setting.
--  Protection du code : 5 saisies fausses (attendance_max_failures) sur un même événement bloquent l'étudiant attendance_lock_minutes (défaut 10) ; les tentatives sont tracées.
--  Score : _talent_event_record('event_attended', 'event_attendance', '<événement>:<étudiant>', ...) avec l'organisateur comme auteur (auto-interaction / comptes liés / rafales contrôlés par _talent_precheck) ;
--  annulation exacte des points si l'inscription est annulée, supprimée ou remboursée, si l'événement est annulé ou supprimé, ou si la présence est supprimée. Rien n'est inséré par la migration, aucun rattrapage.
--  RPC : event_attendance_code_generate, event_attendance_list (organisateur), event_attendance_check_in, my_event_attendance (étudiant). Tables fermées (RLS sans politique).
-- Additive et rejouable. Retour arrière :
--   drop trigger trg_event_attendance_registration on event_registrations ; drop trigger trg_event_attendance_event on events ; drop trigger trg_event_attendance_delete on event_attendance ;
--   drop function event_attendance_code_generate(uuid, boolean), event_attendance_list(uuid), event_attendance_check_in(uuid, text), my_event_attendance(), _event_attendance_sync(uuid, uuid), _event_attendance_window(uuid),
--     _event_registration_valid(uuid, uuid), _event_organizer(uuid), _event_attendance_trg_registration(), _event_attendance_trg_event(), _event_attendance_trg_delete(), _event_attendance_guard() ;
--   drop table event_attendance_attempts, event_attendance, event_attendance_codes.

-- ============================================================ 1. Tables
create table if not exists event_attendance_codes (
  event_id uuid primary key references events (id) on delete cascade,
  code text not null check (code ~ '^[0-9A-F]{8}$'),
  version integer not null default 1 check (version >= 1),
  generated_by uuid references profiles (id) on delete set null,
  generated_at timestamptz not null default now()
);

create table if not exists event_attendance (
  id bigint generated always as identity primary key,
  event_id uuid not null references events (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled')),
  method text not null default 'code' check (method in ('code')),
  code_version integer not null check (code_version >= 1),
  checked_in_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancel_reason text check (cancel_reason is null or char_length(cancel_reason) <= 300),
  unique (event_id, user_id)
);
create index if not exists event_attendance_user on event_attendance (user_id, checked_in_at desc);

create table if not exists event_attendance_attempts (
  id bigint generated always as identity primary key,
  event_id uuid not null references events (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  outcome text not null check (outcome in ('ok', 'bad_code')),
  at timestamptz not null default now()
);
create index if not exists event_attendance_attempts_user on event_attendance_attempts (user_id, event_id, at desc);

alter table event_attendance_codes enable row level security;
alter table event_attendance enable row level security;
alter table event_attendance_attempts enable row level security;
revoke all on event_attendance_codes, event_attendance, event_attendance_attempts from public, anon, authenticated;

-- L'identité d'une présence ne change jamais (seul le statut et l'horodatage de pointage évoluent, via les fonctions du lot).
create or replace function _event_attendance_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.event_id is distinct from old.event_id or new.user_id is distinct from old.user_id then raise exception 'Une présence n''est pas modifiable'; end if;
  return new;
end $$;
revoke all on function _event_attendance_guard() from public, anon, authenticated;
drop trigger if exists trg_event_attendance_guard on event_attendance;
create trigger trg_event_attendance_guard before update on event_attendance for each row execute function _event_attendance_guard();

-- ============================================================ 2. Aides internes
create or replace function _event_attendance_window(p_event uuid) returns table (opens_at timestamptz, closes_at timestamptz, ends_eff timestamptz)
language sql stable security definer set search_path = public as $$
  select e.starts_at - make_interval(mins => _talent_setting('attendance_grace_minutes', 15)::integer),
         coalesce(e.ends_at, e.starts_at + make_interval(hours => _talent_setting('attendance_default_hours', 4)::integer)) + make_interval(mins => _talent_setting('attendance_grace_minutes', 15)::integer),
         coalesce(e.ends_at, e.starts_at + make_interval(hours => _talent_setting('attendance_default_hours', 4)::integer))
  from events e where e.id = p_event
$$;
revoke all on function _event_attendance_window(uuid) from public, anon, authenticated;

-- Inscription valable : confirmée, ni annulée ni remboursée, paiement éventuel confirmé.
create or replace function _event_registration_valid(p_event uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from event_registrations g left join payment_transactions t on t.id = g.payment_id
    where g.event_id = p_event and g.user_id = p_user and g.status = 'confirmed' and g.refund_status is null and (g.payment_id is null or coalesce(t.status, '') = 'confirmed'))
$$;
revoke all on function _event_registration_valid(uuid, uuid) from public, anon, authenticated;

-- Organisateur : créateur de l'événement, ou direction / administration (même règle que event_registrants).
create or replace function _event_organizer(p_event uuid) returns events
language plpgsql stable security definer set search_path = public as $$
declare e events; v_role text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into e from events where id = p_event;
  if e.id is null or v_role not in ('dept', 'direction', 'admin') or not (e.created_by = auth.uid() or v_role in ('direction', 'admin')) then raise exception 'Événement introuvable'; end if;
  return e;
end $$;
revoke all on function _event_organizer(uuid) from public, anon, authenticated;

-- Synchronise une présence avec le score : comptée si présence confirmée, inscription valable et événement publié ; sinon annulée avec retrait exact des points.
create or replace function _event_attendance_sync(p_event uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a event_attendance; e events; v_reason text; v_source text := p_event::text || ':' || p_user::text;
begin
  select * into a from event_attendance where event_id = p_event and user_id = p_user;
  if a.id is null then
    perform _talent_event_cancel('event_attended', 'event_attendance', v_source, 'Présence supprimée');
    return;
  end if;
  select * into e from events where id = p_event;
  if e.id is null then v_reason := 'Événement supprimé';
  elsif e.status <> 'published' then v_reason := 'Événement annulé ou retiré';
  elsif not _event_registration_valid(p_event, p_user) then v_reason := 'Inscription annulée ou remboursée';
  end if;
  if v_reason is not null then
    if a.status = 'confirmed' then
      update event_attendance set status = 'cancelled', cancelled_at = now(), cancel_reason = v_reason where id = a.id;
      insert into notifications (user_id, kind, title, body, data)
        values (p_user, 'event', 'Votre présence n''est plus comptée', left(coalesce('« ' || e.title || ' » : ', '') || lower(v_reason) || '.', 500), jsonb_build_object('event', p_event));
    end if;
    perform _talent_event_cancel('event_attended', 'event_attendance', v_source, v_reason);
  elsif a.status = 'confirmed' then
    perform _talent_event_record(p_user, 'event_attended', 'event_attendance', v_source, a.checked_in_at, null, e.created_by,
      jsonb_build_object('event', p_event, 'kind', e.kind, 'checked_in_at', a.checked_in_at, 'code_version', a.code_version));
  end if;
end $$;
revoke all on function _event_attendance_sync(uuid, uuid) from public, anon, authenticated;

-- ============================================================ 3. Déclencheurs (jamais bloquants pour l'opération d'origine)
create or replace function _event_attendance_trg_registration() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if tg_op = 'DELETE' then
      perform _event_attendance_sync(old.event_id, old.user_id);
      return old;
    end if;
    perform _event_attendance_sync(new.event_id, new.user_id);
  exception when others then raise warning 'présence événement (inscription) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _event_attendance_trg_registration() from public, anon, authenticated;
drop trigger if exists trg_event_attendance_registration on event_registrations;
create trigger trg_event_attendance_registration after update of status, refund_status, payment_id or delete on event_registrations for each row execute function _event_attendance_trg_registration();

create or replace function _event_attendance_trg_event() returns trigger
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  begin
    for r in select user_id from event_attendance where event_id = new.id and status = 'confirmed' loop
      perform _event_attendance_sync(new.id, r.user_id);
    end loop;
  exception when others then raise warning 'présence événement (événement) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _event_attendance_trg_event() from public, anon, authenticated;
drop trigger if exists trg_event_attendance_event on events;
create trigger trg_event_attendance_event after update of status on events for each row when (new.status is distinct from 'published') execute function _event_attendance_trg_event();

-- Suppression d'une présence (ou de l'événement en cascade) : l'activité de score est annulée.
create or replace function _event_attendance_trg_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    perform _talent_event_cancel('event_attended', 'event_attendance', old.event_id::text || ':' || old.user_id::text, 'Présence supprimée');
  exception when others then raise warning 'présence événement (suppression) : %', sqlerrm;
  end;
  return old;
end $$;
revoke all on function _event_attendance_trg_delete() from public, anon, authenticated;
drop trigger if exists trg_event_attendance_delete on event_attendance;
create trigger trg_event_attendance_delete after delete on event_attendance for each row execute function _event_attendance_trg_delete();

-- ============================================================ 4. RPC organisateur
create or replace function event_attendance_code_generate(p_event uuid, p_renew boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare e events; w record; c event_attendance_codes; v_new text;
begin
  e := _event_organizer(p_event);
  if e.status <> 'published' then raise exception 'Cet événement n''est pas publié : aucun code de pointage'; end if;
  select * into w from _event_attendance_window(e.id);
  if now() > w.closes_at then raise exception 'La fenêtre de pointage de cet événement est terminée'; end if;
  v_new := upper(substr(encode(sha256(convert_to(gen_random_uuid()::text || clock_timestamp()::text, 'UTF8')), 'hex'), 1, 8));
  select * into c from event_attendance_codes where event_id = e.id for update;
  if c.event_id is null then
    insert into event_attendance_codes (event_id, code, generated_by) values (e.id, v_new, auth.uid()) returning * into c;
  elsif coalesce(p_renew, false) then
    update event_attendance_codes set code = v_new, version = version + 1, generated_by = auth.uid(), generated_at = now() where event_id = e.id returning * into c;
  end if;
  return jsonb_build_object('event', e.id, 'code', c.code, 'code_display', substr(c.code, 1, 4) || '-' || substr(c.code, 5, 4), 'version', c.version, 'generated_at', c.generated_at,
    'opens_at', w.opens_at, 'closes_at', w.closes_at, 'window_open', now() between w.opens_at and w.closes_at);
end $$;

create or replace function event_attendance_list(p_event uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare e events; w record; c event_attendance_codes;
begin
  e := _event_organizer(p_event);
  select * into w from _event_attendance_window(e.id);
  select * into c from event_attendance_codes where event_id = e.id;
  return jsonb_build_object('event', jsonb_build_object('id', e.id, 'title', e.title, 'starts_at', e.starts_at, 'ends_at', e.ends_at, 'place', coalesce(e.place, ''), 'status', e.status),
    'opens_at', w.opens_at, 'closes_at', w.closes_at, 'window_open', now() between w.opens_at and w.closes_at, 'code_issued', c.event_id is not null, 'code_version', c.version,
    'registered', (select count(*)::int from event_registrations g where g.event_id = e.id and _event_registration_valid(e.id, g.user_id)),
    'present', (select count(*)::int from event_attendance a where a.event_id = e.id and a.status = 'confirmed'),
    'items', coalesce((select jsonb_agg(jsonb_build_object('user_id', a.user_id, 'name', display_name(a.user_id), 'checked_in_at', a.checked_in_at, 'status', a.status, 'cancel_reason', a.cancel_reason) order by a.checked_in_at)
                       from event_attendance a where a.event_id = e.id), '[]'::jsonb));
end $$;

-- ============================================================ 5. RPC étudiant
create or replace function event_attendance_check_in(p_event uuid, p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); e events; w record; c event_attendance_codes; a event_attendance; v_code text; v_max integer := _talent_setting('attendance_max_failures', 5)::integer;
        v_lock numeric := _talent_setting('attendance_lock_minutes', 10); v_fail integer; v_def integer := _talent_setting('attendance_default_hours', 4)::integer; v_id bigint;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  v_code := upper(regexp_replace(coalesce(p_code, ''), '[^0-9A-Za-z]', '', 'g'));
  if char_length(v_code) <> 8 then raise exception 'Code invalide : il comporte 8 caractères'; end if;
  select * into e from events where id = p_event and status = 'published';
  if e.id is null then raise exception 'Événement introuvable'; end if;
  if not _event_registration_valid(e.id, v_uid) then raise exception 'Vous n''êtes pas inscrit(e) à cet événement : le pointage est impossible'; end if;
  select * into w from _event_attendance_window(e.id);
  if now() < w.opens_at or now() > w.closes_at then
    raise exception 'Le pointage n''est possible que pendant l''événement (de % à %)', to_char(w.opens_at at time zone 'Africa/Douala', 'DD/MM HH24"h"MI'), to_char(w.closes_at at time zone 'Africa/Douala', 'DD/MM HH24"h"MI');
  end if;
  if exists (select 1 from event_attendance where event_id = e.id and user_id = v_uid and status = 'confirmed') then raise exception 'Votre présence est déjà enregistrée pour cet événement'; end if;
  select count(*)::int into v_fail from event_attendance_attempts where event_id = e.id and user_id = v_uid and outcome = 'bad_code' and at > now() - make_interval(secs => v_lock * 60);
  if v_fail >= v_max then raise exception 'Trop de codes erronés : réessayez dans % minutes', v_lock::integer; end if;
  if exists (select 1 from event_attendance a2 join events e2 on e2.id = a2.event_id
             where a2.user_id = v_uid and a2.status = 'confirmed' and a2.event_id <> e.id
               and e2.starts_at < coalesce(e.ends_at, e.starts_at + make_interval(hours => v_def)) and e.starts_at < coalesce(e2.ends_at, e2.starts_at + make_interval(hours => v_def))) then
    raise exception 'Vous avez déjà pointé à un autre événement au même moment';
  end if;
  select * into c from event_attendance_codes where event_id = e.id;
  if c.event_id is null then raise exception 'L''organisateur n''a pas encore émis de code de pointage'; end if;
  if c.code <> v_code then
    insert into event_attendance_attempts (event_id, user_id, outcome) values (e.id, v_uid, 'bad_code');
    return jsonb_build_object('ok', false, 'reason', 'bad_code', 'message', 'Code incorrect', 'remaining_attempts', greatest(v_max - v_fail - 1, 0));
  end if;
  insert into event_attendance (event_id, user_id, code_version) values (e.id, v_uid, c.version)
  on conflict (event_id, user_id) do update set status = 'confirmed', code_version = excluded.code_version, checked_in_at = now(), cancelled_at = null, cancel_reason = null
    where event_attendance.status = 'cancelled'
  returning id into v_id;
  if v_id is null then raise exception 'Votre présence est déjà enregistrée pour cet événement'; end if;
  insert into event_attendance_attempts (event_id, user_id, outcome) values (e.id, v_uid, 'ok');
  begin
    perform _event_attendance_sync(e.id, v_uid);
  exception when others then raise warning 'présence événement (score) : %', sqlerrm;
  end;
  insert into notifications (user_id, kind, title, body, data)
    values (v_uid, 'event', 'Présence enregistrée', left('Votre présence à « ' || e.title || ' » est enregistrée.', 500), jsonb_build_object('event', e.id));
  select * into a from event_attendance where id = v_id;
  return jsonb_build_object('ok', true, 'event', e.id, 'title', e.title, 'checked_in_at', a.checked_in_at);
end $$;

create or replace function my_event_attendance() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('event', e.id, 'title', e.title, 'kind', e.kind, 'starts_at', e.starts_at, 'ends_at', e.ends_at, 'place', coalesce(e.place, ''),
      'opens_at', w.opens_at, 'closes_at', w.closes_at, 'window_open', now() between w.opens_at and w.closes_at,
      'attended', a.status = 'confirmed', 'checked_in_at', case when a.status = 'confirmed' then a.checked_in_at end) order by e.starts_at desc)
    from (select g.event_id from event_registrations g where g.user_id = v_uid and _event_registration_valid(g.event_id, v_uid) order by g.created_at desc limit 100) r
    join events e on e.id = r.event_id and e.status = 'published'
    cross join lateral _event_attendance_window(e.id) w
    left join event_attendance a on a.event_id = e.id and a.user_id = v_uid), '[]'::jsonb);
end $$;

revoke all on function event_attendance_code_generate(uuid, boolean), event_attendance_list(uuid), event_attendance_check_in(uuid, text), my_event_attendance() from public, anon;
grant execute on function event_attendance_code_generate(uuid, boolean), event_attendance_list(uuid), event_attendance_check_in(uuid, text), my_event_attendance() to authenticated;
