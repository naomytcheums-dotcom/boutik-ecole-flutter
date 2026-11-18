-- Lot H2 « Département » (3/6) : suivi du département (étudiants, projets, innovations, compétences, opportunités, partenariats, validations),
-- réalisations mises en avant, statistiques, rapports exportables. Chaque fonction est cloisonnée par _dept_pick() : un compte Département ne lit que SON département,
-- l'administrateur et la direction peuvent cibler un département (ou tous) en lecture.
-- Retour arrière : drop function dept_overview(uuid), dept_students(int), dept_students_list(text, int, int, uuid), dept_student_detail(uuid), dept_projects(text, text, int, uuid),
--   dept_skills(uuid), dept_opportunities(uuid), dept_opportunity_applicants(uuid, uuid), dept_partnerships(uuid), dept_partnership_save(jsonb, uuid), dept_partnership_delete(uuid),
--   dept_highlights(uuid), dept_highlight_set(text, uuid, text, boolean, uuid), dept_validations(uuid), dept_activity(uuid, int), dept_report(text, date, date, uuid), dept_certificates(uuid), _dept_sees_opp(text, uuid) ;
--   drop table department_partnerships, department_highlights ; alter table productions drop column department_id ; alter table mentors drop column department_id ;
--   recréer staff_mentors, staff_productions, mentor_create, production_create, production_update (20261105000700), department_detail (20261117010000), dept_students (20261105000300).

-- ============================== Tables ==============================
create table if not exists department_partnerships (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references departments(id) on delete cascade,
  partner_name text not null check (char_length(btrim(partner_name)) between 2 and 120),
  kind text not null default 'convention' check (kind in ('stage', 'convention', 'sponsoring', 'atelier', 'recherche', 'mecenat', 'autre')),
  status text not null default 'prospect' check (status in ('prospect', 'negociation', 'actif', 'termine', 'abandonne')),
  contact_name text not null default '' check (char_length(contact_name) <= 120),
  contact_email text not null default '' check (char_length(contact_email) <= 120),
  contact_phone text not null default '' check (char_length(contact_phone) <= 30),
  description text not null default '' check (char_length(description) <= 2000),
  starts_on date,
  ends_on date,
  amount integer not null default 0 check (amount between 0 and 1000000000),
  students integer not null default 0 check (students between 0 and 100000),
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (starts_on is null or ends_on is null or ends_on >= starts_on)
);
create index if not exists department_partnerships_department_idx on department_partnerships (department_id, status);
alter table department_partnerships enable row level security;
drop policy if exists "partenariats : département, direction, administration" on department_partnerships;
create policy "partenariats : département, direction, administration" on department_partnerships for select
  using (coalesce(current_role_name()::text, '') in ('admin', 'direction') or _dept_sees_dept(department_id));
revoke all on department_partnerships from public, anon, authenticated;
grant select on department_partnerships to authenticated;

create table if not exists department_highlights (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references departments(id) on delete cascade,
  kind text not null check (kind in ('project', 'certificate')),
  ref uuid not null,
  title text not null check (char_length(title) between 1 and 160),
  note text not null default '' check (char_length(note) <= 300),
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (department_id, kind, ref)
);
alter table department_highlights enable row level security;
drop policy if exists "réalisations mises en avant : lecture" on department_highlights;
create policy "réalisations mises en avant : lecture" on department_highlights for select using (true);
revoke all on department_highlights from public, anon, authenticated;
grant select (id, department_id, kind, ref, title, note, created_at) on department_highlights to anon, authenticated;

alter table productions add column if not exists department_id uuid references departments(id) on delete set null;
alter table mentors add column if not exists department_id uuid references departments(id) on delete set null;
update productions x set department_id = a.department_id from department_accounts a where x.department_id is null and x.created_by = a.user_id;
update mentors x set department_id = a.department_id from department_accounts a where x.department_id is null and x.created_by = a.user_id;

-- Offre : visible d'un responsable si elle cible son département (nom exact) ou si elle vient d'un compte de son département.
create or replace function _dept_sees_opp(p_target text, p_poster uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select _dept_sees_name(p_target) or _dept_sees(p_poster)
$$;
revoke all on function _dept_sees_opp(text, uuid) from public, anon, authenticated;
grant execute on function _dept_sees_opp(text, uuid) to authenticated;

-- ============================== Encadrement : mentors et productions du département ==============================
create or replace function staff_mentors() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid;
begin
  perform _staff_check(false);
  if coalesce(current_role_name()::text, '') = 'dept' then v := coalesce(_dept_id(), '00000000-0000-0000-0000-000000000000'::uuid); end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'specialty', m.specialty, 'active', m.active,
    'productions', (select count(*)::int from productions p where p.mentor_id = m.id and p.status = 'en_cours')) order by m.created_at desc)
    from mentors m where v is null or m.department_id = v), '[]'::jsonb);
end $$;

create or replace function staff_productions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid;
begin
  perform _staff_check(false);
  if coalesce(current_role_name()::text, '') = 'dept' then v := coalesce(_dept_id(), '00000000-0000-0000-0000-000000000000'::uuid); end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'title', p.title, 'team', p.team, 'mentor', coalesce(m.name, ''), 'progress', p.progress,
    'status', case when p.status = 'en_cours' and p.due_on is not null and p.due_on < current_date then 'en_retard' else p.status end, 'due_on', p.due_on,
    'finished_at', p.finished_at) order by p.created_at desc)
    from productions p left join mentors m on m.id = p.mentor_id where v is null or p.department_id = v), '[]'::jsonb);
end $$;

