# Anomalies et corrections — mission autonome du 31/10

Chaque anomalie est **démontrée par un test reproductible** ; la correction est validée par le même test.
Rien n'est déployé ni appliqué en production (voir [PLAN_PRODUCTION.md](./PLAN_PRODUCTION.md)).
Base de test : réplique exacte de la production (0 écart de catalogue), voir
[AUDIT_REGULARISATION_MIGRATIONS_20261031.md](./AUDIT_REGULARISATION_MIGRATIONS_20261031.md).

## A. Migrations et base de données

| # | Anomalie | Gravité | Preuve | Correction | Statut |
|---|---|---|---|---|---|
| A1 | Historique distant inexistant ; 13/15 noms ignorés par la CLI ; `db push` rejouerait `p0` (écritures sur `auth.users`) | Élevée (opérationnelle) | `migration list --linked`, `db push --dry-run` sur réplique | Régularisation (rapport §8 bis) | **Corrigé en production** (31/10, 14 h 20) |
| A2 | `20261030f` non rejouable après `g` (`cannot change return type`) | Moyenne | rejeu sur réplique | Ne jamais rejouer ; marquer « appliquée » | Documenté |
| A3 | Politiques `missions` ASCII de la production non supprimées par 31a → nouvelle politique sans effet restrictif | Élevée | `security_31_rest.py` sur réplique + 31a | `20261031c` : suppression ASCII + accentuées, politique `missions : visibilité restreinte` | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A4 | `schema.sql` du dépôt ≠ production (noms accentués ; 2 politiques permissives absentes en prod) → tests antérieurs trop permissifs | Moyenne | comparaison catalogue | 31c supprime les 2 politiques ; tests désormais sur la réplique | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A5 | `assign_mission`, `submit_milestone`, `decide_milestone` sans contrôle explicite `auth.uid()` | Faible (défense en profondeur) | lecture + test `anon` | contrôle ajouté (31c) | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A6 | `save_project` : projet approuvé modifiable sans nouvel examen ; projet soumis modifiable pendant l'examen | Moyenne | `security_31_rest.py` | `approved` modifié → `submitted` + notification ; `submitted` verrouillé | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A7 | Codes de certificat sur 32 bits (`md5(random())`, 8 hexa) → énumérables via `verify_certificate` (anon) | Moyenne | lecture + test | 16 hexa `gen_random_bytes(8)`, contrainte 8 ou 16 | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A8 | Messagerie de mission : le personnel pouvait écrire ; fichier d'un tiers attachable | Élevée | `security_31_rest.py` | `is_mission_party` ; fichier lié à l'expéditeur et à la mission | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A9 | Code de retrait : `random()`, essais erronés non journalisés (le `raise` annulait l'audit), pas de limite | Élevée | `lots2_rest.py`, `security_31_rest.py` | `gen_random_bytes`, `pickup_attempts`, réponse `'incorrect'` journalisée, blocage à 5 puis nouveau code | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A10 | `EXECUTE` à `public/anon` sur les fonctions de déclencheur | Faible | catalogue | révoqué (31c), déclencheurs testés | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A11 | `sync_order_cancelled` sans `search_path` | Faible | catalogue | `set search_path = public` | **Corrigé en production** (31c, 31/10 ~15 h 40) |
| A12 | Droits `missions` déjà retirés en production sans trace d'origine | Information | catalogue | aucune (idempotent) | Origine inconnue |

## B. Paiements (Edge Functions)

| # | Anomalie | Gravité | Preuve | Correction | Statut |
|---|---|---|---|---|---|
| B1 | `pay` : une commande **annulée** pouvait être envoyée au paiement | Élevée | `pay_e2e.py` contre la version déployée : **6/15** | refus `cancelled_at` | **Corrigé en production** (`pay`/`notchpay-webhook` v6, 31/10) |
| B2 | `pay` : un second appel créait un **second paiement** Notch Pay pour la même commande | Élevée | `pay_e2e.py` | réutilisation de la référence en attente ; confirmation si le paiement précédent est complet | **Corrigé en production** (`pay`/`notchpay-webhook` v6, 31/10) |
| B3 | `pay` : montant absent ou non fini non traité comme insuffisant | Moyenne | `pay_e2e.py` | traité comme insuffisant | **Corrigé en production** (`pay`/`notchpay-webhook` v6, 31/10) |
| B4 | `pay` : mise à jour de commande sans garde de concurrence | Moyenne | lecture | `.eq("paid", false).is("cancelled_at", null)` | **Corrigé en production** (`pay`/`notchpay-webhook` v6, 31/10) |
| B5 | Webhook : paiement reçu après annulation → commande confirmée payée | Élevée | `webhook_e2e.py` (commande `o4`) | résultat `paid_after_cancellation`, non confirmée, à rembourser | **Corrigé en production** (`pay`/`notchpay-webhook` v6, 31/10) |
| B6 | `notchpay-mcp` déployé = commit `814db47`, accepte encore la clé en paramètre d'URL `?key=` | Moyenne | code téléchargé (`functions download`) | version du dépôt (en-tête uniquement) — **redéploiement requis** | **Corrigé en production** (`notchpay-mcp` v3 : `?key=` refusé, vérifié) |
| B7 | Secrets `NOTCHPAY_KEY` / `NOTCHPAY_HASH` non renouvelés depuis le 30/10 | Moyenne | `secrets list` (dates) | renouvellement par le propriétaire | En attente |
| B8 | Annulation de la commande **pendant** la relecture du paiement chez Notch Pay : le webhook confirmait la commande annulée (confirmed: true), pay répondait « complete » | Élevée | tests de concurrence ajoutés : webhook 20/21 et pay 15/16 avant correctif | mise à jour conditionnée à cancelled_at is null, relecture puis résultat paid_after_cancellation / échec « cancelled » ; webhook 21/21, pay 16/16 | **Corrigé en production** (v6, commit `d695001`) |

## C. Flutter

| # | Anomalie | Correction | Statut |
|---|---|---|---|
| C1 | `confirmPickupDialog` ne gérait pas la réponse `'incorrect'` de `confirm_pickup` (31c) | alerte « Code de retrait incorrect… » ([lots.dart](../../lib/figma/live/lots.dart)) | Corrigé ; 403/403 tests Flutter, goldens inchangés |
| C2 | Test navigateur `lots.spec.ts` supposait des codes de certificat à 8 caractères | expression `{16}` | Corrigé |
| C3 | Depuis 31c (production), `confirm_pickup` répond `'incorrect'` sans erreur ; l'interface **déployée** (`061029c2…`, antérieure à `057af8a`) affiche alors « Remise confirmée » — message faux, la commande n'étant pas remise (vérifié dans le code de la fonction : aucune mise à jour sur code erroné) | correction C1 déjà dans le dépôt ; **déploiement web requis** (autorisation) avant d'ouvrir le kiosque. Sans effet aujourd'hui : 0 compte `support`/`admin`, 0 commande payée | **En attente de déploiement** |

## D. Recommandations non appliquées (décision requise)

- Révoquer `TRUNCATE/REFERENCES/TRIGGER` par défaut d'`anon`/`authenticated` (risque faible : non exposé par PostgREST).
- `verify_certificate` (anon) expose nom du titulaire et motif de révocation : choix produit à confirmer.
- 25 avertissements `flutter analyze` (imports inutilisés, préexistants) : non corrigés pour ne pas toucher aux écrans validés.
