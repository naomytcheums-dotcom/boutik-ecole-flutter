-- Lot F3b : écran 96 « Défis d'innovation » de l'entreprise. Lecture des concours et hackathons (annonces publiées ou clôturées) avec leur phase
-- (à venir, ouvert, terminé) pour de vrais filtres ; le détail s'ouvre sur la fiche existante (/concours/:id). Données publiques uniquement.
-- Retour arrière : drop function defis_list(integer);

create or replace function defis_list(p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(x.c order by x.ord, x.dl nulls last)
    from (
      select jsonb_build_object(
               'id', a.id, 'title', a.title, 'organizer', a.organizer, 'kind', a.kind, 'status', a.status, 'verified', a.verified,
               'opens_on', a.opens_on, 'deadline', a.deadline, 'results_on', a.results_on, 'prize_amount', a.prize_amount, 'reward', a.reward,
               'phase', case when a.status = 'closed' or (a.deadline is not null and a.deadline < current_date) then 'ended'
                             when a.opens_on is not null and a.opens_on > current_date then 'upcoming' else 'open' end) as c,
             case when a.status = 'closed' or (a.deadline is not null and a.deadline < current_date) then 2
                  when a.opens_on is not null and a.opens_on > current_date then 1 else 0 end as ord,
             a.deadline as dl
        from contest_announcements a
       where a.status in ('published', 'closed') and a.kind in ('contest', 'hackathon', 'call')
       order by a.created_at desc
       limit least(greatest(coalesce(p_limit, 100), 1), 200)
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function defis_list(integer) from public, anon;
grant execute on function defis_list(integer) to authenticated;
