-- H10 SOCIAL : droits de modération d'un live, côté SQL.
-- Constat : moderate_live_viewer permettait de bannir l'hôte lui-même (par l'administration), laissait un invité co-diffuseur banni dans live_cohosts avec le statut « approved »,
-- et échouait sur une clé étrangère brute pour un compte inconnu. Les droits restent : l'hôte du live, l'administration, le support.
-- Retour arrière : recréer moderate_live_viewer depuis 20261110000000.

create or replace function moderate_live_viewer(p_live uuid, p_user uuid, p_message bigint default null) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Action non autorisée'; end if;
  if p_message is not null then update live_messages set hidden = true where id = p_message and live_id = p_live; end if;
  if p_user is not null and p_user <> auth.uid() then
    if p_user = l.host_id then raise exception 'L''hôte du live ne peut pas être exclu'; end if;
    if not exists (select 1 from profiles where id = p_user) then raise exception 'Membre introuvable'; end if;
    insert into live_bans (live_id, user_id, by_user) values (p_live, p_user, auth.uid()) on conflict do nothing;
    update live_viewers set left_at = now() where live_id = p_live and user_id = p_user and left_at is null;
    update live_cohosts set status = 'removed', decided_at = now() where live_id = p_live and user_id = p_user and status in ('requested', 'approved');
    perform _live_recount(p_live);
  end if;
  return 'ok';
end $$;
revoke all on function moderate_live_viewer(uuid, uuid, bigint) from public, anon;
grant execute on function moderate_live_viewer(uuid, uuid, bigint) to authenticated;
