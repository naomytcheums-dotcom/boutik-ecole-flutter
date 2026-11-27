# H13.1 — Lot J : fiche de décision du Top 100 (pondérations et publication)

> **Statut : rien n'est décidé, rien n'est activé, rien n'est publié.** Production : 0 règle de score active, 0 période, 0 entrée de classement. Aucune donnée fictive n'a été créée en production.

Le détail de la proposition (13 familles, plafonds, seuils) est dans [H13_PROPOSITION_PONDERATIONS_TOP100.md](./H13_PROPOSITION_PONDERATIONS_TOP100.md). Ce document liste **ce que vous devez trancher** et **ce que chaque choix entraîne**. Je n'ai décidé aucune valeur à votre place.

## 1. Décisions à prendre

| # | Décision | Valeur proposée (non appliquée) | Conséquence si vous la changez |
|---|---|---|---|
| J1 | Points par famille d'activité (13 familles) | voir §3 de la proposition | Plus de points sur une famille = plus de poids de cette activité dans le rang. Les familles « sociales » (replays, présence) restent faibles pour que le classement reflète des compétences démontrées. |
| J2 | Plafonds jour / mois par famille | 2 180 points/mois au total | Un plafond bas empêche de dominer par volume ; un plafond haut avantage les très actifs. |
| J3 | Poids qualité `w` | 0,8 sur l'avis vérifié, 0 ailleurs | `w > 0` sur une famille sans qualité mesurée ne fait que réduire ses points. À relever quand une note de mission ou un score d'évaluation existera. |
| J4 | Score minimal cumulé | 50 | Plus haut = moins d'étudiants éligibles, classement plus sélectif. |
| J5 | Activités minimales | 3 | Évite un rang sur une seule action. |
| J6 | Cohorte minimale | 10 (repli du code : 5) | Plus haut = moins d'identification dans un petit groupe ; filières trop petites non publiées. |
| J7 | Nombre d'entrées | 100 | |
| J8 | Portées publiées | national, établissement, filière | Département et domaine plus tard, quand les cohortes sont assez grandes. |
| J9 | Anti-fraude : rafale / répétition | 8 en 10 min ; 3 par auteur en 30 jours | Plus strict = plus de faux positifs à examiner par un humain. |
| J10 | Délai de contestation | 60 jours | |
| J11 | Plafonds distincts par catégorie | non existant (plafonds par famille uniquement) | Fonctionnalité à décider : sinon la limite reste documentée. |
| J12 | Qui publie, à quel rythme | `ranking.publish` + 2FA, mensuel | Une publication ne change plus ; seule une correction auditée est possible. |

## 2. Ce qui est vérifié (local, base propre)

Scénarios rejoués le 27/11 sur une base reconstruite avec toutes les migrations locales :

| Scénario | Résultat |
|---|---|
| `h10_talent.mjs` (suivi des activités, vivier) | 215 OK, 0 échec |
| `h12_top100a.mjs` (règles, points, plafonds, annulation) | 181 OK, 0 échec |
| `h12_top100b.mjs` (anti-fraude, contestations, consentement) | 281 OK, 0 échec |
| `h13_ranking.mjs` (période, publication, explications, correction) | 217 OK, 0 échec |

Ce que ces tests prouvent : sans règle active aucun point n'est attribué et la publication est refusée ; une activité annulée retire exactement ses points ; l'auto-interaction, les comptes liés, la répétition et la rafale sont neutralisés ; la publication respecte le consentement et la cohorte minimale ; l'explication du score et la contestation fonctionnent.

Ce qu'ils ne prouvent pas : le comportement avec de vraies données de production (il n'y en a pas : 0 règle, 0 période) ni l'adéquation des valeurs à votre réalité (c'est la décision J1 à J10).

## 3. Simulation

Aucune simulation n'a été publiée. Les scénarios ci-dessus utilisent des comptes de test **fictifs, dans une base locale jetable** ; ils n'ont jamais été écrits en production et ne seront pas affichés dans l'application. Une prévisualisation sur données réelles n'est possible qu'après activation des règles (point 4 de la procédure d'application de la proposition) ; avec 25 profils et 1 commande, elle donnerait un classement sans valeur statistique.

## 4. Pour avancer

Répondez à J1 à J12 (ou « je valide la proposition telle quelle »). Je préparerai alors `admin_talent_rules_apply_proposal` en brouillon, vous contrôlerez les valeurs dans l'administration, puis l'activation et la première publication restent des gestes de votre part (permissions + 2FA).
