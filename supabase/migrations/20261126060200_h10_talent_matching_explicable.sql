-- H10 Talent (3/5) : matching EXPLICABLE entre une opportunité et un talent (CDC 7.3, B-722 à B-730, B-720).
-- Le moteur lit talent_skills (niveau, années, justificatif), les critères structurés de l'offre (opportunity_criteria, sinon opportunities.skills), le portfolio, les
-- certificats et le graphe de compétences (relations « proche_de » / « prerequis_de » alimentées par l'administrateur ; vide = aucune proximité inventée).
-- Pour chaque critère : satisfait / partiel (niveau ou années insuffisants ou non renseignés) / proche (compétence voisine dans le graphe) / manquant ; la compétence
-- retrouvée, son niveau, ses années, le justificatif (vérifié ou non), les réalisations et certificats cités comme preuves, les pistes de progression.
-- Score « explicable_v1 » sur 100 : compétences 60 (obligatoire = poids 3, souhaité = 1 ; satisfait 1, partiel 0,5, proche 0,5 × poids de la relation), preuves 10
-- (part des critères retrouvés appuyés par un justificatif vérifié ou un certificat), filière 15, disponibilité 15 (7 si non renseignée, comme le score historique).
-- Formule de DÉPART, NON CALIBRÉE (calibrage et poids = décision de produit) ; elle ne remplace PAS le score historique de _opp_match, qui reste renvoyé tel quel
-- (clé 'legacy') : opp_applications_for, opp_my_match, opps_recommended et opp_suggested_students ne changent pas.
-- AUCUNE décision automatique : ces RPC ne modifient aucun statut de candidature ; le texte renvoyé le rappelle.
-- Confidentialité : le candidat voit son propre résultat (offre publiée) ; l'organisation (propriétaire ou équipe, lecture) voit celui d'un candidat de son offre, ou d'un talent
-- visible dont la rubrique « competences » du passeport est partagée avec les organisations ; sinon seuls les NOMS de compétences (déjà visibles dans l'annuaire) sont utilisés.
-- Additive et rejouable. Retour arrière : drop function opp_applications_ranked(uuid), talent_skill_gaps(uuid, uuid), opp_match_explain(uuid, uuid), _talent_match_access(opportunities, uuid),
--   _talent_match_core(opportunities, uuid, boolean), _talent_has_skill_name(uuid, text), _talent_level_label(text).

create or replace function _talent_level_label(p_level text) returns text
language sql immutable set search_path = public as $$
  select case p_level when 'debutant' then 'Débutant' when 'intermediaire' then 'Intermédiaire' when 'avance' then 'Avancé' when 'expert' then 'Expert' else '' end
$$;
revoke all on function _talent_level_label(text) from public, anon;
grant execute on function _talent_level_label(text) to authenticated;

-- La personne déclare-t-elle cette compétence (passeport ou texte libre du profil), au nom exact près (accents et casse ignorés) ?
create or replace function _talent_has_skill_name(p_user uuid, p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from talent_skills t where t.owner_id = p_user and _skill_norm(t.skill) = _skill_norm(p_name))
      or exists (select 1 from profiles pr, regexp_split_to_table(lower(coalesce(pr.skills, '')), '[,;\n•]+') tok where pr.id = p_user and _skill_norm(tok) = _skill_norm(p_name))
$$;
revoke all on function _talent_has_skill_name(uuid, text) from public, anon, authenticated;

create or replace function _talent_match_core(o opportunities, p_user uuid, p_detail boolean default true) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  pr profiles%rowtype; leg jsonb; k record; t record; n text; v_status text; v_source text; v_credit numeric; v_w numeric;
  v_lvl text; v_yrs numeric; v_matched_as text; v_has_proof boolean; v_proof_ok boolean; v_port integer; v_cert integer;
  v_near_name text; v_near_w numeric; v_prereq jsonb; v_level_ok boolean; v_years_ok boolean; v_item jsonb;
  v_crit jsonb := '[]'; v_sat text[] := '{}'; v_par text[] := '{}'; v_close text[] := '{}'; v_mis text[] := '{}'; v_unmet text[] := '{}';
  v_reasons text[] := '{}'; v_reco jsonb := '[]'; v_proofs jsonb := '[]'; v_gaps jsonb := '[]';
  v_wsum numeric := 0; v_csum numeric := 0; v_matched integer := 0; v_proved integer := 0; v_total integer := 0; v_nproof_reco integer := 0;
  v_skills_pts integer; v_proof_pts integer; v_dept_pts integer; v_avail_pts integer; v_score integer;
begin
  select * into pr from profiles where id = p_user;
  if pr.id is null then return null; end if;
  leg := _opp_match(o, p_user);
  for k in
    select z.skill, z.importance, z.min_level, z.min_years from (
      select c.skill, c.importance, c.min_level, c.min_years, c.created_at ord from opportunity_criteria c where c.opportunity_id = o.id
      union all
      select btrim(s), 'souhaite', null::text, null::numeric, now() from unnest(o.skills) s
      where btrim(s) <> '' and not exists (select 1 from opportunity_criteria c where c.opportunity_id = o.id)) z
    order by (z.importance = 'obligatoire') desc, z.ord, z.skill
  loop
    v_total := v_total + 1;
    n := _skill_norm(k.skill);
    v_w := case k.importance when 'obligatoire' then 3 else 1 end;
    v_status := 'manquant'; v_source := null; v_credit := 0; v_lvl := null; v_yrs := null; v_matched_as := null; v_has_proof := null; v_proof_ok := null;
    v_port := 0; v_cert := 0; v_near_name := null; v_near_w := null; v_prereq := '[]'::jsonb; v_level_ok := null; v_years_ok := null;

    select ts.skill, ts.level, ts.years, ts.proof_document_id is not null as has_proof, coalesce(d.status = 'verified', false) as proof_ok into t
    from talent_skills ts left join user_documents d on d.id = ts.proof_document_id
    where ts.owner_id = p_user and (position(n in _skill_norm(ts.skill)) > 0 or position(_skill_norm(ts.skill) in n) > 0)
    order by (_skill_norm(ts.skill) = n) desc, _talent_level_rank(ts.level) desc nulls last limit 1;

    if t.skill is not null and p_detail then
      v_source := 'talent_skill'; v_matched_as := t.skill; v_lvl := t.level; v_yrs := t.years; v_has_proof := t.has_proof; v_proof_ok := t.proof_ok;
    elsif t.skill is not null then
      v_source := 'profil_texte'; v_matched_as := t.skill;
    else
      select btrim(tok) into v_matched_as from regexp_split_to_table(lower(coalesce(pr.skills, '')), '[,;\n•]+') tok
      where btrim(tok) <> '' and (position(n in _skill_norm(tok)) > 0 or position(_skill_norm(tok) in n) > 0) limit 1;
      if v_matched_as is not null then v_source := 'profil_texte'; end if;
    end if;

    if v_source is not null then
      v_level_ok := case when k.min_level is null then null when v_lvl is null then null else _talent_level_rank(v_lvl) >= _talent_level_rank(k.min_level) end;
      v_years_ok := case when k.min_years is null then null when v_yrs is null then null else v_yrs >= k.min_years end;
      if (k.min_level is null or v_level_ok is true) and (k.min_years is null or v_years_ok is true) then
        v_status := 'satisfait'; v_credit := 1;
      else
        v_status := 'partiel'; v_credit := 0.5;
      end if;
    else
      select b.skill, e.weight into v_near_name, v_near_w
      from skill_graph_edges e
      join skill_catalog a on a.id in (e.from_skill, e.to_skill) and _skill_norm(a.skill) = n and a.status = 'approved'
      join skill_catalog b on b.id = case when e.from_skill = a.id then e.to_skill else e.from_skill end and b.status = 'approved'
      where e.kind = 'proche_de' and _talent_has_skill_name(p_user, b.skill)
      order by e.weight desc, b.skill limit 1;
      if v_near_name is not null then v_status := 'proche'; v_credit := round(0.5 * v_near_w, 2); end if;
    end if;

    if v_status <> 'satisfait' then
      select coalesce(jsonb_agg(distinct p.skill), '[]'::jsonb) into v_prereq
      from skill_graph_edges e join skill_catalog a on a.id = e.to_skill and _skill_norm(a.skill) = n and a.status = 'approved'
      join skill_catalog p on p.id = e.from_skill and p.status = 'approved'
      where e.kind = 'prerequis_de' and not _talent_has_skill_name(p_user, p.skill);
    end if;

    if v_status in ('satisfait', 'partiel') then
      v_matched := v_matched + 1;
      if p_detail then
        select count(*)::int into v_port from portfolio_items pi where pi.owner_id = p_user and pi.kind = 'realisation'
          and position(n in _skill_norm(pi.title || ' ' || pi.category || ' ' || pi.description)) > 0;
        select count(*)::int into v_cert from certificates c where c.holder_id = p_user and not c.revoked and position(n in _skill_norm(c.subject_title)) > 0;
        if v_has_proof then
          v_proofs := v_proofs || jsonb_build_array(jsonb_build_object('skill', k.skill, 'kind', 'justificatif', 'state', case when v_proof_ok then 'verifie' else 'depose_non_verifie' end));
        end if;
        if v_port > 0 then v_proofs := v_proofs || jsonb_build_array(jsonb_build_object('skill', k.skill, 'kind', 'realisation', 'count', v_port)); end if;
        if v_cert > 0 then v_proofs := v_proofs || jsonb_build_array(jsonb_build_object('skill', k.skill, 'kind', 'certificat', 'count', v_cert)); end if;
        if coalesce(v_proof_ok, false) or v_cert > 0 then v_proved := v_proved + 1; end if;
      end if;
    end if;

    v_wsum := v_wsum + v_w; v_csum := v_csum + v_w * v_credit;
    if v_status = 'satisfait' then v_sat := v_sat || k.skill;
    elsif v_status = 'partiel' then v_par := v_par || k.skill;
    elsif v_status = 'proche' then v_close := v_close || k.skill;
    else v_mis := v_mis || k.skill; end if;
    if k.importance = 'obligatoire' and v_status <> 'satisfait' then v_unmet := v_unmet || k.skill; end if;

    if v_status = 'manquant' then
      v_reco := v_reco || jsonb_build_array(jsonb_build_object('kind', 'competence_manquante', 'skill', k.skill,
        'text', 'Compétence à acquérir ou à renseigner : ' || k.skill || case when jsonb_array_length(v_prereq) > 0 then ' (prérequis : ' || (select string_agg(x, ', ') from jsonb_array_elements_text(v_prereq) x) || ')' else '' end));
    elsif v_status = 'proche' then
      v_reco := v_reco || jsonb_build_array(jsonb_build_object('kind', 'competence_proche', 'skill', k.skill,
        'text', v_near_name || ' est proche de ' || k.skill || ' : renseignez ' || k.skill || ' si vous l''avez pratiquée, sinon complétez-la.'));
    elsif v_status = 'partiel' then
      v_reco := v_reco || jsonb_build_array(jsonb_build_object('kind', 'niveau_a_renforcer', 'skill', k.skill,
        'text', case when v_level_ok is false then k.skill || ' : niveau demandé ' || _talent_level_label(k.min_level) || ', niveau déclaré ' || _talent_level_label(v_lvl) || '.'
                     when v_years_ok is false then k.skill || ' : ' || k.min_years || ' an(s) demandé(s), ' || v_yrs || ' déclaré(s).'
                     else k.skill || ' : niveau ou années non renseignés, complétez la compétence dans votre passeport.' end));
    elsif v_source = 'talent_skill' and not coalesce(v_has_proof, false) and v_nproof_reco < 3 then
      v_nproof_reco := v_nproof_reco + 1;
      v_reco := v_reco || jsonb_build_array(jsonb_build_object('kind', 'justificatif', 'skill', k.skill, 'text', 'Ajoutez un justificatif vérifiable pour ' || k.skill || '.'));
    end if;

    v_item := jsonb_build_object('skill', k.skill, 'importance', k.importance, 'min_level', k.min_level, 'min_years', k.min_years, 'status', v_status, 'source', v_source,
      'matched_as', v_matched_as, 'level', v_lvl, 'years', v_yrs, 'level_ok', v_level_ok, 'years_ok', v_years_ok,
      'proof', case when v_source = 'talent_skill' then jsonb_build_object('has', v_has_proof, 'verified', v_proof_ok) else null end,
      'portfolio_count', v_port, 'certificate_count', v_cert, 'weight', v_w, 'credit', v_credit,
      'close_to', case when v_near_name is not null then jsonb_build_object('skill', v_near_name, 'weight', v_near_w) else null end, 'prerequisites_missing', v_prereq);
    v_crit := v_crit || jsonb_build_array(v_item);
    if v_status <> 'satisfait' then v_gaps := v_gaps || jsonb_build_array(v_item); end if;
  end loop;

  v_skills_pts := case when v_wsum > 0 then round(60 * v_csum / v_wsum)::int else 30 end;
  v_proof_pts := case when v_matched > 0 then round(10.0 * v_proved / v_matched)::int else 0 end;
  v_dept_pts := round(15.0 * coalesce((leg ->> 'department')::int, 0) / 25)::int;
  v_avail_pts := coalesce((leg ->> 'availability')::int, 0);
  v_score := least(100, v_skills_pts + v_proof_pts + v_dept_pts + v_avail_pts);

  if v_total = 0 then v_reasons := v_reasons || 'L''offre ne demande aucune compétence précise : la part « compétences » est neutre.'::text;
  else
    v_reasons := v_reasons || (cardinality(v_sat) || ' critère(s) satisfait(s) sur ' || v_total || (case when cardinality(v_par) > 0 then ', ' || cardinality(v_par) || ' partiel(s)' else '' end)
                               || (case when cardinality(v_close) > 0 then ', ' || cardinality(v_close) || ' proche(s)' else '' end) || '.');
  end if;
  if cardinality(v_unmet) > 0 then v_reasons := v_reasons || ('Critère(s) obligatoire(s) non satisfait(s) : ' || array_to_string(v_unmet, ', ') || '.'); end if;
  if v_matched > 0 and p_detail then v_reasons := v_reasons || (v_proved || ' critère(s) retrouvé(s) sur ' || v_matched || ' appuyé(s) par une preuve vérifiable.'); end if;
  if not p_detail then v_reasons := v_reasons || 'Niveaux, années et justificatifs non pris en compte : le talent n''a pas partagé cette rubrique de son passeport.'::text; end if;
  v_reasons := v_reasons || (case when coalesce((leg ->> 'department')::int, 0) >= 25 then 'La filière correspond (ou l''offre n''en vise aucune).' else 'La filière ne correspond pas à celle visée.' end);
  v_reasons := v_reasons || (case coalesce((leg ->> 'availability')::int, 0) when 15 then 'Disponibilité compatible avec le type d''offre.' when 7 then 'Disponibilité non renseignée.' else 'Disponibilité non compatible avec le type d''offre.' end);

  return jsonb_build_object('engine', 'explicable_v1', 'calibrated', false, 'automatic_decision', false, 'detail', p_detail,
    'score', v_score,
    'parts', jsonb_build_object('competences', jsonb_build_object('points', v_skills_pts, 'max', 60), 'preuves', jsonb_build_object('points', v_proof_pts, 'max', 10),
                                'filiere', jsonb_build_object('points', v_dept_pts, 'max', 15), 'disponibilite', jsonb_build_object('points', v_avail_pts, 'max', 15)),
    'criteria', v_crit, 'satisfied', to_jsonb(v_sat), 'partial', to_jsonb(v_par), 'close', to_jsonb(v_close), 'missing', to_jsonb(v_mis), 'mandatory_unmet', to_jsonb(v_unmet),
    'meets_all_mandatory', cardinality(v_unmet) = 0, 'proofs_used', v_proofs, 'reasons', to_jsonb(v_reasons), 'recommendations', v_reco, 'gaps', v_gaps,
    'legacy', leg,
    'notice', 'Ce classement aide à trier ; il ne décide de rien. Aucune embauche, présélection ni refus n''est automatique : la décision reste humaine.');
end $$;
revoke all on function _talent_match_core(opportunities, uuid, boolean) from public, anon, authenticated;

-- Droit de lire l'explication : renvoie true si le détail (niveaux, années, preuves) peut être utilisé.
create or replace function _talent_match_access(o opportunities, p_user uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_user is null or p_user = auth.uid() then
    if o.status <> 'published' and not _opp_can(o.poster_id, false) then raise exception 'Offre introuvable'; end if;
    return true;
  end if;
  if not _opp_can(o.poster_id, false) then raise exception 'Offre introuvable'; end if;
  if exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = p_user) then return true; end if;
  if _org_approved(o.poster_id) and _talent_listable(p_user) then return _passport_audience_ok(p_user, 'competences', o.poster_id); end if;
  raise exception 'Talent introuvable';
end $$;
revoke all on function _talent_match_access(opportunities, uuid) from public, anon, authenticated;

create or replace function opp_match_explain(p_opp uuid, p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype; v_detail boolean; v_u uuid; r jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp;
  if o.id is null then raise exception 'Offre introuvable'; end if;
  v_detail := _talent_match_access(o, p_user);
  v_u := coalesce(p_user, auth.uid());
  r := _talent_match_core(o, v_u, v_detail);
  if r is null then raise exception 'Talent introuvable'; end if;
  return r || jsonb_build_object('opportunity', jsonb_build_object('id', o.id, 'title', o.title, 'org', o.org_name), 'user_id', v_u,
    'name', case when v_u = auth.uid() then null else display_name(v_u) end);
end $$;

-- Lacunes d'un talent par rapport à une offre : critères non satisfaits, compétences proches (graphe), prérequis manquants, pistes de progression.
create or replace function talent_skill_gaps(p_opp uuid, p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r jsonb := opp_match_explain(p_opp, p_user);
begin
  return jsonb_build_object('opportunity', r -> 'opportunity', 'user_id', r -> 'user_id', 'gaps', r -> 'gaps', 'missing', r -> 'missing', 'close', r -> 'close', 'partial', r -> 'partial',
    'mandatory_unmet', r -> 'mandatory_unmet', 'recommendations', r -> 'recommendations', 'automatic_decision', false);
end $$;

-- Candidatures d'une offre classées avec l'explication synthétique. Ne modifie aucun statut.
create or replace function opp_applications_ranked(p_opp uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and _opp_can(poster_id, false);
  if o.id is null then raise exception 'Offre introuvable'; end if;
  return jsonb_build_object('automatic_decision', false,
    'notice', 'Ce classement aide à trier ; il ne décide de rien. Les décisions restent humaines.',
    'items', coalesce((select jsonb_agg(x.j order by (x.j ->> 'score')::int desc, x.j ->> 'created_at') from (
      select jsonb_build_object('application_id', a.id, 'applicant_id', a.applicant_id, 'name', display_name(a.applicant_id), 'status', a.status, 'created_at', a.created_at,
        'score', m.r -> 'score', 'legacy_score', m.r -> 'legacy' -> 'score', 'satisfied', m.r -> 'satisfied', 'partial', m.r -> 'partial', 'close', m.r -> 'close', 'missing', m.r -> 'missing',
        'mandatory_unmet', m.r -> 'mandatory_unmet', 'meets_all_mandatory', m.r -> 'meets_all_mandatory', 'reasons', m.r -> 'reasons', 'can_manage', _opp_can(o.poster_id, true)) j
      from opportunity_applications a cross join lateral (select _talent_match_core(o, a.applicant_id, true) r) m
      where a.opportunity_id = o.id and m.r is not null) x), '[]'::jsonb));
end $$;

revoke all on function opp_match_explain(uuid, uuid), talent_skill_gaps(uuid, uuid), opp_applications_ranked(uuid) from public, anon;
grant execute on function opp_match_explain(uuid, uuid), talent_skill_gaps(uuid, uuid), opp_applications_ranked(uuid) to authenticated;
