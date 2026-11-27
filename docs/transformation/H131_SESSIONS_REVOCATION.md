# H13.1 · Lot SESSIONS : révocation effective des sessions

Migration : `20261129020000_h131_sessions_garde.sql` (strictement additive). Tests : `supabase/tests/marketplace_pglite/h131_sessions.mjs` (80 contrôles), `supabase/functions/_shared/session.test.mjs` (9), `test/journey/h131_sessions_test.dart` (8).

## 1. Ce que fait (et ne fait pas) le mécanisme

Un jeton d'accès Supabase est un JWT signé : PostgREST et Storage le vérifient **localement** (signature + `exp`), sans interroger GoTrue. Supprimer les lignes de `auth.sessions` (ce que faisait H13 à la suspension) ne « révoque » donc **pas** le jeton déjà émis : il reste cryptographiquement valide jusqu'à son expiration (1 h par défaut). Le correctif H13.1 **ne prétend pas révoquer le jeton** : la base refuse les requêtes qu'il porte.

Le JWT contient `sub` (compte) et `session_id` (ligne de `auth.sessions`). PostgREST exécute `pgrst.db_pre_request` (`public.enforce_mfa_on_sensitive`) avant **chaque** requête, avec `request.jwt.claims` renseigné. H13.1 y insère, en tête, l'appel à `_session_guard()` (insertion dans le corps existant plutôt que remplacement : les migrations h4/k1/l3/h10 réécrivent la liste des opérations 2FA de cette fonction et doivent pouvoir continuer à le faire ; l'insertion est idempotente et vérifiée après rejeu de k1 et h10).

