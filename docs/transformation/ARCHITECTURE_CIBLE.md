# Architecture cible (état au 03/11/2026, lot 1)

Branche `transformation-ecosysteme-20261103`, créée à partir de `f129386` (branche d'origine `ux-audit-20261101`). État initial sauvegardé dans `C:\Users\NITROV15\Documents\Boutik-Ecole-Audit-Backups\etat_initial_transformation_20261103_190014\` (patch des modifications non commitées, copie des fichiers non suivis).

## 1. Ce que le dépôt est réellement (lu dans le code et les migrations, pas déduit des maquettes)

| Couche | Réalité |
|---|---|
| Écrans | 315 écrans générés depuis Figma dans `lib/figma/g/*.dart` par `tool/figma_export/convert.py` : positions absolues (`gP(x, y, w, h, …)`) dans une toile de taille fixe (390 px mobile, 1280 px web). `bindings.json` branche des données ; une liste `_frozen` protège les écrans modifiés à la main (dont 42). |
| État et logique | 40 modules Riverpod dans `lib/figma/live/` (store, auth, chat, missions, concours, livraison, parrainage, notifications…). Une couche ancienne `lib/features` (377 fichiers) est masquée par les écrans générés. |
| Données | Supabase : 25 migrations dans `supabase/migrations/` (9 appliquées en production avant le 29/10, 4 le 01/11 sur autorisation du propriétaire, le reste local) ; fonctions `pay`, `notchpay-webhook`, `notchpay-mcp`. |
| Mode hors connexion | `demoContent = !Backend.ready` : sans serveur, des données d'exemple s'affichent. |

## 2. Causes structurelles trouvées (démontrées par le code)

1. **Toile à positions absolues dans une toile fixe** : explique "maquette de téléphone dans le navigateur". Un correctif de composition plein écran pour téléphones existe dans `GScreen._phone` (voir RESPONSIVE_PWA.md).
2. **Textes figés de la maquette dans les écrans** : l'écran 42 contenait les lignes, les frais et le total de la maquette ; 43 une référence et un montant figés ; 46 un statut et une chronologie figés. Corrigé (section 4).
3. **Commande d'exemple fabriquée quand il n'y a aucune commande** : `lastOrderProvider` renvoie `#BE-2026-0142` avec le panier courant. Les écrans de détail l'affichaient comme une commande réelle. Corrigé pour le mode connecté (redirection).
4. **Erreurs serveur transmises brutes à l'interface** : `Backend.requestCertification` renvoyait `e.message`. Corrigé.
5. **Cible de l'onglet Messages codée dans le générateur** (`NAV_DEST['icon/chat']`) et dans 93 fichiers. Corrigé aux deux niveaux.

## 3. Principe retenu : une source de vérité, pas de doublon

| Donnée | Source existante à étendre (jamais dupliquer) | Manque |
|---|---|---|
| Profil | `profiles` | couverture, visibilité des champs, centres d'intérêt |
| Publications | `posts` (reels : média obligatoire, statut pending/published/hidden), `post_likes`, `post_reports` | type texte/lien/projet/produit/événement, visibilité, commentaires, partages, enregistrements |
| Abonnements sociaux | `engagements` avec `kind = 'follow'` | lecture des abonnés / abonnements, compteurs |
| Messagerie | `conversations`, `conversation_participants`, `messages`, vues de liste et de non-lus | blocage, signalement de conversation |
| Notifications | `notifications`, `notification_preferences`, `device_tokens`, `notification_outbox` | générateurs d'événements ; aucun envoi réel n'est branché |
| Produits, commandes, paiements | `listings`, `orders`, `order_lines`, fonction `pay` + webhook signé | multi-prestataires |
| Communautés | rien | tables à créer, en réutilisant `profiles`, `posts`, `notifications` |
| Plans et abonnements payants | rien | tables à créer |
| Campagnes | `post_boosts` = visibilité gratuite (série de 6 jours), pas une campagne | tables à créer, liées à `posts` et `listings` |

## 4. Livré dans ce lot

- Module `lib/figma/live/order_summary.dart` : récapitulatif et chronologie de commande partagés (écrans 42, 43, 46, 47).
- `lib/core/domain/feed_ranker.dart` : classement du fil, **non branché**.
- `lib/core/domain/abonnements_campagnes.dart` : droits premium et cycle des campagnes, **non branché**.
- Tests : `test/purchase/coherence_commande_test.dart`, `test/domain/ecosysteme_domaine_test.dart`.

## 5. Architecture visée (inchangée dans son principe)

Présentation (écrans `lib/figma`) → états Riverpod (`lib/figma/live`) → règles pures (`lib/core/domain`) → accès aux données (`backend.dart`) → Supabase (RLS + fonctions `security definer`). Les règles de droits, de paiement et de campagne s'appliquent **côté serveur** ; le code Dart de `lib/core/domain` en est la spécification testable, pas la protection.
