-- Lot H2 « Département » (6/6) : rapport sponsors (écran 239) lisible du département pour SES contributions seulement.
-- Un sponsor (et ses contributions) n'est visible d'un compte dept que s'il finance son département (nom exact) ; le rapport ne totalise que ces lignes.
-- Retour arrière : recréer les politiques « sponsors : propriétaire ou gestion » et « contributions : propriétaire du sponsor ou gestion » (20261105000100)
--   et sponsor_report (20261105000100).

-- Aide security definer : lit les contributions sans repasser par leur politique (évite la récursion sponsors <-> sponsorships).
create or replace function _sponsor_dept_sees(p_sponsor uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from sponsorships s where s.sponsor_id = p_sponsor and _dept_sees_name(s.department))
$$;
revoke all on function _sponsor_dept_sees(uuid) from public, anon, authenticated;
grant execute on function _sponsor_dept_sees(uuid) to anon, authenticated;

drop policy if exists "sponsors : propriétaire ou gestion" on sponsors;
create policy "sponsors : propriétaire ou gestion" on sponsors for select
  using (owner_id = auth.uid() or is_platform_staff() or _sponsor_dept_sees(id));

drop policy if exists "contributions : propriétaire du sponsor ou gestion" on sponsorships;
create policy "contributions : propriétaire du sponsor ou gestion" on sponsorships for select
  using (is_platform_staff() or _dept_sees_name(department) or exists (select 1 from sponsors s where s.id = sponsor_id and s.owner_id = auth.uid()));

create or replace function sponsor_report(p_sponsor uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s sponsors; v_all boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from sponsors where id = p_sponsor;
  v_all := s.id is not null and (coalesce(s.owner_id = auth.uid(), false) or is_platform_staff());   -- owner_id nul : jamais de NULL dans le contrôle (l'ancienne version laissait passer)
  if s.id is null or not (v_all or exists (select 1 from sponsorships x where x.sponsor_id = s.id and _dept_sees_name(x.department))) then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object(
    'sponsor', s.name,
    'total', (select coalesce(sum(amount), 0)::bigint from sponsorships where sponsor_id = s.id and (v_all or _dept_sees_name(department))),
    'students', (select coalesce(sum(students), 0)::int from sponsorships where sponsor_id = s.id and (v_all or _dept_sees_name(department))),
    'projects', (select coalesce(jsonb_agg(jsonb_build_object('title', title, 'department', coalesce(department, ''), 'amount', amount, 'students', students, 'outcome', coalesce(outcome, ''), 'status', status, 'year', year) order by year desc, created_at desc), '[]'::jsonb)
                 from sponsorships where sponsor_id = s.id and (v_all or _dept_sees_name(department)))
  );
end $$;


