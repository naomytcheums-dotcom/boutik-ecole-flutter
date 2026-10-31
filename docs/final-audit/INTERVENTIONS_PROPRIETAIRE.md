# Interventions du propriétaire (préparées et vérifiées autant que possible sans vos accès)

Aucune de ces actions ne demande de communiquer un secret dans une conversation. Chaque étape indique la vérification attendue.

> **Mise à jour du 31/10 (audit des migrations)** : appliquer **31a puis 31b puis `20261031c_correctifs_securite_audit.sql`** dans la même séance — 31a/31b seules ouvrent 10 défauts de sécurité démontrés (voir [ANOMALIES_ET_CORRECTIONS.md](./ANOMALIES_ET_CORRECTIONS.md)).
> **Ne pas utiliser `supabase db push`** avant la régularisation de l'historique : il rejouerait `20261029_p0_securite.sql` (écritures sur des comptes). Procédure complète : [AUDIT_REGULARISATION_MIGRATIONS_20261031.md](./AUDIT_REGULARISATION_MIGRATIONS_20261031.md) §8–§9 et [PLAN_PRODUCTION.md](./PLAN_PRODUCTION.md).

## 1. Appliquer la migration `20261031a` (missions, vœux, campagnes, certificats, bornes, projets, lives, liens, motif d'annulation)
Pré-requis : migrations jusqu'à `20261030k` appliquées (vérifié : `engage`, `request_quote` répondent en production).

1. Vérification avant (Supabase → SQL Editor) — résultat attendu : `t | null | null | null`
   ```sql
   select to_regclass('public.missions') is not null as missions_existe, to_regclass('public.wishes') as wishes,
          to_regclass('public.certificates') as certificates, to_regclass('public.kiosks') as kiosks;
   select count(*) as missions_existantes from missions;   -- noter la valeur (les lignes existantes passent en statut « draft »)
   ```
2. Coller le contenu de `supabase/migrations/20261031a_missions_voeux_campagnes_certificats_bornes.sql` dans le SQL Editor → **Run**.
   Le script est idempotent (il peut être relancé) ; il contient en fin de fichier le bloc de retour arrière.
3. Vérification après — attendu : 23 fonctions, 4 bornes, `introuvable = true`, `cancelled` synchronisé (requêtes vérifiées sur la base isolée)
   ```sql
   select count(*) from pg_proc where proname in ('save_mission','propose_on_mission','decide_proposal','assign_mission','submit_milestone','decide_milestone',
     'save_wish','delete_wish','review_wish','save_campaign','review_campaign','issue_certificate','revoke_certificate','verify_certificate',
     'report_kiosk_incident','schedule_kiosk_event','save_project','add_project_step','review_project','save_live','save_profile_links',
     'cancel_order_with_reason','sync_order_cancelled');            -- 23
   select id from kiosks order by id;                                -- borne-1 … borne-4
   select verify_certificate('BE-CERT-00000000');                    -- {"introuvable": true, …}
   select count(*) from orders where cancelled_at is not null and not cancelled;   -- 0
   ```
4. Puis : `notify pgrst, 'reload schema';` ; le test `e2e/tests/production.spec.ts` s'ignore alors de lui-même et les écrans 90, 218, 84, 205, 224,
   82, 278, 271, 93b, 199, 202, 234, 285, 213, 283, 166, 211, 277, 282 deviennent pleinement opérationnels (vérifiés sur base isolée : 77/77 REST, 7/7 navigateur).

## 2. Nettoyer les comptes de test
`delete from auth.users where email like 'zz-test-%@example.com'` **échouerait** : annonces, commandes, missions, certificats, journaux de bornes
référencent les profils sans cascade. Utiliser `supabase/maintenance/cleanup_test_accounts.sql` :
1. exécuter seulement la requête « 1. INVENTAIRE » et relire la liste (que des adresses `zz-test-…@example.com`, domaine réservé RFC 2606) ;
2. exécuter le fichier entier : il se termine par `ROLLBACK` et affiche `comptes_test_restants = 0` et `comptes_reels_avant = comptes_reels_apres` ;
   il s'arrête de lui-même (« ARRÊT : … ») si une donnée d'un compte réel dépend d'un compte de test ;
3. si les totaux sont bons, remplacer la dernière ligne `rollback;` par `commit;` et relancer ;
4. fichiers de stockage orphelins : Storage → buckets `listing-images` et `chat-files` (requête fournie en fin de fichier).
Validé sur la base isolée : 22 comptes de test et leurs données supprimés, données hors test intactes ; garde-fou déclenché par une commande « réelle » portant sur une annonce de test.

