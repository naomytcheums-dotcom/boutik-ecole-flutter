-- Lot H12 / TOP100-B (3/5) : lecture publique et entreprise des classements, page publique d'un talent, vues d'entreprises anonymisées (CDC Top 100, 1.2 et 1.5).
--  1. RPC en lecture (anon et connectés) sur les classements PUBLIÉS uniquement et sur les étudiants CONSENTANTS (talent_visibility_settings.public_ranking, 020000) : top100_national, top100_by_program,
--     top100_by_institution, top100_by_department, top100_by_domain, talents_rising, talents_new, talents_most_viewed_by_companies, ranking_history, talent_public_profile.
--     Un étudiant retiré (correction), suspendu, non vérifié ou ayant retiré son consentement disparaît immédiatement ; ses autres données ne sont jamais exposées.
--     Nom public : nom complet seulement si show_full_name, sinon prénom et initiale ; photo seulement si show_photo ; score, évolution, compétences, badges, projets seulement si la rubrique est partagée.
--     Filtres : mois/année (p_period AAAA-MM), établissement, filière, département, domaine de compétence, niveau/promotion vérifié (rattachement vérifié).
--     Aucun classement publié : réponse honnête { published: false, items: [] } (jamais de donnée fictive).
--  2. talent_profile_views + talent_profile_view_record : vues de profil par les entreprises VÉRIFIÉES (et leurs membres, comptées pour l'organisation), dédoublonnées par organisation, talent et jour UTC ;
--     talents_most_viewed_by_companies n'expose que des compteurs agrégés (organisations distinctes, vues) : jamais l'identité de l'entreprise visiteuse. Plafond de 200 profils différents par organisation et par jour.
--  3. talent_public_profile(user) : page publique du talent (rangs, score, évolution, compétences, badges, projets, passeport partagé, disponibilité publiable) selon le consentement ;
--     my_ranking_positions : l'étudiant voit ses propres positions publiées même sans consentement.
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière : drop function top100_national(text, integer, integer, uuid, uuid, uuid, text, text), top100_by_program(uuid, text, integer, integer, text),
--   top100_by_institution(uuid, text, uuid, uuid, text, text, integer, integer), top100_by_department(uuid, text, integer, integer, text), top100_by_domain(text, text, uuid, text, integer, integer),
--   talents_rising(text, integer, uuid, uuid, text), talents_new(text, integer, uuid, uuid, text), talents_most_viewed_by_companies(text, integer), ranking_history(integer), talent_public_profile(uuid),
--   talent_profile_view_record(uuid), my_ranking_positions(), _ranking_list(text, text, text, uuid, uuid, uuid, text, text, integer, integer), _ranking_item_json(ranking_entries, talent_visibility_settings, profiles),
--   _top100_viewer_org() ; drop table talent_profile_views.

create table if not exists talent_profile_views (
  id bigint generated always as identity primary key,
  org_id uuid not null references profiles (id) on delete cascade,
  talent_id uuid not null references profiles (id) on delete cascade,
  view_day date not null default ((now() at time zone 'utc')::date),
  created_at timestamptz not null default now(),
  unique (org_id, talent_id, view_day)
);
create index if not exists talent_profile_views_talent on talent_profile_views (talent_id, view_day);
alter table talent_profile_views enable row level security;
revoke all on talent_profile_views from public, anon, authenticated;

-- Organisation vérifiée au nom de laquelle la personne connectée consulte (elle-même ou le propriétaire dont elle est membre actif) ; nul sinon.
create or replace function _top100_viewer_org() returns uuid
language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then null
    when _viewer_class() = 'org_ok' then auth.uid()
    else (select m.owner_id from company_members m join profiles p on p.id = m.user_id
          where m.user_id = auth.uid() and m.status = 'active' and not coalesce(p.suspended, false) and _org_approved(m.owner_id) limit 1) end
$$;
revoke all on function _top100_viewer_org() from public, anon, authenticated;

-- ============================================================ Mise en forme d'une entrée selon le consentement
create or replace function _ranking_item_json(e ranking_entries, v talent_visibility_settings, pf profiles) returns jsonb
language sql stable set search_path = public as $$
  select jsonb_build_object('rank', e.rank, 'user_id', e.user_id,
    'name', case when v.show_full_name then pf.name else _short_name(pf.name) end,
    'photo', case when v.show_photo then pf.avatar_url end,
    'institution_id', e.details -> 'institution_id', 'institution', e.details ->> 'institution', 'program_id', e.details -> 'program_id', 'program', e.details ->> 'program',
    'department_id', e.details -> 'department_id', 'department', e.details ->> 'department', 'promotion', e.details ->> 'promotion', 'scope', e.scope_kind,
    'score', case when 'score' = any (v.shared_sections) then e.score end,
    'month_points', case when 'evolution' = any (v.shared_sections) then e.month_points end,
    'delta_rank', case when 'evolution' = any (v.shared_sections) then e.delta_rank end,
    'delta_score', case when 'evolution' = any (v.shared_sections) then e.delta_score end,
    'is_new', e.is_new,
    'skills', case when 'skills' = any (v.shared_sections) then e.details -> 'skills' end,
    'badges', case when 'badges' = any (v.shared_sections) then e.details -> 'badges' end,
    'projects', case when 'projects' = any (v.shared_sections) then e.details -> 'projects' end)
$$;
revoke all on function _ranking_item_json(ranking_entries, talent_visibility_settings, profiles) from public, anon, authenticated;

-- Liste d'un classement publié (période demandée ou dernier mois publié).
create or replace function _ranking_list(p_period text, p_kind text, p_ref text, p_inst uuid, p_prog uuid, p_dept uuid, p_domain text, p_level text, p_limit integer, p_offset integer) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods; v_lim integer := least(greatest(coalesce(p_limit, 100), 1), 100); v_off integer := greatest(coalesce(p_offset, 0), 0); v_items jsonb; v_total integer;
begin
  select * into pr from ranking_periods where (p_period is not null and period = p_period) or (p_period is null and status = 'published') order by period desc limit 1;
  if pr.id is null then
    return jsonb_build_object('published', false, 'period', p_period, 'scope', p_kind, 'items', '[]'::jsonb, 'total', 0, 'note', 'Aucun classement n''est publié pour le moment.');
  end if;
  select coalesce(jsonb_agg(x.j order by x.rank, x.nm), '[]'::jsonb), coalesce(max(x.total), 0) into v_items, v_total from (
    select _ranking_item_json(e, v, pf) j, e.rank, pf.name nm, count(*) over ()::int total
    from ranking_entries e
    join talent_visibility_settings v on v.user_id = e.user_id and v.public_ranking
    join profiles pf on pf.id = e.user_id
    where e.period_id = pr.id and e.scope_kind = p_kind and e.voided_at is null and is_verified_student(e.user_id)
      and (e.scope_ref = coalesce(p_ref, '') or (p_kind = 'domain' and lower(e.scope_ref) = lower(btrim(p_ref))))
      and (p_inst is null or e.details ->> 'institution_id' = p_inst::text)
      and (p_prog is null or e.details ->> 'program_id' = p_prog::text)
      and (p_dept is null or e.details ->> 'department_id' = p_dept::text)
      and (nullif(btrim(p_level), '') is null or lower(e.details ->> 'promotion') = lower(btrim(p_level)))
      and (nullif(btrim(p_domain), '') is null or p_kind = 'domain' or exists (select 1 from talent_skills ts where ts.owner_id = e.user_id and lower(ts.domain) = lower(btrim(p_domain))))
    order by e.rank, pf.name limit v_lim offset v_off) x;
  return jsonb_build_object('published', true, 'period', pr.period, 'status', pr.status, 'published_at', pr.published_at, 'scope', p_kind, 'scope_ref', p_ref, 'items', v_items, 'total', v_total);
end $$;
revoke all on function _ranking_list(text, text, text, uuid, uuid, uuid, text, text, integer, integer) from public, anon, authenticated;

create or replace function top100_national(p_period text default null, p_limit integer default 100, p_offset integer default 0, p_institution uuid default null, p_program uuid default null,
                                           p_department uuid default null, p_domain text default null, p_level text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select _ranking_list(p_period, 'national', '', p_institution, p_program, p_department, p_domain, p_level, p_limit, p_offset)
$$;
create or replace function top100_by_program(p_program uuid, p_period text default null, p_limit integer default 100, p_offset integer default 0, p_level text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select _ranking_list(p_period, 'program', coalesce(p_program::text, ''), null, null, null, null, p_level, p_limit, p_offset)
$$;
create or replace function top100_by_institution(p_institution uuid, p_period text default null, p_program uuid default null, p_department uuid default null, p_domain text default null,
                                                 p_level text default null, p_limit integer default 100, p_offset integer default 0) returns jsonb
language sql stable security definer set search_path = public as $$
  select _ranking_list(p_period, 'institution', coalesce(p_institution::text, ''), null, p_program, p_department, p_domain, p_level, p_limit, p_offset)
$$;
create or replace function top100_by_department(p_department uuid, p_period text default null, p_limit integer default 100, p_offset integer default 0, p_level text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select _ranking_list(p_period, 'department', coalesce(p_department::text, ''), null, null, null, null, p_level, p_limit, p_offset)
$$;
create or replace function top100_by_domain(p_domain text, p_period text default null, p_institution uuid default null, p_level text default null, p_limit integer default 100, p_offset integer default 0) returns jsonb
language sql stable security definer set search_path = public as $$
  select _ranking_list(p_period, 'domain', coalesce(p_domain, ''), p_institution, null, null, null, p_level, p_limit, p_offset)
$$;

-- ============================================================ En progression / nouveaux talents (meilleure entrée de chaque étudiant : nationale si elle existe)
create or replace function talents_rising(p_period text default null, p_limit integer default 20, p_institution uuid default null, p_program uuid default null, p_domain text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods; v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 100);
begin
  select * into pr from ranking_periods where (p_period is not null and period = p_period) or (p_period is null and status = 'published') order by period desc limit 1;
  if pr.id is null then return jsonb_build_object('published', false, 'period', p_period, 'items', '[]'::jsonb, 'note', 'Aucun classement n''est publié pour le moment.'); end if;
  return jsonb_build_object('published', true, 'period', pr.period, 'items', coalesce((select jsonb_agg(z.j order by z.dr desc, z.ds desc, z.rank) from (
    select _ranking_item_json(b, v, pf) j, b.delta_rank dr, coalesce(b.delta_score, 0) ds, b.rank
    from ranking_entries b
    join talent_visibility_settings v on v.user_id = b.user_id and v.public_ranking and 'evolution' = any (v.shared_sections)
    join profiles pf on pf.id = b.user_id
    where b.id in (select distinct on (e.user_id) e.id from ranking_entries e where e.period_id = pr.id and e.voided_at is null and e.delta_rank > 0 order by e.user_id, (e.scope_kind = 'national') desc, e.delta_rank desc, e.rank)
      and is_verified_student(b.user_id)
      and (p_institution is null or b.details ->> 'institution_id' = p_institution::text) and (p_program is null or b.details ->> 'program_id' = p_program::text)
      and (nullif(btrim(p_domain), '') is null or exists (select 1 from talent_skills ts where ts.owner_id = b.user_id and lower(ts.domain) = lower(btrim(p_domain))))
    order by b.delta_rank desc, coalesce(b.delta_score, 0) desc, b.rank limit v_lim) z), '[]'::jsonb));
end $$;

create or replace function talents_new(p_period text default null, p_limit integer default 20, p_institution uuid default null, p_program uuid default null, p_domain text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare pr ranking_periods; v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 100);
begin
  select * into pr from ranking_periods where (p_period is not null and period = p_period) or (p_period is null and status = 'published') order by period desc limit 1;
  if pr.id is null then return jsonb_build_object('published', false, 'period', p_period, 'items', '[]'::jsonb, 'note', 'Aucun classement n''est publié pour le moment.'); end if;
  return jsonb_build_object('published', true, 'period', pr.period, 'items', coalesce((select jsonb_agg(z.j order by z.rank) from (
    select _ranking_item_json(b, v, pf) j, b.rank
    from ranking_entries b
    join talent_visibility_settings v on v.user_id = b.user_id and v.public_ranking
    join profiles pf on pf.id = b.user_id
    where b.id in (select distinct on (e.user_id) e.id from ranking_entries e where e.period_id = pr.id and e.voided_at is null
            and not exists (select 1 from ranking_entries e2 join ranking_periods p2 on p2.id = e2.period_id where e2.user_id = e.user_id and p2.period < pr.period and e2.voided_at is null)
          order by e.user_id, (e.scope_kind = 'national') desc, e.rank)
      and is_verified_student(b.user_id)
      and (p_institution is null or b.details ->> 'institution_id' = p_institution::text) and (p_program is null or b.details ->> 'program_id' = p_program::text)
      and (nullif(btrim(p_domain), '') is null or exists (select 1 from talent_skills ts where ts.owner_id = b.user_id and lower(ts.domain) = lower(btrim(p_domain))))
    order by b.rank limit v_lim) z), '[]'::jsonb));
end $$;

-- ============================================================ Vues d'entreprises : enregistrement dédoublonné et compteurs agrégés anonymisés
create or replace function talent_profile_view_record(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_org := _top100_viewer_org();
  if v_org is null then return jsonb_build_object('recorded', false, 'reason', 'not_verified_company'); end if;
  if p_user is null or p_user = auth.uid() or p_user = v_org then return jsonb_build_object('recorded', false, 'reason', 'not_countable'); end if;
  if not exists (select 1 from talent_visibility_settings v where v.user_id = p_user and v.public_ranking) or not is_verified_student(p_user) then return jsonb_build_object('recorded', false, 'reason', 'not_public'); end if;
  if exists (select 1 from user_blocks where (blocker_id = p_user and blocked_id = auth.uid()) or (blocker_id = auth.uid() and blocked_id = p_user)) then return jsonb_build_object('recorded', false, 'reason', 'not_public'); end if;
  select count(*)::int into v_n from talent_profile_views where org_id = v_org and view_day = (now() at time zone 'utc')::date;
  if v_n >= 200 then return jsonb_build_object('recorded', false, 'reason', 'daily_limit'); end if;
  insert into talent_profile_views (org_id, talent_id) values (v_org, p_user) on conflict (org_id, talent_id, view_day) do nothing;
  get diagnostics v_n = row_count;
  return jsonb_build_object('recorded', v_n = 1, 'reason', case when v_n = 1 then null else 'already_counted_today' end);
end $$;

create or replace function talents_most_viewed_by_companies(p_period text default null, p_limit integer default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_period text := coalesce(p_period, to_char(now() at time zone 'utc', 'YYYY-MM')); v_from date; v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 100);
begin
  if v_period !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Période invalide (AAAA-MM)'; end if;
  v_from := to_date(v_period || '-01', 'YYYY-MM-DD');
  return jsonb_build_object('period', v_period, 'items', coalesce((select jsonb_agg(z.j order by z.companies desc, z.views desc, z.nm) from (
    select jsonb_build_object('user_id', x.talent_id, 'name', case when v.show_full_name then pf.name else _short_name(pf.name) end, 'photo', case when v.show_photo then pf.avatar_url end,
             'companies', x.companies, 'views', x.views,
             'institution', (select i.name from student_affiliations a join institutions i on i.id = a.institution_id where a.user_id = x.talent_id and a.status = 'verified' and a.ended_at is null limit 1),
             'program', (select g.name from student_affiliations a join programs g on g.id = a.program_id where a.user_id = x.talent_id and a.status = 'verified' and a.ended_at is null limit 1)) j,
           x.companies, x.views, pf.name nm
    from (select w.talent_id, count(distinct w.org_id)::int companies, count(*)::int views from talent_profile_views w
          where w.view_day >= v_from and w.view_day < (v_from + interval '1 month')::date group by w.talent_id) x
    join talent_visibility_settings v on v.user_id = x.talent_id and v.public_ranking
    join profiles pf on pf.id = x.talent_id
    where is_verified_student(x.talent_id)
    order by x.companies desc, x.views desc, pf.name limit v_lim) z), '[]'::jsonb));
end $$;

-- ============================================================ Historique des classements mensuels
create or replace function ranking_history(p_limit integer default 24) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('period', p.period, 'status', p.status, 'published_at', p.published_at, 'entries_count', p.entries_count, 'corrections', p.correction_count,
    'content_hash', p.content_hash,
    'top', coalesce((select jsonb_agg(_ranking_item_json(e, v, pf) order by e.rank, pf.name)
                     from ranking_entries e
                     join talent_visibility_settings v on v.user_id = e.user_id and v.public_ranking join profiles pf on pf.id = e.user_id
                     where e.period_id = p.id and e.scope_kind = 'national' and e.rank <= 3 and e.voided_at is null and is_verified_student(e.user_id)), '[]'::jsonb)) order by p.period desc), '[]'::jsonb)
  from (select * from ranking_periods order by period desc limit least(greatest(coalesce(p_limit, 24), 1), 120)) p
$$;

-- ============================================================ Page publique d'un talent
create or replace function talent_public_profile(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v talent_visibility_settings; pf profiles; a record; v_latest uuid; v_sections text[]; v_viewer_org uuid; v_contact text; v_self boolean;
begin
  select * into v from talent_visibility_settings where user_id = p_user;
  select * into pf from profiles where id = p_user;
  if v.user_id is null or not v.public_ranking or pf.id is null or not is_verified_student(p_user) then return jsonb_build_object('found', false); end if;
  v_sections := v.shared_sections;
  v_self := p_user = auth.uid();
  v_viewer_org := _top100_viewer_org();
  v_contact := case when auth.uid() is null then 'login_required' when v_self then 'self' when v_viewer_org is not null then 'allowed' else 'not_allowed' end;
  select id into v_latest from ranking_periods where status = 'published' order by period desc limit 1;
  select a2.status, g.name program, i.name institution, a2.promotion, g.department_id, d.name department into a
    from student_affiliations a2 join programs g on g.id = a2.program_id join institutions i on i.id = a2.institution_id left join departments d on d.id = g.department_id
    where a2.user_id = p_user and a2.status = 'verified' and a2.ended_at is null;
  return jsonb_build_object('found', true, 'user_id', p_user,
    'name', case when v.show_full_name then pf.name else _short_name(pf.name) end,
    'photo', case when v.show_photo then pf.avatar_url end,
    'institution', a.institution, 'program', a.program, 'department', a.department, 'promotion', a.promotion, 'affiliation_verified', a.status is not null,
    'shared_sections', to_jsonb(v_sections), 'contact', v_contact,
    'ranking', case when 'rank' = any (v_sections) then coalesce((select jsonb_agg(jsonb_build_object('scope', e.scope_kind, 'scope_ref', e.scope_ref,
          'scope_label', case e.scope_kind when 'program' then e.details ->> 'program' when 'institution' then e.details ->> 'institution' when 'department' then e.details ->> 'department' when 'domain' then e.scope_ref else 'Cameroun' end,
          'rank', e.rank, 'cohort_size', (e.details ->> 'cohort_size')::int, 'period', p.period) order by (e.scope_kind = 'national') desc, e.scope_kind, e.rank)
        from ranking_entries e join ranking_periods p on p.id = e.period_id where e.period_id = v_latest and e.user_id = p_user and e.voided_at is null), '[]'::jsonb) else null end,
    'score', case when 'score' = any (v_sections) then (select e.score from ranking_entries e where e.period_id = v_latest and e.user_id = p_user and e.voided_at is null order by (e.scope_kind = 'national') desc, e.rank limit 1) else null end,
    'evolution', case when 'evolution' = any (v_sections) then coalesce((select jsonb_agg(jsonb_build_object('period', h.period, 'rank', h.rank, 'delta_rank', h.delta_rank, 'month_points', h.month_points,
          'score', case when 'score' = any (v_sections) then h.score end) order by h.period desc)
        from (select distinct on (p.period) p.period, e.rank, e.delta_rank, e.month_points, e.score from ranking_entries e join ranking_periods p on p.id = e.period_id
              where e.user_id = p_user and e.voided_at is null order by p.period, (e.scope_kind = 'national') desc, e.rank) h), '[]'::jsonb) else null end,
    'skills', case when 'skills' = any (v_sections) then coalesce((select jsonb_agg(jsonb_build_object('domain', s.domain, 'skill', s.skill, 'level', s.level, 'years', s.years, 'has_proof', s.proof_document_id is not null,
          'proof_verified', coalesce(d.status = 'verified', false)) order by _talent_level_rank(s.level) desc, s.skill)
        from talent_skills s left join user_documents d on d.id = s.proof_document_id where s.owner_id = p_user), '[]'::jsonb) else null end,
    'badges', case when 'badges' = any (v_sections) then _ranking_badges(p_user) else null end,
    'projects', case when 'projects' = any (v_sections) then coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'summary', left(coalesce(x.summary, ''), 300), 'department', x.department) order by x.updated_at desc)
        from (select pj.* from projects pj where pj.owner_id = p_user and pj.status = 'approved' order by pj.updated_at desc limit 20) x), '[]'::jsonb) else null end,
    'passport', case when 'passport' = any (v_sections) then jsonb_build_object(
        'headline', coalesce((select headline from talent_passport_profile where owner_id = p_user), ''), 'summary', coalesce((select summary from talent_passport_profile where owner_id = p_user), ''),
        'certificates', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'title', c.subject_title, 'issued_at', c.issued_at) order by c.issued_at desc) from certificates c where c.holder_id = p_user and not c.revoked), '[]'::jsonb),
        'missions', coalesce((select jsonb_agg(jsonb_build_object('title', m.title, 'ended_on', m.updated_at::date) order by m.updated_at desc)
                              from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = p_user and mp.status = 'accepted' where m.status in ('delivered', 'closed')), '[]'::jsonb)) else null end,
    'availability', case when v.availability_public then (select jsonb_build_object('kinds', to_jsonb(av.kinds), 'available_from', av.available_from) from student_availability av where av.user_id = p_user) else null end);