create or replace function mentor_create(p_name text, p_role text, p_specialty text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; v_dept uuid;
begin
  perform _staff_check(true);
  if coalesce(current_role_name()::text, '') = 'dept' then
    v_dept := _dept_id();
    if v_dept is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;
  end if;
  insert into mentors (name, role, specialty, created_by, department_id) values (trim(p_name), coalesce(nullif(p_role, ''), 'Mentor'), coalesce(trim(p_specialty), ''), auth.uid(), v_dept) returning id into v;
  return v;
end $$;

create or replace function production_create(p_title text, p_team text, p_mentor uuid, p_due date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; v_dept uuid;
begin
  perform _staff_check(true);
  if coalesce(current_role_name()::text, '') = 'dept' then
    v_dept := _dept_id();
    if v_dept is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;
    if p_mentor is not null and not exists (select 1 from mentors m where m.id = p_mentor and m.department_id = v_dept) then raise exception 'Ce mentor relève d''un autre département'; end if;
  end if;
  insert into productions (title, team, mentor_id, due_on, created_by, department_id) values (trim(p_title), coalesce(trim(p_team), ''), p_mentor, p_due, auth.uid(), v_dept) returning id into v;
  return v;
end $$;

create or replace function production_update(p_id uuid, p_progress int, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  perform _staff_check(true);
  if p_status not in ('en_cours', 'terminee', 'annulee') then raise exception 'Statut invalide'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' then v := coalesce(_dept_id(), '00000000-0000-0000-0000-000000000000'::uuid); end if;
  update productions set progress = case when p_status = 'terminee' then 100 else least(greatest(p_progress, 0), 100) end, status = p_status,
    finished_at = case when p_status = 'terminee' then now() else null end where id = p_id and (v is null or department_id = v);
  if not found then raise exception 'Production introuvable'; end if;
end $$;

-- ============================== Étudiants ==============================
create or replace function dept_students(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare scope uuid := _dept_scope();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id, 'name', t.name, 'department', coalesce(t.department, ''), 'role', t.role, 'listings', t.listings, 'sales', t.sales, 'verified', t.verified,
      'verified_student', t.verified_student, 'level', coalesce(t.study_level, ''), 'projects', t.projects, 'skills', t.skills, 'suspended', t.suspended
    ) order by t.name)
    from (
      select p.id, p.name, p.department, p.role::text as role, p.certification::text = 'approved' as verified, is_verified_student(p.id) as verified_student, p.study_level, coalesce(p.suspended, false) as suspended,
             (select count(*)::int from listings l where l.seller_id = p.id and l.status = 'approved') as listings,
             (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = p.id and o.paid and o.cancelled_at is null) as sales,
             (select count(*)::int from projects x where x.owner_id = p.id) as projects,
             (select count(*)::int from talent_skills s where s.owner_id = p.id) as skills
      from profiles p
      where p.role::text = 'student' and (scope is null or p.department_id = scope)
      order by p.name limit least(greatest(p_limit, 1), 200)
    ) t
  ), '[]'::jsonb);
end $$;

create or replace function dept_students_list(p_query text default '', p_limit int default 50, p_offset int default 0, p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); q text := nullif(lower(btrim(coalesce(p_query, ''))), '');
begin
  return jsonb_build_object(
    'total', (select count(*)::int from profiles p where p.role::text = 'student' and (v is null or p.department_id = v) and (q is null or lower(p.name) like '%' || q || '%')),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', t.name, 'department', coalesce(t.department, ''), 'level', coalesce(t.study_level, ''), 'verified_student', t.vs, 'certified', t.cert,
        'suspended', t.suspended, 'listings', t.listings, 'projects', t.projects, 'skills', t.skills) order by t.name)
      from (
        select p.id, p.name, p.department, p.study_level, is_verified_student(p.id) vs, p.certification::text = 'approved' cert, coalesce(p.suspended, false) suspended,
               (select count(*)::int from listings l where l.seller_id = p.id and l.status = 'approved') listings,
               (select count(*)::int from projects x where x.owner_id = p.id) projects,
               (select count(*)::int from talent_skills s where s.owner_id = p.id) skills
        from profiles p
        where p.role::text = 'student' and (v is null or p.department_id = v) and (q is null or lower(p.name) like '%' || q || '%')
        order by p.name limit least(greatest(coalesce(p_limit, 50), 1), 100) offset greatest(coalesce(p_offset, 0), 0)
      ) t), '[]'::jsonb));
end $$;

-- Fiche de suivi d'un étudiant du département (jamais d'un autre) : parcours, projets, compétences, ventes, candidatures.
create or replace function dept_student_detail(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(null); s profiles;
begin
  select * into s from profiles where id = p_user and role::text = 'student';
  if s.id is null or (v is not null and s.department_id is distinct from v) then raise exception 'Étudiant introuvable dans ce département'; end if;
  return jsonb_build_object(
    'id', s.id, 'name', s.name, 'department', coalesce(s.department, ''), 'institution', coalesce(s.institution, ''), 'level', coalesce(s.study_level, ''),
    'verified_student', is_verified_student(s.id), 'certified', s.certification::text = 'approved', 'suspended', coalesce(s.suspended, false), 'since', s.created_at,
    'projects', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind, 'status', x.status, 'updated_at', x.updated_at) order by x.updated_at desc)
                          from projects x where x.owner_id = s.id), '[]'::jsonb),
    'skills', coalesce((select jsonb_agg(jsonb_build_object('skill', k.skill, 'domain', k.domain, 'level', k.level) order by k.skill) from talent_skills k where k.owner_id = s.id), '[]'::jsonb),
    'listings', (select count(*)::int from listings l where l.seller_id = s.id and l.status = 'approved'),
    'sales', (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = s.id and o.paid and o.cancelled_at is null),
    'applications', (select count(*)::int from opportunity_applications a where a.applicant_id = s.id),
    'hired', (select count(*)::int from opportunity_hires h where h.student_id = s.id));