## 3. Serveur MCP Notch Pay (erreur 401)

> **Mise à jour du 31/10 (~16 h 15)** : `notchpay-mcp` v3 déployée (code du dépôt, commit `d695001`) ; la clé dans l'URL est refusée.
> **Verify JWT est resté actif** : la passerelle accepte la clé publiable (en-tête `apikey` ou `Authorization: Bearer`), il suffit donc que le
> client MCP envoie aussi `x-mcp-access-key`. Les étapes 3 et suivantes ci-dessous (désactivation) ne sont **plus nécessaires** ; la vérification
> avec votre clé se fait par le §9.
Cause : la passerelle Supabase exige un JWT (« Verify JWT » activé) ; les clients MCP n'en ont pas, et les nouvelles clés « publishable » ne sont pas des JWT.
La fonction protège elle-même ses outils : `tools/call` exige `MCP_ACCESS_KEY` (comparaison en temps constant) ; `initialize`/`tools/list`
ne renvoient aucune donnée. La clé n'est plus acceptée dans l'URL (journalisée) : uniquement en en-tête (`x-mcp-access-key` ou `Authorization: Bearer`).
1. Générer la clé **sur votre poste** (elle ne doit apparaître nulle part ailleurs) :
   PowerShell : `$b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Fill($b); -join ($b | % { $_.ToString('x2') })`
