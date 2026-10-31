# Plan de mise en production contrôlée

État au 31/10 : **rien de ce lot n'est déployé.** Production servie = build `061029c2…` (commit `0c18c17`),
migrations 1 à 13 en place, 31a/31b/31c absentes, Edge Functions `pay` et `notchpay-webhook` = version du dépôt avant correctifs,
`notchpay-mcp` = commit `814db47`.

Chaque étape ci-dessous **requiert l'autorisation explicite du propriétaire**. Les étapes sont indépendantes
sauf mention contraire ; l'ordre recommandé minimise le risque.

## 0. Préalables (sans risque)

```powershell
git fetch; git checkout feat/figma-fidele; git pull
$env:Path="C:\Users\NITROV15\dev\flutter\bin;C:\Program Files\Git\cmd;C:\nvm4w\nodejs;C:\Program Files\Docker\Docker\resources\bin;"+$env:Path
cd $env:USERPROFILE\boutik_local; npx supabase start -x studio,imgproxy,vector,logflare,supavisor,edge-runtime,mailpit; cd -
python tool/audit/build_prod_replica.py --with-pending      # dump frais de production → réplique → 31a, 31b, 31c ; attendu « 0 écart »
python supabase/tests/run_all_local.py                     # attendu 386/386
flutter test                                               # attendu 403/403
```

Sauvegarde de la production avant toute écriture :
```powershell
npx supabase@2.122.0 db dump --linked -f backup\prod_schema_<date>.sql
npx supabase@2.122.0 db dump --linked --data-only -f backup\prod_data_<date>.sql
```
(et/ou point de restauration PITR dans le tableau de bord si le plan le permet).

## 1. Régularisation de l'historique des migrations (autorisation requise)

Voir [AUDIT_REGULARISATION_MIGRATIONS_20261031.md](./AUDIT_REGULARISATION_MIGRATIONS_20261031.md) §8.
1. Renommer localement en horodatages à 14 chiffres (branche dédiée), contrôler `migration list --local`.
2. `npx supabase@2.122.0 migration repair --linked --status applied <13 versions>` — enregistre sans exécuter.
3. `npx supabase@2.122.0 migration list --linked` → 13 appliquées, 3 en attente.

Retour arrière : `migration repair --status reverted <versions>` (ne touche que la table d'historique).

## 2. Migrations 31a → 31b → 31c (autorisation requise)

Procédure détaillée et requêtes de contrôle avant/après : rapport d'audit §9.
- `npx supabase@2.122.0 db push --dry-run` doit lister **exactement** les 3 fichiers en attente ; sinon arrêter.
- `npx supabase@2.122.0 db push` (ou SQL Editor fichier par fichier puis `migration repair --status applied`).
- `notify pgrst, 'reload schema';`
- Contrôle : `python tool/audit/catalog_snapshot.py linked snap_apres.json` comparé à la réplique → 0 écart.

Retour arrière : blocs « RETOUR ARRIÈRE » en fin de 31a et 31b (tables vides au moment de l'application → aucune perte) ;
pour 31c, réappliquer les définitions de fonctions de 31a/31b concernées.

## 3. Edge Functions (autorisation requise)

```powershell
npx supabase@2.122.0 functions deploy pay --project-ref zxqcnmgwhtbxkdpjqtlr
npx supabase@2.122.0 functions deploy notchpay-webhook --project-ref zxqcnmgwhtbxkdpjqtlr --no-verify-jwt
npx supabase@2.122.0 functions deploy notchpay-mcp --project-ref zxqcnmgwhtbxkdpjqtlr --no-verify-jwt
```
Contrôles :
- `pay` : `PAY_FN=https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/pay python supabase/tests/pay_e2e.py` — **uniquement** si le test est adapté à des comptes `zz-test` de production ; sinon appel unitaire sur une commande annulée → **409** `order_cancelled` attendu.
- `notchpay-webhook` : POST sans signature → 401 ; GET → 405.
- `notchpay-mcp` : `python supabase/tests/mcp_e2e.py` → 27/27 ; `?key=` doit être refusé (401).

Retour arrière : `npx supabase functions download <nom>` **avant** déploiement (copie de la version courante), puis redéployer cette copie.

## 4. Secrets Notch Pay (propriétaire uniquement)

Renouveler `NOTCHPAY_KEY` (sandbox) et `NOTCHPAY_HASH` dans le tableau Notch Pay, puis
`npx supabase@2.122.0 secrets set NOTCHPAY_KEY=… NOTCHPAY_HASH=…` (ne jamais committer ni journaliser les valeurs).
Ensuite : un paiement **sandbox** depuis l'application → vérifier une ligne `payment_events` et la commande `paid = true`.

## 5. Application web (autorisation requise)

```powershell
flutter build web --release        # sans --dart-define : pointe la production
# contrôle : aucune adresse 127.0.0.1 dans build/web/main.dart.js
vercel deploy --prod build/web     # depuis le dossier lié au projet Vercel
```
Contrôles : SHA-256 de `main.dart.js` servi = build local ; `BASE_URL=https://boutik-ecole.vercel.app npx playwright test production` (27 attendus, à étendre aux actions 31a/31b une fois appliquées).

Retour arrière : `vercel rollback` vers le déploiement `061029c2…` (ou « Promote » de l'ancien déploiement dans le tableau Vercel).

## 6. Nettoyage (autorisation requise — suppression de données)

`supabase/maintenance/cleanup_test_accounts.sql` : 44 comptes `zz-test` en production. Exécuter d'abord la partie `select` de contrôle.

## 7. Variables d'environnement et configuration

| Élément | État constaté | Action |
|---|---|---|
| `BE_URL` / `BE_KEY` (clé publiable) | intégrés au build par défaut | aucune |
| `NOTCHPAY_KEY`, `NOTCHPAY_HASH` | présents (30/10) | renouveler (§4) |
| `MCP_ACCESS_KEY` | présent (30/10 08:09) | aucune |
| `NOTCHPAY_API` (nouveau, facultatif) | absent | laisser absent en production (sert aux tests locaux) |
| MFA TOTP | 2 facteurs enrôlés en production | aucune |
| Verify JWT | `pay` : oui ; `notchpay-webhook` : non ; `notchpay-mcp` : oui → **non** au redéploiement | §3 |
