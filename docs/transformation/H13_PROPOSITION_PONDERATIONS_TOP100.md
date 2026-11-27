# H13 — Proposition de pondérations initiales du score de talent (Top 100)

> **Statut : PROPOSITION, non appliquée par défaut.** Le propriétaire décide. Rien n'est activé, rien n'est publié, aucun classement n'existe. La RPC `admin_talent_rules_apply_proposal` enregistre ces valeurs **en brouillon (`active = false`)** : tant qu'une règle n'est pas activée par `admin_talent_rule_set`, elle n'attribue aucun point, et `ranking_publish` refuse (« Aucune règle de score active »).

Source de vérité : la fonction SQL `_talent_rules_proposal()` (migration `20261128010100`), lisible via `admin_talent_rules_proposal()` (permission `ranking.rules`). Ce document en est le commentaire.

## 1. Principes

1. **La qualité et la réalisation vérifiée comptent plus que la popularité.** Il n'existe aucune règle pour les vues, les likes, les abonnés : ils ne peuvent pas produire de points. Les familles les mieux dotées sont celles qui reposent sur une validation humaine ou un justificatif vérifiable (évaluation validée, mission validée, certificat, projet approuvé avec preuves).
2. **Plafonds par famille, jour et mois** : aucune famille ne peut dominer. Le plafond d'une catégorie est la somme des plafonds mensuels de ses familles (tableau 3). Le moteur applique des plafonds **par famille** ; il n'existe pas de plafond de catégorie distinct (limite connue).
3. **Poids qualité uniquement là où la qualité est mesurée.** Formule serveur : `points attribués = points × ((1 − w) + w × qualité)`, qualité dans [0, 1], une qualité non mesurée valant 0. Aujourd'hui, seul l'avis vérifié porte une qualité réelle (note 1 à 5 → `(note − 1) / 4`). Mettre `w > 0` sur une famille sans qualité mesurée ne ferait que réduire ses points : la proposition laisse donc `w = 0` partout sauf pour `review_verified` (0,8). Quand une qualité sera mesurée pour d'autres familles (note de mission, score d'évaluation), le propriétaire pourra relever `w`.
4. **Équité entre filières.** Les points par activité sont identiques quelle que soit la filière ; la comparaison se fait par cohorte (centiles par filière, établissement, national, cohorte minimale) et le classement des établissements se fait par **points moyens par étudiant vérifié**, jamais par effectif seul.
5. **Anti-manipulation.** Activité neutralisée (0 point, alerte, réversible par un humain) pour auto-interaction, comptes liés (même matricule ou même e-mail à l'alias près), répétition d'un même auteur, rafale ; plafonds du jour qui empêchent de contourner par annulation/réactivation ; toute activité annulée (remboursement, révocation, suppression) retire exactement ses points.

## 2. Hypothèse d'échelle

Le plafond mensuel total proposé est de **2 180 points** (somme du tableau 3) ; il ne sera presque jamais atteint. Un étudiant actif réaliste (1 mission validée, 1 certificat, quelques ventes, des replays) se situe autour de 150 à 400 points par mois. Les seuils (section 4) sont exprimés dans cette échelle.

## 3. Tableau par famille

`Plafond jour / mois` = `cap_per_day` / `cap_per_period` (points, jour UTC, mois civil). `w` = poids qualité.

| Famille (code) | Catégorie | Points | Plafond jour | Plafond mois | w | Justification |
|---|---|---:|---:|---:|---:|---|
| `assessment_validated` | Réalisation | 120 | 120 | 360 | 0 | Évaluation validée par un humain : preuve de compétence la plus fiable. |
| `mission_validated` | Réalisation | 100 | 200 | 400 | 0 | Mission réalisée et validée par le client. |
| `certificate_verified` | Réalisation | 80 | 80 | 240 | 0 | Certificat émis et non révoqué, vérifiable par son code. |
| `project_published_with_proof` | Réalisation | 70 | 70 | 210 | 0 | Projet approuvé avec preuves. |
| `sale_confirmed` | Réalisation | 30 | 60 | 240 | 0 | Vente payée et non remboursée ; plafonnée car plus facile à simuler. |
| `skill_demonstrated` | Compétence | 50 | 50 | 150 | 0 | Compétence adossée à un justificatif vérifié par un humain. |
| `collaboration` | Compétence | 40 | 40 | 120 | 0 | Projet approuvé réalisé à plusieurs étudiants réels. |
| `badge_verified` | Compétence | 15 | 15 | 45 | 0 | Badge adossé à un replay réellement terminé. |
| `live_hosted` | Engagement | 40 | 40 | 120 | 0 | Live réellement animé avec au moins un participant réel. |
| `challenge_participation` | Engagement | 25 | 25 | 75 | 0 | Participation effective, sans valoriser le résultat. |
| `review_verified` | Engagement | 20 | 40 | 120 | **0,8** | Avis lié à un achat réel : la note pèse 80 % des points. |
| `replay_completed_100` | Engagement | 10 | 20 | 60 | 0 | Consommation (progression serveur) : faible poids. |
| `event_attended` | Engagement | 10 | 10 | 40 | 0 | Présence prouvée par le code de l'organisateur : faible poids. |

Plafonds mensuels par catégorie (somme) : **Réalisation 1 450** (≈ 66 %), **Compétence 315** (≈ 14 %), **Engagement 415** (≈ 19 %). La réalisation vérifiée domine ; l'engagement (la partie la plus « sociale ») reste sous 20 %.

## 4. Seuils proposés (non écrits par la RPC)

Ces valeurs relèvent de réglages distincts que le propriétaire saisit lui-même.

| Réglage | Proposé | Où le saisir | Justification |
|---|---:|---|---|
| Seuil minimal de score cumulé | 50 | `admin_ranking_settings_set` (`p_min_score`) | Au moins une activité réelle significative avant d'être classé. |
| Seuil d'activité (activités confirmées) | 3 | `admin_ranking_settings_set` (`p_min_activities`) | Évite un classement sur une seule action. |
| Nombre d'entrées par classement | 100 | `admin_ranking_settings_set` (`p_entries_limit`) | « Top 100 ». |
| Portées publiées | national, établissement, filière | `admin_ranking_settings_set` (`p_scopes`) | Département et domaine pourront être ajoutés quand les cohortes seront assez grandes. |
| Cohorte minimale (`min_cohort`) | 10 | `admin_talent_setting_set` | Évite d'identifier un étudiant dans un petit groupe (repli actuel du code : 5). |
| Rafale (`burst_count` / `burst_minutes`) | 8 activités / 10 min | `admin_talent_setting_set` | Repli actuel : 10 / 10. |
| Répétition d'un auteur (`actor_repeat`) | 3 / 30 jours | `admin_talent_setting_set` | Inchangé. |
| Délai de contestation (`dispute_days`) | 60 jours | `admin_talent_setting_set` | Ajouté par H13 ; repli technique 60. |

## 5. Procédure d'application (par le propriétaire)

1. Relire ce tableau et `admin_talent_rules_proposal()` (colonne `differs`).
2. `admin_talent_rules_apply_proposal(motif)` — permission `ranking.rules` + 2FA : enregistre les valeurs **en brouillon** (versionnées dans `talent_score_rule_history`, auditées). Refuse si une règle est déjà active ou si un classement est déjà publié.
3. Ajuster famille par famille avec `admin_talent_rule_set` ; saisir les seuils (section 4).
4. Activer les règles retenues (`active = true`) : à partir de là seulement, de nouveaux points sont attribués ; `admin_talent_recompute` peut attribuer les activités déjà tracées.
5. `admin_ranking_readiness(période)` puis `ranking_publish(période)` (permission `ranking.publish`). Une publication ne change plus ; seule une correction auditée est possible.

## 6. Ce qui n'est pas décidé

Valeurs définitives, activation, seuils, publication, plafonds de catégorie distincts, poids qualité des familles sans mesure de qualité. Aucune donnée fictive n'est créée par la proposition.
