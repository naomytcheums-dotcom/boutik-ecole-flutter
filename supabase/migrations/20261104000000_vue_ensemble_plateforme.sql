-- Vue d'ensemble de la plateforme (écran 108, tableau de bord du département) : chiffres réels, réservés au personnel.
-- NON APPLIQUÉE en production : testée sur la base locale isolée (supabase/tests/vue_ensemble_local.sql).
-- Lecture seule ; aucune donnée n'est modifiée. Retour arrière : drop function platform_overview().

create or replace function platform_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'direction', 'support', 'finance') then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object(
    'students', (select count(*)::int from profiles where role::text = 'student'),
    'sellers', (select count(distinct seller_id)::int from listings where seller_id is not null and status = 'approved'),
    'listings_approved', (select count(*)::int from listings where status = 'approved'),
    'listings_pending', (select count(*)::int from listings where status = 'pending'),
    'orders', (select count(*)::int from orders),
    'orders_paid', (select count(*)::int from orders where paid and cancelled_at is null),
    'paid_revenue', (select coalesce(sum(subtotal + fee), 0)::bigint from orders where paid and cancelled_at is null)
  );
end $$;
revoke all on function platform_overview() from public, anon;
grant execute on function platform_overview() to authenticated;
