# État de reprise — 3ᵉ reprise (31/10/2026, matin)

> Départ : `6401966` (poussé). Arrivée : voir §7. Production servie : `main.dart.js` SHA-256 **`061029c244ac7b21e1bbdae23fc20fd6f8dc9809499925e0d55d62de35ce9d9a`**.
> Règle appliquée : une fonctionnalité n'est dite « vérifiée en production » que si un test l'a exercée sur `https://boutik-ecole.vercel.app` et la base `zxqcnmgwhtbxkdpjqtlr`.

## 1. Interventions annoncées : ce qui est réellement constaté en production
| Élément | Constat | Preuve |
|---|---|---|
| Migration `20261031a` | **NON appliquée** | `missions.status` → PostgreSQL 42703 ; `wishes`, `kiosks`, `certificates`, `order_cancellations` → PGRST205 ; `verify_certificate`, `save_mission`, `cancel_order_with_reason` → PGRST202 (vérifié à 05 h 10 puis de nouveau avant le déploiement) |
| Migration `20261031b` (nouvelle) | non appliquée (écrite pendant cette reprise) | `shared_cv` → PGRST202 |
| `MCP_ACCESS_KEY` | **configurée** | `tools/call` → « Accès refusé » au lieu de « outils pas encore activés » ; sans clé, clé fausse (en-tête), clé dans l'URL : refusés |
| MCP, passerelle | `initialize`/`tools/list` répondent avec l'en-tête public `apikey` (200) ; sans en-tête : 401 | appels JSON-RPC |
| MCP, appel authentifié | **non vérifiable** sans la clé (jamais demandée) | commande fournie : INTERVENTIONS §9 |
| Webhook, événement sandbox authentique | **non vérifiable** (journal lisible seulement avec la clé MCP ou le rôle service) | GET 405, POST non signé 401 (inchangé) |
Conséquence : les 28 actions de `20261031a` et 12 des 16 nouvelles (toutes sauf 23, 264, 272, 275) **ne peuvent pas être vérifiées en production** ; elles y affichent « fonction pas encore activée » (vérifié par `production.spec.ts`). Hypothèse : SQL exécuté sur un autre projet. Marche à suivre : `INTERVENTIONS_PROPRIETAIRE.md` (« Constat du 31/10 », §8, §9).

