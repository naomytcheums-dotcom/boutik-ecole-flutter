-- Lot F1 (1/6) — lecture des talents : visibilité des étudiants pour les entreprises (E1-1, E1-2, E5-3, E5-4, E5-6 en partie, E5-8).
--   · _org_approved(uid) : l'organisation (rôle company ou other) a une fiche entreprise approuvée (ou compte de test) ;
--   · _viewer_class() : anon / suspended / staff (département, direction, administration, support) / org_ok / org_locked / other ;
--   · talents_search(p_query, p_filiere, p_skills, p_limit, p_offset) : jsonb { total, items[], locked, reason, limit, offset }.
--       - une entreprise ou organisation NON approuvée ne voit AUCUN talent nominatif (locked = true) ;
--       - une entreprise approuvée voit le nom ABRÉGÉ + filière + compétences ; le nom complet seulement si l'étudiant a publié le lien de son CV ;
--       - un étudiant qui a retiré « Me proposer aux recruteurs » (_talent_visible) n'apparaît jamais ; jamais de téléphone ni d'e-mail ;
--       - la recherche par nom porte sur le nom affiché (un nom complet ne peut pas être deviné par la recherche) ;
--       - p_skills : l'étudiant doit avoir TOUTES les compétences listées ; p_filiere : filière contenant le texte ;
--   · talents_list(p_query, p_limit) : même règles (ancien contrat, tableau d'éléments) ;
--   · _talent_guard() (vivier) : entreprise ou organisation approuvée, département, administration ; talent_lists_get / talent_list_members_get / talent_list_add
--     ne comptent et n'ajoutent que des étudiants encore visibles.
-- Retour arrière : recréer talents_list depuis 20261117991000, _talent_guard depuis 20261114003900, talent_list_add depuis 20261117080000,
--   talent_lists_get et talent_list_members_get depuis 20261114003900 ; drop function talents_search(text, text, text[], int, int), _viewer_class(), _org_approved(uuid).

create or replace function _org_approved(p_uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(p_uid is not null and (
      exists (select 1 from company_profiles c where c.owner_id = p_uid and c.status = 'approved')
      or exists (select 1 from profiles p where p.id = p_uid and p.is_test)), false)
$$;
revoke all on function _org_approved(uuid) from public, anon, authenticated;

create or replace function _viewer_class() returns text
language plpgsql stable security definer set search_path = public as $$
declare v_role text;
begin
  if auth.uid() is null then return 'anon'; end if;
  v_role := coalesce(current_role_name()::text, '');
  if v_role = '' then return 'suspended'; end if;
  if v_role in ('dept', 'direction', 'admin', 'support') then return 'staff'; end if;
  if v_role in ('company', 'other') then return case when _org_approved(auth.uid()) then 'org_ok' else 'org_locked' end; end if;
  return 'other';
end $$;
revoke all on function _viewer_class() from public, anon, authenticated;

-- Le lien de CV de l'étudiant est-il publié (consentement à montrer son nom complet) ?
create or replace function _cv_published(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from cv_links l where l.owner_id = p_user and l.revoked_at is null and (l.expires_at is null or l.expires_at > now()))
$$;
revoke all on function _cv_published(uuid) from public, anon, authenticated;

create or replace function talents_search(p_query text default '', p_filiere text default '', p_skills text[] default '{}', p_limit int default 20, p_offset int default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_class text;
  v_q text := replace(replace(replace(trim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_');
  v_f text := replace(replace(replace(trim(coalesce(p_filiere, '')), '\', '\\'), '%', '\%'), '_', '\_');
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_off int := least(greatest(coalesce(p_offset, 0), 0), 10000);
  v_skills text[];
  v_total int; v_items jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_class := _viewer_class();
  if v_class = 'suspended' then raise exception 'Compte suspendu : consultation des talents impossible'; end if;
  if v_class = 'org_locked' then
    return jsonb_build_object('total', 0, 'items', '[]'::jsonb, 'locked', true, 'limit', v_limit, 'offset', v_off,
      'reason', 'Votre entreprise doit être vérifiée par l''administrateur avant de consulter les talents : complétez votre fiche entreprise et envoyez vos pièces justificatives.');
  end if;
  select coalesce(array_agg(x), '{}') into v_skills from (
    select replace(replace(replace(trim(s), '\', '\\'), '%', '\%'), '_', '\_') x from unnest(coalesce(p_skills, '{}'::text[])) s
    where char_length(trim(s)) between 1 and 40 limit 10) t;

  with f as (
    select p.id, p.name, p.department, p.institution, p.skills, p.city, p.avatar_url, p.certification, p.cover_path, p.cover_kind, p.created_at,
           (v_class = 'staff' or (v_class = 'org_ok' and _cv_published(p.id))) as full_name
    from profiles p
    where p.role::text = 'student' and not coalesce(p.suspended, false) and nullif(trim(coalesce(p.skills, '')), '') is not null
      and is_verified_student(p.id) and profile_in_directory(p.id) and _talent_visible(p.id)
      and (v_f = '' or coalesce(p.department, '') ilike '%' || v_f || '%')
      and not exists (select 1 from unnest(v_skills) k where coalesce(p.skills, '') not ilike '%' || k || '%')
  ), g as (
    select f.*, case when f.full_name then f.name else _short_name(f.name) end as shown from f
  ), h as (
    select * from g where v_q = '' or shown ilike '%' || v_q || '%' or coalesce(skills, '') ilike '%' || v_q || '%' or coalesce(department, '') ilike '%' || v_q || '%'
  ), pg as (
    select h.*, row_number() over (order by (h.certification::text = 'approved') desc, h.created_at desc, h.id) as ord from h
    order by (h.certification::text = 'approved') desc, h.created_at desc, h.id limit v_limit offset v_off
  )
  select (select count(*)::int from h),
         coalesce((select jsonb_agg(jsonb_build_object('id', pg.id, 'name', pg.shown, 'name_full', pg.full_name,
                     'department', coalesce(pg.department, ''), 'institution', coalesce(pg.institution, ''), 'skills', coalesce(pg.skills, ''), 'city', coalesce(pg.city, ''),
                     'avatar_url', pg.avatar_url, 'certified', pg.certification::text = 'approved', 'cover_path', pg.cover_path, 'cover_kind', pg.cover_kind,
                     'cv_published', _cv_published(pg.id)) order by pg.ord) from pg), '[]'::jsonb)
    into v_total, v_items;
  return jsonb_build_object('total', v_total, 'items', v_items, 'locked', false, 'limit', v_limit, 'offset', v_off);
end $$;
revoke all on function talents_search(text, text, text[], int, int) from public, anon;
grant execute on function talents_search(text, text, text[], int, int) to authenticated;

-- Ancien contrat (tableau d'éléments) : mêmes règles de visibilité.
create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return talents_search(p_query, '', '{}'::text[], p_limit, 0) -> 'items';
end $$;
revoke all on function talents_list(text, int) from public, anon;
grant execute on function talents_list(text, int) to authenticated;

-- Vivier : entreprise ou organisation approuvée, département, administration.
create or replace function _talent_guard() returns void
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('company', 'other', 'dept', 'admin') then raise exception 'Réservé aux entreprises'; end if;
  if v_role in ('company', 'other') and not _org_approved(auth.uid()) then
    raise exception 'Votre entreprise doit être vérifiée par l''administrateur avant de constituer un vivier de talents.';
  end if;
end $$;
revoke all on function _talent_guard() from public, anon, authenticated;

-- Un étudiant devenu invisible, non vérifié ou suspendu n'est plus compté ni listé dans les viviers.
create or replace function _talent_listable(p_student uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_verified_student(p_student) and _talent_visible(p_student) and profile_in_directory(p_student)
$$;
revoke all on function _talent_listable(uuid) from public, anon, authenticated;

create or replace function talent_lists_get(p_student uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  insert into talent_lists (owner_id, name) values (auth.uid(), 'Favoris') on conflict do nothing;
  return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name,
      'count', (select count(*)::int from talent_list_members m where m.list_id = l.id and _talent_listable(m.student_id)),
      'has', case when p_student is null then null else exists (select 1 from talent_list_members m where m.list_id = l.id and m.student_id = p_student) end)
      order by (l.name = 'Favoris') desc, l.name)
    from talent_lists l where l.owner_id = auth.uid()), '[]'::jsonb);
end $$;

create or replace function talent_list_members_get(p_list uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _talent_guard();
  if not exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid()) then raise exception 'Liste introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.student_id, 'name', display_name(m.student_id), 'department', pr.department, 'note', m.note, 'added_at', m.added_at) order by m.added_at desc)
                   from talent_list_members m join profiles pr on pr.id = m.student_id where m.list_id = p_list and _talent_listable(m.student_id)), '[]'::jsonb);
end $$;

create or replace function talent_list_add(p_list uuid, p_student uuid, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  if not exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid()) then raise exception 'Liste introuvable'; end if;
  if not _talent_listable(p_student) then raise exception 'Étudiant introuvable'; end if;
  if (select count(*) from talent_list_members where list_id = p_list) >= 500 then raise exception '500 étudiants au plus par liste'; end if;
  insert into talent_list_members (list_id, student_id, note) values (p_list, p_student, left(btrim(coalesce(p_note, '')), 200))
  on conflict (list_id, student_id) do update set note = excluded.note;
end $$;

revoke all on function talent_lists_get(uuid), talent_list_members_get(uuid), talent_list_add(uuid, uuid, text) from public, anon;
grant execute on function talent_lists_get(uuid), talent_list_members_get(uuid), talent_list_add(uuid, uuid, text) to authenticated;
