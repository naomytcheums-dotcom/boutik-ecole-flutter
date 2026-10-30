# État de reprise (30/10/2026, soir — reprise par l'agent Copilot après l'interruption de Claude)

## 1. Audit de reprise (constaté, pas supposé)
| Élément annoncé par Claude | Constat | Preuve |
|---|---|---|
| Dernier commit | `34efe61` présent localement ; 3 commits **non poussés** (`8df0f0e`, `0c64272`, `34efe61`) | `git status` : « ahead 3 » |
| Modifications en cours | aucune modification suivie ; 4 scripts non suivis `e2e/explore.mjs`, `login.mjs`, `q36.mjs`, `rep.mjs` | conservés tels quels, commit `ff7d572` |
| Build et déploiement interrompus | **aboutis** : `build/web/main.dart.js` (15:28, après `34efe61`) servi en production, SHA-256 `448b9af1…` identique | `curl` + `Get-FileHash` |
| 382 tests Flutter | **confirmé** : 382 réussis | `flutter test` |
| Tests navigateur « menu du compte et commandes » | **rejoués : 5/5** (`parcours.spec.ts`) sur le site déployé | Playwright |
| Devis (« envoi de la demande » jamais vu réussi) | **non rejouable sans le propriétaire** : les comptes de `qt_state.json` ont été supprimés ; une série neuve exige l'approbation SQL d'un service de test (les comptes valideurs de démonstration sont bannis) | connexion refusée (400) |
| MCP Notch Pay | toujours **401** (« Verify JWT » actif sur `notchpay-mcp`) | `curl` |
| Webhook Notch Pay | rejette correctement : GET 405, POST sans signature 401, signature fausse 401 ; code relu (HMAC-SHA256 du corps brut, comparaison en temps constant, anti-rejeu, relecture fournisseur) | `curl` |
| Accès d'administration de la base | **absent dans cet environnement** (pas de jeton Supabase CLI ni d'accès SQL) : aucune migration ne peut être appliquée, aucun compte de test supprimé, aucun réglage de fonction modifié | `supabase projects list` → jeton requis |

## 2. Travaux de la reprise
- **Engagements réversibles** (écrans 101, 153, 217, 89, 35) : l'état enregistré est lu sur le serveur et affiché sur le bouton (« Inscrit(e) ✓ · Gérer mon inscription », « Candidature ✓ », « Précommandé ✓ », « Alerte active ✓ ») ; un nouvel appui rappelle la date et propose l'annulation (`cancel_engagement`). Le doublon reste refusé par le serveur.
- **Parcours de candidature** : 153 « Postuler » → 159 « Candidature envoyée » → « Mes candidatures » (76) → « Retirer » (retire la candidature active la plus récente) ; « Contacter » → 55 ; « Autres offres » → 152 ; « Ignorer » revient en arrière.
- **Préférences enregistrées** : 156 (8 interrupteurs) et 236 (4 canaux) liés à un état lisible, enregistrés (`alert_prefs`, `channel_prefs`) et relus à la connexion.
- **Actions réelles** : portfolio (72, `portfolio_item`), écrire à un mentor (77, `contact_request`), question au vendeur (39 → messagerie réelle, produit consulté affiché).
- **29 actions « Démonstration » supprimées** (105 → 76) : liens métier (18→49, 26→05, 69/154→18c, 93/189→94, 94→93b, 87→278, 102→22c, 194/233→196, 233→189, 215→90, 221→P3, 198 « Qualifier »→199).
- **Défaut corrigé (routeur)** : les identifiants `P3`, `L1`, `A3`… (studio créateur) et `146-1`, `148-1`… (variantes) étaient appelés `p3`, `148_1`, `147_2`… par une vingtaine de liens, qui ouvraient « Écran introuvable » — dont **« Paramètres » du menu du compte**. Résolution tolérante à la casse et au séparateur (`screenById`), test qui vérifie chaque lien de chaque écran.
- **Navigation contextuelle** : 60 liens posés sur des libellés existants (`tool/audit/contextual_links.py`, marqueur `// lien métier`, idempotent) et entrées du menu du compte filtrées par rôle (studio, vœux, campagnes, entreprise, administration, finance, kiosques, jury, sécurité). **225 → 302 écrans atteignables** depuis l'accueil.
- **Sécurité** : écrans 180 et 181 (rôles et permissions) réservés à l'administrateur (ils étaient ouverts à tous).
- **Outil d'audit** : `nav_graph.py` reconnaît désormais les identifiants à lettre (ils étaient tous comptés orphelins). Ne **pas** relancer `apply_journeys.py` : un essai à blanc montre qu'il retirerait une quarantaine de liens existants.

