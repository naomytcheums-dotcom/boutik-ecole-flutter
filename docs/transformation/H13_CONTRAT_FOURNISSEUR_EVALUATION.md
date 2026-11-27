# H13 — Contrat technique d'un fournisseur d'évaluation (Edge Function `assessment-dispatch`)

Objectif : qu'un fournisseur réel puisse être **activé dès réception de ses identifiants**, sans nouveau développement si son API suit le contrat « adaptateur générique » ci-dessous
(sinon, un adaptateur dédié s'ajoute dans `ADAPTERS` de `supabase/functions/assessment-dispatch/logic.ts`, le reste est inchangé).

> **Statut : prêt, en attente d'accès.** Aucun fournisseur n'est enregistré ni activé, aucun appel réel n'a eu lieu, aucun secret n'existe dans le dépôt. Tout est testé contre un **faux fournisseur local**
> (`node --test supabase/functions/assessment-dispatch/logic.test.mjs`, 17 cas) et sur PGlite (`h12_eval_dispatch.mjs`, `h13_eval.mjs`). Un fournisseur n'est « intégré » qu'après un appel réel réussi (plan P0 à P9 de `H9_FOURNISSEURS_EVALUATION.md` §10).

## 1. Vue d'ensemble

```
Candidat ──assessment_request──▶ base (demande « envoyee », fournisseur ATTRIBUÉ par le serveur : _assessment_pick_provider)
pg_cron (5 min) ──?action=dispatch──▶ Edge Function ──assessment_dispatch_claim──▶ base (réclame ; ≤ 5 tentatives, ≥ 10 min d'écart)
Edge Function ──POST {BASE_URL}/assessments──▶ Fournisseur ──▶ {external_ref, candidate_url?}
Edge Function ──assessment_dispatch_accepted──▶ base (demande « acceptee » : le quota gratuit est consommé à ce moment seulement)
Candidat ouvre candidate_url (bouton « Commencer l'évaluation ») ; le fournisseur évalue
Fournisseur ──POST ?provider=<code> + x-signature──▶ Edge Function ──assessment_dispatch_result──▶ base (garde-fous, « terminee »)
```

La base de données ne parle jamais au fournisseur. Les RPC `assessment_dispatch_*` et `assessment_provider_health_report` sont réservées au rôle `service_role`.

## 2. Secrets (secrets de fonction Supabase, jamais dans Git, jamais dans l'application)

Pour un fournisseur de code `prov_x` (le code du registre : `a-z`, `0-9`, `_`, 2 à 40 caractères ; le nom de variable est le code en MAJUSCULES) :

| Variable | Rôle |
|---|---|
| `ASSESSMENT_PROV_X_BASE_URL` | URL de base de l'API du fournisseur (`https://…`, sans `/` final). |
| `ASSESSMENT_PROV_X_API_KEY` | Clé d'API, envoyée en `Authorization: Bearer`. |
| `ASSESSMENT_PROV_X_WEBHOOK_SECRET` | Secret partagé de signature HMAC des rappels. |
| `ASSESSMENT_PROV_X_REQUIRE_TIMESTAMP` (optionnel) | `1` : le rappel DOIT porter `x-timestamp` (voir §5). |

Un fournisseur est « **configuré** » seulement avec les **trois** premières variables : sans secret de rappel, un résultat ne pourrait pas être authentifié et l'envoi consommerait un crédit du fournisseur pour rien.
Sans configuration complète : rien n'est réclamé, rien n'est envoyé, rien n'est compté, aucun résultat n'est simulé (réponse `503 not_configured`).

Poser les secrets : `supabase secrets set ASSESSMENT_PROV_X_BASE_URL=… ASSESSMENT_PROV_X_API_KEY=… ASSESSMENT_PROV_X_WEBHOOK_SECRET=…` (valeurs fournies par le fournisseur ; ne jamais les écrire dans un fichier du dépôt).

## 3. Envoi (Edge Function → fournisseur)

`POST {BASE_URL}/assessments` — `Authorization: Bearer <API_KEY>`, `Content-Type: application/json`, délai maximal 15 s.

```json
{ "reference": "<uuid de la demande>", "family": "<code famille>", "mode": "<code mode>", "callback_url": "https://<projet>.supabase.co/functions/v1/assessment-dispatch?provider=prov_x" }
```

**Aucune donnée personnelle** (nom, e-mail, téléphone) n'est envoyée : le transfert de données personnelles reste une décision juridique du propriétaire (loi camerounaise 2024/017).

Réponse attendue (2xx) : `{ "external_ref": "<référence du fournisseur, ≤ 200 caractères>", "candidate_url": "https://… (optionnel)" }`.
`candidate_url` n'est conservé que s'il est en `https://` ; il alimente le bouton « Commencer l'évaluation » du candidat (visible tant que la demande est acceptée ou en cours).
Réponse non 2xx, sans `external_ref`, ou délai dépassé : **échec d'envoi** journalisé (`assessment_dispatch_log`), nouvelle tentative au plus tôt 10 minutes plus tard ; après **5 tentatives** la demande devient `echouee` et le quota gratuit n'est **pas** consommé.

## 4. Rappel (fournisseur → Edge Function)

`POST https://<projet>.supabase.co/functions/v1/assessment-dispatch?provider=prov_x` (fonction déployée avec `--no-verify-jwt` : l'authentification est la signature).

En-têtes : `x-signature: sha256=<hex>` (obligatoire) ; `x-timestamp: <secondes Unix>` (optionnel, §5).
Signature : **HMAC-SHA256** du **corps brut exact** (octets reçus, avant tout re-parse) avec `ASSESSMENT_PROV_X_WEBHOOK_SECRET`, en hexadécimal minuscule, préfixé `sha256=`. Comparaison en temps constant.

Corps (taille ≤ 200 000 caractères) :

```json
{
  "reference": "<uuid de la demande>", "external_ref": "<optionnel, doit égaler celui de l'envoi>",
  "status": "completed",
  "competences": [{ "name": "Usinage", "level": "intermediaire", "verifiable_remotely": true }],
  "criteria": [{ "name": "Précision", "score": 7, "max_score": 10 }],
  "evidence": [{ "kind": "Rapport du fournisseur" }],
  "details": {}, "limits": "Évaluation à distance : le geste technique n'a pas été observé.", "recommendations": []
}
```
ou `{ "reference": "<uuid>", "status": "failed", "detail": "abandon du candidat" }` (la demande devient `echouee`, quota non consommé).

Règles de validation (rien n'est complété ni deviné) : `competences` 1 à 50 éléments ; `criteria` ≤ 200 ; `evidence` ≤ 200 ; `recommendations` ≤ 50 ; `details` objet ; **`limits` non vide (≤ 2000)**.
Garde-fous de la base (`_assessment_result_guard`, 20261125095000) : critères en liste blanche, **aucun champ de biais** (accent, apparence, âge, sexe…), validation humaine imposée pour toute compétence `verifiable_remotely: false`. Un résultat refusé est journalisé (`result_rejected`) et le rappel reçoit `422`.
Idempotence : un résultat déjà enregistré n'est jamais remplacé (`200 {"duplicate": true}`) ; le même rappel rejoué est donc inoffensif.

| Réponse | Sens |
|---|---|
| `200 {"ok":true}` | résultat enregistré (ou échec pris en compte) |
| `400` `bad_json`, `bad_reference`, `bad_status`, `bad_competences`, `bad_criteria`, `bad_shape`, `missing_limits` | corps invalide |
| `401` `bad_signature`, `stale_timestamp`, `timestamp_required` | signature ou horodatage refusé |
| `409` `provider_not_active`, `not_running` | fournisseur non actif / demande non démarrée |
| `413` `too_large` · `422` `result_rejected`/`rejected` | trop gros / refusé par les garde-fous |
| `503` `not_configured` | secrets absents |

## 5. Horodatage anti-rejeu (optionnel)

Si le fournisseur envoie l'en-tête `x-timestamp` (secondes Unix, ou millisecondes), il doit être à **±5 minutes** de l'heure du serveur, et la signature couvre alors la chaîne `"<x-timestamp>.<corps brut>"`
(`x-signature: sha256=HMAC(secret, timestamp + "." + corps)`), sans quoi l'horodatage ne protégerait de rien (un message capturé ne peut pas être rejoué avec un horodatage neuf).
Sans `x-timestamp` : contrat historique (signature du corps seul). Avec `ASSESSMENT_PROV_X_REQUIRE_TIMESTAMP=1` : un rappel sans `x-timestamp` est refusé (`401 timestamp_required`).
Dans tous les cas, l'idempotence de la base protège déjà contre un rejeu de résultat.

## 6. Statuts d'une demande (vus par le candidat)

| Statut serveur | État affiché | Quota gratuit |
|---|---|---|
| `envoyee` | En attente (ou « fournisseur non configuré » si le rapport de santé le dit) | non consommé |
| `acceptee` | Acceptée · prête à commencer (bouton si lien https) | **consommé** |
| `en_cours` | En cours | consommé |
| `terminee` | Terminée (résultat, preuves, limites, contestation ; validation humaine si requise) | consommé |
| `refusee` / `echouee` | Erreur, avec le message du serveur | **non consommé** (ou rendu) |
| `paiement_requis` | Indisponible : le paiement des évaluations supplémentaires n'est pas en service (prix non décidé) | — |
| `annulee` | Annulée | — |

Quota : **1 évaluation gratuite par étudiant et par mois civil** (fuseau Douala), comptée à l'acceptation ; une évaluation supplémentaire reste **indisponible** tant que le propriétaire n'a pas décidé du prix (`platform_settings 'assessment.extra_price'` absent).

## 7. Santé : `?action=health` et rapport

`POST …/assessment-dispatch?action=health` avec la clé de service (`Authorization: Bearer <SERVICE_ROLE_KEY>`) **ou** la clé interne de la planification (`x-dispatch-key`, vérifiée par `dispatch_key_check`).
Pour chaque fournisseur du registre, la fonction vérifie la **présence** des trois secrets (**sans appeler le fournisseur**, sans consommer de crédit) et écrit le rapport par `assessment_provider_health_report` :
trois booléens (`base_url`, `api_key`, `webhook_secret`) et la date — **jamais une valeur**. Réponse : `{"ok":true,"providers":n,"active":n,"active_configured":n,"active_not_configured":n}`.

Lecture : `assessment_provider_readiness()` — pour un candidat : `{"ready": bool}` (un fournisseur ACTIF dont la configuration complète a été confirmée il y a **moins de 3 heures**) ;
pour l'équipe « intégrations » (`tech.integrations`) : en plus le détail par fournisseur (booléens, date, rapport ancien ou non, dernier test) et l'état de la file (en attente, en cours, échecs sur 24 h, dernier événement).
L'application affiche « Fournisseur non configuré » seulement si le serveur répond `ready: false` ; une lecture en échec n'affirme rien.

## 8. Planification

Migration `20261128040200_h13_eval_planification.sql` (même mécanisme que `dispatch-notifications`, `pg_cron` + `pg_net`, clé interne `internal_secrets.dispatch_key` en en-tête `x-dispatch-key`) :
`assessment-dispatch` toutes les 5 minutes **seulement s'il existe un fournisseur actif** ; `assessment-health` toutes les 15 minutes seulement s'il existe un fournisseur enregistré. Sans `pg_cron`/`pg_net`, la migration passe sans erreur (avis) : appeler alors périodiquement
```
curl -X POST "https://<projet>.supabase.co/functions/v1/assessment-dispatch?action=dispatch" -H "x-dispatch-key: <clé interne>"
curl -X POST "https://<projet>.supabase.co/functions/v1/assessment-dispatch?action=health"   -H "x-dispatch-key: <clé interne>"
```
(l'URL du projet est celle de production, comme dans `20261115000100` ; elle est à paramétrer si un environnement de préproduction est créé — risque R-T1.)

## 9. Procédure d'activation d'un fournisseur réel (à réception des identifiants)

1. Décisions du propriétaire et juridique (P0, DPA, transfert de données) — hors développement.
2. Administration → « Fournisseurs d'évaluation » → **Enregistrer un fournisseur** (code, familles, modes) : statut `candidat`.
3. Poser les trois secrets (§2) ; attendre le rapport de santé (≤ 15 min) : l'écran affiche « Configuration serveur : complète ».
4. Faire **un appel réel** (sandbox ou production) de bout en bout ; si le format du fournisseur diffère du contrat générique, ajouter un adaptateur dans `ADAPTERS` + test contre un faux serveur.
5. **Enregistrer un test d'intégration** réussi (jamais avant un appel réel) puis **Activer** (administrateur global, 2FA, journal d'audit ; le serveur refuse sans test réussi).
6. Vérifier le journal d'envoi et la file ; fournisseur suspendu ou test échoué = retiré du service immédiatement.

## 10. Hors périmètre (toujours en attente)

Aucun fournisseur choisi ; prix d'une évaluation supplémentaire (décision propriétaire) ; financement des campagnes d'organisation (une campagne reste « en attente de financement ») ; transfert de données personnelles (décision juridique) ; relecture du résultat via l'API du fournisseur (nécessaire pour un fournisseur sans signature, cf. H9 §9.5).
