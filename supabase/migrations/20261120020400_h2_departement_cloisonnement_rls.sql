-- Lot H2 « Département » (5/6) : politiques RLS cloisonnées par département.
-- Les politiques de lecture qui donnaient au rôle dept TOUTES les lignes d'une table (annonces, boutiques, projets, publications, réclamations, devis, missions, certificats…)
-- ne lui donnent plus que celles dont le propriétaire est dans son département (_dept_sees & co, voir 20261120020000 / 20261120020300). L'administrateur, le support
-- et la direction gardent leur périmètre ; les signalements de conversation privée ne sont plus lisibles du rôle dept ; les concours ne sont gérés que par le
-- département du créateur (ou l'administrateur).
-- Chaque politique reprend sa dernière définition avec la seule restriction du rôle dept.
-- Retour arrière : recréer chaque politique depuis la migration indiquée dans le commentaire qui la précède (anciennes clauses current_role_name() in ('dept', ...)).

-- campaigns : « campagnes : publiques une fois validées, porteur, département » (définition de 20261031000000_missions_voeux_campagnes_certificats_bornes.sql)
drop policy if exists "campagnes : publiques une fois validées, porteur, département" on campaigns;
create policy "campagnes : publiques une fois validées, porteur, département" on campaigns for select using (status = 'approved' or owner_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(owner_id)));

-- certificates : « certificats : titulaire, émetteurs » (définition de 20261031000000_missions_voeux_campagnes_certificats_bornes.sql)
drop policy if exists "certificats : titulaire, émetteurs" on certificates;
create policy "certificats : titulaire, émetteurs" on certificates for select using (holder_id = auth.uid() or (current_role_name() in ('admin', 'direction') or (_dept_sees(holder_id) or _dept_sees_name(department))));

-- certification_requests : « certification : titulaire ou équipe » (définition de 20261110000200_certification_parcours.sql)
drop policy if exists "certification : titulaire ou équipe" on certification_requests;
create policy "certification : titulaire ou équipe" on certification_requests for select using (user_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(user_id)));

-- claim_sellers : « rattachements : le vendeur et la moderation » (définition de 20261117040200_money_reclamations.sql)
drop policy if exists "rattachements : le vendeur et la moderation" on claim_sellers;
create policy "rattachements : le vendeur et la moderation" on claim_sellers for select using (seller_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(seller_id)));

-- claims : « reclamations : demandeur, vendeur, moderation » (définition de 20261030000800_avis_reclamations_signalements.sql)
drop policy if exists "reclamations : demandeur, vendeur, moderation" on claims;
create policy "reclamations : demandeur, vendeur, moderation" on claims for select using (claimant_id = auth.uid() or seller_id = auth.uid() or (current_role_name() in ('admin', 'support') or _claim_dept_sees(id)));

-- engagements : « engagements : propriétaire et modération » (définition de 20261030001000_engagements.sql)
drop policy if exists "engagements : propriétaire et modération" on engagements;
create policy "engagements : propriétaire et modération" on engagements for select using (user_id = auth.uid() or (current_role_name() in ('admin', 'support') or _dept_sees(user_id)));

-- files : « fichiers : propriétaire, mission, département » (définition de 20261031000100_parametres_fichiers_dossiers_cv_retrait.sql)
drop policy if exists "fichiers : propriétaire, mission, département" on files;
create policy "fichiers : propriétaire, mission, département" on files for select using (owner_id = auth.uid() or (scope = 'mission' and ref is not null and is_mission_participant(ref)) or (current_role_name() in ('admin') or _dept_sees(owner_id)));

-- listing_history : « historique lisible par le vendeur et le departement » (définition de 20261030000200_annonces_stock.sql)
drop policy if exists "historique lisible par le vendeur et le departement" on listing_history;
create policy "historique lisible par le vendeur et le departement" on listing_history for select using (exists (select 1 from listings l where l.id = listing_id and l.seller_id = auth.uid()) or (current_role_name() in ('admin') or _listing_dept_sees(listing_id)));

-- listing_reports : « signalements : auteur et moderation » (définition de 20261030000800_avis_reclamations_signalements.sql)
drop policy if exists "signalements : auteur et moderation" on listing_reports;
create policy "signalements : auteur et moderation" on listing_reports for select using (reporter_id = auth.uid() or (current_role_name() in ('admin', 'support') or _listing_dept_sees(listing_id)));

