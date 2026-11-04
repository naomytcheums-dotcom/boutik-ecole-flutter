-- Talents visibles sans connexion (page d'accueil, liste des talents) et proposition de mission à un talent par message direct.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale isolée (supabase/tests/talents_local.sql).
-- Lecture seule pour talents_list ; start_direct_conversation écrit une conversation et un message (jamais sans connexion).
-- Retour arrière : drop function start_direct_conversation(uuid, text); et remettre talents_list de 20261104000200 (connexion requise).

create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'department', coalesce(t.department, ''), 'institution', coalesce(t.institution, ''),
                                        'skills', coalesce(t.skills, ''), 'city', coalesce(t.city, ''), 'avatar_url', t.avatar_url, 'certified', t.certification::text = 'approved'))
    from (
      select * from profiles
      where role::text = 'student' and not suspended and nullif(trim(coalesce(skills, '')), '') is not null
        and (coalesce(trim(p_query), '') = '' or name ilike '%' || trim(p_query) || '%' or skills ilike '%' || trim(p_query) || '%' or coalesce(department, '') ilike '%' || trim(p_query) || '%')
      order by (certification::text = 'approved') desc, created_at desc
      limit least(greatest(p_limit, 1), 50)
    ) t
  ), '[]'::jsonb);
$$;
revoke all on function talents_list(text, int) from public;
grant execute on function talents_list(text, int) to anon, authenticated;

-- Message direct (hors annonce) : retrouve la conversation entre les deux personnes ou la crée, puis ajoute le message.
create or replace function start_direct_conversation(p_user uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user and not suspended) then raise exception 'Destinataire introuvable'; end if;
  select c.id into cid from conversations c
    where c.listing_id is null
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = p_user)
      and (select count(*) from conversation_participants p where p.conversation_id = c.id) = 2
    limit 1;
  if cid is null then
    insert into conversations (listing_id, created_by) values (null, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id) values (cid, auth.uid()), (cid, p_user);
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;
revoke all on function start_direct_conversation(uuid, text) from public, anon;
grant execute on function start_direct_conversation(uuid, text) to authenticated;
