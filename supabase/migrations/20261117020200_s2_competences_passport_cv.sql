-- Lot S2 (3/5) : compétences, Talent Passport, CV vivant (S2-1, S2-21, S2-32, S2-71, S2-78, S2-20).
--  1. S2-1  : profile_skills_sync ne REMPLACE plus profiles.skills : les compétences saisies à la main dans « Modifier mon profil » sont conservées,
--             celles du Talent Passport y sont ajoutées ; supprimer ou renommer une compétence du Passport ne retire que celle-là.
--  2. S2-32 / S2-21 : talent_passport(p_user) : compétences AVEC niveau, années d'expérience, justificatif (présence et état, jamais le fichier ni la
--             description pour un tiers), points et badges calculés sur des données réelles ; visible selon la visibilité du profil.
--  3. S2-71 / S2-78 / S2-20 : le CV reprend toutes les réalisations du portfolio (projet, image, vidéo, lien), les niveaux de compétence et ne publie
--             que des liens https:// (le client ne filtre plus seul).
-- Retour arrière : voir le bas du fichier.

-- ============================================================ 1. compétences : fusion sans écrasement
create or replace function _profile_skills_merge(p_user uuid, p_remove text[] default '{}'::text[]) returns void
language sql security definer set search_path = public as $$
  with cur as (
    select btrim(x) s, ord from profiles p, unnest(string_to_array(coalesce(p.skills, ''), ',')) with ordinality as u(x, ord) where p.id = p_user
  ), keep as (
    select s, ord from cur where s <> '' and lower(s) <> all (select lower(btrim(r)) from unnest(coalesce(p_remove, '{}'::text[])) r)
  ), ts as (
    select skill s, 100000 + row_number() over (order by created_at) ord from talent_skills where owner_id = p_user
  ), u as (
    select s, ord from keep union all select s, ord from ts
  ), d as (
    select distinct on (lower(s)) s, ord from u order by lower(s), ord
  )
  update profiles set skills = coalesce((select string_agg(s, ', ' order by ord) from d), '') where id = p_user
$$;
revoke all on function _profile_skills_merge(uuid, text[]) from public, anon, authenticated;

create or replace function profile_skills_sync(p_user uuid) returns void
language sql security definer set search_path = public as $$
  select _profile_skills_merge(p_user, '{}'::text[])
$$;
revoke all on function profile_skills_sync(uuid) from public, anon, authenticated;

create or replace function skill_save(p_id uuid, p_domain text, p_job text, p_skill text, p_level text, p_years numeric, p_description text, p_proof uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; d text := trim(coalesce(p_domain, '')); j text := trim(coalesce(p_job, '')); s text := trim(coalesce(p_skill, '')); v_old text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(d) < 2 then raise exception 'Choisissez un domaine'; end if;
  if char_length(s) < 2 then raise exception 'Choisissez ou saisissez une compétence'; end if;
  if p_level not in ('debutant', 'intermediaire', 'avance', 'expert') then raise exception 'Choisissez un niveau'; end if;
  if p_proof is not null and not exists (select 1 from user_documents where id = p_proof and owner_id = auth.uid()) then raise exception 'Justificatif introuvable'; end if;
  perform catalog_propose(d, j, s);
  if p_id is null then
    perform 1 from profiles where id = auth.uid() for update;
    if (select count(*) from talent_skills where owner_id = auth.uid()) >= 100 then raise exception 'Limite de 100 compétences atteinte'; end if;
    insert into talent_skills (owner_id, domain, job, skill, level, years, description, proof_document_id)
    values (auth.uid(), d, j, s, p_level, p_years, left(trim(coalesce(p_description, '')), 1000), p_proof) returning id into v;
  else
    select skill into v_old from talent_skills where id = p_id and owner_id = auth.uid();
    update talent_skills set domain = d, job = j, skill = s, level = p_level, years = p_years, description = left(trim(coalesce(p_description, '')), 1000),
      proof_document_id = p_proof, updated_at = now() where id = p_id and owner_id = auth.uid() returning id into v;
    if v is null then raise exception 'Compétence introuvable'; end if;
  end if;
  perform _profile_skills_merge(auth.uid(), case when v_old is not null and lower(v_old) <> lower(s) then array[v_old] else '{}'::text[] end);
  return v;
exception when unique_violation then raise exception 'Cette compétence est déjà dans votre profil';
end $$;

create or replace function skill_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_old text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from talent_skills where id = p_id and owner_id = auth.uid() returning skill into v_old;
  if not found then raise exception 'Compétence introuvable'; end if;
  perform _profile_skills_merge(auth.uid(), array[v_old]);
end $$;
revoke all on function skill_save(uuid, text, text, text, text, numeric, text, uuid), skill_delete(uuid) from public, anon;
grant execute on function skill_save(uuid, text, text, text, text, numeric, text, uuid), skill_delete(uuid) to authenticated;

-- ============================================================ 2. Talent Passport
create or replace function talent_passport(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := coalesce(p_user, auth.uid()); v_own boolean; p profiles%rowtype; v_points integer;
begin
  if v_user is null then return null; end if;
  v_own := v_user = auth.uid();
  select * into p from profiles where id = v_user and not coalesce(suspended, false);
  if not found or not profile_visible(v_user) then return null; end if;
  v_points := points_total(v_user);
  return jsonb_build_object(
    'user_id', p.id, 'own', v_own, 'name', p.name, 'certified', p.certification::text = 'approved',
    'points', v_points, 'level', point_level(v_points),
    'skills', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'domain', s.domain, 'job', s.job, 'skill', s.skill, 'level', s.level, 'years', s.years,
                                          'description', case when v_own then s.description else '' end,
                                          'has_proof', s.proof_document_id is not null, 'proof_verified', coalesce(d.status = 'verified', false))
                       order by case s.level when 'expert' then 0 when 'avance' then 1 when 'intermediaire' then 2 else 3 end, s.created_at)
      from talent_skills s left join user_documents d on d.id = s.proof_document_id where s.owner_id = v_user), '[]'::jsonb),
    'badges', coalesce((
      select jsonb_agg(jsonb_build_object('code', b.code, 'count', b.n) order by b.ord)
      from (
        select 1 as ord, 'certified'::text as code, 1 as n where p.certification::text = 'approved'
        union all select 2, 'certificates', count(*)::int from certificates c where c.holder_id = v_user and not c.revoked having count(*) > 0
        union all select 3, 'verified_documents', count(*)::int from user_documents d where d.owner_id = v_user and d.status = 'verified' having count(*) > 0
        union all select 4, 'proven_skills', count(*)::int from talent_skills s join user_documents d on d.id = s.proof_document_id and d.status = 'verified'
                   where s.owner_id = v_user having count(*) > 0
        union all select 5, 'expert_skills', count(*)::int from talent_skills s where s.owner_id = v_user and s.level = 'expert' having count(*) > 0
        union all select 6, 'missions', count(*)::int from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = v_user and mp.status = 'accepted'
                   where m.status in ('delivered', 'closed') having count(*) > 0
        union all select 7, 'helper', 1 where point_level(v_points) <> 'none'
      ) b), '[]'::jsonb));
