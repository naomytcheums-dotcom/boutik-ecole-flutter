# Algorithme de recommandation

État : **implémenté et testé unitairement dans `lib/core/domain/feed_ranker.dart` ; non branché** à l'application (aucun fil de publications n'existe : la table `posts` actuelle ne contient que des reels). Il ne prouve pas qu'un fil fonctionne.

## Entrées

`FeedItem` : auteur, date, catégorie, format, communauté, compteurs (j'aime, commentaires, enregistrements, partages, signalements), qualité (0 à 1, calculée en amont sans les likes), état de modération. `FeedSignals` : abonnements, communautés rejointes, intérêts (catégorie → poids), affinité par auteur, auteurs masqués ou bloqués, contenus masqués ou déjà vus, catégories coupées. Aucune donnée sensible n'est prévue.

## Score (poids par défaut, tous configurables via `RankWeights`)

`score = 0,28 affinité + 0,25 intérêt + 0,18 fraîcheur + 0,12 qualité + 0,08 popularité + 0,09 communauté − pénalité signalements − pénalité déjà vu`

- Fraîcheur : décroissance exponentielle, demi-vie de 48 h.
- Popularité : `log(1 + j'aime + 2·commentaires + 3·enregistrements + 2·partages) / log(1 + 500)`, plafonnée à 1, poids de 0,08 : un contenu viral ne domine pas.
- Signalements : pénalité progressive jusqu'à 5 signalements ; la décision reste à la modération (un contenu non approuvé n'est jamais classé).
- Déjà vu : pénalité de 0,45.
- Diversité : sélection gloutonne, au plus 2 contenus par auteur, pénalité par répétition d'auteur (0,22), de catégorie (0,06) et de format (0,04).

## Onglets

Pour toi (classement complet), Abonnements et Communautés (filtres sur relations réelles, même classement), Tendances (popularité × fraîcheur), Publications récentes (ordre chronologique pur). Chaque résultat porte des raisons lisibles ("Vous suivez cet auteur", "Correspond à votre intérêt : tech"…).

## Limites assumées

- Les poids sont des valeurs de départ, **non calibrées** sur des données réelles ; elles doivent être évaluées (clics, masquages, durée) avant tout réglage.
- Les protections contre faux likes, abonnements artificiels et spam relèvent du serveur (limitation de débit, unicité `(post, utilisateur)`, détection d'anomalies) : elles ne sont pas dans ce module.
- Produits, profils, communautés, projets, services et événements : le même moteur peut les classer si on leur fournit un `FeedItem` ; ces adaptateurs ne sont pas écrits.
- Les contenus sponsorisés sont insérés par la logique de campagne, avec la mention « Sponsorisé », et ne passent pas par ce score.