-- listings : « annonces : boutique active » (définition de 20261107000000_marketplace.sql)
drop policy if exists "annonces : boutique active" on listings;
create policy "annonces : boutique active" on listings as restrictive for select using (shop_id is null or seller_id = auth.uid() or exists (select 1 from shops s where s.id = shop_id and s.status = 'active') or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(seller_id)));

-- listings : « annonces approuvées visibles par tous » (définition de schema.sql)
drop policy if exists "annonces approuvées visibles par tous" on listings;
create policy "annonces approuvées visibles par tous" on listings for select using (status = 'approved' or seller_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(seller_id)));

-- listings : « validation par le departement » (définition de 20261029000100_p1_securite.sql)
drop policy if exists "validation par le departement" on listings;
create policy "validation par le departement" on listings for update using (seller_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(seller_id))) with check (seller_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(seller_id)));

-- message_reports : « signalements de conversation : auteur et modération » (définition de 20261106000100_messagerie_notifications_ia.sql)
drop policy if exists "signalements de conversation : auteur et modération" on message_reports;
create policy "signalements de conversation : auteur et modération" on message_reports for select using (reporter_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support')));

-- mission_agreements : « accords de mission : parties et département » (définition de 20261117045100_missions_prestataire.sql)
drop policy if exists "accords de mission : parties et département" on mission_agreements;
create policy "accords de mission : parties et département" on mission_agreements for select using (client_id = auth.uid() or provider_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(provider_id)));

-- mission_milestones : « jalons : client, prestataire retenu, département » (définition de 20261031000000_missions_voeux_campagnes_certificats_bornes.sql)
drop policy if exists "jalons : client, prestataire retenu, département" on mission_milestones;
create policy "jalons : client, prestataire retenu, département" on mission_milestones for select using (exists (select 1 from missions m where m.id = mission_id and (m.client_id = auth.uid() or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted'))) or (current_role_name() in ('admin') or _dept_sees_mission_provider(mission_id)));

-- mission_proposals : « propositions : auteur, client, département » (définition de 20261031000000_missions_voeux_campagnes_certificats_bornes.sql)
drop policy if exists "propositions : auteur, client, département" on mission_proposals;
create policy "propositions : auteur, client, département" on mission_proposals for select using (author_id = auth.uid() or exists (select 1 from missions m where m.id = mission_id and m.client_id = auth.uid()) or (current_role_name() in ('admin') or _dept_sees(author_id)));

-- pickups : « retraits : gestion ou acheteur » (définition de 20261105001000_modules_restants.sql)
drop policy if exists "retraits : gestion ou acheteur" on pickups;
create policy "retraits : gestion ou acheteur" on pickups for select using ((coalesce(current_role_name()::text, '') in ('admin', 'direction', 'support') or _order_dept_sees(order_id)) or exists (select 1 from orders o where o.id = order_id and o.buyer_id = auth.uid()));

-- post_comments : « commentaires visibles » (définition de 20261103000000_commentaires_publications.sql)
drop policy if exists "commentaires visibles" on post_comments;
create policy "commentaires visibles" on post_comments for select using ( (status = 'visible' and exists (select 1 from posts p where p.id = post_id and p.status = 'published')) or author_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(author_id)) );

-- post_reports : « signalements : auteur du signalement et modération » (définition de 20261101000600_reels_defis.sql)
drop policy if exists "signalements : auteur du signalement et modération" on post_reports;
create policy "signalements : auteur du signalement et modération" on post_reports for select using (reporter_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _post_dept_sees(post_id)));

-- posts : « publications visibles » (définition de 20261103000100_communautes_notifications_sociales.sql)
drop policy if exists "publications visibles" on posts;
create policy "publications visibles" on posts for select using ( (status = 'published' and (community_id is null or exists (select 1 from communities c where c.id = community_id and c.privacy = 'public' and c.status = 'active') or is_community_member(community_id))) or author_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(author_id)) );

-- projects : « projets : porteur et département » (définition de 20261115000100_securite_client.sql)
drop policy if exists "projets : porteur et département" on projects;
create policy "projets : porteur et département" on projects for select using (owner_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(owner_id)));

-- quote_messages : « fil de devis : parties et équipe » (définition de 20261118040200_f4_negociation_devis.sql)
drop policy if exists "fil de devis : parties et équipe" on quote_messages;
create policy "fil de devis : parties et équipe" on quote_messages for select using (exists (select 1 from quote_requests q where q.id = quote_messages.quote_id and (q.requester_id = auth.uid() or q.provider_id = auth.uid() or (current_role_name() in ('admin', 'support') or _dept_sees(q.provider_id) or _dept_sees(q.requester_id)))));

