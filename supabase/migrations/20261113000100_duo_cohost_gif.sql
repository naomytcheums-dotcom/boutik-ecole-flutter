-- Réseau social, troisième série : duo et remix de vidéos, co-diffusion en Live, GIF autorisés dans les médias.
-- Non destructif : colonnes et tables ajoutées ; le seul changement existant est l'ajout de image/gif aux types acceptés.
-- Retour arrière : alter table posts drop column remix_of, drop column remix_kind ; drop table live_cohosts ;
--                  drop function create_remix, request_cohost, respond_cohost, my_cohost_status, list_cohost_requests, remove_cohost ;
--                  retirer image/gif de storage.buckets.allowed_mime_types pour post-media.

-- ------------------------------------------------------------------ GIF
update storage.buckets set allowed_mime_types = (select array(select distinct unnest(allowed_mime_types || array['image/gif']))) where id = 'post-media';

-- ------------------------------------------------------------------ duo et remix
alter table posts add column if not exists remix_of uuid references posts(id) on delete set null;
alter table posts add column if not exists remix_kind text check (remix_kind is null or remix_kind in ('duet', 'remix'));
create index if not exists posts_remix on posts (remix_of) where remix_of is not null;

-- Publie une vidéo « en duo » (côte à côte avec l'originale) ou « en remix » (réponse qui renvoie vers l'originale).
create or replace function create_remix(p_original uuid, p_kind text, p_path text, p_caption text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare res jsonb; orig posts%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('duet', 'remix') then raise exception 'Type invalide'; end if;
  select * into orig from posts where id = p_original and status = 'published' and media_kind = 'video';
  if not found then raise exception 'La vidéo d''origine est introuvable'; end if;
  res := create_post_v2(p_caption, jsonb_build_array(jsonb_build_object('path', p_path, 'kind', 'video')), null, '{}'::text[], null, null);
  update posts set remix_of = p_original, remix_kind = p_kind where id = (res->>'id')::uuid;
  return res;
end $$;
revoke all on function create_remix(uuid, text, text, text) from public, anon;
grant execute on function create_remix(uuid, text, text, text) to authenticated;

-- ------------------------------------------------------------------ co-diffusion en Live
create table if not exists live_cohosts (
  live_id uuid not null references lives(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'requested' check (status in ('requested', 'approved', 'refused', 'removed')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  primary key (live_id, user_id)
);
alter table live_cohosts enable row level security;
revoke all on live_cohosts from anon, authenticated;

create or replace function request_cohost(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live and status = 'live';
  if not found then raise exception 'Ce live n''est pas en direct'; end if;
  if l.host_id = auth.uid() then raise exception 'Vous êtes déjà l''hôte de ce live'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Vous ne pouvez pas participer à ce live'; end if;
  insert into live_cohosts (live_id, user_id, status) values (p_live, auth.uid(), 'requested')
  on conflict (live_id, user_id) do update set status = case when live_cohosts.status = 'approved' then 'approved' else 'requested' end, decided_at = null;
  return 'demandée';
end $$;

create or replace function respond_cohost(p_live uuid, p_user uuid, p_approve boolean) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from lives where id = p_live and host_id = auth.uid() and status = 'live') then raise exception 'Réservé à l''hôte du live en cours'; end if;
  if p_approve and (select count(*) from live_cohosts where live_id = p_live and status = 'approved') >= 3 then raise exception '3 invités au plus en même temps'; end if;
  update live_cohosts set status = case when p_approve then 'approved' else 'refused' end, decided_at = now()
  where live_id = p_live and user_id = p_user and status in ('requested', 'approved');
  if not found then raise exception 'Demande introuvable'; end if;
  return case when p_approve then 'acceptée' else 'refusée' end;
end $$;

create or replace function remove_cohost(p_live uuid, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from lives where id = p_live and host_id = auth.uid()) and p_user <> auth.uid() then raise exception 'Réservé à l''hôte'; end if;
  update live_cohosts set status = 'removed', decided_at = now() where live_id = p_live and user_id = p_user and status in ('requested', 'approved');
  return 'retiré';
end $$;

create or replace function my_cohost_status(p_live uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select status from live_cohosts where live_id = p_live and user_id = auth.uid()), 'none')
$$;

create or replace function list_cohost_requests(p_live uuid) returns table (user_id uuid, name text, avatar text, status text)
language sql stable security definer set search_path = public as $$
  select c.user_id, coalesce(nullif(trim(p.name), ''), 'Membre'), p.avatar_url, c.status
  from live_cohosts c join profiles p on p.id = c.user_id
  where c.live_id = p_live and c.status in ('requested', 'approved')
    and exists (select 1 from lives l where l.id = p_live and l.host_id = auth.uid())
  order by (c.status = 'requested') desc, c.created_at
$$;

revoke all on function request_cohost(uuid), respond_cohost(uuid, uuid, boolean), remove_cohost(uuid, uuid), my_cohost_status(uuid), list_cohost_requests(uuid) from public, anon;
grant execute on function request_cohost(uuid), respond_cohost(uuid, uuid, boolean), remove_cohost(uuid, uuid), my_cohost_status(uuid), list_cohost_requests(uuid) to authenticated;