2. Supabase → Edge Functions → Secrets → ajouter `MCP_ACCESS_KEY` = la valeur générée.
3. Redéployer la fonction modifiée **et** désactiver « Verify JWT » pour **cette fonction seulement** :
   `npx supabase@2.122.0 login` puis `npx supabase@2.122.0 functions deploy notchpay-mcp --project-ref zxqcnmgwhtbxkdpjqtlr --no-verify-jwt`
   (ou Edge Functions → notchpay-mcp → Details → « Enforce JWT verification » : désactivé, après avoir déployé le nouveau code).
   `notchpay-webhook` reste sans JWT (Notch Pay n'en envoie pas ; il est protégé par la signature HMAC) ; `pay` garde sa configuration actuelle.
4. Vérifications (attendu) :
   - `POST …/functions/v1/notchpay-mcp/mcp` avec `{"jsonrpc":"2.0","id":1,"method":"tools/list"}` → 200 et 4 outils ;
   - `tools/call` sans en-tête → `isError: true` « Accès refusé » ; avec `?key=` dans l'URL → refusé ; avec `x-mcp-access-key` → données (téléphones et e-mails masqués) ;
   - Journaux de la fonction : aucune valeur de clé (la fonction n'en écrit jamais).
   Test local de référence : `python supabase/tests/mcp_e2e.py` → 27/27.

## 4. Renouveler les clés Notch Pay (exposées dans une conversation antérieure)
1. Notch Pay → Paramètres → Clés API : régénérer la **clé API** (mode test/sandbox d'abord) et le **Hash Key** du webhook. Les anciennes valeurs deviennent invalides.
2. Supabase → Edge Functions → Secrets : remplacer `NOTCHPAY_KEY` et `NOTCHPAY_HASH` par les nouvelles valeurs (saisie directe, jamais dans un fichier du dépôt).
3. Aucune modification de code n'est nécessaire (les fonctions lisent les secrets à chaque appel).

## 5. Valider le webhook avec un événement authentique (sandbox, sans argent réel)
1. Notch Pay → Paramètres → Webhooks : URL `https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-webhook`, événements `payment.complete`,
   `payment.failed`, `payment.canceled` ; vérifier que le Hash Key affiché est celui de l'étape 4.
2. Avec la clé **sandbox**, passer une commande sur le site avec un numéro de test Notch Pay (paiement simulé par le fournisseur, aucun débit),
   ou utiliser le bouton d'envoi d'événement de test s'il est proposé dans le tableau de bord.
3. Contrôles : Edge Functions → notchpay-webhook → Logs (aucune ligne « webhook refusé : signature invalide ») ;
   SQL : `select event_type, reference, outcome, received_at from payment_events order by received_at desc limit 5;` → `confirmed` (ou le motif du refus) ;
   la commande correspondante passe à `paid = true`.
   Si la signature est refusée, la ligne de journal indique sans aucun secret si le corps re-sérialisé ou la clé API auraient correspondu (diagnostic).
   Algorithme vérifié (code et 19/19 tests locaux) : HMAC-SHA256 du corps brut avec le Hash Key, en-tête `x-notch-signature`, comparaison en temps constant, anti-rejeu par empreinte du corps.

## 6. Rejouer les tests navigateur des devis en production (facultatif)
`python supabase/tests/quotes_rest.py 1` → approuver le service affiché (`update listings set status='approved' where title='<titre>';`) →
`STATE=<fichier> npx playwright test devis --workers=1`. Déjà vérifié 5/5 sur base isolée identique au schéma de production.

## 7. Comptes « dept », « support », « admin » de recette
Les rôles du personnel ne peuvent pas être pris à l'inscription (règle de sécurité vérifiée). Pour recetter en production les écrans du département
(vœux, campagnes, projets, certificats, attribution) et du support (bornes) : créer un compte, puis en SQL `update profiles set role = 'dept' where email = '…';`.

---

## Constat du 31/10/2026 (5 h – 7 h) après l'annonce « interventions effectuées »
Vérifications faites sur le projet utilisé par le site, `zxqcnmgwhtbxkdpjqtlr` :
| Intervention | Constat | Preuve |
|---|---|---|
| §1 migration `20261031a` | **non appliquée** | `select … missions.status` → erreur PostgreSQL 42703 « column missions.status does not exist » ; `wishes`, `kiosks`, `certificates`, `order_cancellations` : PGRST205 ; `verify_certificate` : PGRST202 |
| §2 nettoyage des comptes de test | non vérifiable sans accès (la procédure reste valide, revalidée avec `20261031b`) | — |
| §3 `MCP_ACCESS_KEY` | **configurée** : `tools/call` répond « Accès refusé » (et non « outils pas encore activés ») ; sans clé, clé fausse, clé dans l'URL : refusés | appels JSON-RPC |
| §3 « Verify JWT » | la passerelle exige toujours un en-tête d'authentification : sans en-tête → 401 ; avec l'en-tête public `apikey` (clé publishable) → 200 | `curl` |
| §3 code corrigé de `notchpay-mcp` | indéterminable sans la clé (un appel authentifié avec la clé en en-tête doit réussir, avec la clé dans l'URL doit échouer) | — |
| §4–5 clés Notch Pay, événement sandbox | non vérifiables sans accès (le journal `payment_events` n'est lisible qu'avec la clé MCP ou le rôle service) | — |

Hypothèse la plus probable : le SQL a été exécuté sur **un autre projet** Supabase, ou l'exécution s'est arrêtée à une erreur. Le projet du site est `zxqcnmgwhtbxkdpjqtlr` (voir `lib/figma/live/backend.dart`).

## 8. Appliquer la migration `20261031b` (après `20261031a`, dans le même éditeur SQL)
1. Avant : `select to_regclass('public.mission_proposals') is not null;` → `t` (sinon appliquer d'abord `20261031a`).
2. Coller `supabase/migrations/20261031b_parametres_fichiers_dossiers_cv_retrait.sql` → **Run** (idempotente).
3. Après — attendu (vérifié sur base isolée) :
   ```sql
   select count(*) from pg_proc where proname in ('save_institution','save_notification_template','create_api_key','revoke_api_key','send_mission_message',
     'register_file','regenerate_cv_link','shared_cv','my_pickup_code','confirm_pickup','invite_department_member','is_mission_participant','storage_file_allowed'); -- 13
   select id, public, file_size_limit from storage.buckets where id = 'project-files';   -- project-files | f | 52428800
   select shared_cv(repeat('0', 32));                                                     -- (vide : lien inconnu)
   select count(*) from notification_templates;                                           -- 4
   ```
4. `notify pgrst, 'reload schema';` puis relancer `npx playwright test production --workers=1` : les tests « avant migration » s'ignorent d'eux-mêmes.

## 9. Vérifier le MCP avec la clé (sur votre poste, la clé ne doit pas apparaître ailleurs)
```powershell
$k = Read-Host -AsSecureString "MCP_ACCESS_KEY" | ConvertFrom-SecureString -AsPlainText
$u = "https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-mcp/mcp"
$b = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"boutik_recent_webhook_events","arguments":{}}}'
curl.exe -s -X POST $u -H "Content-Type: application/json" -H "apikey: sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01" -H "x-mcp-access-key: $k" -d $b   # attendu : liste (éventuellement vide), isError false
curl.exe -s -X POST "$u?key=$k" -H "Content-Type: application/json" -H "apikey: sb_publishable_yYEzuivRZlBnVOkuMCiSow_syCjss01" -d $b               # attendu : « Accès refusé » (nouveau code déployé)
```
Si le second appel réussit, l'ancien code est encore déployé : `npx supabase@2.122.0 functions deploy notchpay-mcp --project-ref zxqcnmgwhtbxkdpjqtlr`.
La réponse du premier appel montre aussi les derniers événements de webhook : un événement `payment.complete` avec `outcome = confirmed` prouve le §5.
