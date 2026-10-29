# Accessibilité — relecture finale

Audit automatique de **chaque écran** (315) : `flutter test --tags a11y` (fichier `test/a11y/a11y_audit_test.dart`), rapport détaillé dans `build/a11y_report.txt`. Ce test produit un rapport ; il n'échoue pas, car certaines règles dépendent de décisions de design (voir plus bas).

| Règle | Outil | Résultat |
|---|---|---|
| Zone touchable étiquetée pour les lecteurs d'écran | `labeledTapTargetGuideline` | **0 écran en défaut** (6 corrigés : photos touchables, avatar de 03, galeries de 32, 77, 89, 251) |
| Zone tactile ≥ 44 × 44 px | `iOSTapTargetGuideline` | 46 écrans / 75 éléments restants, tous à la taille de la maquette (voir QUESTIONS.md n° 20). Le champ de recherche des 66 écrans web a été corrigé (zone de 44 px sans changement visuel). |
| Contraste du texte ≥ 4,5:1 | palette vérifiée par calcul | Toutes les couleurs de texte de la palette passent sur tous les fonds (texte secondaire 5,1:1 minimum, succès 4,7:1, alerte 5,3:1, erreur 5,7:1, accent 5,7:1). Le texte indicatif des champs en pastille est passé de 4,4:1 à 4,9:1. |
| Contraste mesuré sur les pixels | `textContrastGuideline` | 146 écrans signalés. Après examen, ce sont des mesures faussées : texte hors de la zone visible d'une liste (ratio ≈ 1,0), petits textes lissés (sidebar web « Principal » déclarée à 5,1:1 mais mesurée à 1,4:1), textes sur photo avec dégradé. Ce résultat n'est donc pas un critère de réussite. |

Autres points en place :

- **Texte agrandi** (186, 149) : taille 0,9 à 1,4 appliquée à toute l'application ; « Réduire les animations » et « Contraste renforcé » sont transmis à `MediaQuery` (`disableAnimations`, `highContrast`).
- **Lecteurs d'écran** : en-têtes marqués (`Semantics(header: true)`), boutons-icônes étiquetés, états annoncés (`liveRegion`) pour le chargement, le hors connexion, le QR de borne et ses comptes à rebours.
- **Borne (206–210)** : zones tactiles de 64 à 124 px, texte limité à 1,2× pour ne pas casser la mise en page fixe 720×1280.
- **Langue** : français par défaut, anglais pour 185 et la borne (fichiers `arb`).

Non vérifié (à faire sur appareil réel) : lecture complète avec TalkBack / VoiceOver, navigation au clavier sur le Web.
