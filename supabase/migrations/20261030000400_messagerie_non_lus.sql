-- Correctif : le premier message d'une conversation doit compter comme non lu pour le vendeur
-- (son entrée dans la conversation avait le même horodatage que le message, donc created_at > last_read_at était faux).
create or replace function start_conversation(p_listing uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found then raise exception 'Annonce introuvable'; end if;
  if l.seller_id is null then raise exception 'Annonce de la plateforme : contactez le support'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  select c.id into cid from conversations c
    where c.listing_id = l.id
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = l.seller_id)
    limit 1;
  if cid is null then
    insert into conversations (listing_id, created_by) values (l.id, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, l.seller_id, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;
revoke all on function start_conversation(uuid, text) from public, anon;
grant execute on function start_conversation(uuid, text) to authenticated;
