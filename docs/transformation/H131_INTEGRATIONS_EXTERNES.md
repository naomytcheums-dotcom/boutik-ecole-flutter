# H13.1 — Lot K : état réel des intégrations externes

Règle appliquée : une intégration n'est « opérationnelle » que si un appel réel a abouti. Un secret présent n'est pas une preuve de fonctionnement ; une réponse `not_configured`, 401 ou 503 n'est jamais « opérationnelle ». Les tests de contrat ci-dessous utilisent un faux serveur local, **pas** le vrai fournisseur.

Source des secrets présents : `supabase secrets list` (noms seulement ; aucune valeur lue ni affichée), projet de production, le 27/11/2026.

| Intégration | Code | Secrets requis | Secrets présents en production | Test de contrat (faux serveur) | Statut honnête |
|---|---|---|---|---|---|
| Évaluation de compétences (`assessment-dispatch`) | Oui, adaptateurs génériques + rappel signé HMAC | `ASSESSMENT_<CODE>_BASE_URL`, `_API_KEY`, `_WEBHOOK_SECRET` par fournisseur actif | **Aucun** | Oui (`logic.test.mjs`) | **En attente d'une configuration externe.** Sans fournisseur : `503 not_configured`, rien d'envoyé, aucun résultat simulé. Aucun fournisseur n'est actif ni contractualisé. |
| Enregistrement des lives (`live-record`, `live-egress-webhook`) | Oui | `LIVEKIT_URL/API_KEY/API_SECRET` + `LIVEKIT_EGRESS_S3_ENDPOINT/ACCESS_KEY/SECRET` (bucket `live-replays` par défaut) | LiveKit : oui. **S3 Egress : non** | Oui | **En attente d'une configuration externe** (Egress LiveKit + clés S3 de stockage). Aucun replay n'est créé tant que non configuré (503). |
| Salles live (`live-token`, `live-moderate`) | Oui | `LIVEKIT_URL/API_KEY/API_SECRET` | Oui | Oui | Secrets présents, logique testée. **Connexion réelle à une salle depuis un appareil non validée dans cette mission** : à classer « terminé mais non validé en conditions réelles ». |
| Notifications push Android (FCM) | Oui | `FIREBASE_SERVICE_ACCOUNT_JSON` | Oui | Partiel | Secret présent. **Réception sur un appareil réel non validée** dans cette mission. |
| Notifications push Web (VAPID) | Oui (`push-config`) | `VAPID_PUBLIC_KEY`, clé privée, `VAPID_SUBJECT` | Sujet présent ; noms de clés à contrôler par le propriétaire | Non | Non validé. |
| Notifications push iOS (APNs) | — | Clé APNs, macOS/Xcode | Non | — | **Hors périmètre** (iOS exclu), non configuré. |
| E-mail (Resend) | Oui | `RESEND_API_KEY`, `RESEND_FROM` | Oui | Non | Secrets présents ; envoi réel non rejoué ici. |
| SMS / WhatsApp (Twilio) | Oui (`momo`, `integrations-oauth`) | `TWILIO_*` | Oui | Non | Secrets présents ; envoi réel non rejoué ici (coût réel). |
| Paiement Notch Pay (`pay`, `notchpay-webhook`) | Oui | `NOTCHPAY_KEY`, `NOTCHPAY_HASH` (+ `NOTCHPAY_API` facultatif) | Oui | Oui | Je ne lis ni ne modifie ces clés. **Aucun paiement réel n'est effectué** par ces travaux. Un test bac à sable avec de vraies clés de test reste à faire par le propriétaire. |
| Paiement Tara (`tara-pay`, `tara-webhook`) | Oui | `TARA_API_KEY`, `TARA_BUSINESS_ID`, `TARA_WEBHOOK_SECRET`, `TARA_API_URL` | Les trois premiers ; `TARA_API_URL` absent (valeur par défaut éventuelle dans le code à confirmer) | Oui | Non validé en réel. |
| Paiement MTN MoMo (`momo`, `momo-callback`) | Oui | `MTN_MOMO_CALLBACK_SECRET` | **Non** | Oui | En attente d'une configuration externe. |
| Traduction automatique (`translate`) | Oui | `TRANSLATE_API_URL`, `TRANSLATE_API_KEY`, `TRANSLATE_PROVIDER_CODE` + fournisseur actif dans `ai_providers` | **Aucun** | Oui | **En attente d'une configuration externe** : sans fournisseur, `not_configured`. Seule l'interface anglaise (fichier `en.json`) est réellement fournie. |
| Kéla IA (`kela-chat`) | Oui | `ANTHROPIC_API_KEY` | **Non** | — | **Hors périmètre H13.1 par décision du propriétaire** ; reste non configuré. |
| Intégrations tierces (Dropbox, Meta, LinkedIn, Trello) | Oui | clés OAuth par fournisseur | Non | Partiel | Non configurées. |

## Constats importants

1. Aucune clé n'a été inventée, ajoutée ni modifiée. Les fonctions restent en `not_configured` tant que le propriétaire ne fournit pas les identifiants.
2. Ce qui bloque un fournisseur d'évaluation n'est pas du code : c'est le **choix et le contrat** d'un fournisseur (voir `H13_CONTRAT_FOURNISSEUR_EVALUATION.md`), ses clés et l'URL de rappel à lui communiquer.
3. Pour les replays : créer les clés S3 de Supabase Storage, un compte LiveKit avec Egress, puis renseigner les 3 variables `LIVEKIT_EGRESS_S3_*`. Un enregistrement réel de bout en bout est ensuite à faire.
4. Tests réels à faire par le propriétaire avec ses comptes : un push Android sur appareil, une connexion à une salle live, un paiement bac à sable, un e-mail et un SMS de test.
