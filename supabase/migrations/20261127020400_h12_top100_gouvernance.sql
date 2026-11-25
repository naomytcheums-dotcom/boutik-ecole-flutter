-- Lot H12 / TOP100-B (5/5) : gouvernance et administration du Top 100 (CDC Top 100, section 10).
--  1. Indicateurs nationaux AGRÉGÉS (admin_ranking_national_indicators), qualité des données (admin_data_quality : affiliations en attente, étudiants sans filière, filières sans étudiant,
--     établissements sans filière, matricules en doublon, rattachements incohérents avec le profil), anomalies (admin_ranking_anomalies : alertes de fraude par signal, contestations ouvertes,
--     étudiants récidivistes, classements publiés contenant des entrées devenues inéligibles, intégrité des empreintes). Les listes détaillées existent déjà (partie A : admin_talent_flags_list,
--     admin_talent_disputes_list, student_affiliation_queue, ...) et ne sont PAS dupliquées. Droit : l'une des permissions institutions.manage, ranking.rules, ranking.publish, ranking.moderate.
--  2. Responsable institutionnel / responsable de département : my_ranking_scopes (périmètres accessibles) et scope_dashboard(établissement, département) = lecture AGRÉGÉE de SON périmètre
--     uniquement (effectif vérifié, actifs du mois, talents classés, rattachements en attente, répartition par filière, points moyens par étudiant vérifié, rang de l'établissement) ; jamais de nom ni de score
--     individuel ; moyenne masquée sous min_cohort. Un responsable ne lit jamais un autre établissement ni un autre département.
--  3. Notifications : entrée au classement et changement de rang (ranking_publish), correction (ranking_correct), décision de contestation et d'affiliation (partie A) utilisent la table notifications existante.
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière : drop function admin_ranking_national_indicators(), admin_data_quality(), admin_ranking_anomalies(), my_ranking_scopes(), scope_dashboard(uuid, uuid),
--   _ranking_scope_allowed(uuid, uuid), _top100_any_admin().

create or replace function _top100_any_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select has_any_admin_permission(array['institutions.manage', 'ranking.rules', 'ranking.publish', 'ranking.moderate'])
$$;
revoke all on function _top100_any_admin() from public, anon, authenticated;

-- Périmètre lisible par la personne connectée : administration (tout), responsable d'établissement (son établissement et ses départements), compte département rattaché et vérifié (son département).
create or replace function _ranking_scope_allowed(p_institution uuid, p_department uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare v_inst uuid;
begin
  if auth.uid() is null then return false; end if;
  if _top100_any_admin() then return true; end if;
  if p_department is not null then
    select institution_id into v_inst from departments where id = p_department;
    if v_inst is null then return false; end if;
    if _dept_of(auth.uid()) is not distinct from p_department then return true; end if;
    return exists (select 1 from institution_managers m join profiles p on p.id = m.user_id where m.user_id = auth.uid() and m.institution_id = v_inst and not coalesce(p.suspended, false));
  end if;
  if p_institution is not null then
    return exists (select 1 from institution_managers m join profiles p on p.id = m.user_id where m.user_id = auth.uid() and m.institution_id = p_institution and not coalesce(p.suspended, false));
  end if;
  return false;
end $$;
revoke all on function _ranking_scope_allowed(uuid, uuid) from public, anon, authenticated;

-- ============================================================ 1. Administration
create or replace function admin_ranking_national_indicators() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_period text := to_char(now() at time zone 'utc', 'YYYY-MM'); v_students integer; v_verified integer; v_aff integer; v_consent integer; v_active integer; v_avg numeric; lp ranking_periods;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _top100_any_admin() then raise exception 'Réservé : exige une permission du classement (institutions.manage, ranking.rules, ranking.publish ou ranking.moderate)'; end if;
  select count(*)::int into v_students from profiles where role::text = 'student' and not coalesce(suspended, false);
  select count(*)::int into v_verified from profiles p where p.role::text = 'student' and is_verified_student(p.id);
  select count(*)::int, count(*) filter (where coalesce(v.public_ranking, false))::int,
         count(*) filter (where exists (select 1 from talent_score_ledger l where l.user_id = a.user_id and l.period = v_period and l.points > 0))::int,
         round(avg(coalesce(ts.total, 0)), 2)
    into v_aff, v_consent, v_active, v_avg
    from student_affiliations a left join talent_visibility_settings v on v.user_id = a.user_id left join talent_scores ts on ts.user_id = a.user_id
    where a.status = 'verified' and a.ended_at is null and is_verified_student(a.user_id);
  select * into lp from ranking_periods where status = 'published' order by period desc limit 1;
  return jsonb_build_object('period', v_period,
    'students', jsonb_build_object('total', v_students, 'verified', v_verified, 'affiliated_verified', v_aff, 'consenting', v_consent, 'active_this_month', v_active, 'avg_score_per_affiliated_student', v_avg),
    'institutions', jsonb_build_object('verified', (select count(*)::int from institutions where status = 'verified'), 'proposed', (select count(*)::int from institutions where status = 'proposed'),
      'with_students', (select count(distinct a.institution_id)::int from student_affiliations a where a.status = 'verified' and a.ended_at is null),
      'programs_active', (select count(*)::int from programs where active)),
    'queue', jsonb_build_object('pending_affiliations', (select count(*)::int from student_affiliations where status = 'pending'),
      'open_fraud_flags', (select count(*)::int from talent_fraud_flags where status = 'open'), 'open_disputes', (select count(*)::int from talent_score_disputes where status = 'open')),
    'rankings', jsonb_build_object('published_periods', (select count(*)::int from ranking_periods where status = 'published'), 'archived_periods', (select count(*)::int from ranking_periods where status = 'archived'),
      'latest', case when lp.id is null then null else jsonb_build_object('period', lp.period, 'entries', lp.entries_count, 'published_at', lp.published_at, 'corrections', lp.correction_count) end,
      'rules_active', (select count(*)::int from talent_score_rules where active and points > 0),
      'settings_decided', coalesce((select s.min_score is not null and s.entries_limit is not null and cardinality(s.scopes) > 0 from ranking_settings s where s.id), false)),
    'by_institution', coalesce((select jsonb_agg(jsonb_build_object('institution_id', z.institution_id, 'name', z.name, 'verified_students', z.n, 'avg_score', z.avg) order by z.avg desc, z.name)
      from (select i.id institution_id, i.name, count(*)::int n, round(avg(coalesce(ts.total, 0)), 2) avg from student_affiliations a join institutions i on i.id = a.institution_id
            left join talent_scores ts on ts.user_id = a.user_id where a.status = 'verified' and a.ended_at is null and is_verified_student(a.user_id) group by i.id, i.name) z), '[]'::jsonb));
end $$;

create or replace function admin_data_quality() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _top100_any_admin() then raise exception 'Réservé : exige une permission du classement (institutions.manage, ranking.rules, ranking.publish ou ranking.moderate)'; end if;
  return jsonb_build_object(
    'pending_affiliations', jsonb_build_object('total', (select count(*)::int from student_affiliations where status = 'pending'),
      'oldest_days', (select floor(extract(epoch from now() - min(requested_at)) / 86400)::int from student_affiliations where status = 'pending'),
      'by_institution', coalesce((select jsonb_agg(jsonb_build_object('institution_id', z.institution_id, 'name', z.name, 'count', z.n) order by z.n desc, z.name)
        from (select a.institution_id, i.name, count(*)::int n from student_affiliations a join institutions i on i.id = a.institution_id where a.status = 'pending' group by a.institution_id, i.name) z), '[]'::jsonb)),
    'students_without_program', jsonb_build_object(
      'verified_without_affiliation', (select count(*)::int from profiles p where p.role::text = 'student' and is_verified_student(p.id)
                                        and not exists (select 1 from student_affiliations a where a.user_id = p.id and a.status = 'verified' and a.ended_at is null)),
      'with_pending_request', (select count(*)::int from profiles p where p.role::text = 'student' and is_verified_student(p.id)
                                and not exists (select 1 from student_affiliations a where a.user_id = p.id and a.status = 'verified' and a.ended_at is null)
                                and exists (select 1 from student_affiliations a where a.user_id = p.id and a.status = 'pending')),
      'sample', coalesce((select jsonb_agg(jsonb_build_object('user_id', x.id, 'name', _short_name(x.name), 'has_pending', x.pending) order by x.name)
        from (select p.id, p.name, exists (select 1 from student_affiliations a where a.user_id = p.id and a.status = 'pending') pending from profiles p
              where p.role::text = 'student' and is_verified_student(p.id) and not exists (select 1 from student_affiliations a where a.user_id = p.id and a.status = 'verified' and a.ended_at is null)
              order by p.name limit 50) x), '[]'::jsonb)),
    'programs', jsonb_build_object('inactive_with_students', (select count(*)::int from programs g where not g.active and exists (select 1 from student_affiliations a where a.program_id = g.id and a.status = 'verified' and a.ended_at is null)),
      'active_without_students', (select count(*)::int from programs g where g.active and not exists (select 1 from student_affiliations a where a.program_id = g.id and a.status = 'verified' and a.ended_at is null))),
    'institutions', jsonb_build_object('verified_without_programs', (select count(*)::int from institutions i where i.status = 'verified' and not exists (select 1 from programs g where g.institution_id = i.id)),
      'awaiting_review', (select count(*)::int from institutions where status = 'proposed')),
    'matricule_duplicates', (select count(*)::int from (select institution_id, lower(btrim(matricule)) m from profiles where role::text = 'student' and nullif(btrim(matricule), '') is not null and institution_id is not null
                                                        group by institution_id, lower(btrim(matricule)) having count(*) > 1) d),
    'profile_affiliation_mismatch', (select count(*)::int from student_affiliations a join profiles p on p.id = a.user_id where a.status = 'verified' and a.ended_at is null
                                      and p.institution_id is not null and p.institution_id <> a.institution_id));
end $$;

create or replace function admin_ranking_anomalies() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _top100_any_admin() then raise exception 'Réservé : exige une permission du classement (institutions.manage, ranking.rules, ranking.publish ou ranking.moderate)'; end if;
  return jsonb_build_object(
    'flags_open_by_signal', coalesce((select jsonb_object_agg(z.signal, z.n) from (select signal, count(*)::int n from talent_fraud_flags where status = 'open' group by signal) z), '{}'::jsonb),
    'flags_open', (select count(*)::int from talent_fraud_flags where status = 'open'),
    'disputes_open', (select count(*)::int from talent_score_disputes where status = 'open'),
    'repeat_students', coalesce((select jsonb_agg(jsonb_build_object('user_id', z.user_id, 'student', display_name(z.user_id), 'flags', z.n) order by z.n desc, z.user_id)
      from (select user_id, count(*)::int n from talent_fraud_flags group by user_id having count(*) >= 2 order by count(*) desc limit 20) z), '[]'::jsonb),
    'published_needing_correction', coalesce((select jsonb_agg(jsonb_build_object('period', z.period, 'entries', z.n) order by z.period desc)
      from (select p.period, count(*)::int n from ranking_entries e join ranking_periods p on p.id = e.period_id
            where p.status = 'published' and e.voided_at is null and not _ranking_still_eligible(e.user_id) group by p.period) z), '[]'::jsonb),
    'integrity', coalesce((select jsonb_agg(jsonb_build_object('period', p.period, 'intact', (ranking_verify_hash(p.period) ->> 'intact')::boolean) order by p.period desc) from ranking_periods p), '[]'::jsonb));
end $$;

-- ============================================================ 2. Périmètre d'un responsable
create or replace function my_ranking_scopes() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_dept uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_dept := _dept_of(auth.uid());
  return jsonb_build_object('admin', _top100_any_admin(),
    'institutions', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'name', i.name) order by i.name)
      from institution_managers m join institutions i on i.id = m.institution_id join profiles p on p.id = m.user_id where m.user_id = auth.uid() and not coalesce(p.suspended, false)), '[]'::jsonb),
    'department', (select jsonb_build_object('id', d.id, 'name', d.name, 'institution_id', d.institution_id) from departments d where d.id = v_dept));
