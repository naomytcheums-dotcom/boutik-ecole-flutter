-- Lot H3 (Direction) : vision transversale en LECTURE pour la direction (et l'administrateur).
-- Fonctions direction_* : tableau de bord institutionnel, départements (liste + fiche), activités / projets / innovations / productions /
-- événements / offres, performances, personnes (étudiants, responsables, mentors), finance consolidée, rapport consolidé exportable.
-- Toutes sont en lecture seule, security definer, vérifient auth.uid() et le rôle (direction ou admin) dans le corps ; un compte suspendu n'a
-- plus de rôle effectif. Elles ne renvoient ni e-mail, ni téléphone, ni dernière connexion, ni donnée de paiement individuelle : ce sont des
-- chiffres consolidés et des listes de réalisations. La finance détaillée reste à la finance (voir 20261120030000).
-- Les départements sont lus ici ; aucune fonction de ce fichier ne modifie quoi que ce soit.
-- Retour arrière : drop function direction_dashboard(), direction_departments(), direction_department_detail(uuid), direction_activity(text, uuid, int),
--   direction_performance(), direction_people(text, uuid, int), direction_finance_summary(int), direction_consolidated_report(date, date), direction_dept_partnerships(uuid), direction_sponsors_report();

create or replace function direction_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_since timestamptz := now() - interval '30 days'; v_prev timestamptz := now() - interval '60 days';
begin
  perform _inst_check_direction();
  return jsonb_build_object(
    'students', (select count(*)::int from profiles where role::text = 'student' and not coalesce(suspended, false)),
    'students_verified', (select count(*)::int from profiles where is_verified_student(id)),
    'students_new_30d', (select count(*)::int from profiles where role::text = 'student' and created_at >= v_since),
    'students_new_prev_30d', (select count(*)::int from profiles where role::text = 'student' and created_at >= v_prev and created_at < v_since),
    'departments', (select count(*)::int from departments where status = 'verified'),
    'dept_heads', (select count(*)::int from profiles where role::text = 'dept' and not coalesce(suspended, false)),
    'projects', (select count(*)::int from projects where kind = 'projet' and status = 'approved'),
    'innovations', (select count(*)::int from projects where kind = 'innovation' and status = 'approved'),
    'projects_pending', (select count(*)::int from projects where status = 'submitted'),
    'projects_30d', (select count(*)::int from projects where status <> 'draft' and created_at >= v_since),
    'projects_prev_30d', (select count(*)::int from projects where status <> 'draft' and created_at >= v_prev and created_at < v_since),
    'productions_active', (select count(*)::int from productions where status = 'en_cours'),
    'productions_done', (select count(*)::int from productions where status = 'terminee'),
    'mentors', (select count(*)::int from mentors where active),
    'events_upcoming', (select count(*)::int from events where status = 'published' and starts_at >= now()),
    'events_30d', (select count(*)::int from events where status = 'published' and starts_at >= v_since and starts_at < now()),
    'opportunities', (select count(*)::int from opportunities where status = 'published'),
    'applications_30d', (select count(*)::int from opportunity_applications where created_at >= v_since),
    'partnerships_active', (select count(*)::int from institutional_partnerships where status = 'active'),
    'partnerships_proposed', (select count(*)::int from institutional_partnerships where status = 'proposed'),
    'dept_partnerships_active', (select count(*)::int from department_partnerships where status = 'actif'),
    'validations_pending', (select count(*)::int from institutional_validations where status = 'pending'),
    'listings_approved', (select count(*)::int from listings where status = 'approved'),
    'orders_paid', (select count(*)::int from orders where paid and cancelled_at is null),
    'paid_revenue', (select coalesce(sum(subtotal + fee), 0)::bigint from orders where paid and cancelled_at is null),
    'months', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'month', to_char(m, 'YYYY-MM'),
        'projects', (select count(*)::int from projects pr where pr.status <> 'draft' and date_trunc('month', pr.created_at) = m),
        'orders_paid', (select count(*)::int from orders o where o.paid and o.cancelled_at is null and date_trunc('month', o.created_at) = m),
        'students_new', (select count(*)::int from profiles s where s.role::text = 'student' and date_trunc('month', s.created_at) = m)
      ) order by m), '[]'::jsonb)
      from generate_series(date_trunc('month', now()) - interval '5 months', date_trunc('month', now()), interval '1 month') m
    )
  );
