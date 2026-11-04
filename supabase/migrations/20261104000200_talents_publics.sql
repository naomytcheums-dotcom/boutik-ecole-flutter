-- Talents à découvrir (accueil, recherche de talents) : fiches lues sur les VRAIS profils étudiants qui ont renseigné
-- des compétences. Lecture seule ; aucune donnée n'est modifiée. Réservé aux comptes connectés.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale isolée (supabase/tests/talents_local.sql).
-- Retour arrière : drop function talents_list(text, int);

create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'department', coalesce(t.department, ''), 'institution', coalesce(t.institution, ''),
                                        'skills', coalesce(t.skills, ''), 'city', coalesce(t.city, ''), 'avatar_url', t.avatar_url, 'certified', t.certification::text = 'approved'))
    from (
      select * from profiles
      where role::text = 'student' and not suspended and nullif(trim(coalesce(skills, '')), '') is not null
        and (coalesce(trim(p_query), '') = '' or name ilike '%' || trim(p_query) || '%' or skills ilike '%' || trim(p_query) || '%' or coalesce(department, '') ilike '%' || trim(p_query) || '%')
      order by (certification::text = 'approved') desc, created_at desc
      limit least(greatest(p_limit, 1), 50)
    ) t
  ), '[]'::jsonb);
end $$;
revoke all on function talents_list(text, int) from public, anon;
grant execute on function talents_list(text, int) to authenticated;
