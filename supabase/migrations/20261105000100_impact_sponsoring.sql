-- Impact et sponsoring (écrans 105, 107, 237, 238, 239) : données définies et mesurables, aucune valeur inventée.
--  * le vendeur déclare si un produit est issu de matériaux récupérés et son poids (kg) : seule base du « déchets valorisés » ;
--  * l'impact de la plateforme et celui d'une personne sont CALCULÉS sur les commandes payées et les missions livrées ;
--  * le sponsoring est saisi par la gestion (sponsors, contributions) ; le rapport d'un sponsor est lisible par lui et par la gestion ;
--  * les créations d'autres établissements sont les annonces publiées dont le vendeur appartient à un autre établissement.
-- Aucun facteur de conversion en CO₂ n'est appliqué : sans méthode validée, ce chiffre n'est pas produit.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale (supabase/tests/impact_sponsoring_local.sql).
-- Retour arrière : drop function platform_impact(), my_impact(), sponsor_report(uuid), sponsor_create(text, uuid), sponsorship_add(uuid, text, text, int, int, text, text, int), listings_other_institutions(int);
--   drop table sponsorships, sponsors; alter table listings drop column recycled, drop column recycled_kg;

alter table listings add column if not exists recycled boolean not null default false;
alter table listings add column if not exists recycled_kg numeric(8, 2) check (recycled_kg is null or recycled_kg >= 0);
grant insert (recycled, recycled_kg), update (recycled, recycled_kg) on listings to authenticated;

create table if not exists sponsors (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  owner_id uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists sponsors_name_key on sponsors (lower(name));

create table if not exists sponsorships (
  id uuid primary key default gen_random_uuid(),
  sponsor_id uuid not null references sponsors(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 160),
  department text,
  amount integer not null default 0 check (amount >= 0),
  students integer not null default 0 check (students >= 0),
  outcome text check (outcome is null or char_length(outcome) <= 200),
  status text not null default 'en_cours' check (status in ('en_cours', 'termine')),
  year integer not null default extract(year from now())::int,
  created_at timestamptz not null default now()
);
create index if not exists sponsorships_sponsor on sponsorships (sponsor_id, year desc);

alter table sponsors enable row level security;
alter table sponsorships enable row level security;
revoke all on sponsors, sponsorships from anon, authenticated;
grant select on sponsors, sponsorships to authenticated;
drop policy if exists "sponsors : propriétaire ou gestion" on sponsors;
create policy "sponsors : propriétaire ou gestion" on sponsors for select using (owner_id = auth.uid() or is_platform_staff());
drop policy if exists "contributions : propriétaire du sponsor ou gestion" on sponsorships;
create policy "contributions : propriétaire du sponsor ou gestion" on sponsorships for select
  using (is_platform_staff() or exists (select 1 from sponsors s where s.id = sponsor_id and s.owner_id = auth.uid()));

-- Impact de la plateforme : agrégats publics, sans donnée personnelle.
create or replace function platform_impact() returns jsonb
language sql stable security definer set search_path = public as $$
  with paid as (
    select o.id, o.created_at, o.subtotal, l.seller_id, coalesce(p.city, '') as city, ol.qty, l.recycled_kg
    from orders o
    join order_lines ol on ol.order_id = o.id
    left join listings l on l.id = ol.listing_id
    left join profiles p on p.id = l.seller_id
    where o.paid and o.cancelled_at is null
  )
  select jsonb_build_object(
    'students_paid', (select count(distinct seller_id)::int from paid where seller_id is not null),
    'revenue_paid', (select coalesce(sum(subtotal), 0)::bigint from (select distinct id, subtotal from paid) x),
    'orders_paid', (select count(distinct id)::int from paid),
    'missions_delivered', (select count(*)::int from missions where status = 'delivered'),
    'recycled_kg', (select coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) from paid where recycled_kg is not null),
    'cities', (select coalesce(jsonb_agg(jsonb_build_object('city', city, 'orders', n, 'students', s) order by n desc), '[]'::jsonb)
               from (select city, count(distinct id)::int n, count(distinct seller_id)::int s from paid where city <> '' group by city) c)
  );
$$;