end $$;

create or replace function direction_departments() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _inst_check_direction();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', d.id, 'name', d.name, 'institution', i.name, 'status', d.status,
      'head', (select string_agg(p.name, ', ' order by p.name) from profiles p where p.department_id = d.id and p.role::text = 'dept'),
      'students', (select count(*)::int from profiles p where p.department_id = d.id and p.role::text = 'student' and not coalesce(p.suspended, false)),
      'students_verified', (select count(*)::int from profiles p where p.department_id = d.id and is_verified_student(p.id)),
      'projects', (select count(*)::int from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.kind = 'projet' and pr.status = 'approved'),
      'innovations', (select count(*)::int from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.kind = 'innovation' and pr.status = 'approved'),
      'projects_pending', (select count(*)::int from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.status = 'submitted'),
      'listings', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = d.id and l.status = 'approved'),
      'sales', (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
                where p.department_id = d.id and o.paid and o.cancelled_at is null),
      'partnerships', (select count(*)::int from institutional_partnerships ip where ip.department_id = d.id and ip.status = 'active'),
      'dept_partnerships', (select count(*)::int from department_partnerships dp where dp.department_id = d.id and dp.status = 'actif')
    ) order by i.name, d.name)
    from departments d join institutions i on i.id = d.institution_id
  ), '[]'::jsonb);
end $$;

create or replace function direction_department_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_d record;
begin
  perform _inst_check_direction();
  select d.id, d.name, d.status, i.name as institution into v_d from departments d join institutions i on i.id = d.institution_id where d.id = p_id;
  if not found then raise exception 'Département introuvable'; end if;
  return jsonb_build_object(
    'id', v_d.id, 'name', v_d.name, 'institution', v_d.institution, 'status', v_d.status,
    'heads', (select coalesce(jsonb_agg(p.name order by p.name), '[]'::jsonb) from profiles p where p.department_id = p_id and p.role::text = 'dept'),
    'students', (select count(*)::int from profiles p where p.department_id = p_id and p.role::text = 'student' and not coalesce(p.suspended, false)),
    'students_verified', (select count(*)::int from profiles p where p.department_id = p_id and is_verified_student(p.id)),
    'recent_projects', (
      select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind, 'owner', x.owner, 'status', x.status, 'created_at', x.created_at) order by x.created_at desc), '[]'::jsonb)
      from (select pr.id, pr.title, pr.kind, pr.status, pr.created_at, p.name as owner from projects pr join profiles p on p.id = pr.owner_id
            where p.department_id = p_id and pr.status <> 'draft' order by pr.created_at desc limit 10) x
    ),
    'partnerships', (
      select coalesce(jsonb_agg(jsonb_build_object('id', ip.id, 'name', ip.name, 'kind', ip.kind, 'status', ip.status) order by ip.created_at desc), '[]'::jsonb)
      from institutional_partnerships ip where ip.department_id = p_id and ip.status in ('proposed', 'active', 'suspended')
    )
  );
end $$;

