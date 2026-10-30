# Notch Pay : diagnostic et tests (sans secrets)

## Architecture
- `pay` (Edge Function, JWT requis) : démarre le paiement Mobile Money (MTN/Orange), interroge le statut, contrôle téléphone, référence, montant, devise.
- `notchpay-webhook` (JWT désactivé, signature obligatoire) : HMAC-SHA256 du corps brut comparé en temps constant ; anti-rejeu (`payment_events`) ; rapprochement par référence ; relecture auprès du fournisseur avant de passer `paid=true`.

## Tests
- **Sandbox réel (30/10)** : MTN `+237670000000` → `complete` ; `…0004` → `failed` ; commande d'autrui → 404 ; commande déjà payée → 409 ; mise à jour directe de `paid`/`reference` → 0 ligne.
- **Webhook, simulé localement** : 19/19 (sans signature, fausse signature, rejeu, sous-paiement, devise, référence, fournisseur injoignable puis retentative…). `python supabase/tests/webhook_e2e.py`.
- **Webhook, réel** : une requête reçue du fournisseur le 30/10 à 07:14 a été rejetée (« signature invalide »). **Cause non établie.** Hypothèses : secret `NOTCHPAY_HASH` différent du Hash Key de l'endpoint (test/production), ou format de signature différent de la documentation. Un diagnostic sans valeur sensible est déployé (noms d'en-têtes, longueurs, indicateurs). **Aucun webhook authentique n'a été accepté.**
- Vérifié en production : POST sans signature → 401 ; fausse signature → 401 ; GET → 405.

## État
BLOQUÉ — CAUSE À IDENTIFIER : il faut un événement réel envoyé par Notch Pay après le déploiement du diagnostic (bouton de test du tableau de bord), puis lecture des journaux.
Les références `trx.test_…` montrent que la clé API est celle du sandbox ; le passage en production (clé et Hash Key de production) est une action du propriétaire. Aucune transaction réelle n'a été lancée. Le Hash Key a été exposé dans une conversation : à renouveler chez Notch Pay puis à remplacer dans les secrets Supabase.
