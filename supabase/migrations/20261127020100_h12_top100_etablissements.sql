-- Lot H12 / TOP100-B (2/5) : classement des établissements, indicateurs NORMALISÉS par étudiant vérifié (CDC Top 100, 1.4 et 1.6).
--  1. ranking_institution_entries : une ligne par établissement et par classement mensuel, figée à la publication (hook de ranking_publish) avec la même garde d'immutabilité et la même empreinte
--     que les classements d'étudiants (l'empreinte de la période les inclut).
--  2. Indicateurs par établissement vérifié, comptés sur les seuls étudiants au rattachement VÉRIFIÉ et vérifiés (comptes non suspendus) :
--     - verified_students (effectif vérifié, affiché mais JAMAIS utilisé seul pour classer) ; active_students = étudiants ayant des points dans le mois de la période ;
--     - ranked_talents = étudiants de l'établissement présents au classement publié ; projects, badges (badges + certificats), challenges, missions (missions + collaborations) = activités
--       confirmées tracées (talent_events) avant la fin de la période ;
--     - avg_score = points moyens PAR ÉTUDIANT VÉRIFIÉ (somme des scores / effectif vérifié, zéros compris) : un grand effectif n'est pas avantagé ; avg_month_points = progression mensuelle moyenne ;
--       active_rate = part d'étudiants actifs ; ratios par étudiant (projects_per_student, ...).
--     Classement = avg_score décroissant puis active_rate ; un établissement n'est classé qu'à partir de min_cohort étudiants vérifiés (aucune comparaison sur un trop petit effectif).
--     Répartition par filière : filières d'au moins min_cohort étudiants vérifiés, le reste regroupé (aucun individu identifiable).
--  3. RPC PUBLIQUES (anon et connectés, données publiées seulement) : ranking_institutions_public(période, établissement), ranking_institution_history(établissement).
--  4. _ranking_period_hash et ranking_verify_hash couvrent aussi les établissements.
--  Les corrections de classement d'étudiants (ranking_correct) ne modifient pas ce tableau : il porte sur des effectifs agrégés vérifiés.
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière : drop function ranking_institutions_public(text, uuid), ranking_institution_history(uuid), _ranking_institutions_build(uuid, text),
--   _ranking_inst_entry_hash(ranking_institution_entries), _ranking_guard_inst() ; remettre _ranking_period_hash et ranking_verify_hash de 20261127020000 ; drop table ranking_institution_entries.

create table if not exists ranking_institution_entries (
  id bigint generated always as identity primary key,
  period_id uuid not null references ranking_periods (id),
  institution_id uuid not null,
  rank integer not null check (rank >= 1),
  verified_students integer not null check (verified_students >= 0),
  active_students integer not null check (active_students >= 0),
  ranked_talents integer not null default 0,
  projects integer not null default 0,
  badges integer not null default 0,
  challenges integer not null default 0,
  missions integer not null default 0,
  avg_score numeric(12, 2) not null,
  avg_month_points numeric(12, 2) not null,
  active_rate numeric(5, 2) not null,
  prev_rank integer,
  delta_rank integer,
  delta_avg_score numeric(12, 2),
  is_new boolean not null default false,
  details jsonb not null default '{}'::jsonb,
  entry_hash text not null default '',
  unique (period_id, institution_id)
);
create index if not exists ranking_institution_entries_rank on ranking_institution_entries (period_id, rank);
alter table ranking_institution_entries enable row level security;
revoke all on ranking_institution_entries from public, anon, authenticated;

create or replace function _ranking_inst_entry_hash(e ranking_institution_entries) returns text
language sql stable set search_path = public as $$
  select encode(sha256(convert_to(concat_ws('|', e.period_id, e.institution_id, e.rank, e.verified_students, e.active_students, e.ranked_talents, e.projects, e.badges, e.challenges, e.missions,
    e.avg_score, e.avg_month_points, e.active_rate, coalesce(e.prev_rank::text, ''), coalesce(e.delta_rank::text, ''), e.is_new, e.details::text), 'UTF8')), 'hex')
$$;
revoke all on function _ranking_inst_entry_hash(ranking_institution_entries) from public, anon, authenticated;

create or replace function _ranking_guard_inst() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op <> 'INSERT' then raise exception 'Le classement publié des établissements ne se modifie pas'; end if;
  if coalesce(current_setting('app.ranking_write', true), '') <> 'on' then raise exception 'Publication réservée à ranking_publish'; end if;
  new.entry_hash := _ranking_inst_entry_hash(new);
  return new;
