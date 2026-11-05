-- Console d'administration de l'établissement (écrans 119 Départements, 120 Utilisateurs, 121 Responsables) : listes réelles,
-- réservées à la gestion (responsable de département, direction, administrateur, support). Lecture seule, aucune donnée de mot de passe.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale (supabase/tests/console_administration_local.sql).
-- Retour arrière : drop function admin_departments(), admin_users(text[], int);

create or replace function admin_departments() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', d.name, 'institution', i.name, 'status', d.status,
      'students', (select count(*)::int from profiles p where p.department_id = d.id and p.role::text = 'student'),
      'head', (select string_agg(p.name, ', ' order by p.name) from profiles p where p.department_id = d.id and p.role::text = 'dept')
    ) order by i.name, d.name)
    from departments d join institutions i on i.id = d.institution_id
  ), '[]'::jsonb);
end $$;

-- Personnes de la plateforme avec leur rôle, leur département, leur dernière connexion et leur état (suspendu ou actif).
create or replace function admin_users(p_roles text[] default null, p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', t.name, 'role', t.role, 'department', coalesce(t.department, ''), 'last_login', t.last_login, 'suspended', t.suspended,
      'students', t.students
    ) order by t.name)
    from (
      select p.name, p.role::text as role, p.department, u.last_sign_in_at as last_login, p.suspended,
             (select count(*)::int from profiles s where s.department_id is not null and s.department_id = p.department_id and s.role::text = 'student') as students
      from profiles p left join auth.users u on u.id = p.id
      where p_roles is null or p.role::text = any (p_roles)
      order by p.name limit least(greatest(p_limit, 1), 200)
    ) t
  ), '[]'::jsonb);
end $$;

revoke all on function admin_departments(), admin_users(text[], int) from public, anon;
grant execute on function admin_departments(), admin_users(text[], int) to authenticated;
