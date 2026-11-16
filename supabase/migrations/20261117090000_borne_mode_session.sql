-- Mode « borne » (S9-40, S9-38, S9-39) : un terminal public ne porte jamais la session d'un étudiant.
--  * Chaque borne a un jeton d'appareil (créé par le support/l'administrateur, seul son empreinte SHA-256 est stockée) ;
--  * la borne envoie un battement de cœur (kiosk_heartbeat) : l'état « en ligne » devient mesuré (kiosks.last_seen_at) ;
--  * l'appariement avec le téléphone se fait par un code court (kiosk_pairings) émis SANS compte sur la borne : le téléphone,
--    connecté à SON compte, le réclame (kiosk_pair_claim) et ouvre la fiche de l'annonce ; aucun mot de passe n'est saisi sur la borne.
-- Aucune donnée existante n'est modifiée. Rejouable.
-- Retour arrière : drop function if exists kiosk_provision(text), kiosk_heartbeat(text, text), kiosk_pair_issue(text, text, uuid, integer),
--   kiosk_pair_status(text, text, text), kiosk_pair_revoke(text, text, text), kiosk_pair_claim(text), kiosk_device_ok(text, text);
--   drop table if exists kiosk_pairings, kiosk_devices; alter table kiosks drop column if exists last_seen_at;

alter table kiosks add column if not exists last_seen_at timestamptz;

create table if not exists kiosk_devices (
  kiosk_id text primary key references kiosks(id) on delete cascade,
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  rotated_at timestamptz not null default now()
);
alter table kiosk_devices enable row level security;
revoke all on kiosk_devices from anon, authenticated;

