-- H13 SOCIAL 2/6 : abonnements et désabonnements fiables.
--  * garde serveur sur engagements(kind = 'follow', ref = identifiant de compte) : pas d'auto-abonnement, compte cible inexistant / suspendu / bloqué (dans les deux sens) refusé,
--    abonné suspendu refusé ; le désabonnement reste toujours possible. Les cibles non-compte (« company:89 ») ne sont pas concernées ;
--  * notification « Nouvel abonné » UNE SEULE FOIS par couple (abonné, suivi) : se réabonner après un désabonnement ne renotifie pas ;
--  * follow_set(p_user, p_follow) : idempotent (rejeu sans effet, sans erreur), renvoie l'état et les compteurs ; follow_stats(p_user) ;
--  * public_profile : compteurs d'abonnés / d'abonnements sans les comptes suspendus ni les auto-abonnements historiques (même contrat JSON qu'avant) ;
--  * creators_suggested : suggestions de créateurs à suivre, uniquement des données publiques (nom abrégé, avatar, certifié, compteurs) ; jamais soi-même,
--    jamais un compte déjà suivi, bloqué, suspendu, au profil non visible ou sans publication visible.
-- Strictement additif. Retour arrière : drop trigger trg_h13_follow_guard on engagements ; drop function follow_set(uuid, boolean), follow_stats(uuid), creators_suggested(integer), _h13_follow_guard() ;
--   recréer trg_notify_follow depuis 20261103000100 et public_profile depuis 20261119060000.

create or replace function _h13_follow_guard() returns trigger language plpgsql security definer set search_path = public as $$
declare v_target uuid;
begin
  if new.kind <> 'follow' or new.status <> 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  if new.ref !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return new; end if;
  v_target := new.ref::uuid;
  if v_target = new.user_id then raise exception 'Vous ne pouvez pas vous abonner à votre propre compte'; end if;
  if exists (select 1 from profiles where id = new.user_id and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if not exists (select 1 from profiles where id = v_target and not coalesce(suspended, false)) then raise exception 'Compte introuvable ou indisponible'; end if;
  if exists (select 1 from user_blocks b where (b.blocker_id = v_target and b.blocked_id = new.user_id) or (b.blocker_id = new.user_id and b.blocked_id = v_target)) then
    raise exception 'Abonnement impossible avec ce compte';
  end if;
  return new;
end $$;
revoke all on function _h13_follow_guard() from public, anon, authenticated;
drop trigger if exists trg_h13_follow_guard on engagements;
create trigger trg_h13_follow_guard before insert or update on engagements for each row execute function _h13_follow_guard();

create or replace function trg_notify_follow() returns trigger language plpgsql security definer set search_path = public as $$
declare v_target uuid;
begin
  if new.kind <> 'follow' or new.status <> 'active' then return null; end if;
  begin v_target := new.ref::uuid; exception when others then return null; end;
  if v_target = new.user_id or not exists (select 1 from profiles where id = v_target) then return null; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return null; end if;
  if exists (select 1 from notifications n where n.user_id = v_target and n.kind = 'follow' and n.data->>'user' = new.user_id::text) then return null; end if;
  insert into notifications (user_id, kind, title, body, data)
    values (v_target, 'follow', 'Nouvel abonné', display_name(new.user_id) || ' vous suit.', jsonb_build_object('user', new.user_id));
  return null;
end $$;

create or replace function _h13_follow_counts(p_user uuid) returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'followers', (select count(*)::int from engagements e join profiles f on f.id = e.user_id and not coalesce(f.suspended, false)
                   where e.kind = 'follow' and e.ref = p_user::text and e.status = 'active' and e.user_id <> p_user),
    'following', (select count(*)::int from engagements e where e.kind = 'follow' and e.user_id = p_user and e.status = 'active' and e.ref <> p_user::text
                   and exists (select 1 from profiles t where t.id::text = e.ref and not coalesce(t.suspended, false))))
$$;
revoke all on function _h13_follow_counts(uuid) from public, anon, authenticated;

create or replace function follow_set(p_user uuid, p_follow boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); v_status text; v_changed boolean := false; v_counts jsonb;
begin
  perform _assert_active();
  if p_user is null then raise exception 'Compte introuvable ou indisponible'; end if;
  if p_user = me then raise exception 'Vous ne pouvez pas vous abonner à votre propre compte'; end if;
  select status into v_status from engagements where user_id = me and kind = 'follow' and ref = p_user::text;
  if coalesce(p_follow, true) then
    if v_status is distinct from 'active' then
      if not exists (select 1 from profiles where id = p_user and not coalesce(suspended, false)) or not profile_visible(p_user) then raise exception 'Compte introuvable ou indisponible'; end if;
      insert into engagements (user_id, kind, ref) values (me, 'follow', p_user::text)
        on conflict (user_id, kind, ref) do update set status = 'active', updated_at = now();
      v_changed := true;
    end if;
  elsif v_status = 'active' then
    update engagements set status = 'cancelled', updated_at = now() where user_id = me and kind = 'follow' and ref = p_user::text;
    v_changed := true;
  end if;
  v_counts := _h13_follow_counts(p_user);
  return jsonb_build_object('user', p_user, 'following', coalesce(p_follow, true), 'changed', v_changed, 'followers', v_counts->'followers', 'following_count', v_counts->'following');
end $$;
revoke all on function follow_set(uuid, boolean) from public, anon;
grant execute on function follow_set(uuid, boolean) to authenticated;

create or replace function follow_stats(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from profiles where id = p_user and not coalesce(suspended, false)) and profile_visible(p_user) then
    _h13_follow_counts(p_user) || jsonb_build_object('user', p_user,
      'i_follow', exists (select 1 from engagements e where e.user_id = auth.uid() and e.kind = 'follow' and e.ref = p_user::text and e.status = 'active'))
  end
$$;
revoke all on function follow_stats(uuid) from public;
grant execute on function follow_stats(uuid) to anon, authenticated;

-- public_profile : même contrat, compteurs d'abonnés / d'abonnements corrigés
create or replace function public_profile(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'name', case when auth.uid() is null then _short_name(p.name)
                 when p.id <> auth.uid() and p.role::text = 'student' and _viewer_class() in ('org_ok', 'org_locked') and not (_viewer_class() = 'org_ok' and _cv_published(p.id)) then _short_name(p.name)
                 else p.name end,
    'role', case when p.role::text in ('student', 'company', 'other') then p.role::text else 'student' end,
    'city', coalesce(p.city, ''),
    'institution', coalesce(p.institution, ''),
    'department', coalesce(p.department, ''),
    'bio', coalesce(p.bio, ''),
    'skills', coalesce(p.skills, ''),
    'avatar_url', p.avatar_url,
    'certified', p.certification::text = 'approved',
    'posts_count', (select count(*)::int from posts x where x.author_id = p.id and x.status = 'published' and x.kind = 'media' and x.community_id is null),
    'followers_count', (_h13_follow_counts(p.id)->>'followers')::int,
    'following_count', (_h13_follow_counts(p.id)->>'following')::int,
    'rating', coalesce((select round(avg(r.rating)::numeric, 2) from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id), 0),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id)
  )
  from profiles p
  where p.id = p_user and not coalesce(p.suspended, false)
    and profile_visible(p.id)
    and (
      p.id = auth.uid()
      or (p.role::text in ('student', 'company', 'other'))
      or (p.role::text not in ('admin', 'direction', 'finance', 'support', 'client', 'visitor')
          and (exists (select 1 from posts x where x.author_id = p.id and x.status = 'published' and x.community_id is null)
            or exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')))
    );
$$;

create or replace function creators_suggested(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x.j order by x.followers desc, x.last_post desc), '[]'::jsonb) from (
    select jsonb_build_object('id', p.id, 'name', display_name(p.id), 'avatar_url', p.avatar_url, 'certified', p.certification::text = 'approved',
             'posts_count', (select count(*)::int from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null),
             'followers_count', (_h13_follow_counts(p.id)->>'followers')::int) j,
           (_h13_follow_counts(p.id)->>'followers')::int followers,
           (select max(z.published_at) from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null) last_post
    from profiles p
    where not coalesce(p.suspended, false) and p.role::text in ('student', 'company', 'other')
      and p.id is distinct from auth.uid()
      and profile_visible(p.id)
      and exists (select 1 from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null)
      and not is_blocked_between(auth.uid(), p.id)
      and not exists (select 1 from engagements e where e.user_id = auth.uid() and e.kind = 'follow' and e.ref = p.id::text and e.status = 'active')
    order by 2 desc, 3 desc
    limit least(greatest(coalesce(p_limit, 10), 1), 30)) x
$$;
revoke all on function creators_suggested(integer) from public;
grant execute on function creators_suggested(integer) to anon, authenticated;
