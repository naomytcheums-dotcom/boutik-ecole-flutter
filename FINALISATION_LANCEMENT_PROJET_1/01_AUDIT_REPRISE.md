# 01 — Audit de reprise (phase 0), diagnostic disque (phase 1) et inventaire exhaustif

> Date : 01/11/2026, 07 h 10 – 07 h 40. **Lecture seule** : aucune modification du code, de la production ni du disque, hormis la
> création de ce dossier de livrables, d'une sauvegarde Git indépendante (46 Ko) et des fichiers de mesure.
> Preuves : `FINALISATION_LANCEMENT_PROJET_1/donnees/` et `sauvegarde/`.

## A. État Git

| Élément | Constat | Preuve |
|---|---|---|
| Branche | `feat/figma-fidele`, **en avance de 2** sur `origin/feat/figma-fidele` | `git status -sb` |
| HEAD | `04a0dbd5feacfc2a0199cf9238562772f9f722ff` | `git rev-parse HEAD` |
| Commits locaux non poussés | `04a0dbd` (01/11 06:07) « Exporter (110), Partager (161) » ; `6364a6d` (01/11 06:00) « plus aucun succès sans réalité… » | `git log origin/feat/figma-fidele..HEAD` |
| Différence `6364a6d` → `04a0dbd` | 5 fichiers, +22 −3 : `g_110.dart`, `g_161.dart`, `hackathons.dart`, `finalisation_20261101_test.dart`, `bindings.json` | `git diff --stat` |
| Contenu de `6364a6d` | 30 fichiers, +904 −46 | `git show --stat` |
| Modifications non commitées | **aucune** ; non suivis : `AUDIT_REPRISE_20261031/`, `FINALISATION_PROJET_1/`, `supabase/migrations_backup_20261031/` (préexistants), `FINALISATION_LANCEMENT_PROJET_1/` (ce rapport) | `git status --porcelain` |
| Étiquette de sauvegarde | `sauvegarde-avant-finalisation-20261101` → `dfecbae5934f…` (intacte) | `git rev-parse …^{commit}` |
| Sauvegarde indépendante | `sauvegarde/commits_6364a6d_04a0dbd.bundle` (46 631 octets, SHA-256 `d702edc079940652…`), **vérifiée** (`git bundle verify` : « is okay ») | `donnees/empreintes_sha256_phase0.csv` |

**Empreintes SHA-256 des éléments critiques** (16 premiers caractères ; empreintes complètes dans le CSV) :

| Fichier | Octets | SHA-256 |
|---|---|---|
| `supabase/migrations/20261101000000_administration_comptes_signalements.sql` | 4 768 | `b4b3328b85efb134` |
| `lib/figma/live/backend.dart` | 44 856 | `75c47c1423c7db63` |
| `lib/figma/live/auth.dart` | 36 434 | `0896775ede7a1e0b` |
| `lib/figma/live/admin.dart` | 5 310 | `e7afed1ed5c8d5ea` |
| `lib/figma/live/ops.dart` | 19 314 | `91e9eff5eba1c155` |
| `lib/figma/live/missions.dart` | 13 652 | `9f41e938ea9e6dca` |
| `lib/figma/live/hackathons.dart` | 14 397 | `85f73d0d424faba1` |
| `lib/figma/live/lots.dart` | 67 409 | `d1f60ec0467fb571` |
| `lib/figma/live/drafts.dart` | 2 946 | `acbf651c4278f2d7` |
| `lib/figma/registry.dart` | 22 413 | `aa54abd6897998de` |
| `tool/figma_export/bindings.json` | 200 630 | `607ad7eaa9af294f` |
| `pubspec.lock` | 39 784 | `ec99058b0f472637` |
| `web/vercel.json` | 611 | `e3d36acba8f09686` |

## B. État des corrections locales

Les 12 corrections C1 à C12 (rapport `FINALISATION_PROJET_1/02`) sont présentes dans HEAD :
- mot de passe oublié réel ;
- administration des comptes et signalements côté serveur ;
- missions et concours sans action simulée ;
- 11 faux succès supprimés ;
- certificats ;
- écran 176 ;
- identité Web ;
- permissions Android et iOS.

**Aucune n'est en production** : le bundle en ligne est toujours `0e6f976a…` (`69753e6`), vérifié le 01/11 à 06 h 45.

## C. État des migrations

