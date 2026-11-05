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
