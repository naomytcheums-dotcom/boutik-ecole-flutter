-- Tableau de bord par offre : vues, personnes distinctes, favoris, candidatures, taux de réponse et recrutements.
-- Une vue = une personne qui ouvre l'offre, comptée une fois par jour ; l'auteur de l'offre n'est jamais compté.
create table if not exists opportunity_views (
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  viewer_id uuid not null references profiles(id) on delete cascade,
  day date not null default current_date,
  primary key (opportunity_id, viewer_id, day)
);
create index if not exists opportunity_views_opp on opportunity_views (opportunity_id, day);
alter table opportunity_views enable row level security;
revoke all on opportunity_views from anon, authenticated;

create or replace function opp_view_track(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if not exists (select 1 from opportunities where id = p_id and status = 'published' and poster_id <> auth.uid()) then return; end if;
  insert into opportunity_views (opportunity_id, viewer_id) values (p_id, auth.uid()) on conflict do nothing;
end $$;

-- Statistiques d'une offre (son auteur seulement) ; p_id null : toutes ses offres, une ligne par offre.
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
    from opportunities o where o.poster_id = auth.uid() and (p_id is null or o.id = p_id)), '[]'::jsonb);
end $$;

revoke all on function opp_view_track(uuid), opp_stats(uuid) from public, anon;
grant execute on function opp_view_track(uuid), opp_stats(uuid) to authenticated;