## 2. Les 16 dernières actions « Démonstration » : 0 restante
| Écran | Action réelle | Serveur | Vérification |
|---|---|---|---|
| 118 | identité de l'établissement (direction, admin) | `institution_settings`, `save_institution` | navigateur (base isolée) |
| 265 | modification d'un modèle de notification (admin) | `notification_templates` | REST |
| 264 | aperçu des pages publiques (Accueil, À propos, FAQ, CGU) | — | code, liens testés |
| 280 | clé d'intégration créée une fois, **empreinte SHA-256 seule conservée**, révocation | `api_keys` | navigateur + SQL (clé absente en clair) |
| 286 | invitation d'un membre du département (notification si le compte existe) | `department_invitations` | REST |
| 263, 83, 279 | dépôts de fichiers (médiathèque, projet) : types JPG/PNG/WebP/PDF/MP4/ZIP, 5 Mo par image, 50 Mo sinon, exécutables refusés, compartiment privé | `project-files`, `files`, `register_file` | navigateur (279) + REST (263) |
| 196 | dossier de mission : messages et fichiers entre le client et le prestataire retenu, notifications | `mission_messages`, `send_mission_message` | navigateur (message, PDF accepté, .exe refusé, tiers sans accès) |
| 228 | lien de CV régénéré (l'ancien cesse de fonctionner), page publique `/#/cv/<jeton>` sans coordonnées | `cv_links`, `shared_cv` | navigateur |
| 46 + 146-2 | code de retrait délivré après paiement ; remise au kiosque seulement avec le bon code ; commande livrée | `my_pickup_code`, `confirm_pickup` | navigateur (code faux refusé, bon code accepté) |
| 272 | double authentification TOTP (QR code, code faux refusé, session AAL2) | Supabase Auth MFA | **production : REST 8/8 et navigateur 1/1** |
| 158 | comparaison des propositions réellement reçues | `mission_proposals` | code |
| 23 | « Innovations » ouvre le registre des innovations (87) | — | lien |
| 275 | « Continuer » reprend le formulaire réel (58) | — | lien |
Écran 146-2 « Confirmer la remise » n'avait aucune action : reliée à la vérification du code. Écran 46 : en ligne, le numéro de la commande consultée remplace celui de la maquette et le code fictif « 482 915 » est masqué.

## 3. Défauts trouvés pendant cette reprise et corrigés
1. Copie dans le presse-papiers refusée par le navigateur (permission ou copie après un appel réseau) : l'activation de la double authentification s'interrompait après l'inscription du facteur. Copies rendues non bloquantes, messages exacts.
2. Le code de retrait était demandé pour la commande d'exemple de la maquette quand la liste des commandes n'était pas encore chargée : liste relue avant l'appel.
3. La clé TOTP était affichée dans un `SelectableText` absent de l'arbre d'accessibilité : remplacé.
4. Une tentative TOTP échouée laissait un facteur non vérifié ; un nouvel essai en créait un autre : trois essais sur le même facteur, facteurs abandonnés retirés avant une nouvelle inscription.
5. `feedback_rest.py` ne conservait pas les mots de passe nécessaires à `avis.spec.ts` : la série avis passe désormais 9/9 en une seule exécution.

## 4. Tests exécutés (résultats réels)
| Domaine | Base isolée (Docker, 17 migrations) | Production |
|---|---|---|
| Flutter (`flutter test`) | **403 réussis** (401 + 2 nouveaux tests unitaires) ; 315 goldens inchangés | — |
| REST | `lots_rest` 77/77 · `lots2_rest` 55/55 · `quotes_rest` 30/30 · `mfa_rest` 8/8 ; migrations rejouées deux fois (idempotentes) | `mfa_rest` **8/8** |
| Navigateur | **51/51** : avis 9, devis 5, engagements 5, lots 7, lots2 7, mfa 1, parcours 5, visiteur 12 (2 tests « avant migration » ignorés par conception) | **27/27** : engagements 5, mfa 1, parcours 5, visiteur 12, production 4 (avant migration : vœu, certificat, lien de CV ; page CV publique) |
| Nettoyage des comptes de test | dry-run revalidé avec `20261031b` (143 comptes, données hors test intactes) | non exécuté (pas d'accès) |

## 5. Écrans et parcours
303/315 écrans atteignables par un parcours métier ; les 12 autres sont des états réels (150-2, 150-3, 182, 183) ou des variantes de maquette (S1, A2, P4, 250B, 176, 150-1, 150-4, 275). Aucun outil de liens relancé. 0 action « Démonstration » dans le code (`nav_graph.py`).

## 6. Ce qui reste (interventions du propriétaire uniquement)
1. Appliquer `20261031a` puis `20261031b` **sur le projet `zxqcnmgwhtbxkdpjqtlr`** (§1 et §8), puis relancer `production.spec.ts` et les specs `lots`/`lots2` en production (comptes du personnel à créer : §7).
2. Vérifier l'appel MCP authentifié et, si besoin, redéployer `notchpay-mcp` (§9).
3. Renouveler les clés Notch Pay et déclencher un paiement sandbox (§4–5) ; le résultat est lisible par l'outil MCP `boutik_recent_webhook_events`.
4. Exécuter `supabase/maintenance/cleanup_test_accounts.sql` (ROLLBACK puis COMMIT).

## 7. Commits et déploiement
`a86d3ff` migration 20261031b et tests · `6ae90f5` application (16 actions) · `4daae97` e2e et audit · `4eb9b8a` écrans protégés · `0c18c17` feedback_rest · puis documentation. Branche `feat/figma-fidele`.
Déploiement Vercel production vérifié : SHA-256 servi = build local `061029c2…`.

---
# [2ᵉ reprise] État de reprise et bilan final (30/10/2026, nuit — 2ᵉ reprise par l'agent Copilot)

> Point de départ de cette reprise : commit `841b6e0` (poussé), arbre propre. Dernier commit de cette reprise : voir §9.
> Accès disponibles : dépôt Git, Vercel (CLI authentifiée), Docker. **Aucun accès administrateur à la base de production** ni au tableau de bord
> Notch Pay : les actions correspondantes sont préparées dans `INTERVENTIONS_PROPRIETAIRE.md`, avec leurs vérifications.

## 1. Environnement de test isolé (nouveau)
Une pile Supabase **locale** (Docker, `%USERPROFILE%\boutik_local`, hors du dépôt) reçoit `schema.sql` + les 15 migrations, dont la nouvelle `20261031a`.
Les rôles de personnel et les approbations y sont faits par SQL en tant que propriétaire **local** ; aucune donnée de production n'est touchée.
L'application se construit vers cette base par `--dart-define=BE_URL=… --dart-define=BE_KEY=…` (production par défaut) ; les scripts REST et les specs
Playwright lisent `BE_URL` / `BE_KEY` (production par défaut). `lots_rest.py` et `lots.spec.ts` refusent de s'exécuter hors base locale.

## 2. Demandes de devis
- Code, table, RLS, fonctions (`request_quote`, `answer_quote`, `decide_quote`, `cancel_quote`) relus.
- REST sur base isolée : **30/30** (visiteur refusé, auto-devis refusé, besoin incomplet, service inexistant, doublon, tiers sans accès, notifications, décisions, annulations, aucune écriture directe).
- Navigateur (`devis.spec.ts`) sur base isolée : **5/5**, dont « le demandeur envoie une demande de devis » vu réussi de bout en bout pour la première fois
  (client → service → demande → réception par le prestataire → réponse → acceptation, persistance vérifiée en REST).
- En production : rejouable après approbation d'un service de test par le propriétaire (INTERVENTIONS §6).

## 3. Comptes de test
La requête proposée précédemment (`delete from auth.users …`) **échouerait** : 8 tables référencent les profils sans cascade (annonces, commandes,
missions, certificats, journaux de bornes, auteurs de décision). Procédure contrôlée : `supabase/maintenance/cleanup_test_accounts.sql`
(inventaire, garde-fous, transaction terminée par ROLLBACK, totaux avant/après). **Validée sur la base isolée** (22 comptes et leurs données supprimés,
données hors test intactes ; garde-fou déclenché par une commande d'un compte non-test sur une annonce de test). Non exécutée en production (pas d'accès).

## 4. Notch Pay
- **MCP (401)** : la passerelle « Verify JWT » est incompatible avec un client MCP (pas de JWT ; les clés publishable ne sont pas des JWT). La fonction
  protège déjà ses outils par `MCP_ACCESS_KEY` (temps constant). Corrigé : la clé n'est plus acceptée **dans l'URL** (elle apparaîtrait dans les journaux),
  seulement en en-tête (`x-mcp-access-key`, `Authorization: Bearer`). Test de conformité : **27/27** (dont « clé dans l'URL refusée »).
  **Code modifié non déployé** : le déploiement de fonctions exige l'accès Supabase (commande exacte et désactivation de Verify JWT pour cette seule fonction : INTERVENTIONS §3).
  Production actuelle : toujours 401 (`curl`).
- **Webhook** : algorithme vérifié (HMAC-SHA256 du corps brut, `x-notch-signature`, temps constant, anti-rejeu, relecture fournisseur, sous-paiement,
  devise, référence) — **19/19** sur le vrai code avec fournisseur simulé. Production : sans signature 401, signature fausse 401, GET 405.
  **Aucun événement authentique reçu** : il faut renouveler les clés (exposées) puis déclencher un paiement sandbox (INTERVENTIONS §4–5).

## 5. Les 76 actions « Démonstration »
| Traitement | Nombre | Détail |
|---|---|---|
| Action serveur réelle, **nouvelle fonction** (migration `20261031a`) | 28 | besoins 90 (brouillon, publier), propositions 93b (accepter, refuser), attribution 199, pack 202 (commander), jalons 234 (valider, correction) et 285, vœux 218 (brouillon, publier), campagnes 84 (brouillon, continuer), projets 205 (brouillon, envoyer), journal 82, liens de projet 278, lives 224 (brouillon, planifier), liens du profil 271 (ajouter, enregistrer) et P5, certificats 213/283 (émettre), 166 (mes certificats), 211 (vérification publique), bornes 277 (journal d'incidents), 282 (événement) |
| Action réelle sur un backend **existant** | 9 | service 59 (brouillon, publier → annonce « Services »), export CSV 284 (commandes) et 288 (catalogue), état réseau 206, invitation WhatsApp 241, filtres de la borne 207 (tout, produits, services) |
| Ouverture du bon parcours fonctionnel | 8 | 202 personnaliser → 90, 276 → catalogue hors ligne 207, 287/288 « nouvelle fiche » → 58, 231/A2 « commencer » → assistante A1, 171 « continuer en sécurité » → paiement 08, 207 « missions » → 191 |
| Dépendance externe expliquée (rien de simulé) | 4 | 219 duel (séquestre), 250 et 250b « propulser » (option payante), L1 « lancer le live » (pas de service de diffusion) |
| Pas une action (zone tactile retirée) | 11 | bulles de conversation 196 (3), 55 (2), 95 (2), textes d'information 18c (2), titre L1, entrée de menu courante 237 |
| **Restant** | **16** | voir §8 |

Fonctionnelles **immédiatement en production** : les 9 + 8 + 4 + 11 ci-dessus, et l'annulation avec motif (repli sur `cancel_order`).
Les 28 actions « nouvelle fonction » affichent en production « fonction pas encore activée » jusqu'à l'application de la migration (vérifié par `production.spec.ts`) ;
elles sont **vérifiées sur base isolée** (REST 77/77, navigateur 7/7).

## 6. Tables et migration
`20261031a_missions_voeux_campagnes_certificats_bornes.sql` — **écrite, testée sur base isolée, NON appliquée en production** :
`missions` (étendue ; ancienne règle permettant à tout étudiant de modifier toute mission supprimée), `mission_proposals`, `mission_milestones`, `wishes`,
`campaigns`, `certificates` (code unique, empreinte SHA-256, révocation, vérification publique limitée), `kiosks`, `kiosk_incidents`, `kiosk_events`
(créneaux sans chevauchement), `projects`, `project_steps`, `scheduled_lives`, `profiles.links` (https uniquement), `order_cancellations`,
synchronisation `orders.cancelled` / `cancelled_at`. RLS sur chaque table, aucune écriture directe, 23 fonctions serveur, idempotente, retour arrière en fin de fichier.
Défauts trouvés et corrigés par les tests : expression régulière invalide (répétition > 255), envoi d'un projet ignorant la présentation déjà enregistrée,
politique non idempotente, et **défaut existant** : `cancel_order` renseignait `cancelled_at` sans `cancelled` → une commande annulée réapparaissait comme
active dans l'application (corrigé côté application immédiatement, et côté serveur par la migration).

## 7. États contextuels et écran 47
- Coupure réseau → 150-3 ; « Réessayer » ne quitte l'état que si le réseau est revenu ; retour du réseau → écran précédent + « Connexion rétablie » ;
  « Mes commandes » hors ligne → 183 ; session perdue sans déconnexion demandée → 150-2 (état remis à zéro). Vérifié en navigateur (coupure simulée).
- Écran 47 : relié au détail de commande (29) pour une commande réelle non payée ; données de la commande affichées ; motif sélectionnable et enregistré ;
  vérifié en navigateur sur base isolée (commande annulée, motif `too_slow` lu en REST).
- Écrans sans lien, apparaissant par état ou variantes de maquette (12) : S1 (démarrage animé, variante de 01), A2 (variante de 231), P4 et 250B (variantes de 250),
  176 (variante d'accueil), 182 (atteint depuis 150-3), 183 (hors ligne), 150-1 (synchronisation : non affiché, aucune donnée de synchronisation réelle),
  150-2 (session expirée), 150-3 (coupure), 150-4 (état vide, rendu par la liste réelle de 45), 275 (formulaire en erreur, variante de 58).
- Navigation : **303/315** écrans atteignables par des liens métier (302 → 303 avec 47) ; aucun outil de liens relancé.

## 8. Restant (16 actions) et cause
118 identité de l'établissement, 265 modèles de notifications, 264 aperçu des pages, 280 clés d'intégration, 286 invitation d'équipe (administration : tables
et règles à définir) · 263, 83, 279, 196 « ajouter un fichier » (téléversements : compartiment de stockage dédié et analyse antivirus à prévoir) · 196 « envoyer »
(messagerie de dossier de mission) · 272 vérification en 2 étapes (MFA TOTP de Supabase à activer et à intégrer) · 228 régénérer le lien du CV (jeton de partage)
· 46 code de retrait (absent du modèle de commande) · 158 comparer des candidatures · 23 filtre « Innovations » · 275 « continuer » (variante d'erreur).

## 9. Tests, commits, déploiement
| Domaine | Résultat |
|---|---|
| Flutter | **401 réussis** (394 + 7 nouveaux), 315 goldens inchangés (une différence de 704 px sur 47 détectée et corrigée, pas de régénération) |
| REST base isolée | lots 77/77 · devis 30/30 · engagements 18/18 · favoris 9/9 |
| MCP / webhook (vraies fonctions, dépendances simulées) | 27/27 · 19/19 |
| Navigateur base isolée | 34/34 : lots 7, devis 5, engagements 5, parcours 5, visiteur 12 |
| Navigateur production | 24/24 exécutés : engagements 5, parcours 5, visiteur 12, production (avant migration) 2 ; 21 ignorés par conception (base isolée ou état préparé requis) |
| Commits | `b488df6` serveur et tests, `5862ab2` application, `63ba0ab` e2e et audit, `60266f5` écrans protégés, puis documentation |
| Déploiement | Vercel production, `main.dart.js` SHA-256 **`ae88a0f2987042e7bd5061668a9ba7087380055c40b8b602785823bd54a5d4dc`** = build local |

## 10. Reprendre
```powershell
cd C:\Users\NITROV15\Downloads\boutik_ecole_flutter
$env:Path = "C:\Users\NITROV15\dev\flutter\bin;C:\Program Files\Git\cmd;C:\nvm4w\nodejs;C:\Program Files\Docker\Docker\resources\bin;" + $env:Path
cd $env:USERPROFILE\boutik_local; npx supabase@2.122.0 start -x studio,imgproxy,vector,logflare,supavisor,edge-runtime,mailpit; cd -
# base isolée vierge : appliquer schema.sql puis supabase/migrations/*.sql (dans l'ordre) avec : Get-Content <f> -Raw | docker exec -i supabase_db_boutik_local psql -U postgres -v ON_ERROR_STOP=1
$env:BE_URL="http://127.0.0.1:54321"; $env:BE_KEY="<clé publishable affichée par « supabase start »>"
python supabase\tests\lots_rest.py                       # 77/77 attendu
flutter test                                             # 401 attendus
flutter build web --release --dart-define=BE_URL=$env:BE_URL --dart-define=BE_KEY=$env:BE_KEY -o build/web_local
# servir build/web_local sur 127.0.0.1:8099 puis : cd e2e; $env:BASE_URL="http://127.0.0.1:8099"; npx playwright test --workers=1
```

---
# Historique — 1ʳᵉ reprise


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
