# 02 — État des fonctionnalités (01/11/2026, fin de journée)

Légende : **PROD** = en production et vérifié en ligne · **LOCAL** = fait et testé en local (réplique), pas en production · **À FAIRE**.

| Domaine | État | Preuve |
|---|---|---|
| Catalogue des 11 produits de la plateforme (prix, stock, département, vendeur « Boutik-École ») | **PROD** (migration + site) | migration 20261101000100, site `706cb391…`, REST anonyme 14/14 |
| Préparation des commandes des produits plateforme par le département ou l'administrateur | **PROD** | réplique 28/28 ; compte administrateur réel créé |
| Stocks réels des 11 produits | **À FAIRE** (propriétaire) | stock fictif 100 conservé : quantités réelles inconnues, non inventées |
| Administration des comptes (rôle, suspension) et des signalements, côté serveur | **PROD** | migration 20261101000000, réplique 20/20 |
| Concours : publication, inscription, équipes, dépôt, jury, classement, modération | **PROD** | migration 20261101000200, réplique 38/38 ; 0 concours publié |
| Livraison : retrait sur campus ; domicile désactivé tant que l'administrateur ne l'active pas ; carnet d'adresses ; circuit logistique | **PROD** | migration 20261101000300, réplique 22/22 ; réglage lu en ligne : désactivé |
| Suivi de mission réel (192 à 201) | **PROD** (site) | tests 448/448, puis 462/462 |
| Écrans d'état 150-1, 150-4, 275 ; écran de démarrage S1 ; A2 | **PROD** (site) | S1 vérifié en ligne (Playwright) |
| Recherche du back-office (63 écrans), journaux d'audit sans entrées fictives | **PROD** (site) | golden images identiques |
| Parrainage et gains (code, filleuls, primes, part des ventes, gains en attente 14 jours) | **LOCAL** | migration 20261101000400, réplique 19/19 ; **non autorisée en production** |
| Notifications : architecture commune (préférences, appareils, file d'envoi) | **LOCAL** | migration 20261101000500, réplique 12/12 ; aucun envoi |
| Envoi push, e-mail, SMS | **À FAIRE** | fournisseurs et coûts à choisir |
| Reels, lives, défis et points | **À FAIRE** | règles validées ; fournisseur vidéo à choisir ; migration à écrire |
| Paiement Mobile Money (Notch Pay) et séquestre des jalons | **À FAIRE** (clés en direct, sandbox) | les écrans affichent « indisponible », aucun faux succès |
| Vérification étudiant (18c) | **À FAIRE** | migration à écrire (matricule, pièces privées) |
| Données de maquette encore affichées | **À FAIRE** | 116 écrans (matrice 00) |
