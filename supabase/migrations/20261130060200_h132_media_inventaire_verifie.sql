-- H13.2 (agent 6) MÉDIAS : inventaire par objet et confirmation vérifiée (SHA-256) de la bascule des anciens médias de « post-media » vers « post-media-private ».
--  1. media_inventory_objects(après, limite) : une ligne par objet de post-media (type de référence, état de confidentialité, motif, taille, type MIME, copie privée présente,
--     état de la bascule), pagination par nom. Lecture seule, réservée au service_role. Aucune donnée personnelle hors le chemin (qui contient l'identifiant du dossier) :
--     l'outil d'exploitation ne l'écrit jamais dans ses rapports.
--  2. media_inventory_buckets() : objets et octets par compartiment (lecture seule, service_role).
--  3. media_migration.sha256 / verified_size : empreinte et taille constatées par l'outil sur l'ORIGINAL et la COPIE (identiques).
--  4. media_migrate_confirm_checked(chemin, sha256, taille) : exige une empreinte valide et une taille égale à celle du stockage, puis applique media_migrate_confirm (qui ne met à jour
--     post_media.storage_bucket qu'une fois la copie vérifiée) et enregistre l'empreinte. Rien n'est supprimé, nulle part.
-- Strictement additive. Retour arrière : drop function media_migrate_confirm_checked(text, text, bigint), media_inventory_buckets(), media_inventory_objects(text, integer), _media_ref_kind(text) ;
--   alter table media_migration drop column sha256, drop column verified_size (facultatif : colonnes nullables).

alter table media_migration add column if not exists sha256 text;
alter table media_migration add column if not exists verified_size bigint;

create or replace function _media_ref_kind(p_path text) returns text
language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from post_media pm where pm.path = p_path) then 'post_media'
    when exists (select 1 from posts p where p.media_path = p_path) then 'post'
    when exists (select 1 from post_comments c where c.attachment_path = p_path) then 'comment'
    when exists (select 1 from stories s where s.media_path = p_path) then 'story'
    when exists (select 1 from profile_covers x where x.path = p_path) or exists (select 1 from profiles x where x.cover_path = p_path) then 'profile_cover'
    when exists (select 1 from communities x where x.logo_path = p_path or x.cover_path = p_path) then 'community'
    when exists (select 1 from company_profiles x where x.logo_path = p_path or x.cover_path = p_path) then 'organization'
    when exists (select 1 from lives x where x.cover_path = p_path) then 'live'
    when exists (select 1 from opportunities x where x.media_path = p_path) then 'opportunity'
    else 'none' end
$$;
revoke all on function _media_ref_kind(text) from public, anon, authenticated;

create or replace function media_inventory_objects(p_after text default null, p_limit integer default 200)
returns table (path text, size_bytes bigint, mimetype text, created_at timestamptz, state text, reference_kind text, reason text, reversible boolean, in_private boolean, migration_status text)
language plpgsql stable security definer set search_path = public as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 200), 1), 1000);
begin
  perform _media_assert_service();
  return query
    select o.name, nullif(o.metadata->>'size', '')::bigint, o.metadata->>'mimetype', o.created_at,
           _media_ref_state(o.name), _media_ref_kind(o.name),
           (select r.reason from _media_restrict_reason(o.name, true) r limit 1),
           (select r.reversible from _media_restrict_reason(o.name, true) r limit 1),
           exists (select 1 from storage.objects d where d.bucket_id = 'post-media-private' and d.name = o.name),
           (select m.status from media_migration m where m.path = o.name)
    from storage.objects o
    where o.bucket_id = 'post-media' and (p_after is null or o.name > p_after)
    order by o.name
    limit v_lim;
end $$;
revoke all on function media_inventory_objects(text, integer) from public, anon, authenticated;
grant execute on function media_inventory_objects(text, integer) to service_role;

create or replace function media_inventory_buckets() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _media_assert_service();
  return coalesce((select jsonb_agg(jsonb_build_object('bucket', b.id, 'public', b.public, 'objects', coalesce(x.n, 0), 'bytes', coalesce(x.s, 0)) order by b.id)
    from storage.buckets b
    left join (select bucket_id, count(*) n, sum(nullif(metadata->>'size', '')::bigint) s from storage.objects group by bucket_id) x on x.bucket_id = b.id), '[]'::jsonb);
end $$;
revoke all on function media_inventory_buckets() from public, anon, authenticated;
grant execute on function media_inventory_buckets() to service_role;

create or replace function media_migrate_confirm_checked(p_path text, p_sha256 text, p_size bigint) returns text
language plpgsql security definer set search_path = public as $$
declare v_dst jsonb; v_res text;
begin
  perform _media_assert_service();
  if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then raise exception 'Empreinte SHA-256 invalide'; end if;
  if p_size is null or p_size < 0 then raise exception 'Taille invalide'; end if;
  select o.metadata into v_dst from storage.objects o where o.bucket_id = 'post-media-private' and o.name = p_path limit 1;
  if v_dst is not null and nullif(v_dst->>'size', '') is not null and (v_dst->>'size')::bigint <> p_size then
    update media_migration set status = 'failed', note = 'taille constatée par l''outil différente de celle du stockage' where path = p_path;
    return 'failed';
  end if;
  v_res := media_migrate_confirm(p_path);
  if v_res = 'verified' then
    update media_migration set sha256 = p_sha256, verified_size = p_size where path = p_path;
  end if;
  return v_res;
end $$;
revoke all on function media_migrate_confirm_checked(text, text, bigint) from public, anon, authenticated;
grant execute on function media_migrate_confirm_checked(text, text, bigint) to service_role;
