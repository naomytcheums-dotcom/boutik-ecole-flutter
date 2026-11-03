# Sécurité et permissions

## Ce que ce lot a fait

Aucune politique RLS, aucune fonction serveur et aucune migration n'a été modifiée ni appliquée. Aucune clé n'a été lue ni changée. Aucun paiement, aucune notification réelle, aucun compte créé.

Côté application : les erreurs techniques du serveur ne sont plus affichées (`Backend.userMessage`) ; un visiteur est invité à se connecter avant une action réservée (`requireLogin` pour la certification).

## État connu (documents du dépôt, non revérifié par ce lot)

Les audits des 29 au 31/10/2026 (`docs/audit-boutik-ecole/06_SECURITE_ET_PERMISSIONS.md`, `09_REGISTRE_ANOMALIES.md`, `docs/final-audit/SECURITE_ET_RLS.md`) indiquent : élévation de rôle par `UPDATE profiles` **corrigée** (déclencheur `trg_protect_profile`, vérifiée en production avec un compte jetable) ; comptes de démonstration invalidés ; paiement : montants et références calculés ou contrôlés côté serveur, webhook signé (HMAC), anti-rejeu ; **AN-013 : le contrôle d'accès par rôle des écrans d'administration n'existe que dans l'interface** (état local) ; messagerie et commandes filtrées par propriétaire par RLS ; tests d'isolation entre deux comptes non exécutés en conditions réelles.

## Rôles demandés et existants

Existants côté serveur (`app_role`) : 10 valeurs dont student, client, company, dept, finance, support, direction, admin. Demandés et absents : modérateur, professionnel, administrateur de communauté (rôle **par communauté**, pas global : table `community_members`). Les droits premium se lisent dans `subscriptions`, pas dans `profiles.role`.

## Règles à respecter pour les extensions

1. Toute permission est une politique RLS ou une fonction `security definer` qui vérifie `auth.uid()` ; jamais une valeur envoyée par le client.
2. Aucune table de publications, de communautés, d'abonnements ou de campagnes n'accorde d'écriture directe ; l'écriture passe par des fonctions qui valident (comme `engage`).
3. Les statuts de paiement ne changent que dans la fonction qui a vérifié le prestataire.
4. Toute action d'administration est journalisée (`audit_log`).

## À vérifier avant toute recette

Tests de permissions sur une **base de test isolée** avec un compte par rôle (prérequis P-04 à P-09 de la phase 7).