end $$;

-- ============================== Projets, innovations, compétences ==============================
create or replace function dept_projects(p_kind text default null, p_status text default null, p_limit int default 100, p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department);
begin
  if p_kind is not null and p_kind not in ('projet', 'innovation') then raise exception 'Type inconnu'; end if;
  if p_status is not null and p_status not in ('draft', 'submitted', 'approved', 'rejected') then raise exception 'Statut inconnu'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind, 'status', x.status, 'summary', left(coalesce(x.summary, ''), 240), 'owner_id', x.owner_id,
      'owner', coalesce(nullif(btrim(o.name), ''), 'Étudiant'), 'visibility', x.visibility, 'review_note', x.review_note, 'updated_at', x.updated_at,
      'members', (select count(*)::int from project_members m where m.project_id = x.id and m.status = 'accepted'),
      'featured', exists (select 1 from department_highlights h where h.kind = 'project' and h.ref = x.id)) order by x.updated_at desc)
    from (select * from projects pr where (p_kind is null or pr.kind = p_kind) and (p_status is null or pr.status = p_status)
            and exists (select 1 from profiles w where w.id = pr.owner_id and w.department_id is not null and (v is null or w.department_id = v))
          order by pr.updated_at desc limit least(greatest(coalesce(p_limit, 100), 1), 200)) x
    join profiles o on o.id = x.owner_id), '[]'::jsonb);
end $$;

create or replace function dept_skills(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department);
begin
  return jsonb_build_object(
    'students_with_skills', (select count(distinct s.owner_id)::int from talent_skills s join profiles p on p.id = s.owner_id where p.department_id is not null and (v is null or p.department_id = v)),
    'total', (select count(*)::int from talent_skills s join profiles p on p.id = s.owner_id where p.department_id is not null and (v is null or p.department_id = v)),
    'skills', coalesce((
      select jsonb_agg(jsonb_build_object('skill', t.skill, 'domain', t.domain, 'students', t.students, 'advanced', t.advanced) order by t.students desc, t.skill)
      from (select lower(btrim(s.skill)) skill, min(s.domain) domain, count(distinct s.owner_id)::int students,
                   count(distinct s.owner_id) filter (where s.level in ('avance', 'expert'))::int advanced
            from talent_skills s join profiles p on p.id = s.owner_id
            where p.department_id is not null and (v is null or p.department_id = v) group by 1 order by 3 desc, 1 limit 40) t), '[]'::jsonb),
    'domains', coalesce((
      select jsonb_agg(jsonb_build_object('domain', t.domain, 'count', t.n) order by t.n desc, t.domain)
      from (select s.domain, count(*)::int n from talent_skills s join profiles p on p.id = s.owner_id
            where p.department_id is not null and (v is null or p.department_id = v) group by 1 order by 2 desc limit 12) t), '[]'::jsonb));
end $$;

-- ============================== Réalisations mises en avant ==============================
create or replace function dept_highlights(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department);
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'kind', h.kind, 'ref', h.ref, 'title', h.title, 'note', h.note, 'created_at', h.created_at) order by h.created_at desc)
                   from department_highlights h where v is null or h.department_id = v), '[]'::jsonb);
end $$;

create or replace function dept_highlight_set(p_kind text, p_ref uuid, p_note text default '', p_on boolean default true, p_department uuid default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); v_title text; v_ok boolean := false; v_note text := left(btrim(coalesce(p_note, '')), 300); d departments;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if v is null then raise exception 'Indiquez le département'; end if;
  if p_kind not in ('project', 'certificate') then raise exception 'Type inconnu'; end if;
  if not coalesce(p_on, true) then
    delete from department_highlights where department_id = v and kind = p_kind and ref = p_ref;
    return false;
  end if;
  select * into d from departments where id = v;
  if p_kind = 'project' then
    select x.title, true into v_title, v_ok from projects x join profiles o on o.id = x.owner_id
      where x.id = p_ref and o.department_id = v and x.status = 'approved' and x.visibility = 'public' and not coalesce(o.suspended, false);
    if not coalesce(v_ok, false) then raise exception 'Seul un projet validé et public de votre département peut être mis en avant'; end if;
  else
    select c.subject_title, true into v_title, v_ok from certificates c
      where c.id = p_ref and not c.revoked and (c.department is not null and lower(btrim(c.department)) = lower(btrim(d.name)) or exists (select 1 from profiles h where h.id = c.holder_id and h.department_id = v));
    if not coalesce(v_ok, false) then raise exception 'Seul un certificat actif de votre département peut être mis en avant'; end if;
  end if;
  insert into department_highlights (department_id, kind, ref, title, note, created_by) values (v, p_kind, p_ref, left(v_title, 160), v_note, auth.uid())
  on conflict (department_id, kind, ref) do update set note = excluded.note, title = excluded.title;
  return true;
end $$;