end $$;
revoke all on function talent_passport(uuid) from public;
grant execute on function talent_passport(uuid) to anon, authenticated;

-- ============================================================ 3. CV vivant
-- Dernière définition : 20261115200300. Ajouts : toutes les réalisations du portfolio (type, lien http(s) seulement), niveaux de compétence, liens https:// uniquement.
create or replace function _cv_build(p_owner uuid, p_missions boolean, p_reviews boolean, p_links boolean, p_portfolio boolean, p_expires timestamptz) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('nom', p.name, 'departement', p.department, 'etablissement', p.institution, 'bio', p.bio, 'competences', p.skills,
      'competences_niveaux', coalesce((select jsonb_agg(jsonb_build_object('competence', s.skill, 'niveau', s.level, 'annees', s.years)
          order by case s.level when 'expert' then 0 when 'avance' then 1 when 'intermediaire' then 2 else 3 end, s.created_at)
          from (select * from talent_skills where owner_id = p_owner order by created_at limit 30) s), '[]'::jsonb),
      'certifie', p.certification::text = 'approved',
      'liens', case when p_links then coalesce((select jsonb_agg(l) from jsonb_array_elements(case when jsonb_typeof(p.links) = 'array' then p.links else '[]'::jsonb end) l
                                                where jsonb_typeof(l) = 'object' and coalesce(l ->> 'url', '') ~* '^https://[^\s<>"]+$'), '[]'::jsonb) else '[]'::jsonb end,
      'expire', p_expires,
      'realisations', case when p_portfolio then coalesce((select jsonb_agg(jsonb_build_object('titre', x.title, 'description', left(x.description, 300), 'categorie', x.category, 'date', x.happened_on,
            'type', x.kind, 'lien', case when x.url ~* '^https?://[^ ]+$' then x.url else '' end) order by x.featured desc, x.created_at desc)
          from (select * from portfolio_items where owner_id = p_owner order by featured desc, created_at desc limit 8) x), '[]'::jsonb) else '[]'::jsonb end,
      'missions', case when p_missions then coalesce((select jsonb_agg(jsonb_build_object('titre', m.title, 'statut', m.status) order by m.updated_at desc)
          from (select m.title, m.status, m.updated_at from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = p_owner and mp.status = 'accepted'
                where m.status in ('delivered', 'closed') and m.title is not null order by m.updated_at desc limit 8) m), '[]'::jsonb) else '[]'::jsonb end,
      'avis', case when p_reviews then jsonb_build_object(
          'nombre', (select count(*)::int from reviews r join listings li on li.id = r.listing_id where li.seller_id = p_owner),
          'moyenne', (select round(avg(r.rating)::numeric, 1) from reviews r join listings li on li.id = r.listing_id where li.seller_id = p_owner),
          'derniers', coalesce((select jsonb_agg(jsonb_build_object('note', q.rating, 'commentaire', q.comment) order by q.created_at desc)
              from (select r.rating, r.comment, r.created_at from reviews r join listings li on li.id = r.listing_id
                    where li.seller_id = p_owner and nullif(btrim(coalesce(r.comment, '')), '') is not null order by r.created_at desc limit 3) q), '[]'::jsonb))
        else null end)
  from profiles p where p.id = p_owner and not coalesce(p.suspended, false)
$$;
revoke all on function _cv_build(uuid, boolean, boolean, boolean, boolean, timestamptz) from public, anon, authenticated;

-- Retour arrière : rejouer _cv_build depuis 20261115200300_l10_cv_vivant.sql ; skill_save, skill_delete et profile_skills_sync depuis 20261110010000_talents_projets_portfolio.sql ;
--   drop function talent_passport(uuid), _profile_skills_merge(uuid, text[]).
