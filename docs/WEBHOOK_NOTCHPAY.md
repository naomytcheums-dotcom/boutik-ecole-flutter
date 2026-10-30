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

## Tests
**Local, simulé (19/19 réussis, 30/10/2026)** — `python supabase/tests/webhook_e2e.py` : la vraie fonction tourne dans Deno ; Supabase et l'API Notch Pay sont simulés ; les événements sont signés avec un Hash Key de test. Couvre : absence de signature, signature fausse, corps altéré, `payment.complete` valide, rejeu, événement sur commande déjà payée, sous-paiement, devise incorrecte, référence du fournisseur différente, statut « pending », fournisseur injoignable puis retentative, référence inconnue, `payment.failed`/`canceled`, événement non paiement, corps non JSON, méthode GET.

**Avec le vrai fournisseur : NON FAIT.** Aucun événement réel signé par Notch Pay n'a été reçu.

## État de vérification (30/10/2026)
| Élément | État | Preuve |
|---|---|---|
| Migration `payment_events` | Appliquée | table présente, accès anonyme refusé (42501) |
| Fonction `notchpay-webhook` | Déployée (dernière version = dépôt) | tableau de bord : « Last deployed » |
| Secret `NOTCHPAY_KEY` | Présent | liste des secrets (nom + empreinte, valeur jamais lue) |
| Secret `NOTCHPAY_HASH` | **Absent** | liste des secrets |
| « Verify JWT » désactivé | **Non** (à faire par le propriétaire) | un appel sans en-tête renvoie `UNAUTHORIZED_NO_AUTH_HEADER` |
| Webhook déclaré chez Notch Pay | **Non vérifiable** (action propriétaire) | — |

Tant que ces trois derniers points ne sont pas réglés, le webhook ne confirme aucun paiement ; la confirmation passe par l'interrogation de `pay` (action `status`), qui applique les mêmes contrôles de montant, devise et référence.
