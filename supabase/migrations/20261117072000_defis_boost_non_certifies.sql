-- Défis et boost : comptes non certifiés (S7-43), boost de série borné (S7-44), abonnés de boutique comptés dans le badge « Cent abonnés » (S7-18).
--  - my_challenges : ajoute pending_posts / posts_week_pending (publications en attente de validation), certified, boost_ready, boost_next_in (jours avant le prochain boost)
--    et compte les abonnés de la boutique de l'étudiant en plus des abonnés du profil (personnes distinctes).
--  - claim_challenge : le message d'échec indique les publications en attente (elles comptent dès qu'elles sont validées).
--  - claim_streak_boost : le boost vise la dernière publication VALIDÉE visible dans le fil public (hors publications de communauté) ; un boost au plus tous les 6 jours
--    (la série de 6 jours se refait entre deux boosts) ; message clair si seules des publications en attente existent.
-- Retour arrière : recréer my_challenges, claim_challenge et claim_streak_boost depuis 20261115170000_l7_parrainage_social_lives_defis.sql.

create or replace function my_challenges() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; streak int; wk date := date_trunc('week', d)::date; posts_week int; pending_week int; pending_all int; pts int; rank int;
        ledger int; followers int; best_peak int; sales int; v_marks jsonb; v_certified boolean; v_last_boost timestamptz; v_ready boolean; v_next int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  streak := _streak(auth.uid());
  select count(*) into posts_week from posts
    where author_id = auth.uid() and status = 'published' and repost_of is null and remix_of is null and community_id is null and published_at >= (wk::timestamp at time zone 'Africa/Douala');
  select count(*) into pending_week from posts
    where author_id = auth.uid() and status = 'pending' and repost_of is null and remix_of is null and community_id is null and created_at >= (wk::timestamp at time zone 'Africa/Douala');
  select count(*) into pending_all from posts where author_id = auth.uid() and status = 'pending' and community_id is null;
  select coalesce(sum(points), 0) into ledger from points_ledger where user_id = auth.uid();
  begin
    pts := points_total(auth.uid());
  exception when undefined_function then
    pts := ledger;
  end;
  select count(*) + 1 into rank from (select user_id, sum(points) s from points_ledger group by user_id) x where x.s > ledger;
  select count(distinct u) into followers from (
    select e.user_id u from engagements e where e.kind = 'follow' and e.ref = auth.uid()::text and e.status = 'active'
    union all
    select sf.user_id from shop_follows sf join shops s on s.id = sf.shop_id where s.owner_id = auth.uid()) f;
  select coalesce(max(peak_viewers), 0) into best_peak from lives where host_id = auth.uid() and status = 'ended';
  select count(*) into sales from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null;
  select jsonb_agg(exists (select 1 from daily_checkins c where c.user_id = auth.uid() and c.day = wk + g) order by g) into v_marks from generate_series(0, 6) g;
  select (certification::text = 'approved' or role::text in ('dept', 'admin')) into v_certified from profiles where id = auth.uid();
  select max(created_at) into v_last_boost from points_ledger where user_id = auth.uid() and source = 'streak6';
  v_next := case when v_last_boost is null then 0 else greatest(0, ceil(extract(epoch from (v_last_boost + interval '6 days' - now())) / 86400.0)::int) end;
  v_ready := exists (select 1 from posts where author_id = auth.uid() and status = 'published' and community_id is null);
  return jsonb_build_object(
    'streak', streak, 'next_reward_in', greatest(6 - streak, 0),
    'checked_today', exists (select 1 from daily_checkins where user_id = auth.uid() and day = d),
    'streak_reward_claimable', streak >= 6 and v_next = 0 and not exists (select 1 from points_ledger where user_id = auth.uid() and source = 'streak6' and ref = d::text),
    'streak_claimed_today', exists (select 1 from points_ledger where user_id = auth.uid() and source = 'streak6' and ref = d::text),
    'boost_next_in', v_next, 'boost_ready', v_ready,
    'week_marks', v_marks, 'today_index', extract(isodow from d)::int - 1,
    'week_end_days', 7 - extract(isodow from d)::int,
    'posts_week', posts_week, 'posts_goal', 3, 'posts_week_pending', pending_week, 'pending_posts', pending_all, 'certified', coalesce(v_certified, false),
    'posts_claimable', posts_week >= 3 and not exists (select 1 from points_ledger where user_id = auth.uid() and source = 'challenge:posts3' and ref = wk::text),
    'posts_claimed', exists (select 1 from points_ledger where user_id = auth.uid() and source = 'challenge:posts3' and ref = wk::text),
    'points', pts,
    'badges', jsonb_build_object('first_sale', sales > 0, 'followers_100', followers >= 100, 'live_star', best_peak >= 10, 'top10', ledger > 0 and rank <= 10),
    'badge_info', jsonb_build_object('sales', sales, 'followers', followers, 'best_peak', best_peak, 'rank', case when ledger > 0 then rank end)
  );
