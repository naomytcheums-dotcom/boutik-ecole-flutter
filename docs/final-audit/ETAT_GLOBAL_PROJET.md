# État global du projet Boutik-École — 31/10

Légende : ✅ vérifié en production · 🟡 vérifié localement (réplique exacte), en attente d'une opération autorisée · ⛔ bloqué / non vérifiable.

## Synthèse

| Domaine | État | Preuve | Ce qui manque |
|---|---|---|---|
| Application web (315 écrans, goldens) | ✅ servie (`061029c2…`) | SHA-256 du bundle ; 403/403 Flutter ; régression production 16/16 | — |
| Navigation, visiteur, rôles côté interface | ✅ | `visiteur` 12/12 en production ; `parcours` sur réplique | — |
| Authentification + MFA TOTP | ✅ | MFA REST production 8/8 (reprise précédente) ; `mfa` navigateur sur réplique ; 2 facteurs enrôlés en production | — |
| Marketplace, annonces, stock, commandes vendeur | ✅ | migrations 30c/30h en production (identiques) ; suites REST 386/386 sur réplique | — |
| Messagerie (annonces, commandes, pièces jointes) | ✅ | 30d–30g en production ; REST sur réplique | — |
| Avis, réclamations, signalements | ✅ | 30i en production ; `avis` 9/9 navigateur sur réplique | — |
| Services et devis | ✅ | 30j en production ; `devis` 5/5 sur réplique | — |
| Engagements | ✅ | 30k en production ; `engagements` navigateur | — |
| Missions, propositions, affectations, jalons | 🟡 | **31a + 31c en production** : politique unique `missions : visibilité restreinte`, contrôles `auth.uid()` explicites (catalogue = copie locale, 41/41 contrôles) ; parcours authentifiés : `lots_rest` 77/77 et `security_31` 24/24 en local | recette authentifiée en production (comptes du personnel) |
| Vœux, campagnes, projets, lives, liens de profil | 🟡 | **31a + 31c en production** (`save_project` : approuvé modifié → revalidation) ; parcours authentifiés vérifiés en local seulement | idem |
| Certificats (émission, vérification QR, révocation) | 🟡 | **31a + 31c en production** : codes 64 bits, contrainte 8 ou 16 hexa ; `verify_certificate` 200 « introuvable » | émission à recetter avec un compte `dept` |
| Bornes (incidents, événements) | 🟡 | **31a en production** : 4 bornes lisibles publiquement, incidents réservés (401 anonyme) | parcours support à vérifier avec un compte `support` |
| Paramètres administrateur, modèles de notification, clés API | 🟡 | **31b en production** : établissement lisible publiquement, modèles et clés réservés (401 anonyme), `key_hash` illisible ; parcours admin non rejoués (aucun compte du personnel) | comptes du personnel pour la recette |
| Fichiers (compartiment privé `project-files`) | 🟡 | **31b + 31c en production** : compartiment privé, 3 politiques de stockage, `register_file` réservé aux parties pour la portée mission | dépôt réel à recetter |
| Messagerie de mission | 🟡 | **31b + 31c en production** : écriture réservée aux parties (`is_mission_party`), fichier joint lié à l'expéditeur | recette authentifiée |
| Liens CV (`/#/cv/<token>`) | 🟡 | **31b en production** : `shared_cv` répond (`null` pour un jeton inconnu) | parcours authentifié à rejouer |
| Codes de retrait | 🟡 | **31b + 31c en production** : `gen_random_bytes`, essais comptés et journalisés, blocage à 5 ; interface `confirmPickupDialog` corrigée **non déployée** : l'interface en ligne affiche « Remise confirmée » quand le serveur répond `'incorrect'` (la commande n'est pourtant **pas** remise et l'essai est journalisé) — sans effet aujourd'hui (0 compte `support`/`admin`, 0 commande payée), anomalie C3 | déploiement web **avant** toute ouverture du kiosque |
| Paiement `pay` | 🟡 | correctif 15/15 ; version déployée 6/15 | déploiement de `pay` |
| Webhook Notch Pay | 🟡 | correctif 20/20 ; en production : 401 sans signature ; **0 événement réel reçu** | déploiement + paiement sandbox réel |
| MCP Notch Pay | ⛔ | code du dépôt 27/27 ; déployé = `814db47` (`?key=` accepté) | redéploiement `--no-verify-jwt` |
| Historique des migrations | ✅ régularisé le 31/10 (14 h 20) ; 31a (~14 h 45), 31b (~15 h 20), 31c (~15 h 40) appliquées par la CLI ; `migration list --linked` 16/16 | aucune migration en attente |
| Données de test en production | ⛔ | 44 + 2 comptes `zz-test` (2 créés par la régression de ce lot) | nettoyage (autorisation) |

## Migrations

| Migration | Production |
|---|---|
| 1 à 13 (`20261029000000` → `20261030001000`) | ✅ appliquées manuellement, enregistrées dans l'historique (31/10, 14 h 20) |
| `20261031000000` (31a) | ✅ appliquée le 31/10 (~14 h 45) — §8 ter |
| `20261031000100` (31b) | ✅ appliquée le 31/10 (~15 h 20) — §8 quater |
| `20261031000200` (31c, correctif de cet audit) | ✅ appliquée le 31/10 (~15 h 40) — §8 quinquies |

Détails : [AUDIT_REGULARISATION_MIGRATIONS_20261031.md](./AUDIT_REGULARISATION_MIGRATIONS_20261031.md).

## Qualité

- `flutter analyze` : 0 erreur ; `flutter test` : 403/403 ; Deno `check` : 3/3.
- Anomalies et corrections : [ANOMALIES_ET_CORRECTIONS.md](./ANOMALIES_ET_CORRECTIONS.md).
- Résultats détaillés : [RESULTATS_TESTS.md](./RESULTATS_TESTS.md).
- Mise en production : [PLAN_PRODUCTION.md](./PLAN_PRODUCTION.md).
