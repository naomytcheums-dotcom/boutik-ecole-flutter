# 07 — Design et responsive

Limites : le comparatif visuel détaillé de chaque écran n'a pas été refait pendant cet audit. Ce document s'appuie sur (a) les mesures automatiques existantes, (b) les écrans consultés dans le navigateur pendant la session (03, 04, 05, 07, 11, 25, 45, 53 sur une instance locale ; écran 11 sur le site déployé), (c) l'analyse du code. Les captures prises pendant la session sont conservées dans le dossier de session de l'outil (non jointes au dépôt).

## Fidélité à la maquette (VÉRIFIÉ, mesure automatique)
Écart moyen par pixel 2,5/255 sur 314 écrans comparés ; 305 sous 6 ; trois écarts élevés (207, 208, 25) expliqués par des données qui remplacent des images de la maquette ; l'écran 125 n'a pas pu être comparé (référence invalide). Les 315 écrans sont fixés par des tests « golden ».

## Incohérences d'interface constatées (VÉRIFIÉ en navigateur sauf mention)
| Réf. | Constat | Priorité |
|---|---|---|
| D-01 | Explorer (04) : pastilles Produit/Service/Projet/Talent de styles et positions différents dans la maquette ; unifiées par le code, rendu final non revu | P3 |
| D-02 | Écran 05 : une image de héros unique quel que soit le produit ; texte de département à vérifier | P3 |
| D-03 | Images de produits parfois chargées après le texte (premier affichage lent) | P2 (lié à AN-018) |
| D-04 | Chat (53) : le champ avait un fond blanc de thème ; corrigé dans le code, non revu | P3 |
| D-05 | Cartes blanches retirées sur tous les écrans mobiles par règle automatique (taille ≥ 150×64, fond clair) : effets de bord possibles non tous contrôlés | P2 |

## Responsive (VÉRIFIÉ par le code, NON VÉRIFIÉ sur appareils)
- Chaque écran est une toile à taille fixe (390 px mobile, 1280 px web, 720×1280 borne) dans un `FittedBox` (`gen.dart`) : l'échelle s'adapte, la mise en page non. Les 71 écrans web deviennent illisibles sur un téléphone (AN-019).
- Les écrans mobiles hauts (> 1 000 px) défilent verticalement ; aucun menu mobile adaptatif.
- Débordement horizontal : aucun défilement horizontal de page, car tout est mis à l'échelle.
- Clavier : `resizeToAvoidBottomInset: false` ; test sur téléphone requis (AN-020).

## Ergonomie et états
- États de chargement : un seul indicateur (barre de démarrage) ; aucun état de chargement pour les appels réseau (paiement : message seulement).
- États vides : présents là où la maquette les prévoit (listes) ; états d'erreur réseau : absents (erreurs avalées, AN-010).
- Confirmations : messages courts (320 px) ; fenêtres de dialogue limitées à 380 px.
- Interactions clavier et libellés d'accessibilité : non vérifiés (AN-021). Les contrastes de textes gris clair sur fond clair sont signalés par l'utilisateur et non mesurés dans cet audit.
- Retour (`gBack`) revient à l'écran précédent, sinon à l'accueil ; onglets du bas par remplacement de pile (`gTab`).

## Problèmes bloquants une tâche (ergonomie réelle)
1. Parcours d'achat impossible à terminer sans compte serveur actif (message « Connectez-vous… »).
2. Écrans de gestion inatteignables par navigation (222 écrans sans lien entrant).
