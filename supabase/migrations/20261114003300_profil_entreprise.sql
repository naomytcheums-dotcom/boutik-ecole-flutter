-- Profil public de l'entreprise : couverture, chiffres et publications en cours (offres, concours, besoins).
-- Ne touche à aucune fonction existante : une colonne et deux fonctions nouvelles.
alter table company_profiles add column if not exists cover_path text check (cover_path is null or char_length(cover_path) between 5 and 300);

-- Couverture : propriétaire ou administrateur de l'entreprise ; le fichier doit être dans le dossier de la personne qui l'envoie.
create or replace function company_cover_set(p_path text, p_owner uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner);
begin
  if company_role_of(v_owner) not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  if nullif(p_path, '') is not null and split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Image invalide : déposez-la d''abord dans votre dossier'; end if;
  update company_profiles set cover_path = nullif(p_path, ''), updated_at = now() where owner_id = v_owner;
end $$;

-- Vue du profil : fiche publique (jamais les pièces, le numéro ni l'interlocuteur) + publications en cours.
create or replace function company_profile_view(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := coalesce(p_owner, auth.uid()); c company_profiles%rowtype; v_mine boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  if not found then return null; end if;
  v_mine := v_owner = auth.uid() or company_role_of(v_owner) is not null;
  return jsonb_build_object(
    'owner_id', c.owner_id, 'company_name', c.company_name, 'sector', c.sector, 'size', c.size, 'city', c.city, 'website', c.website,
    'description', c.description, 'founded_year', c.founded_year, 'logo_path', c.logo_path, 'cover_path', c.cover_path,
    'verified', c.status = 'approved', 'status', case when v_mine then c.status else null end, 'mine', v_mine,
    'offers', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'title', o.title, 'kind', o.kind, 'location', o.location, 'deadline', o.deadline) order by o.created_at desc)
                        from (select * from opportunities where poster_id = v_owner and status = 'published' order by created_at desc limit 20) o), '[]'::jsonb),
    'contests', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'kind', a.kind, 'deadline', a.deadline) order by a.created_at desc)
                          from (select * from contest_announcements where poster_id = v_owner and status = 'published' order by created_at desc limit 20) a), '[]'::jsonb),
    'needs_open', (select count(*) from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress')),
    'recruits', (select count(*) from opportunity_applications x join opportunities o on o.id = x.opportunity_id where o.poster_id = v_owner and x.status = 'hired')
  );
end $$;

revoke all on function company_cover_set(text, uuid), company_profile_view(uuid) from public, anon;
grant execute on function company_cover_set(text, uuid), company_profile_view(uuid) to authenticated;