## 3. Tests exécutés pendant la reprise
| Type | Commande | Résultat |
|---|---|---|
| Flutter (unitaires, widgets, 315 goldens) | `flutter test` | **394 réussis** (382 + 12 nouveaux) ; aucune image de référence modifiée |
| Analyse | `flutter analyze lib test` | aucune erreur (avertissements/infos préexistants) |
| Navigateur, site déployé | `npx playwright test tests/parcours.spec.ts` | 5/5 (avant et après déploiement) |
| Navigateur, site déployé | `npx playwright test tests/engagements.spec.ts` | **5/5** : inscription → état → désinscription (serveur `cancelled`) ; candidature → 159 → 76 → retrait (serveur `cancelled`) ; canaux enregistrés et relus après rechargement ; « Paramètres » s'ouvre ; question exigée puis adressée au serveur |
| Navigateur, site déployé | `npx playwright test tests/visiteur.spec.ts` | 12/12 |
| Navigateur, devis | `devis.spec.ts` | **non exécutable** (cf. §1) |
| REST | — | aucun nouveau test REST : aucune migration ajoutée (les fonctions `engage`/`cancel_engagement` sont couvertes par `engagements_rest.py`, 18/18, Claude) |

## 4. Déploiement
- Commit déployé : `980f163` ; `flutter build web --release` ; `vercel deploy --prod` depuis `build/web`.
- Version servie = build testé : SHA-256 de `main.dart.js` **`3c40979c3f16d3fed0fd176a4c97566a5ee5aa6761dbdb8983bdc4e9975c3cf9`** des deux côtés.

## 5. Données de test à supprimer (action du propriétaire)
Comptes jetables créés par les tests navigateur de la reprise : `zz-test-par-*@example.com` (au moins 4, davantage si le premier lancement interrompu par l'absence de Chromium en a créé) et `zz-test-eng-*@example.com` (4), avec leurs engagements. Suppression : `delete from auth.users where email like 'zz-test-%@example.com';` (les profils et engagements suivent par cascade).

## 6. Reste à faire (voir `RESTE_A_FAIRE.md`)
Bloqué par le propriétaire : MCP (Verify JWT), webhook réel, renouvellement des clés exposées, approbation d'un service de test pour rejouer `devis.spec.ts`, nettoyage des comptes jetables, toute nouvelle migration. À développer : 76 actions « Démonstration », 13 écrans sans entrée (12 états/variantes + 47), tableaux de bord vendeur calculés, photo de profil, certification complète.

## 7. Reprendre
```powershell
cd C:\Users\NITROV15\Downloads\boutik_ecole_flutter
$env:Path = "C:\Users\NITROV15\dev\flutter\bin;C:\Program Files\Git\cmd;C:\nvm4w\nodejs;" + $env:Path
git log --oneline -5; git status --short
python -I tool\audit\nav_graph.py ; python -I tool\audit\gen_matrix.py   # état des liens et des actions de démonstration
flutter test                                                            # 394 attendus
cd e2e; npx playwright test tests/parcours.spec.ts tests/engagements.spec.ts --workers=1
```
