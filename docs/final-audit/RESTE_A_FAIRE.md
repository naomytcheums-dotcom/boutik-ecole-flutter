# Reste à faire (tâches réellement non terminées ou bloquées)

## Bloqué par une action du propriétaire
1. Désactivation de « Verify JWT » : faite. Reste : renouveler le Hash Key et la clé API Notch Pay (exposés), remplacer `NOTCHPAY_HASH` et `NOTCHPAY_KEY` dans Supabase, envoyer un événement de test depuis Notch Pay pour lire le diagnostic.
2. Passage en production Notch Pay (clé et Hash Key de production) : décision et clés du propriétaire.
3. Réactiver « Confirm email » dans Supabase et fournir un modèle d'e-mail avec jeton, ou choisir un fournisseur SMS, pour un vrai code de vérification.

## À développer (non commencé ou partiel)
- **Persistance Supabase** : annonces vendeur (+ images, Storage), stock et mouvements, commandes reçues par le vendeur, messagerie, notifications, missions, hackathons, borne, avis, tableaux de bord calculés par vues SQL.
- **175 actions « Démonstration »** sur 122 écrans (liste dans `ACTIONS_DEMONSTRATION.md`) : chacune demande son comportement métier et sa persistance.
- **Liens contextuels** : 255 écrans ne sont atteints que par « Mes rubriques » ; leurs parcours naturels (boutons, lignes de menu) restent à câbler écran par écran.
- Édition du profil, téléversement de photo, procédure de certification complète (justificatifs, écran de décision).
- Récupération de mot de passe réelle ; connexion par téléphone.
- Tests Playwright (connexion, navigation, formulaires, rôles, responsive, paiement sandbox), accessibilité, performance (bundle 9 Mo), builds Android et iOS.
- Webhook Notch Pay : identifier la cause du rejet de signature, puis test sandbox de bout en bout avec un événement authentique.
- Orange Money, sous-paiement et remboursements avec le fournisseur.
- Séparation des environnements (démo / préproduction / production) : une seule base Supabase aujourd'hui.
