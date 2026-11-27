# Boutik-École : matrice de tests du compte Client (27 novembre 2026)

Site en ligne `https://boutik-ecole.vercel.app`, format téléphone 375 x 812, compte « Test Client » (ouvert depuis le compte administrateur). Tests faits à la main dans un navigateur. **Le parcours client n'est PAS validé : il est PARTIEL.** Les autres acteurs (étudiant, organisation, département, administrateur) ne sont pas testés.

Statuts : OK = action faite et résultat vu ; DÉFAUT = problème constaté ; À CONFIRMER = résultat incertain ; BLOQUÉ = dépendance manquante.

## A. Actions faites à l'écran

| # | Écran | Action | Résultat attendu | Résultat réel | Statut | Après correction (27 nov., soir) |
|---|---|---|---|---|---|---|
| 1 | Démarrage | « Passer » l'introduction | écran de connexion ou choix | arrivée sur l'accueil sans se connecter | À CONFIRMER (choix de conception) | Non rejoué |
| 2 | Démarrage (cache vidé) | premier affichage | écran rapide | plus de 30 s, écran vide au début | DÉFAUT | Non rejoué |
| 3 | Après connexion | fenêtre « Conditions d'utilisation » > Plus tard | reste fermée | réapparue pendant le chargement de la page | DÉFAUT | Non rejoué |
| 4 | Accueil | icône recherche | recherche | ouvre « Rechercher » | OK | Non rejoué |
| 5 | Accueil | barre de recherche | recherche | ouvre « Rechercher » | OK | Non rejoué |
| 6 | Accueil | flèche de la bannière « À la une » | ouvre le contenu | rien ne se passe | DÉFAUT | OK en ligne : la flèche ouvre la rubrique affichée (vérifié avec le compte étudiant, pas le client) |
| 7 | Accueil | « Voir tout » (produits en vedette) | catalogue | « Catalogue de produits », 0 résultat | OK (catalogue vide) | Non rejoué |
| 8 | Accueil | avatar | profil | « Mon profil » | OK | Non rejoué |
| 9 | Accueil | menu du bas : Réseau, Messages, Kéla | ouvre l'onglet | les trois onglets s'ouvrent | OK | Non rejoué |
| 10 | Rechercher | saisie dans le champ, puis Entrée | résultats | le texte ne s'affiche pas, aucune réaction (outil de test possible en cause) | À CONFIRMER à la main | Non rejoué |
| 11 | Rechercher | bouton « Talents » | résultats talents | « Aucun talent » (0) | OK (à vérifier : étudiant certifié absent) | Non rejoué |
| 12 | Résultats | saisie « dev » | filtre | texte affiché, 0 résultat | OK | Non rejoué |
| 13 | Filtres | « Produit physique » puis « Appliquer » | filtre actif | « Filtres : 1 appliqués » | OK | Non rejoué |
| 14 | Filtres | liste « Filière » | liste de choix | ne s'ouvre pas (liste vide depuis la suppression des établissements) | DÉFAUT | Non rejoué |
| 15 | Profil | « Modifier mon profil » | fenêtre complète | description, compétences, ville, visibilité seulement : **ni photo, ni nom** | DÉFAUT | OK en ligne pour l’affichage : « Changer ma photo » et « Nom » présents, nom vide refusé avec message (étudiant). Enregistrement d’un nouveau nom et envoi d’une photo : non testés en ligne |
| 16 | Profil | « Enregistrer » sans changement | confirmation | fenêtre fermée, aucune confirmation vue | À CONFIRMER | Non rejoué |
| 17 | Profil | cadres de couverture | image entière | image coupée (texte illisible) | DÉFAUT | Non rejoué |
| 18 | Profil | compteur Favoris | nombre | « — » | DÉFAUT | Compteurs Produits et Services à 0 au lieu de « — » (étudiant). Compteur Favoris du client : non revérifié |
| 19 | Menu du compte | « Mes devis » | liste ou vide | message « Aucune demande de devis » | OK | Non rejoué |
| 20 | Menu du compte | « Mes réclamations » | liste ou vide | message « Aucune réclamation » | OK | Non rejoué |
| 21 | Mes collections | « Créer une collection » | formulaire | fenêtre en bas de page | OK | Non rejoué |
| 22 | Nouvelle collection | liste « Visibilité » | plusieurs choix | un seul choix « Privée » | DÉFAUT | Non rejoué |
| 23 | Nouvelle collection | « Créer » sans nom | erreur dans la fenêtre | la fenêtre se ferme, message ensuite (saisie perdue) | DÉFAUT | OK en ligne : la fenêtre reste ouverte avec le message sous le champ (étudiant) |
| 24 | Mes collections | ouvrir une collection | contenu | « Cette collection est vide », Modifier / Supprimer | OK (non modifiée) | Non rejoué |
| 25 | Fenêtre de collection | changer de page avec la fenêtre ouverte | fenêtre fermée | elle reste par-dessus | DÉFAUT (mineur) | Non rejoué |
| 26 | Adresses | ajouter, ouvrir la modification, supprimer | fonctionne | fonctionne (confirmation de suppression ajoutée ensuite, non revérifiée) | OK | Non rejoué |
| 27 | Duel, support, besoin | envoi vide | message d'erreur | message affiché | OK | Non rejoué |
| 28 | Réseau social | publications en attente | liste | « Mes publications en attente » avec le statut | OK | Non rejoué |
| 29 | Réseau social | « Quoi de neuf ? » | formulaire | formulaire ouvert | OK | Non rejoué |
| 30 | Nouvelle publication | « Publier » vide | message | « Écrivez un texte ou ajoutez un média ou un lien » | OK | Non rejoué |
| 31 | Nouvelle publication | « Programmées » | liste | « Aucune publication programmée » | OK | Non rejoué |
| 32 | Nouvelle publication | mise en page | titre en premier | la phrase sur les hashtags est au-dessus du titre | DÉFAUT | Corrigé dans le code et publié ; non revérifié à l’écran |
| 33 | Réseau social | aimer puis retirer | compteur 1 puis 0 | conforme | OK | Non rejoué |
| 34 | Réseau social | commentaires | fenêtre | fenêtre ouverte (aucun commentaire envoyé) | OK | Non rejoué |
| 35 | Réseau social | vidéo | aperçu et lecture | pas d'aperçu ; écran noir après le toucher | DÉFAUT à confirmer | Non rejoué |
| 36 | Réseau social | partager | options de partage | aucun résultat visible | À CONFIRMER | Non rejoué |
| 37 | Kéla | « Commencer », puis écrire | réponse | « Kéla n'est pas configurée » | BLOQUÉ (clé IA absente) | Non rejoué |
| 38 | Accessibilité | boutons du menu du bas et des publications | nom lisible | plusieurs boutons sans nom | DÉFAUT | Non rejoué |

