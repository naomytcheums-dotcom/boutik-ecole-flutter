# 07 — Travaux restants, par priorité

> Aucune tâche n'a été commencée. Aucune suppression d'écran ni de fonctionnalité n'est proposée. Les difficultés sont estimées en
> taille relative (S ≤ ½ jour, M ≈ 1-2 jours, L ≥ 3 jours).

## P0 — Sécurité ou blocage critique

| # | Tâche | Résultat attendu | Fichiers concernés | Dépendances | Difficulté | Risque | Critère d'acceptation | Test nécessaire |
|---|---|---|---|---|---|---|---|---|
| P0-1 | **Renouveler les clés Notch Pay** (exposées), puis valider **un** paiement sandbox de bout en bout | `NOTCHPAY_KEY`/`NOTCHPAY_HASH` neufs ; un paiement sandbox confirmé par un webhook signé authentique | secrets Supabase (aucun fichier source) ; `supabase/functions/pay`, `notchpay-webhook` (sans modification attendue) | votre autorisation ; compte Notch Pay | S | faible (sandbox) | `payment_events` contient l'événement ; commande `paid=true` ; rejeu refusé | `supabase/tests/webhook_e2e.py`, `pay_e2e.py` en sandbox ; lecture MCP `boutik_recent_webhook_events` |
| P0-2 | **Remplacer le faux « mot de passe oublié »** | e-mail de réinitialisation Supabase et changement réel du mot de passe ; plus aucun code `482917` | `lib/figma/live/auth.dart:488-517` (`submitForgot`, `submitReset`), écrans 15 et 16 ; modèle d'e-mail Supabase | choix e-mail ou SMS (06 §5-1) ; URL de redirection autorisée dans Supabase Auth | M | moyen (parcours d'authentification) | connexion réussie avec le nouveau mot de passe ; message neutre si le compte n'existe pas | test widget + test navigateur sur la réplique ; recette en production avec un compte autorisé |
| P0-3 | **Administration des comptes réelle** (rôle, suspension) | RPC `admin_set_role` et `admin_set_suspended` (SECURITY DEFINER, admin seulement, journal) ; écran 128 relié ; liste des comptes lue sur le serveur | nouvelle migration ; `lib/figma/live/admin.dart` ; `g_128.dart` | P0 déjà en place (`protect_profile_authority`) ; votre autorisation de migration | M | **élevé** (droits) | un admin change un rôle ; un non-admin est refusé (403 ou erreur RLS) ; le compte suspendu ne peut plus se connecter | test de sécurité REST (escalade refusée) + test widget |

## P1 — Fonctionnalités essentielles

