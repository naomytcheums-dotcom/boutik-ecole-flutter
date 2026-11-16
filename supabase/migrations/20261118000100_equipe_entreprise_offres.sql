-- Profil Entreprise : l'équipe d'une entreprise (company_members) peut enfin travailler sur les offres du propriétaire.
-- Avant : opp_close, opp_application_decide, opp_media_set, opp_applications_for, opp_stats, opp_my_posted et opp_applications_received
-- ne reconnaissaient que le publicateur (poster_id = auth.uid()) : un administrateur, un responsable financier ou un lecteur d'équipe voyait
-- « Offre introuvable » pour les offres de son entreprise.
-- Règle : le propriétaire garde tous les droits ; un membre actif « admin » peut tout gérer (fermer, décider une candidature, changer le média) ;
-- « finance » et « viewer » peuvent seulement consulter (candidatures, statistiques, liste). La publication (opp_save), les invitations d'étudiants
-- (opp_invite) et les suggestions restent au propriétaire : elles dépendent de la vérification et du forfait de l'entreprise.
-- Retour arrière : recréer ces sept fonctions depuis leurs dernières définitions (20261114001300, 20261114003*, 20261115180*) ; drop function _opp_can(uuid, boolean).

create or replace function _opp_can(p_poster uuid, p_write boolean) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    p_poster = auth.uid()
    or exists (
      select 1 from company_members m join profiles me on me.id = m.user_id
      where m.owner_id = p_poster and m.user_id = auth.uid() and m.status = 'active' and not me.suspended
        and (m.role = 'admin' or (not coalesce(p_write, true) and m.role in ('finance', 'viewer')))))
$$;
revoke all on function _opp_can(uuid, boolean) from public, anon, authenticated;


-- opp_close : écriture ouverte à l'équipe
create or replace function opp_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update opportunities set status = 'closed' where id = p_id and (_opp_can(poster_id, true) or coalesce(current_role_name()::text, '') in ('admin', 'dept'));
  if not found then raise exception 'Offre introuvable'; end if;
end $$;


-- opp_application_decide : écriture ouverte à l'équipe
create or replace function opp_application_decide(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status not in ('viewed', 'shortlisted', 'rejected', 'hired') then raise exception 'Statut inconnu'; end if;
  select * into a from opportunity_applications where id = p_id;
  if not found then raise exception 'Candidature introuvable'; end if;
  select * into o from opportunities where id = a.opportunity_id and _opp_can(poster_id, true);
  if not found then raise exception 'Candidature introuvable'; end if;
  update opportunity_applications set status = p_status where id = p_id;
  if coalesce((select pf.results from opportunity_alert_prefs pf where pf.user_id = a.applicant_id), true) then
    perform notify_user(a.applicant_id, 'opportunity_application', case p_status when 'hired' then 'Félicitations !' when 'shortlisted' then 'Candidature retenue' when 'rejected' then 'Candidature non retenue' else 'Candidature consultée' end,
      o.org_name || ' : ' || left(o.title, 60), jsonb_build_object('opportunity', o.id, 'application', p_id));
  end if;
end $$;


-- opp_media_set : écriture ouverte à l'équipe
create or replace function opp_media_set(p_id uuid, p_path text, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from opportunities where id = p_id and _opp_can(poster_id, true)) then raise exception 'Offre introuvable'; end if;
  if nullif(p_path, '') is null then
    update opportunities set media_path = null, media_kind = null where id = p_id;
    return;
  end if;
  if p_kind not in ('image', 'video') then raise exception 'Format inconnu'; end if;
  if split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  update opportunities set media_path = p_path, media_kind = p_kind where id = p_id;
end $$;


-- opp_applications_for : lecture ouverte à l'équipe
create or replace function opp_applications_for(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  select * into o from opportunities where id = p_id and _opp_can(poster_id, false);
  if not found then raise exception 'Offre introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'applicant_id', a.applicant_id, 'name', display_name(a.applicant_id), 'department', pr.department, 'message', a.message, 'cv_link', a.cv_link,
      'status', a.status, 'created_at', a.created_at, 'match', _opp_match(o, a.applicant_id)) order by a.created_at desc)
    from opportunity_applications a join profiles pr on pr.id = a.applicant_id where a.opportunity_id = p_id), '[]'::jsonb);
end $$;


-- opp_stats : lecture ouverte à l'équipe
create or replace function opp_stats(p_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', o.id,
      'views', (select count(*)::int from opportunity_views v where v.opportunity_id = o.id),
      'viewers', (select count(distinct v.viewer_id)::int from opportunity_views v where v.opportunity_id = o.id),
      'views_7d', (select count(*)::int from opportunity_views v where v.opportunity_id = o.id and v.day >= current_date - 6),
      'saves', (select count(*)::int from opportunity_saves s where s.opportunity_id = o.id),
      'applications', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id),
      'answered', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id and a.status <> 'sent'),
      'shortlisted', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id and a.status in ('shortlisted', 'hired')),
      'hired', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id and a.status = 'hired'),
      'conversion', case when (select count(*) from opportunity_views v where v.opportunity_id = o.id) = 0 then null
                         else round(100.0 * (select count(*) from opportunity_applications a where a.opportunity_id = o.id) / (select count(distinct v.viewer_id) from opportunity_views v where v.opportunity_id = o.id), 1) end,
      'response_rate', case when (select count(*) from opportunity_applications a where a.opportunity_id = o.id) = 0 then null
                            else round(100.0 * (select count(*) from opportunity_applications a where a.opportunity_id = o.id and a.status <> 'sent') / (select count(*) from opportunity_applications a where a.opportunity_id = o.id), 0) end
    ) order by o.created_at desc)
    from opportunities o where _opp_can(o.poster_id, false) and (p_id is null or o.id = p_id)), '[]'::jsonb);
end $$;


-- opp_my_posted : lecture ouverte à l'équipe
create or replace function opp_my_posted() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(_opp_card(o, auth.uid()) || jsonb_build_object('applications', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id),
      'review_note', o.review_note, 'description', o.description, 'poster', display_name(o.poster_id)) order by (o.status = 'pending') desc, o.created_at desc)
    from opportunities o where _opp_can(o.poster_id, false) or (v_staff and o.status = 'pending')), '[]'::jsonb);
end $$;


-- opp_applications_received : lecture ouverte à l'équipe
create or replace function opp_applications_received(p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(z.j order by z.s desc, z.j->>'created_at' desc) from (
      select jsonb_build_object('id', a.id, 'opportunity_id', o.id, 'title', o.title, 'applicant_id', a.applicant_id, 'name', display_name(a.applicant_id), 'department', coalesce(pr.department, ''),
               'status', a.status, 'created_at', a.created_at, 'match', _opp_match(o, a.applicant_id)) j,
             coalesce((_opp_match(o, a.applicant_id)->>'score')::int, 0) s
      from opportunity_applications a join opportunities o on o.id = a.opportunity_id join profiles pr on pr.id = a.applicant_id
      where _opp_can(o.poster_id, false)
      order by a.created_at desc limit v_lim) z), '[]'::jsonb);
end $$;
