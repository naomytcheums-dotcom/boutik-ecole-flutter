-- Lot L4 (a) : la capacité de vendre (seller_capable, lot K2) est imposée aux opérations COMMERCIALES des missions et des campagnes, côté SERVEUR.
--   Commercial (exige seller_open = étudiant vérifié + téléphone vérifié + compte non suspendu + boutique non en pause) :
--     · proposer un devis / une offre de prestation sur un besoin (propose_on_mission) ;
--     · être retenu pour une mission (acceptation par le client : decide_proposal ; attribution par le département ou l'administrateur : assign_mission) ;
--     · créer, modifier, soumettre, reprendre ou faire valider une campagne publicitaire d'un ÉTUDIANT (ad_campaign_save / submit / toggle / review), et la diffuser (ad_feed).
--   NON commercial, inchangé : publier un besoin, retirer ou décliner une proposition, messagerie de mission, livraison et règlement d'une mission DÉJÀ engagée
--   (comme K2 : l'engagement en cours est conservé), concours, appels à projets, opportunités, projets étudiants, réseau social, messagerie.
--   Organisations et administrateurs : aucune capacité vendeur imposée aux campagnes des organisations (forfait boost_campagnes seul, inchangé) ;
--   département et administrateur ne vendent pas (K2) : ils ne PROPOSENT pas de devis, mais attribuent à un talent éligible.
--   Gardes par déclencheurs (valables pour les RPC ET les écritures directes). Désactiver (pause, annulation, fin) reste toujours libre.
-- Additive et rejouable. Retour arrière :
--   drop trigger trg_zz_l4_proposal on mission_proposals ; drop trigger trg_zz_l4_ad_campaign on ad_campaigns ;
--   drop function l4_proposal_guard(), l4_ad_campaign_guard(), l4_is_student(uuid) ; recréer ad_feed depuis 20261106000000_premium_publicites.sql.

create or replace function l4_is_student(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.role::text = 'student' from profiles p where p.id = p_user), false)
$$;
revoke all on function l4_is_student(uuid) from public, anon, authenticated;

-- ============================================================ 1. Propositions de prestation
create or replace function l4_proposal_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v text;
begin
  if uid is null then return new; end if;                                   -- éditeur SQL / tâches planifiées
  if new.status = 'submitted' and (tg_op = 'INSERT' or old.status is distinct from 'submitted') then
    if new.author_id = uid then
      v := _seller_block_reason(uid, true);
      if v is not null then raise exception 'Proposer ses services sur un besoin est une prestation de service : %', v; end if;
    elsif not seller_open(new.author_id) then
      raise exception 'Ce talent n''est pas éligible à la prestation de service (étudiant vérifié, téléphone vérifié, boutique non en pause) : attribution impossible';
    end if;
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' and not seller_open(new.author_id) then
    raise exception 'Ce talent n''est plus éligible à la prestation de service : acceptation impossible';
  end if;
  return new;
end $$;
revoke all on function l4_proposal_guard() from public, anon, authenticated;
drop trigger if exists trg_zz_l4_proposal on mission_proposals;
create trigger trg_zz_l4_proposal before insert or update on mission_proposals for each row execute function l4_proposal_guard();

-- ============================================================ 2. Campagnes publicitaires
create or replace function l4_ad_campaign_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v text;
begin
  if uid is null then return new; end if;
  if new.owner_id is distinct from uid then
    -- un valideur ne lance pas la campagne d'un étudiant qui ne peut plus vendre ; les autres écritures (diffusion, paiement confirmé) ne sont pas concernées
    if tg_op = 'UPDATE' and new.status in ('approved', 'active') and old.status is distinct from new.status and l4_is_student(new.owner_id) and not seller_open(new.owner_id) then
      raise exception 'Le vendeur n''est plus éligible à la vente : validation de la campagne impossible';
    end if;
    return new;
  end if;
  if not l4_is_student(uid) then return new; end if;                         -- organisations, administrateurs : forfait seul
  if tg_op = 'UPDATE' and new.status in ('paused', 'finished') then return new; end if;
  v := _seller_block_reason(uid, true);
  if v is not null then raise exception 'Une campagne publicitaire est une opération commerciale : %', v; end if;
  return new;
end $$;
revoke all on function l4_ad_campaign_guard() from public, anon, authenticated;
drop trigger if exists trg_zz_l4_ad_campaign on ad_campaigns;
create trigger trg_zz_l4_ad_campaign before insert or update on ad_campaigns for each row execute function l4_ad_campaign_guard();

-- Diffusion : plus de publicité d'un étudiant devenu non éligible ou dont la boutique est en pause (organisations inchangées).
create or replace function ad_feed(p_limit int default 3) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'body', c.body, 'post_id', c.post_id, 'listing_id', c.listing_id,
         'sponsored', true, 'owner', coalesce(o.name, 'Annonceur')) order by random()), '[]'::jsonb)
  from (select * from ad_campaigns
        where status = 'active' and spent_xaf < budget_xaf and coalesce(starts_on, current_date) <= current_date and coalesce(ends_on, current_date) >= current_date
          and owner_id is distinct from auth.uid()
          and (not l4_is_student(owner_id) or seller_open(owner_id))
          and (daily_budget_xaf is null or coalesce((select count(*) from ad_events e where e.campaign_id = ad_campaigns.id and e.kind = 'click' and e.day = current_date), 0)
               * coalesce((select (value #>> '{}')::int from platform_settings where key = 'ads.cost_per_click'), 0) < daily_budget_xaf)
        limit least(greatest(p_limit, 1), 10)) c
  left join profiles o on o.id = c.owner_id;
$$;