| Cas | Résultat |
|---|---|
| Requête anonyme (pas de `sub`) ou `role = service_role` | jamais refusée |
| Jeton authentifié dont le `session_id` n'existe plus dans `auth.sessions` (ou dont `not_after` est dépassé, ou session d'un autre compte) | **HTTP 401**, SQLSTATE `PT401`, message « Session expirée ou révoquée, reconnectez-vous », indice `session_revoked` |
| Compte suspendu (`profiles.suspended`) ou bloqué (`auth.users.banned_until` futur), session encore présente | **HTTP 403** (`42501`), « Compte suspendu : cette action est impossible. Contactez le support. », indice `account_suspended`, lectures **et** écritures |
| Compte suspendu : RPC de contact et droits des personnes (`support_ticket_create`, `request_account_deletion`, `cancel_account_deletion`, `accept_terms`, `unregister_device`, `unregister_all_devices`, `log_audit`) | passent la garde (un compte suspendu garde le droit de contacter le support et de demander la suppression) ; une session **fermée** reste refusée même pour elles |
| Jeton sans `session_id` (ancien format) | session non contrôlée, mais suspension/blocage contrôlés |
| Erreur interne du contrôle | la requête passe (la garde ne doit jamais rendre l'API indisponible) |

Coût : trois lectures par clé primaire (`auth.sessions.id`, `profiles.id`, `auth.users.id`) par requête, une seule fois (pré-requête). Mesure PGlite en mémoire : ≈ 0,01 ms par contrôle (ordre de grandeur, non représentatif d'un Postgres réseau ; à mesurer sur le projet réel).

### Fonctions créées
- `_session_status_of(compte, session)` : `ok | session_revoked | suspended` ; **service_role uniquement** (fonctions Edge).
- `_session_status()` / `_session_is_live()` : même contrôle sur les revendications de la requête en cours ; `stable`, `security definer`, exécutables par `anon`, `authenticated`, `service_role` (politiques RLS).
- `_session_guard()` : lève les erreurs ci-dessus ; appelée par `enforce_mfa_on_sensitive`.
- `_session_revoke_tokens(compte)` (interne) : `auth.refresh_tokens.revoked = true`.
- Réécriture de `_profile_suspension_sessions()` (suspension : ban + refresh tokens révoqués + sessions supprimées ; réactivation : ban levé, **les anciens jetons restent refusés**, il faut une nouvelle session) et de `admin_account_sessions_revoke()` (mêmes révocations, journalisée).

## 2. Ce qui est effectivement bloqué

| Surface | Bloqué ? | Détail |
|---|---|---|
| PostgREST (tables, vues, RPC) | **Oui** | garde `db_pre_request` sur chaque requête ; testé en lecture et écriture (`h131_sessions.mjs`) |
| Refresh du jeton | **Oui (GoTrue)** | le ban (`banned_until`) et la suppression des sessions/refresh tokens empêchent d'obtenir un nouvel access token : la fenêtre résiduelle est au plus la durée restante du jeton |
| Nouvelle connexion d'un compte suspendu | **Oui (GoTrue)** | ban |
| Fonctions Edge appelées par un utilisateur | **Oui** | voir §3 : identité par `auth.getUser()` puis `_session_status_of` (401 `session_revoked` / 403 `account_suspended` / 503 si la vérification est indisponible : refus, jamais acceptation) |
| Storage | **Seulement si la politique appelle `_session_is_live()`** | Storage n'exécute pas `db_pre_request` : il pose `request.jwt.claims` puis évalue les politiques RLS de `storage.objects`. Ajouter `and (select _session_is_live())` aux politiques des compartiments **privés** (coordination lot MEDIA : leurs migrations ne sont pas modifiées ici). Exemple testé (`h131_sessions.mjs` §H) : lecture vide et écriture refusée avec une session supprimée, autre compte intact. Les compartiments **publics** (lecture par URL) ne sont pas concernés |
| Realtime (websocket) | **Non (fenêtre résiduelle)** | voir §4 |
| Fonctions Edge sans appelant authentifié (webhooks, `push-config`, etc.) | sans objet | pas de session utilisateur |

## 3. Inventaire des fonctions Edge (`supabase/functions`)

Toutes les fonctions qui agissent au nom d'un utilisateur passent déjà par `auth.getUser()` (GoTrue) : aucune ne se contentait de décoder le JWT. Mais `getUser` n'interroge pas l'état du compte, et GoTrue ne couvre pas tous les cas (ban sans suppression de session, session fermée entre deux vérifications selon la version). H13.1 ajoute le contrôle serveur de la base (`_shared/session.ts`, `verifyCaller`).

| Fonction | Avant | Après |
|---|---|---|
| `integrations-sync`, `integrations-publish`, `integrations-oauth` (hors `/callback`), `auth-recovery` (actions `phone_verify_*`), `admin-test-accounts`, `live-token`, `live-record`, `live-moderate`, `momo` | `callerOf` → `auth.getUser` | `callerOf` → `callerResult` (getUser + `_session_status_of`) ; réponse 401 `session_revoked` / 403 `account_suspended` via `jsonResponse` |
| `pay`, `tara-pay`, `kela-chat` (contrôle d'accès uniquement ; activation de Kela inchangée), `translate` | `auth.getUser` propre | `callerResult` partagé |
| `assessment-dispatch`, `dispatch-notifications`, `notchpay-webhook`, `notchpay-mcp`, `tara-webhook`, `momo-callback`, `live-egress-webhook` | clé de service / secret de webhook / signature | inchangé (aucun jeton utilisateur) |
| `push-config` | publique (clé VAPID publique) | inchangé |

Si `_session_status_of` n'existe pas (migration non appliquée), les fonctions répondent 503 `session_check_unavailable` : **appliquer la migration avant de déployer les fonctions**. Non vérifié contre un vrai GoTrue (aucun accès à la production) : le comportement `getUser` d'une session supprimée (GoTrue renvoie `session_not_found`) est documenté par GoTrue mais le contrôle de la base ne s'y fie pas.

## 4. Realtime : fenêtre résiduelle

Le client Realtime vérifie le jeton à la connexion et à chaque `access_token` poussé, et coupe à l'expiration. Une connexion websocket **déjà ouverte** d'un compte suspendu reste donc ouverte au plus jusqu'à l'expiration du jeton (≤ 1 h). Pendant ce temps :
- les changements Postgres (`postgres_changes`) sont filtrés par les politiques RLS du compte : un compte suspendu perd `current_role_name()` (rôles privilégiés), mais continue de voir **ses propres** lignes (messages, notifications) et les données déjà publiques ;
- les canaux privés (`study_rooms`, Realtime Authorization) sont autorisés à l'adhésion : un compte déjà membre reste connecté.
Usage dans l'application : `lives.dart` (`live-<id>`) et `study_rooms.dart` (canal privé). À la déconnexion locale, `supabase_flutter` ré-authentifie Realtime avec la clé publique (`signedOut`).
Mitigations : (1) raccourcir la durée de vie des jetons (Supabase Auth → JWT expiry, 5 à 15 min : **décision propriétaire**, impact : plus de rafraîchissements) ; (2) ajouter `(select _session_is_live())` aux politiques des tables de messagerie sensibles (les événements `postgres_changes` sont évalués par RLS à chaque diffusion) ; (3) côté application, une réponse `session_revoked` de n'importe quel appel REST déconnecte l'appareil et ferme l'écran (§5), ce qui arrête les canaux ouverts par les écrans.

## 5. Mobile et Web (Flutter)

- `lib/figma/live/session_revoked.dart` : `RevokedSessionClient` (passé à `Supabase.initialize(httpClient:)` par `Backend.init`) observe les réponses 401/403 de PostgREST, des fonctions Edge et de GoTrue ; un corps `session_revoked`, `account_suspended`, `session_not_found` ou `user_banned` déclenche `auth.signOut(scope: local)`. Les 401 ordinaires (jeton expiré `PGRST301`, `unauthorized`) et les 403 de politique RLS ne déconnectent **jamais**. Une seule déconnexion même si plusieurs requêtes échouent.
- L'événement `signedOut` sans déconnexion demandée est déjà traité par `SystemStates` : `appSessionExpired` (purge des états privés par `resetAccountScopedState`, brouillons effacés), écran 150-2 « Votre session a expiré », et le message « Session expirée ou révoquée, reconnectez-vous » (traduit en anglais dans `assets/i18n/en.json`).
- Rafraîchissement d'un compte suspendu : refusé par GoTrue (ban) ; `gotrue-dart` supprime alors la session et émet `signedOut` (même chemin).
- Stockage : une politique RLS de Storage qui refuse (403 « row-level security ») n'est pas distinguable d'un refus ordinaire côté client : la déconnexion se fait au premier appel REST/Edge suivant.
- `pubspec.yaml` : `http` devient dépendance directe (déjà présent, même version 1.6.0 dans `pubspec.lock`).

## 6. Procédure et retour arrière

Appliquer `20261129020000_h131_sessions_garde.sql`, puis déployer les fonctions Edge modifiées (`_shared`, `pay`, `tara-pay`, `kela-chat`, `translate` et celles qui utilisent `callerOf`), puis le site/l'APK. Vérifier : `select _session_status_of('<uuid compte>', '<uuid session>')` avec la clé de service ; `select prosrc like '%_session_guard%' from pg_proc where proname = 'enforce_mfa_on_sensitive'`. Retour arrière : retirer la ligne `perform public._session_guard();` du corps de `enforce_mfa_on_sensitive()` (recréer depuis `pg_get_functiondef`), recréer `_profile_suspension_sessions()` et `admin_account_sessions_revoke()` depuis `20261128070100`.

Réserves : aucun test contre le vrai PostgREST/GoTrue/Storage/Realtime (aucun accès à la production, interdit) : la garde est exercée en simulant `request.jwt.claims`, `request.path` et `request.method` puis en appelant la fonction `db_pre_request` comme le fait PostgREST ; le code HTTP 401 pour `PT401` suit la documentation PostgREST (SQLSTATE `PTnnn`).
