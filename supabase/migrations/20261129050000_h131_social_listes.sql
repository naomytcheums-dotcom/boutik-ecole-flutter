-- H13.1 SOCIAL-LISTES : listes « Abonnés » / « Abonnements » paginées par curseur, confidentialité des listes, suggestions de créateurs fondées sur des données réelles.
--  * profiles.follow_lists_public (défaut true) : la personne peut masquer ses deux listes (follow_lists_privacy_get / follow_lists_privacy_set) ;
--  * followers_list(p_user, p_limit, p_cursor) et following_list(p_user, p_limit, p_cursor) : keyset sur (date d'abonnement, id), 50 lignes au plus par page,
--    jamais de doublon d'une page à l'autre. Retour : { allowed, reason, items[{id, name, avatar_url, role, certified, i_follow, is_me}], next, own, lists_public }.
--    Refus (allowed = false, items vides) : profil introuvable / suspendu / supprimé / bloqué (dans un sens ou dans l'autre) / non visible pour l'appelant
--    (reason = 'unavailable', sans distinguer les cas) ; listes masquées par leur propriétaire (reason = 'lists_hidden'). Le propriétaire voit toujours ses listes.
--    Sont exclus des lignes : comptes suspendus ou supprimés (anonymisés), comptes bloqués par l'appelant ou l'ayant bloqué, comptes bloqués avec le propriétaire de la liste,
--    comptes dont le profil n'est pas visible pour l'appelant (privé, réservé aux membres pour un visiteur) et comptes sans profil public (client, équipe).
--    Aucune donnée privée : ni e-mail, ni téléphone, ni ville, ni date d'abonnement. L'anonyme ne lit que les listes de profils publics et ne reçoit que des noms abrégés.
--  * creators_suggested(p_limit) : même contrat qu'avant + « reason » et « mutual_count ». Classement par signaux réels (même département, même établissement,
--    abonnements en commun, communautés en commun, compétences communes, activité récente, popularité) ; exclut soi, déjà suivis, bloqués, suspendus,
--    profils non visibles ou sortis de l'annuaire, comptes sans publication visible. Aucun profil inventé : sans résultat, la liste est vide.
-- Strictement additif. Retour arrière : drop function followers_list(uuid, integer, jsonb), following_list(uuid, integer, jsonb), follow_lists_privacy_get(), follow_lists_privacy_set(boolean),
--   _h131_follow_list(uuid, text, integer, jsonb), _h131_listable(uuid), _h131_blocked(uuid, uuid) ; drop index engagements_follow_ref_h131 ; alter table profiles drop column follow_lists_public ;
--   recréer creators_suggested depuis 20261128050100.

alter table profiles add column if not exists follow_lists_public boolean not null default true;
create index if not exists engagements_follow_ref_h131 on engagements (ref, created_at desc, id desc) where kind = 'follow' and status = 'active';

create or replace function _h131_blocked(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_a is not null and p_b is not null and exists (select 1 from user_blocks b where (b.blocker_id = p_a and b.blocked_id = p_b) or (b.blocker_id = p_b and b.blocked_id = p_a))
$$;
revoke all on function _h131_blocked(uuid, uuid) from public, anon, authenticated;

-- Profil affichable dans une liste pour l'appelant : mêmes règles que public_profile (rôles publics, profil visible, non suspendu).
create or replace function _h131_listable(p_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p
    where p.id = p_id and not coalesce(p.suspended, false) and profile_visible(p.id)
      and (p.id = auth.uid()
           or p.role::text in ('student', 'company', 'other')
           or (p.role::text not in ('admin', 'direction', 'finance', 'support', 'client', 'visitor')
               and (exists (select 1 from posts x where x.author_id = p.id and x.status = 'published' and x.community_id is null)
                 or exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')))))
$$;
revoke all on function _h131_listable(uuid) from public, anon, authenticated;

create or replace function follow_lists_privacy_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object('public', coalesce((select follow_lists_public from profiles where id = auth.uid()), true));
end $$;

create or replace function follow_lists_privacy_set(p_public boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform _assert_active();
  if p_public is null then raise exception 'Réglage inconnu'; end if;
  update profiles set follow_lists_public = p_public where id = auth.uid();
  return follow_lists_privacy_get();
end $$;
revoke all on function follow_lists_privacy_get(), follow_lists_privacy_set(boolean) from public, anon;
grant execute on function follow_lists_privacy_get(), follow_lists_privacy_set(boolean) to authenticated;

create or replace function _h131_follow_list(p_user uuid, p_dir text, p_limit integer, p_cursor jsonb) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_at timestamptz; v_id uuid;
  v_items jsonb; v_more boolean; v_next jsonb;
  v_own boolean := coalesce(p_user = me, false);
begin
  if p_cursor is not null and jsonb_typeof(p_cursor) <> 'null' then
    begin
      v_at := (p_cursor ->> 'at')::timestamptz; v_id := (p_cursor ->> 'id')::uuid;
    exception when others then v_at := null; v_id := null; end;
    if v_at is null or v_id is null then raise exception 'Curseur invalide'; end if;
  end if;
  if p_user is null or _h131_blocked(me, p_user) or not _h131_listable(p_user) then
    return jsonb_build_object('allowed', false, 'reason', 'unavailable', 'items', '[]'::jsonb, 'next', null, 'own', false);
  end if;
  if not v_own and not coalesce((select follow_lists_public from profiles where id = p_user), true) then
    return jsonb_build_object('allowed', false, 'reason', 'lists_hidden', 'items', '[]'::jsonb, 'next', null, 'own', false);
  end if;

  select coalesce(jsonb_agg(x.j order by x.created_at desc, x.id desc) filter (where x.rn <= v_limit), '[]'::jsonb),
         count(*) > v_limit,
         (array_agg(jsonb_build_object('at', x.created_at, 'id', x.id) order by x.created_at desc, x.id desc) filter (where x.rn = v_limit))[1]
    into v_items, v_more, v_next
  from (
    select row_number() over (order by g.created_at desc, g.id desc) rn, g.created_at, g.id,
           jsonb_build_object(
             'id', p.id,
             'name', case when me is null then _short_name(p.name)
                          when p.id <> me and p.role::text = 'student' and _viewer_class() in ('org_ok', 'org_locked') and not (_viewer_class() = 'org_ok' and _cv_published(p.id)) then _short_name(p.name)
                          else p.name end,
             'avatar_url', p.avatar_url,
             'role', case when p.role::text in ('student', 'company', 'other', 'dept') then p.role::text else 'other' end,
             'certified', p.certification::text = 'approved',
             'i_follow', me is not null and exists (select 1 from engagements f where f.user_id = me and f.kind = 'follow' and f.ref = p.id::text and f.status = 'active'),
             'is_me', coalesce(p.id = me, false)) j
    from (
      select e.id, e.created_at, e.user_id other from engagements e
       where p_dir = 'followers' and e.kind = 'follow' and e.status = 'active' and e.ref = p_user::text and e.user_id <> p_user
      union all
      select e.id, e.created_at, t.id from engagements e join profiles t on t.id::text = e.ref
       where p_dir = 'following' and e.kind = 'follow' and e.status = 'active' and e.user_id = p_user and t.id <> p_user
    ) g
    join profiles p on p.id = g.other
    where (v_at is null or (g.created_at, g.id) < (v_at, v_id))
      and _h131_listable(p.id)
      and not _h131_blocked(me, p.id)
      and not _h131_blocked(p_user, p.id)
    order by g.created_at desc, g.id desc
    limit v_limit + 1
  ) x;

  return jsonb_build_object('allowed', true, 'reason', null, 'items', v_items, 'next', case when v_more then v_next end, 'own', v_own,
                            'lists_public', case when v_own then coalesce((select follow_lists_public from profiles where id = me), true) end);
end $$;
revoke all on function _h131_follow_list(uuid, text, integer, jsonb) from public, anon, authenticated;

create or replace function followers_list(p_user uuid, p_limit integer default 20, p_cursor jsonb default null) returns jsonb
language sql stable security definer set search_path = public as $$ select _h131_follow_list(p_user, 'followers', p_limit, p_cursor) $$;
create or replace function following_list(p_user uuid, p_limit integer default 20, p_cursor jsonb default null) returns jsonb
language sql stable security definer set search_path = public as $$ select _h131_follow_list(p_user, 'following', p_limit, p_cursor) $$;
revoke all on function followers_list(uuid, integer, jsonb), following_list(uuid, integer, jsonb) from public;
grant execute on function followers_list(uuid, integer, jsonb), following_list(uuid, integer, jsonb) to anon, authenticated;

-- Suggestions : uniquement des comptes réels, classés par signaux mesurés ; « reason » dit pourquoi (même_departement, meme_etablissement, abonnements_communs,
-- communautes_communes, competences_communes, actif_recemment, populaire). Pour un visiteur anonyme, seuls l'activité et la popularité comptent.
create or replace function creators_suggested(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  with me as (
    select p.institution_id, p.department_id, nullif(lower(trim(p.institution)), '') inst, nullif(lower(trim(p.department)), '') dept,
           array(select trim(s) from unnest(regexp_split_to_array(lower(coalesce(p.skills, '')), '[,;\n]')) s where trim(s) <> '') skills
    from profiles p where p.id = auth.uid()
  ), cand as (
    select p.id, p.avatar_url, p.certification::text = 'approved' certified,
           (select count(*)::int from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null) posts_count,
           (_h13_follow_counts(p.id) ->> 'followers')::int followers,
           (select count(*)::int from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null and z.published_at > now() - interval '30 days') recent_posts,
           (select max(z.published_at) from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null) last_post,
           coalesce((select (m.department_id is not null and p.department_id = m.department_id) or (m.department_id is null and m.dept is not null and m.dept = nullif(lower(trim(p.department)), '')) from me m), false) same_dept,
           coalesce((select (m.institution_id is not null and p.institution_id = m.institution_id) or (m.institution_id is null and m.inst is not null and m.inst = nullif(lower(trim(p.institution)), '')) from me m), false) same_inst,
           case when auth.uid() is null then 0 else (
             select count(*)::int from engagements a
               join engagements b on b.user_id::text = a.ref and b.kind = 'follow' and b.status = 'active' and b.ref = p.id::text
               join profiles x on x.id = b.user_id and not coalesce(x.suspended, false) and x.follow_lists_public and profile_visible(x.id)
              where a.user_id = auth.uid() and a.kind = 'follow' and a.status = 'active') end mutual,
           case when auth.uid() is null then 0 else (
             select count(*)::int from community_members c1 join community_members c2 on c2.community_id = c1.community_id and c2.status = 'active'
              join communities cm on cm.id = c1.community_id and cm.status = 'active'
              where c1.user_id = auth.uid() and c1.status = 'active' and c2.user_id = p.id) end shared_communities,
           coalesce((select count(*)::int from (select trim(s) from unnest(regexp_split_to_array(lower(coalesce(p.skills, '')), '[,;\n]')) s where trim(s) <> '' and trim(s) = any (coalesce((select m.skills from me m), '{}'::text[]))) q), 0) shared_skills
    from profiles p
    where not coalesce(p.suspended, false) and p.role::text in ('student', 'company', 'other')
      and p.id is distinct from auth.uid()
      and profile_visible(p.id) and profile_in_directory(p.id)
      and exists (select 1 from posts z where z.author_id = p.id and z.status = 'published' and z.community_id is null)
      and not _h131_blocked(auth.uid(), p.id)
      and not exists (select 1 from engagements e where e.user_id = auth.uid() and e.kind = 'follow' and e.ref = p.id::text and e.status = 'active')
  ), scored as (
    select c.*,
      (case when c.same_dept then 30 else 0 end) + (case when c.same_inst then 15 else 0 end) + least(c.mutual, 5) * 8 + least(c.shared_communities, 3) * 10
        + least(c.shared_skills, 3) * 5 + least(c.recent_posts, 5) * 2 + least(round(ln(1 + c.followers) * 2)::int, 8) score
    from cand c
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'name', display_name(s.id), 'avatar_url', s.avatar_url, 'certified', s.certified, 'posts_count', s.posts_count, 'followers_count', s.followers,
      'mutual_count', s.mutual,
      'reason', case when s.same_dept then 'meme_departement' when s.same_inst then 'meme_etablissement' when s.mutual > 0 then 'abonnements_communs'
                     when s.shared_communities > 0 then 'communautes_communes' when s.shared_skills > 0 then 'competences_communes'
                     when s.recent_posts > 0 then 'actif_recemment' else 'populaire' end)
    order by s.score desc, s.last_post desc nulls last, s.id), '[]'::jsonb)
  from (select * from scored order by score desc, last_post desc nulls last, id limit least(greatest(coalesce(p_limit, 10), 1), 30)) s
$$;
revoke all on function creators_suggested(integer) from public;
grant execute on function creators_suggested(integer) to anon, authenticated;