## B. Pages seulement ouvertes (aucun bouton testé)

`/s/04 06 19 22 25 26 28 45 49 50 51 52 70 78 100 103 151 155 160 191 214 216 219 220 221 238 240 244 245 253`, `/marche`, `/marche/panier`, `/marche/telechargements`, `/commandes/suivi`, `/mes-avis`, `/litiges`, `/mentors`, `/mes-entreprises`, `/concours`, `/innovations`, `/evenements/mes`, `/atelier`, `/createur/statistiques`, `/profil-createur/moi`, `/replays`, `/top100`, `/evaluations`, `/vendeur/conditions`, `/parametres/informations`, `/parametres/paiement`, `/aide/contact`. Elles s'affichent, sans plus.

## C. NON testé

- Achat : aucun produit visible, donc ni panier, ni livraison, ni paiement, ni commande, ni suivi, ni facture, ni avis.
- Paiement réel ou bac à sable.
- Envoi de messages, de commentaires, de publications, d'histoires ; abonnements ; signalements.
- Envoi de photos, vidéos et fichiers (impossible avec l'outil de test) : photo de profil, couvertures, portfolio.
- Notifications du téléphone, géolocalisation, export des données, suppression de compte, déconnexion et reconnexion.
- La plupart des onglets, listes et filtres des pages de la section B.
- Entrées du menu du compte autres que celles citées.
- Version web large et tablette ; application Android.

## D. Défauts signalés par la propriétaire, encore non traités

Icônes de l'en-tête d'accueil à retirer ; « Votre besoin » (cadres sans image, trop petits) ; Kéla « Découvrir » sur le texte ; champ « Voix en texte » ; image de la bannière d'aide ; logos officiels Orange Money et MTN MoMo (fichiers à fournir) ; saisie avec propositions, calendrier des disponibilités, liste de langues ; portfolio (filtres, catégories, date) ; fond identique partout (la page 404 garde un fond uni) ; vidéos en lecture automatique.

## E. Deuxième série de clics (27 novembre, après-midi)

| Écran | Boutons essayés | Résultat |
|---|---|---|
| Accueil | pastilles Tous, Produits, Services, Talents, Projets | les cinq ouvrent une page ; en-têtes et menu du bas différents selon la page (DÉFAUT de cohérence) |
| Services | « Mes devis », « Demander un devis » | fenêtres d'information affichées |
| Projets innovants | « Soumettre un projet ou une innovation » | aucun effet visible (DÉFAUT) |
| Marketplace | listes types, filières, besoins, produits/boutiques, catégories, tri | les six listes s'ouvrent |
| Marketplace | liste « Filières » | propose encore des filières préremplies (Génie électrique, informatique, civil, agroalimentaire) (DÉFAUT) |
| Marketplace | réglages, éclair, cœur/boutiques suivies, « Appel aux organisations », « Projets de l'IUT » | tous ouvrent une page ou une fenêtre |
| Appel aux organisations | « Publier mon besoin » | ouvre « Votre besoin » |
| Réseau social | onglets Abonnements, Vidéos, Boutiques | les trois changent le contenu |
| Notifications | onglets Commandes, Messages, Autres | fonctionnent ; notification « Votre compte est certifié » |
| Événements | onglet Expositions, mois suivant | fonctionnent |
| Opportunités | « Offres classées pour vous », « Mon dossier », listes types et modes | fonctionnent |

Encore non essayés : la plupart des boutons des pages ouvertes par ces actions, les interrupteurs, la recherche dans chaque page, les autres entrées du menu ⋮.

## F. Après correction, 27 novembre au soir

Les statuts des tableaux ci-dessus restent les constats d’origine. Version publiée depuis la branche `correctifs-ui`.

- Vérifié à l’écran : icônes de l’en-tête d’accueil retirées ; « Partager » lisible ; icône de Kéla sur « Assistant Opportunités » ; sur grand écran, le Super admin arrive sur le tableau de bord de la plateforme et le compte département sur son espace (« En attente de rattachement »).
- Publié mais non revérifié : « Partager » copie le lien sans feuille de partage ; changement de photo ; certification masquée pour l’équipe ; redirection des organisations (session du 8102 fermée) et de la direction ou finance.
- Toujours en défaut : premier affichage très lent (PageSpeed, téléphone simulé en 4G lente : Speed Index 25,7 s) ; liste « Filière » ; vidéos ; boutons sans nom ; fenêtre des conditions à chaque ouverture ; « Nouveau projet » tronqué ; titres masqués par le bandeau des comptes de test.
