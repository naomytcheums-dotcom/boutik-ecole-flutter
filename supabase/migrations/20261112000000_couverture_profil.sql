-- Couverture de profil : photo ou vidéo choisie par l'étudiant, affichée en fond de sa carte dans « Talents à découvrir ».
-- Non destructif : deux colonnes ajoutées, une fonction d'écriture, talents_list renvoie en plus la couverture.
-- Retour arrière : alter table profiles drop column cover_path, drop column cover_kind; drop function set_my_cover(text, text);
--                  (talents_list : rejouer 20261104000200_talents_publics.sql).

alter table profiles add column if not exists cover_path text;
alter table profiles add column if not exists cover_kind text;

create or replace function set_my_cover(p_path text, p_kind text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('image', 'video') then raise exception 'Type de couverture invalide'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  update profiles set cover_path = p_path, cover_kind = p_kind where id = auth.uid();
  return 'enregistrée';
end $$;
revoke all on function set_my_cover(text, text) from public, anon;
grant execute on function set_my_cover(text, text) to authenticated;

create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'department', coalesce(t.department, ''), 'institution', coalesce(t.institution, ''),
                                        'skills', coalesce(t.skills, ''), 'city', coalesce(t.city, ''), 'avatar_url', t.avatar_url, 'certified', t.certification::text = 'approved',
                                        'cover_path', t.cover_path, 'cover_kind', t.cover_kind))
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
