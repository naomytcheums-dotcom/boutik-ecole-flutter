-- Lot S2 (2/5) : confidentialité du profil (S2-9, S2-13, S2-96).
-- Deux réglages choisis par la personne :
--   * profile_visibility : 'public' (défaut, tout le monde, visiteurs compris), 'members' (comptes connectés seulement), 'private' (moi et l'équipe seulement) ;
--   * directory_listed   : apparaître dans l'annuaire des talents (défaut : oui, comme avant ; sans effet si le profil est privé).
-- Les colonnes ne sont modifiables que par profile_privacy_set (le GRANT de colonnes de profiles n'est pas modifié).
-- Fonctions de lecture à appeler par public_profile et talents_list (objets du chef) : profile_visible(uuid) et profile_in_directory(uuid) ;
-- ici elles sont déjà appliquées au portfolio, aux couvertures et au CV d'un talent (cv_public).
-- Retour arrière : voir le bas du fichier.

alter table profiles add column if not exists profile_visibility text not null default 'public';
alter table profiles add column if not exists directory_listed boolean not null default true;
alter table profiles drop constraint if exists profiles_profile_visibility_chk;
alter table profiles add constraint profiles_profile_visibility_chk check (profile_visibility in ('public', 'members', 'private'));

-- Le profil de p_owner est-il lisible par la personne qui appelle (visiteur compris) ?
create or replace function profile_visible(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.id = auth.uid() or p.profile_visibility = 'public' or (p.profile_visibility = 'members' and auth.uid() is not null) or is_platform_staff()
                   from profiles p where p.id = p_owner), false)
$$;
-- La personne accepte-t-elle de figurer dans l'annuaire des talents ?
create or replace function profile_in_directory(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.directory_listed and p.profile_visibility <> 'private' from profiles p where p.id = p_owner), false)
$$;
revoke all on function profile_visible(uuid), profile_in_directory(uuid) from public;
grant execute on function profile_visible(uuid), profile_in_directory(uuid) to anon, authenticated;

create or replace function profile_privacy_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from profiles where id = auth.uid();
  return jsonb_build_object('visibility', p.profile_visibility, 'directory', p.directory_listed, 'student', p.role::text = 'student');
end $$;

create or replace function profile_privacy_set(p_visibility text, p_directory boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : réglage impossible'; end if;
  if p_visibility is null or p_visibility not in ('public', 'members', 'private') then raise exception 'Visibilité inconnue'; end if;
  update profiles set profile_visibility = p_visibility, directory_listed = coalesce(p_directory, directory_listed) where id = auth.uid();
  return profile_privacy_get();
end $$;
revoke all on function profile_privacy_get(), profile_privacy_set(text, boolean) from public, anon;
grant execute on function profile_privacy_get(), profile_privacy_set(text, boolean) to authenticated;

-- Portfolio : lisible selon la visibilité du profil (auparavant public sans condition).
drop policy if exists "portfolio : lecture publique" on portfolio_items;
drop policy if exists "portfolio : selon la visibilité du profil" on portfolio_items;
create policy "portfolio : selon la visibilité du profil" on portfolio_items for select using (owner_id = auth.uid() or profile_visible(owner_id));

-- Couvertures du profil (dernière définition : 20261114003400) : masquées avec le profil.
create or replace function profile_covers_get(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('slot', c.slot, 'path', c.path, 'kind', c.kind) order by c.slot)
                   from profile_covers c where c.user_id = coalesce(p_user, auth.uid()) and profile_visible(c.user_id)), '[]'::jsonb);
end $$;
revoke all on function profile_covers_get(uuid) from public, anon;
grant execute on function profile_covers_get(uuid) to authenticated;

-- CV d'un talent (écran 229, dernière définition : 20261115200300) : un profil privé n'est pas consultable par son identifiant.
create or replace function cv_public(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c cv_links%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not profile_visible(p_user) then return null; end if;
  select * into c from cv_links where owner_id = p_user and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then return null; end if;
  return _cv_payload(c) || jsonb_build_object('user_id', p_user);
end $$;
revoke all on function cv_public(uuid) from public, anon;
grant execute on function cv_public(uuid) to authenticated;

-- Retour arrière : rejouer profile_covers_get depuis 20261114003400, cv_public depuis 20261115200300 ;
--   drop policy "portfolio : selon la visibilité du profil" on portfolio_items ; create policy "portfolio : lecture publique" on portfolio_items for select using (true) ;
--   drop function profile_privacy_get(), profile_privacy_set(text, boolean), profile_visible(uuid), profile_in_directory(uuid) ;
--   alter table profiles drop constraint profiles_profile_visibility_chk, drop column profile_visibility, drop column directory_listed.
