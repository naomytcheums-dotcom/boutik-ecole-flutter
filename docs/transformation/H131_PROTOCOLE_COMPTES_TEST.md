# H13.1 — Protocole des comptes de test et de la validation connectée (écriture)

Complète `H13_PROTOCOLE_VALIDATION_CONNECTEE.md` et `H7_SCENARIOS_VALIDATION_CONNECTEE.md`. Objectif : pouvoir jouer, sur un **projet Supabase de test jetable**, les parcours des cinq acteurs (Visiteur/Client, Étudiant-vendeur, Organisation, Responsable de département, Administrateur) **sans jamais écrire dans la production**.

## 1. Ce qui est demandé aux propriétaires (et rien de plus)
1. **Un projet Supabase de test jetable**, distinct de la production (référence `zxqcnmgwhtbxkdpjqtlr`). Il suffit d'un projet gratuit vide ; il est supprimé après la validation.
2. **Ses clés**, transmises par variables d'environnement (jamais dans un fichier du dépôt) : l'URL du projet, la clé publique (`anon`) et la clé de service (`service_role`) **de ce projet de test seulement**.
3. Les mêmes migrations que la production appliquées sur ce projet (`supabase db push` sur le projet de test).

Pas de numéro de téléphone réel, pas de compte personnel, pas de clé de paiement, pas de clé Notch Pay, aucun accès à la production. Les paiements ne sont jamais joués : seul le paiement à la **livraison** (confirmé par l'acheteur, aucun argent encaissé) l'est.

## 2. Gardes (appliquées avant tout appel réseau)
Communes à `create_test_accounts.mjs` et à `validate_actors.mjs` (mode écriture), implémentées dans `tool/connected/guards.mjs` :
| Garde | Effet |
|---|---|
| `SUPABASE_URL` contient la référence de production `zxqcnmgwhtbxkdpjqtlr` (casse quelconque, chemin, paramètre) | **REFUS** (code de sortie 2) |
| `ALLOW_TEST_PROJECT` non défini ou vide | **REFUS** |
| Hôte différent de `<ref>.supabase.co` ou `localhost` / `127.0.0.1` ; `http` distant ; identifiant dans l'URL | **REFUS** |
| Une clé fournie (jeton JWT) dont le contenu référence la production | **REFUS** |
`--dry-run` applique les mêmes gardes et n'effectue aucun appel réseau. Testées par `node --test tool/connected/guards.test.mjs` (12 tests : production, ALLOW absent, hôtes interdits, clés de production, dry-run sans réseau, création contre un serveur factice et idempotence, `validate_actors` en écriture refusé sur la production).

## 3. Créer les cinq comptes de test
```
$env:SUPABASE_URL='https://<ref-de-test>.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY='<clé service du projet de TEST>'
$env:ALLOW_TEST_PROJECT='1'
$env:TEST_PASSWORD='<mot de passe choisi, 12 caractères au moins, une lettre et un chiffre>'
node tool/connected/create_test_accounts.mjs --dry-run     # aperçu sans réseau
node tool/connected/create_test_accounts.mjs
```
Crée (ou retrouve, de façon idempotente ; le mot de passe est réaligné) :
| Acteur | E-mail | Rôle serveur | Affiliations créées |
|---|---|---|---|
| Client | `client-h131@test.invalid` | `client` | — |
| Étudiant-vendeur | `etudiant-h131@test.invalid` | `student` | établissement et département de test A, filière de test, rattachement **vérifié**, carte d'étudiant **vérifiée**, compte **certifié**, numéro fictif `600000131` (téléphone « vérifié » : la vente l'exige) |
| Organisation | `organisation-h131@test.invalid` | `company` | fiche « Organisation de TEST H131 » **vérifiée** |
| Responsable de département | `departement-h131@test.invalid` | `dept` | compte de département rattaché au département de test A (le département B sert aux refus croisés) |
| Administrateur | `admin-h131@test.invalid` | `admin` | — |
Tous les profils sont marqués `is_test = true` (visibles dans l'écran « Comptes de test » de l'administrateur). Le mot de passe n'est ni écrit ni affiché. L'outil est compatible avec la fonction Edge `admin-test-accounts` (e-mails `@boutik-ecole.test`, un compte par rôle) : les deux mécanismes coexistent.

## 4. Valider
Lecture seule (production comprise, sans compte : 11 contrôles du Visiteur) — inchangé :
```
$env:SUPABASE_URL='https://<ref>.supabase.co'; $env:SUPABASE_ANON_KEY='<clé publique>'
$env:TEST_CLIENT='client-h131@test.invalid:<TEST_PASSWORD>'; $env:TEST_STUDENT='etudiant-h131@test.invalid:...'; $env:TEST_ORG='organisation-h131@test.invalid:...'
$env:TEST_DEPT='departement-h131@test.invalid:...'; $env:TEST_ADMIN='admin-h131@test.invalid:...'
node tool/connected/validate_actors.mjs
```
Écriture (projet de TEST uniquement) : ajouter `WRITE_TESTS=1` et `ALLOW_TEST_PROJECT=1`. Scénarios joués (tous préfixés `H131-<horodatage>`) :
- **Client** : modifie sa bio ; refus de s'attribuer le rôle administrateur / la certification ; préférences et notifications ; publie un besoin.
- **Chaîne Étudiant → Administrateur → Client** : capacité de vente, boutique (création, soumission, refus au client, validation par l'administrateur), annonce (refus de l'auto-validation, validation par l'administrateur), commande à la livraison (double envoi idempotent), confirmation par l'acheteur, réception par le vendeur, passage d'état (refusé à l'acheteur), suivi ; refus au responsable de département de lire la commande.
- **Organisation** : vivier (refusé à un client), publication d'un besoin. **Département** : production et événement (refusés à un étudiant), vue d'ensemble. **Administrateur** : liste des utilisateurs, commandes, journal d'audit (refusés à un client).
Un acteur dont le compte manque est affiché **NON TESTE**, jamais OK. Un refus n'est compté que pour une réponse 400/401/403 : un 404 (fonction ou signature inconnue) est un échec, jamais un refus.

## 5. Ce qui a été exécuté sans projet de test
Aucun compte de test n'existe. Les scénarios d'écriture ont été exécutés **contre une simulation locale** : `supabase/tests/marketplace_pglite/h131_validate_ecriture.mjs` lance le vrai `validate_actors.mjs` (WRITE_TESTS=1) sur un mini-PostgREST HTTP local branché sur la base rejouée (schéma + migrations, RLS, rôles, jwt claims par compte, garde `db_pre_request`), avec les comptes créés par le vrai `create_test_accounts.mjs` ; `h131_outils_comptes_test.mjs` vérifie les données de l'outil contre le schéma (triggers compris) et son idempotence. Ces exécutions prouvent les noms de fonctions, les paramètres et les droits ; elles **ne remplacent pas** une exécution sur un vrai projet Supabase (Auth réel, PostgREST réel, e-mails, stockage, Edge Functions).

## 6. Hors périmètre (impossible sans éléments externes)
SMS/OTP réels, e-mails réels, TOTP réel, paiements (même sandbox), notifications push sur appareil, enregistrement LiveKit/S3, fournisseurs d'évaluation, exécution sur appareil Android, iOS.
