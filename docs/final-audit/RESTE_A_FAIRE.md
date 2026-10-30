# Reste à faire (tâches réellement non terminées ou bloquées — 30/10/2026, soir)

## Bloqué par une action du propriétaire
1. **Serveur MCP** : « Verify JWT » est encore ACTIVÉ sur la fonction `notchpay-mcp` (vérifié le 30/10) ; désactiver « Verify JWT » sur `notchpay-mcp` et ajouter le secret `MCP_ACCESS_KEY` (étapes dans `MCP_NOTCHPAY.md`).
2. **Webhook Notch Pay** : envoyer un événement de test depuis Notch Pay pour lire le diagnostic de signature ; renouveler le Hash Key et la clé API (exposés) et remplacer `NOTCHPAY_HASH` / `NOTCHPAY_KEY`.
3. Passage en production Notch Pay (clé et Hash Key de production) : décision du propriétaire.
4. Réactiver « Confirm email » et fournir un modèle d'e-mail avec jeton (ou un fournisseur SMS) pour un vrai code de vérification.

## À développer
- Messagerie : pièces jointes et messages vocaux en conversation enregistrée ; fil dédié à une commande (écran 54) ; "Contacter le vendeur" depuis une fiche produit (seules les 3 occurrences liées aux commandes sont branchées).
- **175 actions « Démonstration » sur 122 écrans** (liste dans `ACTIONS_DEMONSTRATION.md`), dont aucune n'a été traitée dans ce lot au-delà des 17 de navigation : chacune demande son comportement métier.
- **Liens contextuels** : 255 écrans ne sont atteints que par « Mes rubriques ».
- Modification d'une annonce (écran), téléversement de photos (annonce et profil), édition du profil, procédure de certification complète (justificatifs, écran de décision).
- Commandes reçues par le vendeur (lecture des `order_lines` de ses annonces, statuts de préparation), tableaux de bord calculés par vues SQL.
- Règle d'unicité du titre : le panier commande par titre ; deux vendeurs ne peuvent donc pas avoir le même titre d'annonce (décision métier à confirmer).
- Rôle choisi à l'inscription : la migration `20261030g` est prête mais volontairement non appliquée (assouplissement de sécurité) : à appliquer par le propriétaire si approuvé.
- Tests Playwright / E2E navigateur (connexion, annonces, commande, validation, notifications, rôles, responsive), accessibilité, performance (bundle 9 Mo), builds Android et iOS.
- Webhook Notch Pay : identifier la cause du rejet de signature puis test sandbox de bout en bout avec un événement authentique ; Orange Money, sous-paiement et remboursements.
- Séparation des environnements : une seule base Supabase pour démonstration et production.
