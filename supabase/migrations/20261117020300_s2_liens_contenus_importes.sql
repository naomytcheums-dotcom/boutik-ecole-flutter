-- Lot S2 (4/5) : liens du profil, réseaux connectés et contenus importés (S2-43, S2-44, S2-45, S2-6).
--  1. S2-44 : une connexion à un réseau (Instagram, TikTok, YouTube, GitHub, Facebook, LinkedIn, Behance) ajoute le lien du compte à profiles.links
--             (donc l'icône du profil) ; la déconnexion le retire. Sans modifier les Edge Functions : un déclencheur suit integration_connections.
--  2. S2-45 : profile_links_public(p_user) rend les liens https:// visibles de tous, selon la visibilité du profil.
--  3. S2-43 : profile_imported_items(p_user) rend les contenus importés choisis « Portfolio » ou « Public » (jamais « Privé »).
-- Retour arrière : voir le bas du fichier.

-- ============================================================ 1. connexion → lien du profil
create or replace function _profile_link_add(p_user uuid, p_label text, p_url text) returns void
language plpgsql security definer set search_path = public as $$
declare v_links jsonb;
begin
  if p_url is null or p_url !~* '^https://[^\s<>"]+$' or char_length(p_url) not between 12 and 300 then return; end if;
  select case when jsonb_typeof(links) = 'array' then links else '[]'::jsonb end into v_links from profiles where id = p_user;
  if v_links is null then return; end if;
  if exists (select 1 from jsonb_array_elements(v_links) l where l ->> 'url' = p_url) or jsonb_array_length(v_links) >= 12 then return; end if;
  update profiles set links = v_links || jsonb_build_array(jsonb_build_object('label', left(coalesce(nullif(btrim(p_label), ''), 'Lien'), 60), 'url', p_url)) where id = p_user;
end $$;

create or replace function _profile_link_remove(p_user uuid, p_url text) returns void
language sql security definer set search_path = public as $$
  update profiles set links = coalesce((select jsonb_agg(l) from jsonb_array_elements(case when jsonb_typeof(links) = 'array' then links else '[]'::jsonb end) l
                                        where l ->> 'url' is distinct from p_url), '[]'::jsonb)
  where id = p_user and p_url is not null
$$;
revoke all on function _profile_link_add(uuid, text, text), _profile_link_remove(uuid, text) from public, anon, authenticated;

create or replace function _sync_profile_link_from_connection() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if tg_op = 'DELETE' then
    perform _profile_link_remove(old.user_id, old.profile_url);
    return old;
  end if;
  if new.provider not in ('facebook', 'instagram', 'linkedin', 'tiktok', 'youtube', 'github', 'behance') then return new; end if;
  -- Une synchronisation ordinaire ne rétablit pas un lien que la personne a retiré à la main.
  if tg_op = 'UPDATE' and old.status is not distinct from new.status and old.profile_url is not distinct from new.profile_url then return new; end if;
  if tg_op = 'UPDATE' and old.profile_url is distinct from new.profile_url then perform _profile_link_remove(old.user_id, old.profile_url); end if;
  if new.status = 'connected' then
    select name into v_name from integration_providers where id = new.provider;
    perform _profile_link_add(new.user_id, v_name, new.profile_url);
  elsif new.status = 'revoked' then
    perform _profile_link_remove(new.user_id, new.profile_url);
  end if;
  return new;
end $$;
revoke all on function _sync_profile_link_from_connection() from public, anon, authenticated;
drop trigger if exists trg_sync_profile_link on integration_connections;
create trigger trg_sync_profile_link after insert or update or delete on integration_connections for each row execute function _sync_profile_link_from_connection();

-- Rattrapage : les comptes déjà connectés rejoignent les liens du profil.
do $$
declare r record;
begin
  for r in select c.user_id, p.name, c.profile_url from integration_connections c join integration_providers p on p.id = c.provider
           where c.status = 'connected' and c.profile_url is not null and c.provider in ('facebook', 'instagram', 'linkedin', 'tiktok', 'youtube', 'github', 'behance') loop
    perform _profile_link_add(r.user_id, r.name, r.profile_url);
  end loop;
end $$;

-- ============================================================ 2. liens publics d'un profil
create or replace function profile_links_public(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_agg(jsonb_build_object('label', coalesce(l ->> 'label', ''), 'url', l ->> 'url'))
                   from profiles p, jsonb_array_elements(case when jsonb_typeof(p.links) = 'array' then p.links else '[]'::jsonb end) l
                   where p.id = p_user and not coalesce(p.suspended, false) and profile_visible(p.id) and coalesce(l ->> 'url', '') ~* '^https://[^\s<>"]+$'), '[]'::jsonb)
$$;
revoke all on function profile_links_public(uuid) from public;
grant execute on function profile_links_public(uuid) to anon, authenticated;

-- ============================================================ 3. contenus importés partagés
create or replace function profile_imported_items(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := coalesce(p_user, auth.uid());
begin
  if v_user is null then return '[]'::jsonb; end if;
  if v_user <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid) and (not profile_visible(v_user) or exists (select 1 from profiles where id = v_user and suspended)) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'provider', x.provider, 'kind', x.kind, 'title', x.title, 'body', left(coalesce(x.body, ''), 300),
             'url', case when coalesce(x.url, '') ~* '^https://[^\s<>"]+$' then x.url else '' end, 'visibility', x.visibility, 'published_at', x.published_at) order by x.published_at desc nulls last, x.imported_at desc)
    from (select * from integration_imported_items
          where user_id = v_user and (visibility in ('portfolio', 'public') or v_user = auth.uid())
          order by published_at desc nulls last, imported_at desc limit 50) x), '[]'::jsonb);
end $$;
revoke all on function profile_imported_items(uuid) from public;
grant execute on function profile_imported_items(uuid) to anon, authenticated;

-- Retour arrière : drop trigger trg_sync_profile_link on integration_connections ;
--   drop function _sync_profile_link_from_connection(), _profile_link_add(uuid, text, text), _profile_link_remove(uuid, text), profile_links_public(uuid), profile_imported_items(uuid).
