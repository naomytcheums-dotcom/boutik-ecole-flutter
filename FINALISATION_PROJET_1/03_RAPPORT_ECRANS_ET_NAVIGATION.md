# 03 — Écrans et navigation

> Base : l'inventaire mesuré le 31/10 (`AUDIT_REPRISE_20261031/02_INVENTAIRE_ECRANS_ROUTES.md`, 315 écrans) et les modifications du
> 01/11 (`6364a6d`, local).

## 1. Situation

| Catégorie | 31/10 | 01/11 (local) | Changement |
|---|---|---|---|
| Accessibles directement | 15 | 15 | — |
| Accessibles indirectement | 189 | 189 | — |
| Conditionnels (rôle ou état système) | 103 | **104** | 176 relié par le menu du compte (rôle client) |
| Route sans point d'entrée actif | 2 | 2 | 150-1, 275 |
| Réellement orphelins | 3 | **2** | 150-4, S1 |
| Doublons potentiels | 3 | 3 | A2, P4, 250b |
| **Total** | 315 | 315 | aucun écran supprimé |

## 2. Décision écran par écran

| Écran | Fonction | Doit-il être accessible ? | Point d'entrée retenu | Décision |
|---|---|---|---|---|
| 176 Bienvenue (client) | onboarding du rôle client (177 l'est pour l'entreprise) | oui | menu du compte « Premiers pas (client) », rôle client | **relié** (`account_menu.dart`) |
| 150-2 Session expirée | état système | oui, automatiquement | `system_states.dart` | inchangé (conditionnel) |
| 150-3, 182, 183 | hors connexion | oui, automatiquement | `system_states.dart` | inchangé |
| 150-1 Synchronisation | état transitoire au retour du réseau | facultatif | aujourd'hui, un message « Connexion rétablie » s'affiche déjà | **non relié** : à décider (un écran plein pour une resynchronisation instantanée n'apporte rien) |
| 150-4 Mes commandes (vide) | état vide de la liste 45 | oui, s'il est préféré à l'état vide intégré à 45 | « Mes commandes » sans commande | **non relié** : un basculement automatique 45 → 150-4 provoquerait un clignotement pendant le chargement ; à décider avec la maquette |
| 275 Déposer un produit (erreurs) | variante « erreurs de validation » du formulaire de dépôt | non : le formulaire réel affiche ses erreurs sous les champs | — | **non relié**, gardé comme référence de maquette |
| A2 Accueil Kéla | doublon de 231 (même classe) | non | — | décision : retirer du parcours (déjà le cas) ou fusionner |
| P4, 250b Nouvelle publication | doublons de 250 | non | — | idem |
| S1 Démarrage animé | animation de lancement | à décider | éventuellement avant 01 | décision |

Aucun écran n'a été supprimé.

## 3. Routes, permissions et liens profonds

| Contrôle | Résultat | Preuve |
|---|---|---|
| Les 315 routes `/s/:id` résolvent un écran (`gBuilders` = manifeste, 315/315) | conforme | `AUDIT_REPRISE_20261031/02` §1 |
| Écran inexistant → « Écran introuvable » | conforme | Playwright en production (31/10) |
| Écran réservé, visiteur → 404 neutre et journal « Accès refusé » | conforme | Playwright en production (31/10) |
| Lien direct rechargé, retour arrière du navigateur | conforme | Playwright en production (31/10) |
| Lien de réinitialisation → écran 16 | **nouveau** : `app.dart` ouvre 16 sur l'événement `passwordRecovery` | revue de code ; non testé en navigateur |
| Nouvelles entrées du menu filtrées par rôle | « Premiers pas » (client), « Révoquer un certificat » (département, admin), « Demandes de certification » (admin) | `account_menu.dart` |

## 4. Parcours par rôle

La garde **côté client** (`access.dart`) est vérifiée en production pour le visiteur (31/10). **Aucun parcours authentifié par rôle
n'a été rejoué en production** : cela exigerait des comptes de recette, ce qui est interdit sans votre autorisation. Les droits
**serveur** des nouvelles fonctions sont vérifiés par rôle sur la réplique (client, support, département, administrateur, anonyme :
rapport 05 §3).