-- Suivi des partenariats tenus par les départements (table du lot département) : lecture seule pour la direction, tous départements ou un seul.
create or replace function direction_dept_partnerships(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _inst_check_direction();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'department_id', x.department_id, 'department', x.department, 'partner', x.partner_name, 'kind', x.kind, 'status', x.status,
                                        'starts_on', x.starts_on, 'ends_on', x.ends_on, 'students', x.students, 'amount', x.amount, 'updated_at', x.updated_at)
                     order by (x.status in ('actif', 'negociation')) desc, x.updated_at desc)
    from (
      select dp.*, d.name as department from department_partnerships dp join departments d on d.id = dp.department_id
      where p_department is null or dp.department_id = p_department order by dp.updated_at desc limit 300
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function direction_activity(p_kind text, p_department uuid default null, p_limit int default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_n int := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  perform _inst_check_direction();
  if coalesce(p_kind, '') not in ('projects', 'innovations', 'productions', 'events', 'opportunities') then raise exception 'Type d''activité inconnu'; end if;
  if p_kind in ('projects', 'innovations') then
    return coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'owner', x.owner, 'department', x.department, 'status', x.status, 'created_at', x.created_at) order by x.created_at desc)
      from (
        select pr.id, pr.title, pr.status, pr.created_at, p.name as owner, coalesce(d.name, nullif(pr.department, ''), nullif(p.department, '')) as department
        from projects pr join profiles p on p.id = pr.owner_id left join departments d on d.id = p.department_id
        where pr.kind = case p_kind when 'innovations' then 'innovation' else 'projet' end and pr.status <> 'draft'
          and (p_department is null or p.department_id = p_department)
        order by pr.created_at desc limit v_n
      ) x
    ), '[]'::jsonb);
  elsif p_kind = 'productions' then
    return coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'team', x.team, 'mentor', x.mentor, 'progress', x.progress, 'status', x.status, 'due_on', x.due_on, 'created_at', x.created_at) order by x.created_at desc)
      from (
        select pd.id, pd.title, pd.team, pd.progress, pd.status, pd.due_on, pd.created_at, m.name as mentor
        from productions pd left join mentors m on m.id = pd.mentor_id order by pd.created_at desc limit v_n
      ) x
    ), '[]'::jsonb);
  elsif p_kind = 'events' then
    return coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind, 'place', x.place, 'status', x.status, 'starts_at', x.starts_at, 'registrations', x.registrations) order by x.starts_at desc)
      from (
        select e.id, e.title, e.kind, e.place, e.status, e.starts_at, (select count(*)::int from event_registrations r where r.event_id = e.id) as registrations
        from events e where e.status <> 'draft' order by e.starts_at desc limit v_n
      ) x
    ), '[]'::jsonb);
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'org', x.org_name, 'kind', x.kind, 'status', x.status, 'deadline', x.deadline, 'applications', x.applications, 'created_at', x.created_at) order by x.created_at desc)
    from (
      select o.id, o.title, o.org_name, o.kind, o.status, o.deadline, o.created_at, (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id) as applications
      from opportunities o
      where p_department is null or o.department_target = '' or lower(o.department_target) = lower(coalesce((select name from departments where id = p_department), ''))
      order by o.created_at desc limit v_n
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function direction_performance() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_a timestamptz := now() - interval '90 days'; v_b timestamptz := now() - interval '180 days';
begin
  perform _inst_check_direction();
  return jsonb_build_object(
    'periods', jsonb_build_object(
      'projects', jsonb_build_object('current', (select count(*)::int from projects where status <> 'draft' and created_at >= v_a), 'previous', (select count(*)::int from projects where status <> 'draft' and created_at >= v_b and created_at < v_a)),
      'orders', jsonb_build_object('current', (select count(*)::int from orders where paid and cancelled_at is null and created_at >= v_a), 'previous', (select count(*)::int from orders where paid and cancelled_at is null and created_at >= v_b and created_at < v_a)),
      'students', jsonb_build_object('current', (select count(*)::int from profiles where role::text = 'student' and created_at >= v_a), 'previous', (select count(*)::int from profiles where role::text = 'student' and created_at >= v_b and created_at < v_a)),
      'applications', jsonb_build_object('current', (select count(*)::int from opportunity_applications where created_at >= v_a), 'previous', (select count(*)::int from opportunity_applications where created_at >= v_b and created_at < v_a))
    ),
    'validation_rate', (select case when count(*) filter (where status in ('approved', 'rejected')) = 0 then null
                                    else round(100.0 * count(*) filter (where status = 'approved') / count(*) filter (where status in ('approved', 'rejected')))::int end from projects),
    'departments', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', t.name, 'students_verified', t.sv, 'projects_approved', t.pa, 'projects_rejected', t.pr, 'innovations_approved', t.ia,
        'approval_rate', case when t.pa + t.pr = 0 then null else round(100.0 * t.pa / (t.pa + t.pr))::int end,
        'projects_per_100_students', case when t.sv = 0 then null else round(100.0 * (t.pa + t.ia) / t.sv)::int end,
        'active_sellers', t.sellers, 'sales', t.sales, 'partnerships', t.partners
      ) order by t.name), '[]'::jsonb)
      from (
        select d.id, d.name,
          (select count(*)::int from profiles p where p.department_id = d.id and is_verified_student(p.id)) as sv,
          (select count(*)::int from projects x join profiles p on p.id = x.owner_id where p.department_id = d.id and x.kind = 'projet' and x.status = 'approved') as pa,
          (select count(*)::int from projects x join profiles p on p.id = x.owner_id where p.department_id = d.id and x.status = 'rejected') as pr,
          (select count(*)::int from projects x join profiles p on p.id = x.owner_id where p.department_id = d.id and x.kind = 'innovation' and x.status = 'approved') as ia,
          (select count(distinct l.seller_id)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = d.id and l.status = 'approved') as sellers,
          (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
           where p.department_id = d.id and o.paid and o.cancelled_at is null) as sales,
          (select count(*)::int from institutional_partnerships ip where ip.department_id = d.id and ip.status = 'active') as partners
        from departments d where d.status = 'verified'
      ) t
    )
  );
