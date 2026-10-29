# 00 — Synthèse exécutive de l'audit

Date : 29 octobre 2026 · Dépôt : branche `feat/figma-fidele` · Site : https://boutik-ecole.vercel.app · Mode : lecture seule (rien déployé, rien commité, aucune donnée de production créée ou modifiée).

## État réel du projet
Boutik-École est aujourd'hui **un prototype interactif très fidèle à la maquette, avec un squelette de backend**, et non une marketplace opérationnelle.
- **Ce qui est solide** : 315 écrans codés et fixés par des tests visuels ; 339 tests passent ; analyse statique sans alerte ; 948 liens de navigation sans cible cassée ; RLS efficace pour un visiteur anonyme (mesuré) ; aucun secret dans le dépôt ni son historique (recherche par motif) ; schéma de base de 9 tables ; fonction de paiement déployée.
- **Ce qui ne l'est pas** : presque toute la logique vit **en mémoire du navigateur** (95 états), seuls la connexion, les commandes, le journal et le paiement atteignent le serveur, et aucun écran n'est alimenté par la base. Deux utilisateurs ne partagent donc aucune donnée.

## Mise à jour du 29 octobre 2026 — correctifs P0
Les 3 failles critiques (AN-001, AN-002, AN-003) ont été corrigées sur la base de production et vérifiées par requêtes (compte jetable supprimé ensuite). Détail et preuves dans `09_REGISTRE_ANOMALIES.md`. Reste ouvert : 27 anomalies (P1 : 11, P2 : 13, P3 : 3).

**2e passe** : AN-004 (annonces) et AN-022 (journal) corrigées et testées en base ; fonction `pay` mise à jour et confirmée déployée ; application republiée. Le paiement reste non vérifié (clé Notch Pay absente). Anomalies ouvertes : 25.

## Problèmes bloquants (état à l'audit initial)
- **3 failles critiques (P0)** dans la configuration serveur : un utilisateur peut s'attribuer le rôle administrateur (AN-001) ; des comptes de démonstration, dont un administrateur, existent en production avec un mot de passe public (AN-002) ; les montants et l'état « payé » d'une commande sont choisis par le client (AN-003).
- **11 problèmes P1** : auto-validation d'annonce, rejeu de référence de paiement, connexion validée côté client, données non persistées, stock jamais décrémenté, numéros de commande en collision, erreurs ignorées, vérification simulée, tableaux de bord à données de démonstration, droits seulement dans l'interface, paiement non vérifié.
- **Décompte** : 30 anomalies — P0 : 3 · P1 : 11 · P2 : 13 · P3 : 3.

## Causes racines communes
1. **Pas de source de vérité serveur** : les écrans ont été branchés sur des états locaux pour aller vite.
2. **Sécurité pensée côté interface** : rôles, prix, validations contrôlés par l'application, pas par la base.
3. **Écrans générés depuis Figma** : fidèles visuellement, mais la logique doit être ajoutée écran par écran (222 écrans sans lien entrant, 192 actions « Démonstration »).
4. **Environnement unique** : démonstration et production confondues.

## Points positifs
Fidélité visuelle mesurée ; architecture de génération reproductible ; modules d'état bien séparés (`lib/figma/live`) ; schéma de base avec RLS déjà posé ; fonction de paiement qui contrôle l'utilisateur et le propriétaire de la commande ; build web déployable et en-têtes de sécurité de base.

## Prochaines actions (détail : `10_PLAN_CORRECTIF_PRIORISE.md`)
1. Séparer production et démonstration, supprimer les comptes de démonstration de la production (AN-002).
2. Corriger les politiques de la base (rôle, commandes, annonces) et le calcul des montants côté serveur (AN-001, 003, 004, 005).
3. Brancher les écrans sur la base (auth, annonces, commandes, stock) avant d'ajouter des fonctionnalités.
4. Tester le paiement en sandbox, puis écrire les tests de non-régression de sécurité.

## Limites de cet audit
Aucun parcours n'a été joué sur les données de production ; pas d'appareil Android/iOS ; clé de paiement absente ; tests négatifs de sécurité non exécutés (exploitabilité déduite du code) ; accessibilité et dépendances vulnérables non mesurées. Voir `08_TESTS_ET_RESULTATS.md`.

## Livrables
`docs/audit-boutik-ecole/` : 00 à 12 (ce dossier). Aucun fichier applicatif n'a été modifié.
