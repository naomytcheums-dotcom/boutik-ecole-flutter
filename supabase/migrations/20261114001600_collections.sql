-- Mes collections : listes nommées de produits favoris (privée, partagée par lien, publique). Création, renommage, visibilité, ajout et retrait de produits, suppression.
-- Retour arrière : drop function collections_list(), collection_save(uuid, text, text), collection_delete(uuid), collection_item_toggle(uuid, text), collection_get(uuid); drop table user_collection_items, user_collections.

create table if not exists user_collections (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references profiles(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 60),
  visibility text not null default 'private' check (visibility in ('private', 'shared', 'public')),
  created_at timestamptz not null default now()
);
create unique index if not exists user_collections_name on user_collections (owner, lower(name));
create table if not exists user_collection_items (
  collection_id uuid not null references user_collections(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  added_at timestamptz not null default now(),
  primary key (collection_id, title)
);
alter table user_collections enable row level security;
alter table user_collection_items enable row level security;
revoke all on user_collections, user_collection_items from anon, authenticated;

create or replace function collections_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'visibility', c.visibility,
      'count', (select count(*) from user_collection_items i where i.collection_id = c.id),
      'items', coalesce((select jsonb_agg(i.title order by i.added_at desc) from user_collection_items i where i.collection_id = c.id), '[]'::jsonb)) order by c.created_at desc), '[]'::jsonb)
  from user_collections c where c.owner = auth.uid()
$$;

create or replace function collection_get(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', c.id, 'name', c.name, 'visibility', c.visibility, 'owner', display_name(c.owner), 'mine', c.owner = auth.uid(),
      'items', coalesce((select jsonb_agg(i.title order by i.added_at desc) from user_collection_items i where i.collection_id = c.id), '[]'::jsonb))
  from user_collections c where c.id = p_id and (c.owner = auth.uid() or c.visibility in ('shared', 'public'))
$$;

create or replace function collection_save(p_id uuid, p_name text, p_visibility text default 'private') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2 then raise exception 'Donnez un nom à la collection (2 lettres au moins)'; end if;
  if coalesce(p_visibility, 'private') not in ('private', 'shared', 'public') then raise exception 'Visibilité inconnue'; end if;
  if p_id is null then
    if (select count(*) from user_collections where owner = auth.uid()) >= 30 then raise exception 'Trente collections au plus'; end if;
    insert into user_collections (owner, name, visibility) values (auth.uid(), btrim(p_name), coalesce(p_visibility, 'private')) returning id into v_id;
  else
    update user_collections set name = btrim(p_name), visibility = coalesce(p_visibility, 'private') where id = p_id and owner = auth.uid() returning id into v_id;
    if v_id is null then raise exception 'Collection introuvable'; end if;
  end if;
  return v_id;
exception when unique_violation then raise exception 'Vous avez déjà une collection de ce nom';
end $$;

create or replace function collection_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from user_collections where id = p_id and owner = auth.uid();
  if not found then raise exception 'Collection introuvable'; end if;
end $$;

-- Ajoute le produit à la collection, ou le retire s'il y est déjà ; renvoie vrai quand il y est après l'appel.
create or replace function collection_item_toggle(p_id uuid, p_title text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from user_collections where id = p_id and owner = auth.uid()) then raise exception 'Collection introuvable'; end if;
  if char_length(btrim(coalesce(p_title, ''))) = 0 then raise exception 'Produit inconnu'; end if;
  delete from user_collection_items where collection_id = p_id and title = btrim(p_title);
  if found then return false; end if;
  if (select count(*) from user_collection_items where collection_id = p_id) >= 200 then raise exception 'Deux cents produits au plus par collection'; end if;
  insert into user_collection_items (collection_id, title) values (p_id, btrim(p_title));
  return true;
end $$;

revoke all on function collections_list(), collection_get(uuid), collection_save(uuid, text, text), collection_delete(uuid), collection_item_toggle(uuid, text) from public, anon;
grant execute on function collections_list(), collection_get(uuid), collection_save(uuid, text, text), collection_delete(uuid), collection_item_toggle(uuid, text) to authenticated;