| # | Tâche | Résultat attendu | Fichiers | Dépendances | Difficulté | Risque | Acceptation | Test |
|---|---|---|---|---|---|---|---|---|
| P1-1 | Supprimer les **9 faux succès** (14, 64, 164, 165, 167, 192, 194, 195, 210) | chaque bouton enregistre réellement (brouillons de mission, question à l'admin, signalement, messages) ou explique honnêtement qu'il n'est pas disponible | `g_64`, `g_164`, `g_165`, `g_167`, `g_192`, `g_194`, `g_195`, `g_210`, `g_14` ; `lots.dart`, `messages.dart` | RPC existantes (`mission_messages`, `report_listing`…) ; écrans figés dans `tool/figma_export/bindings.json` (`_frozen`) | M | faible | plus aucun `gToast` de succès sans appel serveur (script `messages_seuls_ecrans`) | goldens inchangés + tests widget |
| P1-2 | Signalements du support réels (131, 170) | lecture de `listing_reports`, actions de modération serveur, compteurs calculés | `lib/figma/live/ops.dart` | rôle support | M | faible | compteurs = nombre réel de lignes | test REST + widget |
| P1-3 | **Recette authentifiée en production**, avec autorisation : retrait réel (support), inscription, MFA, devis, missions | preuves en production pour les 36 fonctionnalités « IMPLÉMENTÉE NON VÉRIFIÉE » prioritaires | `e2e/tests/*.spec.ts` existants | P0-1 (paiement) ; comptes de recette ; nettoyage `zz-test` | L | moyen (données de test en production) | rapport de recette, puis nettoyage | Playwright existants |
| P1-4 | Nettoyage des comptes `zz-test` | aucun compte de test en production | `supabase/maintenance/cleanup_test_accounts.sql` | votre autorisation | S | moyen (suppression) | requête de contrôle = 0 compte `zz-test-%` | lecture SQL |
| P1-5 | Relier les écrans sans parcours : 176 (après le rôle « client »), 150-4 (liste vide), 150-1 (retour de connexion), 275 (erreurs de dépôt) | 0 écran de catégorie 4 ou 5 | `auth.dart` (`submitRole`), `system_states.dart`, `g_45`, `g_287`/`g_288` | — | S | faible | `outils/inventaire_ecrans.py` : catégories 4 et 5 = 0 | goldens + test de navigation |

## P2 — Fonctionnalités importantes

| # | Tâche | Résultat attendu | Fichiers | Difficulté | Acceptation |
|---|---|---|---|---|---|
| P2-1 | Interface de **révocation et de décision de certification** | menu dept/admin → `revoke_certificate`, `decide_certification` | `lots.dart`, `account_menu.dart` | S | certificat révoqué → `verify_certificate` le signale |
| P2-2 | Classement réel des hackathons | classement calculé sur les notes du jury, côté serveur | `hackathons.dart` + migration | M | aucune équipe fictive en production |
| P2-3 | Jeton de borne signé par le serveur | session QR émise et consommée par une RPC | `missions.dart` + migration | M | rejeu refusé côté serveur |
| P2-4 | Tableaux de bord : inventaire des chiffres affichés et branchement sur des vues SQL | aucun chiffre figé en production | 57, 108, 117, 127, 139, 187 | L | chaque indicateur relié à une requête |
| P2-5 | MCP : aligner `verify_jwt` et la documentation, puis tester avec la vraie clé | appel authentifié réussi ; `?key=` refusé | `supabase/functions/notchpay-mcp/index.ts` (commentaire), réglage de la fonction | S | `mcp_e2e.py` vert en production |
| P2-6 | Erreurs de fichiers explicites | plus d'échec silencieux d'envoi ou d'URL signée | `backend.dart:307-346, 541-570, 710-726` | S | message d'erreur affiché |
| P2-7 | Export de données automatique (RGPD) | fichier d'export généré pour l'utilisateur | `engage.dart`, Edge Function ou RPC | M | export téléchargeable |
| P2-8 | Paiements annexes (contributions, duels, mise en avant, retrait des gains) | une fois P0-1 validé | `pay.dart`, écrans 84b, 219, 243, 250 | L | paiement sandbox confirmé |

## P3 — Améliorations et finitions

| # | Tâche | Difficulté |
|---|---|---|
| P3-1 | Corriger les 3 avertissements et les 13 `use_build_context_synchronously` de `flutter analyze` | S |
| P3-2 | Trancher A2, P4, 250b, S1 (doublons et échantillons) **avec vous**, sans les supprimer d'office | S |
| P3-3 | Retirer l'écran 14 (code SMS de démonstration) du parcours ou le brancher sur un vrai OTP | S |
| P3-4 | Raccourcir les parcours de 6 à 10 étapes | M |
| P3-5 | Documenter que `lib/features/**/s*_screen.dart` est une couche morte (ou la retirer **après accord**) pour éviter les corrections au mauvais endroit | S |
| P3-6 | Couverture de code (`flutter test --coverage`) et tests des RPC non couvertes | M |
| P3-7 | Notifications push, e-mail et SMS (si elles entrent dans le périmètre) | L |
| P3-8 | Localisation des écrans générés (si plusieurs langues sont prévues) | L |

## Ordre recommandé

P0-1 → P0-2 → P0-3 → P1-1 → P1-5 → P1-2 → P1-4 et P1-3 (recette) → P2.
