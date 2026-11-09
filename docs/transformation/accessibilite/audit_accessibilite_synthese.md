# Synthèse accessibilité — Boutik-École (qualification, après correction)

Méthode : Flutter Accessibility Guideline API (androidTapTargetGuideline 48 dp, labeledTapTargetGuideline, textContrastGuideline WCAG AA 4,5:1), écrans ouverts en mode connecté à 412 × 915, contraste mesuré à 3 pixels par point (résolution d'un téléphone). Aucune certification n'est revendiquée : mesure automatisée, sans lecteur d'écran réel.

## Mobile (244 écrans)
| Mesure | Avant | Après |
|---|---|---|
| Zones tactiles < 48 dp | 1349 | 248 (sur 81 écrans) |
| Éléments tactiles sans libellé TalkBack | 1530 | 21 |
| Contrastes insuffisants | 130 | 0 |
| Débordements à 150 % / 200 % (7 écrans signalés) | 7 écrans | 0 |

Contrastes : les 130 signalements « avant » venaient d'une mesure à 1 pixel par point (le texte fin y paraît gris clair : un texte `111015` était mesuré `AAAAAB`). À 3 pixels par point il n'en reste aucun. Un seul défaut réel : rouge d'état `E5484D` en petit texte (2,61:1), remplacé par `B42318`. Le gris secondaire `57545F` des textes ≤ 14 px passe à `4A4854` (même teinte, un cran plus foncé).

Libellés : « Bouton » n'existe plus ; chaque zone prend son texte, le texte voisin, un rôle selon sa place (Retour, Options, Onglet de navigation n sur m) ou « Ouvrir : … » ; les doublons sont numérotés (« … 2 sur 4 »). Interrupteurs, champs et pastilles portent un libellé ; les pastilles exposent leur état sélectionné.

Zones tactiles : anneau invisible qui porte la zone à 48 dp sans changer l'apparence, jamais au-dessus d'une autre zone distincte (zones imbriquées traitées comme un seul bouton) ; interrupteurs et pastilles agrandis dans leur composant. Reste 248 zones : surtout des liens texte de 17–18 dp de haut serrés contre leurs voisins, qu'on ne peut agrandir sans recouvrir une zone voisine.

Polices agrandies : 7 écrans en exception (261, 148-1, 149, 173, 100, 225, 226) corrigés sans désactiver la mise à l'échelle (colonnes défilantes au lieu de déborder ; bandeau des jours réduit à l'échelle).

## Pourquoi 244 écrans « mobile » sur 315
Le registre compte 315 écrans ; l'audit mobile ne couvre que ceux dessinés pour téléphone (390 de large). Les 71 autres sont classés :
| Catégorie | Écrans | Remarque |
|---|---|---|
| Console web (1272–1280 px) | 64 | consoles d'administration, finance, exploitation, entreprise ; mesurés à leur largeur, libellés ajoutés, anneaux 48 dp non appliqués (usage souris/clavier) |
| Tablette (720–768 px) | 6 | |
| Borne (1500 px) | 1 | écran D1 |
Mesure de ces 71 écrans : zones < 48 dp 824 (non corrigées : cibles souris), sans libellé 5, contraste 0, débordements 0.

## Reste à faire / limites
- 248 zones < 48 dp et 21 éléments sans libellé sur mobile ; consoles web non adaptées au tactile.
- Aucun test avec TalkBack réel sur téléphone ; mesure automatisée uniquement.
- Captures de référence régénérées (écart moyen 0,67 % de pixels : gris de texte plus foncé).
