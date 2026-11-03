# Responsive et PWA

## Cause du « téléphone dans le navigateur »

Chaque écran est une toile à positions absolues de 390 px (mobile) ou 1280 px (web) mise à l'échelle par `FittedBox` (`lib/figma/gen.dart`, `GScreen`). La composition ne s'adapte pas : seule l'échelle change. À partir de 700 px de large la toile est centrée sur un fond uni, avec la fausse barre d'état (9:41, réseau, batterie), l'îlot et l'indicateur d'accueil **présents dans les maquettes** (vérifié dans Figma : écrans 21 et 10).

## Ce qui est déjà en place dans l'arbre de travail (modifications non commitées héritées, conservées)

`GScreen._phone` : sur un téléphone (largeur < 600 et < 700 px de toile) l'écran occupe toute la largeur **et** toute la hauteur, sans cadre ; la fausse barre d'état et l'indicateur d'accueil sont retirés ; le menu du bas et les barres d'actions pleine largeur restent fixes ; le contenu défile jusqu'au bout avec une marge égale à la hauteur du menu (D-042) ; le clavier est pris en compte. Testé : `test/journey/plein_ecran_telephone_test.dart`, 5 tests (360×640, 390×664, 412×839, 430×740 ; barre « Passer / Continuer » de 175).

## Ce qui n'est PAS résolu

- **Tablette et ordinateur** : la toile mobile reste centrée. Une vraie composition par largeur (colonnes, navigation latérale, tableaux) demande de recomposer chaque famille d'écrans ; les 71 écrans « web » sont des toiles de 1280 px mises à l'échelle sur petit écran. Aucun travail de recomposition n'est livré dans ce lot.
- **Fausse barre d'état à 1024 px et plus** (D-086) : maintenue ; la décision produit est en attente (Q-06 de la phase 7).
- **Contrastes** (D-084) : non corrigés ; changer les couleurs modifie les rendus de référence (315 images) et demande leur régénération ; reporté.
- **Hauteur réduite** (D-087, 375 × 500) : non reproduit dans les tests ; non corrigé.

## PWA

Présent : `web/manifest.json` (nom, icônes 192/512 et maskables, `display: standalone`, couleurs, langue `fr`), service worker généré par Flutter. À corriger : `orientation: portrait-primary` bloque le mode paysage des tablettes et des ordinateurs ; à retirer ou à passer à `any` après décision. Non vérifié dans cette session : installation, comportement hors ligne, mise à jour, notifications push (aucun envoi réel n'est branché). **Aucune construction web n'a été lancée** : le disque libre est de 3 à 4 Go, insuffisant pour une compilation lourde.

Une PWA n'est pas une application native ; l'application reste utilisable dans un navigateur classique.
