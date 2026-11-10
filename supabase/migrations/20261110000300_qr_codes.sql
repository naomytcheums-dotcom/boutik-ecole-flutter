-- QR codes réels : chaque code est un jeton aléatoire (192 bits, non devinable), UNIQUE, rattaché à son propriétaire et à un contenu.
-- Les codes « permanents » (profil, annonce…) sont créés une fois et retrouvés ensuite ; les codes « à usage unique » (borne → téléphone,
-- retrait de commande) expirent et ne servent qu'une fois. Aucune donnée existante n'est modifiée.

create table if not exists qr_codes (
  id uuid primary key default gen_random_uuid(),
  token text not null unique check (token ~ '^[A-Za-z0-9_-]{32}$'),
  owner_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('profile', 'listing', 'order_pickup', 'kiosk_transfer', 'event', 'certificate')),
  target_id text not null check (char_length(target_id) between 1 and 120),   -- identifiant du contenu (profil, annonce, commande…)
  label text not null default '' check (char_length(label) <= 120),
  single_use boolean not null default false,
  expires_at timestamptz,
  used_at timestamptz,
  revoked boolean not null default false,
  scans integer not null default 0,
  created_at timestamptz not null default now()
);
-- un seul code permanent actif par propriétaire, nature et contenu
create unique index if not exists qr_codes_permanent_uniq on qr_codes (owner_id, kind, target_id) where expires_at is null and not revoked;
create index if not exists qr_codes_owner on qr_codes (owner_id, created_at desc);
alter table qr_codes enable row level security;
revoke all on qr_codes from anon, authenticated;
grant select on qr_codes to authenticated;
drop policy if exists "qr : propriétaire" on qr_codes;
create policy "qr : propriétaire" on qr_codes for select using (owner_id = auth.uid());

-- Jeton aléatoire cryptographique de 32 caractères (alphabet URL sûr)
create or replace function qr_new_token() returns text
language plpgsql volatile set search_path = public, extensions as $$
declare alphabet text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'; b bytea; t text := ''; i int;
begin
  b := gen_random_bytes(32);
  for i in 0..31 loop t := t || substr(alphabet, 1 + (get_byte(b, i) & 63), 1); end loop;
  return t;
end $$;
revoke all on function qr_new_token() from public, anon, authenticated;

-- Crée (ou retrouve, pour un code permanent) le QR du titulaire. p_ttl_seconds null = permanent.
create or replace function qr_issue(p_kind text, p_target_id text, p_label text default '', p_ttl_seconds integer default null, p_single_use boolean default false) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare r qr_codes%rowtype; tok text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('profile', 'listing', 'order_pickup', 'kiosk_transfer', 'event', 'certificate') then raise exception 'Type de QR inconnu'; end if;
  if p_kind = 'profile' and p_target_id <> auth.uid()::text then raise exception 'Vous ne pouvez créer que votre propre QR de profil'; end if;
  if p_kind = 'listing' and not exists (select 1 from listings where id::text = p_target_id and seller_id = auth.uid()) then raise exception 'Cette annonce ne vous appartient pas'; end if;
  if p_ttl_seconds is not null and (p_ttl_seconds < 30 or p_ttl_seconds > 86400) then raise exception 'Durée de validité invalide'; end if;
  if p_ttl_seconds is null then
    select * into r from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked;
    if found then return jsonb_build_object('token', r.token, 'expires_at', null, 'single_use', r.single_use, 'created', false); end if;
  else
    -- code temporaire : les précédents encore actifs du même contenu sont révoqués (un seul code vivant)
    update qr_codes set revoked = true where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is not null and not revoked and used_at is null;
  end if;
  loop
    tok := qr_new_token();
    begin
      insert into qr_codes (token, owner_id, kind, target_id, label, single_use, expires_at)
        values (tok, auth.uid(), p_kind, p_target_id, coalesce(p_label, ''), p_single_use or p_ttl_seconds is not null and p_kind in ('kiosk_transfer', 'order_pickup'),
                case when p_ttl_seconds is null then null else now() + make_interval(secs => p_ttl_seconds) end)
        returning * into r;
      exit;
    exception when unique_violation then
      if p_ttl_seconds is null and exists (select 1 from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked) then
        select * into r from qr_codes where owner_id = auth.uid() and kind = p_kind and target_id = p_target_id and expires_at is null and not revoked;
        exit;
      end if; -- sinon collision de jeton (probabilité négligeable) : on retire un jeton
    end;
  end loop;
  return jsonb_build_object('token', r.token, 'expires_at', r.expires_at, 'single_use', r.single_use, 'created', true);
end $$;

-- Lecture d'un code scanné. p_consume = true : marque l'usage (codes à usage unique) et compte le scan.
-- Réponse limitée à ce que le code désigne : pas de données privées du propriétaire.
create or replace function qr_resolve(p_token text, p_consume boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r qr_codes%rowtype; owner_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into r from qr_codes where token = coalesce(p_token, '') for update;
  if not found then return jsonb_build_object('valid', false, 'reason', 'unknown'); end if;
  select name into owner_name from profiles where id = r.owner_id;
  if r.revoked then return jsonb_build_object('valid', false, 'reason', 'revoked', 'kind', r.kind); end if;
  if r.expires_at is not null and r.expires_at < now() then return jsonb_build_object('valid', false, 'reason', 'expired', 'kind', r.kind); end if;
  if r.single_use and r.used_at is not null then return jsonb_build_object('valid', false, 'reason', 'used', 'kind', r.kind); end if;
  if p_consume then
    update qr_codes set scans = scans + 1, used_at = case when r.single_use then now() else used_at end where id = r.id;
  end if;
  return jsonb_build_object('valid', true, 'kind', r.kind, 'target_id', r.target_id, 'label', r.label, 'owner_id', r.owner_id,
                            'owner_name', coalesce(owner_name, ''), 'single_use', r.single_use, 'expires_at', r.expires_at);
end $$;

-- Retire un de ses codes (le titulaire seulement)
create or replace function qr_revoke(p_token text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update qr_codes set revoked = true where token = p_token and owner_id = auth.uid();
end $$;

revoke all on function qr_issue(text, text, text, integer, boolean), qr_resolve(text, boolean), qr_revoke(text) from public, anon;
grant execute on function qr_issue(text, text, text, integer, boolean), qr_resolve(text, boolean), qr_revoke(text) to authenticated;