end $$;

-- ============================================================ Mes positions (l'étudiant voit ses propres rangs publiés, consentement ou non)
create or replace function my_ranking_positions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_latest uuid; v_period text; v talent_visibility_settings;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  select id, period into v_latest, v_period from ranking_periods where status = 'published' order by period desc limit 1;
  select * into v from talent_visibility_settings where user_id = auth.uid();
  if v_latest is null then
    return jsonb_build_object('published', false, 'positions', '[]'::jsonb, 'public', coalesce(v.public_ranking, false), 'note', 'Aucun classement n''est publié pour le moment.');
  end if;
  return jsonb_build_object('published', true, 'period', v_period, 'public', coalesce(v.public_ranking, false),
    'positions', coalesce((select jsonb_agg(jsonb_build_object('scope', e.scope_kind, 'scope_ref', e.scope_ref, 'rank', e.rank, 'score', e.score, 'month_points', e.month_points, 'delta_rank', e.delta_rank,
        'is_new', e.is_new, 'cohort_size', (e.details ->> 'cohort_size')::int) order by (e.scope_kind = 'national') desc, e.scope_kind)
      from ranking_entries e where e.period_id = v_latest and e.user_id = auth.uid() and e.voided_at is null), '[]'::jsonb));
end $$;

revoke all on function top100_national(text, integer, integer, uuid, uuid, uuid, text, text), top100_by_program(uuid, text, integer, integer, text), top100_by_institution(uuid, text, uuid, uuid, text, text, integer, integer),
  top100_by_department(uuid, text, integer, integer, text), top100_by_domain(text, text, uuid, text, integer, integer), talents_rising(text, integer, uuid, uuid, text), talents_new(text, integer, uuid, uuid, text),
  talents_most_viewed_by_companies(text, integer), ranking_history(integer), talent_public_profile(uuid), talent_profile_view_record(uuid), my_ranking_positions() from public, anon;
grant execute on function top100_national(text, integer, integer, uuid, uuid, uuid, text, text), top100_by_program(uuid, text, integer, integer, text), top100_by_institution(uuid, text, uuid, uuid, text, text, integer, integer),
  top100_by_department(uuid, text, integer, integer, text), top100_by_domain(text, text, uuid, text, integer, integer), talents_rising(text, integer, uuid, uuid, text), talents_new(text, integer, uuid, uuid, text),
  talents_most_viewed_by_companies(text, integer), ranking_history(integer), talent_public_profile(uuid) to anon, authenticated;
grant execute on function talent_profile_view_record(uuid), my_ranking_positions() to authenticated;
