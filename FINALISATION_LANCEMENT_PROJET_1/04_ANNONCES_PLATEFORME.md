# 02 — Phase 2 : les 11 produits de la plateforme deviennent de vrais produits

Date : 01/11/2026. Commit local **`169c143`** (non poussé). Migration locale **`20261101000100_produits_plateforme.sql`** (non appliquée en production).

## A. Constat initial (preuves dans le code et en production, lecture seule)

| # | Défaut | Preuve |
|---|---|---|
| 1 | Le catalogue acheteur affichait des prix, des descriptions et des **noms de vendeurs fictifs** (« Mouanga Yannick »…) codés en dur, alors qu'en base ces produits n'ont **aucun vendeur** | `lib/figma/live/store.dart` (`liveCatalog`), migration p0 lignes 25 à 37 (`seller_id` null) |
| 2 | Les commandes de ces produits n'étaient **visibles par personne** pour être préparées : `seller_orders()` filtre sur `seller_id = auth.uid()` | `20261030000700_commandes_vendeur.sql` |
| 3 | Aucun écran ne permettait de gérer leur stock ou leur prix (seule une requête directe en base le pouvait) | `Backend.myListings()` limité à `seller_id = uid` |
| 4 | Un compte département ou administrateur pouvait **changer le vendeur** d'une annonce (`protect_listing_status` ne le figeait pas pour ces rôles) | définition en production (`prod_public_schema.sql`) |
| 5 | En production : stock de **100** fictif pour chacun des 11 produits, aucune photo, aucune commande, aucun mouvement de stock | `donnees/production_produits_plateforme_lecture.json` |
| 6 | En production : **aucun compte département ou administrateur réel** (seuls des comptes `zz-test`) | même fichier (`gestionnaires_reels = 0`) |

Ce qui fonctionnait déjà : `create_order` choisit l'annonce de la plateforme et recalcule les prix côté serveur ; le stock est décrémenté atomiquement ; le retrait au kiosque (31c) s'applique à toute commande payée.

## B. Corrections

**Serveur** (migration locale, aucune donnée modifiée, signatures inchangées) :
- `is_platform_manager()` : vrai pour les rôles `dept` et `admin` uniquement ; non exécutable par `anon` ;
- `seller_orders()` et `set_seller_order_status()` : le département et l'administrateur voient et font avancer **uniquement les lignes des produits de la plateforme**. Le vendeur étudiant ne voit toujours que ses lignes ;
- `protect_listing_status()` : le vendeur d'une annonce ne change plus jamais, même pour le département ou l'administrateur.

**Client** :
- `Backend.platformListings()` lit les produits publiés sans vendeur. Le catalogue acheteur en tire le prix, le stock, le département et la description. Le vendeur affiché est **« Boutik-École »**. La photo reste le visuel d'origine tant qu'aucune photo n'est déposée ;
- les produits épuisés ou retirés ne sont plus proposés ;
- si la première lecture n'a pas encore abouti, **aucun produit d'exemple** n'est présenté comme réel ;
- hors serveur, le catalogue des maquettes est **inchangé**, ce qui préserve les golden images ;
- le département et l'administrateur retrouvent les produits de la plateforme dans **Mon catalogue / Stocks** (écrans 61 et 62) et leurs lignes de commande dans **Commandes reçues / Préparer** (écrans 63 et 64).

## C. Tests

| Test | Où | Résultat |
|---|---|---|
| Migration : 28 cas couvrant les rôles, la RLS, les stocks, la préparation, le retrait au kiosque et la non-régression du vendeur | **réplique locale**, transaction annulée | **28/28** (`donnees/test_migration_20261101000100_replique.txt`) |
| Flutter : `platform_products_test` (7 nouveaux), `listings_server_test`, `seller_orders_server_test`, `orders_real_test` | local | **19/19** (`donnees/flutter_test_phase2.txt`) |
| Golden images : écrans 01 à 19, 39, 57, 61 à 64 et 170 | local | **26/26 identiques** (`donnees/flutter_golden_phase2.txt`) |
| Requêtes PostgREST (`seller_id=is.null`, filtre `or=(…)`) | réplique locale | acceptées : 12 lignes |
| `flutter analyze` sur les 3 fichiers modifiés | local | 0 erreur (3 avertissements d'information préexistants) |

**Aucun test de production** : la migration n'y est pas appliquée et le site n'est pas redéployé.

## D. Incident pendant les tests (réplique locale uniquement)

Le premier lancement du script a remplacé le marqueur de la migration **aussi dans un commentaire**. Le `BEGIN` a alors été absorbé par une erreur de syntaxe et le script s'est exécuté **hors transaction sur la réplique Docker locale**.

Effets mesurés :
- la migration appliquée ;
- 2 stocks modifiés (Confiture artisanale 99 → 1 ; zz-test-msg 9 → 10) ;
- 3 mouvements de stock (n° 73 à 75) et 4 lignes d'historique (n° 92 à 95).

Aucune commande, notification ni entrée de journal n'a été créée.

Restauration en une transaction :
- stocks rétablis, déclencheurs suspendus pour ne créer aucun mouvement ;
- les 7 lignes supprimées ;
- les fonctions d'origine réappliquées et `is_platform_manager` supprimée.

Vérifié ensuite : stocks à 99 et 9, derniers identifiants à 72 et 91, fonction absente.

Correction du script : le marqueur est désormais une ligne entière unique (`--@@MIGRATION@@--`), l'exécution s'arrête à la première erreur jusqu'à la fin de la migration, et le lanceur `outils/executer_test_replique.ps1` refuse de s'exécuter si le marqueur n'apparaît pas exactement une fois. **La production n'a pas été touchée.**

## E. Mémoire de la machine

La compilation des tests est restée bloquée 25 minutes (0,35 Go de RAM libre, 59,0 Go engagés sur 62,6 Go). Je n'ai arrêté qu'un `flutter test` orphelin du 30/10, issu d'une session précédente (PID 42236, 35984 et 38464), ainsi que mon propre lancement interrompu.

Résultat : 3,6 Go de mémoire engagée libérés. Le serveur `flutter run` du 29/10 (port 8080) a été **laissé en marche**.

## F. Reste à faire (autorisation ou décision du propriétaire)

1. **Appliquer `20261101000100`** en production. Elle dépend logiquement de `20261101000000`, qui n'est pas appliquée non plus. Puis redéployer le site.
2. **Créer au moins un compte département ou administrateur réel**. Sans lui, les commandes des produits de la plateforme ne peuvent pas être préparées.
3. **Saisir les vrais stocks** à la place des 100 fictifs, confirmer les prix, puis déposer des photos. Après déploiement, l'écran 62 suffit.
4. Décider si « Logo et identité visuelle » et « Cours de soutien en maths », qui sont des **prestations**, restent vendus comme des produits en stock ou passent en services (devis).
5. Écran 05 (fiche produit) : la mention de vendeur affiche « Boutik-École », mais d'autres éléments de la maquette restent figés (note, avis). Ils sont traités dans le lot 5 (catalogue).
