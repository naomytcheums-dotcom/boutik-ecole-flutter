# Serveur MCP Notch Pay (lecture seule)

Fonction : `supabase/functions/notchpay-mcp/index.ts` — transport Streamable HTTP, JSON-RPC 2.0, sans état.

## URL pour Claude Connecteurs
```
https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-mcp/mcp?key=<MCP_ACCESS_KEY>
```
`<MCP_ACCESS_KEY>` est une chaîne aléatoire que **le propriétaire** choisit (au moins 32 caractères) ; elle est aussi enregistrée comme secret Supabase du même nom. Cette URL contient un secret : ne la publie pas.

## Étapes à faire par le propriétaire (non réalisables par l'assistant : sécurité)
1. Supabase > Edge Functions > `notchpay-mcp` > Settings : désactiver « Verify JWT with legacy secret », puis Save changes (sans cela, Claude ne peut pas appeler l'URL).
2. Supabase > Edge Functions > Secrets : ajouter `MCP_ACCESS_KEY` = la chaîne aléatoire choisie.
3. Claude > Connecteurs > Ajouter un connecteur personnalisé : coller l'URL ci-dessus avec la clé.

## Outils (tous en lecture seule)
`notchpay_list_payments`, `notchpay_get_payment`, `boutik_recent_webhook_events`, `boutik_order_payment_status`. Aucun outil ne crée de paiement, de transfert ni de remboursement. Téléphones et e-mails sont masqués. `initialize` et `tools/list` sont publics ; `tools/call` exige la clé d'accès (sinon : « outils non activés » ou « accès refusé »).
La clé API utilisée est `NOTCHPAY_KEY` : actuellement celle du **sandbox**.

## Vérifications
- Test de conformité local (vraie fonction dans Deno, Notch Pay et base simulés) : **26/26** — `python supabase/tests/mcp_e2e.py` (protocole, erreurs JSON-RPC, lot, clé d'accès, masquage, validation, lecture seule).
- Fonction **déployée** : client officiel `@modelcontextprotocol/inspector` (CLI, transport HTTP) : `tools/list` renvoie les 4 outils ; `tools/call` sans clé renvoie `isError` (« outils non activés »). Ce test passe en envoyant la clé publique Supabase, car la vérification JWT est encore active.
- **Non vérifié** : l'appel sans aucun en-tête (celui que fera Claude) tant que l'étape 1 n'est pas faite : il renvoie actuellement `401 Missing authorization header`.