end $$;

create or replace function direction_people(p_kind text, p_department uuid default null, p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_n int := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  perform _inst_check_direction();
  if coalesce(p_kind, '') not in ('students', 'responsables', 'mentors') then raise exception 'Type de personnes inconnu'; end if;
  if p_kind = 'students' then
    return coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'department', x.department, 'level', x.level, 'verified', x.verified, 'projects', x.projects) order by x.name)
      from (
        select p.id, p.name, coalesce(d.name, nullif(p.department, '')) as department, p.study_level as level, is_verified_student(p.id) as verified,
               (select count(*)::int from projects pr where pr.owner_id = p.id and pr.status = 'approved') as projects
        from profiles p left join departments d on d.id = p.department_id
        where p.role::text = 'student' and not coalesce(p.suspended, false) and (p_department is null or p.department_id = p_department)
        order by p.name limit v_n
      ) x
    ), '[]'::jsonb);
  elsif p_kind = 'responsables' then
    return coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'role', x.role, 'department', x.department) order by x.role, x.name)
      from (
        select p.id, p.name, p.role::text as role, coalesce(d.name, nullif(p.department, '')) as department
        from profiles p left join departments d on d.id = p.department_id
        where p.role::text = 'dept' and not coalesce(p.suspended, false) and (p_department is null or p.department_id = p_department)
        order by p.name limit v_n
      ) x
    ), '[]'::jsonb);
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name, 'role', m.role, 'specialty', m.specialty, 'active', m.active,
                                        'productions', (select count(*)::int from productions pd where pd.mentor_id = m.id)) order by m.name)
    from (select * from mentors order by name limit v_n) m
  ), '[]'::jsonb);
end $$;

