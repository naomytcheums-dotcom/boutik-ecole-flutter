# Tests à l'écran sur le site en ligne (27 novembre 2026)

Site `https://boutik-ecole.vercel.app`, format mobile 375 x 812, compte de test Client ouvert depuis le compte administrateur. Vérification visuelle, page par page. Non commité (travail de Copilot en cours dans le dépôt).

## Client : ouverts et affichés sans erreur, sans donnée fictive vue

Accueil, notifications, réglages de notifications, canaux, profil, menu du compte ; `/s/04 06 19 22 25 25b 26 27 45 49 52 70 78 100 103 151 155 160 191 214 216 219 220 221 231 238 240 244 245 253` ; `/marche`, `/marche/panier`, `/marche/telechargements`, `/commandes/suivi`, `/mes-avis`, `/litiges`, `/mentors`, `/mes-entreprises`, `/concours`, `/innovations`, `/evenements/mes`, `/atelier`, `/createur/statistiques`, `/profil-createur/moi`, `/replays`, `/top100`, `/evaluations`, `/vendeur/conditions`, `/parametres/informations`, `/parametres/paiement`, `/aide/contact`.

Actions réussies : ajout, modification (formulaire ouvert) et suppression d'une adresse de test ; messages d'erreur sur duel vide, demande de support vide, besoin vide ; Kéla ouvre l'assistante et dit honnêtement qu'elle n'est pas configurée.

## Défauts constatés

1. « Revenir à mon compte » a déconnecté (écran « Session expirée ») au lieu de revenir à l'administrateur. Une seule tentative ; cause non cherchée.
2. Adresse : « Enregistrer » avec des champs vides ferme la fenêtre sans message.
3. Adresse : la corbeille supprime sans confirmation.
4. Page « Écran introuvable » : deux menus du bas superposés.
5. Bandeau « Compte de test » : recouvre le haut des pages (titres, retour, cloche). Ne concerne que ce mode.
6. Menu du bas absent sur certaines pages (favoris, comparer, explorer, catalogue, rechercher, duel, résultats, hackathons).
7. Tutoiement et vouvoiement mélangés (« Recommandés pour toi », « Touche le micro » / « Touchez le micro »).
8. Mentions « IUT » encore présentes (Projets de l'IUT, Innovations, Opportunités « Réservées IUT »).
9. « Canaux et notifications » : libellé « Notifications dans l'applica… » coupé.
10. Reels : boutons aimer, commenter, partager, enregistrer affichés sans aucun reel.
11. Parrainage : montants et pourcentages affichés (500, 750 + 2 %, 1 000 + 3 %) : à confirmer par le propriétaire.
12. Atelier : un live « tch » apparaît « EN DIRECT » avec 0 spectateur : à vérifier (resté ouvert ?).

## Non testé chez le Client

Achat et paiement (aucun produit visible), envoi de messages, publication, communauté, candidature, téléversement de fichiers et photos, export des données, localisation, notifications du navigateur, fenêtres Devis / Réclamations / code de parrainage, la plupart des filtres et onglets.

## Autres acteurs

Étudiant, Organisation, Département, Administrateur : non testés.
