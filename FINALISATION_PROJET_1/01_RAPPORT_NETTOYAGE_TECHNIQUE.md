# 01 — Rapport de nettoyage technique et d'assainissement contrôlé

> Date : 01/11/2026. Dépôt `feat/figma-fidele` à `dfecbae` (identique à `origin`). Point de sauvegarde local créé avant toute
> intervention : étiquette annotée **`sauvegarde-avant-finalisation-20261101`** (non poussée). Les dossiers non suivis préexistants
> (`supabase/migrations_backup_20261031/`, `AUDIT_REPRISE_20261031/`) sont conservés.
> **Aucune suppression** n'a été faite, ni en production ni en local.

## 1. Comptes de test en production

Méthode :
- lecture **seule** de la production via `tool/audit/prod_readonly_probe.py`, qui exécute chaque requête dans
  `begin transaction read only` et refuse tout mot-clé d'écriture ;
- script de collecte : `FINALISATION_PROJET_1/outils/inventaire_zz_test.py` ;
- résultats : `donnees/zz_test_inventaire_production.json` et `donnees/production_volumes_comptes.json`.

### 1.1 Existence et nombre

L'historique parlait de « deux comptes `zz-test` ». **La production en contient 46**, sur **55 comptes au total**. Ils ont tous été
créés les 30 et 31/10 par les recettes navigateur et REST.

| Préfixe | Comptes | Rôles | Origine (tests) |
|---|---|---|---|
| `zz-test-par-*` | 28 | 14 client, 14 student | `e2e/tests/parcours.spec.ts` |
| `zz-test-eng-*` | 10 | 5 client, 5 student | `e2e/tests/engagements.spec.ts` |
| `zz-test-prod-*` | 6 | student | `e2e/tests/production.spec.ts` (avant 31a) |
| `zz-test-mfa-*` | 2 | 1 client, 1 sans profil (`zz-test-mfa-cf360c3e`) | `e2e/tests/mfa.spec.ts` |

**Ce ne sont pas de vrais utilisateurs** :
- domaine `example.com`, réservé par la RFC 2606, sur lequel aucune adresse réelle ne peut exister ;
- motif strict `^zz-test-[a-z0-9-]+@example\.com$` ;
- noms « Test … » ;
- aucun **autre** compte `@example.com` en production.

### 1.2 Données rattachées

Les 50 clés étrangères vers `auth.users` et `public.profiles` ont été examinées, avec un décompte dynamique par table.

| Table | Lignes rattachées aux comptes `zz-test` | Comportement à la suppression du compte |
|---|---|---|
| `auth.sessions` | 113 | cascade |
| `auth.identities` | 46 | cascade |
| `public.profiles` | 45 | cascade |
| `public.engagements` | 18 (9 inscriptions à un événement, 3 préférences de canaux, 3 candidatures, 1 demande d'export, 1 vote, 1 alerte) | cascade |
| `auth.mfa_factors` | 2 | cascade |
| **Toutes les autres tables** (commandes, annonces, missions, certificats, messages, fichiers…) | **0** | — |
| `storage.objects` | **0** (les 3 buckets sont **vides** en production) | — |
| Lignes de commande de comptes réels portant sur des annonces de test | **0** | — |

Les 19 clés étrangères **sans** cascade (`listings.seller_id`, `orders.buyer_id`, `missions.client_id`,
`certificates.issued_by`, etc.) n'ont **aucune** ligne rattachée aux comptes `zz-test`. La suppression ne peut donc pas échouer sur une
contrainte.

### 1.3 Autres comptes (pour information, sans adresse)

9 comptes hors `zz-test` :
- **8 comptes « client » bannis**, créés le 29/10 : les comptes de démonstration neutralisés par le correctif P0 (`b1bf0d1`) ;
- **1 compte « student »** créé le 30/10, actif.

Aucun n'est concerné par ce nettoyage.

### 1.4 Plan de nettoyage (non exécuté, **autorisation requise**)

| Élément | Détail |
|---|---|
| Périmètre | les 46 comptes du motif `^zz-test-[a-z0-9-]+@example\.com$`, et rien d'autre. Si vous voulez vous limiter à une partie des comptes, il faut donner leur liste d'identifiants |
| Script | `supabase/maintenance/cleanup_test_accounts.sql` (existant, versionné) : inventaire, puis transaction avec garde-fous (arrêt si une donnée d'un compte réel dépend d'un compte de test) et contrôle avant/après des comptes, annonces et commandes réels ; **se termine par `ROLLBACK`** : il faut relire les totaux, puis remplacer par `COMMIT` |
| Ordre | 1. inventaire en lecture seule (section 1 du script) ; 2. sauvegarde ; 3. transaction en `ROLLBACK` (essai à blanc) ; 4. relecture ; 5. `COMMIT` ; 6. vérifications |
| Dépendances supprimées en cascade | 45 profils, 18 engagements, 113 sessions, 46 identités, 2 facteurs MFA |
| Risques | faibles : aucune commande, annonce ou fichier ; aucune référence sans cascade. Le seul risque est la suppression des **preuves** des recettes du 30-31/10 (engagements), ce qui est souhaité |
| Sauvegarde et retour arrière | avant le `COMMIT` : export CSV de `auth.users` (colonnes non sensibles), de `profiles` et d'`engagements` filtrés sur les 46 identifiants (éditeur SQL), et vérification de la sauvegarde quotidienne de Supabase. Retour arrière : **non trivial** (les mots de passe et identités ne se recréent pas à l'identique), ce qui est acceptable pour des comptes jetables |
| Vérifications après | `comptes_test_restants = 0` ; nombre de comptes réels avant = après (9) ; annonces (11) et commandes (0) inchangées ; aucun objet sans propriétaire dans `storage.objects` |