-- Impact de la personne connectée : ses achats payés auprès d'étudiants, et le poids de matériaux récupérés qu'ils représentent.
create or replace function my_impact() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return (
    with mine as (
      select o.id, o.created_at, o.subtotal, l.seller_id, ol.qty, l.recycled_kg
      from orders o join order_lines ol on ol.order_id = o.id left join listings l on l.id = ol.listing_id
      where o.buyer_id = auth.uid() and o.paid and o.cancelled_at is null
    )
    select jsonb_build_object(
      'purchases', (select count(distinct id)::int from mine),
      'amount', (select coalesce(sum(subtotal), 0)::bigint from (select distinct id, subtotal from mine) x),
      'students_supported', (select count(distinct seller_id)::int from mine where seller_id is not null),
      'recycled_kg', (select coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) from mine where recycled_kg is not null),
      'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'recycled_kg', kg) order by m), '[]'::jsonb)
                 from (select to_char(date_trunc('month', created_at), 'YYYY-MM') m, coalesce(sum(qty * recycled_kg), 0)::numeric(12, 2) kg
                       from mine where created_at >= date_trunc('month', now()) - interval '5 months' group by 1) t)
    )
  );
end $$;

-- Rapport d'un sponsor : total, étudiants et liste des contributions (lecture réservée au sponsor et à la gestion).
create or replace function sponsor_report(p_sponsor uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s sponsors;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from sponsors where id = p_sponsor;
  if s.id is null or not (s.owner_id = auth.uid() or is_platform_staff()) then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object(
    'sponsor', s.name,
    'total', (select coalesce(sum(amount), 0)::bigint from sponsorships where sponsor_id = s.id),
    'students', (select coalesce(sum(students), 0)::int from sponsorships where sponsor_id = s.id),
    'projects', (select coalesce(jsonb_agg(jsonb_build_object('title', title, 'department', coalesce(department, ''), 'amount', amount, 'students', students, 'outcome', coalesce(outcome, ''), 'status', status, 'year', year) order by year desc, created_at desc), '[]'::jsonb)
                 from sponsorships where sponsor_id = s.id)
  );
end $$;

create or replace function sponsor_create(p_name text, p_owner uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  insert into sponsors (name, owner_id) values (trim(p_name), p_owner) returning id into v_id;
  return v_id;
end $$;

create or replace function sponsorship_add(p_sponsor uuid, p_title text, p_department text, p_amount int, p_students int, p_outcome text, p_status text default 'en_cours', p_year int default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  insert into sponsorships (sponsor_id, title, department, amount, students, outcome, status, year)
  values (p_sponsor, trim(p_title), nullif(trim(coalesce(p_department, '')), ''), greatest(coalesce(p_amount, 0), 0), greatest(coalesce(p_students, 0), 0), nullif(trim(coalesce(p_outcome, '')), ''),
          case when p_status = 'termine' then 'termine' else 'en_cours' end, coalesce(p_year, extract(year from now())::int))
  returning id into v_id;
  return v_id;
end $$;

-- Créations des autres établissements : annonces publiées dont le vendeur est rattaché à un établissement différent de celui de la personne.
create or replace function listings_other_institutions(p_limit int default 20) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title, 'price', t.price, 'department', coalesce(t.department, ''), 'institution', t.institution, 'image', t.image) order by t.created_at desc), '[]'::jsonb)
  from (
    select l.id, l.title, l.price, l.department, l.created_at, p.institution, coalesce(l.images[1], l.image_url) as image
    from listings l join profiles p on p.id = l.seller_id
    where l.status = 'approved' and l.seller_id is not null and coalesce(trim(p.institution), '') <> ''
      and (auth.uid() is null or lower(p.institution) <> lower(coalesce((select institution from profiles where id = auth.uid()), '')))
    order by l.created_at desc limit least(greatest(p_limit, 1), 50)
  ) t;
$$;

revoke all on function platform_impact(), my_impact(), sponsor_report(uuid), sponsor_create(text, uuid), sponsorship_add(uuid, text, text, int, int, text, text, int), listings_other_institutions(int) from public, anon;
grant execute on function platform_impact(), listings_other_institutions(int) to anon, authenticated;
grant execute on function my_impact(), sponsor_report(uuid), sponsor_create(text, uuid), sponsorship_add(uuid, text, text, int, int, text, text, int) to authenticated;
