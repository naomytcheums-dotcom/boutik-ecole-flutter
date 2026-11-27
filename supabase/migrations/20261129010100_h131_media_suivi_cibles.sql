-- H13.1 MÉDIAS 2/3 : suivi de la bascule vers le stockage privé et cibles de lecture.
--  * media_migration : une ligne par fichier de « post-media » à protéger (file d'attente -> copié et vérifié) ; aucune suppression n'est faite ni déclenchée ici.
--  * post_media.storage_bucket : compartiment du fichier (« post-media » par défaut = comportement d'avant).
--  * _media_ref_state(chemin) : état du contenu qui référence un fichier, indépendant de la personne connectée :
--      public (publication publiée hors communauté fermée, histoire active, couverture/logo/offre/live) ; pending (publication en attente de validation) ;
--      restricted (publication retirée/masquée, communauté fermée, histoire expirée ou masquée, commentaire d'une publication non publique) ; unreferenced (brouillon, envoi jamais rattaché).
--  * post_media_signed_target(chemin) / post_media_targets(chemins) : disent si un fichier est dans le compartiment privé (=> URL signée à durée limitée) ou public.
-- Strictement additif. Retour arrière : drop function post_media_targets(text[]), post_media_signed_target(text), _media_ref_state(text) ; drop table media_migration ;
--   alter table post_media drop column storage_bucket.

alter table post_media add column if not exists storage_bucket text not null default 'post-media';
alter table post_media drop constraint if exists post_media_storage_bucket_check;
alter table post_media add constraint post_media_storage_bucket_check check (storage_bucket in ('post-media', 'post-media-private'));

create table if not exists media_migration (
  path text primary key check (char_length(path) between 3 and 400),
  source_bucket text not null default 'post-media' check (source_bucket = 'post-media'),
  target_bucket text not null default 'post-media-private' check (target_bucket = 'post-media-private'),
  status text not null default 'queued' check (status in ('queued', 'verified', 'failed', 'rolled_back')),
  reason text not null,
  reversible boolean not null default true,
  size_bytes bigint,
  note text not null default '',
  queued_at timestamptz not null default now(),
  verified_at timestamptz,
  rolled_back_at timestamptz,
  old_delete_marked_at timestamptz
);
create index if not exists media_migration_status on media_migration (status);
alter table media_migration enable row level security;
revoke all on media_migration from anon, authenticated;

-- Contenu public : visible de tout le monde (hors communauté fermée) ; contenu en attente : validation en cours ; sinon restreint.
create or replace function _media_post_public(p_post uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from posts p where p.id = p_post and p.status = 'published'
    and (p.community_id is null or exists (select 1 from communities c where c.id = p.community_id and c.privacy = 'public' and c.status = 'active')))
$$;
revoke all on function _media_post_public(uuid) from public, anon, authenticated;

create or replace function _media_ref_state(p_path text) returns text
language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from post_media pm where pm.path = p_path and _media_post_public(pm.post_id))
      or exists (select 1 from posts p where p.media_path = p_path and _media_post_public(p.id))
      or exists (select 1 from post_comments c where c.attachment_path = p_path and _media_post_public(c.post_id))
      or exists (select 1 from stories s where s.media_path = p_path and s.status = 'visible' and s.expires_at > now())
      or exists (select 1 from profile_covers x where x.path = p_path)
      or exists (select 1 from profiles x where x.cover_path = p_path)
      or exists (select 1 from communities x where x.logo_path = p_path or x.cover_path = p_path)
      or exists (select 1 from company_profiles x where x.logo_path = p_path or x.cover_path = p_path)
      or exists (select 1 from lives x where x.cover_path = p_path)
      or exists (select 1 from opportunities x where x.media_path = p_path) then 'public'
    when exists (select 1 from post_media pm join posts p on p.id = pm.post_id where pm.path = p_path and p.status = 'pending')
      or exists (select 1 from posts p where p.media_path = p_path and p.status = 'pending') then 'pending'
    when exists (select 1 from post_media pm where pm.path = p_path)
      or exists (select 1 from posts p where p.media_path = p_path)
      or exists (select 1 from post_comments c where c.attachment_path = p_path)
      or exists (select 1 from stories s where s.media_path = p_path) then 'restricted'
    else 'unreferenced' end
$$;
revoke all on function _media_ref_state(text) from public, anon, authenticated;

-- Le fichier est-il servi par le compartiment privé ? (objet présent dans « post-media-private » ; si le fichier est suivi par la bascule, seulement une fois « verified »)
create or replace function _media_in_private(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from storage.objects o where o.bucket_id = 'post-media-private' and o.name = p_path)
     and not exists (select 1 from media_migration m where m.path = p_path and m.status <> 'verified')
$$;
revoke all on function _media_in_private(text) from public, anon, authenticated;

create or replace function post_media_signed_target(p_path text) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when _media_in_private(p_path)
    then jsonb_build_object('bucket', 'post-media-private', 'signed', true, 'ttl_seconds', 3600)
    else jsonb_build_object('bucket', 'post-media', 'signed', false, 'ttl_seconds', 0) end
$$;
revoke all on function post_media_signed_target(text) from public;
grant execute on function post_media_signed_target(text) to anon, authenticated;

-- Lot de chemins (200 au plus) : renvoie seulement ceux qui doivent être signés ; les autres restent sur l'URL publique.
create or replace function post_media_targets(p_paths text[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(x.p, 'post-media-private'), '{}'::jsonb)
  from (select distinct p from unnest((coalesce(p_paths, '{}'::text[]))[1:200]) p where p is not null and _media_in_private(p)) x
$$;
revoke all on function post_media_targets(text[]) from public;
grant execute on function post_media_targets(text[]) to anon, authenticated;
