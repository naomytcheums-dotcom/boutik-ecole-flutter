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

## Application de 31b en production (31/10, ~15 h 20)

| Contrôle | Résultat |
|---|---|
| `db push --linked --dry-run --workdir <limité>` | 31b seule (garde automatique) |
| Répétition sur réplique (historique aligné, `search_path=public`) | sortie 0 ; `lots_rest` 77/77 ; `lots2_rest` 54/59 (défaut connu du code de retrait, corrigé par 31c) |
| `db push --linked --workdir <limité>` | sortie 0 |
| Catalogue production après 31b = réplique après 31b | **0 écart** |
| Delta production avant → après | ajouts uniquement |
| Empreintes des données existantes | identiques |
| REST anonyme en production (18 appels) | conformes |
| Playwright `visiteur` en production | **12/12** |

## Application de 31c en production (31/10, ~15 h 40)

| Contrôle | Lieu | Résultat |
|---|---|---|
| Copie locale reconstruite depuis la production (31a + 31b) | local | **0 écart** (outil complété : droits par colonne) |
| Répétition CLI dans un répertoire isolé (`search_path=public`) | local | 31c seule, sortie 0 |
| `run_all_local.py` (13 suites) sur la copie locale + 31c | local | **386/386** |
| `security_31_rest.py` | local | **24/24** (13/24 avant 31c) |
| `lots2_rest.py` (code de retrait : essai erroné journalisé, blocage à 5, nouveau code) | local | **59/59** |
| Catalogue production = copie locale, juste avant application | production | 0 écart |
| `db push --linked --dry-run --workdir <isolé>` | production | `20261031000200` seule |
| `db push --linked --workdir <isolé>` | production | sortie 0 |
| `migration list --linked` | production | 16/16 |
| Catalogue production après 31c = copie locale après 31c | production | **0 écart** |
| Empreintes des données (34) | production | identiques ; historique 15 → 16 |
| Contrôles de sécurité sur le catalogue + REST anonyme | production | **41/41** |
| Playwright `visiteur` | production | **12/12** |

Non réalisable en production (interdiction de créer des comptes du personnel ou de modifier des données métier) : code de retrait erroné réel, blocage à 5, message de dossier de mission, refus d'un fichier tiers, revalidation d'un projet approuvé. Ces comportements sont prouvés en local uniquement.

## Redéploiement des Edge Functions (31/10, ~16 h 15)

| Contrôle | Lieu | Résultat |
|---|---|---|
| Code local = `origin/feat/figma-fidele` (commit `d695001`) | local | identique |
| Tests de concurrence (annulation pendant la relecture Notch Pay) **avant** correctif | local | webhook 20/21, pay 15/16 → défaut B8 démontré |
| `pay_e2e.py` / `webhook_e2e.py` / `mcp_e2e.py` après correctif | local (Deno, fournisseur simulé) | **16/16**, **21/21**, **27/27** |
| `deno check` des 3 fonctions | local | OK |
| Code déployé retéléchargé = fichiers du commit | production | 3/3 identiques (SHA-256) |
| Verify JWT après déploiement | production | `pay` actif, `notchpay-webhook` désactivé, `notchpay-mcp` actif — inchangés |
| Contrôles non financiers (refus, signatures, CORS, `?key=`, fuite de secrets, base inchangée) | production | **21/21** |

Non réalisables par l'agent : appel MCP authentifié avec la vraie clé (valeur secrète inconnue de l'agent, propriétaire : INTERVENTIONS §9) ;
événement webhook signé (secret `NOTCHPAY_HASH` non lisible ; aucun événement simulé pouvant modifier une commande) ; parcours `pay` authentifié
(création de comptes interdite) ; lecture des journaux des fonctions (non exposés par la CLI, tableau de bord du propriétaire).

## Déploiement du site (31/10, 18 h 42) — écran de retrait

| Contrôle | Lieu | Résultat |
|---|---|---|
| `retrait.spec` (8 exigences) sur l'**ancienne** version (`RETRAIT_SOFT=1`) | local, base réelle | **défauts démontrés** : « Remise confirmée » affiché pour les réponses `null`, `"ok"`, `true` ; aucun message en cas de délai dépassé ; seconde confirmation possible pendant l'attente |
| `retrait.spec` sur la version corrigée (strict, sans relance) | local, base réelle | **1/1** : code erroné, bon code (« delivered » vérifié), 5 essais, code remplacé, réseau, délai, HTTP 401/403/500, réponses inattendues, soumission répétée (1 seul envoi), actualisation (session fermée, « Commande déjà remise »), 3 confirmations simultanées → 1 seule remise |
| `form_dialog_test.dart` (double clic) | local | 2/2 (Flutter ignore déjà le second clic ; le test fige ce comportement) |
| `flutter test` complet | local | **405/405**, goldens inchangés |
| `flutter analyze` | local | 0 erreur, 3 avertissements préexistants |
| `lots` + `lots2` | local | 12 réussis + 1 instable ; 1 échec sous charge (« établissement 118 ») → **1/1 rejoué seul** |
| Bundle de production : URL, clé publiable, 0 adresse locale, 0 secret | local | conforme |
| SHA-256 servi = construit | production | identique (`0e6f976a…`) |
| `visiteur` | production | **12/12** |
| `retrait_en_ligne` (site déployé, trafic Supabase entièrement intercepté) | production (frontend) | **1/1** ; 17 requêtes interceptées, 0 vers la base, 0 erreur JavaScript |
| `connexion_en_ligne` (identifiants inexistants) | production | **1/1** : refus 400 du serveur, aucune session, 146-2 inaccessible, 0 erreur JavaScript |
| Compteurs avant/après (comptes, sessions, jetons, journaux, profils, annonces, commandes, paiements) | production | identiques |

Incident d'environnement : `flutter test` bloqué deux fois sans message — **disque C: saturé (0,4 Go libres)**. 2,3 Go de dossiers temporaires
`flutter_tools.*` supprimés ; deux caches d'installation Visual Studio/.NET de 8,4 Go dans `%TEMP%` (`ahmsz33r`, `swlgp0us`) laissés en place (non créés par cette session).

Non réalisable : remise réelle en production (exige un compte `support` et une commande payée, interdits).

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
