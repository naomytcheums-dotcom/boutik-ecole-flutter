# Talents, projets, services, besoins (10 novembre 2026)

Pages « réelles » (connecté uniquement ; hors connexion, la maquette reste affichée). Elles remplacent l'écran de maquette au début de `build()`
(`if (!demoContent) return const XxxPage();`). Aucun champ n'est prérempli ni accompagné d'un exemple.

| Écran | Page | Fichier |
|---|---|---|
| 203 Mes compétences | `SkillsPage` (liste, modifier, supprimer) + `SkillFormPage` | `lib/figma/live/talent_pages.dart` |
| 72 Ajouter à mon profil | `AddToProfilePage` (compétence, réalisation, document, portfolio) | idem |
| 73 Mes documents | `DocumentsPage` : CV, diplômes, certificats, autres, carte, certificat de scolarité ; ajout multiple, voir, remplacer, supprimer | idem |
| Puce « Portfolio » des profils 10, 77, 89 | `PortfolioPage` / `PortfolioFormPage` : état vide avec « Créer mon portfolio », réalisations, images, vidéos, liens, élément phare libre | idem |
| 74, 229 | raccourcis « Mes compétences », « Ajouter un CV / Gérer mes documents », « Mon portfolio » (dans `MyProfileCard`) | `vendeur.dart` |
| 80, 205 (+ 87 « Déclarer une innovation », 78 bouton) | `ProjectFormPage`, `MyProjectsPage` | `project_pages.dart` |
| 59 Nouveau service | `ServiceFormPage` (tarif vide = « Sur devis ») | `service_pages.dart` |
| 90 Publier un besoin | `NeedFormPage`, `MyNeedsPage` | `need_pages.dart` |

Composants communs : `tp_ui.dart` (`TpPage`, `TpField`, `TpSelect` extensible avec « Autre (saisir) », `TpChoice`, sélecteur de fichiers contrôlé, etc.).

## Serveur (migration `20261110010000_talents_projets_portfolio.sql`, additive)

- `skill_catalog` : domaines > métiers > compétences de référence (génie civil, informatique, design, gestion, électricité, mécanique, agro, santé, enseignement).
  Extensible : `catalog_propose` ajoute une entrée « proposée », visible de son auteur seul jusqu'à `catalog_review` (équipe).
- `talent_skills` (RPC `skill_save`, `skill_delete`) : domaine, métier, compétence, niveau, expérience, description, justificatif facultatif
  (un de ses propres documents). Synchronise `profiles.skills`.
- `portfolio_items` (RPC `portfolio_save`, `portfolio_delete`), compartiment public `portfolio-media` (RLS : écriture dans son dossier seulement).
  Un seul élément « phare » par personne (index unique partiel).
- `projects` : colonnes `kind`, `details` (fiche complète), `media`, `visibility` ; RPC `project_save_full` (brouillon ou publication ;
  la publication refuse si titre, description, domaine, problème, solution, avancement ou contact manquent) et `project_delete` (brouillons et refusés).
  Un projet envoyé ou publié n'est plus modifiable ici. Compartiment public `project-media`.
- Test : `supabase/tests/talents_pglite/scenario.mjs` (23 vérifications : RLS, doublons, justificatif étranger refusé, un seul phare, publication incomplète refusée…).
  Rejeu : voir `supabase/tests/marketplace_pglite/README.md`.

## Diplôme : pas de « code »

Aucun champ « code » n'existe dans l'application pour les diplômes (aucun mécanisme de vérification par code n'est implémenté) : le diplôme s'importe comme
tout document (PDF/JPG/PNG/WebP, 10 Mo) et passe en « En attente » jusqu'à vérification par l'équipe.

## Offres premium

« Prix à définir » devient « Tarif non défini » ; la souscription est refusée tant que `plans.price_xaf` est vide. Les tarifs sont lus de la table `plans`
(fixés par l'administrateur, écran « Fixer le prix »). Aucun tarif n'est inventé : les cinq plans n'ont pas encore de prix en production.