end $$;

create or replace function claim_challenge(p_code text) returns integer
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; wk date := date_trunc('week', d)::date; n int; k int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_code <> 'posts3' then raise exception 'Défi indisponible'; end if;
  select count(*) into n from posts
    where author_id = auth.uid() and status = 'published' and repost_of is null and remix_of is null and community_id is null and published_at >= (wk::timestamp at time zone 'Africa/Douala');
  if n < 3 then
    select count(*) into k from posts
      where author_id = auth.uid() and status = 'pending' and repost_of is null and remix_of is null and community_id is null and created_at >= (wk::timestamp at time zone 'Africa/Douala');
    raise exception 'Défi non atteint : % publication(s) validée(s) sur 3 cette semaine (les republications ne comptent pas)%', n,
      case when k > 0 then ' ; ' || k || ' en attente de validation par le département : elle(s) compteront une fois validée(s)' else '' end;
  end if;
  insert into points_ledger (user_id, source, ref, points) values (auth.uid(), 'challenge:posts3', wk::text, 200);
  return 200;
exception when unique_violation then raise exception 'Récompense déjà récupérée cette semaine';
end $$;

create or replace function claim_streak_boost() returns text
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; streak int; p uuid; v_last timestamptz; v_pending int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  streak := _streak(auth.uid());
  if streak < 6 then raise exception 'Série de % jour(s) : la récompense arrive à 6 jours', streak; end if;
  select max(created_at) into v_last from points_ledger where user_id = auth.uid() and source = 'streak6';
  if v_last is not null and v_last > now() - interval '6 days' then raise exception 'Un boost a déjà été récupéré récemment : le prochain est possible 6 jours après'; end if;
  select id into p from posts where author_id = auth.uid() and status = 'published' and community_id is null order by published_at desc limit 1;
  if p is null then
    select count(*) into v_pending from posts where author_id = auth.uid() and status = 'pending' and community_id is null;
    if v_pending > 0 then
      raise exception 'Votre publication attend la validation du département : le boost s''applique à une publication validée visible dans le fil. Revenez après sa validation (ou demandez la certification de votre compte).';
    end if;
    raise exception 'Publiez d''abord un post pour recevoir le boost';
  end if;
  if exists (select 1 from post_boosts where user_id = auth.uid() and now() between starts_at and ends_at) then raise exception 'Un boost est déjà actif'; end if;
  insert into points_ledger (user_id, source, ref, points) values (auth.uid(), 'streak6', d::text, 1);
  insert into post_boosts (post_id, user_id) values (p, auth.uid());
  return 'boosted';
exception when unique_violation then raise exception 'Récompense du jour déjà récupérée';
end $$;
revoke all on function my_challenges(), claim_challenge(text), claim_streak_boost() from public, anon;
grant execute on function my_challenges(), claim_challenge(text), claim_streak_boost() to authenticated;