| Élément | Constat |
|---|---|
| Locales | 17 (jusqu'à `20261101000000`) |
| Distantes (production) | 16 (jusqu'à `20261031000200`) |
| Non appliquée | **`20261101000000_administration_comptes_signalements.sql`** (`admin_set_account`, `set_report_status`) ; testée 20/20 sur la réplique en transaction annulée |
| Preuve | `donnees/migration_list_phase0.txt` (`npx supabase migration list --linked`, lecture seule) |

## D. Fonctionnalités, tests et environnement

| Domaine | Constat |
|---|---|
| Tests | `test/` 31 fichiers (421 tests au 01/11 : 405 + 16), `test_legacy/` 33, `e2e/tests/` 12 tests Playwright, `supabase/tests/` 17 scripts (REST réplique 386/386 le 01/11) |
| Fonctions backend appelées | 54 RPC (toutes présentes en production, audit du 31/10) + 2 nouvelles (`admin_set_account`, `set_report_status`, **absentes en production**) ; Edge Function `pay` |
| Variables d'environnement | côté Flutter : seulement `BE_URL` et `BE_KEY` (`--dart-define`, valeurs par défaut = production publique) ; **aucun secret dans le code ni dans le bundle** (analysé le 01/11). Secrets serveur (noms) : `NOTCHPAY_KEY`, `NOTCHPAY_HASH`, `MCP_ACCESS_KEY`, `SUPABASE_*`. Fichier d'environnement local : `ios/Flutter/ephemeral/flutter_native_integration.env` (généré par Flutter, sans secret) |
| Flutter | 3.47.8 stable, Dart 3.13.7 ; **`no-enable-android`** (plateforme Android **désactivée** dans la configuration Flutter) ; Chrome et Edge disponibles |
| Android | **aucun SDK Android installé** (ni `Android\Sdk`, ni caches Gradle) |
| iOS | Windows uniquement : **aucune compilation iOS possible** |
| Navigateurs de test | Playwright 1.49.1 : Chromium uniquement (1148 et 1248) ; **ni Firefox ni WebKit** ; Firefox non installé |

## E. Anomalies précédentes : état actuel

| Anomalie (rapports 02 à 09 du 01/11) | État vérifié le 01/11 à 07 h 30 |
|---|---|
| Écrans de mission et de concours avec données d'exemple | **toujours présentes** (confirmé par l'inventaire : 21 écrans 160-169 et 191-201) |
| 46 comptes `zz-test` | toujours en production (aucune suppression) |
| Clés Notch Pay exposées | non renouvelées |
| Aucun admin ni support réel en production | inchangé |
| Migration `20261101000000` | non appliquée |
| Espace disque | **0,29 Go libres** (aggravé), fichier d'échange 48,0 Go, mémoire engagée 59,0 / 62,6 Go |

## F. Phase 1 — Diagnostic disque (lecture seule) et proposition de nettoyage

Mesures du 01/11 07 h 15 (`donnees/disque_caches_dev.csv`), complétées par l'audit de stockage du 31/10 :

| Chemin | Taille | Utilité |
|---|---|---|
| `%LOCALAPPDATA%\Temp` | 14,25 Go | dont 48 extractions de l'installateur Visual Studio (4,09 Go) et 2 caches de mise à jour VS (8,21 Go) |
| `%LOCALAPPDATA%\npm-cache` | 4,84 Go | cache de paquets npm, régénérable |
| `~\.cache` | 3,09 Go | caches d'outils d'IA (Hugging Face…) |
| `C:\src\flutter` | 2,59 Go | **second SDK Flutter** (le projet utilise `~\dev\flutter`) |
| `~\dev\flutter\bin\cache` | 2,45 Go | SDK en service : indispensable |
| `%LOCALAPPDATA%\ms-playwright` | 1,20 Go | navigateurs de test (Chromium 1148 utilisé par `e2e`) |
| `%LOCALAPPDATA%\.dartServer` | 1,14 Go | cache de l'analyseur Dart (régénérable) |
| `%LOCALAPPDATA%\Pub\Cache` | 1,07 Go | paquets Dart du projet : indispensable hors ligne |
| `~\.android` | 0,50 Go | configuration et images d'émulateur |
| Projet `build\` / `.dart_tool\` | 0,40 / 0,45 Go | artefacts régénérables |
| Fichier d'échange | 48,0 Go | **ne pas réduire** (consigne et audit) |

**Proposition de nettoyage (rien n'est exécuté, votre autorisation est requise ligne par ligne)** :

| # | Chemin exact | Taille | Utilité | Risque | Récupération estimée | Commande proposée |
|---|---|---|---|---|---|---|
| N1 | les **48 dossiers** listés dans `Audit_Stockage_PC_20261031\PHASE_2_DIAGNOSTIC\donnees\vs_extractions_temp.csv` (dans `%TEMP%`) | 4,09 Go | aucune (copies orphelines de l'installateur VS) | très faible | **4,1 Go** | `Import-Csv <csv> \| % { Remove-Item -LiteralPath (Join-Path $env:TEMP $_.Nom) -Recurse -Force }`, après avoir vérifié qu'aucun processus `BackgroundDownload`, `setup` ou `vs_installer` ne tourne |
| N2 | `%LOCALAPPDATA%\npm-cache` | 4,84 Go | accélère `npm install` | faible (re-téléchargement à la demande) | **4,8 Go** | `npm cache clean --force` |
| N3 | `<projet>\build` | 0,40 Go | artefacts de compilation et de test | nul (régénéré) | 0,4 Go | `Remove-Item -LiteralPath C:\Users\NITROV15\Downloads\boutik_ecole_flutter\build -Recurse -Force` |
| N4 | `%TEMP%\ahmsz33r`, `%TEMP%\swlgp0us` | 8,21 Go | mises à jour VS déjà téléchargées, non installées | moyen : re-téléchargement si vous installez ces mises à jour | 8,2 Go | à décider avec l'option « Télécharger lors de l'installation » de VS |
| N5 | `C:\src\flutter` | 2,59 Go | second SDK, **usage inconnu** | **moyen à élevé** si un autre projet l'utilise | 2,6 Go | aucune avant votre confirmation |
| N6 | `%LOCALAPPDATA%\.dartServer` | 1,14 Go | cache de l'analyseur | faible ; à faire VS Code fermé | 1,1 Go | `Remove-Item … -Recurse` (VS Code fermé) |
| — | **Redémarrage de Windows** | — | ramène le fichier d'échange à sa taille initiale | aucun (sauvegardez votre travail) | **≈ 20 Go temporaires** (constaté au redémarrage du 29/10) | votre geste |

**Recommandation** : N1 + N2 + N3 libèrent **≈ 9,3 Go** à faible risque. C'est suffisant pour les compilations Web et pour installer
le SDK Android (≈ 3 à 5 Go pour les outils et une plateforme), mais **pas** pour ajouter un émulateur (≈ 6 à 10 Go de plus).

**Tant que l'espace n'est pas libéré**, je ne lance ni compilation (Web, APK) ni suite de tests complète. La dernière avait fait passer
l'espace libre de 2,46 à 0,34 Go via le fichier d'échange.

## G. Inventaire exhaustif des écrans (mission « raccordement intégral »)

Méthode (script `outils/inventaire_lancement.py`, lecture seule) :
- les 315 fichiers `lib/figma/g/g_*.dart` ;
- chaque gestionnaire (`tap:`, `gTap`) est classé :
  - **serveur** : fonction de `lib/figma/live` qui atteint Supabase, à l'exclusion de celles qui n'écrivent que dans le journal d'audit ;
  - **navigation** ;
  - **locale** : panier, filtres, interface ;
  - **attente** : `unavailableAction` ou « bientôt » ;
  - **message seul** ;
- les **données de maquette visibles en production** sont les textes littéraux chiffrés (montants, compteurs, dates, durées) non
  masqués par `demoContent` ;
- les **sources serveur** sont les providers observés par l'écran et reliés à Supabase ;
- les **tests fonctionnels** sont les tests (hors goldens) qui importent ou ouvrent l'écran.

| Statut | Écrans | Définition appliquée |
|---|---|---|
| CONNECTÉ ET FONCTIONNEL | **9** | source ou action serveur (ou aucune donnée de maquette) **et** preuve de test local : 29, 45, 47, 57, 64, 90, 110, 156, 236 |
| CONNECTÉ MAIS PARTIEL | **34** | serveur branché, mais ≥ 3 données de maquette encore visibles |
| NON VÉRIFIÉ | **112** | raccordé (navigation et parfois serveur), sans test fonctionnel qui l'ouvre |
| DONNÉES FICTIVES | **128** | ≥ 3 données de maquette visibles sans source serveur, ou parcours mission ou concours d'exemple |
| ACCESSIBLE MAIS NON FONCTIONNEL | **19** | champs de saisie reliés à **aucune** saisie ni action : 104, 126, 137, 138, 144, 168, 179, 180, 181, 182, 188, 18c, 251, 25b, 267, 40, 41, 49, 52 |
| BLOQUÉ PAR UNE DÉPENDANCE | **6** | 84b, 210, 219, 243, 250, L1 (paiements, diffusion, imprimante) |
| ORPHELIN | **4** | 150-1, 150-4, 275, S1 |
| DOUBLON | **3** | A2, P4, 250b |
| **Total** | **315** | |

**Interactions recensées : 2 025.**

| Nature | Nombre | Remarque |
|---|---|---|
| Navigation | 1 722 | souvent en double : zone `gP` et `gTap` superposées |
| Serveur | 176 | |
| Locales | 117 | filtres, panier, interface |
| En attente | 9 | |
| Message seul | 1 | « Discussion d'équipe : bientôt disponible » |

À cela s'ajoutent 214 champs de saisie.

**Taux de raccordement réellement prouvé** (écrans « CONNECTÉ ET FONCTIONNEL » avec test) : **9 / 315 = 2,9 %**. Les 112 « NON
VÉRIFIÉ » peuvent être fonctionnels, mais aucune preuve ne l'établit.

Les chiffres historiques ne sont plus d'actualité :
- **222 orphelins** : il en reste 4 orphelins et 3 doublons ;
- **192 actions « Démonstration »** : il n'en reste aucune.

Le vrai chantier est désormais l'**affichage de données de maquette** (162 écrans « fictifs » ou « partiels ») et l'**absence de
preuve** (112 écrans).

Limites de la méthode :
- un texte chiffré peut être une donnée réelle et fixe (« 48 h ») ; il est alors compté comme maquette ;
- un écran peut être couvert par un test qui appelle ses fonctions sans l'importer ;
- les boutons dessinés **sans** gestionnaire ne sont pas détectés ;
- les statuts sont donc à confirmer écran par écran pendant les lots.

## H. Plan de raccordement par lots (proposé)

| Lot | Domaine | Écrans | Dépendances |
|---|---|---|---|
| 1 | Écrans décidés : 150-1, 150-4, 275, A2, P4, 250b, S1 | 7 | aucune (règles à préciser pour S1, A2, P4) |
| 2 | Formulaires non fonctionnels (19) | 19 | schéma existant pour une partie (devis 40 : `quote_requests`) ; **aucune table d'adresses de livraison** (41) ni de concours (168) |
| 3 | Missions sur mesure (191-201) : vraies missions, jalons, propositions | 11 | RPC existantes (`save_mission`, `submit_milestone`…) |
| 4 | Concours (160-169) : concours, inscriptions et classement réels | 10 | seule `hackathon_teams` existe (équipe, thème, règlement) ; **aucune table** de concours, de dépôt ni de note : migration nécessaire |
| 5 | Catalogue, fiches, commandes (A, C, D, E) : retrait des données de maquette | ≈ 45 | `listings`, `orders` existants |
| 6 | Espaces étudiant, entreprise, talents, projets (G, H, I, J, X) | ≈ 45 | tables existantes ; certaines statistiques à calculer (vues SQL) |
| 7 | Département, administration, finance, exploitation (L, M, N, O, P) | ≈ 45 | tableaux de bord : vues SQL à créer (migration) |
| 8 | Communauté, innovations, Kéla, cercle (AD, AI, AM, K) | ≈ 50 | plusieurs fonctionnalités sans modèle de données (reels, parrainage, gains) : **décisions métier** |
| 9 | Paramètres, confiance, onboarding, borne (Q, U, V, W, AA) | ≈ 30 | sessions de borne (migration) |
| 10 | Notifications push, e-mail et SMS | transversal | Firebase (projet à créer), fournisseur e-mail et SMS (**coûts à valider**) |

Chaque lot exige des tests. Les lots 2 à 9 demandent des **compilations et des tests** qui ne sont pas raisonnables avec 0,29 Go libres.

## I. Ce qui peut être fait localement, et ce qui exige votre autorisation

**Localement, sans autorisation** :
- corrections de code et tests ciblés ;
- migrations préparées et testées sur la réplique en transaction annulée ;
- documents ;
- conception des notifications.

Ces travaux restent **limités** tant que le disque n'est pas libéré.

**Autorisation requise** :
- nettoyage disque N1 à N6 ;
- installation du SDK Android et activation de la plateforme Android dans Flutter (`flutter config --enable-android`) ;
- installation de Firefox et WebKit pour Playwright (≈ 0,3 Go) ;
- création d'un projet Firebase ;
- choix et coûts d'un fournisseur e-mail et SMS ;
- application de migrations et déploiement ;
- push ;
- comptes de recette ;
- clés Notch Pay ;
- paiement sandbox ;
- nettoyage des comptes `zz-test`.

**Décisions métier attendues** (ces écrans ne peuvent pas être raccordés sans elles) :
- S1 : animation de démarrage avant 01, ou non ?
- A2 et P4 : quelle fonction distincte de 231 et 250b ?
- concours : qui les publie, et règles de classement ?
- reels, parrainage, gains : règles de gains et de retrait ?
- adresses de livraison : livraison à domicile réelle, ou retrait à la borne seulement ?
