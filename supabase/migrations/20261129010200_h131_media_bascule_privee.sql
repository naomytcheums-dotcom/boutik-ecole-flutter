-- H13.1 MÉDIAS 3/3 : procédure de bascule des médias NON publics de « post-media » vers « post-media-private » (réservée au service_role : clé de service côté serveur, jamais dans l'application).
--  1. media_migrate_private_batch(limite, avec_orphelins) : place en file d'attente (media_migration) les fichiers dont TOUS les contenus sont restreints (publication retirée/masquée,
--     communauté fermée, histoire expirée/masquée, commentaire non public ; avec_orphelins : brouillons non rattachés de plus de 24 h) et renvoie les fichiers à copier. Les publications
--     en attente de validation et tout fichier encore utilisé par un contenu public ne sont JAMAIS touchés.
--  2. COPIE du fichier vers « post-media-private » (même chemin) : faite par l'API Storage (tool\backup\media_migrate_private.mjs, clé de service lue dans l'environnement) car une copie SQL
--     de la ligne de storage.objects ne déplace pas le contenu binaire.
--  3. media_migrate_confirm(chemin) : VÉRIFIE (objet présent dans le compartiment privé, même taille et même type que l'original) puis marque « verified »,
--     met à jour post_media.storage_bucket et MARQUE l'ancien fichier comme supprimable (old_delete_marked_at) : rien n'est supprimé.
--  4. media_old_deletion_candidates() : liste en lecture seule ce qu'un humain peut supprimer (vérifié, encore restreint, bascule non réversible). Aucune suppression automatique, jamais.
--  5. media_migrate_rollback(chemin) : annule la bascule (la lecture revient au compartiment public tant que l'ancien fichier existe) ; le fichier privé est conservé.
--  6. media_migration_report() : compteurs (fichiers par état, à protéger, encore exposés par URL publique, en file, vérifiés, échoués, supprimables).
-- Strictement additif. Retour arrière : drop function media_migration_report(), media_old_deletion_candidates(boolean), media_migrate_rollback(text), media_migrate_confirm(text),
--   media_migrate_private_batch(integer, boolean), _media_restrict_reason(text, boolean), _media_assert_service().

create or replace function _media_assert_service() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Réservé au service';
  end if;
end $$;
revoke all on function _media_assert_service() from public, anon, authenticated;

create or replace function _media_restrict_reason(p_path text, p_orphans boolean default false) returns table (reason text, reversible boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_state text := _media_ref_state(p_path);
begin
  if v_state = 'unreferenced' then
    if coalesce(p_orphans, false) then return query select 'orphan'::text, true; end if;
    return;
  end if;
  if v_state <> 'restricted' then return; end if;
  if exists (select 1 from post_media pm join posts p on p.id = pm.post_id where pm.path = p_path and p.status = 'removed')
     or exists (select 1 from posts p where p.media_path = p_path and p.status = 'removed') then
    return query select 'post_removed'::text, false;
  elsif exists (select 1 from stories s where s.media_path = p_path and s.expires_at <= now()) then
    return query select 'story_expired'::text, false;
  elsif exists (select 1 from stories s where s.media_path = p_path and s.status = 'hidden') then
    return query select 'story_hidden'::text, true;
  elsif exists (select 1 from post_media pm join posts p on p.id = pm.post_id where pm.path = p_path and p.status = 'hidden')
     or exists (select 1 from posts p where p.media_path = p_path and p.status = 'hidden') then
    return query select 'post_hidden'::text, true;
  elsif exists (select 1 from post_media pm join posts p on p.id = pm.post_id where pm.path = p_path and p.community_id is not null)
     or exists (select 1 from posts p where p.media_path = p_path and p.community_id is not null) then
    return query select 'community_closed'::text, true;
  elsif exists (select 1 from post_comments c where c.attachment_path = p_path) then
    return query select 'comment_inaccessible'::text, true;
  else
    return query select 'restricted_other'::text, true;
  end if;
end $$;
revoke all on function _media_restrict_reason(text, boolean) from public, anon, authenticated;

create or replace function media_migrate_private_batch(p_limit integer default 50, p_include_orphans boolean default false)
returns table (path text, reason text, status text, size_bytes bigint)
language plpgsql security definer set search_path = public as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 500);
begin
  perform _media_assert_service();
  insert into media_migration (path, reason, reversible, size_bytes)
  select o.name, r.reason, r.reversible, nullif(o.metadata->>'size', '')::bigint
  from storage.objects o
  cross join lateral _media_restrict_reason(o.name, p_include_orphans) r
  where o.bucket_id = 'post-media'
    and (r.reason <> 'orphan' or o.created_at < now() - interval '1 day')
    and not exists (select 1 from media_migration m where m.path = o.name)
  order by o.created_at, o.name
  limit v_lim
  on conflict on constraint media_migration_pkey do nothing;
  return query select m.path, m.reason, m.status, m.size_bytes from media_migration m
    where m.status in ('queued', 'failed') order by m.queued_at, m.path limit v_lim;
end $$;
revoke all on function media_migrate_private_batch(integer, boolean) from public, anon, authenticated;
grant execute on function media_migrate_private_batch(integer, boolean) to service_role;

create or replace function media_migrate_confirm(p_path text) returns text
language plpgsql security definer set search_path = public as $$
declare m media_migration; v_src jsonb; v_dst jsonb; v_dst_found boolean;
begin
  perform _media_assert_service();
  select * into m from media_migration where path = p_path;
  if not found then raise exception 'Fichier absent de la file de bascule'; end if;
  if m.status = 'rolled_back' then raise exception 'Bascule annulée pour ce fichier'; end if;
  select o.metadata into v_dst from storage.objects o where o.bucket_id = 'post-media-private' and o.name = p_path limit 1;
  v_dst_found := found;
  if not v_dst_found then
    update media_migration set note = 'copie absente du compartiment privé' where path = p_path;
    return 'missing_destination';
  end if;
  select o.metadata into v_src from storage.objects o where o.bucket_id = 'post-media' and o.name = p_path limit 1;
  if v_src is not null and (
       (nullif(v_src->>'size', '') is not null and nullif(v_dst->>'size', '') is not null and (v_src->>'size')::bigint <> (v_dst->>'size')::bigint)
    or (nullif(v_src->>'mimetype', '') is not null and nullif(v_dst->>'mimetype', '') is not null and v_src->>'mimetype' <> v_dst->>'mimetype')) then
    update media_migration set status = 'failed', note = 'taille ou type différents entre l''original et la copie' where path = p_path;
    return 'failed';
  end if;
  update media_migration set status = 'verified', verified_at = now(), old_delete_marked_at = now(), note = '',
         size_bytes = coalesce(nullif(v_dst->>'size', '')::bigint, size_bytes)
   where path = p_path;
  update post_media set storage_bucket = 'post-media-private' where post_media.path = p_path;
  return 'verified';
end $$;
revoke all on function media_migrate_confirm(text) from public, anon, authenticated;
grant execute on function media_migrate_confirm(text) to service_role;

create or replace function media_migrate_rollback(p_path text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare m media_migration; v_done integer := 0; v_skipped integer := 0;
begin
  perform _media_assert_service();
  for m in select * from media_migration where status <> 'rolled_back' and (p_path is null or path = p_path) order by path loop
    if m.status = 'verified' and not exists (select 1 from storage.objects o where o.bucket_id = 'post-media' and o.name = m.path) then
      if p_path is not null then raise exception 'Ancien fichier absent de post-media : recopier depuis post-media-private avant le retour arrière'; end if;
      v_skipped := v_skipped + 1;
      continue;
    end if;
    update media_migration set status = 'rolled_back', rolled_back_at = now(), old_delete_marked_at = null where path = m.path;
    update post_media set storage_bucket = 'post-media' where post_media.path = m.path;
    v_done := v_done + 1;
  end loop;
  if p_path is not null and v_done = 0 then raise exception 'Fichier absent de la file de bascule'; end if;
  return jsonb_build_object('rolled_back', v_done, 'skipped', v_skipped);
end $$;
revoke all on function media_migrate_rollback(text) from public, anon, authenticated;
grant execute on function media_migrate_rollback(text) to service_role;

-- Lecture seule : ce qu'un humain peut supprimer de « post-media » (jamais fait par la base).
create or replace function media_old_deletion_candidates(p_include_reversible boolean default false)
returns table (path text, reason text, verified_at timestamptz, size_bytes bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _media_assert_service();
  return query
    select m.path, m.reason, m.verified_at, m.size_bytes from media_migration m
    where m.status = 'verified' and m.old_delete_marked_at is not null
      and (m.reversible = false or coalesce(p_include_reversible, false))
      and exists (select 1 from storage.objects o where o.bucket_id = 'post-media' and o.name = m.path)
      and exists (select 1 from storage.objects o where o.bucket_id = 'post-media-private' and o.name = m.path)
      and _media_ref_state(m.path) in ('restricted', 'unreferenced')
    order by m.verified_at, m.path;
end $$;
revoke all on function media_old_deletion_candidates(boolean) from public, anon, authenticated;
grant execute on function media_old_deletion_candidates(boolean) to service_role;

create or replace function media_migration_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  perform _media_assert_service();
  with o as (
    select o.name, _media_ref_state(o.name) st, (m.path is not null) tracked, m.status mst
    from storage.objects o left join media_migration m on m.path = o.name
    where o.bucket_id = 'post-media')
  select jsonb_build_object(
    'public_bucket_objects', (select count(*) from o),
    'public_content', (select count(*) from o where st = 'public'),
    'pending_review', (select count(*) from o where st = 'pending'),
    'restricted', (select count(*) from o where st = 'restricted'),
    'unreferenced', (select count(*) from o where st = 'unreferenced'),
    'still_exposed_by_public_url', (select count(*) from o where st = 'restricted'),
    'to_queue', (select count(*) from o where st = 'restricted' and not tracked),
    'queued', (select count(*) from media_migration where status = 'queued'),
    'verified', (select count(*) from media_migration where status = 'verified'),
    'failed', (select count(*) from media_migration where status = 'failed'),
    'rolled_back', (select count(*) from media_migration where status = 'rolled_back'),
    'private_bucket_objects', (select count(*) from storage.objects where bucket_id = 'post-media-private'),
    'old_deletable', (select count(*) from media_old_deletion_candidates(false)),
    'old_deletable_reversible_included', (select count(*) from media_old_deletion_candidates(true)),
    'generated_at', now()) into v;
  return v;
end $$;
revoke all on function media_migration_report() from public, anon, authenticated;
grant execute on function media_migration_report() to service_role;
