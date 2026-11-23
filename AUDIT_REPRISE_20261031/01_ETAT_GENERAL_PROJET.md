# 01 — État général du projet Boutik-École (Projet 1) — audit de reprise du 31/10/2026

> **Audit en lecture seule.** Aucun fichier du projet n'a été modifié, aucun commit ni push, aucune écriture en production, aucun
> déploiement, aucune migration. Seuls les rapports et outils d'audit ont été créés dans `AUDIT_REPRISE_20261031/`.
> Les vérifications « production » de ce document ont été faites aujourd'hui ; celles marquées « historique » proviennent des
> documents existants et n'ont **pas** été rejouées.

## 1. Dépôt Git

| Élément | Constat (31/10, 22 h 15) | Comparaison avec le dernier état connu |
|---|---|---|
| Répertoire | `C:\Users\NITROV15\Downloads\boutik_ecole_flutter` (existe) | identique |
| Branche active | `feat/figma-fidele`, suivie de `origin/feat/figma-fidele` | identique |
| Commit actuel | **`dfecbae`** (`docs+test(site): déploiement de 69753e6 …`) | dernier commit connu |
| Écart local / distant | **0** (HEAD = `@{u}` = `dfecbae5934f0a20…`) | à jour |
| Modifications non commitées | **aucune** | — |
| Fichiers non suivis | `supabase/migrations_backup_20261031/` (sauvegarde de la régularisation des migrations, préexistante) et `AUDIT_REPRISE_20261031/` (ce rapport) | la sauvegarde était déjà présente ; **non modifiée** |
| Conflits | aucun | — |
| Commit du site déployé | `69753e6` (code identique à `dfecbae` pour `lib/` : `dfecbae` ne modifie que la documentation et les tests) | conforme |
| Fichiers importants absents | `supabase/config.toml` absent (les réglages `verify_jwt` se lisent en production : voir §5) | déjà le cas |

Derniers commits :
1. `dfecbae` — documentation et tests du déploiement ;
2. `69753e6` — correctifs C3/C4 du kiosque ;
3. `dd7de9b` — documentation des fonctions ;
4. `d695001` — correctif B8 (annulation pendant la relecture Notch Pay) ;
5. `9dd56bb`, `fac8196`, `ace1e9e` — migrations 31c, 31b, 31a ;
6. `6a65c9d` — régularisation de l'historique ;
7. `6ae90f5` — 16 dernières actions réelles ;
8. `5862ab2` — actions réelles.

## 2. Architecture

| Couche | Emplacement | Taille | Rôle |
|---|---|---|---|
| Point d'entrée | `lib/main.dart` (initialise `Backend.init()` puis `App`), `lib/app.dart` | 2 fichiers | démarrage, thème, localisation |
| Routage | `lib/core/router/app_router.dart` | — | `GoRouter` : `/` → `/s/01`, `/catalogue` (liste de revue des 315 écrans), `/espace` (« Mes rubriques »), `/cv/:token` (CV partagé), **`/s/:id`** (tous les écrans, enveloppés par `AccessGuard`) |
| **Écrans exécutés** | `lib/figma/g/g_*.dart` (315 fichiers générés depuis Figma) + `lib/figma/registry.dart` (`gBuilders`, 315 entrées) | 355 fichiers dans `lib/figma` | rendu fidèle à la maquette ; navigation `gOpen`/`gTab`/`gEspace` (`lib/figma/nav.dart`) ; actions vers les modules métier |
| **Modules métier** | `lib/figma/live/*.dart` (36 fichiers, 409 Ko) | — | `backend.dart` (client Supabase), `auth.dart`, `access.dart` (rôles), `lots.dart` (missions, vœux, campagnes, projets, lives, certificats, bornes, paramètres), `engage.dart`, `seller.dart`, `pay.dart`, `messages.dart`, `chat.dart`, `notifs.dart`, `store.dart`, `system_states.dart`, `shared_cv.dart`, `account_menu.dart`, `espace.dart`… |
| Manifeste | `lib/features/**/screens.dart` + `lib/features/screens.dart` | 376 fichiers dans `lib/features` | titres, sections, nœuds Figma. **Constat important** : pour les 315 écrans, `allScreens` remplace le constructeur par `gBuilders[id]` ; les widgets `*Screen` de `lib/features` **ne sont jamais construits à l'exécution**. C'est une couche historique morte, mais compilée. Ses liens (`context.openScreen(...)`) sont inactifs. |
| Données d'exemple | `lib/data/demo/*.dart`, `lib/data/repositories/repositories.dart` | 33 fichiers dans `lib/data` | utilisées par les écrans `features` (morts) et par le mode hors connexion (`demoContent = !Backend.ready`, `lib/figma/live/auth.dart:527`) |
| Thème et utilitaires | `lib/core/` | 34 fichiers | couleurs, widgets communs |
| Localisation | `lib/l10n/` | 3 fichiers + ARB | infrastructure présente ; les textes des écrans générés sont écrits en dur en français |
| Rôles | `lib/figma/live/access.dart` | — | 10 rôles : visitor, client, student, company, other, dept, direction, finance, support, admin. `allowedRoles(id)` filtre **côté client** (page 404 neutre et journal « Accès refusé ») ; la sécurité réelle repose sur RLS et RPC |
| Gestion d'état | Riverpod 3 (`flutter_riverpod`) | — | providers dans `lib/figma/live` |
| Backend | Supabase (`supabase_flutter`) ; Edge Functions `pay`, `notchpay-webhook`, `notchpay-mcp` | 16 migrations, `supabase/schema.sql` | voir §4 |
| Paiement | `lib/figma/live/pay.dart` → `functions.invoke('pay')` | — | Notch Pay (Mobile Money) |
| Stockage | buckets `listing-images`, `chat-files`, `project-files` (créés par les migrations) | — | photos, pièces jointes, dossiers de mission |

