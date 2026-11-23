# 07 — Sécurité, performances et fiabilité

> Lectures de production faites le 01/11 **en lecture seule** (`tool/audit/prod_readonly_probe.py`, transaction `read only`) ou par
> HTTP. Aucun secret n'est affiché : seuls les **noms** sont cités. Preuves : `donnees/production_securite_catalogue.json`,
> `donnees/production_performances.csv`.

## 1. Sécurité

| Domaine | Constat | Statut |
|---|---|---|
| RLS | **toutes** les tables du schéma `public` ont la RLS activée (0 exception) ; 39 tables avec politiques ; 10 politiques sur `storage` | conforme |
| Fonctions `SECURITY DEFINER` | 72 sur 73 fonctions publiques ; **toutes** fixent `search_path` | conforme |
| Fonctions exécutables par `anon` | 8 : `verify_certificate`, `shared_cv`, `listing_rating` (publiques par conception), aides RLS `current_role_name`, `is_participant`, `is_mission_participant`, `chat_file_allowed` (sans session, elles ne révèlent rien), `rls_auto_enable` (fonction de déclencheur d'événements, qui ne s'appelle pas directement) | acceptable |
| Nouvelles fonctions (`admin_set_account`, `set_report_status`) | `revoke … from public, anon` ; `grant … to authenticated` ; rôle vérifié dans la fonction ; anonyme refusé (test T8) | conforme sur la réplique ; **absentes en production** |
| Protection inter-utilisateurs | profils : chacun ne voit que le sien (T10b) ; messagerie, fichiers et missions : RLS par participant (`security_31_rest`, `chat_attachments_rest`) | conforme (R) |
| Doubles opérations et paiements tardifs | `pay` et webhook idempotents (`paid=false`, `cancelled_at is null`), anti-rejeu par empreinte ; retrait : une confirmation à la fois, 5 essais | conforme (code et tests R) ; **non éprouvé avec un vrai paiement** |
| Sessions | suspension effective (bannissement et sessions fermées) **après** application de la migration ; avant, une suspension était seulement locale | corrigé (local) |
| Réinitialisation du mot de passe | flux PKCE, réponse identique que le compte existe ou non (pas d'énumération), session de récupération fermée après le changement | corrigé (local) |
| Secrets dans le bundle en ligne (9,5 Mo, analysé en mémoire) | `service_role` : 0 ; JWT en dur : 0 ; clé Notch Pay privée : 0 ; `MCP_ACCESS_KEY` : 0 ; `sb_secret_` : 2 **faux positifs** (tests de préfixe dans la bibliothèque Supabase, aucun jeton) ; `sb_publishable_` : clé publique, normale | conforme |
| Secrets serveur (noms) | `NOTCHPAY_KEY`, `NOTCHPAY_HASH`, `MCP_ACCESS_KEY`, `SUPABASE_*` présents ; `NOTCHPAY_API` absent (facultatif) | présents ; **`NOTCHPAY_KEY` et `NOTCHPAY_HASH` à renouveler** (exposées, historique) |
| Edge Functions | `pay` v6 (`verify_jwt=true`), `notchpay-webhook` v6 (`verify_jwt=false`, HMAC), `notchpay-mcp` v3 (`verify_jwt=true`, alors que le commentaire du code dit « désactivé ») | à aligner (documentation) |
| Stockage | `listing-images` public (images d'annonces), limité à 5 Mo et 3 types d'images ; `chat-files` (10 Mo) et `project-files` (50 Mo) **privés**, types MIME restreints ; buckets vides | conforme |
| En-têtes Web | `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` ; **pas** de `Content-Security-Policy` ni de `Strict-Transport-Security` explicite (Vercel force HTTPS) | amélioration recommandée |
| Comptes de test en production | 46 `zz-test` (rapport 01) | nettoyage à autoriser |
| Points de restauration du PC | supprimés par Windows faute d'espace (audit de stockage) | hors projet, mais risque pour le poste de développement |

## 2. Performances (production, 01/11)

| Ressource | Taille | Transférée (Brotli) | Premier octet | Total |
|---|---|---|---|---|
| `main.dart.js` | 9,52 Mo | **2,34 Mo** | 1,20 s | 2,86 s |
| `canvaskit/chromium/canvaskit.wasm` (Chrome) | 5,43 Mo | **2,07 Mo** | 0,74 s | 2,49 s |
| `canvaskit/canvaskit.wasm` (autres navigateurs) | 7,28 Mo | 2,93 Mo | 0,81 s | 5,91 s |
| `AssetManifest.bin.json` | 0,20 Mo | — | — | 0,95 s |
| Build Web complet (local) | 61,3 Mo, 1 985 fichiers ; dont assets 16,1 Mo (images 10,8 Mo ; la plus grosse 410 Ko) | — | — | — |

Mesures depuis ce PC (Douala, réseau du poste) ; elles ne valent pas test de charge.

Constats et optimisations possibles, **non appliquées** pour éviter tout risque de régression :
1. **Cache** : toutes les ressources sont servies avec `max-age=0, must-revalidate`, donc revalidées à chaque visite. Mettre en cache
   long `canvaskit/` et les polices (non versionnés par Flutter : seulement avec un nom versionné ou un `version.json` maîtrisé).
2. **Images** : 10,8 Mo de PNG et JPG ; une conversion en WebP réduirait le poids d'environ 30 à 60 % (estimation, sans toucher à la
   direction artistique).
3. **Bundle** : `lib/features` (couche d'écrans morte) est compilée ; la retirer allégerait `main.dart.js`, **après votre accord**.
4. **Chargement initial** : aucun écran d'attente dans `index.html` pendant le téléchargement des 5 Mo.
5. **Requêtes Supabase** : lectures bornées (`limit(200)` pour les signalements, `limit(500)` pour les comptes) ; rafraîchissement
   des annonces publiques toutes les 60 s (`seller.dart:183`).

**Mémoire** : `dartaotruntime` (analyse) et les testeurs Flutter engagent plusieurs Go. Sur ce PC (15,7 Go de RAM, mémoire engagée de
59 Go), la suite de tests a fait passer le fichier d'échange de 45,9 à **48,0 Go** et l'espace libre de 2,46 à **0,34 Go** (voir
l'audit de stockage).

## 3. Fiabilité

| Point | Constat |
|---|---|
| Exceptions | les appels serveur (`Backend.*`) capturent les erreurs et renvoient un message ; aucun succès sans réponse |
| Journalisation | `audit_log` côté serveur (`log_audit` et les nouvelles fonctions) ; journaux des Edge Functions dans Supabase |
| Réseau instable | écrans hors connexion (150-3, 182, 183) et session expirée (150-2) automatiques ; délais du paiement et du retrait |
| Transactions et idempotence | `create_order`, `confirm_pickup`, `pay`, webhook : transactionnels et idempotents ; nouvelles fonctions verrouillées (`for update`) |
| Sauvegardes | sauvegardes automatiques Supabase **non vérifiées** (offre du projet inconnue) ; dépôt : étiquette de sauvegarde et deux commits locaux |
| Supervision | **aucune** supervision ni alerte configurée (disponibilité, erreurs JavaScript, échecs de webhook) |

## 4. Notch Pay : procédure de renouvellement des clés et de validation sandbox (à exécuter **par vous** ou avec votre autorisation)

1. **Préparer** (aucune écriture) :
   - vérifier que le compte Notch Pay est en mode **sandbox (test)** ;
   - noter l'URL du webhook `https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-webhook`.
2. **Renouveler** dans le tableau de bord Notch Pay :
   - générer une nouvelle **clé publique de test** et un nouveau **secret de hachage (webhook)** ;
   - révoquer les anciens.
3. **Enregistrer** les secrets dans Supabase, en tapant ou collant les valeurs directement **dans le terminal**, jamais dans un
   fichier ni dans le dépôt :
   `npx supabase secrets set NOTCHPAY_KEY=… NOTCHPAY_HASH=… --project-ref zxqcnmgwhtbxkdpjqtlr`.
   Les fonctions lisent les secrets à chaque appel : aucun redéploiement n'est nécessaire.
4. **Contrôler sans payer** :
   - un POST non signé sur le webhook doit répondre **401** ;
   - `npx supabase secrets list` doit afficher les nouvelles empreintes.
5. **Paiement sandbox**, avec votre autorisation explicite :
   - un compte de recette dédié (à supprimer ensuite) et une commande de faible montant sur une annonce de test ;
   - paiement avec un numéro de test Notch Pay.
6. **Vérifier** :
   - `payment_events` contient l'événement (lecture seule ou outil MCP `boutik_recent_webhook_events`) ;
   - la commande passe à `paid=true` ;
   - un **rejeu** du même événement est ignoré ;
   - un paiement reçu **après annulation** est journalisé `paid_after_cancellation`.
7. **Retrait** : compte support de recette → `confirm_pickup` avec le code, puis 5 essais erronés sur une autre commande (blocage).
8. **Nettoyer** : comptes et données de recette supprimés avec le script de maintenance.
