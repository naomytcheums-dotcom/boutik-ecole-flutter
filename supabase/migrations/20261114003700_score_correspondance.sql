-- Score de correspondance (0 à 100) entre une offre et un étudiant, calculé uniquement à partir de ce que l'étudiant a renseigné.
--   Compétences demandées retrouvées dans son profil : 50 points (25 si l'offre n'en demande pas)
--   Filière visée : 25 points (25 si l'offre ne vise aucune filière)
--   Disponibilité compatible avec le type d'offre : 15 points (7 si l'étudiant n'a rien indiqué)
--   Profil renseigné (présentation 5, photo 5) : 10 points
-- Le score aide à trier ; il ne décide de rien et n'exclut personne.
create or replace function _opp_match(o opportunities, p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr profiles%rowtype; av student_availability%rowtype; have boolean; want text[]; sk text; v_total integer;
        v_skills numeric := 0; v_found integer := 0; v_dept integer := 0; v_avail integer := 0; v_prof integer := 0; v_need text; v_kinds text[];
begin
  select * into pr from profiles where id = p_user;
  if not found then return null; end if;
  -- compétences
  if cardinality(o.skills) = 0 then
    v_skills := 25;
  else
    foreach sk in array o.skills loop
      if btrim(sk) <> '' and exists (
           select 1 from regexp_split_to_table(lower(coalesce(pr.skills, '')), '[,;\n•]+') t
           where btrim(t) <> '' and (btrim(t) like '%' || lower(btrim(sk)) || '%' or lower(btrim(sk)) like '%' || btrim(t) || '%')) then
        v_found := v_found + 1;
      end if;
    end loop;
    v_skills := round(50.0 * v_found / cardinality(o.skills));
  end if;
  -- filière
  if btrim(coalesce(o.department_target, '')) = '' then
    v_dept := 25;
  else
    foreach sk in array regexp_split_to_array(lower(o.department_target), '\s*,\s*') loop
      if btrim(sk) <> '' and btrim(coalesce(pr.department, '')) <> '' and (lower(pr.department) like '%' || btrim(sk) || '%' or btrim(sk) like '%' || lower(pr.department) || '%') then
        v_dept := 25;
      end if;
    end loop;
  end if;
  -- disponibilité
  select * into av from student_availability where user_id = p_user;
  if not found or cardinality(av.kinds) = 0 then
    v_avail := 7;
  else
    v_kinds := case o.kind when 'stage' then array['internship', 'vacation'] when 'emploi' then array['job'] when 'mission' then array['mission'] when 'benevolat' then array['volunteer'] else array[]::text[] end;
    if av.kinds && v_kinds then v_avail := 15; end if;
  end if;
  -- profil renseigné
  if btrim(coalesce(pr.bio, '')) <> '' then v_prof := v_prof + 5; end if;
  if coalesce(pr.avatar_url, '') <> '' then v_prof := v_prof + 5; end if;
  v_total := least(100, v_skills::int + v_dept + v_avail + v_prof);
  return jsonb_build_object('score', v_total, 'skills', v_skills::int, 'skills_found', v_found, 'skills_wanted', cardinality(o.skills), 'department', v_dept, 'availability', v_avail, 'profile', v_prof);
end $$;
revoke all on function _opp_match(opportunities, uuid) from public, anon, authenticated;

-- Candidatures reçues : même résultat qu'avant, avec le score de chaque candidat.
create or replace function opp_applications_for(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  select * into o from opportunities where id = p_id and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'applicant_id', a.applicant_id, 'name', display_name(a.applicant_id), 'department', pr.department, 'message', a.message, 'cv_link', a.cv_link,
      'status', a.status, 'created_at', a.created_at, 'match', _opp_match(o, a.applicant_id)) order by a.created_at desc)
    from opportunity_applications a join profiles pr on pr.id = a.applicant_id where a.opportunity_id = p_id), '[]'::jsonb);
end $$;

-- Étudiants qui correspondent le mieux à une offre (son auteur seulement) : étudiants actifs ayant renseigné une présentation ou des compétences,
-- hors personnes déjà candidates. Les plus proches d'abord.
create or replace function opp_suggested_students(p_id uuid, p_limit integer default 10) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  select * into o from opportunities where id = p_id and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  return coalesce((
    select jsonb_agg(t.j order by (t.j->'match'->>'score')::int desc, t.j->>'name')
    from (select x.j
          from (select jsonb_build_object('id', pr.id, 'name', display_name(pr.id), 'department', pr.department, 'avatar_url', pr.avatar_url, 'match', _opp_match(o, pr.id)) j
                from profiles pr
                where pr.role = 'student' and not pr.suspended and pr.id <> o.poster_id
                  and (btrim(coalesce(pr.skills, '')) <> '' or btrim(coalesce(pr.bio, '')) <> '')
                  and not exists (select 1 from opportunity_applications a where a.opportunity_id = p_id and a.applicant_id = pr.id)
                limit 500) x
          where (x.j->'match'->>'score')::int >= 30
          order by (x.j->'match'->>'score')::int desc, x.j->>'name'
          limit greatest(1, least(coalesce(p_limit, 10), 30))) t), '[]'::jsonb);
end $$;

revoke all on function opp_suggested_students(uuid, integer) from public, anon;
grant execute on function opp_suggested_students(uuid, integer) to authenticated;
