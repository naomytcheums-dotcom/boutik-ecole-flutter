-- H13 SOCIAL 4/6 : profils créateurs — onglets, épinglage (3 au plus par onglet), visites agrégées.
--  * onglets : lives, publications, projets, produits, reposts, clips. creator_profile_tabs(p_user) donne le nombre d'éléments VISIBLES de chaque onglet (0 = état vide honnête) ;
--    creator_tab_items(p_user, p_tab, p_limit, p_before_at, p_before_id) liste l'onglet : éléments épinglés d'abord (première page), puis curseur (date, id) sans doublon ;
--  * confidentialité : profil non visible, suspendu ou bloqué => rien (null) ; lives : publics seulement (le propriétaire voit tout) ; projets approuvés publics ; produits approuvés,
--    hors exemples et boutiques fermées ; reposts dont l'original est encore visible ; clips prêts dont le replay est listable pour le lecteur ;
--  * creator_pins + creator_pin_set(p_tab, p_item, p_pin) : propriétaire seulement, élément à lui et éligible, 3 épinglés au plus par onglet (verrouillé contre les doubles clics concurrents),
--    épingler / désépingler est idempotent ; creator_pins_list(p_user) ;
--  * visites de profil : profile_visit_record (une visite par visiteur, profil et jour ; le visiteur n'est stocké que sous forme d'empreinte non réversible côté API, la table n'est lisible
--    par personne) et creator_visit_stats(p_days) : COMPTEURS AGRÉGÉS seulement pour le propriétaire (jamais d'identité).
-- Strictement additif. Retour arrière : drop function creator_profile_tabs(uuid), creator_tab_items(uuid, text, integer, timestamptz, uuid), creator_pin_set(text, uuid, boolean), creator_pins_list(uuid),
--   profile_visit_record(uuid), creator_visit_stats(integer), _h13_creator_items(uuid, text, uuid), _h13_pin_eligible(uuid, text, uuid), _h13_pins_limit() ; drop table creator_pins, profile_visits.

create table if not exists creator_pins (
  user_id uuid not null references profiles(id) on delete cascade,
  tab text not null check (tab in ('lives', 'publications', 'projets', 'produits', 'reposts', 'clips')),
  item_id uuid not null,
  pinned_at timestamptz not null default now(),
  primary key (user_id, tab, item_id)
);
alter table creator_pins enable row level security;
revoke all on creator_pins from anon, authenticated;
grant select on creator_pins to authenticated;
drop policy if exists "epingles : proprietaire" on creator_pins;
create policy "epingles : proprietaire" on creator_pins for select using (user_id = auth.uid());

create table if not exists profile_visits (
  owner_id uuid not null references profiles(id) on delete cascade,
  day date not null default ((now() at time zone 'Africa/Douala'))::date,
  visitor_key text not null,
  created_at timestamptz not null default now(),
  primary key (owner_id, day, visitor_key)
);
alter table profile_visits enable row level security;
revoke all on profile_visits from anon, authenticated;

create or replace function _h13_pins_limit() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from creator_pins where user_id = new.user_id and tab = new.tab) >= 3 then raise exception 'Trois éléments épinglés au plus par onglet'; end if;
  return new;
end $$;
revoke all on function _h13_pins_limit() from public, anon, authenticated;
drop trigger if exists trg_h13_pins_limit on creator_pins;
create trigger trg_h13_pins_limit before insert on creator_pins for each row execute function _h13_pins_limit();