## 3. Dépendances et outillage

| Élément | Valeur |
|---|---|
| Flutter | **3.47.8** (stable, révision `737ba8f8`) — une version plus récente existe (non installée, conformément à la consigne) |
| Dart | **3.13.7** |
| Contrainte du SDK | `^3.13.7` |
| Dépendances principales | flutter_riverpod 3.4.3, go_router 18.1.1, supabase_flutter 2.18.3, google_fonts 9, pdf/printing, image_picker, file_picker, record, speech_to_text, share_plus, url_launcher, qr, shared_preferences, audioplayers, web 1.1.2 |
| Fichier de verrouillage | `pubspec.lock` cohérent (modifié avec `pubspec.yaml` le 30/10 à 21 h 04, commit `5862ab2`) ; aucune modification locale |
| Supabase CLI | **2.122.0** (`npx --no-install supabase --version`) |
| Playwright | installé dans `e2e/node_modules` |

## 4. Tests (exécutés aujourd'hui)

| Commande | Résultat | Durée | Effets sur le disque |
|---|---|---|---|
| `flutter analyze --no-pub` | **0 erreur**, 3 avertissements (imports inutilisés : `account_menu.dart:4` et `:8`, `engage.dart:9`), 22 informations (13 × `use_build_context_synchronously`, 3 × commentaire HTML, 2 × accolades, 2 × `_`, 1 import, 1 élément null-aware) | 238 s | caches `.dart_tool` (ignoré par Git) |
| `flutter test --no-pub --concurrency=1` | **405 / 405 réussis**, 0 ignoré, 0 échec — dont 1 golden par écran (315 rendus comparés à `test/golden`) | 3 min | `build/` (ignoré) ; **aucun** fichier `test/failures` créé ; `git status` inchangé |
| Playwright **sur la production**, en lecture seule : `visiteur.spec.ts` + `retrait_en_ligne.spec.ts` | **13 / 13 réussis** (5,4 min) : chargement sans erreur JavaScript, accueil sans inscription imposée, « Mes rubriques » sans espaces réservés, 404 neutre sur un écran vendeur, écran inexistant, 5 tailles d'écran sans débordement, rechargement et retour arrière ; écran de retrait 146-2 : **17 requêtes Supabase toutes interceptées, 13 envois `confirm_pickup` simulés, aucun faux « Remise confirmée », 0 erreur JavaScript** | 5,4 min | `e2e/results` (ignoré par Git ; l'ancien contenu a été sauvegardé dans `donnees/e2e_results_avant`) |

**Non exécutés, volontairement** :
- les 10 autres tests Playwright (`avis`, `devis`, `engagements`, `mfa`, `parcours`, `production`, `connexion_en_ligne`) créent des comptes `zz-test` ou des données en production, ou se connectent avec un compte (interdit) ;
- `lots`, `lots2` et `retrait` exigent la base locale isolée ;
- les 17 scripts `supabase/tests/*.py` (REST, sécurité, e2e de paiement, webhook et MCP) écrivent dans la base, locale ou de production ;
- couverture de code : non calculée (aucune configuration `--coverage` existante ; ce calcul aurait créé `coverage/`).

