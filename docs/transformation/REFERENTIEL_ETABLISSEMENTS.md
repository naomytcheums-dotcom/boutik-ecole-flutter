# Référentiel des établissements et des départements

Migration : `supabase/migrations/20261104000100_referentiels_profil_documents.sql` (tests : `supabase/tests/referentiels_documents_local.sql`, 24/24 sur la base locale isolée).

## Sources et ce qui est réellement préchargé

| Donnée | Source | État |
|---|---|---|
| Universités d'État (Yaoundé I, Yaoundé II, Douala, Dschang, Buea, Bamenda, Ngaoundéré, Maroua, Bertoua, Ebolowa) | Site officiel du MINESUP, rubrique « Institutions universitaires » (https://www.minesup.gov.cm) | préchargées, statut `verified` |
| Institut universitaire de technologie de Douala | Établissement de l'Université de Douala (contexte du projet) | préchargé, `verified`, **non imposé** à l'étudiant |
| Institutions privées d'enseignement supérieur (IPES) | « Liste des institutions privées d'enseignement supérieur autorisées » publiée par le MINESUP (fichier PDF) | **non préchargées** : le fichier n'a pas pu être consulté ; à importer par un administrateur après lecture |
| Départements / filières | aucune liste officielle exploitable trouvée | **aucun préchargé** ; proposés par les étudiants, validés par l'équipe |

Rien n'est inventé : tout établissement absent de la liste est proposé par la personne (`institution_propose`), visible d'elle seule en attendant la relecture (`reference_review`, rôles admin et support).

## Parcours

1. Compléter le profil : le champ « Établissement » ouvre une fenêtre de recherche (nom, sigle ou ville) alimentée par `institutions_search`.
2. Le champ « Département » dépend de l'établissement choisi (`departments_list`). Référentiel vide : message clair et bouton « Mon département n'est pas dans la liste » (`department_propose`).
3. Le matricule est saisi par l'étudiant dans « Vérification étudiant » ; il reste vide tant qu'il n'est pas renseigné (`profile_set_academic`, jamais généré, format contrôlé côté serveur).

## À faire par l'équipe

- Importer la liste officielle des IPES (PDF MINESUP) comme lignes `institutions` de type `prive`, statut `verified`, `source` renseignée.
- Renseigner les départements des établissements, ou valider les propositions (`reference_review('department', id, true)`).
- Aucune interface d'administration dédiée n'existe encore : la relecture se fait par la fonction serveur.