end $$;

create or replace function scope_dashboard(p_institution uuid default null, p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_dept uuid; v_inst uuid; v_name text; v_kind text; v_period text := to_char(now() at time zone 'utc', 'YYYY-MM'); v_min integer := _talent_setting('min_cohort', 5)::integer;
        v_n integer; v_active integer; v_avg numeric; v_pending integer; v_ranked integer; v_lp uuid; v_programs jsonb; v_other integer; v_irank jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_institution is null and p_department is null then
    v_dept := _dept_of(auth.uid());
    if v_dept is null then
      select m.institution_id into v_inst from institution_managers m where m.user_id = auth.uid() order by m.assigned_at limit 1;
    end if;
  else
    v_dept := p_department; v_inst := p_institution;
  end if;
  if v_dept is null and v_inst is null then raise exception 'Précisez le périmètre (établissement ou département) : accès refusé hors de votre périmètre'; end if;
  if v_dept is not null then select institution_id into v_inst from departments where id = v_dept; end if;
  if not _ranking_scope_allowed(case when v_dept is null then v_inst end, v_dept) then raise exception 'Accès refusé : hors de votre périmètre'; end if;
  if v_dept is not null then
    select name into v_name from departments where id = v_dept; v_kind := 'department';
  else
    select name into v_name from institutions where id = v_inst; v_kind := 'institution';
  end if;
  if v_name is null then raise exception 'Périmètre introuvable'; end if;
  select count(*)::int, count(*) filter (where exists (select 1 from talent_score_ledger l where l.user_id = a.user_id and l.period = v_period and l.points > 0))::int,
         round(avg(coalesce(ts.total, 0)), 2)
    into v_n, v_active, v_avg
    from student_affiliations a join programs g on g.id = a.program_id left join talent_scores ts on ts.user_id = a.user_id
    where a.status = 'verified' and a.ended_at is null and is_verified_student(a.user_id)
      and ((v_dept is not null and g.department_id = v_dept) or (v_dept is null and a.institution_id = v_inst));
  select count(*)::int into v_pending from student_affiliations a join programs g on g.id = a.program_id
    where a.status = 'pending' and ((v_dept is not null and g.department_id = v_dept) or (v_dept is null and a.institution_id = v_inst));
  select id into v_lp from ranking_periods where status = 'published' order by period desc limit 1;
  select count(distinct e.user_id)::int into v_ranked from ranking_entries e
    where e.period_id = v_lp and e.voided_at is null and ((v_dept is not null and e.details ->> 'department_id' = v_dept::text) or (v_dept is null and e.details ->> 'institution_id' = v_inst::text));
  select coalesce(jsonb_agg(jsonb_build_object('program_id', x.program_id, 'name', x.name, 'verified_students', x.n) order by x.n desc, x.name), '[]'::jsonb) into v_programs
    from (select g.id program_id, g.name, count(*)::int n from student_affiliations a join programs g on g.id = a.program_id
          where a.status = 'verified' and a.ended_at is null and is_verified_student(a.user_id) and ((v_dept is not null and g.department_id = v_dept) or (v_dept is null and a.institution_id = v_inst))
          group by g.id, g.name having count(*) >= v_min) x;
  v_other := coalesce(v_n, 0) - coalesce((select sum((p ->> 'verified_students')::int) from jsonb_array_elements(v_programs) p), 0);
  select jsonb_build_object('period', p.period, 'rank', e.rank, 'delta_rank', e.delta_rank, 'avg_score', e.avg_score, 'verified_students', e.verified_students) into v_irank
    from ranking_institution_entries e join ranking_periods p on p.id = e.period_id where e.period_id = v_lp and e.institution_id = v_inst;
  return jsonb_build_object('scope', jsonb_build_object('kind', v_kind, 'id', coalesce(v_dept, v_inst), 'name', v_name), 'period', v_period, 'min_cohort', v_min,
    'verified_students', v_n, 'active_this_month', v_active, 'ranked_talents', v_ranked, 'pending_affiliations', v_pending,
    'avg_score_per_verified_student', case when v_n >= v_min then v_avg else null end,
    'avg_hidden_reason', case when v_n < v_min then 'cohorte_insuffisante' else null end,
    'programs', v_programs, 'other_programs_students', v_other, 'institution_ranking', v_irank,
    'note', 'Lecture agrégée de votre périmètre : aucun nom ni score individuel.');
end $$;

revoke all on function admin_ranking_national_indicators(), admin_data_quality(), admin_ranking_anomalies(), my_ranking_scopes(), scope_dashboard(uuid, uuid) from public, anon;
grant execute on function admin_ranking_national_indicators(), admin_data_quality(), admin_ranking_anomalies(), my_ranking_scopes(), scope_dashboard(uuid, uuid) to authenticated;
