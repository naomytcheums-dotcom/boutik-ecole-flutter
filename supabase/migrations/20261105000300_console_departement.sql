-- Console du département (écrans 109 Étudiants et vendeurs, 112 Statistiques) : chiffres réels calculés sur les annonces et les
-- commandes payées. Portée : un responsable de département voit son département ; direction, administrateur et support voient tout.
-- Lecture seule. NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale (supabase/tests/console_departement_local.sql).
-- Retour arrière : drop function dept_students(int), dept_stats();

create or replace function _dept_scope() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); d uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  if r = 'dept' then
    select department_id into d from profiles where id = auth.uid();
    return coalesce(d, '00000000-0000-0000-0000-000000000000'::uuid);   -- aucun département renseigné : aucune ligne
  end if;
  return null;   -- null : tout l'établissement
end $$;
revoke all on function _dept_scope() from public, anon, authenticated;

create or replace function dept_students(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare scope uuid := _dept_scope();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', t.name, 'department', coalesce(t.department, ''), 'role', t.role, 'listings', t.listings, 'sales', t.sales, 'verified', t.verified
    ) order by t.name)
    from (
      select p.name, p.department, p.role::text as role, p.certification::text = 'approved' as verified,
             (select count(*)::int from listings l where l.seller_id = p.id and l.status = 'approved') as listings,
             (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = p.id and o.paid and o.cancelled_at is null) as sales
      from profiles p
      where p.role::text = 'student' and (scope is null or p.department_id = scope)
      order by p.name limit least(greatest(p_limit, 1), 200)
    ) t
  ), '[]'::jsonb);
end $$;

create or replace function dept_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare scope uuid := _dept_scope();
begin
  return (
    with lines as (
      select o.id as order_id, o.created_at, ol.unit_price * ol.qty as amount, l.category
      from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
      where o.paid and o.cancelled_at is null and (scope is null or p.department_id = scope)
    )
    select jsonb_build_object(
      'revenue', (select coalesce(sum(amount), 0)::bigint from lines),
      'orders', (select count(distinct order_id)::int from lines),
      'avg_basket', (select coalesce((sum(amount) / nullif(count(distinct order_id), 0))::bigint, 0) from lines),
      'services_revenue', (select coalesce(sum(amount) filter (where category = 'Services'), 0)::bigint from lines),
      'weeks', (select coalesce(jsonb_agg(jsonb_build_object('week', w, 'revenue', r) order by w), '[]'::jsonb)
                from (select to_char(date_trunc('week', created_at), 'YYYY-MM-DD') w, sum(amount)::bigint r from lines
                      where created_at >= date_trunc('week', now()) - interval '7 weeks' group by 1) x)
    )
  );
end $$;

revoke all on function dept_students(int), dept_stats() from public, anon;
grant execute on function dept_students(int), dept_stats() to authenticated;
