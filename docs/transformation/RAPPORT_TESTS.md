# Rapport de tests (03/11/2026, code final du lot 3)

Chaque série a été lancée **en entier, sur le code tel qu'il est commité**, sans fichier exclu, avec un seul processus de test à la fois (`-j 1`).

| Série | Résultat | Détail |
|---|---|---|
| Suite hors rendus de référence (`--exclude-tags golden`) | **1 896 réussis, 0 échoué, 0 ignoré, 0 interrompu** (code de sortie 0) | inclut les deux gros fichiers (`lot1_etats`, `lot2_formulaires`), `test/domain` (22), `coherence_commande_test` (10), `publications_sociales_test` (10), `communautes_test` (6), `plein_ecran_telephone_test` (8), `responsive_tous_ecrans_test` (945 : chaque écran du registre à 360×740, 768×1024 et 1280×800) |
| Rendus de référence (315 écrans) | **315 réussis, 0 échoué** | 306 images régénérées volontairement (couleurs de texte relevées pour le contraste) ; 9 inchangées |
| Serveur : commentaires, enregistrements, partages (`supabase/tests/commentaires_local.sql`) | **29 réussis, 0 échoué** | base locale isolée Docker, appels par SQL avec changement de rôle |
| Serveur : communautés, rôles, modération, notifications (`supabase/tests/communautes_local.sql`) | **62 réussis, 0 échoué** | idem |

## Ce que ces séries prouvent, et ne prouvent pas

- Elles prouvent que chaque écran se compose sans exception aux trois largeurs, que les corrections liées aux commandes, aux publications et aux communautés se comportent comme attendu avec un serveur **simulé**, et que les règles SQL (droits, rôles, bannissement, limites, notifications) tiennent sur la base locale.
- Elles ne prouvent **pas** : le parcours complet du client Flutter contre la base locale (aucune connexion réelle testée), le comportement dans un navigateur, le rendu sur appareil, ni la fidélité visuelle fine (seuls 3 rendus ont été regardés : 42, 46, 103).
- Le test de composition (945 cas) ne vérifie pas le fonctionnement des boutons.
- Les tests serveur passent par SQL, pas par l'interface HTTP de la base.

## Régressions trouvées et corrigées pendant ce lot

1. Une image de produit inconnu (« placeholder ») faisait planter l'écran 09 et la liste de l'écran 29 : repli ajouté (`lineImage`, `_NoImage`).
2. `orders_real_test` attendait l'ancien libellé « ×2 » de l'écran 29 : mis à jour vers « Qté : 2 ».
3. Droit d'exécution manquant pour les visiteurs sur deux fonctions de lecture des communautés (trouvé par les tests serveur).
