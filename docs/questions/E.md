# Questions · section E (41–49)

1. **45 · vignettes vides** — Sur la maquette, la zone vignette (50 px) des 4 commandes est vide (images non exportées ?). Choix : afficher une photo de démonstration par commande (SectionEData.orders).
2. **41 · téléphone « +237 6 XX XX XX XX »** — Valeur ou masque ? Choix : masque affiché comme indication (couleur encre, comme la maquette) ; le champ est vide et « Continuer » exige un vrai numéro (9 chiffres commençant par 6).
3. **41, 42, 47, 48 · cases à cocher** — Cochée = carré encre plein sans coche, non cochée = carré blanc bordé (reproduit tel quel). Les lignes de motif font 36 px de haut (pas de 36 px imposé par la maquette, < 44 px) ; la zone tactile couvre toute la largeur.
4. **45, 47 · rouge « Annulée » / « Annuler la commande »** — Le rouge #E5484D de la maquette n’atteint pas 4,5:1 (3,3:1 sur fond rose, 3,9:1 sur blanc). Choix : texte en AppColors.error (#B42318) ; la bordure du bouton garde #E5484D.
5. **44 · illustration** — Le sac 3D chromé de la maquette est approximé par ChromeIcon(shopping-bag), comme les autres illustrations chromées du projet.
6. **46 · carte** — La carte du Cameroun avec le trajet est extraite de la capture (assets/images/e_carte_trajet.png, fond rendu transparent) ; les pastilles de départ/arrivée font partie de l’illustration.
7. **49 · icône « Commandes et livraisons »** — Icône Lucide la plus proche : package-2 (ajoutée à assets/icons).
8. **42 · photos des articles** — Les vignettes de la maquette ne correspondent pas aux articles (image « Branding » pour l’ordinateur, croquis pour la lampe, masques pour le logo) : reproduites telles quelles.
9. **45 · « 12 commandes »** — 4 commandes seulement sont listées. Choix : le compteur affiche le total du compte (12) sans filtre, puis le nombre de résultats dès qu’un filtre ou une recherche est actif.
10. **49 · bouton « Contacter le support »** — 28 px de haut sur la maquette ; zone tactile portée à 44 px sans changer le visuel.
11. **Navigation** (non précisée par les maquettes) — 41 → 08 (Paiement), 42 → 43, 43 « J’ai payé » → 44, 44 → 46 / 03, 45 → 46 (48 pour une commande annulée), 46 « Contacter le vendeur » → 51, 47 → 45, 48 reste sur place (message), 49 → 45 / 43 / 51.
12. **En-têtes** — Titre 21 px à x = 76 et barre d’actions blanche en bas (100 px) mesurés sur les captures ; marge haute alignée sur la maquette (zone d’état de 47 px) plutôt que sur TitleHeader de la section A.
