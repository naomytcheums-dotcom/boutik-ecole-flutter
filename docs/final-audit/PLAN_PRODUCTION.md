# Plan de mise en production contrôlée

État au 31/10 (19 h) : migrations 1 à 13 + 31a + 31b + 31c **appliquées** (historique 16/16) ; Edge Functions `pay` v6, `notchpay-webhook` v6,
`notchpay-mcp` v3 **déployées** (commit `d695001`, §3) ; site **déployé** : commit `69753e6`, `main.dart.js` SHA-256 `0e6f976a…` (§5).

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

## 1. Régularisation de l'historique des migrations — ✅ FAITE le 31/10 à 14 h 20

13 versions enregistrées comme appliquées sans exécution (preuves : rapport d'audit §8 bis). `migration list --linked` : 13/13 local = distant.

## 1 (historique). Procédure suivie

Voir [AUDIT_REGULARISATION_MIGRATIONS_20261031.md](./AUDIT_REGULARISATION_MIGRATIONS_20261031.md) §8.
1. Renommer localement en horodatages à 14 chiffres (branche dédiée), contrôler `migration list --local`.
2. `npx supabase@2.122.0 migration repair --linked --status applied <13 versions>` — enregistre sans exécuter.
3. `npx supabase@2.122.0 migration list --linked` → 13 appliquées, 3 en attente.

Retour arrière : `migration repair --status reverted <versions>` (ne touche que la table d'historique).

## 2. Migrations 31a → 31b → 31c (autorisation requise pour chacune)

- **31a : ✅ appliquée le 31/10 (~14 h 45)**, contrôles conformes — rapport d'audit §8 ter.
- **31b : ✅ appliquée le 31/10 (~15 h 20)** par répertoire de travail limité, contrôles conformes — rapport d'audit §8 quater.
- **31c : ✅ appliquée le 31/10 (~15 h 40)** par répertoire de travail isolé, contrôles conformes (41/41 en production) — rapport d'audit §8 quinquies. **Aucune migration en attente.**
- ⚠ Avant d'ouvrir le kiosque : déployer le site (§5) — l'interface en ligne ne gère pas la réponse `'incorrect'` de `confirm_pickup` (anomalie C3).
- **Répétition locale** : une réplique réinitialisée n'a pas d'historique → avant tout `db push --db-url <local>`, aligner l'historique local sur la production (`migration repair --db-url <local> --status applied <versions de production>`), sinon la CLI rejoue tout depuis `p0`.
- Méthode « une seule migration » (utilisée pour 31b) :
  ```powershell
  $W="$env:TEMP\push_31b"; New-Item -ItemType Directory -Force "$W\supabase\migrations" | Out-Null
  Copy-Item -Recurse supabase\.temp "$W\supabase\.temp"
  Get-ChildItem supabase\migrations\*.sql | ? { $_.Name -le "20261031000100_z" } | Copy-Item -Destination "$W\supabase\migrations\"
  npx supabase@2.122.0 db push --linked --dry-run --workdir $W   # doit lister 20261031000100 seule
  ```

### Procédure générale

Procédure détaillée et requêtes de contrôle avant/après : rapport d'audit §9.
- Renommage fait (31a, 31b, 31c au format `<timestamp>_name`).
- **Attention [F]** : la session de `db push` ne contient pas le schéma `extensions` dans son `search_path` (incident du 31/10). Les appels `pgcrypto` de 31a/31b/31c sont tous dans des fonctions `set search_path = public, extensions` : non concernés, mais vérifier sur la réplique avec la CLI (`--db-url`) et non avec `psql`.
- `npx supabase@2.122.0 db push --dry-run` doit lister **exactement** les 3 fichiers en attente ; sinon arrêter.
- `npx supabase@2.122.0 db push` (ou SQL Editor fichier par fichier puis `migration repair --status applied`).
- `notify pgrst, 'reload schema';`
- Contrôle : `python tool/audit/catalog_snapshot.py linked snap_apres.json` comparé à la réplique → 0 écart.

Retour arrière : blocs « RETOUR ARRIÈRE » en fin de 31a et 31b (tables vides au moment de l'application → aucune perte) ;
pour 31c, réappliquer les définitions de fonctions de 31a/31b concernées.

## 3. Edge Functions — ✅ DÉPLOYÉES le 31/10 (~16 h 15)

| Fonction | Avant | Après | Verify JWT | Code déployé |
|---|---|---|---|---|
| `pay` | v5 (`e66217e`) | **v6** | actif (inchangé) | SHA-256 `46B9E851…3BD4` = `d695001` |
| `notchpay-webhook` | v5 (`b3160af`) | **v6** | désactivé (inchangé ; authenticité par HMAC) | SHA-256 `3D7CED0F…89B1` = `d695001` |
| `notchpay-mcp` | v2 (`814db47`, lisait `?key=`) | **v3** | actif (**inchangé**) | SHA-256 `D8917F1C…2142` = `d695001` |

Commandes exécutées (chaque fonction nommée explicitement, aucune autre fonction touchée) :
```powershell
npx supabase@2.122.0 functions deploy pay --project-ref zxqcnmgwhtbxkdpjqtlr --use-api
npx supabase@2.122.0 functions deploy notchpay-webhook --project-ref zxqcnmgwhtbxkdpjqtlr --no-verify-jwt --use-api
npx supabase@2.122.0 functions deploy notchpay-mcp --project-ref zxqcnmgwhtbxkdpjqtlr --use-api
```
**Verify JWT de `notchpay-mcp` conservé actif** : la passerelle accepte la clé publiable (constaté), un client MCP fonctionne donc avec
`apikey`/`Authorization: Bearer <clé publiable>` **et** `x-mcp-access-key: <clé MCP>`. La désactivation n'était pas nécessaire ; la validation
interne de la clé (en-tête seulement, temps constant) reste la protection des outils.

Contrôles après déploiement (production, non financiers) : **21/21** — code déployé = commit (retéléchargé) ; 401 sans jeton / sans session ;
CORS limité ; webhook 401 sans signature, signature fausse, préfixée ou HMAC deviné, 405 en GET ; MCP : `tools/call` refusé sans clé,
avec `?key=` et avec une mauvaise clé ; aucun secret dans les 19 réponses ; base inchangée (0 événement, 0 commande).

Retour arrière : code précédent sauvegardé dans `%USERPROFILE%\boutik_backups\fonctions_20261031\deploye_avant\` → redéployer avec
`--workdir <ce dossier>` et les mêmes options de Verify JWT.

## 3 (historique). Commandes prévues

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

## 5. Application web — ✅ DÉPLOYÉE le 31/10 à 18 h 42

| Élément | Valeur |
|---|---|
| Commit déployé | `69753e6` (C3 `057af8a` + C4 : succès uniquement sur « delivered », délai de 20 s, une confirmation à la fois) |
| `main.dart.js` | SHA-256 `0e6f976a1001d9d3cc6642b6e4b644bbdb2a8e82e494ea730a971537c50b7b84` — **servi = construit** (vérifié après déploiement) |
| Déploiement Vercel | `dpl_5VXXmTvNUZzvaU9ZaokJ47SqcrJu` (`boutik-ecole-m2uy9dd13-…`), alias `https://boutik-ecole.vercel.app`, état READY |
| Retour arrière | déploiement précédent `boutik-ecole-rmhifulr0-naomytcheums-dotcoms-projects.vercel.app` (`061029c2…`) : `npx vercel rollback boutik-ecole-rmhifulr0-naomytcheums-dotcoms-projects.vercel.app` ou « Promote » dans le tableau Vercel |

Audit du bundle avant déploiement : URL Supabase de production, clé **publiable** de production uniquement, 0 adresse locale, clé locale absente,
aucun secret (les 2 occurrences de `sb_secret_` sont le libellé du contrôle de format de clé de `supabase_flutter`, présentes aussi dans la version
précédente) ; `vercel.json` : installation et construction désactivées (`echo skip`), dossier statique seul → **aucune migration ni écriture en base**.

Commandes exécutées :
```powershell
flutter build web --release                  # sans --dart-define : valeurs de production
cd build\web; npx vercel deploy --prod --yes # dossier lié au projet (.vercel conservé)
```
Vérifications en ligne : `visiteur` 12/12 ; `retrait_en_ligne` 1/1 (écran de retrait du site déployé, tout le trafic Supabase intercepté, 0 requête
vers la base) ; `connexion_en_ligne` 1/1 (refus réel d'identifiants inexistants, aucune session) ; compteurs de production identiques avant/après
(comptes, sessions, jetons, journaux, profils, annonces, commandes, paiements).

### Procédure (référence)

```powershell
flutter build web --release        # sans --dart-define : pointe la production
# contrôle : aucune adresse 127.0.0.1 dans build/web/main.dart.js
vercel deploy --prod build/web     # depuis le dossier lié au projet Vercel
```

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
| Verify JWT | `pay` : oui ; `notchpay-webhook` : non ; `notchpay-mcp` : oui (conservé au redéploiement du 31/10) | §3 |