-- Fiche publique : identité publiée et réalisations mises en avant (les contacts ne sont publiés que si le département l'a choisi).
create or replace function department_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d departments; i institutions; f department_profiles;
begin
  select * into d from departments where id = p_id and status = 'verified';
  if d.id is null then return null; end if;
  select * into i from institutions where id = d.institution_id;
  select * into f from department_profiles where department_id = d.id;
  return jsonb_build_object(
    'id', d.id, 'name', d.name, 'institution', coalesce(i.name, ''), 'institution_short', coalesce(i.short_name, ''), 'city', coalesce(i.city, ''),
    'description', coalesce(f.description, ''), 'mission', coalesce(f.mission, ''), 'programs', to_jsonb(coalesce(f.programs, '{}'::text[])), 'website', coalesce(f.website, ''),
    'contact_email', case when coalesce(f.contact_public, false) then coalesce(f.contact_email, '') else '' end,
    'contact_phone', case when coalesce(f.contact_public, false) then coalesce(f.contact_phone, '') else '' end,
    'address', case when coalesce(f.contact_public, false) then coalesce(f.address, '') else '' end,
    'highlights', coalesce((select jsonb_agg(jsonb_build_object('kind', h.kind, 'title', h.title, 'note', h.note) order by h.created_at desc)
                            from (select * from department_highlights x where x.department_id = d.id order by x.created_at desc limit 8) h), '[]'::jsonb),
    'students', (select count(*)::int from profiles p where p.department_id = d.id and is_verified_student(p.id)),
    'listings', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = d.id and l.status = 'approved'),
    'projects', (select count(*)::int from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.status = 'approved' and pr.visibility = 'public'),
    'featured', case when auth.uid() is null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'skills', coalesce(s.skills, ''), 'avatar_url', s.avatar_url, 'certified', s.certification::text = 'approved'))
      from (select * from profiles p where p.department_id = d.id and is_verified_student(p.id)
                and nullif(trim(coalesce(p.skills, '')), '') is not null
            order by (p.certification::text = 'approved') desc, p.created_at desc limit 4) s), '[]'::jsonb) end
  );
end $$;

-- ============================== Opportunités ==============================
create or replace function dept_opportunities(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments;
begin
  if v is not null then select * into d from departments where id = v; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', o.id, 'title', o.title, 'org', o.org_name, 'kind', o.kind, 'status', o.status, 'deadline', o.deadline, 'verified', o.verified,
      'targeted', v is not null and lower(btrim(o.department_target)) = lower(btrim(d.name)), 'created_at', o.created_at,
      'applications', (select count(*)::int from opportunity_applications a join profiles p on p.id = a.applicant_id where a.opportunity_id = o.id and p.department_id is not null and (v is null or p.department_id = v)),
      'hired', (select count(*)::int from opportunity_hires h join opportunity_applications a on a.id = h.application_id join profiles p on p.id = h.student_id
                where a.opportunity_id = o.id and p.department_id is not null and (v is null or p.department_id = v))) order by o.created_at desc)
    from (select * from opportunities x
          where (v is null or x.status = 'published' or _dept_sees_opp(x.department_target, x.poster_id))
            and (v is null or x.status in ('published', 'pending', 'rejected', 'closed'))
          order by x.created_at desc limit 200) o), '[]'::jsonb);
end $$;

create or replace function dept_opportunity_applicants(p_opportunity uuid, p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('student_id', p.id, 'name', p.name, 'status', a.status, 'applied_at', a.created_at,
      'hired', exists (select 1 from opportunity_hires h where h.application_id = a.id)) order by a.created_at desc)
    from opportunity_applications a join profiles p on p.id = a.applicant_id
    where a.opportunity_id = p_opportunity and p.department_id is not null and (v is null or p.department_id = v)), '[]'::jsonb);
end $$;

-- ============================== Partenariats ==============================
create or replace function dept_partnerships(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments;
begin
  if v is not null then select * into d from departments where id = v; end if;
  return jsonb_build_object(
    'partnerships', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'department_id', x.department_id, 'partner_name', x.partner_name, 'kind', x.kind, 'status', x.status, 'contact_name', x.contact_name,
        'contact_email', x.contact_email, 'contact_phone', x.contact_phone, 'description', x.description, 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'amount', x.amount, 'students', x.students,
        'updated_at', x.updated_at) order by (x.status in ('actif', 'negociation')) desc, x.updated_at desc)
      from department_partnerships x where v is null or x.department_id = v), '[]'::jsonb),
    'sponsorships', coalesce((select jsonb_agg(jsonb_build_object('sponsor', sp.name, 'title', s.title, 'amount', s.amount, 'students', s.students, 'status', s.status, 'year', s.year) order by s.year desc, s.created_at desc)
      from sponsorships s join sponsors sp on sp.id = s.sponsor_id
      where v is not null and nullif(btrim(coalesce(s.department, '')), '') is not null and lower(btrim(s.department)) = lower(btrim(d.name))), '[]'::jsonb));
end $$;

