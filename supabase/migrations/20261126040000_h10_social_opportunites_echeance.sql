-- H10 SOCIAL : une offre dont la date limite est passée n'est jamais « active ».
-- Les listes publiques, la recherche et les rappels filtraient déjà ; restaient des compteurs (tableau de bord organisation, direction, département),
-- les « autres offres » de la fiche, l'activation d'un rappel sur une offre échue, et aucun indicateur « expirée » pour l'écran.
-- Ne modifie ni les forfaits ni leurs quotas (used_offers reste inchangé : décision du propriétaire).
-- Retour arrière : recréer _opp_card depuis 20261114003500 et les fonctions company_dashboard (20261120010100), direction_dashboard (20261120030200),
--   dept_overview (20261120020200), opp_detail (20261118010400), opp_remind (20261114001300).

-- La carte d'offre expose « expired » (date limite dépassée) et « open » (acceptant des candidatures) ; les autres clés sont inchangées.
create or replace function _opp_card(o opportunities, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', o.id, 'org', o.org_name, 'verified', o.verified, 'kind', o.kind, 'contract', o.contract, 'title', o.title, 'location', o.location, 'mode', o.mode, 'duration', o.duration,
    'pay_kind', o.pay_kind, 'pay_amount', o.pay_amount, 'pay_note', o.pay_note, 'deadline', o.deadline, 'skills', to_jsonb(o.skills), 'department_target', o.department_target, 'iut_only', o.iut_only,
    'status', o.status, 'created_at', o.created_at, 'logo', (select pr.avatar_url from profiles pr where pr.id = o.poster_id),
    'media_path', o.media_path, 'media_kind', o.media_kind,
    'expired', o.deadline is not null and o.deadline < current_date,
    'open', o.status = 'published' and (o.deadline is null or o.deadline >= current_date),
    'saved', exists (select 1 from opportunity_saves s where s.opportunity_id = o.id and s.user_id = p_user),
    'applied', exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = p_user))
$$;
revoke all on function _opp_card(opportunities, uuid) from public, anon, authenticated;

-- Correctifs ciblés sur les définitions en place (idempotent : sans effet si déjà appliqué, erreur si la définition attendue a changé).
do $$
declare r record; def text;
begin
  for r in select * from (values
    ('public.company_dashboard(uuid)'::regprocedure,
     $a$'offers_active', (select count(*)::int from opportunities where poster_id = v_owner and status in ('pending', 'published'))$a$,
     $b$'offers_active', (select count(*)::int from opportunities where poster_id = v_owner and (status = 'pending' or (status = 'published' and (deadline is null or deadline >= current_date))))$b$),
    ('public.direction_dashboard()'::regprocedure,
     $a$'opportunities', (select count(*)::int from opportunities where status = 'published'),$a$,
     $b$'opportunities', (select count(*)::int from opportunities where status = 'published' and (deadline is null or deadline >= current_date)),$b$),
    ('public.dept_overview(uuid)'::regprocedure,
     $a$from opportunities o where o.status = 'published' and (v is null$a$,
     $b$from opportunities o where o.status = 'published' and (o.deadline is null or o.deadline >= current_date) and (v is null$b$),
    ('public.opp_detail(uuid)'::regprocedure,
     $a$and id <> p_id and status in ('published', 'closed')$a$,
     $b$and id <> p_id and (status = 'closed' or (status = 'published' and (deadline is null or deadline >= current_date)))$b$),
    ('public.opp_remind(uuid, boolean)'::regprocedure,
     $a$status = 'published' and deadline is not null)$a$,
     $b$status = 'published' and deadline is not null and deadline >= current_date)$b$)
  ) as t(fn, old_txt, new_txt) loop
    def := pg_get_functiondef(r.fn);
    if position(r.new_txt in def) > 0 then
      continue;
    elsif position(r.old_txt in def) = 0 then
      raise exception 'Définition inattendue pour %', r.fn::text;
    end if;
    execute replace(def, r.old_txt, r.new_txt);
  end loop;
end $$;