create or replace function direction_finance_summary(p_months int default 12) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_n int := least(greatest(coalesce(p_months, 12), 1), 36);
begin
  perform _inst_check_direction();
  return jsonb_build_object(
    'months', (
      select coalesce(jsonb_agg(jsonb_build_object('month', to_char(m, 'YYYY-MM'),
        'orders_paid', (select count(*)::int from orders o where o.paid and o.cancelled_at is null and date_trunc('month', o.created_at) = m),
        'collected', (select coalesce(sum(o.subtotal + o.fee), 0)::bigint from orders o where o.paid and o.cancelled_at is null and date_trunc('month', o.created_at) = m),
        'fees', (select coalesce(sum(o.fee), 0)::bigint from orders o where o.paid and o.cancelled_at is null and date_trunc('month', o.created_at) = m)
      ) order by m desc), '[]'::jsonb)
      from generate_series(date_trunc('month', now()) - make_interval(months => v_n - 1), date_trunc('month', now()), interval '1 month') m
    ),
    'totals', jsonb_build_object(
      'orders_paid', (select count(*)::int from orders where paid and cancelled_at is null),
      'collected', (select coalesce(sum(subtotal + fee), 0)::bigint from orders where paid and cancelled_at is null),
      'fees', (select coalesce(sum(fee), 0)::bigint from orders where paid and cancelled_at is null),
      'paid_out_30d', (select coalesce(sum(amount), 0)::bigint from payout_batches where status = 'verse' and paid_on >= current_date - 30)
    )
  );
end $$;