create table if not exists kiosk_pairings (
  id uuid primary key default gen_random_uuid(),
  token text not null unique check (token ~ '^[A-Za-z0-9_-]{32}$'),
  kiosk_id text not null references kiosks(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  label text not null default '' check (char_length(label) <= 200),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references profiles(id) on delete set null,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists kiosk_pairings_kiosk on kiosk_pairings (kiosk_id, created_at desc);
alter table kiosk_pairings enable row level security;
revoke all on kiosk_pairings from anon, authenticated;

-- Vérifie le jeton d'appareil d'une borne (interne).
create or replace function kiosk_device_ok(p_kiosk text, p_token text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(p_token, '') <> '' and exists (
    select 1 from kiosk_devices d
    where d.kiosk_id = p_kiosk and d.token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex'))
$$;
revoke all on function kiosk_device_ok(text, text) from public, anon, authenticated;

-- Support / administration : crée ou renouvelle le jeton d'une borne. Le jeton n'est renvoyé qu'ici, une seule fois.
create or replace function kiosk_provision(p_kiosk text) returns text
language plpgsql security definer set search_path = public as $$
declare tok text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au support ou à l''administrateur'; end if;
  if not exists (select 1 from kiosks where id = p_kiosk) then raise exception 'Borne inconnue'; end if;
  insert into kiosk_devices (kiosk_id, token_hash) values (p_kiosk, encode(sha256(convert_to(tok, 'UTF8')), 'hex'))
  on conflict (kiosk_id) do update set token_hash = excluded.token_hash, rotated_at = now();
  update kiosk_pairings set revoked = true where kiosk_id = p_kiosk and not revoked and used_at is null;
  return tok;
end $$;
revoke all on function kiosk_provision(text) from public, anon;
grant execute on function kiosk_provision(text) to authenticated;

-- Battement de cœur : appelé par la borne (sans compte). Mesure la présence réelle ; ne change jamais un état posé par le support.
create or replace function kiosk_heartbeat(p_kiosk text, p_token text) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare now_ timestamptz := now();
begin
  if not kiosk_device_ok(p_kiosk, p_token) then raise exception 'Borne non autorisée'; end if;
  update kiosks set last_seen_at = now_ where id = p_kiosk;
  return now_;
end $$;
revoke all on function kiosk_heartbeat(text, text) from public;
grant execute on function kiosk_heartbeat(text, text) to anon, authenticated;

-- Code d'appariement émis par la borne pour une annonce publiée : valable 5 minutes (30 s à 10 min), usage unique, sans compte.
create or replace function kiosk_pair_issue(p_kiosk text, p_token text, p_listing uuid, p_ttl_seconds integer default 300) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; tok text; exp timestamptz;
begin
  if not kiosk_device_ok(p_kiosk, p_token) then raise exception 'Borne non autorisée'; end if;
  if p_ttl_seconds is null or p_ttl_seconds < 30 or p_ttl_seconds > 600 then raise exception 'Durée de validité invalide'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found then raise exception 'Annonce introuvable ou non publiée'; end if;
  if (select count(*) from kiosk_pairings where kiosk_id = p_kiosk and created_at > now() - interval '1 minute') >= 12 then
    raise exception 'Trop de codes demandés : patientez un instant';
  end if;
  delete from kiosk_pairings where created_at < now() - interval '1 day';
  update kiosk_pairings set revoked = true where kiosk_id = p_kiosk and not revoked and used_at is null;
  tok := replace(gen_random_uuid()::text, '-', '');
  exp := now() + make_interval(secs => p_ttl_seconds);
  insert into kiosk_pairings (token, kiosk_id, listing_id, label, expires_at) values (tok, p_kiosk, l.id, left(l.title, 200), exp);
  return jsonb_build_object('token', tok, 'expires_at', exp, 'label', left(l.title, 200));
end $$;
revoke all on function kiosk_pair_issue(text, text, uuid, integer) from public;
grant execute on function kiosk_pair_issue(text, text, uuid, integer) to anon, authenticated;

-- État d'un code, lu par la borne qui l'a émis : pending, used, expired, revoked ou unknown.
create or replace function kiosk_pair_status(p_kiosk text, p_token text, p_pairing text) returns text
language plpgsql stable security definer set search_path = public as $$
declare r kiosk_pairings%rowtype;
begin
  if not kiosk_device_ok(p_kiosk, p_token) then raise exception 'Borne non autorisée'; end if;
  select * into r from kiosk_pairings where token = coalesce(p_pairing, '') and kiosk_id = p_kiosk;
  if not found then return 'unknown'; end if;
  if r.used_at is not null then return 'used'; end if;
  if r.revoked then return 'revoked'; end if;
  if r.expires_at < now() then return 'expired'; end if;
  return 'pending';
end $$;
revoke all on function kiosk_pair_status(text, text, text) from public;
grant execute on function kiosk_pair_status(text, text, text) to anon, authenticated;

-- Abandon sur la borne (« Annuler », fin de session) : le code encore valable est révoqué.
create or replace function kiosk_pair_revoke(p_kiosk text, p_token text, p_pairing text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not kiosk_device_ok(p_kiosk, p_token) then raise exception 'Borne non autorisée'; end if;
  update kiosk_pairings set revoked = true where token = coalesce(p_pairing, '') and kiosk_id = p_kiosk and used_at is null;
end $$;
revoke all on function kiosk_pair_revoke(text, text, text) from public;
grant execute on function kiosk_pair_revoke(text, text, text) to anon, authenticated;

-- Téléphone connecté : réclame le code scanné. Renvoie l'annonce à ouvrir ; son propre produit n'est pas consommé (own = true).
create or replace function kiosk_pair_claim(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r kiosk_pairings%rowtype; l listings%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into r from kiosk_pairings where token = coalesce(p_token, '') for update;
  if not found then return jsonb_build_object('valid', false, 'reason', 'unknown'); end if;
  if r.revoked then return jsonb_build_object('valid', false, 'reason', 'revoked', 'kind', 'kiosk_pair'); end if;
  if r.used_at is not null then return jsonb_build_object('valid', false, 'reason', 'used', 'kind', 'kiosk_pair'); end if;
  if r.expires_at < now() then return jsonb_build_object('valid', false, 'reason', 'expired', 'kind', 'kiosk_pair'); end if;
  select * into l from listings where id = r.listing_id;
  if not found or l.status <> 'approved' then return jsonb_build_object('valid', false, 'reason', 'unavailable', 'kind', 'kiosk_pair'); end if;
  if l.seller_id = auth.uid() then
    return jsonb_build_object('valid', true, 'kind', 'kiosk_pair', 'listing_id', r.listing_id, 'label', r.label, 'kiosk_id', r.kiosk_id, 'own', true);
  end if;
  update kiosk_pairings set used_at = now(), used_by = auth.uid() where id = r.id;
  return jsonb_build_object('valid', true, 'kind', 'kiosk_pair', 'listing_id', r.listing_id, 'label', r.label, 'kiosk_id', r.kiosk_id, 'own', false);
end $$;
revoke all on function kiosk_pair_claim(text) from public, anon;
grant execute on function kiosk_pair_claim(text) to authenticated;
