# 04 — Phase 4, lot 2 : les 19 écrans dont les champs n'étaient reliés à rien

Date : 01/11/2026. Commit local **`d79cca1`** (non poussé). Aucune migration, aucune modification de la production.

## A. Constat

Sur les 19 écrans, l'essentiel des champs sont des **recherches**. La recherche d'en-tête du back-office (« Rechercher données, rapports, produits… ») était inerte sur **63 écrans web**, et pas seulement sur les 9 écrans du lot.

Trois vrais formulaires n'ont pas de modèle de données : 18c, 41 et 168.

Découverte en chemin : les journaux d'audit 126 et 137 affichaient **8 entrées fictives même avec le serveur**.

## B. Raccordements

| Écran(s) | Avant | Après | Preuve |
|---|---|---|---|
| 63 écrans web du back-office (108 à 145, 147-x, 168, 169, 180, 181, 187 à 190, 198 à 200, 213, 239, 262 à 269, D1) | champ sans action | Validation de la saisie : liste des **pages autorisées au rôle** dont le titre correspond, plus « Rechercher dans le catalogue » (22). Sans résultat, cela est indiqué. La règle est ajoutée à `convert.py`, si bien qu'une régénération produit la même liaison. | 3 tests et 63 golden images identiques |
| 126, 137 Journaux d'audit | champ sans action ; `auditQueryProvider` n'était renseigné par aucun écran | La saisie filtre réellement le journal. Les entrées d'exemple n'apparaissent plus quand un serveur est joint. | 2 tests |
| 182 Explorer (chargement), 251 Découvrir | champ sans action | Recherche dans le catalogue (22), comme l'écran 19 | golden images identiques ; aucun test fonctionnel |
| 188 Recherche de talents | champ sans action | Recherche de talents (70, `talentQueryProvider`) | golden image identique ; aucun test fonctionnel |
| 40 Demande de devis | Champs sans enregistrement, valeurs d'exemple pré-remplies, et bouton qui ouvrait **le panier sans rien envoyer** | Saisie enregistrée. Si un service est consulté, envoi réel par `request_quote` (mêmes règles que 95b). Sinon, une explication s'affiche et **rien n'est envoyé**. Plus de valeurs d'exemple en mode connecté. | 2 tests |

## C. Non raccordés, avec leur motif

| Écran | Motif |
|---|---|
| 18c Vérification étudiant | Matricule, niveau et pièces justificatives : **aucune colonne ni aucun stockage privé**. `request_certification` ne prend aucun paramètre. Migration à préparer et tester sur la réplique. |
| 41 Adresse de livraison | **Aucune table d'adresses** ; votre décision sur la livraison à domicile est attendue |
| 168 Publier un concours | **Aucune table de concours** (lot concours, règles attendues) |
| 49 Aide, 52 Messages, 25b Mes collections, 104 Carte, 179 Guide | Recherches locales qui exigent de filtrer la liste affichée par chaque écran. À traiter avec le remplacement des données de maquette de ces écrans (lots 5 à 9). |

## D. Tests (tous locaux)

| Test | Résultat |
|---|---|
| `lot2_formulaires_test` (6 nouveaux) | **6/6**, après correction de 2 erreurs dans mes propres tests : l'écran 82 « Journal du projet » est légitimement ouvert à tous, et le toucher visait mal le bouton |
| `lot1_etats_test` (non-régression) | 9/9 |
| Golden images : 63 écrans du back-office, plus 40, 182 et 251 | **66/66 identiques** |
| `flutter analyze` sur les fichiers modifiés à la main | **aucun problème** |

**Aucune vérification en production** : le site n'est pas redéployé.

## E. Matrice après les phases 3 et 4

| Statut | Départ (phase 0) | Maintenant |
|---|---|---|
| CONNECTÉ ET FONCTIONNEL (preuve locale) | 9 | **15** |
| CONNECTÉ MAIS PARTIEL | 34 | 34 |
| NON VÉRIFIÉ | 112 | 120 |
| DONNÉES FICTIVES | 128 | 128 |
| ACCESSIBLE MAIS NON FONCTIONNEL | 19 | **5** |
| BLOQUÉ PAR UNE DÉPENDANCE | 6 | 11 |
| ORPHELIN | 4 | **1** |
| DOUBLON | 3 | **1** |
