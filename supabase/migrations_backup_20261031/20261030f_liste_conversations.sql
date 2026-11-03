-- Liste de mes conversations (interlocuteur, annonce, dernier message, non-lus). Les noms ne sont visibles que des participants de la conversation.
create or replace function my_conversations()
returns table (id uuid, listing_title text, other_name text, last_body text, last_at timestamptz, unread integer)
language sql stable security definer set search_path = public as $$
  select c.id,
         l.title,
         coalesce(op.name, 'Utilisateur'),
         (select m.body from messages m where m.conversation_id = c.id order by m.id desc limit 1),
         c.last_message_at,
         (select count(*)::int from messages m where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.created_at > p.last_read_at)
  from conversations c
  join conversation_participants p on p.conversation_id = c.id and p.user_id = auth.uid()
  left join listings l on l.id = c.listing_id
  left join conversation_participants q on q.conversation_id = c.id and q.user_id <> auth.uid()
  left join profiles op on op.id = q.user_id
  order by c.last_message_at desc
$$;
revoke all on function my_conversations() from public, anon;
grant execute on function my_conversations() to authenticated;

-- Annonce et vendeur d'un titre (pour « Contacter le vendeur » depuis une commande) : seulement les annonces publiées.
create or replace function listing_contact(p_title text)
returns table (listing_id uuid, has_seller boolean)
language sql stable security definer set search_path = public as $$
  select id, seller_id is not null from listings where title = p_title and status = 'approved' order by (seller_id is null) limit 1
$$;
revoke all on function listing_contact(text) from public, anon;
grant execute on function listing_contact(text) to authenticated;
