-- Consolidation finale des objets que plusieurs lots du profil Étudiant redéfinissent (propriété du chef) :
--   * talents_list : étudiants VÉRIFIÉS (S1), annuaire consenti (S2-13), jokers de recherche échappés (S2-16), noms abrégés sauf pour les
--     entreprises, le département, la direction, le support et l'administration (confidentialité des noms) ;
--   * public_profile : profil masqué ou réservé aux membres respecté (S2-9), nom abrégé pour un visiteur ;
--   * mates_search : profil privé exclu de l'annuaire de coéquipiers (S2-13) ;
--   * profiles : le changement de NOM d'un compte certifié retire la certification et prévient le département (S2-4).
-- Ce fichier est le dernier de la série : il fait foi. Retour arrière : réappliquer talents_list (20261117010000), public_profile (20261117000100),
--   mates_search (20261117060000), protect_profile_authority (20261117990100).

create or replace function _short_name(p_name text) returns text
language sql immutable as $$
  select coalesce(nullif(trim(split_part(coalesce(p_name, ''), ' ', 1) || ' ' || case when split_part(coalesce(p_name, ''), ' ', 2) <> '' then left(split_part(p_name, ' ', 2), 1) || '.' else '' end), ''), 'Un membre')
$$;

create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_full boolean; v_q text := replace(replace(replace(trim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_full := coalesce(current_role_name()::text, '') in ('company', 'dept', 'direction', 'admin', 'support');
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'name', case when v_full then t.name else _short_name(t.name) end,
                                        'department', coalesce(t.department, ''), 'institution', coalesce(t.institution, ''),
                                        'skills', coalesce(t.skills, ''), 'city', coalesce(t.city, ''), 'avatar_url', t.avatar_url, 'certified', t.certification::text = 'approved',
                                        'cover_path', t.cover_path, 'cover_kind', t.cover_kind))
    from (
      select * from profiles
      where role::text = 'student' and not suspended and nullif(trim(coalesce(skills, '')), '') is not null
        and is_verified_student(id) and profile_in_directory(id)
        and (v_q = '' or name ilike '%' || v_q || '%' or skills ilike '%' || v_q || '%' or coalesce(department, '') ilike '%' || v_q || '%')
      order by (certification::text = 'approved') desc, created_at desc
      limit least(greatest(p_limit, 1), 50)
    ) t
  ), '[]'::jsonb);
end $$;
revoke all on function talents_list(text, int) from public, anon;
grant execute on function talents_list(text, int) to authenticated;

create or replace function public_profile(p_user uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'name', case when auth.uid() is null then _short_name(p.name) else p.name end,
    'role', case when p.role::text in ('student', 'company', 'other') then p.role::text else 'student' end,
    'city', coalesce(p.city, ''),
    'institution', coalesce(p.institution, ''),
    'department', coalesce(p.department, ''),
    'bio', coalesce(p.bio, ''),
    'skills', coalesce(p.skills, ''),
    'avatar_url', p.avatar_url,
    'certified', p.certification::text = 'approved',
    'posts_count', (select count(*)::int from posts x where x.author_id = p.id and x.status = 'published' and x.kind = 'media' and x.community_id is null),
    'followers_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.ref = p.id::text and e.status = 'active'),
    'following_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.user_id = p.id and e.status = 'active'),
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

create or replace function mates_search(p_query text default '', p_category uuid default null, p_department text default '', p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_kw text[]; v_q text := replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'La recherche de coéquipiers est réservée aux étudiants'; end if;
  if p_category is not null then select keywords into v_kw from mate_categories where id = p_category and active; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', display_name(t.id), 'department', coalesce(t.department, ''), 'skills', coalesce(t.skills, ''), 'avatar_url', t.avatar_url,
      'certified', t.certification::text = 'approved',
      'invite', (select i.status from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1),
      'invite_id', (select i.id from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1)) order by (t.certification::text = 'approved') desc, t.created_at desc)
    from (select * from profiles pr
          where pr.role::text = 'student' and not coalesce(pr.suspended, false) and pr.id <> auth.uid() and nullif(btrim(coalesce(pr.skills, '')), '') is not null
            and exists (select 1 from mate_consents mc where mc.user_id = pr.id and mc.visible)
            and profile_in_directory(pr.id)
            and (v_q = '' or pr.name ilike '%' || v_q || '%' or pr.skills ilike '%' || v_q || '%' or coalesce(pr.department, '') ilike '%' || v_q || '%')
            and (nullif(btrim(coalesce(p_department, '')), '') is null or coalesce(pr.department, '') ilike '%' || btrim(p_department) || '%')
            and (v_kw is null or exists (select 1 from unnest(v_kw) k where lower(pr.skills || ' ' || coalesce(pr.department, '')) ~ ('(^|[^a-zà-ÿ0-9])' || regexp_replace(k, '([.*+?^$()\[\]{}|\\])', '\\\1', 'g'))))
          order by pr.created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) t), '[]'::jsonb);
end $$;
revoke all on function mates_search(text, uuid, text, integer) from public, anon;
grant execute on function mates_search(text, uuid, text, integer) to authenticated;

-- S2-4 : un nom modifié sur un compte certifié invalide la certification (le badge ne reste pas attaché à un nom non vérifié) et le département est prévenu.
create or replace function profiles_name_recertify() returns trigger
language plpgsql security definer set search_path = public as $$
declare v record;
begin
  if tg_op = 'UPDATE' and new.name is distinct from old.name and old.certification::text = 'approved'
     and auth.uid() is not null and coalesce(current_role_name()::text, '') not in ('admin') then
    new.certification := 'none';
    new.certification_decided_by := null;
    new.certification_decided_at := null;
    for v in select p.id from profiles p
             where not coalesce(p.suspended, false) and (p.role::text = 'admin' or (p.role::text = 'dept' and lower(coalesce(p.department, '')) = lower(coalesce(new.department, '')))) loop
      perform notify_user(v.id, 'verification', 'Nom modifié : certification retirée', left(coalesce(old.name, '') || ' est devenu ' || coalesce(new.name, '') || '. La personne doit redemander la certification.', 300), jsonb_build_object('user', new.id));
    end loop;
  end if;
  return new;
end $$;
revoke execute on function profiles_name_recertify() from public, anon, authenticated;
-- Nom en « z » : le déclencheur passe APRÈS trg_protect_profile (ordre alphabétique), qui ne voit donc pas ce retrait de certification.
drop trigger if exists trg_profiles_name_recertify on profiles;
drop trigger if exists trg_z_profiles_name_recertify on profiles;
create trigger trg_z_profiles_name_recertify before update of name on profiles for each row execute function profiles_name_recertify();
