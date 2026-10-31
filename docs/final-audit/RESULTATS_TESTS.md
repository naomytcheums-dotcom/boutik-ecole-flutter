# Résultats des tests — 31/10 (mission autonome)

Seuls les tests **réellement exécutés** pendant ce lot figurent ici, avec leur résultat lu (pas seulement le code de sortie).

## Environnements

| Nom | Description |
|---|---|
| **Réplique** | base Supabase locale (Docker) reconstruite par `tool/audit/build_prod_replica.py` à partir d'un `pg_dump` de production : **0 écart** de catalogue sur 13 catégories ; puis 31a + 31b + 31c (`--with-pending`) |
| **Production** | `https://boutik-ecole.vercel.app` (bundle `061029c2…`, vérifié par SHA-256) + Supabase `zxqcnmgwhtbxkdpjqtlr` (31a/31b/31c **non** appliquées) |
| **Deno local** | Edge Functions réelles exécutées par `npx deno`, Supabase et Notch Pay simulés |

## Résultats

| Domaine | Commande | Environnement | Résultat |
|---|---|---|---|
| Analyse statique Flutter | `flutter analyze lib test` | local | **0 erreur**, 3 avertissements (imports inutilisés, fichiers non modifiés), 22 infos |
| Tests Flutter + goldens | `flutter test` | local | **403/403** ; goldens inchangés |
| Typage Edge Functions | `npx deno check pay, notchpay-webhook, notchpay-mcp` | local | **OK** (3/3) |
| Sécurité 31a/31b/31c | `supabase/tests/security_31_rest.py` | réplique + 31a + 31b | **13/24** → 10 défauts démontrés |
| | idem | réplique + 31a + 31b + 31c | **24/24** |
| REST complet (13 suites) | `supabase/tests/run_all_local.py` | réplique + 31a/b/c | **386/386** (lots, lots2, sécurité 31, engagements, favoris, MFA, devis, annonces/stock, conversations, pièces jointes, messagerie, commandes vendeur, avis) |
| Rejeu de 31c | `psql -v ON_ERROR_STOP=1 < 20261031c…` sur base qui l'a déjà | réplique | sortie 0 (idempotent) |
| Paiement `pay` (correctif) | `supabase/tests/pay_e2e.py` | Deno local | **15/15** |
| Paiement `pay` (version déployée) | `PAY_FN=<copie déployée> pay_e2e.py` | Deno local | **6/15** → défauts B1–B4 démontrés |
| Webhook Notch Pay | `supabase/tests/webhook_e2e.py` (signatures, idempotence, doublons, montant, devise, annulation) | Deno local | **20/20** |
| MCP Notch Pay (code du dépôt) | `supabase/tests/mcp_e2e.py` | Deno local | **27/27** |
| Navigateur — lots, lots2, MFA, engagements, parcours, visiteur | `npx playwright test lots lots2 mfa engagements parcours visiteur --workers=1` | build `web_local` → réplique | **37/37** |
| Navigateur — devis | `STATE=qt.json npx playwright test devis` | réplique | **5/5** |
| Navigateur — avis/réclamations | `STATE=fb3.json npx playwright test avis --retries=0` | réplique | **9/9** en une exécution (après correction du test, voir ci-dessous) |
| **Régression production** | `BASE_URL=https://boutik-ecole.vercel.app npx playwright test production visiteur` | **production** | **16/16** |
| Bundle servi | SHA-256 de `main.dart.js` | production | `061029c244ac…` = dernier déploiement (rien de ce lot n'est déployé) |

Total navigateur sur la réplique : **51/51**. Total REST : **386/386**.

## Application de 31a en production (31/10, ~14 h 45)

| Contrôle | Résultat |
|---|---|
| `db push --dry-run` (réplique puis production) | 31a seule |
| `db push` réplique (`search_path=public`) puis production | sortie 0 |
| `lots_rest.py` sur réplique + 31a seule | **77/77** |
| `security_31_rest.py` sur réplique + 31a seule | 13/24 (exposition résiduelle connue, corrigée par 31c) |
| Catalogue production après 31a = réplique après 31a | **0 écart** |
| Delta production avant → après | ajouts uniquement, 0 modification ni retrait |
| Empreintes des données existantes (profils, annonces, engagements, audit, `auth.users`, séquence) | identiques |
| REST anonyme en production (12 appels) | conformes (lectures publiques 200, tables réservées 401, RPC réservées 401) |
| Playwright `visiteur` en production | **12/12** |
| Réplique reconstruite depuis la production (avec 31a) + 31b + 31c en local : `run_all_local.py` | **386/386** (après ajout des bornes de référence à la graine de la réplique) |

## Échecs rencontrés et traitement

| Test | Symptôme | Cause | Traitement |
|---|---|---|---|
| `avis` « publie un avis vérifié » | « Vous pourrez évaluer cet article quand le vendeur l'aura préparé » | préparation documentée incomplète : la règle (avis après préparation) existe depuis 30i et est vérifiée par `feedback_rest.py` | préparation documentée dans l'en-tête du test (le vendeur marque la commande préparée) |
| `avis` idem | 3 avis lus au lieu de 1 | les avis sont publics ; le test lisait tous les avis de la base | filtre `reviewer_id=eq.<acheteur>` |
| `avis` « le vendeur répond » | « Réponse vide » ; passe seul | minutage : saisie avant que le champ du dialogue soit prêt | attente du champ + vérification de sa valeur avant l'envoi |

Aucun test supprimé ou désactivé.

## Non exécutés (et pourquoi)

- Suites REST et navigateur des fonctions 31a/31b/31c **en production** : migrations non appliquées (autorisation requise).
- Événement Notch Pay sandbox réel : aucun événement reçu (0 ligne `payment_events`) ; nécessite un paiement sandbox initié par le propriétaire avec des clés renouvelées.
- `mcp_e2e.py` contre la production : la version déployée (`814db47`) n'est pas celle du dépôt ; redéploiement requis.