create or replace function dept_partnership_save(p jsonb, p_department uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); v_id uuid; old department_partnerships; v_name text; v_kind text; v_status text; v_mail text; v_phone text;
  v_start date; v_end date; v_amount int; v_students int; r record;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if p is null or jsonb_typeof(p) <> 'object' then raise exception 'Fiche invalide'; end if;
  v_id := nullif(p->>'id', '')::uuid;
  if v_id is not null then
    select * into old from department_partnerships where id = v_id;
    if old.id is null or (v is not null and old.department_id <> v) then raise exception 'Partenariat introuvable dans ce département'; end if;
    v := old.department_id;
  end if;
  if v is null then raise exception 'Indiquez le département'; end if;
  v_name := btrim(coalesce(p->>'partner_name', ''));
  v_kind := coalesce(nullif(p->>'kind', ''), 'convention');
  v_status := coalesce(nullif(p->>'status', ''), 'prospect');
  v_mail := lower(btrim(coalesce(p->>'contact_email', '')));
  v_phone := btrim(coalesce(p->>'contact_phone', ''));
  if char_length(v_name) not between 2 and 120 then raise exception 'Nom du partenaire : 2 à 120 caractères'; end if;
  if v_kind not in ('stage', 'convention', 'sponsoring', 'atelier', 'recherche', 'mecenat', 'autre') then raise exception 'Type de partenariat inconnu'; end if;
  if v_status not in ('prospect', 'negociation', 'actif', 'termine', 'abandonne') then raise exception 'Statut inconnu'; end if;
  if v_mail <> '' and v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Adresse e-mail invalide'; end if;
  if v_phone <> '' and v_phone !~ '^[0-9+()\s.-]{6,30}$' then raise exception 'Numéro de téléphone invalide'; end if;
  v_start := nullif(p->>'starts_on', '')::date;
  v_end := nullif(p->>'ends_on', '')::date;
  if v_start is not null and v_end is not null and v_end < v_start then raise exception 'La fin ne peut pas précéder le début'; end if;
  v_amount := coalesce(nullif(p->>'amount', '')::int, 0);
  v_students := coalesce(nullif(p->>'students', '')::int, 0);
  if v_amount < 0 or v_students < 0 then raise exception 'Montant et effectif ne peuvent pas être négatifs'; end if;
  if char_length(coalesce(p->>'description', '')) > 2000 then raise exception 'Description : 2000 caractères au plus'; end if;
  if v_id is null then
    insert into department_partnerships (department_id, partner_name, kind, status, contact_name, contact_email, contact_phone, description, starts_on, ends_on, amount, students, created_by)
    values (v, v_name, v_kind, v_status, left(btrim(coalesce(p->>'contact_name', '')), 120), v_mail, v_phone, btrim(coalesce(p->>'description', '')), v_start, v_end, v_amount, v_students, auth.uid())
    returning id into v_id;
  else
    update department_partnerships set partner_name = v_name, kind = v_kind, status = v_status, contact_name = left(btrim(coalesce(p->>'contact_name', '')), 120), contact_email = v_mail, contact_phone = v_phone,
      description = btrim(coalesce(p->>'description', '')), starts_on = v_start, ends_on = v_end, amount = v_amount, students = v_students, updated_at = now() where id = v_id;
  end if;
  if v_status = 'actif' and (old.id is null or old.status <> 'actif') then
    for r in select id from profiles where role::text = 'direction' and not coalesce(suspended, false) limit 50 loop
      perform notify_user(r.id, 'partnership', 'Partenariat de département', (select d.name from departments d where d.id = v) || ' : « ' || v_name || ' » est actif.',
        jsonb_build_object('partnership', v_id, 'department', v));
    end loop;
  end if;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Responsable'), auth.uid(), case when old.id is null then 'Partenariat de département créé' else 'Partenariat de département modifié' end, left(v_name, 200), 'Départements', 'Info');
  return v_id;
end $$;

create or replace function dept_partnership_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v uuid := _dept_pick(null); x department_partnerships;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into x from department_partnerships where id = p_id;
  if x.id is null or (v is not null and x.department_id <> v) then raise exception 'Partenariat introuvable dans ce département'; end if;
  delete from department_partnerships where id = p_id;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Responsable'), auth.uid(), 'Partenariat de département supprimé', left(x.partner_name, 200), 'Départements', 'Info');
end $$;

-- ============================== Validations du ressort du département ==============================
create or replace function dept_validations(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments; res jsonb;
begin
  if v is not null then select * into d from departments where id = v; end if;
  res := jsonb_build_object(
    'certifications', (select count(*)::int from profiles p where p.department_id is not null and (v is null or p.department_id = v) and p.certification::text in ('pending', 'review')),
    'documents', (select count(*)::int from user_documents x join profiles p on p.id = x.owner_id where x.status = 'pending' and p.department_id is not null and (v is null or p.department_id = v)),
    'listings', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where l.status = 'pending' and p.department_id is not null and (v is null or p.department_id = v)),
    'projects', (select count(*)::int from projects x join profiles p on p.id = x.owner_id where x.status = 'submitted' and p.department_id is not null and (v is null or p.department_id = v)),
    'campaigns', (select count(*)::int from campaigns c join profiles p on p.id = c.owner_id where c.status = 'submitted' and p.department_id is not null and (v is null or p.department_id = v)),
    'milestones', (select count(*)::int from campaign_milestones m join campaigns c on c.id = m.campaign_id join profiles p on p.id = c.owner_id
                   where m.declared_at is not null and m.validated_at is null and p.department_id is not null and (v is null or p.department_id = v)),
    'support_requests', (select count(*)::int from project_support_requests s join profiles p on p.id = s.user_id where s.status in ('open', 'in_progress') and p.department_id is not null and (v is null or p.department_id = v)),
    'wishes', (select count(*)::int from wishes w join profiles p on p.id = w.author_id where w.status = 'submitted' and coalesce(w.department_id, p.department_id) is not null and (v is null or coalesce(w.department_id, p.department_id) = v)),
    'mentors', (select count(*)::int from mentor_profiles m join profiles p on p.id = m.user_id where m.status = 'pending' and p.department_id is not null and (v is null or p.department_id = v)),
    'opportunities', (select count(*)::int from opportunities o where o.status = 'pending'
                      and (v is null or (nullif(btrim(o.department_target), '') is not null and lower(btrim(o.department_target)) = lower(btrim(d.name))) or exists (select 1 from profiles p where p.id = o.poster_id and p.department_id = v))),
    'announcements', (select count(*)::int from contest_announcements a where a.status = 'pending'
                      and (v is null or exists (select 1 from profiles p where p.id = a.poster_id and p.department_id = v))));
  return res || jsonb_build_object('total', (select coalesce(sum((e.value)::int), 0)::int from jsonb_each_text(res) e));
