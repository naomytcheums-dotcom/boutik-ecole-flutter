# Lot 4 — Concours réels (écrans 160 à 169)

Date : 01/11/2026. Commit local **`5877085`** (non poussé). Migration locale **`20261101000200_concours.sql`**, **non appliquée en production**. Règles : `REGLES_METIER_PROPOSEES.md` § 1.

## A. Constat initial
- Il n'existait **aucune table de concours** : seulement `hackathon_teams` (vide).
- Les écrans affichaient 4 concours, un classement et des équipes **d'exemple**, codés en dur.
- En mode connecté, le dépôt, la notation et les invitations répondaient « indisponible », et l'inscription n'était qu'un engagement générique.

## B. Serveur (migration locale)

| Élément | Contenu |
|---|---|
| Tables | `contests`, `contest_teams`, `contest_members`, `contest_submissions`, `contest_jurors`, `contest_scores` |
| Droits | RLS en **lecture seule**. Toute écriture passe par 9 fonctions. Les dépôts sont visibles de l'équipe, du jury (une fois soumis) et du département. Les notes sont visibles du juré, du département, et de l'équipe après les résultats. |
| `save_contest` | Département ou administrateur. Après publication, les dates ne peuvent qu'être prolongées, la dotation et les places qu'augmentées. Action journalisée. |
| `set_contest_status` | publié → jury (seulement après la clôture des dépôts) → résultats (seulement si **chaque projet a au moins 2 notes**). Annulation possible. Membres notifiés. |
| `register_contest_team` | Étudiants seulement. Règlement obligatoire, places, échéance, une équipe par étudiant et par concours. |
| `invite_contest_member`, `answer_contest_invite` | Capitaine seulement ; 5 membres au plus ; acceptation par l'invité |
| `submit_contest_project` | Capitaine seulement, avant l'échéance. Originalité certifiée. Brouillon possible ; verrouillé après soumission. |
| `assign_contest_juror`, `score_contest_submission` | Jurés désignés. 4 critères sur 10. Conflit d'intérêts refusé. Notation seulement pendant la délibération. |
| `contest_ranking` | Moyenne des jurés, départage par Innovation puis Impact puis heure du dépôt. Caché avant publication, sauf pour le jury et le département. Équipes écartées exclues. |
| `moderate_contest_team` | Motif obligatoire, capitaine notifié, action journalisée |

**Tests sur la réplique (transaction annulée) : 38/38.** Ils couvrent les rôles, les places, l'échéance, le capitaine, les jurés, le conflit d'intérêts, les notes hors bornes, les résultats incomplets, le classement exact (31,00 contre 25,50), les notifications, la modération, l'écriture directe refusée, et la réplique inchangée après annulation.

## C. Client

| Écran | Avec le serveur |
|---|---|
| 160, 161 | Concours du serveur. « Aucun concours publié pour le moment » s'il n'y en a pas. Places restantes réelles. |
| 162 | Inscription réelle |
| 163 | Invitation réelle par e-mail. **Reste** : l'annuaire de coéquipiers affiché vient de la maquette. |
| 164 | **Reste** : les membres affichés viennent de la maquette |
| 165 | Dépôt réel par le capitaine, avec confirmation d'originalité |
| 166 | Classement réel |
| 167 | Le juré choisit le projet, puis la note est enregistrée par le serveur |
| 168 | « Soumettre pour validation » ouvre la vraie publication. Les champs absents de l'écran sont demandés dans la boîte de dialogue. |
| 169 | Modération réelle du concours sélectionné. **Reste** : le tableau affiché vient de la maquette. |

Hors serveur, la maquette est inchangée : golden images identiques.

## D. Tests
- 5 nouveaux tests Flutter.
- 2 tests de la finalisation précédente adaptés : ils vérifiaient l'ancien message « indisponible ». L'intention « aucun envoi ni succès simulé » est conservée.
- **Suite complète : 453/453.**

## E. Hors production
- Rien n'est appliqué en production.
- Il faudra appliquer `20261101000000` puis `20261101000100` puis `20261101000200`, après votre autorisation, puis redéployer le site.
