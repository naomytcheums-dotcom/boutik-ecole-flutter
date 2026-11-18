-- Lot H2 « Département » (2/6) : identité du département (fiche éditable par ses responsables), vue d'ensemble et annuaire des comptes cloisonnés.
-- Retour arrière : drop function dept_identity_get(uuid), dept_identity_save(jsonb, uuid) ; drop table department_profiles ;
--   recréer platform_overview (20261117010000), admin_users (20261105000200), admin_departments (20261117010000).

create table if not exists department_profiles (
  department_id uuid primary key references departments(id) on delete cascade,
  description text not null default '' check (char_length(description) <= 2000),
  mission text not null default '' check (char_length(mission) <= 1000),
  programs text[] not null default '{}' check (cardinality(programs) <= 20),
  head_name text not null default '' check (char_length(head_name) <= 120),
  contact_email text not null default '' check (char_length(contact_email) <= 120),
  contact_phone text not null default '' check (char_length(contact_phone) <= 30),
  address text not null default '' check (char_length(address) <= 200),
  website text not null default '' check (char_length(website) <= 200),
  contact_public boolean not null default false,
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table department_profiles enable row level security;
drop policy if exists "fiche département : responsables et administration" on department_profiles;
create policy "fiche département : responsables et administration" on department_profiles for select
  using (coalesce(current_role_name()::text, '') in ('admin', 'direction') or _dept_sees_dept(department_id));
revoke all on department_profiles from public, anon, authenticated;
grant select on department_profiles to authenticated;

create or replace function dept_identity_get(p_department uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments; i institutions; f department_profiles;
begin
  if v is null then raise exception 'Indiquez le département'; end if;
  select * into d from departments where id = v;
  if d.id is null then raise exception 'Département introuvable'; end if;
  select * into i from institutions where id = d.institution_id;
  select * into f from department_profiles where department_id = v;
  return jsonb_build_object(
    'department_id', d.id, 'name', d.name, 'status', d.status, 'institution', coalesce(i.name, ''), 'city', coalesce(i.city, ''),
    'description', coalesce(f.description, ''), 'mission', coalesce(f.mission, ''), 'programs', to_jsonb(coalesce(f.programs, '{}'::text[])),
    'head_name', coalesce(f.head_name, ''), 'contact_email', coalesce(f.contact_email, ''), 'contact_phone', coalesce(f.contact_phone, ''),
    'address', coalesce(f.address, ''), 'website', coalesce(f.website, ''), 'contact_public', coalesce(f.contact_public, false), 'updated_at', f.updated_at,
    'accounts', coalesce((select jsonb_agg(jsonb_build_object('name', p.name, 'title', a.title) order by p.name)
                          from department_accounts a join profiles p on p.id = a.user_id where a.department_id = v and p.role::text = 'dept' and not coalesce(p.suspended, false)), '[]'::jsonb));
end $$;

create or replace function dept_identity_save(p jsonb, p_department uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v uuid := _dept_pick(p_department); d departments;
  v_desc text; v_mission text; v_head text; v_mail text; v_phone text; v_addr text; v_web text; v_programs text[];
begin
  if v is null then raise exception 'Indiquez le département'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if p is null or jsonb_typeof(p) <> 'object' then raise exception 'Fiche invalide'; end if;
  select * into d from departments where id = v;
  if d.id is null then raise exception 'Département introuvable'; end if;
  v_desc := btrim(coalesce(p->>'description', ''));
  v_mission := btrim(coalesce(p->>'mission', ''));
  v_head := btrim(coalesce(p->>'head_name', ''));
  v_mail := lower(btrim(coalesce(p->>'contact_email', '')));
  v_phone := btrim(coalesce(p->>'contact_phone', ''));
  v_addr := btrim(coalesce(p->>'address', ''));
  v_web := btrim(coalesce(p->>'website', ''));
  if char_length(v_desc) > 2000 then raise exception 'Présentation : 2000 caractères au plus'; end if;
  if char_length(v_mission) > 1000 then raise exception 'Mission : 1000 caractères au plus'; end if;
  if char_length(v_head) > 120 then raise exception 'Nom du responsable : 120 caractères au plus'; end if;
  if v_mail <> '' and (char_length(v_mail) > 120 or v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') then raise exception 'Adresse e-mail invalide'; end if;
  if v_phone <> '' and (char_length(v_phone) > 30 or v_phone !~ '^[0-9+()\s.-]{6,30}$') then raise exception 'Numéro de téléphone invalide'; end if;
  if char_length(v_addr) > 200 then raise exception 'Adresse : 200 caractères au plus'; end if;
  if v_web <> '' and (char_length(v_web) > 200 or v_web !~* '^https://\S{3,}$') then raise exception 'Site web : une adresse commençant par https:// est attendue'; end if;
  if p ? 'programs' then
    if jsonb_typeof(p->'programs') <> 'array' then raise exception 'Filières invalides'; end if;
    select coalesce(array_agg(x), '{}'::text[]) into v_programs
    from (select distinct btrim(e) x from jsonb_array_elements_text(p->'programs') e where char_length(btrim(e)) between 2 and 80 limit 20) t;
  end if;
  insert into department_profiles (department_id, description, mission, programs, head_name, contact_email, contact_phone, address, website, contact_public, updated_by, updated_at)
  values (v, v_desc, v_mission, coalesce(v_programs, '{}'), v_head, v_mail, v_phone, v_addr, v_web, coalesce((p->>'contact_public')::boolean, false), auth.uid(), now())
  on conflict (department_id) do update set description = excluded.description, mission = excluded.mission,
    programs = case when p ? 'programs' then excluded.programs else department_profiles.programs end,
    head_name = excluded.head_name, contact_email = excluded.contact_email, contact_phone = excluded.contact_phone, address = excluded.address, website = excluded.website,
    contact_public = excluded.contact_public, updated_by = auth.uid(), updated_at = now();
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Responsable'), auth.uid(), 'Identité du département mise à jour', left(d.name, 200), 'Départements', 'Info');
end $$;

revoke all on function dept_identity_get(uuid), dept_identity_save(jsonb, uuid) from public, anon;
grant execute on function dept_identity_get(uuid), dept_identity_save(jsonb, uuid) to authenticated;

-- ============================== Annuaires et vues d'ensemble cloisonnés ==============================
-- Un responsable de département ne voit que les comptes étudiants de son département (et le sien) ; les autres rôles gardent leur périmètre.
create or replace function admin_users(p_roles text[] default null, p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  if r = 'dept' then v := coalesce(_dept_id(), '00000000-0000-0000-0000-000000000000'::uuid); end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', t.name, 'role', t.role, 'department', coalesce(t.department, ''), 'last_login', t.last_login, 'suspended', t.suspended,
      'students', t.students
    ) order by t.name)
    from (
      select p.name, p.role::text as role, p.department, u.last_sign_in_at as last_login, p.suspended,
             (select count(*)::int from profiles s where s.department_id is not null and s.department_id = p.department_id and s.role::text = 'student') as students
      from profiles p left join auth.users u on u.id = p.id
      where (p_roles is null or p.role::text = any (p_roles))
        and (r <> 'dept' or p.id = auth.uid() or (p.role::text = 'student' and p.department_id = v))
      order by p.name limit least(greatest(p_limit, 1), 200)
    ) t
  ), '[]'::jsonb);
end $$;

create or replace function admin_departments() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', d.id, 'name', d.name, 'institution', i.name, 'status', d.status,
      'students', (select count(*)::int from profiles p where p.department_id = d.id and is_verified_student(p.id)),
      'students_declared', (select count(*)::int from profiles p where p.department_id = d.id and p.role::text = 'student'),
      'head', (select string_agg(p.name, ', ' order by p.name) from profiles p where p.department_id = d.id and p.role::text = 'dept')
    ) order by i.name, d.name)
    from departments d join institutions i on i.id = d.institution_id
    where r <> 'dept' or d.id = _dept_id()
  ), '[]'::jsonb);
