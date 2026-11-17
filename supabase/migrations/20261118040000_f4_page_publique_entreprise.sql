-- Lot F4 (1/3) : page publique d'une entreprise (E4-18, E6-1, E5-12).
-- Avant : company_public renvoyait la fiche (même brouillon, refusée ou en attente) à tout connecté ; company_profile_view montrait la fiche brouillon/refusée
-- à tout connecté, ses chiffres comptaient aussi les besoins attribués, et rien dans l'application ne les appelait.
-- Après (une seule règle, _company_page) :
--   · une fiche n'est visible des autres que si elle est APPROUVÉE (et son titulaire non suspendu) ; sinon la fonction répond null, comme pour une fiche inexistante ;
--   · le propriétaire, ses membres actifs et l'administration/le support voient aussi les fiches non approuvées (avec leur statut) ;
--   · jamais RCCM, téléphone, interlocuteur, motif de refus, identité de facturation ni pièces ;
--   · compteurs réels : offres ouvertes, besoins ouverts (publiés), défis ouverts, recrutés ;
--   · company_public (connectés ET visiteurs) : fiche approuvée seulement, sans la liste des besoins (réservée aux connectés, comme open_needs_list).
-- Retour arrière : recréer company_public (20261114002500) et company_profile_view (20261114003300) ; drop function _company_page(uuid).

create or replace function _company_page(p_owner uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); c company_profiles%rowtype; v_mine boolean := false; v_staff boolean := false; v_all boolean;
begin
  if p_owner is null then return null; end if;
  select * into c from company_profiles where owner_id = p_owner;
  if not found then return null; end if;
  if v_uid is not null then
    v_mine := v_uid = p_owner or company_role_of(p_owner) is not null;
    v_staff := coalesce(current_role_name()::text, '') in ('admin', 'support');
  end if;
  if not (v_mine or v_staff) then
    if c.status <> 'approved' then return null; end if;
    if exists (select 1 from profiles where id = p_owner and coalesce(suspended, false)) then return null; end if;
  end if;
  v_all := v_uid is not null;
  return jsonb_build_object(
    'owner_id', c.owner_id, 'company_name', c.company_name, 'sector', c.sector, 'size', c.size, 'city', c.city, 'website', c.website,
    'description', c.description, 'founded_year', c.founded_year, 'logo_path', c.logo_path, 'cover_path', c.cover_path,
    'verified', c.status = 'approved', 'status', case when v_mine or v_staff then c.status else null end, 'mine', v_mine,
    'offers', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'title', o.title, 'kind', o.kind, 'location', o.location, 'deadline', o.deadline) order by o.created_at desc)
                        from (select * from opportunities where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date) order by created_at desc limit 20) o), '[]'::jsonb),
    'contests', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'kind', a.kind, 'deadline', a.deadline) order by a.created_at desc)
                          from (select * from contest_announcements where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date) order by created_at desc limit 20) a), '[]'::jsonb),
    'needs', case when v_all then coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'title', n.title, 'budget_min', n.budget_min, 'budget_max', n.budget_max, 'deadline', n.deadline) order by n.created_at desc)
                          from (select * from missions where client_id = p_owner and status = 'published' and title is not null and kind is distinct from 'mission' order by created_at desc limit 20) n), '[]'::jsonb) else null end,
    'offers_open', (select count(*)::int from opportunities where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date)),
    'contests_open', (select count(*)::int from contest_announcements where poster_id = p_owner and status = 'published' and (deadline is null or deadline >= current_date)),
    'needs_open', case when v_all then (select count(*)::int from missions where client_id = p_owner and status = 'published' and title is not null and kind is distinct from 'mission') else null end,
    'recruits', (select count(*)::int from opportunity_applications x join opportunities o on o.id = x.opportunity_id where o.poster_id = p_owner and x.status = 'hired')
  );
end $$;
revoke all on function _company_page(uuid) from public, anon, authenticated;

-- Fiche publique : connectés et visiteurs, fiches approuvées seulement (le propriétaire, ses membres et l'administration voient aussi les autres).
create or replace function company_public(p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select _company_page(p_owner)
$$;

-- Vue du profil (connecté) : la sienne par défaut ; mêmes règles de visibilité.
create or replace function company_profile_view(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return _company_page(coalesce(p_owner, auth.uid()));
end $$;

revoke all on function company_public(uuid), company_profile_view(uuid) from public, anon;
grant execute on function company_public(uuid) to anon, authenticated;
grant execute on function company_profile_view(uuid) to authenticated;