-- quote_requests : « devis : demandeur et prestataire » (définition de 20261030000900_services_devis.sql)
drop policy if exists "devis : demandeur et prestataire" on quote_requests;
create policy "devis : demandeur et prestataire" on quote_requests for select using (requester_id = auth.uid() or provider_id = auth.uid() or (current_role_name() in ('admin', 'support') or (_dept_sees(provider_id) or _dept_sees(requester_id))));

-- shop_reports : « signalements boutiques : auteur, équipe » (définition de 20261107000000_marketplace.sql)
drop policy if exists "signalements boutiques : auteur, équipe" on shop_reports;
create policy "signalements boutiques : auteur, équipe" on shop_reports for select using (reporter_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _shop_dept_sees(shop_id)));

-- shops : « boutiques : actives, propriétaire, équipe » (définition de 20261107000000_marketplace.sql)
drop policy if exists "boutiques : actives, propriétaire, équipe" on shops;
create policy "boutiques : actives, propriétaire, équipe" on shops for select using (status = 'active' or owner_id = auth.uid() or (coalesce(current_role_name()::text, '') in ('admin', 'support') or _dept_sees(owner_id)));

-- stock_movements : « mouvements lisibles par le vendeur et le departement » (définition de 20261030000200_annonces_stock.sql)
drop policy if exists "mouvements lisibles par le vendeur et le departement" on stock_movements;
create policy "mouvements lisibles par le vendeur et le departement" on stock_movements for select using (exists (select 1 from listings l where l.id = listing_id and l.seller_id = auth.uid()) or (current_role_name() in ('admin') or _listing_dept_sees(listing_id)));

-- talent_skills : « compétences : propriétaire et équipe » (définition de 20261115000100_securite_client.sql)
drop policy if exists "compétences : propriétaire et équipe" on talent_skills;
create policy "compétences : propriétaire et équipe" on talent_skills for select to authenticated using (owner_id = auth.uid() or (current_role_name() in ('admin', 'support') or _dept_sees(owner_id)));

-- wishes : « vœux : publics à leur date, auteur, département » (définition de 20261115200000_l10_voeux_precommandes.sql)
drop policy if exists "vœux : publics à leur date, auteur, département" on wishes;
create policy "vœux : publics à leur date, auteur, département" on wishes for select using ((status = 'approved' or (status = 'scheduled' and publish_at is not null and publish_at <= now())) or author_id = auth.uid() or (current_role_name() in ('admin') or (_dept_sees_dept(department_id) or (department_id is null and _dept_sees(author_id)))));

-- concours : les lignes de gestion ne sont visibles que du département créateur (ou de l'administrateur)
drop policy if exists "concours visibles" on contests;
create policy "concours visibles" on contests for select using (status <> 'draft' or _contest_staff_for(id));
drop policy if exists "équipes visibles" on contest_teams;
create policy "équipes visibles" on contest_teams for select using (not hidden or captain_id = auth.uid() or _contest_staff_for(contest_id));
drop policy if exists "membres visibles" on contest_members;
create policy "membres visibles" on contest_members for select using (user_id = auth.uid() or is_contest_member(team_id) or _contest_staff_for_team(team_id));
drop policy if exists "dépôts : équipe, jury, département" on contest_submissions;
create policy "dépôts : équipe, jury, département" on contest_submissions for select using (is_contest_member(team_id) or _contest_staff_for_team(team_id) or (submitted and is_contest_juror((select t.contest_id from contest_teams t where t.id = team_id))));
drop policy if exists "notes : juré, département, équipe après résultats" on contest_scores;
create policy "notes : juré, département, équipe après résultats" on contest_scores for select using (juror_id = auth.uid() or _contest_staff_for_submission(submission_id) or exists (select 1 from contest_submissions s join contest_teams t on t.id = s.team_id join contests c on c.id = t.contest_id where s.id = submission_id and c.status = 'results' and is_contest_member(t.id)));
drop policy if exists "jurés visibles du département et d'eux-mêmes" on contest_jurors;
create policy "jurés visibles du département et d'eux-mêmes" on contest_jurors for select using (user_id = auth.uid() or _contest_staff_for(contest_id));
drop policy if exists "tâches d'équipe : membres et département" on contest_tasks;
create policy "tâches d'équipe : membres et département" on contest_tasks for select using (is_contest_member(team_id) or _contest_staff_for_team(team_id));
