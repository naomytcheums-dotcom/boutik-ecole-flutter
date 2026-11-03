# État des 315 écrans (fin du lot 3, 03/11/2026)

Source : `etat_ecrans.csv` (une ligne par écran, calculée **depuis le code**). Aucun écran n'est déclaré « validé » : aucun n'a été vérifié dans un navigateur.

## Corrections appliquées par composant partagé (nombre d'écrans dont le code a changé)

| Correction | Écrans | Comment |
|---|---|---|
| Contraste des textes secondaires (D-084) : gris relevé à `#57545F` (≥ 4,5:1 sur les fonds en dégradé mesurés), rouge d'erreur `#C0261B` ; le générateur applique la même table | **306** | 2 231 + 63 occurrences remplacées ; 306 rendus de référence régénérés puis revérifiés |
| Écrans de format mobile : composition plein écran sur téléphone, **colonne de 480 px centrée sur tablette et ordinateur**, sans cadre de téléphone ni fausse barre d'état ni indicateur d'accueil (D-081, D-086) | **233** (format mobile) | `GScreen._phone` généralisé ; testé à 3 largeurs sur les 315 écrans |
| Chiffres fictifs de la maquette (montants, pourcentages, notes, compteurs ≥ 100) remplacés par « — » quand l'application est connectée au serveur ; la démonstration hors connexion est inchangée | **106** (394 occurrences) | règle automatique ; **les populations de ces écrans ne sont pas pour autant branchées sur des données réelles** |
| Onglet Messages de la barre du bas vers la liste des conversations (D-005) | **93** | |
| Messages d'erreur : aucun texte technique brut (D-024) | tous les écrans qui appellent le serveur (point central `Backend`) | |

## Écrans traités individuellement (données, états, règles)

09, 29, 42, 43, 46, 47 (chaîne de commande), 245, 252 (publications : compteurs, commentaires, enregistrement, abonnement, balayage), 103 (communautés réelles), 10 (certification visiteur) : **10 écrans**.

## Récapitulatif demandé

| Catégorie | Nombre |
|---|---|
| Écrans dont le code a reçu au moins une correction (partagée ou propre) | **314 sur 315** (seul S1, écran de démarrage, n'a reçu aucune modification) |
| Écrans corrigés en profondeur (données réelles, états, règles) | **10** |
| Écrans dont la composition aux 3 largeurs est testée | **315** (sans exception de rendu ; ne prouve pas le fonctionnement) |
| Écrans dont le fonctionnement est testé par un test dédié de ce lot | **10** (les 10 ci-dessus) ; d'autres écrans ont des tests antérieurs (23 « connectés et fonctionnels » selon l'inventaire du 01/11) |
| Écrans vérifiés visuellement | **3** (42, 46, 103) sur rendu de test ; **0 dans un navigateur** |
| Écrans bloqués | voir ci-dessous |

## Ce qui reste pour que chaque écran soit réellement « corrigé »

- **Formats web (64), borne (5) et tablette (1)** : ils restent des toiles à positions absolues mises à l'échelle (agrandissables au pincement sur petit écran). Une vraie composition adaptative demande de les recomposer famille par famille : **non fait**.
- **116 écrans à données de maquette** (tableaux de bord département, direction, finance, administration, espaces entreprise) : les chiffres fictifs sont masqués hors démonstration, mais les sources de données n'existent pas : **bloqués** par l'absence de tables et de règles métier.
- **Textes fictifs non numériques** (noms de personnes, intitulés, adresses) : non traités automatiquement ; seuls ceux des écrans individuels ci-dessus ont été retirés.
- **Formulaires, validations, états de chargement/vide/erreur** : traités seulement sur les écrans individuels ci-dessus et sur ceux qui l'étaient déjà.
- **Clavier (D-085)** : l'anneau de focus existe sur les zones cliquables ; les listes déroulantes de la recherche avancée (21) n'ont pas été corrigées.
- **Vérification dans un navigateur** : non faite (serveur de développement actuel pointé sur la production par défaut ; à relancer sur la base locale isolée).
