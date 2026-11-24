-- H9 : réapplication du cloisonnement par département sur deux fonctions d'offres.
-- Constat (scénario h7_cloisonnement.mjs, contrôle 8.r) : 20261124050000_equipe_entreprise_offres.sql recrée opp_close et opp_my_posted à partir de leur définition d'origine
-- (20261114001300), ce qui a effacé les restrictions posées sur place par 20261120020300 (H2) : un compte « département » voyait de nouveau TOUTES les offres en attente de
-- tous les départements (opp_my_posted) et pouvait fermer l'offre de n'importe quel département (opp_close).
-- Cette migration reprend les définitions de 20261124050000 (équipe d'entreprise conservée : _opp_can) avec la seule restriction H2 : le rôle « dept » ne traite que les offres
-- qui ciblent son département (_dept_sees_opp) ; l'administrateur garde tout.
-- Les autres fonctions recréées par 20261124050000 (opp_application_decide, opp_media_set, opp_applications_for, opp_stats, opp_applications_received) n'avaient aucune restriction H2.
-- Retour arrière : recréer opp_close et opp_my_posted depuis 20261124050000 (sans la clause _dept_sees_opp).

create or replace function opp_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update opportunities set status = 'closed' where id = p_id and (_opp_can(poster_id, true) or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees_opp(department_target, poster_id));
  if not found then raise exception 'Offre introuvable'; end if;
end $$;

create or replace function opp_my_posted() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(_opp_card(o, auth.uid()) || jsonb_build_object('applications', (select count(*)::int from opportunity_applications a where a.opportunity_id = o.id),
      'review_note', o.review_note, 'description', o.description, 'poster', display_name(o.poster_id), 'can_manage', _opp_can(o.poster_id, true)) order by (o.status = 'pending') desc, o.created_at desc)
    from opportunities o where _opp_can(o.poster_id, false)
      or (v_staff and o.status = 'pending' and (coalesce(current_role_name()::text, '') = 'admin' or _dept_sees_opp(o.department_target, o.poster_id)))), '[]'::jsonb);
end $$;
