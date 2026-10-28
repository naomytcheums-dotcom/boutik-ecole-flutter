# Questions · section F (50–56)

1. **50 · icône en haut à droite** — La maquette montre un soleil (Lucide sun) sans libellé. Choix : bouton « Paramètres des notifications » ouvrant l’écran 56.
2. **50 · étoile « Laissez un avis »** — Étoile pleine bleue (#2F5D8A) : pas d’équivalent plein dans Lucide. Choix : assets/icons/star-filled.svg (copie de star.svg avec remplissage currentColor).
3. **50 · pastilles de filtre** — Les marges internes diffèrent d’une pastille à l’autre (largeurs fixes Figma 70 / 92,5 / 85 / 99,5) et « Promotions » est coupée : reproduit (largeurs minimales relevées, liste défilante). Aucune pastille « Compte » : « Compte vérifié » n’apparaît que dans « Toutes ».
4. **50 · « La lampe est prête pour le retrai… »** — Texte tronqué sur la maquette alors que la place suffit : affiché en entier (troncature automatique seulement si nécessaire).
5. **50, 51 · références « #BE-2026–0142 »** — La maquette mélange tiret et tiret demi-cadratin ; tiret simple conservé, comme la section E.
6. **53, 54 · vignettes** — « Lampe en bois recyclé » est illustrée par un drone (53) puis par des ampoules (54) : reproduit tel quel (Photos.drone, Photos.bulb).
7. **53–55 · heures des messages** — Le gris #8793A5 n’atteint pas 4,5:1 sur le fond (≈ 2,6:1). Choix : AppColors.textSecondary.
8. **56 · titre** — « Notifications et confidentialité » déborde de l’écran sur la maquette. Choix : titre réduit pour tenir sur la largeur (FittedBox), sans troncature.
9. **52 / 55 · persona** — « Mariam Essono » est un contact de la liste 52 alors que l’entreprise de 55 s’adresse à « Mariam » (l’utilisatrice) : reproduit tel quel.
10. **55 · titre du besoin** — Tronqué sur la maquette (« Besoin : application de suiv… »). Choix : titre complet supposé « Besoin : application de suivi des livraisons », tronqué à l’affichage.
11. **52 · avatars** — Extraits de la capture (assets/images/f_avatar_*.jpg, découpe ronde) ; Aminata Bello réutilise Photos.studentHijab (même photo). Les coins hors du cercle contiennent le fond blanc de la carte, masqués par le découpage rond.
12. **Barre de saisie (53–55)** — Non précisé : le micro devient « Envoyer » dès qu’un texte est saisi ; le message envoyé s’ajoute au fil avec l’heure courante. Trombone, appareil photo, micro et téléphone (53) affichent un message (démonstration).
13. **Navigation** (non précisée par les maquettes) — 50 : Commande expédiée → 51, Nouveau message → 53, Nouveauté favoris → 32, Laissez un avis → 45, Événement → 100, Compte vérifié → 57 ; 51 : « Contacter le vendeur » → 54, « Suivre ma commande » → 46 ; 52 : Yannick → 53, autres contacts → fil générique (dernier message), crayon → feuille « Nouveau message » ; 53 « Voir » → 32 ; 54 « Voir » → 46 ; 56 « Télécharger mes données » → feuille de confirmation (export simulé).
14. **Menu bas (50, 52)** — Aucun onglet n’est mis en évidence sur les maquettes : GlassNavBar sans onglet actif.
15. **Goldens** — docs/screens.json ne donne pas de hauteur pour 50–56 : rendus 390 × 900 contre 844 pour les captures ; dans build/compare, le menu, la barre de saisie et le panneau d’actions apparaissent donc 56 px plus bas.
16. **Pastilles de filtre (50)** — 34 px de haut sur la maquette ; zone tactile portée à 44 px sans changer le visuel.