Inventaire des tests :
- `test/` : 30 fichiers (account 5, golden 1, journey 1, navigation 2, purchase 21) et 1 575 images golden ;
- `test_legacy/` : 33 fichiers ;
- `e2e/tests/` : 12 tests Playwright ;
- `supabase/tests/` : 17 scripts.

Les rapports des agents d'exploration annonçaient « aucun test e2e » et « 2 scripts REST » : c'était **inexact**, corrigé ici.

## 5. Supabase (production `zxqcnmgwhtbxkdpjqtlr`, lecture seule)

| Élément | Constat d'aujourd'hui | Preuve |
|---|---|---|
| Projet lié | `zxqcnmgwhtbxkdpjqtlr` | `supabase/.temp/project-ref` |
| Historique des migrations | **16 locales = 16 distantes**, de `20261029000000` à `20261031000200` ; aucune en attente | `npx supabase migration list --linked` → `donnees/supabase_migration_list.txt` |
| Edge Functions | `pay` **v6**, ACTIVE, `verify_jwt=true` · `notchpay-webhook` **v6**, ACTIVE, `verify_jwt=false` · `notchpay-mcp` **v3**, ACTIVE, **`verify_jwt=true`** | `npx supabase functions list` → `donnees/supabase_functions_list.txt` |
| Cohérence avec le code | les **54 RPC** appelées par l'application existent dans les migrations ou `schema.sql` ; les 10 tables lues directement et les 3 buckets existent ; une seule Edge Function appelée par l'application (`pay`) | `donnees/coherence_flutter_backend.json` |
| Objets serveur sans interface | `revoke_certificate`, `decide_certification` (aucun appel dans `lib/`) | recherche |
| RLS, politiques, droits `EXECUTE` | **non relus en production aujourd'hui** (exigerait une connexion à la base). Historique : catalogue de production identique à la copie locale après 31c (0 écart), 41/41 contrôles de production, sécurité 24/24 en local | `docs/final-audit/AUDIT_REGULARISATION_MIGRATIONS_20261031.md` |

Écart à signaler : l'en-tête de `supabase/functions/notchpay-mcp/index.ts` indique « Verify JWT désactivé », mais la production a `verify_jwt=true`. Un client MCP doit donc présenter un JWT Supabase **et** la clé MCP dans l'en-tête `x-mcp-access-key`. L'option `Authorization: Bearer <clé MCP>` est bloquée par la passerelle. C'est historique (« Verify JWT inchangé ») et ce n'est pas une régression, mais la documentation est incohérente.

## 6. Vercel et production

| Contrôle (HTTP GET, sans écriture) | Résultat |
|---|---|
| `https://boutik-ecole.vercel.app/` | **200**, servi par Vercel (`fra1`) |
| `/main.dart.js` | **200**, 9 523 199 octets, **SHA-256 `0e6f976a1001d9d3…`** = build local `build/web/main.dart.js` (31/10, 18 h 38) = déploiement historique de `69753e6` |
| `/flutter_bootstrap.js`, `/version.json` | 200 (`boutik_ecole` 0.1.0+1) |
| `/s/03`, `/cv/<jeton>` | 200 (application monopage) |
| Identifiant de déploiement Vercel | **non vérifiable** sans accès au compte Vercel ; la correspondance est établie par l'empreinte du bundle |

Une vérification HTTP **n'est pas** la validation d'un parcours : les seuls parcours rejoués en production aujourd'hui sont ceux du
visiteur et l'écran de retrait avec serveur simulé (§4).

## 7. Écarts avec le dernier état connu

| Référence historique | Aujourd'hui |
|---|---|
| 16 migrations jusqu'à `20261031000200` | **confirmé** en production |
| `pay` v6, `notchpay-webhook` v6, `notchpay-mcp` v3 | **confirmé** |
| Déploiement de `69753e6` (`main.dart.js` 0e6f976a) | **confirmé** par empreinte |
| Tests Flutter 405/405, `flutter analyze` 0 erreur | **confirmé** (rejoué) |
| 222 écrans orphelins | **dépassé** : 12 sans lien contextuel aujourd'hui (voir 02) |
| 192 actions « Démonstration » | **dépassé** : 0 aujourd'hui ; 168 sont devenues de vraies actions, mais **22 actions ou flux restent simulés ou en attente** sans porter ce mot (voir 03) |