end $$;

-- ============================== Vue d'ensemble, activité, rapports ==============================
create or replace function dept_overview(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments; i institutions;
begin
  if v is not null then
    select * into d from departments where id = v;
    select * into i from institutions where id = d.institution_id;
  end if;
  return jsonb_build_object(
    'department_id', v, 'department', d.name, 'institution', coalesce(i.name, ''),
    'students', (select count(*)::int from profiles p where p.role::text = 'student' and p.department_id is not null and (v is null or p.department_id = v)),
    'students_verified', (select count(*)::int from profiles p where p.department_id is not null and (v is null or p.department_id = v) and is_verified_student(p.id)),
    'students_certified', (select count(*)::int from profiles p where p.role::text = 'student' and p.certification::text = 'approved' and p.department_id is not null and (v is null or p.department_id = v)),
    'sellers', (select count(distinct l.seller_id)::int from listings l join profiles p on p.id = l.seller_id where l.status = 'approved' and p.department_id is not null and (v is null or p.department_id = v)),
    'listings', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where l.status = 'approved' and p.department_id is not null and (v is null or p.department_id = v)),
    'projects', (select jsonb_build_object('total', count(*)::int, 'approved', count(*) filter (where x.status = 'approved')::int, 'submitted', count(*) filter (where x.status = 'submitted')::int,
                   'draft', count(*) filter (where x.status = 'draft')::int, 'rejected', count(*) filter (where x.status = 'rejected')::int)
                 from projects x join profiles p on p.id = x.owner_id where x.kind = 'projet' and p.department_id is not null and (v is null or p.department_id = v)),
    'innovations', (select jsonb_build_object('total', count(*)::int, 'approved', count(*) filter (where x.status = 'approved')::int, 'submitted', count(*) filter (where x.status = 'submitted')::int,
                      'draft', count(*) filter (where x.status = 'draft')::int, 'rejected', count(*) filter (where x.status = 'rejected')::int)
                    from projects x join profiles p on p.id = x.owner_id where x.kind = 'innovation' and p.department_id is not null and (v is null or p.department_id = v)),
    'skills', (select jsonb_build_object('total', count(*)::int, 'students', count(distinct s.owner_id)::int, 'advanced', count(*) filter (where s.level in ('avance', 'expert'))::int)
               from talent_skills s join profiles p on p.id = s.owner_id where p.department_id is not null and (v is null or p.department_id = v)),
    'opportunities', jsonb_build_object(
      'published', (select count(*)::int from opportunities o where o.status = 'published' and (v is null or lower(btrim(o.department_target)) = lower(btrim(d.name)) or exists (select 1 from profiles p where p.id = o.poster_id and p.department_id = v))),
      'applications', (select count(*)::int from opportunity_applications a join profiles p on p.id = a.applicant_id where p.department_id is not null and (v is null or p.department_id = v)),
      'hired', (select count(*)::int from opportunity_hires h join profiles p on p.id = h.student_id where p.department_id is not null and (v is null or p.department_id = v))),
    'partnerships', (select jsonb_build_object('total', count(*)::int, 'actif', count(*) filter (where x.status = 'actif')::int, 'negociation', count(*) filter (where x.status = 'negociation')::int,
                       'prospect', count(*) filter (where x.status = 'prospect')::int, 'termine', count(*) filter (where x.status = 'termine')::int)
                     from department_partnerships x where v is null or x.department_id = v),
    'sales', jsonb_build_object(
      'revenue', (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
                  where o.paid and o.cancelled_at is null and p.department_id is not null and (v is null or p.department_id = v)),
      'orders', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
                 where o.paid and o.cancelled_at is null and p.department_id is not null and (v is null or p.department_id = v))),
    'validations', dept_validations(p_department),
    'productions', (select jsonb_build_object('en_cours', count(*) filter (where x.status = 'en_cours')::int, 'terminees', count(*) filter (where x.status = 'terminee')::int)
                    from productions x where v is null or x.department_id = v)
  );
end $$;

create or replace function dept_activity(p_department uuid default null, p_limit int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('kind', a.kind, 'title', a.title, 'who', a.who, 'at', a.at) order by a.at desc)
    from (
      select * from (
        select 'project' kind, case x.kind when 'innovation' then 'Innovation : ' else 'Projet : ' end || x.title as title, o.name who, x.updated_at at
          from projects x join profiles o on o.id = x.owner_id where x.status in ('submitted', 'approved') and o.department_id is not null and (v is null or o.department_id = v)
        union all
        select 'listing', 'Annonce : ' || l.title, s.name, l.updated_at from listings l join profiles s on s.id = l.seller_id
          where l.status = 'approved' and s.department_id is not null and (v is null or s.department_id = v)
        union all
        select 'certification', 'Certification : ' || p.certification::text, p.name, coalesce(p.certification_decided_at, p.created_at) from profiles p
          where p.role::text = 'student' and p.certification::text <> 'none' and p.department_id is not null and (v is null or p.department_id = v)
        union all
        select 'application', 'Candidature : ' || o.title, p.name, a.created_at from opportunity_applications a join opportunities o on o.id = a.opportunity_id join profiles p on p.id = a.applicant_id
          where p.department_id is not null and (v is null or p.department_id = v)
        union all
        select 'partnership', 'Partenariat : ' || x.partner_name, x.status, x.updated_at from department_partnerships x where v is null or x.department_id = v
      ) u order by at desc limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) a), '[]'::jsonb);
