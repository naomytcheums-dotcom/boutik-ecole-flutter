-- H13.1 MÉDIAS 1/3 : compartiment PRIVÉ « post-media-private » pour les médias non publics (histoires, publications de communautés fermées, médias retirés ou masqués).
--  * Le compartiment « post-media » reste public (URL anciennes des contenus publics inchangées) ; il n'est PAS modifié ici.
--  * « post-media-private » : public = false => l'URL /object/public/ ne marche pas ; seule une URL signée (créée par une personne que la politique de lecture autorise) ou
--    l'API authentifiée donne accès. Même limite de taille et mêmes types que post-media.
--  * Lecture : le propriétaire (dossier <uid>/), la modération, ou si le contenu qui référence le fichier est accessible à la personne (publication accessible, histoire active et visible,
--    commentaire d'une publication accessible). Un fichier non référencé (brouillon, envoi en cours) n'est lisible que par son propriétaire et la modération.
--  * Dépôt, modification, suppression : seulement dans son dossier <uid>/.
-- Strictement additif. Retour arrière : drop policy « médias privés : … » on storage.objects (4) ; drop function _post_media_private_readable(text) ;
--   le compartiment (et ses objets) n'est supprimé qu'à la main, après avoir copié les fichiers (voir docs\transformation\H131_MATRICE_ACCES_MEDIAS.md).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-media-private', 'post-media-private', false,
        coalesce((select file_size_limit from storage.buckets where id = 'post-media'), 52428800),
        coalesce((select allowed_mime_types from storage.buckets where id = 'post-media'),
                 array['video/mp4', 'video/quicktime', 'image/jpeg', 'image/png', 'image/webp', 'image/gif']))
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function _post_media_private_readable(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (auth.uid() is not null and auth.uid()::text = (string_to_array(p_name, '/'))[1])
    or (auth.uid() is not null and _staff_perm(array['security.moderation', 'security.reports']))
    or exists (select 1 from post_media pm join posts p on p.id = pm.post_id where pm.path = p_name and _post_accessible(p.id))
    or exists (select 1 from posts p where p.media_path = p_name and _post_accessible(p.id))
    or exists (select 1 from post_comments c where c.attachment_path = p_name and _post_accessible(c.post_id))
    or exists (select 1 from stories s join profiles a on a.id = s.author_id and not coalesce(a.suspended, false)
               where s.media_path = p_name and s.status = 'visible' and s.expires_at > now()
                 and profile_visible(s.author_id) and not is_blocked_between(auth.uid(), s.author_id)),
    false)
$$;
revoke all on function _post_media_private_readable(text) from public;
grant execute on function _post_media_private_readable(text) to anon, authenticated;

drop policy if exists "médias privés : lecture" on storage.objects;
create policy "médias privés : lecture" on storage.objects for select
  using (bucket_id = 'post-media-private' and _post_media_private_readable(name));

drop policy if exists "médias privés : dépôt dans son dossier" on storage.objects;
create policy "médias privés : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'post-media-private' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "médias privés : modification dans son dossier" on storage.objects;
create policy "médias privés : modification dans son dossier" on storage.objects for update to authenticated
  using (bucket_id = 'post-media-private' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'post-media-private' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "médias privés : suppression dans son dossier" on storage.objects;
create policy "médias privés : suppression dans son dossier" on storage.objects for delete to authenticated
  using (bucket_id = 'post-media-private' and (storage.foldername(name))[1] = auth.uid()::text);
