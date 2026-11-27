-- H13 ORGS (4/4) : accès multi-organisations — « Mes organisations » avec droits et pastilles d'activité par organisation (sélecteur d'organisation active).
--   my_organizations() : les organisations de la personne connectée = sa propre fiche (compte Organisation) + celles où elle est membre actif ou invitée. Pour chacune : nom, logo,
--   vérifiée ou non, rôle, statut, indicateur « ma fiche », droits du rôle (gérer, payer, lire/écrire le vivier) et pastilles d'activité calculées côté serveur AVEC LES DROITS DU RÔLE
--   dans cette organisation (jamais de chiffre d'une organisation dont on n'est pas membre actif ; « finance » ne voit ni propositions ni vivier) :
--     pending_proposals (propositions de prestataires à examiner), due_reminders (rappels du vivier échus), pending_contacts (demandes de contact sans réponse du talent).
--   Une pastille non autorisée vaut null (jamais 0 trompeur). L'organisation active reste le contexte de l'application (changement sans perte : chaque écran relit l'organisation choisie ;
--   le serveur contrôle le rôle à chaque appel via company_role_of).
-- Additive et rejouable. Retour arrière : drop function my_organizations().

create or replace function my_organizations() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(x.j order by x.rk, x.nm) from (
    select o.rk, lower(o.name) nm, jsonb_build_object(
      'owner_id', o.owner_id, 'company_name', o.name, 'logo_path', o.logo_path, 'verified', o.approved, 'role', o.role, 'status', o.status, 'is_own', o.is_own,
      'can_manage', o.status = 'active' and o.role in ('owner', 'admin'),
      'can_pay', o.status = 'active' and o.role in ('owner', 'admin', 'finance'),
      'can_pool_read', o.status = 'active' and o.approved and o.role in ('owner', 'admin', 'viewer'),
      'can_pool_write', o.status = 'active' and o.approved and o.role in ('owner', 'admin'),
      'pending_proposals', case when o.status = 'active' and o.role in ('owner', 'admin', 'viewer') then
          (select count(*)::int from mission_proposals p join missions m on m.id = p.mission_id where m.client_id = o.owner_id and p.status = 'submitted' and m.status = 'published') end,
      'due_reminders', case when o.status = 'active' and o.approved and o.role in ('owner', 'admin', 'viewer') then
          (select count(*)::int from talent_pool_reminders r where r.org_id = o.owner_id and r.status = 'ouvert' and r.due_on <= current_date and _talent_listable(r.student_id)) end,
      'pending_contacts', case when o.status = 'active' and o.approved and o.role in ('owner', 'admin', 'viewer') then
          (select count(*)::int from talent_contacts c where c.org_id = o.owner_id and _contact_status(c.status, c.expires_at) in ('sent', 'seen') and _talent_listable(c.target_id)) end
    ) j
    from (
      select cp.owner_id, cp.company_name as name, cp.logo_path, cp.status = 'approved' as approved, 'owner'::text as role, 'active'::text as status, true as is_own, 0 as rk
        from company_profiles cp join profiles p on p.id = cp.owner_id where cp.owner_id = v_me and p.role::text in ('company', 'other')
      union all
      select m.owner_id, cp.company_name, cp.logo_path, cp.status = 'approved', m.role, m.status, false, case m.status when 'active' then 1 else 2 end
        from company_members m join company_profiles cp on cp.owner_id = m.owner_id where m.user_id = v_me and m.owner_id <> v_me
    ) o) x), '[]'::jsonb);
end $$;

revoke all on function my_organizations() from public, anon;
grant execute on function my_organizations() to authenticated;