end $$;
revoke all on function _ranking_guard_inst() from public, anon, authenticated;
drop trigger if exists trg_ranking_guard_inst on ranking_institution_entries;
create trigger trg_ranking_guard_inst before insert or update or delete on ranking_institution_entries for each row execute function _ranking_guard_inst();

-- Empreintes : les établissements entrent dans l'empreinte de la période seulement s'il y en a (les périodes antérieures gardent leur empreinte).
create or replace function _ranking_period_hash(p_period uuid) returns text
language sql stable security definer set search_path = public as $$
  select encode(sha256(convert_to(concat_ws('|', p.period, p.settings::text, p.rules::text,
    coalesce((select string_agg(e.entry_hash, ',' order by e.id) from ranking_entries e where e.period_id = p.id), ''),
    nullif((select string_agg(i.entry_hash, ',' order by i.id) from ranking_institution_entries i where i.period_id = p.id), '')), 'UTF8')), 'hex')
  from ranking_periods p where p.id = p_period
$$;
revoke all on function _ranking_period_hash(uuid) from public, anon, authenticated;

create or replace function ranking_verify_hash(p_period text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods; v_entries boolean; v_inst boolean; v_hash text;
begin
  select * into pr from ranking_periods where period = p_period;
  if pr.id is null then return jsonb_build_object('found', false); end if;
  select coalesce(bool_and(e.entry_hash = _ranking_entry_hash(e)), true) into v_entries from ranking_entries e where e.period_id = pr.id;
  select coalesce(bool_and(i.entry_hash = _ranking_inst_entry_hash(i)), true) into v_inst from ranking_institution_entries i where i.period_id = pr.id;
  v_hash := _ranking_period_hash(pr.id);
  return jsonb_build_object('found', true, 'period', pr.period, 'status', pr.status, 'content_hash', pr.content_hash, 'intact', v_entries and v_inst and v_hash = pr.content_hash, 'corrections', pr.correction_count);
end $$;
revoke all on function ranking_verify_hash(text) from public;
grant execute on function ranking_verify_hash(text) to anon, authenticated;

-- Construction à la publication (appelée par ranking_publish, sous app.ranking_write = on).
create or replace function _ranking_institutions_build(p_period_id uuid, p_period text) returns integer
language plpgsql security definer set search_path = public as $$
declare v_end timestamp := to_date(p_period || '-01', 'YYYY-MM-DD') + interval '1 month'; v_cohort integer := _talent_setting('min_cohort', 5)::integer; v_prev text; v_n integer;
begin
  select period into v_prev from ranking_periods where period < p_period order by period desc limit 1;
  with st as (
    select a.user_id, a.institution_id, a.program_id, sc.score, sc.mp, ev.projects, ev.badges, ev.challenges, ev.missions
    from student_affiliations a
    join institutions i on i.id = a.institution_id and i.status = 'verified'
    cross join lateral (select coalesce(sum(l.points) filter (where l.period <= p_period), 0)::int score, coalesce(sum(l.points) filter (where l.period = p_period), 0)::int mp
                        from talent_score_ledger l where l.user_id = a.user_id) sc
    cross join lateral (select count(*) filter (where e.rule_code = 'project_published_with_proof')::int projects,
                               count(*) filter (where e.rule_code in ('badge_verified', 'certificate_verified'))::int badges,
                               count(*) filter (where e.rule_code = 'challenge_participation')::int challenges,
                               count(*) filter (where e.rule_code in ('mission_validated', 'collaboration'))::int missions
                        from talent_events e where e.user_id = a.user_id and e.status = 'confirmed' and e.occurred_at < v_end) ev
    where a.status = 'verified' and a.ended_at is null and is_verified_student(a.user_id)
  ),
  agg as (
    select s.institution_id, count(*)::int verified, count(*) filter (where s.mp > 0)::int active, sum(s.score)::numeric sum_score, sum(s.mp)::numeric sum_mp,
           sum(s.projects)::int projects, sum(s.badges)::int badges, sum(s.challenges)::int challenges, sum(s.missions)::int missions
    from st s group by s.institution_id having count(*) >= v_cohort
  ),
  ranked as (
    select g.*, round(g.sum_score / g.verified, 2) avg_score, round(g.sum_mp / g.verified, 2) avg_mp, round(100.0 * g.active / g.verified, 2) active_rate,
           (select count(distinct e.user_id)::int from ranking_entries e where e.period_id = p_period_id and e.voided_at is null and e.details ->> 'institution_id' = g.institution_id::text) ranked_talents
    from agg g
  ),
  ordered as (
    select r.*, rank() over (order by r.avg_score desc, r.active_rate desc) rk from ranked r
  )
  insert into ranking_institution_entries (period_id, institution_id, rank, verified_students, active_students, ranked_talents, projects, badges, challenges, missions, avg_score, avg_month_points, active_rate,
                                           prev_rank, delta_rank, delta_avg_score, is_new, details)
  select p_period_id, o.institution_id, o.rk, o.verified, o.active, o.ranked_talents, o.projects, o.badges, o.challenges, o.missions, o.avg_score, o.avg_mp, o.active_rate,
         pe.rank, case when pe.id is null then null else pe.rank - o.rk end, case when pe.id is null then null else o.avg_score - pe.avg_score end, pe.id is null,
         jsonb_build_object('name', i.name, 'short_name', i.short_name, 'city', i.city, 'kind', i.kind,
           'per_student', jsonb_build_object('projects', round(o.projects::numeric / o.verified, 3), 'badges', round(o.badges::numeric / o.verified, 3), 'challenges', round(o.challenges::numeric / o.verified, 3),
                                              'missions', round(o.missions::numeric / o.verified, 3)),
           'programs', coalesce((select jsonb_agg(jsonb_build_object('program_id', x.program_id, 'name', x.name, 'verified_students', x.n, 'avg_score', x.av) order by x.n desc, x.name)
                                 from (select s.program_id, g.name, count(*)::int n, round(avg(s.score), 2) av from st s join programs g on g.id = s.program_id where s.institution_id = o.institution_id
                                       group by s.program_id, g.name having count(*) >= v_cohort) x), '[]'::jsonb),
           'other_programs_students', (select count(*)::int from st s where s.institution_id = o.institution_id
                                       and s.program_id not in (select s2.program_id from st s2 where s2.institution_id = o.institution_id group by s2.program_id having count(*) >= v_cohort)))
  from ordered o join institutions i on i.id = o.institution_id
  left join lateral (select pi.id, pi.rank, pi.avg_score from ranking_institution_entries pi join ranking_periods pp on pp.id = pi.period_id
                     where pp.period = v_prev and pi.institution_id = o.institution_id limit 1) pe on true;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke all on function _ranking_institutions_build(uuid, text) from public, anon, authenticated;

-- ============================================================ RPC publiques
create or replace function ranking_institutions_public(p_period text default null, p_institution uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods;
begin
  if p_period is not null then
    select * into pr from ranking_periods where period = p_period;
  else
    select * into pr from ranking_periods where status = 'published' order by period desc limit 1;
  end if;
  if pr.id is null then
    return jsonb_build_object('published', false, 'period', p_period, 'items', '[]'::jsonb, 'note', 'Aucun classement n''est publié pour le moment.');
  end if;
  return jsonb_build_object('published', true, 'period', pr.period, 'status', pr.status, 'published_at', pr.published_at,
    'method', 'Classement par points moyens par étudiant vérifié (jamais par effectif seul), à partir de ' || _talent_setting('min_cohort', 5)::integer || ' étudiants vérifiés.',
    'items', coalesce((select jsonb_agg(jsonb_build_object('rank', e.rank, 'institution_id', e.institution_id, 'name', e.details ->> 'name', 'short_name', e.details ->> 'short_name', 'city', e.details ->> 'city',
        'verified_students', e.verified_students, 'active_students', e.active_students, 'active_rate', e.active_rate, 'ranked_talents', e.ranked_talents, 'projects', e.projects, 'badges', e.badges,
        'challenges', e.challenges, 'missions', e.missions, 'avg_score', e.avg_score, 'avg_month_points', e.avg_month_points, 'per_student', e.details -> 'per_student',
        'delta_rank', e.delta_rank, 'delta_avg_score', e.delta_avg_score, 'is_new', e.is_new, 'programs', e.details -> 'programs', 'other_programs_students', e.details -> 'other_programs_students') order by e.rank, e.details ->> 'name')
      from ranking_institution_entries e where e.period_id = pr.id and (p_institution is null or e.institution_id = p_institution)), '[]'::jsonb));
end $$;

create or replace function ranking_institution_history(p_institution uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if p_institution is null then raise exception 'Établissement obligatoire'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('period', p.period, 'status', p.status, 'rank', e.rank, 'avg_score', e.avg_score, 'avg_month_points', e.avg_month_points, 'verified_students', e.verified_students,
      'active_rate', e.active_rate, 'delta_rank', e.delta_rank) order by p.period desc)
    from ranking_institution_entries e join ranking_periods p on p.id = e.period_id where e.institution_id = p_institution), '[]'::jsonb);
end $$;

revoke all on function ranking_institutions_public(text, uuid), ranking_institution_history(uuid) from public;
grant execute on function ranking_institutions_public(text, uuid), ranking_institution_history(uuid) to anon, authenticated;