end $$;

create or replace function platform_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'admin', 'direction', 'support', 'finance') then raise exception 'Action non autorisée'; end if;
  if r = 'dept' then
    v := coalesce(_dept_id(), '00000000-0000-0000-0000-000000000000'::uuid);
    return jsonb_build_object(
      'students', (select count(*)::int from profiles p where p.department_id = v and is_verified_student(p.id)),
      'students_declared', (select count(*)::int from profiles p where p.department_id = v and p.role::text = 'student'),
      'sellers', (select count(distinct l.seller_id)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = v and l.status = 'approved'),
      'listings_approved', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = v and l.status = 'approved'),
      'listings_pending', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = v and l.status = 'pending'),
      'orders', (select count(distinct o.id)::int from orders o join order_lines ol on ol.order_id = o.id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id where p.department_id = v),
      'orders_paid', (select count(distinct o.id)::int from orders o join order_lines ol on ol.order_id = o.id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
                      where p.department_id = v and o.paid and o.cancelled_at is null),
      'paid_revenue', (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from orders o join order_lines ol on ol.order_id = o.id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
                       where p.department_id = v and o.paid and o.cancelled_at is null)
    );
  end if;
  return jsonb_build_object(
    'students', (select count(*)::int from profiles where is_verified_student(id)),
    'students_declared', (select count(*)::int from profiles where role::text = 'student'),
    'sellers', (select count(distinct seller_id)::int from listings where seller_id is not null and status = 'approved'),
    'listings_approved', (select count(*)::int from listings where status = 'approved'),
    'listings_pending', (select count(*)::int from listings where status = 'pending'),
    'orders', (select count(*)::int from orders),
    'orders_paid', (select count(*)::int from orders where paid and cancelled_at is null),
    'paid_revenue', (select coalesce(sum(subtotal + fee), 0)::bigint from orders where paid and cancelled_at is null)
  );
end $$;
