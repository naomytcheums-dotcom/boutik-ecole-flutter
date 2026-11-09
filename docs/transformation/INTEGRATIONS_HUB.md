# Hub d'intégrations (écrans 271, 280, P3, P5)

Les quatre écrans de la rubrique « Applications connectées » sont quatre vues d'un même hub (`lib/figma/live/integrations_*.dart`) :
271 Mes liens et réseaux (famille Réseaux + autres liens du profil), P5 Connecter mes outils (toutes les familles), P3 Avis et outils connectés
(comptes reliés), 280 Intégrations (état des connecteurs pour l'administration + accès à l'API publique et aux clés, déplacés sur `/integrations/api`).
Sous-écrans : fiche fournisseur, Mes contenus connectés, Publier sur mes réseaux, Mobile Money (tableau de bord, numéros, envoi, historique, détail et reçu).

## Architecture

| Couche | Élément |
|---|---|
| Base | migration `20261109000000_integrations_hub.sql` : `integration_providers`, `integration_connections`, `integration_accounts`, `integration_permissions`, `integration_tokens` (chiffrés, aucun droit pour l'API), `integration_oauth_states` (PKCE, 10 min), `integration_sync_logs`, `integration_imported_items` (unique par connexion + id externe), `integration_publications`, `integration_publication_targets`, `momo_numbers`, `momo_verifications`, `momo_transactions` + fonctions `momo_*`, `integrations_*`. RLS partout. |
| Edge Functions | `integrations-oauth` (catalog, start, callback, disconnect), `integrations-sync` (sync + webhooks Dropbox/Meta), `integrations-publish`, `momo` (vérification SMS, confirm_transfer, refresh_status), `momo-callback`. Code partagé : `supabase/functions/_shared` (noyau chiffré `core.ts`, `engine.ts`, un fichier par fournisseur dans `providers/`, `adapt.ts`, `mtn.ts`). |
| Application | catalogue statique `integrations_model.dart` (miroir de `integration_providers`, pour l'affichage hors connexion), données `integrations_data.dart`, interface `integrations_ui.dart`, `integrations_momo.dart`. |

Sécurité : jetons AES-256-GCM (clé `INTEGRATIONS_ENC_KEY`), jamais renvoyés à Flutter ni journalisés ; PKCE S256 sur tous les fournisseurs qui l'acceptent
(Facebook, Instagram, LinkedIn, Slack et Notion ne l’acceptent pas : secret serveur ; Trello : OAuth 1.0a signé HMAC-SHA1) ; état OAuth à usage unique ; retour limité à l'origine
de l'application ; aucun PIN Mobile Money reçu ni stocké ; envoi = `awaiting_confirmation` → confirmation explicite (`confirm: true`) → `pending` (passage atomique) → rappel.

## Déploiement des fonctions

```
npx supabase@2.122.0 functions deploy integrations-oauth integrations-sync momo-callback --no-verify-jwt --project-ref zxqcnmgwhtbxkdpjqtlr
npx supabase@2.122.0 functions deploy integrations-publish momo --project-ref zxqcnmgwhtbxkdpjqtlr
```

URI de redirection OAuth à déclarer chez chaque fournisseur : `https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/integrations-oauth/callback`
Webhooks : `…/functions/v1/integrations-sync/webhook/dropbox`, `…/webhook/facebook`, `…/webhook/instagram`. Rappel MTN : posé automatiquement par `momo` (`momo-callback?s=<secret>`).

## À fournir par le propriétaire (aucune clé n'est inventée)

Secrets Supabase (Edge Functions > Secrets). Tant qu'ils manquent, le connecteur affiche « En attente de configuration » et le bouton Connecter reste inactif.

| Obligatoire pour tout | `INTEGRATIONS_ENC_KEY` = 32 octets aléatoires en base64 (`openssl rand -base64 32`) |
|---|---|
| Facebook | application Meta, revue `pages_show_list`, `pages_read_engagement`, `pages_manage_posts` + vérification de l'entreprise ; `FACEBOOK_CLIENT_ID/SECRET`, `META_WEBHOOK_VERIFY_TOKEN` |
| Instagram | application Meta avec « API Instagram », comptes Business/Créateur, revue `instagram_business_content_publish` ; `INSTAGRAM_CLIENT_ID/SECRET` |
| LinkedIn | application avec le produit « Share on LinkedIn » (+ Sign In with LinkedIn/OpenID) ; `LINKEDIN_CLIENT_ID/SECRET`. Lecture des publications : Community Management API sur approbation (non utilisée) |
| TikTok | application Login Kit + Display API (`video.list`) ; `TIKTOK_CLIENT_ID` (client key) / `TIKTOK_CLIENT_SECRET`. Publication : audit TikTok exigé (non proposée) |
| Google (Drive, Docs, Sheets, Gmail, Agenda, YouTube) | un projet Google Cloud, écran de consentement vérifié (portées sensibles : `gmail.send`, `calendar.events`, `youtube.readonly`) ; `GOOGLE_CLIENT_ID/SECRET`. `drive.file` évite l'audit CASA ; la lecture de Gmail (restreinte) n'est pas demandée |
| OneDrive, Teams | application Microsoft Entra (comptes personnels + professionnels) ; `MICROSOFT_CLIENT_ID/SECRET` ; Teams : consentement administrateur du locataire |
| Dropbox | application Dropbox ; `DROPBOX_CLIENT_ID/SECRET` (le secret signe aussi le webhook) |
| Slack | application Slack (scopes bot `chat:write`, `chat:write.public`, `channels:read`) ; `SLACK_CLIENT_ID/SECRET` |
| Discord | application Discord ; `DISCORD_CLIENT_ID/SECRET` |
| GitHub | OAuth App GitHub ; `GITHUB_CLIENT_ID/SECRET` |
| Notion | intégration publique Notion ; `NOTION_CLIENT_ID/SECRET` |
| Trello | clé d'API + secret OAuth Trello ; `TRELLO_CLIENT_ID` (clé) / `TRELLO_CLIENT_SECRET` |
| Behance | rien : l'API est fermée aux nouvelles clés, l'utilisateur enregistre l'adresse publique de son portfolio |
| MTN MoMo | contrat marchand + produit Disbursement : `MTN_MOMO_SUBSCRIPTION_KEY`, `MTN_MOMO_API_USER`, `MTN_MOMO_API_KEY`, `MTN_MOMO_TARGET_ENV`, `MTN_MOMO_CURRENCY`, `MTN_MOMO_CALLBACK_SECRET`, (`MTN_MOMO_BASE_URL` en production) |
| Orange Money | contrat marchand Orange + documentation/identifiants d'API d'envoi : l'envoi automatisé n'est pas codé tant qu'Orange ne les fournit pas (réponse 501 honnête). La collecte reste possible via Tara Money (`tara-pay`) |
| Vérification SMS des numéros | secrets Twilio déjà utilisés par `dispatch-notifications` (`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_SMS_FROM`) |

Réglage optionnel : plafond d'un envoi Mobile Money = `platform_settings` clé `momo.transfer_max` (défaut 500 000 FCFA).
Versions d'API modifiables sans redéploiement du code : `META_GRAPH_VERSION` (défaut v24.0), `LINKEDIN_VERSION` (défaut 202510).

## Limites officielles respectées (et alternatives)

- Facebook : Pages seulement. Instagram : comptes professionnels, média obligatoire pour publier (« Lien dans la bio » pour les liens).
- LinkedIn : publication oui, lecture non (approbation). TikTok : import oui, publication non (audit). YouTube : lecture seule, quota 10 000 unités/jour.
- Gmail : envoi seul. Google Drive/Docs/Sheets : `drive.file`. Behance : lien public. Trello : OAuth 1.0a. Slack : pas de PKCE.
- Quotas : intervalle minimal entre deux synchronisations par fournisseur (`next_sync_at`), `Retry-After` / 429 respectés, synchronisation incrémentale (curseur Dropbox).

## Non vérifié

Aucune clé de développeur n'existe encore : les échanges réels avec les fournisseurs (autorisation, jetons, import, publication, transfert MTN) n'ont **pas** été exécutés de bout en bout.
Le code suit la documentation officielle de chaque API ; chaque fournisseur est à recetter une fois ses clés posées.