end $$;

-- Rapport exportable : colonnes + lignes prêtes à être converties en CSV côté application. Chaque génération est journalisée.
create or replace function dept_report(p_kind text, p_from date default null, p_to date default null, p_department uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments; i institutions; v_from timestamptz := coalesce(p_from, date '2000-01-01')::timestamptz;
  v_to timestamptz := (coalesce(p_to, current_date) + 1)::timestamptz; cols jsonb; rws jsonb; v_title text; v_total jsonb := '{}'::jsonb;
begin
  if p_kind not in ('synthese', 'etudiants', 'projets', 'competences', 'opportunites', 'partenariats', 'ventes') then raise exception 'Rapport inconnu'; end if;
  if p_from is not null and p_to is not null and p_to < p_from then raise exception 'La période est inversée'; end if;
  if v is not null then
    select * into d from departments where id = v;
    select * into i from institutions where id = d.institution_id;
  end if;
  if p_kind = 'synthese' then
    v_title := 'Synthèse du département';
    cols := '[{"key":"indicateur","label":"Indicateur"},{"key":"valeur","label":"Valeur"}]'::jsonb;
    with o as (select dept_overview(p_department) j)
    select jsonb_agg(jsonb_build_object('indicateur', x.k, 'valeur', x.val) order by x.ord) into rws from o, lateral (values
      (1, 'Étudiants déclarés', (o.j->>'students')), (2, 'Étudiants vérifiés', (o.j->>'students_verified')), (3, 'Étudiants certifiés', (o.j->>'students_certified')),
      (4, 'Vendeurs actifs', (o.j->>'sellers')), (5, 'Annonces approuvées', (o.j->>'listings')),
      (6, 'Projets', (o.j->'projects'->>'total')), (7, 'Projets validés', (o.j->'projects'->>'approved')),
      (8, 'Innovations', (o.j->'innovations'->>'total')), (9, 'Innovations validées', (o.j->'innovations'->>'approved')),
      (10, 'Compétences déclarées', (o.j->'skills'->>'total')), (11, 'Offres publiées', (o.j->'opportunities'->>'published')),
      (12, 'Candidatures d''étudiants', (o.j->'opportunities'->>'applications')), (13, 'Embauches', (o.j->'opportunities'->>'hired')),
      (14, 'Partenariats', (o.j->'partnerships'->>'total')), (15, 'Partenariats actifs', (o.j->'partnerships'->>'actif')),
      (16, 'Chiffre d''affaires (FCFA)', (o.j->'sales'->>'revenue')), (17, 'Validations en attente', (o.j->'validations'->>'total'))) x(ord, k, val);
  elsif p_kind = 'etudiants' then
    v_title := 'Étudiants du département';
    cols := '[{"key":"nom","label":"Nom"},{"key":"niveau","label":"Niveau"},{"key":"verifie","label":"Vérifié"},{"key":"certifie","label":"Certifié"},{"key":"annonces","label":"Annonces"},{"key":"projets","label":"Projets"},{"key":"competences","label":"Compétences"}]'::jsonb;
    select coalesce(jsonb_agg(jsonb_build_object('nom', p.name, 'niveau', coalesce(p.study_level, ''), 'verifie', case when is_verified_student(p.id) then 'oui' else 'non' end,
        'certifie', case when p.certification::text = 'approved' then 'oui' else 'non' end,
        'annonces', (select count(*) from listings l where l.seller_id = p.id and l.status = 'approved'), 'projets', (select count(*) from projects x where x.owner_id = p.id),
        'competences', (select count(*) from talent_skills s where s.owner_id = p.id)) order by p.name), '[]'::jsonb) into rws
    from profiles p where p.role::text = 'student' and p.department_id is not null and (v is null or p.department_id = v);
  elsif p_kind = 'projets' then
    v_title := 'Projets et innovations';
    cols := '[{"key":"titre","label":"Titre"},{"key":"type","label":"Type"},{"key":"statut","label":"Statut"},{"key":"porteur","label":"Porteur"},{"key":"mis_a_jour","label":"Mis à jour"}]'::jsonb;
    select coalesce(jsonb_agg(jsonb_build_object('titre', x.title, 'type', x.kind, 'statut', x.status, 'porteur', o.name, 'mis_a_jour', to_char(x.updated_at, 'YYYY-MM-DD')) order by x.updated_at desc), '[]'::jsonb) into rws
    from projects x join profiles o on o.id = x.owner_id where o.department_id is not null and (v is null or o.department_id = v) and x.updated_at >= v_from and x.updated_at < v_to;
  elsif p_kind = 'competences' then
    v_title := 'Compétences valorisées';
    cols := '[{"key":"competence","label":"Compétence"},{"key":"domaine","label":"Domaine"},{"key":"etudiants","label":"Étudiants"},{"key":"niveau_avance","label":"Niveau avancé ou expert"}]'::jsonb;
    select coalesce(jsonb_agg(jsonb_build_object('competence', t.skill, 'domaine', t.domain, 'etudiants', t.n, 'niveau_avance', t.adv) order by t.n desc, t.skill), '[]'::jsonb) into rws
    from (select lower(btrim(s.skill)) skill, min(s.domain) domain, count(distinct s.owner_id) n, count(distinct s.owner_id) filter (where s.level in ('avance', 'expert')) adv
          from talent_skills s join profiles p on p.id = s.owner_id where p.department_id is not null and (v is null or p.department_id = v) group by 1) t;
  elsif p_kind = 'opportunites' then
    v_title := 'Opportunités et candidatures';
    cols := '[{"key":"offre","label":"Offre"},{"key":"organisation","label":"Organisation"},{"key":"type","label":"Type"},{"key":"statut","label":"Statut"},{"key":"candidatures","label":"Candidatures du département"},{"key":"embauches","label":"Embauches"}]'::jsonb;
    select coalesce(jsonb_agg(jsonb_build_object('offre', o.title, 'organisation', o.org_name, 'type', o.kind, 'statut', o.status,
        'candidatures', (select count(*) from opportunity_applications a join profiles p on p.id = a.applicant_id where a.opportunity_id = o.id and p.department_id is not null and (v is null or p.department_id = v)),
        'embauches', (select count(*) from opportunity_hires h join opportunity_applications a on a.id = h.application_id join profiles p on p.id = h.student_id
                      where a.opportunity_id = o.id and p.department_id is not null and (v is null or p.department_id = v))) order by o.created_at desc), '[]'::jsonb) into rws
    from opportunities o where (v is null or o.status = 'published' or _dept_sees_opp(o.department_target, o.poster_id)) and o.created_at >= v_from and o.created_at < v_to;
  elsif p_kind = 'partenariats' then
    v_title := 'Partenariats';
    cols := '[{"key":"partenaire","label":"Partenaire"},{"key":"type","label":"Type"},{"key":"statut","label":"Statut"},{"key":"debut","label":"Début"},{"key":"fin","label":"Fin"},{"key":"montant","label":"Montant (FCFA)"},{"key":"etudiants","label":"Étudiants concernés"}]'::jsonb;
    select coalesce(jsonb_agg(jsonb_build_object('partenaire', x.partner_name, 'type', x.kind, 'statut', x.status, 'debut', x.starts_on, 'fin', x.ends_on, 'montant', x.amount, 'etudiants', x.students) order by x.updated_at desc), '[]'::jsonb) into rws
    from department_partnerships x where (v is null or x.department_id = v);
  else
    v_title := 'Ventes des étudiants';
    cols := '[{"key":"vendeur","label":"Vendeur"},{"key":"commandes","label":"Commandes payées"},{"key":"chiffre_affaires","label":"Chiffre d''affaires (FCFA)"}]'::jsonb;
    select coalesce(jsonb_agg(jsonb_build_object('vendeur', t.name, 'commandes', t.n, 'chiffre_affaires', t.ca) order by t.ca desc), '[]'::jsonb) into rws
    from (select p.name, count(distinct o.id) n, coalesce(sum(ol.unit_price * ol.qty), 0)::bigint ca
          from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
          where o.paid and o.cancelled_at is null and p.department_id is not null and (v is null or p.department_id = v) and o.created_at >= v_from and o.created_at < v_to group by p.id, p.name) t;
  end if;
  v_total := jsonb_build_object('rows', jsonb_array_length(coalesce(rws, '[]'::jsonb)));
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Responsable'), auth.uid(), 'Rapport de département généré', left(v_title || coalesce(' : ' || d.name, ''), 200), 'Départements', 'Info');
  return jsonb_build_object('kind', p_kind, 'title', v_title, 'department', d.name, 'institution', coalesce(i.name, ''), 'from', p_from, 'to', p_to, 'generated_at', now(),
    'columns', cols, 'rows', coalesce(rws, '[]'::jsonb), 'totals', v_total);
end $$;

-- ============================== Registre des certificats du département ==============================
create or replace function dept_certificates(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments;
begin
  if v is not null then select * into d from departments where id = v; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'code', c.code, 'kind', c.subject_kind, 'subject', c.subject_title, 'holder', c.holder_name, 'department', coalesce(c.department, ''),
      'issued_at', c.issued_at, 'revoked', c.revoked, 'revoked_reason', c.revoked_reason,
      'featured', exists (select 1 from department_highlights h where h.kind = 'certificate' and h.ref = c.id)) order by c.issued_at desc)
    from (select * from certificates x
          where v is null or (x.department is not null and lower(btrim(x.department)) = lower(btrim(d.name))) or exists (select 1 from profiles h where h.id = x.holder_id and h.department_id = v)
          order by x.issued_at desc limit 200) c), '[]'::jsonb);
