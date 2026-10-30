# Reste à faire (tâches réellement non terminées ou bloquées — 30/10/2026, nuit)

Ce document ne liste que ce qui n'est **pas** fait. Le projet n'est pas terminé : voir « Critères de finition » en bas.

## Bloqué par une action du propriétaire
1. **Serveur MCP** : « Verify JWT » est encore ACTIVÉ sur la fonction `notchpay-mcp` (URL publique en 401). Désactiver « Verify JWT » sur `notchpay-mcp` et ajouter le secret `MCP_ACCESS_KEY` ; l'URL est alors `https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/notchpay-mcp/mcp?key=<MCP_ACCESS_KEY>`. Le serveur reste en lecture seule, données personnelles masquées (26/26 en local).
2. **Webhook Notch Pay** : aucun événement réel n'a encore été accepté. Envoyer un événement de test depuis Notch Pay pour lire le diagnostic de signature ; renouveler le Hash Key et la clé API (exposés dans une conversation) et remplacer `NOTCHPAY_HASH` / `NOTCHPAY_KEY`. La vérification HMAC n'est jamais désactivée.
3. Passage en production Notch Pay (clé et Hash Key de production) et Orange Money : décision du propriétaire.
4. Réactiver « Confirm email » et fournir un modèle d'e-mail avec jeton (ou un fournisseur SMS) pour un vrai code de vérification.

## Dépendances externes qui bloquent des actions précises
- **Paiement du devis accepté** (services), **contribution à une campagne** (84b), **retrait des gains** (243), **séquestre du duel** (219), **paiement de mission** (193, 197, 234) : nécessitent les paiements réels. Les boutons restent affichés et expliquent pourquoi l'action est indisponible (`Retrait indisponible`, `Contribution indisponible`) ; rien n'est simulé.
- **Vérification en 2 étapes** (272) : nécessite l'activation du MFA TOTP de Supabase Auth.

## À développer
- **Écrans encore sans entrée contextuelle (90 sur 315)** : `a1 a2 a3 d1 l1 p1 p2 p3 p4 p5 s1 v1 20 22c 22d 23 24 32 34 35 38 39 47 55 77 84 87 93b 96 99 102 104 106 143 146_2 148_2 150_1 150_2 150_3 150_4 156 158 167 176 178 180 181 182 183 184 185 196 199 202 204 211 218 221 224 225 226 233 234 235 239 241 242 250b 255 256 262 263 264 265 267 268 269 270 275 276 277 278 279 280 281 282 283 284 285 288`. Ce sont des variantes de la maquette (états hors ligne 150_x/182/183/184, variantes d'accueil 175–178, onglets 22c/22d), des écrans de studio créateur (a*, p*, s1, v1, d1, l1) et des consoles secondaires (262–288) dont l'entrée métier doit être décidée avec le propriétaire (aucun libellé de la maquette ne les désigne). Ils restent atteignables par « Toutes les rubriques » (filtré par rôle).
- **105 actions « Démonstration » sur 76 écrans** (liste dans `ACTIONS_DEMONSTRATION.md`, régénérée) : missions sur mesure (191–199), borne (206–210, 276–277), certificats (166, 211, 213, 283), cercle et publication (243–250), administration (118, 280, 282, 284–288), messages de dossier (196, 55), formulaires de brouillon (59, 84, 90, 218, 224).
- Préférences d'alertes (156) et canaux (236) : les interrupteurs de la maquette ne sont pas liés à un état lisible ; à brancher avant d'enregistrer des préférences.
- Tableaux de bord vendeur : les chiffres du haut de l'écran 57 (ventes du mois, commandes, revenu attendu) sont ceux de la maquette ; à calculer par vues SQL (écrans 57, 62, 66, 67).
- Photo de profil (téléversement), procédure de certification complète (justificatifs, écran de décision).
- Séparation des environnements : une seule base Supabase pour démonstration et production.
- Tests Playwright : voir `TESTS_ET_PREUVES.md` ; à étendre à la messagerie avec pièces jointes et vocaux, à la commande complète (paiement sandbox), au parcours validateur et administrateur. Accessibilité, performance (bundle 9 Mo), builds Android et iOS.

## Critères de finition
Le projet ne sera déclaré terminé que lorsque : les 315 écrans ont une entrée par un parcours métier ; plus aucune action « Démonstration » ne subsiste (hors dépendances externes expliquées) ; les parcours par rôle sont couverts par des tests navigateur ; le MCP répond en HTTPS ; le webhook a accepté un événement authentique. Ce n'est pas le cas aujourd'hui.