create or replace function direction_consolidated_report(p_from date default null, p_to date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_to date := coalesce(p_to, current_date);
  v_from date := coalesce(p_from, date_trunc('year', coalesce(p_to, current_date))::date);
  v_a timestamptz; v_b timestamptz; v_who text; v_lines jsonb := '[]'::jsonb; d record;
begin
  perform _inst_check_direction();
  if v_from > v_to then raise exception 'La date de début suit la date de fin'; end if;
  if v_to - v_from > 1830 then raise exception 'Période trop longue (5 ans au maximum)'; end if;
  v_a := v_from::timestamptz; v_b := (v_to + 1)::timestamptz;
  select name into v_who from profiles where id = auth.uid();
  v_lines := jsonb_build_array(
    jsonb_build_object('section', 'Étudiants', 'indicator', 'Étudiants vérifiés (total)', 'department', '', 'value', (select count(*) from profiles where is_verified_student(id))),
    jsonb_build_object('section', 'Étudiants', 'indicator', 'Nouveaux comptes étudiants sur la période', 'department', '', 'value', (select count(*) from profiles where role::text = 'student' and created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Activités', 'indicator', 'Projets déposés sur la période', 'department', '', 'value', (select count(*) from projects where kind = 'projet' and status <> 'draft' and created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Activités', 'indicator', 'Projets validés (total)', 'department', '', 'value', (select count(*) from projects where kind = 'projet' and status = 'approved')),
    jsonb_build_object('section', 'Activités', 'indicator', 'Innovations déposées sur la période', 'department', '', 'value', (select count(*) from projects where kind = 'innovation' and status <> 'draft' and created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Activités', 'indicator', 'Innovations validées (total)', 'department', '', 'value', (select count(*) from projects where kind = 'innovation' and status = 'approved')),
    jsonb_build_object('section', 'Activités', 'indicator', 'Productions en cours', 'department', '', 'value', (select count(*) from productions where status = 'en_cours')),
    jsonb_build_object('section', 'Activités', 'indicator', 'Productions terminées sur la période', 'department', '', 'value', (select count(*) from productions where finished_at >= v_a and finished_at < v_b)),
    jsonb_build_object('section', 'Événements', 'indicator', 'Événements publiés sur la période', 'department', '', 'value', (select count(*) from events where status = 'published' and starts_at >= v_a and starts_at < v_b)),
    jsonb_build_object('section', 'Opportunités', 'indicator', 'Offres publiées sur la période', 'department', '', 'value', (select count(*) from opportunities where status = 'published' and created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Opportunités', 'indicator', 'Candidatures reçues sur la période', 'department', '', 'value', (select count(*) from opportunity_applications where created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Partenariats', 'indicator', 'Partenariats actifs (total)', 'department', '', 'value', (select count(*) from institutional_partnerships where status = 'active')),
    jsonb_build_object('section', 'Partenariats', 'indicator', 'Partenariats proposés sur la période', 'department', '', 'value', (select count(*) from institutional_partnerships where created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Partenariats', 'indicator', 'Partenariats validés sur la période', 'department', '', 'value', (select count(*) from institutional_decision_log where kind = 'partnership' and action = 'Partenariat validé' and created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Validations', 'indicator', 'Validations institutionnelles en attente', 'department', '', 'value', (select count(*) from institutional_validations where status = 'pending')),
    jsonb_build_object('section', 'Validations', 'indicator', 'Décisions rendues sur la période', 'department', '', 'value', (select count(*) from institutional_decision_log where created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Commerce', 'indicator', 'Commandes payées sur la période', 'department', '', 'value', (select count(*) from orders where paid and cancelled_at is null and created_at >= v_a and created_at < v_b)),
    jsonb_build_object('section', 'Commerce', 'indicator', 'Montant encaissé sur la période (FCFA)', 'department', '', 'value', (select coalesce(sum(subtotal + fee), 0) from orders where paid and cancelled_at is null and created_at >= v_a and created_at < v_b))
  );
  for d in select id, name from departments where status = 'verified' order by name loop
    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object('section', 'Départements', 'indicator', 'Étudiants vérifiés', 'department', d.name, 'value', (select count(*) from profiles p where p.department_id = d.id and is_verified_student(p.id))),
      jsonb_build_object('section', 'Départements', 'indicator', 'Projets et innovations déposés sur la période', 'department', d.name,
        'value', (select count(*) from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.status <> 'draft' and pr.created_at >= v_a and pr.created_at < v_b)),
      jsonb_build_object('section', 'Départements', 'indicator', 'Projets et innovations validés (total)', 'department', d.name,
        'value', (select count(*) from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.status = 'approved')),
      jsonb_build_object('section', 'Départements', 'indicator', 'Partenariats actifs', 'department', d.name, 'value', (select count(*) from institutional_partnerships ip where ip.department_id = d.id and ip.status = 'active')),
      jsonb_build_object('section', 'Départements', 'indicator', 'Ventes payées sur la période (FCFA)', 'department', d.name,
        'value', (select coalesce(sum(ol.unit_price * ol.qty), 0) from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
                  where p.department_id = d.id and o.paid and o.cancelled_at is null and o.created_at >= v_a and o.created_at < v_b))
    );
  end loop;
  return jsonb_build_object('from', v_from, 'to', v_to, 'generated_at', now(), 'generated_by', coalesce(v_who, ''), 'lines', v_lines);
end $$;

-- Rapport de sponsoring consolidé (écran 239) : tous les sponsors et leurs contributions, pour la direction (un sponsor ne voit que le sien).
create or replace function direction_sponsors_report() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _inst_check_direction();
  return jsonb_build_object(
    'total', (select coalesce(sum(amount), 0)::bigint from sponsorships),
    'students', (select coalesce(sum(students), 0)::int from sponsorships),
    'sponsors', (select count(*)::int from sponsors),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object('sponsor', sp.name, 'title', s.title, 'department', coalesce(s.department, ''), 'amount', s.amount, 'students', s.students,
                                          'outcome', coalesce(s.outcome, ''), 'status', s.status, 'year', s.year) order by s.year desc, s.created_at desc)
      from sponsorships s join sponsors sp on sp.id = s.sponsor_id
    ), '[]'::jsonb)
  );
end $$;

revoke all on function direction_dashboard(), direction_departments(), direction_department_detail(uuid), direction_activity(text, uuid, int), direction_performance(),
  direction_people(text, uuid, int), direction_finance_summary(int), direction_consolidated_report(date, date), direction_dept_partnerships(uuid), direction_sponsors_report() from public, anon;
grant execute on function direction_dashboard(), direction_departments(), direction_department_detail(uuid), direction_activity(text, uuid, int), direction_performance(),
  direction_people(text, uuid, int), direction_finance_summary(int), direction_consolidated_report(date, date), direction_dept_partnerships(uuid), direction_sponsors_report() to authenticated;
