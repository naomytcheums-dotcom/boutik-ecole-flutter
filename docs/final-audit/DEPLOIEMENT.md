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

## Déploiement du 30/10/2026 (soir, reprise)
| Élément | Valeur | Preuve |
|---|---|---|
| Déploiement interrompu de Claude | **abouti** : build de `34efe61` servi, empreinte `448b9af1…` identique au build local | `curl` + SHA-256 |
| Code déployé | commit `980f163` (reprise : engagements réversibles, préférences, liens) | `git log` |
| Tests avant build | `flutter test` : 394 réussis | sortie |
| Build | `flutter build web --release` réussi | sortie |
| Version servie = build testé | SHA-256 de `main.dart.js` : `3c40979c3f16d3fed0fd176a4c97566a5ee5aa6761dbdb8983bdc4e9975c3cf9` des deux côtés | `Get-FileHash` |
| Vérification après déploiement | Playwright sur `https://boutik-ecole.vercel.app` : parcours 5/5, engagements 5/5, visiteur 12/12 | rapports |
| Migrations | aucune nouvelle | |
| MCP / webhook Notch Pay | inchangés : MCP 401 (Verify JWT), webhook 401 sans signature valide, aucun événement authentique | `curl` |

## Déploiement du 30/10/2026 (nuit, 2ᵉ reprise)
| Élément | Valeur | Preuve |
|---|---|---|
| Code déployé | commits `b488df6` → `60266f5` (application, tests, audit) | `git log` |
| Tests avant build | 401 Flutter ; 34/34 navigateur sur base isolée | sorties |
| Version servie = build testé | SHA-256 `main.dart.js` : `ae88a0f2987042e7bd5061668a9ba7087380055c40b8b602785823bd54a5d4dc` des deux côtés ; aucune adresse locale dans le bundle | `Get-FileHash`, recherche dans le bundle |
| Vérification après déploiement | Playwright production : 24/24 exécutés | rapport |
| Migration `20261031a` | **non appliquée** (pas d'accès) : les 28 actions qui en dépendent l'annoncent clairement | `production.spec.ts` |
| Fonction `notchpay-mcp` | code corrigé **non déployé** (pas d'accès) | `INTERVENTIONS_PROPRIETAIRE.md` §3 |

## Déploiement du 31/10/2026 (matin, 3ᵉ reprise)
| Élément | Valeur |
|---|---|
| Code déployé | `a86d3ff` → `0c18c17` (16 dernières actions, corrections) |
| Version servie = build testé | SHA-256 `061029c244ac7b21e1bbdae23fc20fd6f8dc9809499925e0d55d62de35ce9d9a` des deux côtés, aucune adresse locale dans le bundle |
| Vérification | Playwright production 27/27 ; MFA REST production 8/8 |
| Migrations `20261031a` et `20261031b` | **non appliquées en production** (constaté) |
| MCP | `MCP_ACCESS_KEY` configurée (constaté) ; appel authentifié à vérifier par le propriétaire |

## Déploiement du 31/10/2026 (18 h 42) — écran de retrait (C3, C4)
| Élément | Valeur |
|---|---|
| Code déployé | commit `69753e6` (seule modification de l'application depuis `0c18c17` : `lots.dart`, `backend.dart`) |
| Tests avant build | `flutter test` 405/405 (goldens inchangés) ; `flutter analyze` 0 erreur ; `retrait.spec` 1/1 et `lots2` « code de retrait » 1/1 sur la copie locale de la production |
| Version servie = build testé | SHA-256 `main.dart.js` : `0e6f976a1001d9d3cc6642b6e4b644bbdb2a8e82e494ea730a971537c50b7b84` des deux côtés ; aucune adresse locale ; aucun secret |
| Déploiement Vercel | `dpl_5VXXmTvNUZzvaU9ZaokJ47SqcrJu`, READY, alias `boutik-ecole.vercel.app` ; précédent (retour arrière) : `boutik-ecole-rmhifulr0-…` |
| Vérification après déploiement | `visiteur` 12/12, `retrait_en_ligne` 1/1, `connexion_en_ligne` 1/1 ; compteurs de production inchangés |
| Base, fonctions, secrets | inchangés (16 migrations ; `pay` v6, `notchpay-webhook` v6, `notchpay-mcp` v3) |
