# Déploiement (30/10/2026)

| Élément | Valeur | Preuve |
|---|---|---|
| Code testé et déployé | commit `8962202` (navigation, favoris) ; documentation `b72a56e` ajoutée ensuite (sans changement de code) | `git log` |
| Build | `flutter build web --release` réussi | sortie du build |
| Hébergement | Vercel, `https://boutik-ecole.vercel.app` | |
| Version servie = build testé | empreinte SHA-256 du `main.dart.js` servi identique à celle du build local (`8fe15946…`) ; le fichier contient « Mes rubriques » | comparaison par `sha256sum` |
| Fonction `notchpay-webhook` | déployée avec diagnostic ; POST sans signature → 401, fausse signature → 401, GET → 405 | requêtes `curl` |
| Migrations | `20261029`, `20261029b`, `20261030`, `20261030b` appliquées | colonnes et fonctions vérifiées depuis l'extérieur |

## Limites
- Les parcours critiques n'ont pas été rejoués dans le navigateur après déploiement (outil de navigation inadapté au canvas Flutter) ; vérification limitée à l'empreinte du build et aux appels API.
- Les journaux Vercel n'ont pas été inspectés.
- Une seule base Supabase sert à la démonstration et à la production.

## Déploiement du 30/10/2026 (soir) — annonces, stock, messagerie, notifications
| Élément | Valeur | Preuve |
|---|---|---|
| Code déployé | commit `893214f` (la documentation `19fbce7` n'a pas d'effet sur le build) | `git log` |
| Tests avant build | `flutter test` : 355 réussis ; `flutter analyze` : 2 infos | sorties |
| Build | `flutter build web --release` réussi | sortie du build |
| Version servie = build testé | empreinte SHA-256 de `main.dart.js` identique (`b36cc89c…`) ; le fichier contient `unread_counts` / `cancel_order` | `sha256sum` |
| Migrations appliquées sur la base de production | `20261030c` (annonces, stock, images), `20261030d` (messagerie, notifications), `20261030e` (correctif non-lus) | triggers et buckets vérifiés ; 17+23+26+9 contrôles REST |
| Fonction `notchpay-mcp` | déployée ; atteignable avec la clé publique Supabase ; **non publique** tant que « Verify JWT » n'est pas désactivé | client MCP officiel + `curl` |
| Données de test | supprimées après chaque série (comptes, annonces, commandes, conversations, favoris, images) | requêtes de nettoyage |

Limites : parcours non rejoués dans un navigateur après déploiement (outil inadapté au canvas Flutter) ; journaux Vercel non inspectés ; une seule base pour démonstration et production.

## Déploiement du 31/10/2026 — messagerie complète, vendeur, acheteur
| Élément | Valeur | Preuve |
|---|---|---|
| Code déployé | commit `b8cfa04` (la documentation `7f36c50` n'a pas d'effet sur le build) | `git log` |
| Tests avant build | `flutter test` : 372 réussis | sortie |
| Version servie = build testé | empreinte SHA-256 de `main.dart.js` identique (`998171a7…`) ; contient `start_order_conversation`, `seller_orders`, `chat-files` | `sha256sum` |
| Migrations appliquées sur la base de production | `20261030f` (liste des conversations), `20261030g_messagerie_commande_pieces_jointes`, `20261030h_commandes_vendeur` | fonctions et buckets vérifiés par les tests REST |
| MCP Notch Pay | URL publique **toujours 401** (« Verify JWT » actif sur `notchpay-mcp`) | `curl` |
| Webhook Notch Pay | aucun nouvel événement dans les journaux | tableau de bord |
