-- Lot H13 / RANKING (4/5) : explications publiques du classement (page « Comment est calculé le classement »).
--  ranking_explain(p_period, p_scope, p_scope_ref) [PUBLIC, anonyme compris] : règles en vigueur à la date (règles FIGÉES de la période si elle est publiée, sinon règles actives à la fin de la période
--  d'après l'historique versionné), formule de calcul et de normalisation, critères d'éligibilité, réglages (figés ou courants), et NOMBRE D'EXCLUS PAR MOTIF sans aucune identité
--  (comptes agrégés ; le motif « contrôle d'intégrité » n'est affiché qu'à partir de 5 comptes). Sans classement publié : réponse honnête (published = false), jamais de donnée inventée.
--  Les décomptes d'exclus reflètent l'état actuel des comptes (exclusions_basis = 'current'), pas un instantané de la publication. Lecture seule.
-- Additive et rejouable, aucune donnée insérée. Retour arrière : drop function ranking_explain(text, text, text).

create or replace function ranking_explain(p_period text default null, p_scope text default 'national', p_scope_ref text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods; v_period text; v_end timestamptz; v_rules jsonb; v_settings jsonb; s ranking_settings; v_min numeric; v_minact integer; v_cohort integer := _talent_setting('min_cohort', 5)::integer;
        v_ref uuid; v_counts jsonb; v_causes jsonb; v_entries integer := 0; v_scope_ok boolean; v_fraud integer;
begin
  if p_scope is null or p_scope not in ('national', 'program', 'institution', 'department', 'domain') then raise exception 'Portée inconnue (national, program, institution, department, domain)'; end if;
  if p_period is not null and p_period !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Période invalide (format AAAA-MM)'; end if;
  if p_scope in ('program', 'institution', 'department') then
    begin v_ref := nullif(btrim(coalesce(p_scope_ref, '')), '')::uuid; exception when others then raise exception 'Référence de portée invalide'; end;
    if v_ref is null then raise exception 'Précisez la référence de la portée'; end if;
  end if;
  if p_period is null then select period into v_period from ranking_periods order by period desc limit 1; end if;
  v_period := coalesce(p_period, v_period, to_char(now() at time zone 'utc', 'YYYY-MM'));
  select * into pr from ranking_periods where period = v_period;
  v_end := least(now(), (to_date(v_period || '-01', 'YYYY-MM-DD') + interval '1 month')::timestamptz);
  select * into s from ranking_settings where id;

  if pr.id is not null then
    v_rules := coalesce((select jsonb_agg(r.v || jsonb_build_object('label', t.label, 'description', t.description) order by t.label)
      from jsonb_array_elements(pr.rules) r(v) join talent_score_rules t on t.code = r.v ->> 'code'), '[]'::jsonb);
    v_settings := pr.settings;
  else
    v_rules := coalesce((select jsonb_agg(jsonb_build_object('code', h.code, 'label', t.label, 'description', t.description, 'points', h.points, 'cap_per_day', h.cap_per_day, 'cap_per_period', h.cap_per_period,
        'quality_weight', h.quality_weight, 'version', h.version) order by t.label)
      from (select distinct on (x.code) x.* from talent_score_rule_history x where x.changed_at < v_end order by x.code, x.id desc) h join talent_score_rules t on t.code = h.code where h.active and h.points > 0), '[]'::jsonb);
    v_settings := case when s.id is null or s.min_score is null or s.entries_limit is null or cardinality(s.scopes) = 0 then null
      else jsonb_build_object('min_score', s.min_score, 'min_activities', s.min_activities, 'entries_limit', s.entries_limit, 'scopes', to_jsonb(s.scopes), 'min_cohort', v_cohort) end;
  end if;
  v_min := coalesce((v_settings ->> 'min_score')::numeric, 0);
  v_minact := (v_settings ->> 'min_activities')::integer;
  v_scope_ok := p_scope = 'national' or (v_settings is not null and (v_settings -> 'scopes') ? p_scope);

  select jsonb_object_agg(k, n) into v_counts from (
    select z.cause k, count(*)::int n from (
      select case
        when coalesce(p.suspended, false) then 'suspendus'
        when not is_verified_student(p.id) then 'non_verifies'
        when not exists (select 1 from student_affiliations a join institutions i on i.id = a.institution_id and i.status = 'verified' where a.user_id = p.id and a.status = 'verified' and a.ended_at is null) then 'sans_rattachement_verifie'
        when not coalesce((select v.public_ranking from talent_visibility_settings v where v.user_id = p.id), false) then 'non_consentants'
        when exists (select 1 from talent_fraud_flags f where f.user_id = p.id and f.status in ('open', 'confirmed')) then 'controle_integrite'
        when coalesce((select sum(l.points) from talent_score_ledger l where l.user_id = p.id and l.period <= v_period), 0) <= 0
             or coalesce((select sum(l.points) from talent_score_ledger l where l.user_id = p.id and l.period <= v_period), 0) < v_min then 'sous_le_seuil'
        when v_minact is not null and (select count(*) from talent_events e where e.user_id = p.id and e.status = 'confirmed' and e.occurred_at < (to_date(v_period || '-01', 'YYYY-MM-DD') + interval '1 month')) < v_minact then 'sous_le_seuil'
        else 'eligibles' end cause
      from profiles p where p.role::text = 'student'
        and (p_scope not in ('program', 'institution', 'department') or exists (
          select 1 from student_affiliations a join programs g on g.id = a.program_id
          where a.user_id = p.id and a.ended_at is null
            and ((p_scope = 'program' and a.program_id = v_ref) or (p_scope = 'institution' and a.institution_id = v_ref) or (p_scope = 'department' and g.department_id = v_ref))))
    ) z group by z.cause) y;
  v_counts := coalesce(v_counts, '{}'::jsonb);
  v_fraud := coalesce((v_counts ->> 'controle_integrite')::integer, 0);
  v_causes := jsonb_build_array(
    jsonb_build_object('motif', 'suspendus', 'label', 'Compte suspendu', 'count', coalesce((v_counts ->> 'suspendus')::integer, 0)),
    jsonb_build_object('motif', 'non_verifies', 'label', 'Compte étudiant non vérifié', 'count', coalesce((v_counts ->> 'non_verifies')::integer, 0)),
    jsonb_build_object('motif', 'sans_rattachement_verifie', 'label', 'Aucun rattachement vérifié à une filière d''un établissement vérifié', 'count', coalesce((v_counts ->> 'sans_rattachement_verifie')::integer, 0)),
    jsonb_build_object('motif', 'non_consentants', 'label', 'N''a pas accepté d''apparaître au classement public', 'count', coalesce((v_counts ->> 'non_consentants')::integer, 0)),
    jsonb_build_object('motif', 'controle_integrite', 'label', 'Contrôle d''intégrité en cours ou confirmé', 'count', case when v_fraud >= 5 then v_fraud end, 'masked', v_fraud between 1 and 4),
    jsonb_build_object('motif', 'sous_le_seuil', 'label', 'Score ou activités sous les seuils du classement', 'count', coalesce((v_counts ->> 'sous_le_seuil')::integer, 0)));
  if pr.id is not null then
    select count(*)::int into v_entries from ranking_entries e where e.period_id = pr.id and e.voided_at is null
      and (p_scope = 'national' and e.scope_kind = 'national' or (e.scope_kind = p_scope and e.scope_ref = coalesce(v_ref::text, '')));
  end if;

  return jsonb_build_object(
    'published', pr.id is not null, 'period', v_period, 'status', pr.status, 'published_at', pr.published_at, 'scope', p_scope, 'scope_ref', v_ref, 'scope_published', v_scope_ok,
    'rules_source', case when pr.id is not null then 'frozen_at_publication' else 'history_at_period_end' end,
    'rules', v_rules, 'rules_in_force', jsonb_array_length(v_rules) > 0, 'settings', v_settings, 'settings_decided', v_settings is not null,
    'formula', jsonb_build_object(
      'points', 'points attribués = points de la règle × ((1 − w) + w × qualité), où w est le poids qualité de la règle et la qualité est comprise entre 0 et 1 (0 si elle n''est pas mesurée)',
      'caps', 'Chaque règle a un plafond de points par jour (UTC) et par mois civil ; une activité qui dépasse le plafond ne rapporte que le reste, ou rien.',
      'score', 'Le score à la date d''un classement est la somme du registre de points dont la période est antérieure ou égale à ce mois. Chaque point attribué ou retiré est tracé.',
      'ranking', 'Classement par score décroissant ; à égalité, par points du mois, puis rang ex æquo.',
      'normalization', 'Les comparaisons se font par groupe (national, établissement, filière…) : un groupe de moins de ' || v_cohort || ' étudiants n''est pas publié, pour ne pas identifier une personne.',
      'institutions', 'Les établissements sont classés par points moyens par étudiant vérifié (zéros compris), puis par taux d''activité ; l''effectif seul ne sert jamais à classer.',
      'not_counted', 'Les vues, les mentions « j''aime » et les abonnés ne rapportent aucun point.',
      'freeze', 'Un classement publié ne change plus ; seule une correction auditée, motivée et tracée peut retirer une entrée ou recalculer un rang. Les empreintes sont vérifiables (ranking_verify_hash).'),
    'eligibility', jsonb_build_array('Compte étudiant vérifié et non suspendu', 'Rattachement vérifié à une filière d''un établissement vérifié', 'Consentement explicite au classement public',
      'Aucune alerte de fraude ouverte ou confirmée', 'Score strictement positif et au moins égal au seuil du classement', 'Nombre minimal d''activités confirmées si ce seuil est fixé', 'Groupe d''au moins ' || v_cohort || ' étudiants'),
    'exclusions', v_causes, 'eligible_now', coalesce((v_counts ->> 'eligibles')::integer, 0), 'exclusions_basis', 'current', 'as_of', now(), 'entries_in_scope', v_entries,
    'note', case when pr.id is null then 'Aucun classement n''est publié pour cette période. Les règles et seuils affichés sont ceux en vigueur ou à définir.' else null end);
end $$;

revoke all on function ranking_explain(text, text, text) from public;
grant execute on function ranking_explain(text, text, text) to anon, authenticated;
