-- Badge de niveau (points) visible sur les profils et dans la liste des membres d'une communauté.
-- Lecture seule : les points restent attribués uniquement par le serveur (award_points).
-- Retour arrière : drop function user_level(uuid), community_levels(uuid).

create or replace function user_level(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('total', t.total, 'level', point_level(t.total))
  from (select coalesce(sum(points), 0)::int total from point_events where user_id = p_user) t
$$;

-- Niveaux des membres actifs d'une communauté ayant au moins un niveau (objet { id: { total, level } }).
create or replace function community_levels(p_community uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(x.user_id, jsonb_build_object('total', x.total, 'level', point_level(x.total))), '{}'::jsonb)
  from (
    select m.user_id, coalesce((select sum(e.points) from point_events e where e.user_id = m.user_id), 0)::int total
    from community_members m
    join communities c on c.id = m.community_id
    where m.community_id = p_community and m.status = 'active' and c.status = 'active'
      and (c.privacy in ('public', 'approval') or is_community_member(c.id) or is_platform_staff())
  ) x
  where point_level(x.total) <> 'none'
$$;

revoke all on function user_level(uuid), community_levels(uuid) from public;
grant execute on function user_level(uuid), community_levels(uuid) to anon, authenticated;
