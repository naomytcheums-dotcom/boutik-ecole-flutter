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

## Deuxième lot de 20 écrans (33, 51, 74, 88, 93b, 94, 97, 101, 104, 127, 148_1, 158, 173, 244b, 248, 251, 25b, 263, 278, 285)
- Paramètres (nom/e-mail du compte), boutique (annonces du vendeur), favoris, projets, besoins et propositions de l'entreprise, événements, établissements, catalogue de gestion, cercle, découverte, notifications. Aucune migration. Test `lot20b_test.dart` (42).

## Lot de 30 écrans avec nouvelles tables (migration 20261105001000_modules_restants.sql, appliquée en production)
- Nouvelles tables : platform_settings, cms_items, duels, duel_entries, duel_votes, live_comments, pickups. Fonctions : settings_all, setting_set, cms_save, cms_delete, duel_create, duel_enter, duel_vote, duels_list, live_set_state, live_comment, pickup_register, pickup_collect, pickups_list, my_referral_code, skills_radar. Tests SQL 25/25.
- Écrans reliés : 18, 76, 82, 84b, 116, 122, 125, 136, 138, 144, 146_2, 195, 197, 219, 220, 221, 222, 233, 234, 235, 242, 254, 255, 264, 265, 266, 269, 280, l1, v1. Test `lot30_test.dart` (68).
- Série quotidienne, défis et publications existaient déjà (migration 20261101000600) : non dupliqués. Les réglages sont enregistrés et journalisés ; certains modules ne les lisent pas encore. Création de retrait en casier : fonction prête, pas de formulaire à l'écran.

## Audit des données de maquette en mode connecté (test `audit_donnees_maquette_test.dart`)
- Chaque écran est ouvert en mode connecté, serveur muet, et la liste des noms, références et montants de maquette encore affichés est écrite dans `build/audit_maquette.txt`. Avant : 43 écrans en affichaient. Après : 4 (fil social d'exemple voulu sur 244, deux textes d'aide « Ex. … » dans des champs de saisie 58 et 80, un format de prix sur 217).
- Corrections à la source : commande « d'exemple » (dernière commande), lignes d'exemple de la console des commandes et des flux financiers, talents, opportunités, équipes et projets d'exemple, produit par défaut de la fiche (« Aucun produit choisi »), chef de projet. 127 remis à son état précédent (il lisait déjà le volume réel du serveur). Deux zones de toucher ajoutées sur 102 et 154 ne sont plus actives en démonstration (elles masquaient les boutons d'origine).
- Reste à décision du propriétaire : assistante vocale Kéla (a1-a3, 230-232), 3D/AR (225, 226), double authentification (272), contacts (241), langue (149, 185), permissions (181, 281), contrôles de fiche (256), ajout de fichiers (279).

## Décisions prises sur les écrans restants
- Kéla (230, a1, 232, a3, 231, a2) : la dictée vocale n'existe pas, le brief se fait par écrit et crée un brouillon de besoin réel (save_mission) ; 232/a3 listent les briefs du compte ; 231/a2 deviennent un menu vers les vrais écrans.
- 3D / réalité augmentée (225, 226) : aucun modèle n'existe ; en connecté l'écran dit qu'il n'y en a pas et montre la photo de l'annonce.
- Vérification en 2 étapes (272) : double authentification réelle par application (TOTP Supabase Auth : activation, code, désactivation) à la place du code SMS de maquette.
- Contacts (241) : le navigateur ne donne pas accès au répertoire ; remplacé par le code de parrainage à partager.
- Langue (149, 185) : français actif, anglais « bientôt disponible » ; interrupteurs d'accessibilité de 149 mémorisés sur l'appareil.
- Contrôles de fiche (256) : calculés sur l'annonce réelle du vendeur ; 279 : règles de dépôt sans fichiers fictifs ; 281 : institution du compte.
- Permissions (181) et matrices de rôles : conservées, ce sont les règles de la plateforme (documentation), pas des données.
- Textes d'aide 58 et 80 : neutres hors démonstration. 244 : fil d'exemple conservé à la demande du propriétaire.
