# Progrès du reliage des écrans

| Écran | Date | Statut |
|---|---|---|
| 100 Événements | 2026-11-05 | relié (migration 20261105000000 locale, test evenements_test.dart) |
| 102 Vitrine | 2026-11-05 | relié (produits réels, compteurs réels ; test vitrine_economie_circulaire_test.dart) |
| 106 Économie circulaire | 2026-11-05 | relié (produits de récupération réels ; même test) |
| 103 Communauté | 2026-11-05 | relié (membres réels, accès au profil public ; test vitrine_economie_circulaire_test.dart) |
| 105, 107, 237, 238, 239 | 2026-11-05 | chiffres et listes inventés retirés hors démo : message « source de données non disponible » (aucune table d impact, de sponsoring ou inter-établissements) ; test ecrans_sans_source_test.dart |
| 124 Événements (administration) | 2026-11-05 | relié (table réelle des événements, inscrits, statut ; test evenements_test.dart) |
| 105, 107, 237, 238, 239 | 2026-11-05 | RELIÉS : migration 20261105000100 (champs recycled/recycled_kg sur les annonces, impact calculé, sponsors et contributions, créations d autres établissements) ; SQL 12/12 ; test ecrans_sans_source_test.dart 12/12 |
| 119, 120, 121 | 2026-11-05 | RELIÉS : migration 20261105000200 (admin_departments, admin_users, réservées à la gestion) ; SQL 7/7 ; test console_administration_test.dart 9/9 |
| 109, 112 | 2026-11-05 | RELIÉS : migration 20261105000300 (dept_students, dept_stats, portée par département) ; SQL 6/6 ; test console_administration_test.dart 14/14 |
| 91, 93, 95, 96, 98, 99 | 2026-11-05 | RELIÉS : migration 20261105000400 (company_proposals, company_missions) + lecture RLS des devis et défis ; SQL 5/5 ; test espace_entreprise_test.dart 12/12 |
| 139, 140, 141, 142, 143 | 2026-11-05 | RELIÉS : migration 20261105000500 (payout_batches ; finance_overview, finance_payments, finance_journal, finance_by_department, finance_payouts ; création et statut des lots réservés finance/admin) ; SQL 10/10 ; test finance_test.dart 11/11 |
| 78, 85, 86, 87 | 2026-11-05 | RELIÉS (lecture RLS des projets validés, certificats, campagnes ; contributions non collectées en ligne : message honnête) ; test espace_entreprise_test.dart 19/19 |

## Lot missions (écrans 154, 198, 199, 200)
- 154 Mon dossier : checklist calculée sur les pièces réellement envoyées (CV, carte d'étudiant, certificat de scolarité, diplôme, photo, matricule). Test `dossier_test.dart`.
- 198 Briefs reçus, 199 Attribution, 200 Missions : migration `20261105000600_console_missions.sql` (staff_missions, staff_mission_proposals), attribution réelle par `assign_mission`. Les montants de l'écran 200 sont ceux des jalons ; aucun séquestre réel n'existe en ligne. Tests SQL 4/4, `console_missions_test.dart` 8/8.

## Lot opportunités (écrans 152, 157, 203, 204)
- 152 offres ouvertes réelles (missions publiées) sans pourcentage ; 157 résumé calculé sur propositions et besoins de l'entreprise ; 203 compétences du profil, sans score inventé ; 204 projets réels. Aucune migration. Classement Kéla, scores, financement et mentors : non disponibles côté serveur, dit explicitement à l'écran. Test `opportunites_test.dart`.

## Lot encadrement (écrans 113, 114)
- Migration `20261105000700_encadrement_productions.sql` : tables mentors et productions, fonctions staff_mentors, staff_productions, mentor_create, production_create, production_update ; « en retard » calculé. Tests SQL 8/8, `encadrement_test.dart` 7/7. Bouton « Ajouter un mentor » réel. Création de productions : fonction serveur prête, pas encore de formulaire à l'écran.

## Lot vendeur et entreprise (écrans 66, 67, 69, 189, 190)
- Migration `20261105000800_revenus_vendeur.sql` (seller_revenue : ventes payées, reversé, prévu, disponible, séries mensuelle et hebdomadaire). Tests SQL 4/4, `vendeur_test.dart` 10/10. 69 lit les vrais justificatifs ; 189 propositions et 190 devis réels. Vues d'annonces et conversion : non mesurées, dit à l'écran.

## Lot compte et fiche produit (écrans 27, 31, 32)
- 27 Mes adresses : carnet réel (lecture RLS, ajout par save_address, suppression par delete_address). 31 Avis : moyenne, répartition et commentaires réels du produit choisi. 32 Détail du produit : produit réellement choisi, sans caractéristiques inventées. Test `compte_test.dart`.

## Lot vitrine et vendeur (écrans 04, 20, 22c, 22d, 24, 38, 115, 172, 187, 212)
- Migration `20261105000900_vendeur_public.sql` (seller_public, lisible sans compte, aucune donnée privée). Tests SQL 5/5, `lot_vitrine_vendeur_test.dart`. 24/38/172 : profil, réputation et confiance calculés ; 212 : vérification par code ; 04/20/22c/22d : vrais produits ; 115 : événements réels ; 187 : besoins réels de l'entreprise.

## Lot réseau, vœux, lives, litiges (écrans 118, 129, 133, 134, 213, 214, 216, 223, 246, 261, 262, 267)
- Listes réelles (établissements, départements publiés, vœux ouverts, lives programmés, réclamations, paiements déclarés, certificats) et résumé entreprise sur 261/262. Aucune migration. Test `lot_reseau_test.dart` (29).

## Lot réglages et profil (écrans 184, 186, 211, 227, 229)
- 184/186 : interrupteurs mémorisés sur l'appareil (valeurs par défaut de la maquette), consommation de données non mesurée donc non affichée. 227/229 : carte construite sur le profil et le dernier CV réels. 211 : produit choisi. Test `lot_profil_reglages_test.dart`.

## Lot de 20 écrans (117, 145, 146_1, 147_1, 147_2, 147_3, 155, 169, 180, 183, 217, 268, 270, 276, 277, 283, 284, 286, 287, 288)
- Bornes (kiosks, incidents), annonces à modérer, notifications, commandes du compte, concours, rôles (comptes par rôle), registres de certificats et financier, vœux, établissements, impact de la plateforme. Aucune migration ; lectures protégées par RLS ou fonctions déjà en production. Test `lot20_test.dart` (48). Les statistiques de sessions/scans de la borne et les retraits par casier ne sont pas mesurés : masqués en mode connecté.
