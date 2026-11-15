-- Durcissement de la récupération de compte (Edge Function auth-recovery) :
--  * limitation des tentatives de connexion par téléphone et par adresse (table auth_throttle, réservée au rôle service_role) ;
--  * révocation de toutes les sessions d'un compte après un changement de mot de passe par code.
-- Retour arrière : drop function auth_throttle_check(text, integer, integer), auth_throttle_hit(text), auth_throttle_clear(text), auth_revoke_sessions(uuid); drop table auth_throttle;

create table if not exists auth_throttle (
  id bigserial primary key,
  key text not null,
  at timestamptz not null default now()
);
create index if not exists auth_throttle_key_at on auth_throttle (key, at desc);
alter table auth_throttle enable row level security;
revoke all on auth_throttle from public, anon, authenticated;

-- Nombre d'échecs récents pour une clé ; purge au passage les entrées de plus d'un jour.
create or replace function auth_throttle_check(p_key text, p_window_minutes integer default 15, p_max integer default 10) returns boolean
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  delete from auth_throttle where at < now() - interval '1 day' and random() < 0.05;
  select count(*) into n from auth_throttle where key = p_key and at > now() - make_interval(mins => p_window_minutes);
  return n < p_max;
end $$;

create or replace function auth_throttle_hit(p_key text) returns void
language sql security definer set search_path = public as $$
  insert into auth_throttle (key) values (left(p_key, 120));
$$;

create or replace function auth_throttle_clear(p_key text) returns void
language sql security definer set search_path = public as $$
  delete from auth_throttle where key = p_key;
$$;

-- Supprime les sessions (et leurs jetons de rafraîchissement) d'un compte.
create or replace function auth_revoke_sessions(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from auth.sessions where user_id = p_user;
end $$;

revoke all on function auth_throttle_check(text, integer, integer), auth_throttle_hit(text), auth_throttle_clear(text), auth_revoke_sessions(uuid) from public, anon, authenticated;
grant execute on function auth_throttle_check(text, integer, integer), auth_throttle_hit(text), auth_throttle_clear(text), auth_revoke_sessions(uuid) to service_role;
