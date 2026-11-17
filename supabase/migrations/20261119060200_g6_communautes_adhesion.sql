-- G6 (profil étudiant) : adhésion, départ, décision de demande et bannissement dans les communautés.
-- Corrige : un compte suspendu pouvait rejoindre une communauté ou être accepté ; quitter une
-- communauté dont on n'est pas membre (ou dont on est banni) répondait « left » à tort ; une demande
-- pouvait être acceptée dans une communauté non active ; bannir un profil inexistant levait une
-- erreur technique. Les droits (rangs, confidentialité, notifications) des définitions de
-- 20261103000100 sont conservés.
-- Retour arrière : rejouer les définitions de join_community / leave_community / decide_join_request /
-- ban_member de 20261103000100_communautes_notifications_sociales.sql.

create or replace function join_community(p_community uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c communities%rowtype; m community_members%rowtype; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _account_active(auth.uid()) then raise exception 'Compte suspendu : adhésion impossible'; end if;
  select * into c from communities where id = p_community and status = 'active';
  if not found then raise exception 'Communauté introuvable'; end if;
  select * into m from community_members where community_id = p_community and user_id = auth.uid();
  if found then
    if m.status = 'banned' then raise exception 'Accès refusé à cette communauté'; end if;
    if m.status = 'active' then return 'already'; end if;
    if m.status = 'pending' then return 'pending'; end if;
    update community_members set status = 'active' where community_id = p_community and user_id = auth.uid(); -- invitation acceptée
    return 'joined';
  end if;
  if c.privacy = 'invite' then raise exception 'Cette communauté est accessible sur invitation seulement'; end if;
  if c.privacy = 'approval' then
    insert into community_members (community_id, user_id, role, status) values (p_community, auth.uid(), 'member', 'pending');
    for r in select user_id from community_members where community_id = p_community and status = 'active' and role in ('owner', 'admin', 'moderator') loop
      perform notify_user(r.user_id, 'community_request', 'Demande d’adhésion', display_name(auth.uid()) || ' demande à rejoindre « ' || c.name || ' ».', jsonb_build_object('community', p_community, 'user', auth.uid()));
    end loop;
    return 'pending';
  end if;
  insert into community_members (community_id, user_id, role, status) values (p_community, auth.uid(), 'member', 'active');
  return 'joined';
end $$;

create or replace function leave_community(p_community uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m community_members%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from community_members where community_id = p_community and user_id = auth.uid();
  if not found then raise exception 'Vous n’êtes pas lié(e) à cette communauté'; end if;
  if m.status = 'banned' then raise exception 'Accès refusé à cette communauté'; end if;
  if m.role = 'owner' then raise exception 'Le propriétaire ne peut pas quitter la communauté'; end if;
  delete from community_members where community_id = p_community and user_id = auth.uid() and status <> 'banned';
  return 'left';
end $$;

create or replace function decide_join_request(p_community uuid, p_user uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c communities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 and not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  select * into c from communities where id = p_community;
  if not found then raise exception 'Communauté introuvable'; end if;
  if not exists (select 1 from community_members where community_id = p_community and user_id = p_user and status = 'pending') then raise exception 'Aucune demande en attente'; end if;
  if p_accept then
    if c.status <> 'active' then raise exception 'Cette communauté n’est pas active'; end if;
    if not _account_active(p_user) then raise exception 'Ce compte est suspendu : la demande ne peut pas être acceptée'; end if;
    update community_members set status = 'active' where community_id = p_community and user_id = p_user;
    perform notify_user(p_user, 'community_accept', 'Demande acceptée', 'Vous avez rejoint « ' || c.name || ' ».', jsonb_build_object('community', p_community));
    return 'accepted';
  end if;
  delete from community_members where community_id = p_community and user_id = p_user and status = 'pending';
  perform notify_user(p_user, 'community_reject', 'Demande refusée', 'Votre demande pour « ' || c.name || ' » n’a pas été acceptée.', jsonb_build_object('community', p_community));
  return 'rejected';
end $$;

create or replace function ban_member(p_community uuid, p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare mine integer; theirs integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  mine := community_rank(p_community, auth.uid()); theirs := community_rank(p_community, p_user);
  if mine < 2 then raise exception 'Action non autorisée'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous bannir vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'Profil introuvable'; end if;
  if theirs >= mine then raise exception 'Vous ne pouvez pas bannir un rang égal ou supérieur'; end if;
  insert into community_members (community_id, user_id, role, status) values (p_community, p_user, 'member', 'banned')
    on conflict (community_id, user_id) do update set status = 'banned', role = 'member';
  return 'banned';
end $$;

revoke all on function join_community(uuid), leave_community(uuid), decide_join_request(uuid, uuid, boolean), ban_member(uuid, uuid) from public, anon;
grant execute on function join_community(uuid), leave_community(uuid), decide_join_request(uuid, uuid, boolean), ban_member(uuid, uuid) to authenticated;
