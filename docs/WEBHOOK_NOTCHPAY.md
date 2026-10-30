# Webhook Notch Pay (confirmation de paiement signée)

Fonction : `supabase/functions/notchpay-webhook/index.ts` — table de rejeu : `payment_events` (`supabase/migrations/20261030_webhook_paiement.sql`).

## Ce que fait la fonction
1. Refuse tout appel dont l'en-tête `x-notch-signature` n'est pas le HMAC-SHA256 (hex) du **corps brut**, calculé avec le *Hash Key* du webhook (comparaison en temps constant). Rien n'est lu ni écrit avant cette vérification.
2. Anti-rejeu : l'empreinte SHA-256 du corps est la clé primaire de `payment_events` ; un second envoi identique répond `duplicate`.
3. Rapproche la référence avec `orders.reference` ; référence inconnue → ignorée et journalisée.
4. Pour `payment.complete` uniquement : relit la transaction chez Notch Pay (clé API) et exige statut `complete`, devise `XAF`, référence identique et montant ≥ sous-total + frais. Sinon la commande n'est pas payée (`underpaid`, `currency_mismatch`, …).
5. Transition `paid = false → true` atomique (`update … where paid = false`) : idempotente.

## Configuration (par le propriétaire du compte)
- Secrets Supabase (Edge Functions > Secrets) : `NOTCHPAY_KEY` (déjà présent) et `NOTCHPAY_HASH` (Hash Key du webhook, Notch Pay > Paramètres > Clés API).
- Réglage de la fonction `notchpay-webhook` : **désactiver « Verify JWT with legacy secret »** (Notch Pay n'envoie pas de jeton Supabase ; l'authenticité repose sur la signature).
- Notch Pay > Paramètres > Webhooks : URL `https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-webhook`, événements `payment.*`.
- Test : bouton « Test » du tableau de bord Notch Pay ; vérifier la table `payment_events` (colonne `outcome`).

## État de vérification
Implémenté et déployé. **Non vérifié de bout en bout** tant que `NOTCHPAY_HASH`, le réglage JWT et l'URL côté Notch Pay ne sont pas en place. Format exact de la charge utile à confirmer avec un événement de test réel (la documentation ne détaille pas les champs).
