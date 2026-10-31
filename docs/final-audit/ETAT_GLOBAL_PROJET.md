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
| Missions, propositions, affectations, jalons | 🟡 | 31a + 31c sur réplique : `lots`, `security_31` 24/24 | application de 31a + 31c |
| Vœux, campagnes, projets, lives, liens de profil | 🟡 | 31a sur réplique : `lots_rest`, `lots.spec` | 31a (+ 31c pour `save_project`) |
| Certificats (émission, vérification QR, révocation) | 🟡 | 31a + 31c (codes 64 bits) sur réplique ; en production `verify_certificate` absent (le test production le constate) | 31a + 31c |
| Bornes (incidents, événements) | 🟡 | 31a sur réplique | 31a |
| Paramètres administrateur, modèles de notification, clés API | 🟡 | 31b sur réplique : `lots2_rest` 59/59 | 31b |
| Fichiers (compartiment privé `project-files`) | 🟡 | 31b + 31c sur réplique | 31b + 31c |
| Messagerie de mission | 🟡 | 31b + 31c (`is_mission_party`) | 31b + 31c |
| Liens CV (`/#/cv/<token>`) | 🟡 | 31b sur réplique ; en production `shared_cv` absent (constaté) | 31b |
| Codes de retrait | 🟡 | 31b + 31c (5 essais, journalisés) ; interface `confirmPickupDialog` corrigée | 31b + 31c + déploiement web |
| Paiement `pay` | 🟡 | correctif 15/15 ; version déployée 6/15 | déploiement de `pay` |
| Webhook Notch Pay | 🟡 | correctif 20/20 ; en production : 401 sans signature ; **0 événement réel reçu** | déploiement + paiement sandbox réel |
| MCP Notch Pay | ⛔ | code du dépôt 27/27 ; déployé = `814db47` (`?key=` accepté) | redéploiement `--no-verify-jwt` |
| Historique des migrations | ✅ régularisé le 31/10 (14 h 20) : 13 versions enregistrées sans exécution, `migration list --linked` 13/13 | 31a/b/c à renommer puis appliquer (autorisation) |
| Données de test en production | ⛔ | 44 + 2 comptes `zz-test` (2 créés par la régression de ce lot) | nettoyage (autorisation) |

## Migrations

| Migration | Production |
|---|---|
| 1 à 13 (`20261029` → `20261030k`) | ✅ appliquées manuellement, définitions identiques |
| `20261031a` | absente (sauf retrait des droits d'écriture sur `missions`) |
| `20261031b` | absente |
| `20261031c` (correctif de cet audit) | absente — à appliquer **après** 31a et 31b |

Détails : [AUDIT_REGULARISATION_MIGRATIONS_20261031.md](./AUDIT_REGULARISATION_MIGRATIONS_20261031.md).

## Qualité

- `flutter analyze` : 0 erreur ; `flutter test` : 403/403 ; Deno `check` : 3/3.
- Anomalies et corrections : [ANOMALIES_ET_CORRECTIONS.md](./ANOMALIES_ET_CORRECTIONS.md).
- Résultats détaillés : [RESULTATS_TESTS.md](./RESULTATS_TESTS.md).
- Mise en production : [PLAN_PRODUCTION.md](./PLAN_PRODUCTION.md).
