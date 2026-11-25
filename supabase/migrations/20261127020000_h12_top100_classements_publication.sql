-- Lot H12 / TOP100-B (1/5) : réglages du classement, consentement des talents, classements mensuels FIGÉS, publication, correction auditée, archivage (CDC Top 100, 1.1, 1.2, 9 et 10).
--  1. ranking_settings : seuil minimal d'activité (points, nombre d'activités), nombre d'entrées par classement, portées publiées (national, filière, établissement, département, domaine).
--     AUCUNE valeur par défaut : tant que l'administration n'a pas décidé, rien ne peut être publié (aucune ligne n'est insérée par la migration). Taille minimale d'une cohorte : paramètre min_cohort (010100).
--  2. talent_visibility_settings : consentement de l'étudiant (apparaître au classement public, nom complet, photo, rubriques partagées, disponibilité publiable). Absence de ligne = NON visible.
--  3. ranking_periods / ranking_entries : un classement par mois (AAAA-MM), figé à la publication (rang, score, points du mois, delta, détails, empreinte SHA-256 de chaque entrée et de l'ensemble).
--     Score à la date de la période = somme du registre de points dont la période est <= à la période (registre en ajout seul : reproductible). Une publication ne change plus ;
--     seule une CORRECTION AUDITÉE (ranking_corrections : ancienne et nouvelle valeur, motif, auteur) peut retirer une entrée devenue inéligible et recalculer les rangs ; un classement archivé ne se corrige plus.
--  4. ranking_publish(période) : permission ranking.publish (+ 2FA si facteur vérifié). Exclut les étudiants non vérifiés, non rattachés (filière vérifiée), non consentants, suspendus, signalés
--     pour fraude (alerte ouverte ou confirmée) et sous le seuil (ou à 0 point). Refuse si les réglages ne sont pas décidés, si aucune règle de score n'est active, si la période est future ou déjà publiée,
--     ou si personne n'est éligible. Les groupes (filière, établissement, département, domaine) plus petits que min_cohort ne sont pas publiés.
--  5. RPC : my_top100_visibility_get/set (étudiant), admin_ranking_settings_get/set (ranking.rules), admin_ranking_readiness, ranking_publish, ranking_correct, ranking_archive,
--     admin_ranking_periods_list, admin_ranking_corrections_list (ranking.publish), ranking_verify_hash (public : l'empreinte ne révèle rien).
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière :
--   drop function my_top100_visibility_get(), my_top100_visibility_set(boolean, boolean, boolean, text[], boolean), admin_ranking_settings_get(), admin_ranking_settings_set(integer, integer, integer, text[], text),
--     admin_ranking_readiness(text), ranking_publish(text), ranking_correct(text, text, uuid), ranking_archive(text, text), admin_ranking_periods_list(), admin_ranking_corrections_list(text), ranking_verify_hash(text),
--     _ranking_blockers(text), _ranking_candidates(text), _ranking_badges(uuid), _ranking_entry_hash(ranking_entries), _ranking_period_hash(uuid), _ranking_still_eligible(uuid), _ranking_guard_period(), _ranking_guard_entry(),
--     _ranking_guard_entry_delete(), _ranking_period_ok(text) ; drop table ranking_corrections, ranking_entries, ranking_periods, talent_visibility_settings, ranking_settings.

-- ============================================================ 1. Tables
create table if not exists ranking_settings (
  id boolean primary key default true check (id),
  min_score integer check (min_score is null or min_score >= 0),
  min_activities integer check (min_activities is null or min_activities >= 0),
  entries_limit integer check (entries_limit is null or entries_limit between 1 and 1000),
  scopes text[] not null default '{}' check (scopes <@ array['national', 'program', 'institution', 'department', 'domain']::text[]),
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists talent_visibility_settings (
  user_id uuid primary key references profiles (id) on delete cascade,
  public_ranking boolean not null default false,
  show_full_name boolean not null default false,
  show_photo boolean not null default false,
  shared_sections text[] not null default '{}' check (shared_sections <@ array['rank', 'score', 'evolution', 'skills', 'badges', 'projects', 'passport']::text[]),
  availability_public boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists ranking_periods (
  id uuid primary key default gen_random_uuid(),
  period text not null unique check (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  status text not null default 'published' check (status in ('published', 'archived')),
  published_at timestamptz not null default now(),
  published_by uuid,
  settings jsonb not null,
  rules jsonb not null,
  entries_count integer not null default 0,
  content_hash text not null,
  correction_count integer not null default 0,
  last_corrected_at timestamptz,
  archived_at timestamptz,
  archived_by uuid
);

create table if not exists ranking_entries (
  id bigint generated always as identity primary key,
  period_id uuid not null references ranking_periods (id),
  scope_kind text not null check (scope_kind in ('national', 'program', 'institution', 'department', 'domain')),
  scope_ref text not null default '',
  user_id uuid not null references profiles (id) on delete cascade,
  rank integer not null check (rank >= 1),
  score integer not null check (score > 0),
  month_points integer not null default 0,
  prev_rank integer,
  delta_rank integer,
  delta_score integer,
  is_new boolean not null default false,
  details jsonb not null default '{}'::jsonb,
  voided_at timestamptz,
  void_reason text,
  entry_hash text not null default '',
  unique (period_id, scope_kind, scope_ref, user_id)
);
create index if not exists ranking_entries_scope on ranking_entries (period_id, scope_kind, scope_ref, rank);
create index if not exists ranking_entries_user on ranking_entries (user_id, period_id);

create table if not exists ranking_corrections (
  id bigint generated always as identity primary key,
  period_id uuid not null references ranking_periods (id),
  entry_id bigint,
  user_id uuid,
  scope_kind text,
  scope_ref text,
  field text not null check (field in ('entry', 'rank')),
  old_value jsonb not null,
  new_value jsonb not null,
  reason text not null,
  corrected_by uuid,
  corrected_at timestamptz not null default now()
);
create index if not exists ranking_corrections_period on ranking_corrections (period_id, id);

alter table ranking_settings enable row level security;
alter table talent_visibility_settings enable row level security;
alter table ranking_periods enable row level security;
alter table ranking_entries enable row level security;
alter table ranking_corrections enable row level security;
revoke all on ranking_settings, talent_visibility_settings, ranking_periods, ranking_entries, ranking_corrections from public, anon, authenticated;

-- ============================================================ 2. Gardes d'immutabilité
-- Les fonctions du lot posent app.ranking_write = on ; sans cela aucune écriture n'est possible sur un classement.
create or replace function _ranking_entry_hash(e ranking_entries) returns text
language sql stable set search_path = public as $$
  select encode(sha256(convert_to(concat_ws('|', e.period_id, e.scope_kind, e.scope_ref, e.rank, e.user_id, e.score, e.month_points, coalesce(e.prev_rank::text, ''), coalesce(e.delta_rank::text, ''),
    e.is_new, e.details::text, (e.voided_at is not null)), 'UTF8')), 'hex')
$$;
revoke all on function _ranking_entry_hash(ranking_entries) from public, anon, authenticated;

create or replace function _ranking_guard_entry() returns trigger
language plpgsql set search_path = public as $$
begin
  if coalesce(current_setting('app.ranking_write', true), '') <> 'on' then raise exception 'Un classement publié ne se modifie pas : utilisez une correction auditée'; end if;
  if tg_op = 'UPDATE' and (new.period_id is distinct from old.period_id or new.scope_kind is distinct from old.scope_kind or new.scope_ref is distinct from old.scope_ref
      or new.user_id is distinct from old.user_id or new.score is distinct from old.score or new.month_points is distinct from old.month_points or new.prev_rank is distinct from old.prev_rank
      or new.is_new is distinct from old.is_new or new.details is distinct from old.details or (old.voided_at is not null and new.voided_at is distinct from old.voided_at)) then
    raise exception 'Seuls le rang, le delta et le retrait d''une entrée peuvent être corrigés';
  end if;
  if tg_op = 'UPDATE' and exists (select 1 from ranking_periods p where p.id = new.period_id and p.status <> 'published') then raise exception 'Ce classement est archivé : il ne peut plus être corrigé'; end if;
  new.entry_hash := _ranking_entry_hash(new);
  return new;
end $$;
revoke all on function _ranking_guard_entry() from public, anon, authenticated;
drop trigger if exists trg_ranking_guard_entry on ranking_entries;
create trigger trg_ranking_guard_entry before insert or update on ranking_entries for each row execute function _ranking_guard_entry();

create or replace function _ranking_guard_entry_delete() returns trigger
language plpgsql set search_path = public as $$
begin
  if not exists (select 1 from profiles where id = old.user_id) then return old; end if;
  raise exception 'Une entrée de classement ne se supprime pas : retirez-la par une correction auditée';
end $$;
revoke all on function _ranking_guard_entry_delete() from public, anon, authenticated;
drop trigger if exists trg_ranking_guard_entry_delete on ranking_entries;
create trigger trg_ranking_guard_entry_delete before delete on ranking_entries for each row execute function _ranking_guard_entry_delete();

create or replace function _ranking_guard_period() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then raise exception 'Un classement publié ne se supprime pas : archivez-le'; end if;
  if tg_op = 'INSERT' then
    if coalesce(current_setting('app.ranking_write', true), '') <> 'on' then raise exception 'Publication réservée à ranking_publish'; end if;
    return new;
  end if;
  if coalesce(current_setting('app.ranking_write', true), '') <> 'on' then raise exception 'Un classement publié ne se modifie pas : utilisez une correction auditée'; end if;
  if new.id is distinct from old.id or new.period is distinct from old.period or new.published_at is distinct from old.published_at or new.published_by is distinct from old.published_by
     or new.settings is distinct from old.settings or new.rules is distinct from old.rules then
    raise exception 'La période, les réglages et les règles d''un classement publié sont figés';
  end if;
  if new.status is distinct from old.status and not (old.status = 'published' and new.status = 'archived') then raise exception 'Un classement archivé ne revient pas en arrière'; end if;
  if old.status = 'archived' and (new.content_hash is distinct from old.content_hash or new.correction_count is distinct from old.correction_count) then raise exception 'Ce classement est archivé : il ne peut plus être corrigé'; end if;
  return new;
end $$;
revoke all on function _ranking_guard_period() from public, anon, authenticated;
drop trigger if exists trg_ranking_guard_period on ranking_periods;
create trigger trg_ranking_guard_period before insert or update or delete on ranking_periods for each row execute function _ranking_guard_period();

create or replace function _ranking_guard_corrections() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then return new; end if;
  raise exception 'Le journal des corrections est en ajout seul';
end $$;
revoke all on function _ranking_guard_corrections() from public, anon, authenticated;
drop trigger if exists trg_ranking_guard_corrections on ranking_corrections;
create trigger trg_ranking_guard_corrections before update or delete on ranking_corrections for each row execute function _ranking_guard_corrections();

-- ============================================================ 3. Aides internes
create or replace function _ranking_period_ok(p text) returns boolean
language sql stable set search_path = public as $$
  select p ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' and p <= to_char(now() at time zone 'utc', 'YYYY-MM')
$$;
revoke all on function _ranking_period_ok(text) from public, anon, authenticated;

-- Badges vérifiables d'un étudiant (mêmes sources que talent_passport).
create or replace function _ranking_badges(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('code', b.code, 'count', b.n) order by b.ord), '[]'::jsonb)
  from (
    select 1 ord, 'certified'::text code, 1 n from profiles p where p.id = p_user and p.certification::text = 'approved'
    union all select 2, 'certificates', count(*)::int from certificates c where c.holder_id = p_user and not c.revoked having count(*) > 0
    union all select 3, 'verified_documents', count(*)::int from user_documents d where d.owner_id = p_user and d.status = 'verified' having count(*) > 0
    union all select 4, 'proven_skills', count(*)::int from talent_skills s join user_documents d on d.id = s.proof_document_id and d.status = 'verified' where s.owner_id = p_user having count(*) > 0
    union all select 5, 'expert_skills', count(*)::int from talent_skills s where s.owner_id = p_user and s.level = 'expert' having count(*) > 0
    union all select 6, 'missions', count(*)::int from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = p_user and mp.status = 'accepted' where m.status in ('delivered', 'closed') having count(*) > 0
  ) b
$$;
revoke all on function _ranking_badges(uuid) from public, anon, authenticated;

-- L'étudiant reste-t-il éligible ? (non suspendu, vérifié, sans alerte de fraude ouverte ou confirmée)
create or replace function _ranking_still_eligible(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_verified_student(p_user) and not exists (select 1 from talent_fraud_flags f where f.user_id = p_user and f.status in ('open', 'confirmed'))
$$;
revoke all on function _ranking_still_eligible(uuid) from public, anon, authenticated;

-- Candidats d'une période : étudiants vérifiés, rattachés à une filière vérifiée, consentants, non suspendus, sans fraude, avec un score > 0.
create or replace function _ranking_candidates(p_period text) returns table (user_id uuid, score integer, month_points integer, activities integer, institution_id uuid, program_id uuid, department_id uuid, details jsonb)
language sql stable security definer set search_path = public as $$
  select a.user_id, s.score, s.mp, s.act, a.institution_id, a.program_id, g.department_id,
    jsonb_build_object('institution_id', a.institution_id, 'institution', i.name, 'program_id', a.program_id, 'program', g.name, 'department_id', g.department_id, 'department', d.name,
      'promotion', a.promotion, 'activities', s.act, 'badges', _ranking_badges(a.user_id),
      'projects', (select count(*)::int from projects pj where pj.owner_id = a.user_id and pj.status = 'approved'),
      'skills', coalesce((select jsonb_agg(jsonb_build_object('skill', t.skill, 'domain', t.domain, 'level', t.level) order by t.ord, t.created_at)
                          from (select ts.skill, ts.domain, ts.level, ts.created_at, case ts.level when 'expert' then 0 when 'avance' then 1 when 'intermediaire' then 2 else 3 end ord
                                from talent_skills ts where ts.owner_id = a.user_id order by 5, ts.created_at limit 5) t), '[]'::jsonb))
  from student_affiliations a
  join programs g on g.id = a.program_id
  join institutions i on i.id = a.institution_id and i.status = 'verified'
  left join departments d on d.id = g.department_id
  join talent_visibility_settings v on v.user_id = a.user_id and v.public_ranking
  cross join lateral (
    select coalesce(sum(l.points) filter (where l.period <= p_period), 0)::int score, coalesce(sum(l.points) filter (where l.period = p_period), 0)::int mp,
           (select count(*)::int from talent_events e where e.user_id = a.user_id and e.status = 'confirmed' and e.occurred_at < (to_date(p_period || '-01', 'YYYY-MM-DD') + interval '1 month')) act
    from talent_score_ledger l where l.user_id = a.user_id) s
  where a.status = 'verified' and a.ended_at is null and is_verified_student(a.user_id)
    and not exists (select 1 from talent_fraud_flags f where f.user_id = a.user_id and f.status in ('open', 'confirmed'))
$$;
revoke all on function _ranking_candidates(text) from public, anon, authenticated;

create or replace function _ranking_period_hash(p_period uuid) returns text
language sql stable security definer set search_path = public as $$
  select encode(sha256(convert_to(concat_ws('|', p.period, p.settings::text, p.rules::text,
    coalesce((select string_agg(e.entry_hash, ',' order by e.id) from ranking_entries e where e.period_id = p.id), '')), 'UTF8')), 'hex')
  from ranking_periods p where p.id = p_period
$$;
revoke all on function _ranking_period_hash(uuid) from public, anon, authenticated;

-- Motifs qui empêchent la publication (liste vide = publiable).
create or replace function _ranking_blockers(p_period text) returns text[]
language plpgsql stable security definer set search_path = public as $$
declare s ranking_settings; v text[] := '{}';
begin
  if p_period is null or not _ranking_period_ok(p_period) then return array['Période invalide ou future (format AAAA-MM, au plus le mois en cours)']; end if;
  select * into s from ranking_settings where id;
  if s.id is null or s.min_score is null or s.entries_limit is null or cardinality(s.scopes) = 0 then
    v := array_append(v, 'Réglages du classement non décidés (seuil minimal, nombre d''entrées, portées)');
  end if;
  if not exists (select 1 from talent_score_rules where active and points > 0)   then v := array_append(v, 'Aucune règle de score active'); end if;
    if exists (select 1 from ranking_periods where period = p_period) then v := array_append(v, 'Ce mois est déjà publié : une publication ne change plus'); end if;
  return v;
end $$;
revoke all on function _ranking_blockers(text) from public, anon, authenticated;

-- ============================================================ 4. Consentement de l'étudiant
create or replace function my_top100_visibility_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v talent_visibility_settings;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  select * into v from talent_visibility_settings where user_id = auth.uid();
  return jsonb_build_object('public_ranking', coalesce(v.public_ranking, false), 'show_full_name', coalesce(v.show_full_name, false), 'show_photo', coalesce(v.show_photo, false),
    'shared_sections', to_jsonb(coalesce(v.shared_sections, '{}'::text[])), 'availability_public', coalesce(v.availability_public, false),
    'allowed_sections', to_jsonb(array['rank', 'score', 'evolution', 'skills', 'badges', 'projects', 'passport']::text[]));
end $$;

create or replace function my_top100_visibility_set(p_public_ranking boolean, p_full_name boolean, p_photo boolean, p_sections text[], p_availability boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_sections text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  if p_public_ranking is null or p_full_name is null or p_photo is null or p_availability is null then raise exception 'Choix incomplet'; end if;
  select coalesce(array_agg(distinct x order by x), '{}') into v_sections from unnest(coalesce(p_sections, '{}'::text[])) x;
  if not (v_sections <@ array['rank', 'score', 'evolution', 'skills', 'badges', 'projects', 'passport']::text[]) then raise exception 'Rubrique de partage inconnue'; end if;
  insert into talent_visibility_settings (user_id, public_ranking, show_full_name, show_photo, shared_sections, availability_public)
  values (auth.uid(), p_public_ranking, p_full_name, p_photo, v_sections, p_availability)
  on conflict (user_id) do update set public_ranking = excluded.public_ranking, show_full_name = excluded.show_full_name, show_photo = excluded.show_photo,
    shared_sections = excluded.shared_sections, availability_public = excluded.availability_public, updated_at = now();
  return my_top100_visibility_get();
end $$;

-- ============================================================ 5. Réglages (administration)
create or replace function admin_ranking_settings_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s ranking_settings; v_undecided text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not (has_admin_permission('ranking.rules') or has_admin_permission('ranking.publish')) then raise exception 'Réservé : exige la permission ranking.rules ou ranking.publish'; end if;
  select * into s from ranking_settings where id;
  if s.min_score is null then v_undecided := array_append(v_undecided, 'min_score'); end if;
  if s.entries_limit is null then v_undecided := array_append(v_undecided, 'entries_limit'); end if;
  if s.id is null or cardinality(s.scopes) = 0 then v_undecided := array_append(v_undecided, 'scopes'); end if;
  return jsonb_build_object('min_score', s.min_score, 'min_activities', s.min_activities, 'entries_limit', s.entries_limit, 'scopes', to_jsonb(coalesce(s.scopes, '{}'::text[])),
    'min_cohort', _talent_setting('min_cohort', 5), 'undecided', to_jsonb(v_undecided), 'decided', cardinality(v_undecided) = 0, 'updated_at', s.updated_at);
end $$;

create or replace function admin_ranking_settings_set(p_min_score integer, p_min_activities integer, p_entries_limit integer, p_scopes text[], p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); v_scopes text[];
begin
  perform _top100_admin('ranking.rules');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez le réglage en 10 à 500 caractères'; end if;
  if p_min_score is null or p_min_score < 0 then raise exception 'Seuil minimal de points : un entier >= 0'; end if;
  if p_min_activities is not null and p_min_activities < 0 then raise exception 'Seuil minimal d''activités : un entier >= 0'; end if;
  if p_entries_limit is null or p_entries_limit not between 1 and 1000 then raise exception 'Nombre d''entrées : de 1 à 1000'; end if;
  select coalesce(array_agg(distinct x order by x), '{}') into v_scopes from unnest(coalesce(p_scopes, '{}'::text[])) x;
  if cardinality(v_scopes) = 0 or not (v_scopes <@ array['national', 'program', 'institution', 'department', 'domain']::text[]) then raise exception 'Portées : national, program, institution, department, domain (au moins une)'; end if;
  insert into ranking_settings (id, min_score, min_activities, entries_limit, scopes, updated_by) values (true, p_min_score, p_min_activities, p_entries_limit, v_scopes, auth.uid())
  on conflict (id) do update set min_score = excluded.min_score, min_activities = excluded.min_activities, entries_limit = excluded.entries_limit, scopes = excluded.scopes, updated_by = auth.uid(), updated_at = now();
  perform _top100_audit('Réglages du classement modifiés', format('seuil %s, activités %s, entrées %s, portées %s : %s', p_min_score, coalesce(p_min_activities::text, '-'), p_entries_limit, array_to_string(v_scopes, ','), v_reason));
  return admin_ranking_settings_get();
end $$;

-- Prévisualisation : motifs de blocage et nombre d'étudiants exclus par cause (aucune écriture).
create or replace function admin_ranking_readiness(p_period text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s ranking_settings; v_blockers text[]; v_counts jsonb; v_min integer;
begin
  perform _top100_admin('ranking.publish');
  v_blockers := _ranking_blockers(p_period);
  select * into s from ranking_settings where id;
  v_min := coalesce(s.min_score, 0);
  if _ranking_period_ok(p_period) then
    select jsonb_object_agg(k, n) into v_counts from (
      select z.cause k, count(*)::int n from (
        select case
          when coalesce(p.suspended, false) then 'suspendus'
          when not is_verified_student(p.id) then 'non_verifies'
          when not exists (select 1 from student_affiliations a join institutions i on i.id = a.institution_id and i.status = 'verified' where a.user_id = p.id and a.status = 'verified' and a.ended_at is null) then 'sans_rattachement_verifie'
          when not coalesce((select v.public_ranking from talent_visibility_settings v where v.user_id = p.id), false) then 'non_consentants'
          when exists (select 1 from talent_fraud_flags f where f.user_id = p.id and f.status in ('open', 'confirmed')) then 'fraude'
          when coalesce((select sum(l.points) from talent_score_ledger l where l.user_id = p.id and l.period <= p_period), 0) <= 0
               or coalesce((select sum(l.points) from talent_score_ledger l where l.user_id = p.id and l.period <= p_period), 0) < v_min then 'sous_le_seuil'
          when s.min_activities is not null and (select count(*) from talent_events e where e.user_id = p.id and e.status = 'confirmed' and e.occurred_at < (to_date(p_period || '-01', 'YYYY-MM-DD') + interval '1 month')) < s.min_activities then 'sous_le_seuil'
          else 'eligibles' end cause
        from profiles p where p.role::text = 'student') z group by z.cause) y;
  end if;
  return jsonb_build_object('period', p_period, 'ready', cardinality(v_blockers) = 0, 'blockers', to_jsonb(v_blockers), 'students', coalesce(v_counts, '{}'::jsonb),
    'min_cohort', _talent_setting('min_cohort', 5));
end $$;

-- ============================================================ 6. Publication
create or replace function ranking_publish(p_period text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s ranking_settings; v_blockers text[]; v_id uuid; v_prev text; v_n integer; v_rules jsonb; v_cohort integer := _talent_setting('min_cohort', 5)::integer; r record; v_notified integer := 0; v_groups integer;
begin
  perform _top100_admin('ranking.publish');
  v_blockers := _ranking_blockers(p_period);
  if cardinality(v_blockers) > 0 then raise exception 'Publication impossible : %', array_to_string(v_blockers, ' ; '); end if;
  select * into s from ranking_settings where id;
  select coalesce(jsonb_agg(jsonb_build_object('code', t.code, 'points', t.points, 'cap_per_day', t.cap_per_day, 'cap_per_period', t.cap_per_period, 'quality_weight', t.quality_weight, 'version', t.version) order by t.code), '[]'::jsonb)
    into v_rules from talent_score_rules t where t.active and t.points > 0;
  select period into v_prev from ranking_periods where period < p_period order by period desc limit 1;
  perform set_config('app.ranking_write', 'on', true);
  insert into ranking_periods (period, published_by, settings, rules, content_hash)
  values (p_period, auth.uid(), jsonb_build_object('min_score', s.min_score, 'min_activities', s.min_activities, 'entries_limit', s.entries_limit, 'scopes', to_jsonb(s.scopes), 'min_cohort', v_cohort), v_rules, 'pending')
  returning id into v_id;

  with c as (select * from _ranking_candidates(p_period) x where x.score > 0 and x.score >= s.min_score and (s.min_activities is null or x.activities >= s.min_activities)),
  g as (
    select 'national'::text kind, ''::text ref, c.* from c where 'national' = any (s.scopes)
    union all select 'institution', c.institution_id::text, c.* from c where 'institution' = any (s.scopes)
    union all select 'program', c.program_id::text, c.* from c where 'program' = any (s.scopes)
    union all select 'department', c.department_id::text, c.* from c where c.department_id is not null and 'department' = any (s.scopes)
    union all select 'domain', d.domain, c.* from c join (select distinct owner_id, domain from talent_skills) d on d.owner_id = c.user_id where 'domain' = any (s.scopes)
  ),
  z as (select g.*, count(*) over (partition by g.kind, g.ref) size, rank() over (partition by g.kind, g.ref order by g.score desc, g.month_points desc) rk from g)
  insert into ranking_entries (period_id, scope_kind, scope_ref, user_id, rank, score, month_points, prev_rank, delta_rank, delta_score, is_new, details)
  select v_id, z.kind, z.ref, z.user_id, z.rk, z.score, z.month_points, pe.rank, case when pe.id is null then null else pe.rank - z.rk end,
         case when pe.id is null then null else z.score - pe.score end, pe.id is null, z.details || jsonb_build_object('cohort_size', z.size)
  from z
  left join lateral (select e.id, e.rank, e.score from ranking_entries e join ranking_periods pp on pp.id = e.period_id
                     where pp.period = v_prev and e.scope_kind = z.kind and e.scope_ref = z.ref and e.user_id = z.user_id and e.voided_at is null limit 1) pe on true
  where z.size >= v_cohort and z.rk <= s.entries_limit;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'Aucun étudiant éligible : rien à publier'; end if;
  select count(*)::int into v_groups from (select distinct scope_kind, scope_ref from ranking_entries where period_id = v_id) x;
  update ranking_periods set entries_count = v_n where id = v_id;
  if to_regprocedure('_ranking_institutions_build(uuid, text)') is not null then execute 'select _ranking_institutions_build($1, $2)' using v_id, p_period; end if;
  update ranking_periods set content_hash = _ranking_period_hash(v_id) where id = v_id;

  for r in select distinct on (e.user_id) e.user_id, e.scope_kind, e.rank, e.delta_rank, e.is_new from ranking_entries e where e.period_id = v_id
           order by e.user_id, (e.scope_kind = 'national') desc, e.rank loop
    if r.is_new or coalesce(r.delta_rank, 0) <> 0 then
      perform notify_user(r.user_id, case when r.is_new then 'ranking_entry' else 'ranking_rank_change' end,
        case when r.is_new then 'Vous entrez au classement' else 'Votre rang a changé' end,
        case when r.is_new then 'Classement ' || p_period || ' : vous êtes ' || r.rank || 'e.' else 'Classement ' || p_period || ' : vous êtes ' || r.rank || 'e (' || case when r.delta_rank > 0 then '+' else '' end || r.delta_rank || ').' end,
        jsonb_build_object('period', p_period, 'scope', r.scope_kind, 'rank', r.rank));
      v_notified := v_notified + 1;
    end if;
  end loop;
  perform _top100_audit('Classement publié : ' || p_period, v_n || ' entrées, ' || v_groups || ' groupes');
  return jsonb_build_object('ok', true, 'period', p_period, 'entries', v_n, 'groups', v_groups, 'notified', v_notified, 'content_hash', (select content_hash from ranking_periods where id = v_id));
end $$;

-- ============================================================ 7. Correction auditée et archivage
create or replace function ranking_correct(p_period text, p_reason text, p_user uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); pr ranking_periods; e record; v_voided integer := 0; v_moved integer := 0; v_groups text[] := '{}'; v_old text; v_new text;
begin
  perform _top100_admin('ranking.publish');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez la correction en 10 à 500 caractères'; end if;
  select * into pr from ranking_periods where period = p_period for update;
  if pr.id is null then raise exception 'Classement introuvable'; end if;
  if pr.status <> 'published' then raise exception 'Ce classement est archivé : il ne peut plus être corrigé'; end if;
  perform set_config('app.ranking_write', 'on', true);
  v_old := pr.content_hash;
  for e in select en.* from ranking_entries en where en.period_id = pr.id and en.voided_at is null
             and ((p_user is not null and en.user_id = p_user) or (p_user is null and not _ranking_still_eligible(en.user_id))) loop
    insert into ranking_corrections (period_id, entry_id, user_id, scope_kind, scope_ref, field, old_value, new_value, reason, corrected_by)
    values (pr.id, e.id, e.user_id, e.scope_kind, e.scope_ref, 'entry', jsonb_build_object('rank', e.rank, 'score', e.score, 'voided', false), jsonb_build_object('voided', true), v_reason, auth.uid());
    update ranking_entries set voided_at = now(), void_reason = left(v_reason, 300) where id = e.id;
    if not ((e.scope_kind || '|' || e.scope_ref) = any (v_groups)) then v_groups := v_groups || (e.scope_kind || '|' || e.scope_ref); end if;
    v_voided := v_voided + 1;
  end loop;
  if v_voided = 0 then raise exception 'Aucune entrée à corriger'; end if;
  for e in select x.* from (select en.id, en.user_id, en.rank old_rank, en.prev_rank, en.scope_kind, en.scope_ref,
                                   rank() over (partition by en.scope_kind, en.scope_ref order by en.score desc, en.month_points desc) new_rank
                            from ranking_entries en where en.period_id = pr.id and en.voided_at is null and (en.scope_kind || '|' || en.scope_ref) = any (v_groups)) x
           where x.new_rank <> x.old_rank loop
    insert into ranking_corrections (period_id, entry_id, user_id, scope_kind, scope_ref, field, old_value, new_value, reason, corrected_by)
    values (pr.id, e.id, e.user_id, e.scope_kind, e.scope_ref, 'rank', jsonb_build_object('rank', e.old_rank), jsonb_build_object('rank', e.new_rank), v_reason, auth.uid());
    update ranking_entries set rank = e.new_rank, delta_rank = case when e.prev_rank is null then null else e.prev_rank - e.new_rank end where id = e.id;
    v_moved := v_moved + 1;
  end loop;
  -- une seule notification par étudiant et par correction (retrait de préférence, sinon changement de rang national puis le meilleur)
  for e in select distinct on (c.user_id) c.user_id, c.field, c.scope_kind, c.old_value, c.new_value from ranking_corrections c where c.period_id = pr.id and c.corrected_at = now()
           order by c.user_id, (c.field = 'entry') desc, (c.scope_kind = 'national') desc, c.id loop
    perform notify_user(e.user_id, 'ranking_correction', 'Classement corrigé',
      case when e.field = 'entry' then 'Votre entrée au classement ' || p_period || ' a été retirée après vérification.'
           else 'Classement ' || p_period || ' : votre rang passe de ' || (e.old_value ->> 'rank') || ' à ' || (e.new_value ->> 'rank') || ' après correction.' end,
      jsonb_build_object('period', p_period, 'scope', e.scope_kind));
  end loop;
  v_new := _ranking_period_hash(pr.id);
  update ranking_periods set content_hash = v_new, correction_count = correction_count + 1, last_corrected_at = now() where id = pr.id;
  perform _top100_audit('Classement corrigé : ' || p_period, format('ancienne empreinte %s, nouvelle %s ; %s entrée(s) retirée(s), %s rang(s) modifié(s) : %s', v_old, v_new, v_voided, v_moved, v_reason));
  return jsonb_build_object('ok', true, 'period', p_period, 'voided', v_voided, 'rank_changes', v_moved, 'old_hash', v_old, 'new_hash', v_new);
end $$;

create or replace function ranking_archive(p_period text, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); pr ranking_periods;
begin
  perform _top100_admin('ranking.publish');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez l''archivage en 10 à 500 caractères'; end if;
  select * into pr from ranking_periods where period = p_period for update;
  if pr.id is null then raise exception 'Classement introuvable'; end if;
  if pr.status = 'archived' then raise exception 'Ce classement est déjà archivé'; end if;
  perform set_config('app.ranking_write', 'on', true);
  update ranking_periods set status = 'archived', archived_at = now(), archived_by = auth.uid() where id = pr.id;
  perform _top100_audit('Classement archivé : ' || p_period, v_reason);
  return jsonb_build_object('ok', true, 'period', p_period, 'status', 'archived');
end $$;

-- ============================================================ 8. Lecture administrative et vérification d'intégrité
create or replace function admin_ranking_periods_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.publish') then raise exception 'Réservé : exige la permission ranking.publish'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('period', p.period, 'status', p.status, 'published_at', p.published_at, 'entries_count', p.entries_count,
      'voided', (select count(*)::int from ranking_entries e where e.period_id = p.id and e.voided_at is not null), 'corrections', p.correction_count, 'last_corrected_at', p.last_corrected_at,
      'archived_at', p.archived_at, 'content_hash', p.content_hash, 'settings', p.settings, 'rules', p.rules) order by p.period desc) from ranking_periods p), '[]'::jsonb);
end $$;

create or replace function admin_ranking_corrections_list(p_period text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.publish') then raise exception 'Réservé : exige la permission ranking.publish'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'period', p.period, 'user_id', c.user_id, 'student', display_name(c.user_id), 'scope', c.scope_kind, 'scope_ref', c.scope_ref, 'field', c.field,
      'old_value', c.old_value, 'new_value', c.new_value, 'reason', c.reason, 'corrected_by', display_name(c.corrected_by), 'corrected_at', c.corrected_at) order by c.id desc)
    from (select * from ranking_corrections order by id desc limit 500) c join ranking_periods p on p.id = c.period_id where p_period is null or p.period = p_period), '[]'::jsonb);
end $$;

-- Recalcule les empreintes à partir du contenu : vrai si rien n'a été altéré depuis la publication (ou la dernière correction).
create or replace function ranking_verify_hash(p_period text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods; v_entries boolean; v_hash text;
begin
  select * into pr from ranking_periods where period = p_period;
  if pr.id is null then return jsonb_build_object('found', false); end if;
  select coalesce(bool_and(e.entry_hash = _ranking_entry_hash(e)), true) into v_entries from ranking_entries e where e.period_id = pr.id;
  v_hash := _ranking_period_hash(pr.id);
  return jsonb_build_object('found', true, 'period', pr.period, 'status', pr.status, 'content_hash', pr.content_hash, 'intact', v_entries and v_hash = pr.content_hash, 'corrections', pr.correction_count);
end $$;

revoke all on function my_top100_visibility_get(), my_top100_visibility_set(boolean, boolean, boolean, text[], boolean), admin_ranking_settings_get(), admin_ranking_settings_set(integer, integer, integer, text[], text),
  admin_ranking_readiness(text), ranking_publish(text), ranking_correct(text, text, uuid), ranking_archive(text, text), admin_ranking_periods_list(), admin_ranking_corrections_list(text), ranking_verify_hash(text) from public, anon;
grant execute on function my_top100_visibility_get(), my_top100_visibility_set(boolean, boolean, boolean, text[], boolean), admin_ranking_settings_get(), admin_ranking_settings_set(integer, integer, integer, text[], text),
  admin_ranking_readiness(text), ranking_publish(text), ranking_correct(text, text, uuid), ranking_archive(text, text), admin_ranking_periods_list(), admin_ranking_corrections_list(text) to authenticated;
grant execute on function ranking_verify_hash(text) to anon, authenticated;
