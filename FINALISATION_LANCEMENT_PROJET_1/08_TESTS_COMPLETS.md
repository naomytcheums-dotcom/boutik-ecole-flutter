# 08 — Tests complets (phase 7)

| Suite | Où | Résultat |
|---|---|---|
| Flutter (unitaires, widgets, golden images des 315 écrans, parcours de démonstration) | local | **462/462** |
| `flutter analyze` | local | 0 erreur, 0 avertissement (21 remarques d'information préexistantes) |
| REST complet (17 suites, 386 cas), avec les 4 migrations | réplique locale | **386/386** |
| Migration administration (20261101000000) | réplique, transaction annulée | 20/20 |
| Migration produits plateforme (…0100) | réplique, transaction annulée | 28/28 |
| Migration concours (…0200) | réplique, transaction annulée | 38/38 |
| Migration livraison (…0300) | réplique, transaction annulée | 22/22 |
| Migration parrainage et gains (…0400) | réplique, transaction annulée | 19/19 |
| Migration notifications (…0500) | réplique, transaction annulée | 12/12 |
| Catalogue de production = réplique, après les 4 migrations | **production** | 0 écart |
| Empreintes des données (35) avant et après les migrations | **production** | 34/35 identiques (seul l'historique change) |
| Empreintes avant et après le déploiement et les tests en ligne | **production** | 35/35 identiques |
| REST anonyme sur les nouvelles fonctions | **production** | 14/14 |
| Playwright : visiteur, connexion refusée, retrait simulé, démarrage S1 | **site en ligne** | 15/15 |
| Version servie = build | **site en ligne** | SHA-256 `706cb391…` identique |

Non réalisés :
- parcours authentifiés en production (il faudrait des comptes de recette et des commandes payées) ;
- Firefox et WebKit ;
- APK sur appareil ;
- iOS ;
- paiement sandbox.