end $$;

revoke all on function dept_overview(uuid), dept_students(int), dept_students_list(text, int, int, uuid), dept_student_detail(uuid), dept_projects(text, text, int, uuid), dept_skills(uuid),
  dept_opportunities(uuid), dept_opportunity_applicants(uuid, uuid), dept_partnerships(uuid), dept_partnership_save(jsonb, uuid), dept_partnership_delete(uuid), dept_highlights(uuid),
  dept_highlight_set(text, uuid, text, boolean, uuid), dept_validations(uuid), dept_activity(uuid, int), dept_report(text, date, date, uuid), dept_certificates(uuid), department_detail(uuid) from public, anon;
grant execute on function dept_overview(uuid), dept_students(int), dept_students_list(text, int, int, uuid), dept_student_detail(uuid), dept_projects(text, text, int, uuid), dept_skills(uuid),
  dept_opportunities(uuid), dept_opportunity_applicants(uuid, uuid), dept_partnerships(uuid), dept_partnership_save(jsonb, uuid), dept_partnership_delete(uuid), dept_highlights(uuid),
  dept_highlight_set(text, uuid, text, boolean, uuid), dept_validations(uuid), dept_activity(uuid, int), dept_report(text, date, date, uuid), dept_certificates(uuid) to authenticated;
grant execute on function department_detail(uuid) to anon, authenticated;

