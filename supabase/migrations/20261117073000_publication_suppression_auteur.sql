-- Réseau social : l'auteur peut retirer sa propre publication (S7-8).
-- La publication passe au statut « removed » (invisible partout : fil, profil, republications, signalements clos, boosts supprimés) ; ses fichiers sont renvoyés
-- à l'application pour être effacés du stockage. Les republications vides qui la citaient disparaissent du fil (l'original n'est plus « published »).
-- Retour arrière : update posts set status = 'hidden' where status = 'removed' ; drop function delete_my_post(uuid) ; remettre posts_status_check et posts_kind_contenu
--   d'origine (20261101000600 et 20261114000900).

alter table posts drop constraint if exists posts_status_check;
alter table posts add constraint posts_status_check check (status in ('pending', 'published', 'hidden', 'removed'));

-- Régression de 20261114000900 : la contrainte de contenu refusait de nouveau une publication limitée à un lien ou à une republication sans commentaire,
-- alors que create_post_v2 et l'application les acceptent (20261110000000). On rétablit ces deux cas (publications de type « text » seulement).
alter table posts drop constraint if exists posts_kind_contenu;
alter table posts add constraint posts_kind_contenu check (
  (kind = 'media' and media_path is not null and media_kind is not null)
  or (kind in ('text', 'poll') and nullif(btrim(coalesce(body, '')), '') is not null)
  or (kind = 'text' and (link_url is not null or repost_of is not null)));

create or replace function delete_my_post(p_post uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare p posts%rowtype; v_paths jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from posts where id = p_post and author_id = auth.uid() and status in ('pending', 'published', 'hidden') for update;
  if not found then raise exception 'Publication introuvable'; end if;
  select coalesce(jsonb_agg(x.path), '[]'::jsonb) into v_paths from (
    select p.media_path as path where p.media_path is not null
    union select pm.path from post_media pm where pm.post_id = p.id) x;
  update posts set status = 'removed', review_note = 'Retirée par son auteur', pinned = false where id = p.id;
  delete from post_boosts where post_id = p.id;
  update post_reports set status = 'closed' where post_id = p.id and status = 'open';
  return jsonb_build_object('id', p.id, 'paths', v_paths);
end $$;
revoke all on function delete_my_post(uuid) from public, anon;
grant execute on function delete_my_post(uuid) to authenticated;
