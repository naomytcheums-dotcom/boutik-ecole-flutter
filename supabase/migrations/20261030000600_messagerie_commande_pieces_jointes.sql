-- Messagerie : conversations liées à une commande, pièces jointes et messages vocaux (stockage privé, accès réservé aux participants).

alter table conversations add column if not exists order_number text;
alter table messages add column if not exists kind text not null default 'text';
alter table messages add column if not exists attachment_path text;
alter table messages add column if not exists attachment_name text;
alter table messages add column if not exists attachment_size integer;
alter table messages drop constraint if exists messages_kind_check;
alter table messages add constraint messages_kind_check check (kind in ('text', 'image', 'file', 'voice'));
alter table messages drop constraint if exists messages_attach_ck;
alter table messages add constraint messages_attach_ck check (
  (kind = 'text' and attachment_path is null)
  or (kind <> 'text' and attachment_path is not null and attachment_size between 1 and 10485760));

-- une pièce jointe doit se trouver dans le dossier de LA conversation (<conversation_id>/…)
drop policy if exists "messages : envoi par un participant" on messages;
create policy "messages : envoi par un participant" on messages for insert
  with check (sender_id = auth.uid() and is_participant(conversation_id)
              and (attachment_path is null or attachment_path like conversation_id::text || '/%'));

-- Stockage privé : 10 Mo, images, PDF, documents, audio.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-files', 'chat-files', false, 10485760, array[
  'image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'text/plain',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/mpeg', 'audio/ogg', 'audio/webm', 'audio/aac', 'audio/wav'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function chat_file_allowed(object_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select case when split_part(object_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then is_participant(split_part(object_name, '/', 1)::uuid) else false end
$$;
drop policy if exists "chat : lecture par les participants" on storage.objects;
create policy "chat : lecture par les participants" on storage.objects for select to authenticated
  using (bucket_id = 'chat-files' and chat_file_allowed(name));
drop policy if exists "chat : depot par les participants" on storage.objects;
create policy "chat : depot par les participants" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-files' and chat_file_allowed(name));

-- Conversation liée à une commande : l'acheteur écrit au vendeur de la commande, ou le vendeur à l'acheteur.
create or replace function start_order_conversation(p_order text, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; seller uuid; other uuid; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  select * into o from orders where number = p_order;
  if not found then raise exception 'Commande introuvable'; end if;
  select l.seller_id into seller from order_lines ol join listings l on l.id = ol.listing_id
    where ol.order_id = o.id and l.seller_id is not null order by ol.id limit 1;
  if auth.uid() = o.buyer_id then
    if seller is null then raise exception 'Commande de la plateforme : pas de vendeur étudiant à qui écrire'; end if;
    other := seller;
  elsif exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = auth.uid()) then
    other := o.buyer_id;
  else
    raise exception 'Commande introuvable';
  end if;
  select c.id into cid from conversations c
    where c.order_number = o.number
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = other)
    limit 1;
  if cid is null then
    insert into conversations (order_number, created_by) values (o.number, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, other, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;
revoke all on function start_order_conversation(text, text) from public, anon;
grant execute on function start_order_conversation(text, text) to authenticated;

drop function if exists my_conversations();
create or replace function my_conversations()
returns table (id uuid, listing_title text, other_name text, last_body text, last_at timestamptz, unread integer, order_number text)
language sql stable security definer set search_path = public as $$
  select c.id, l.title, coalesce(op.name, 'Utilisateur'),
         (select case when m.kind = 'text' then m.body when m.kind = 'image' then 'Photo' when m.kind = 'voice' then 'Message vocal' else 'Fichier : ' || coalesce(m.attachment_name, '') end
            from messages m where m.conversation_id = c.id order by m.id desc limit 1),
         c.last_message_at,
         (select count(*)::int from messages m where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.created_at > p.last_read_at),
         c.order_number
  from conversations c
  join conversation_participants p on p.conversation_id = c.id and p.user_id = auth.uid()
  left join listings l on l.id = c.listing_id
  left join conversation_participants q on q.conversation_id = c.id and q.user_id <> auth.uid()
  left join profiles op on op.id = q.user_id
  order by c.last_message_at desc
$$;
revoke all on function my_conversations() from public, anon;
grant execute on function my_conversations() to authenticated;

select (select count(*) from storage.buckets where id = 'chat-files' and not public) as bucket_prive;

-- Suppression : l'expéditeur peut retirer ses propres pièces jointes (jamais celles de l'autre participant).
drop policy if exists "chat : suppression par l'expediteur" on storage.objects;
create policy "chat : suppression par l'expediteur" on storage.objects for delete to authenticated
  using (bucket_id = 'chat-files' and owner_id = auth.uid()::text);
