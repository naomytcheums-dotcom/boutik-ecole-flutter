# 03 — Phase 3 : lot 1, les 7 écrans orphelins ou doublons

Date : 01/11/2026. Commit local **`d5883bb`** (non poussé). Aucune migration ; aucune modification de la production.

## A. Principe retenu

Comme 150-2, 150-3 et 183, déjà raccordés, chaque écran d'état s'affiche **quand l'état se produit réellement**, jamais par un simple lien.

Hors serveur (catalogue des écrans, golden images), la maquette reste affichée à l'identique.

## B. Écrans raccordés (3)

| Écran | Déclencheur réel | Contenu réel | Preuve |
|---|---|---|---|
| **150-4** Mes commandes (vide) | « Mes commandes » (45) d'un compte connecté, quand le serveur a **répondu** et qu'il n'y a aucune commande. Retour à 45 dès qu'une commande existe. | Message et bouton « Découvrir la boutique » de la maquette | `lot1_etats_test` : 2 tests |
| **275** Déposer un produit (erreurs) | « Publier » ou « Brouillon » sur 58 avec **au moins deux** champs invalides (une seule erreur reste affichée sous son champ dans 58) | Valeurs saisies, en lecture seule, et messages d'erreur réels. Le faux « Votre brouillon est enregistré » est remplacé par « Rien n'a été enregistré ». « Continuer » ramène à 58. | 3 tests |
| **150-1** Synchronisation | « Réessayer » sur 150-3 ou 183 une fois le réseau **réellement** revenu, compte connecté | Relecture réelle des favoris, des messages, des commandes et du catalogue. Pourcentage, libellés, heure de dernière synchronisation complète et disponibilité calculés à partir des réponses. « Synchroniser maintenant » relance. Le texte qui promettait une file d'attente hors ligne (inexistante) est remplacé. | 4 tests |

Correction liée : `Backend.myOrders()` renvoyait une liste vide en cas d'échec réseau, ce qui se confondait avec « aucune commande ». Il renvoie désormais `null` ; la dernière liste connue reste affichée.

## C. Écrans non raccordés (4), avec leur motif

| Écran | Constat vérifié | Ce qui manque |
|---|---|---|
| **A2** Accueil Kéla | **Identique** à 231 : mêmes 19 textes, mêmes cibles, 1 lien de moins | Décision : fusion avec 231 (recommandé) ou rôle distinct |
| **P4** Nouvelle publication | Variante de 250 (choix « Photo ou vidéo », Google Drive) | La publication elle-même **n'existe pas** : 250 n'a ni action « Publier » ni table. Lot 8, règles des reels. |
| **250b** Nouvelle publication | Variante de 250 avec « Comptes suggérés » (mentions) | Idem |
| **S1** Démarrage animé | Écran de chargement (barre de progression, « Chargement… ») | Décision : animation avant 01 ou non |

## D. Tests (tous locaux)

| Test | Résultat |
|---|---|
| `lot1_etats_test` (9 nouveaux) avec `orders_real_test`, `platform_products_test` et `listings_server_test` | **24/24** |
| `demo_journey_test` (parcours de bout en bout) | **1/1** |
| Golden images 150-1, 150-3, 150-4, 275, 45, 58 et 183 | **7/7 identiques**, après correction d'un écart de 0,29 % sur 275 dû à un retour à la ligne ajouté puis retiré |
| `flutter analyze` sur les 8 fichiers modifiés | 0 erreur |

Remarque : le dossier `test/golden/failures` est suivi par Git. Les 4 images de 275 écrites par l'essai en échec ont été remises à leur version commitée (`git checkout` de ces 4 fichiers uniquement).

**Aucune vérification en production** : le site n'est pas redéployé.

## E. Matrice

Les statuts de 150-1, 150-4 et 275 passent à **CONNECTÉ ET FONCTIONNEL** (preuve locale). P4 et 250b passent à **BLOQUÉ PAR UNE DÉPENDANCE** (lot 8). A2 reste **DOUBLON** et S1 **ORPHELIN**, en attente de décision.

| Statut | Avant | Après |
|---|---|---|
| CONNECTÉ ET FONCTIONNEL | 9 | **12** |
| BLOQUÉ PAR UNE DÉPENDANCE | 6 | 8 |
| ORPHELIN | 4 | 1 |
| DOUBLON | 3 | 1 |
| autres | 293 | 293 |
