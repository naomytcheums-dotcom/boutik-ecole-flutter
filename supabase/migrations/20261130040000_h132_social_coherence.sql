-- H13.2 agent 4 SOCIAL : cohérence des notifications et des compteurs.
--  * Réponse à un commentaire : l'auteur du commentaire parent est notifié (une fois, jamais soi-même, jamais un compte suspendu ou bloqué) ;
--    l'auteur de la publication n'est pas notifié deux fois pour le même commentaire.
--  * Nouveau commentaire / nouveau message : aucune notification vers un compte suspendu, ni vers un compte qui a bloqué l'auteur (ou inversement).
--  * Compteur d'abonnés / d'abonnements : ne compte que les comptes affichés dans les listes (rôles publics, non suspendus, profil non privé, non bloqués avec le propriétaire),
--    pour que le chiffre annoncé soit toujours égal à la liste.
-- Strictement additif. Retour arrière : recréer trg_notify_comment depuis 20261103000100, on_message_inserted depuis 20261030000300 et _h13_follow_counts depuis 20261128050100 ;
--   drop function _h132_countable(uuid, uuid).

-- Compte affichable dans une liste d'abonnés, indépendamment de l'appelant (mêmes règles que _h131_listable, sans la visibilité propre à l'appelant).
create or replace function _h132_countable(p_id uuid, p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p
    where p.id = p_id and not coalesce(p.suspended, false) and p.profile_visibility <> 'private'
      and (p.role::text in ('student', 'company', 'other')
           or (p.role::text not in ('admin', 'direction', 'finance', 'support', 'client', 'visitor')
               and (exists (select 1 from posts x where x.author_id = p.id and x.status = 'published' and x.community_id is null)
                 or exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')))))
    and not exists (select 1 from user_blocks b where (b.blocker_id = p_id and b.blocked_id = p_owner) or (b.blocker_id = p_owner and b.blocked_id = p_id))
$$;
revoke all on function _h132_countable(uuid, uuid) from public, anon, authenticated;

create or replace function _h13_follow_counts(p_user uuid) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'followers', (select count(*)::int from engagements e
                   where e.kind = 'follow' and e.ref = p_user::text and e.status = 'active' and e.user_id <> p_user and _h132_countable(e.user_id, p_user)),
    'following', (select count(*)::int from engagements e
                   where e.kind = 'follow' and e.user_id = p_user and e.status = 'active' and e.ref <> p_user::text
                     and e.ref ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' and _h132_countable(e.ref::uuid, p_user)))
$$;
revoke all on function _h13_follow_counts(uuid) from public, anon, authenticated;

-- Le destinataire peut-il recevoir une notification venant de p_from ?
create or replace function _h132_can_notify(p_to uuid, p_from uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_to is not null and p_to is distinct from p_from
     and exists (select 1 from profiles t where t.id = p_to and not coalesce(t.suspended, false))
     and not exists (select 1 from user_blocks b where (b.blocker_id = p_to and b.blocked_id = p_from) or (b.blocker_id = p_from and b.blocked_id = p_to))
$$;
revoke all on function _h132_can_notify(uuid, uuid) from public, anon, authenticated;

create or replace function trg_notify_comment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_author uuid; v_parent uuid;
begin
  select author_id into v_author from posts where id = new.post_id;
  if new.parent_id is not null then
    select author_id into v_parent from post_comments where id = new.parent_id;
    if _h132_can_notify(v_parent, new.author_id) then
      perform notify_user(v_parent, 'comment', 'Réponse à votre commentaire', display_name(new.author_id) || ' a répondu à votre commentaire.',
                          jsonb_build_object('post', new.post_id, 'comment', new.id, 'parent', new.parent_id));
    end if;
  end if;
  if v_author is distinct from v_parent and _h132_can_notify(v_author, new.author_id) then
    perform notify_user(v_author, 'comment', 'Nouveau commentaire', display_name(new.author_id) || ' a commenté votre publication.', jsonb_build_object('post', new.post_id, 'comment', new.id));
  end if;
  return null;
end $$;

create or replace function on_message_inserted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update conversations set last_message_at = new.created_at where id = new.conversation_id;
  update conversation_participants set last_read_at = new.created_at where conversation_id = new.conversation_id and user_id = new.sender_id;
  insert into notifications (user_id, kind, title, body, data)
    select p.user_id, 'message', 'Nouveau message', left(new.body, 120), jsonb_build_object('conversation_id', new.conversation_id)
    from conversation_participants p
    where p.conversation_id = new.conversation_id and p.user_id <> new.sender_id and _h132_can_notify(p.user_id, new.sender_id);
  return null;
end $$;