## 2. Fichiers et données de test

| Élément | Constat | Décision |
|---|---|---|
| Buckets `listing-images`, `chat-files`, `project-files` | **0 objet, 0 octet** en production | rien à nettoyer |
| Fichiers sans propriétaire | 0 | — |
| Commandes de test | **0 commande** en production | — |
| Événements de paiement | 0 (`payment_events`) | confirme qu'aucun paiement réel ni sandbox n'a été reçu |
| **11 annonces « plateforme »** sans vendeur (Lampe en bois recyclé, Drone éducatif, Sac à dos design…, stock 100, approuvées) | insérées **volontairement** par la migration `20261029000000_p0_securite.sql:25-37` (« catalogue de la plateforme côté serveur », AN-003). **Ce ne sont pas des données de test**, mais leurs prix et stocks sont ceux de la maquette | **décision métier requise** avant le lancement : produits réellement vendus par l'établissement, ou à retirer ou masquer |
| Journal d'audit | 86 lignes (84 « Connexion réussie », 1 « Accès refusé », 1 « Signalement envoyé ») issues des recettes | conserver (trace) |
| Données d'exemple dans le code (`lib/data/demo`) | affichées **seulement** sans serveur (`demoContent = !Backend.ready`) ou dans la couche `features` morte | aucun effet en production |
| Comptes de démonstration dans le code (`seedAccounts`, `auth.dart`) | utilisés hors connexion et dans la liste locale de l'administration (corrigée, voir rapport 02) | — |

## 3. Qualité technique

| Point | Constat (01/11) | Traitement |
|---|---|---|
| Erreurs d'analyse | 0 | — |
| Imports inutilisés | 3 (`account_menu.dart:4`, `:8`, `engage.dart:9`) + 1 import redondant dans un test | **corrigés** (rapport 02) |
| `use_build_context_synchronously` | 13 informations | non modifiées : ce sont des gardes `mounted` déjà présentes en amont, ou des contextes de dialogue. Analyse au cas par cas recommandée, sans changement automatique |
| Dépendances | à jour, sauf 2 correctifs mineurs (`flutter_svg` 2.3.2, `go_router` 18.1.2) et une version majeure de `qr` (4.0.1) — `donnees/pub_outdated.txt` | **non mises à jour** (aucun bénéfice démontré, risque de régression) ; `pubspec.lock` inchangé (empreinte vérifiée) |
| Couche morte | les 315 écrans passent par `lib/figma/registry.dart` (`gBuilders`) ; les classes `*Screen` de `lib/features` ne sont jamais construites, mais restent compilées et testées dans `test_legacy` | **non supprimée**, sur instruction. Documentée pour éviter de corriger au mauvais endroit |
| Duplications | 3 écrans au contenu fonctionnel en double (A2 = 231, P4 = 250b) — rapport 03 | décision métier |
| Écrans figés | les écrans modifiés à la main doivent figurer dans `tool/figma_export/bindings.json` (`_frozen`), sinon le générateur les écraserait | respecté pour chaque écran modifié |
| Configuration | `supabase/config.toml` absent : les réglages `verify_jwt` vivent en production (`pay` vrai, `notchpay-webhook` faux, `notchpay-mcp` vrai) | documenté |
