# Questions sur les maquettes et l'environnement

Chaque question indique l'écran concerné, la solution retenue en attendant la réponse, et ce qu'il faudrait pour trancher.

## Outillage

1. **Serveur MCP Figma indisponible dans la session de développement.** Les outils `get_design_context` et `get_screenshot` n'étaient pas exposés. Contournement : le fichier étant partagé publiquement, les 315 écrans ont été capturés depuis le visualiseur de prototype Figma (`tool/capture_figma.js`, 2x) puis recadrés (`tool/crop_shots.py`). Les valeurs (textes, couleurs, tailles) sont relevées sur ces captures, pas sur les propriétés exactes des calques.
   → Activer le MCP Figma (ou fournir un jeton d'accès Figma) pour relire les valeurs exactes et les interactions de prototype.
2. **Interactions de prototype (navigation) non lisibles sans le MCP.** La navigation a été déduite des libellés (ex. « Voir la facture » ouvre l'écran 260). Les cibles qui ne sont pas encore codées affichent l'écran « introuvable », jusqu'à ce que leur section soit faite.
   → Faut-il suivre exactement les liens de prototype ? Si oui, il faut l'export des interactions.
3. **Icônes « chrome ».** Les nœuds `icon/…` n'ont pas pu être exportés sans accès API. Solution provisoire : icônes au trait (Lucide, licence ISC) dans `assets/icons/`, et effet métal approché par un dégradé (`ChromeIcon`) pour les grandes illustrations.
   → Exporter les nœuds `icon/…` en PNG 3x / SVG dans `assets/icons/chrome/`.
4. **Photos.** Les photos viennent des captures, donc en basse résolution (≈ 400 px). → Fournir les originaux.

## Section « Nouveaux écrans »

5. **Barre d'état et Dynamic Island** (« 9:41 ») : ce sont des éléments du cadre iPhone de la maquette, ils ne sont pas reproduits (l'OS les affiche).
6. **258 · Espèces au kiosque** : la pastille affiche « € » alors que la monnaie est le FCFA. Je reproduis la maquette telle quelle. → Remplacer par « F » ou une icône de billet ?
7. **284 · Taxes** : « TVA 19,25 % = 53 280 FCFA » ne correspond ni à 19,25 % du brut (63 525) ni du brut moins les frais (62 572). Les montants de la maquette sont repris tels quels dans les données de démonstration ; le net et la ventilation 70/20/10 sont recalculés par le code (même résultat que la maquette). → Préciser l'assiette de la TVA.
8. **284 / 260 · Ventilation** : la facture 260 répartit sur le montant brut, le registre 284 sur le net après frais et taxes. → Quelle base fait foi ?
9. **272 · Après vérification** : la maquette ne dit pas où mène « Vérifier ». Retenu : tableau de bord de l'administration institutionnelle (117).
10. **250b · Boutons du haut** (« Publier », « Modifier », « Couverture ») : ils mesurent environ 30 px de haut dans la maquette ; leur zone tactile est portée à 44 px (règle d'accessibilité), sans changer leur apparence.
11. **288 · Barre latérale sans icônes** : contrairement aux écrans 262 à 269, la maquette 288 n'a pas d'icônes dans la barre latérale ; le composant commun `WebShell` les affiche. → Uniformiser dans un sens ou dans l'autre ?