-- Un élément peut être épinglé par son propriétaire s'il lui appartient et est publié.
create or replace function _h13_pin_eligible(p_user uuid, p_tab text, p_item uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select case p_tab
    when 'lives' then exists (select 1 from lives l where l.id = p_item and l.host_id = p_user and l.status <> 'cancelled')
    when 'publications' then exists (select 1 from posts x where x.id = p_item and x.author_id = p_user and x.status = 'published' and x.community_id is null and x.repost_of is null)
    when 'reposts' then exists (select 1 from posts x where x.id = p_item and x.author_id = p_user and x.status = 'published' and x.community_id is null and x.repost_of is not null)
    when 'projets' then exists (select 1 from projects x where x.id = p_item and x.owner_id = p_user and x.status = 'approved')
    when 'produits' then exists (select 1 from listings x where x.id = p_item and x.seller_id = p_user and x.status = 'approved')
    when 'clips' then exists (select 1 from replay_clips x where x.id = p_item and x.user_id = p_user and x.status = 'pret')
    else false end
$$;
revoke all on function _h13_pin_eligible(uuid, text, uuid) from public, anon, authenticated;

-- Éléments d'un onglet, tels que le lecteur (auth.uid()) a le droit de les voir.
create or replace function _h13_creator_items(p_user uuid, p_tab text, p_viewer uuid)
returns table(id uuid, title text, subtitle text, media_path text, media_kind text, ts timestamptz)
language sql stable security definer set search_path = public as $$
  select * from (
    select l.id, l.title, case l.status when 'live' then 'En direct' when 'scheduled' then 'Programmé' else 'Terminé' end, l.cover_path, case when l.cover_path is not null then 'image' end,
           coalesce(l.started_at, l.scheduled_at, l.created_at)
      from lives l where p_tab = 'lives' and l.host_id = p_user and l.status <> 'cancelled' and (l.visibilite = 'public' or p_viewer = p_user)
    union all
    select x.id, left(coalesce(nullif(btrim(x.caption), ''), nullif(btrim(x.body), ''), 'Publication'), 120), null::text, x.media_path, x.media_kind, coalesce(x.published_at, x.created_at)
      from posts x where p_tab = 'publications' and x.author_id = p_user and x.status = 'published' and x.community_id is null and x.repost_of is null
    union all
    select x.id, left(coalesce(nullif(btrim(o.caption), ''), nullif(btrim(o.body), ''), 'Publication'), 120), 'Republié de ' || display_name(o.author_id), o.media_path, o.media_kind, coalesce(x.published_at, x.created_at)
      from posts x join posts o on o.id = x.repost_of
      where p_tab = 'reposts' and x.author_id = p_user and x.status = 'published' and x.community_id is null
        and o.status = 'published' and o.community_id is null and profile_visible(o.author_id)
        and not exists (select 1 from profiles z where z.id = o.author_id and coalesce(z.suspended, false))
        and (p_viewer is null or not exists (select 1 from user_blocks b where (b.blocker_id = p_viewer and b.blocked_id = o.author_id) or (b.blocker_id = o.author_id and b.blocked_id = p_viewer)))
    union all
    select x.id, x.title, left(coalesce(x.summary, ''), 120), null::text, null::text, x.created_at
      from projects x where p_tab = 'projets' and x.owner_id = p_user and x.status = 'approved' and (coalesce(x.visibility, 'public') = 'public' or p_viewer = p_user)
    union all
    select x.id, x.title, x.price::text || ' FCFA', x.image_url, case when x.image_url is not null then 'image' end, x.created_at
      from listings x where p_tab = 'produits' and x.seller_id = p_user and x.status = 'approved' and x.showcase = false
        and (x.shop_id is null or p_viewer = p_user or exists (select 1 from shops s where s.id = x.shop_id and s.status = 'active'))
    union all
    select c.id, 'Clip : ' || l.title, c.len_sec::text || ' s', null::text, null::text, c.created_at
      from replay_clips c join live_recordings r on r.id = c.recording_id join lives l on l.id = r.live_id
      where p_tab = 'clips' and c.user_id = p_user and c.status = 'pret' and _replay_listing_access(c.recording_id, p_viewer) is not null
  ) s(id, title, subtitle, media_path, media_kind, ts)
$$;
revoke all on function _h13_creator_items(uuid, text, uuid) from public, anon, authenticated;

create or replace function _h13_creator_visible(p_user uuid) returns boolean language sql stable security definer set search_path = public as $$
  select p_user is not null and coalesce(p_user = auth.uid() or (
    exists (select 1 from profiles where id = p_user and not coalesce(suspended, false)) and profile_visible(p_user) and not coalesce(is_blocked_between(auth.uid(), p_user), false)), false)
$$;
revoke all on function _h13_creator_visible(uuid) from public, anon, authenticated;

create or replace function creator_profile_tabs(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t text; v jsonb := '{}'::jsonb; n integer;
begin
  if not _h13_creator_visible(p_user) then return null; end if;
  foreach t in array array['lives', 'publications', 'projets', 'produits', 'reposts', 'clips'] loop
    select count(*)::int into n from _h13_creator_items(p_user, t, auth.uid());
    v := v || jsonb_build_object(t, n);
  end loop;
  return jsonb_build_object('user', p_user, 'tabs', v);
end $$;
revoke all on function creator_profile_tabs(uuid) from public;
grant execute on function creator_profile_tabs(uuid) to anon, authenticated;

create or replace function creator_tab_items(p_user uuid, p_tab text, p_limit integer default 20, p_before_at timestamptz default null, p_before_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50); v_items jsonb; v_next jsonb; v_rows record; v_n integer := 0;
begin
  if p_tab not in ('lives', 'publications', 'projets', 'produits', 'reposts', 'clips') then raise exception 'Onglet inconnu'; end if;
  if not _h13_creator_visible(p_user) then return null; end if;
  v_items := '[]'::jsonb;
  if p_before_at is null then
    for v_rows in select i.*, true as pinned from _h13_creator_items(p_user, p_tab, auth.uid()) i join creator_pins k on k.item_id = i.id and k.user_id = p_user and k.tab = p_tab order by k.pinned_at desc, i.id loop
      v_items := v_items || jsonb_build_object('id', v_rows.id, 'title', v_rows.title, 'subtitle', v_rows.subtitle, 'media_path', v_rows.media_path, 'media_kind', v_rows.media_kind, 'at', v_rows.ts, 'pinned', true);
    end loop;
  end if;
  for v_rows in select i.* from _h13_creator_items(p_user, p_tab, auth.uid()) i
      where not exists (select 1 from creator_pins k where k.user_id = p_user and k.tab = p_tab and k.item_id = i.id)
        and (p_before_at is null or (i.ts, i.id) < (p_before_at, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
      order by i.ts desc, i.id desc limit v_limit + 1 loop
    v_n := v_n + 1;
    if v_n > v_limit then
      v_next := (select jsonb_build_object('before_at', last_at, 'before_id', last_id) from (select (v_items->-1->>'at')::timestamptz last_at, (v_items->-1->>'id')::uuid last_id) z);
      exit;
    end if;
    v_items := v_items || jsonb_build_object('id', v_rows.id, 'title', v_rows.title, 'subtitle', v_rows.subtitle, 'media_path', v_rows.media_path, 'media_kind', v_rows.media_kind, 'at', v_rows.ts, 'pinned', false);
  end loop;
  return jsonb_build_object('tab', p_tab, 'items', v_items, 'next', v_next);
end $$;
revoke all on function creator_tab_items(uuid, text, integer, timestamptz, uuid) from public;
grant execute on function creator_tab_items(uuid, text, integer, timestamptz, uuid) to anon, authenticated;

create or replace function creator_pin_set(p_tab text, p_item uuid, p_pin boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); v_n integer; v_changed boolean := false;
begin
  perform _assert_active();
  if p_tab not in ('lives', 'publications', 'projets', 'produits', 'reposts', 'clips') then raise exception 'Onglet inconnu'; end if;
  perform 1 from profiles where id = me for update;
  if coalesce(p_pin, true) then
    if not _h13_pin_eligible(me, p_tab, p_item) then raise exception 'Élément introuvable ou non publié : il ne peut pas être épinglé'; end if;
    delete from creator_pins k where k.user_id = me and k.tab = p_tab and not _h13_pin_eligible(me, p_tab, k.item_id);
    if not exists (select 1 from creator_pins where user_id = me and tab = p_tab and item_id = p_item) then
      select count(*)::int into v_n from creator_pins where user_id = me and tab = p_tab;
      if v_n >= 3 then raise exception 'Trois éléments épinglés au plus par onglet : désépinglez-en un d''abord'; end if;
      insert into creator_pins (user_id, tab, item_id) values (me, p_tab, p_item);
      v_changed := true;
    end if;
  else
    delete from creator_pins where user_id = me and tab = p_tab and item_id = p_item;
    v_changed := found;
  end if;
  return jsonb_build_object('tab', p_tab, 'item', p_item, 'pinned', coalesce(p_pin, true), 'changed', v_changed,
    'count', (select count(*)::int from creator_pins where user_id = me and tab = p_tab));
end $$;
revoke all on function creator_pin_set(text, uuid, boolean) from public, anon;
grant execute on function creator_pin_set(text, uuid, boolean) to authenticated;

create or replace function creator_pins_list(p_user uuid default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when not _h13_creator_visible(coalesce(p_user, auth.uid())) then null else coalesce((
    select jsonb_object_agg(t.tab, t.ids) from (
      select k.tab, jsonb_agg(k.item_id order by k.pinned_at desc) ids from creator_pins k
      where k.user_id = coalesce(p_user, auth.uid()) and exists (select 1 from _h13_creator_items(k.user_id, k.tab, auth.uid()) i where i.id = k.item_id)
      group by k.tab) t), '{}'::jsonb) end
$$;
revoke all on function creator_pins_list(uuid) from public;
grant execute on function creator_pins_list(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ visites : agrégats seulement
create or replace function profile_visit_record(p_user uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); n integer; d date := ((now() at time zone 'Africa/Douala'))::date;
begin
  if me is null or p_user is null or p_user = me then return false; end if;
  if exists (select 1 from profiles where id = me and coalesce(suspended, false)) then return false; end if;
  if not _h13_creator_visible(p_user) then return false; end if;
  insert into profile_visits (owner_id, day, visitor_key) values (p_user, d, md5(me::text || ':' || p_user::text || ':' || d::text)) on conflict do nothing;
  get diagnostics n = row_count;
  return n = 1;
end $$;
revoke all on function profile_visit_record(uuid) from public, anon;
grant execute on function profile_visit_record(uuid) to authenticated;

create or replace function creator_visit_stats(p_days integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d integer := least(greatest(coalesce(p_days, 30), 1), 365); v_since date := ((now() at time zone 'Africa/Douala'))::date - (least(greatest(coalesce(p_days, 30), 1), 365) - 1);
begin
  perform _assert_active();
  return jsonb_build_object('days', d, 'visits', (select count(*)::int from profile_visits where owner_id = auth.uid() and day >= v_since),
    'by_day', coalesce((select jsonb_agg(jsonb_build_object('day', x.day, 'visits', x.n) order by x.day) from (
      select day, count(*)::int n from profile_visits where owner_id = auth.uid() and day >= v_since group by day) x), '[]'::jsonb),
    'identities', false);
end $$;
revoke all on function creator_visit_stats(integer) from public, anon;
grant execute on function creator_visit_stats(integer) to authenticated;
