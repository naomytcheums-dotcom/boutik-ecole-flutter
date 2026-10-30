# Reste à faire (tâches réellement non terminées ou bloquées — mis à jour à la reprise du 30/10/2026, soir)

Ce document ne liste que ce qui n'est **pas** fait. Le projet n'est pas terminé : voir « Critères de finition » en bas. État de reprise détaillé : `REPRISE.md`.

## Bloqué par une action du propriétaire
0. **Accès d'administration de la base absent de l'environnement de reprise** : aucune migration nouvelle ne peut être appliquée ni aucun compte de test supprimé sans le propriétaire (jeton Supabase ou SQL). Comptes jetables à supprimer : `delete from auth.users where email like 'zz-test-%@example.com';`.
0 bis. **Rejouer `e2e/tests/devis.spec.ts`** sur une série neuve : `python supabase/tests/quotes_rest.py 1`, approbation SQL du service créé, puis `STATE=<fichier> npx playwright test devis --workers=1`.
1. **Serveur MCP** : « Verify JWT » est encore ACTIVÉ sur la fonction `notchpay-mcp` (URL publique en 401). Désactiver « Verify JWT » sur `notchpay-mcp` et ajouter le secret `MCP_ACCESS_KEY` ; l'URL est alors `https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-mcp/mcp?key=<MCP_ACCESS_KEY>`. Le serveur reste en lecture seule, données personnelles masquées (26/26 en local).
2. **Webhook Notch Pay** : aucun événement réel n'a encore été accepté. Envoyer un événement de test depuis Notch Pay pour lire le diagnostic de signature ; renouveler le Hash Key et la clé API (exposés dans une conversation) et remplacer `NOTCHPAY_HASH` / `NOTCHPAY_KEY`. La vérification HMAC n'est jamais désactivée.
3. Passage en production Notch Pay (clé et Hash Key de production) et Orange Money : décision du propriétaire.
4. Réactiver « Confirm email » et fournir un modèle d'e-mail avec jeton (ou un fournisseur SMS) pour un vrai code de vérification.

## Dépendances externes qui bloquent des actions précises
- **Paiement du devis accepté** (services), **contribution à une campagne** (84b), **retrait des gains** (243), **séquestre du duel** (219), **paiement de mission** (193, 197, 234) : nécessitent les paiements réels. Les boutons restent affichés et expliquent pourquoi l'action est indisponible (`Retrait indisponible`, `Contribution indisponible`) ; rien n'est simulé.
- **Vérification en 2 étapes** (272) : nécessite l'activation du MFA TOTP de Supabase Auth.

## À développer
- **Écrans encore sans entrée contextuelle (13 sur 315)** : `s1 a2 p4 250b 176 182 183 275 150_1 150_2 150_3 150_4` sont des états ou variantes de la maquette (démarrage animé, variantes d'accueil et de publication, états hors ligne, session expirée, formulaire en erreur) : ils devraient être affichés par l'état réel correspondant (hors connexion, session expirée, erreur de saisie) plutôt que par un lien. `47` (formulaire d'annulation avec motif) : l'annulation réelle existe dans « Mes commandes », l'écran n'a pas de libellé d'entrée dans le détail de commande (29). Tous restent atteignables par « Toutes les rubriques » (filtré par rôle).
- **76 actions « Démonstration » sur 54 écrans** (liste régénérée dans `ACTIONS_DEMONSTRATION.md`) : missions sur mesure (191–199), borne (206–210, 276–277), certificats (166, 211, 213, 283), cercle et publication (243–250), administration (118, 280, 282, 284–288), messages de dossier (196, 55), formulaires de brouillon (59, 84, 90, 205, 218, 224) — la plupart exigent des tables qui n'existent pas encore (besoins, vœux, campagnes, certificats, bornes), donc une migration à appliquer par le propriétaire.
- Tableaux de bord vendeur : les chiffres du haut de l'écran 57 (ventes du mois, commandes, revenu attendu) sont ceux de la maquette ; à calculer par vues SQL (écrans 57, 62, 66, 67).
- Photo de profil (téléversement), procédure de certification complète (justificatifs, écran de décision).
- Séparation des environnements : une seule base Supabase pour démonstration et production.
- Tests Playwright : voir `TESTS_ET_PREUVES.md` (parcours 5/5, engagements 5/5, visiteur 12/12 à la reprise) ; à étendre à la messagerie avec pièces jointes et vocaux, à la commande complète (paiement sandbox), au parcours validateur et administrateur (nécessite des comptes de rôle créés par le propriétaire), à la précommande, au suivi et à l'alerte de stock. Accessibilité, performance (bundle 9 Mo), builds Android et iOS.
- Les liens posés à la reprise (`// lien métier`) n'ont pas tous été parcourus dans un navigateur : le test `links_test.dart` garantit que chaque cible existe et que le menu ne propose que des écrans autorisés au rôle.

## Critères de finition
Le projet ne sera déclaré terminé que lorsque : les 315 écrans ont une entrée par un parcours métier ; plus aucune action « Démonstration » ne subsiste (hors dépendances externes expliquées) ; les parcours par rôle sont couverts par des tests navigateur ; le MCP répond en HTTPS ; le webhook a accepté un événement authentique. Ce n'est pas le cas aujourd'hui.
