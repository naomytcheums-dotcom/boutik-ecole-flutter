# H13 · Audit de `send_live_reminders` (rappels de live)

Migration corrective : `supabase/migrations/20261128020000_h13_live_rappels_audit.sql` (additive : deux `create or replace function`, aucune table touchée).
Test : `supabase/tests/marketplace_pglite/h13_live.mjs` (43 vérifications, PGlite).

## Historique des versions

| Version | Contenu |
|---|---|
| `20261115200200_l10_ateliers_lives.sql` | Création : table `live_reminders` (clé primaire `(live_id, user_id)`, drapeau `notified`), `live_remind_set`, `send_live_reminders`, tâche `pg_cron` `send-live-reminders` toutes les 5 min (si `pg_cron` est disponible). |
| `20261127500000_h12_atelier_reglages_live.sql` | Redéfinition : reprend la version L10 et ajoute le message de notification de l'hôte (`live_settings.notify_message`, 200 caractères maximum, nettoyé des liens à l'écriture). Aucune version H10 (`20261126*`) ne la redéfinit. |
| `20261128020000_h13_live_rappels_audit.sql` | Cette correction. |

## Ancien comportement (conservé)
- Un rappel est envoyé 30 minutes avant l'heure prévue, ou au démarrage du live (statut `live`) ; texte « Un live commence bientôt » / « Le live a commencé » ; notification de type `live_reminder` avec `data.live`.
- Le message de l'hôte est ajouté à la fin du corps.
- Les rappels des lives terminés, annulés ou créés il y a plus de 90 jours sont supprimés.
- Retour : nombre de rappels envoyés.

## Constats de l'audit

| Point | Constat (avant) | Décision |
|---|---|---|
| Permissions | `revoke all … from public, anon, authenticated` : seul le rôle propriétaire (tâche pg_cron) l'exécutait. `service_role` n'avait aucun droit explicite. | Conservé ; `grant execute … to service_role` explicite ; test : visiteur, utilisateur lambda, hôte, administrateur connecté = `permission denied`. |
| Doublons (séquentiel) | Clé primaire `(live_id, user_id)` + `notified` : un rappel par couple. | Conservé, testé (deux appels = 0 le second ; inscription rejouée = pas de ligne de plus). |
| Doublons (concurrence) | **Défaut** : sélection sans verrou ; deux exécutions simultanées (cron + appel manuel) lisaient les mêmes lignes et notifiaient deux fois. | `for update of rm skip locked` : une ligne n'est traitée que par une exécution. Non reproductible dans PGlite (une seule connexion) : garanti par la construction SQL, signalé comme tel. |
| Échec d'une ligne | **Défaut** : une exception (déclencheur sur `notifications`, contrainte) annulait toute la tâche ; aucun rappel ne partait plus tant que la ligne fautive existait. | Bloc `begin … exception` par rappel ; la ligne fautive est close (`notified = true`) avec un `warning`, les autres partent (test F). |
| Live annulé / terminé | Non sélectionné (statut `scheduled` ou `live` seulement) ; lignes supprimées au passage. L'annulation par l'hôte (`live_cancel`) envoie déjà l'avis « Live annulé ». | Conservé, testé. |
| Live programmé jamais démarré | **Défaut** : un live `scheduled` dont l'heure est passée depuis des jours envoyait « commence dans moins de 30 minutes ». | Fenêtre : heure prévue dans les 3 h passées au plus (même seuil que l'agenda) ; au-delà de 1 jour les rappels sont supprimés. Texte « est sur le point de commencer » si l'heure est atteinte sans démarrage. |
| Rappels désactivés | **Défaut** : `reminders_enabled = false` n'était contrôlé qu'à l'inscription (déclencheur `INSERT`) : les inscrits avant la désactivation recevaient quand même le rappel. | `coalesce(s.reminders_enabled, true)` dans la sélection ; réactiver refait partir le rappel (test D1/D1b). |
| Hôte suspendu | **Défaut** : rappel envoyé pour le live d'un hôte suspendu (l'agenda, lui, le masque). | Ignoré. |
| Destinataire suspendu / banni / live privé | **Défaut** : `live_remind_set` n'appliquait pas la règle d'accès des lives ; un compte connaissant l'identifiant d'un live privé recevait une notification contenant son titre. | `_live_access` (même règle que le jeton de direct) dans `live_remind_set` (refus « live privé : rappel impossible sans invitation ») et dans l'envoi (`ok` ou `billet_requis` seulement : le titre d'un live public à billet est public). |
| Message de l'hôte | 200 caractères (contrainte de colonne) ; liens retirés à l'écriture (`_clean_live_title`) ; texte placé dans une notification affichée comme texte brut (aucune interprétation SQL ni HTML : la valeur est un paramètre d'`INSERT`). | Nettoyage refait à l'envoi (au cas où la valeur serait écrite hors RPC), corps borné à 500 caractères. |
| Fuseau horaire | La fonction ne compare que des `timestamptz` (`now()`, `scheduled_at`) : aucun fuseau intervenant. Le texte ne contient pas d'heure. (L'agenda « aujourd'hui » utilise `Africa/Douala`, hors périmètre.) | Rien à corriger. |
| Ordre / limite | `limit 500` sans `order by` : sélection arbitraire. | Ordre par heure prévue puis date d'inscription. |
| Planification | Tâche `pg_cron` créée seulement si l'extension est disponible, sinon simple `notice`. | **À vérifier en production** : `select * from cron.job where jobname = 'send-live-reminders'`. Si absente, aucun rappel ne part (rien de simulé côté application). |

## Effets de bord de la nouvelle version
- Lignes de `live_reminders` des lives `scheduled` dont l'heure a plus d'un jour sont supprimées (elles ne pouvaient plus rien déclencher).
- Un rappel en échec est clos sans notification (journalisé en `warning` PostgreSQL).
- Les rappels de destinataires suspendus, bannis ou sans accès restent en attente jusqu'à la fin du live, puis sont supprimés.
- `live_remind_set` : un nouveau refus pour les lives privés sans invitation ; les autres règles (cinquante rappels actifs, hôte, date à venir) sont inchangées.

## Décision
Version H13 conservée (compatible avec l'ancien comportement pour les cas normaux : live public, rappels actifs, destinataire actif). Aucune décision financière ni tarifaire concernée.
