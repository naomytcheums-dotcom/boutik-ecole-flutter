-- Référentiel universitaire du Cameroun : établissements supplémentaires + départements / filières (qui étaient vides).
-- NON DESTRUCTIVE : uniquement des insertions (`on conflict do nothing`) ; les 11 établissements existants, les profils et les
-- départements déjà proposés ne sont jamais modifiés ni supprimés. Retour arrière en fin de fichier.
--
-- Sources et limites (à relire par l'équipe) :
--  * établissements d'État, grandes écoles publiques et principaux établissements privés d'enseignement supérieur connus du MINESUP ;
--    la liste officielle des IPES (fichier PDF du MINESUP) reste à importer pour être exhaustive (voir docs/transformation/REFERENTIEL_ETABLISSEMENTS.md) ;
--  * départements : intitulés standards de filières par type d'établissement + départements réels de l'IUT de Douala ;
--    l'équipe affine / complète par `reference_review` ou par propositions des étudiants.

-- Référentiel : insertions retirées sur décision du propriétaire (23 novembre 2026). Aucun établissement ni département n'est créé d'office.

-- ------------------------------------------------------------------ isolation : plus aucun produit d'exemple visible
-- Les 11 annonces « d'exemple » de la plateforme (20261029000000 / 20261101000800, `showcase = true`, sans vendeur) sont fictives.
-- Elles ne sont PAS supprimées (aucune perte de données) mais ne sont plus lisibles par l'API : le catalogue d'un compte neuf est vide
-- tant que de vrais produits ne sont pas publiés. Les fonctions du serveur (security definer) continuent de les voir ; pour les
-- republier, retirer cette politique (voir retour arrière).
drop policy if exists "annonces : exemples masqués" on listings;
create policy "annonces : exemples masqués" on listings as restrictive for select using (showcase = false);

-- Retour arrière (à n'exécuter qu'avec l'accord du propriétaire ; supprimerait aussi les profils rattachés) :
--   drop policy "annonces : exemples masqués" on listings;
--   delete from departments where status = 'verified' and proposed_by is null and created_at >= timestamptz '2026-11-09';
--   (les établissements ajoutés se retirent un par un, par leur nom, seulement s'ils n'ont aucun profil rattaché)
