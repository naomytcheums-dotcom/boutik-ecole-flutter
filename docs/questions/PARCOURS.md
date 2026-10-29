# Questions — Parcours de démonstration (soutenance)

Parcours : 03 → 19 → 22 → 05 → 33 → 10 → 40 → 06 → 07 → 08 → 257 → 259 → 260 → 44 → 09 → 111 → 213 → 212 → 206 → 207 → 208 → 209 → 210 → 237.

Vérifié par `test/journey/demo_journey_test.dart` (sans appareil, à chaque `flutter test`) et `integration_test/demo_journey_test.dart` (navigateur Chrome réel via `flutter drive`, voir README).

Liens ajoutés pour que le parcours se fasse au doigt (pas d'interaction de prototype lisible) :

1. **33 → 10.** Le bloc créateur (photo, nom, filière) ouvre le profil étudiant.
2. **10 → 40.** Les compteurs du profil sont touchables : « Produits » → catalogue (22), « Services » → demande de devis (40), « Projets » → projets innovants (78). Zone tactile de 44 px sans déplacer la mise en page.
3. **40 → 06.** Après l'envoi de la demande, « Demande envoyée » s'affiche et le bouton devient « Voir mon panier ». À confirmer : la maquette ne montre pas l'état après envoi.
4. **44 → 09.** « Suivre ma commande » ouvre « Ma commande » (09) au lieu du suivi de livraison (46), pour suivre le parcours.

Changements d'appareil (le test ouvre directement l'écran, comme la personne sur l'autre appareil) :

5. **09 → 111 → 213.** Passage du mobile acheteur à la console web du département puis au registre des certificats.
6. **210 → 237.** Passage de la borne à la page web d'impact.
