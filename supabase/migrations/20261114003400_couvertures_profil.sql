-- Les 3 couvertures du profil (écran 10) : photo ou vidéo de la personne, affichées tout de suite, sans passer par une publication
-- (une publication reste « en attente » pour un compte non certifié, donc la couverture n'apparaissait jamais).
create table if not exists profile_covers (
  user_id uuid not null references profiles(id) on delete cascade,
  slot integer not null check (slot between 0 and 2),
  path text not null check (char_length(path) between 5 and 300),
  kind text not null check (kind in ('image', 'video')),
  updated_at timestamptz not null default now(),
  primary key (user_id, slot)
);
alter table profile_covers enable row level security;
revoke all on profile_covers from anon, authenticated;

create or replace function profile_cover_set(p_slot integer, p_path text, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_slot not between 0 and 2 then raise exception 'Emplacement inconnu'; end if;
  if p_kind not in ('image', 'video') then raise exception 'Format inconnu'; end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  insert into profile_covers (user_id, slot, path, kind) values (auth.uid(), p_slot, p_path, p_kind)
  on conflict (user_id, slot) do update set path = excluded.path, kind = excluded.kind, updated_at = now();
end $$;

create or replace function profile_cover_clear(p_slot integer) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from profile_covers where user_id = auth.uid() and slot = p_slot;
end $$;

-- Couvertures d'une personne (la mienne par défaut), visibles de tout compte connecté comme son profil public.
create or replace function profile_covers_get(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('slot', c.slot, 'path', c.path, 'kind', c.kind) order by c.slot)
                   from profile_covers c where c.user_id = coalesce(p_user, auth.uid())), '[]'::jsonb);
end $$;

revoke all on function profile_cover_set(integer, text, text), profile_cover_clear(integer), profile_covers_get(uuid) from public, anon;
grant execute on function profile_cover_set(integer, text, text), profile_cover_clear(integer), profile_covers_get(uuid) to authenticated;
