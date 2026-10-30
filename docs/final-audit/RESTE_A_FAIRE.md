# Reste à faire (tâches réellement non terminées ou bloquées — 30/10/2026, soir)

## Bloqué par une action du propriétaire
1. **Serveur MCP** : « Verify JWT » est encore ACTIVÉ sur la fonction `notchpay-mcp` (vérifié le 30/10) ; désactiver « Verify JWT » sur `notchpay-mcp` et ajouter le secret `MCP_ACCESS_KEY` (étapes dans `MCP_NOTCHPAY.md`).
2. **Webhook Notch Pay** : envoyer un événement de test depuis Notch Pay pour lire le diagnostic de signature ; renouveler le Hash Key et la clé API (exposés) et remplacer `NOTCHPAY_HASH` / `NOTCHPAY_KEY`.
3. Passage en production Notch Pay (clé et Hash Key de production) : décision du propriétaire.
4. Réactiver « Confirm email » et fournir un modèle d'e-mail avec jeton (ou un fournisseur SMS) pour un vrai code de vérification.

## À développer
- Messagerie : pièces jointes et messages vocaux en conversation enregistrée ; fil dédié à une commande (écran 54) ; "Contacter le vendeur" depuis une fiche produit (seules les 3 occurrences liées aux commandes sont branchées).
- **127 actions « Démonstration » sur 91 écrans** (liste dans `ACTIONS_DEMONSTRATION.md`) : événements, hackathons, missions sur mesure, borne, certificats, WhatsApp, cercle, administration… chacune demande son comportement métier et sa persistance.
- **Liens contextuels** : 252 écrans ne sont atteints que par « Mes rubriques ».
- Photos d'annonce dans le catalogue acheteur ; photo de profil ; procédure de certification complète (justificatifs, écran de décision) ; boutons « en préparation » et « livrée » (2 et 4) dans les écrans vendeur.
- Tableaux de bord et statistiques vendeur calculés par vues SQL (écrans 57, 62, 66, 67) ; suivi de statut côté acheteur (écran 46) alimenté par la préparation du vendeur.
- Règle tranchée : le titre d'une annonce est unique sur la plateforme (le panier commande par titre).
- Tests Playwright / E2E navigateur (connexion, annonces, commande, validation, notifications, rôles, responsive), accessibilité, performance (bundle 9 Mo), builds Android et iOS.
- Webhook Notch Pay : identifier la cause du rejet de signature puis test sandbox de bout en bout avec un événement authentique ; Orange Money, sous-paiement et remboursements.
- Séparation des environnements : une seule base Supabase pour démonstration et production.
