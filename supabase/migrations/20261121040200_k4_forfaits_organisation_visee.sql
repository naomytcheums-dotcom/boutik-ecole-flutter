-- Lot K4 (Organisation) 3/3 — forfaits proposés selon l'organisation VISÉE, pas selon le compte connecté.
-- Constat : company_plans_list (H1, 20261120010200) filtrait les forfaits sur la fiche de auth.uid(). Un administrateur ou un agent finance d'une organisation
-- (espace partagé, p_owner) n'a pas de fiche : il voyait tous les forfaits (dont « Organisation solidaire » pour une entreprise commerciale, refusé ensuite au paiement) ;
-- et un membre qui possède sa propre fiche voyait les forfaits de SON type au lieu de celui de l'organisation qu'il gère.
-- Correctif : company_plans_list(p_owner) filtre sur l'organisation effective (company_effective_owner : la sienne ou celle dont on est membre actif non suspendu ;
-- accès refusé sinon). L'administrateur global voit toujours tout. Le contrôle serveur au paiement (_company_plan_check) est inchangé.
-- Retour arrière : drop function company_plans_list(uuid) puis recréer company_plans_list() depuis 20261120010200.

drop function if exists company_plans_list();

create or replace function company_plans_list(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_type text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = 'admin' then
    return (select coalesce(jsonb_agg(to_jsonb(p) order by p.position, p.price_fcfa), '[]'::jsonb) from company_plans p);
  end if;
  v_owner := company_effective_owner(p_owner);
  select c.org_type into v_type from company_profiles c where c.owner_id = v_owner;
  return (select coalesce(jsonb_agg(to_jsonb(p) order by p.position, p.price_fcfa), '[]'::jsonb)
          from company_plans p
          where p.active and (cardinality(p.audience_types) = 0 or v_type is null or v_type = any (p.audience_types)));
end $$;
revoke all on function company_plans_list(uuid) from public, anon;
grant execute on function company_plans_list(uuid) to authenticated;
