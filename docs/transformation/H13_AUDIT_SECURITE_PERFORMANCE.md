# H13 · Audit de sécurité et de performance (lot Administration)

Périmètre : base Supabase (schéma `public`), RPC d'administration, journal d'audit, limites de débit, santé des services, exports. Méthode : le scénario
`supabase/tests/marketplace_pglite/h13_audit.mjs` rejoue **toutes** les migrations (schema.sql + 316 fichiers au moment de l'audit) sur PGlite, interroge le catalogue
PostgreSQL et exécute les cas autorisés **et** refusés. Les lignes `CONSTAT` sont l'état mesuré ; les lignes `OK / ECHEC` sont des assertions (132 OK, 0 ECHEC).
Commande : `cd supabase/tests/marketplace_pglite && node replay.mjs all ./h13_audit.mjs` (le code de sortie est toujours 0 : compter les lignes `ECHEC` / `ERREUR`).

Limites de la méthode (à ne pas surévaluer) : PGlite n'est pas Supabase (pas de PostgREST, pas de GoTrue : `auth.sessions` est un substitut) ; les droits par défaut de Supabase
(exécution accordée à `anon`/`authenticated` sur toute nouvelle fonction) sont reproduits par le banc. Rien n'a été exécuté contre la production.

## 1. Constats et état après correction

| # | Contrôle | Constat mesuré | Action | État |
|---|---|---|---|---|
| A1 | RLS sur toutes les tables | 356 tables, **0 sans RLS** | aucune | conforme |
| A1b | Politiques d'écriture sans condition | aucune (`using true`), aucune ciblant `anon` | aucune | conforme |
| A1c | Lecture sans condition | 14 tables : catalogues, avis, bornes publiques, `live_comments` (table héritée) | liste relue et figée dans le test | conforme, documenté |
| A2 | `SECURITY DEFINER` sans `search_path` | 1 550 fonctions, **0 sans** | aucune | conforme |
| A3 | Fonctions exécutables par `anon` | 234 : 26 déclencheurs, 37 pgcrypto, 39 assistants de politiques (préfixe `_`), **132 RPC publiques** | liste blanche (§2) ; tout ajout fait échouer le test | conforme |
| A3 | RPC publiques qui écrivent | 5 (`kiosk_*` ×3 gardées par jeton d'appareil ; `record_view`, `ann_detail` : compte connecté exigé avant toute écriture) | test de comportement visiteur | conforme |
| A4 | Fonctions de service (Edge) exécutables par `anon`/`authenticated` | 24 fonctions appelées par les fonctions Edge : aucune ouverte ; `service_role` peut les exécuter | assertion sur chaque nom + sur tout droit explicite `service_role` | conforme (exceptions §3) |
| A5 | Clés étrangères sans index | **354 sur 672** au moment de l'exploration (673 FK au final, autres lots inclus) | migration `20261128070200` : 380 index `fkix_*` | corrigé |
| A6 | RPC `admin_*` | 51 RPC ; un client simple est refusé sur chacune (comportement testé) ; aucune ouverte à `anon` | aucune | conforme |
| A6 | Actions d'administration/finance **sans ligne de journal** | 16 : moteur de commission, répartition des paiements, remboursement d'un prix d'annonce, virement Mobile Money préparé, décisions d'annonces/offres/réalisations/communautés, réussites, barème de parrainage, contenus et catégories, réinitialisation 2FA par e-mail, suppressions de compte, droits d'équipe | enveloppes `_au_<nom>` (migration `20261128070100`) | corrigé |
| B | `audit_log` | RLS correcte (lecture admin/équipes, aucune politique d'écriture) **mais** droits `INSERT/UPDATE/DELETE` accordés à `authenticated` et `SELECT` à `anon` | droits retirés + journal **en ajout seul** (déclencheurs) | corrigé |
| G | `kiosk_sessions` (table héritée, supplantée par `kiosk_pairings`) | lisible (codes) et modifiable (« utilisé ») par tout compte connecté | trois politiques retirées, table fermée | corrigé |
| G | `live_comments` (héritée, rattachée à `scheduled_lives`, sans notion de visibilité, aucune référence côté application) | lecture publique | **conservée** (une politique fondée sur `_live_can_read` serait fausse : cette fonction vise la table `lives`). Le chat des lives actuels (`live_messages`) est déjà protégé | accepté, à supprimer au prochain nettoyage |
| F | Suspension d'un compte | seule `admin_set_account` fermait les sessions | déclencheur sur `profiles.suspended` : blocage + fermeture des sessions **quel que soit le chemin** ; `admin_account_sessions_revoke` | corrigé |
| C | Limites de débit des RPC publiques coûteuses | aucune | 30 RPC limitées (§4) | corrigé |

## 2. Liste blanche des RPC ouvertes aux visiteurs (`anon`)

Relues : `SECURITY DEFINER`, filtrage par statut/visibilité/compte, aucune donnée privée. Toute RPC ajoutée à cette liste sans relecture fait échouer `h13_audit.mjs` (assertion A3).

Vérifications par code (anti-énumération, limitées en débit) : `verify_certificate`, `verify_certificate_public`, `ranking_verify_hash`, `replay_certificate_verify`, `passport_token_verify`, `qr_resolve_public`, `project_proof_verify`, `shared_cv`, `dept_invite_info`, `promo_preview`.

Listes et fiches publiques : `top100_national`, `top100_by_domain`, `top100_by_institution`, `top100_by_department`, `top100_by_program`, `ranking_history`, `ranking_institution_history`, `ranking_institutions_public`, `ranking_explain`,
`talents_new`, `talents_rising`, `talents_most_viewed_by_companies`, `talent_public_profile`, `talent_passport`, `public_profile`, `public_projects`, `public_project_get`, `public_sellers`, `seller_public`, `shop_public`, `marketplace_search`, `marketplace_shops`,
`product_detail`, `product_extras`, `product_reviews`, `product_digital_info`, `listing_variants_public`, `listing_rating`, `listings_other_institutions`, `showcase_listings`, `trending_products`, `active_auto_promo`, `flash_sales_active`, `delivery_quote`, `campaigns_overview`,
`anns_list`, `ann_detail`, `ann_wins_list`, `opps_list`, `opp_detail`, `opp_hired_list`, `recommended_offers`, `wishes_market`, `wish_get`, `mentors_list`, `mentor_detail`, `mentor_stories`, `communities_list`, `community_feed`, `community_events_list`, `community_images`,
`community_levels`, `community_qa`, `circle_feed`, `circle_feed_page`, `reels_feed`, `author_posts`, `post_counters`, `post_comment_list`, `post_comment_list_v2`, `post_shop_target`, `creator_pins_list`, `creator_profile_tabs`, `creator_tab_items`, `creators_suggested`,
`stories_active`, `duels_list`, `victories_list`, `top_helpers`, `follow_stats`, `lives_now`, `lives_agenda`, `lives_atelier_extras`, `live_get`, `live_settings_get`, `live_can_join`, `replay_library`, `replay_detail`, `replay_search`, `replay_hosts_directory`, `replay_share_info`,
`replay_quiz_can_edit`, `events_between`, `events_upcoming`, `departments_list`, `department_detail`, `institutions_search`, `iut_projects`, `company_public`, `provider_card`, `profile_in_directory`, `profile_links_public`, `profile_imported_items`, `profile_verified`,
`profile_visible`, `platform_impact`, `skills_list`, `suggest_districts`, `mate_categories_list`, `org_types_list`, `author_shop_slug`.

Utilitaires purs : `certificate_canonical`, `certificate_content_hash`, `chat_file_allowed`, `momo_normalize`, `normalize_msisdn`, `notification_category`, `offer_type_of`, `point_level`, `user_level`, `current_role_name`, `is_participant`, `is_mission_participant`,
`is_community_member`, `is_contest_staff`, `is_platform_staff`.

Écrivent (gardées) : `record_view` et `ann_detail` (sans compte connecté : aucune écriture, testé), `kiosk_heartbeat`, `kiosk_pair_issue`, `kiosk_pair_revoke`, `kiosk_pair_status` (jeton d'appareil exigé : « Borne non autorisée », testé).

Hors liste mais exécutables par `anon`, volontairement : 26 fonctions de déclencheurs (non appelables directement), 37 fonctions pgcrypto (extension installée dans `public` : avertissement connu de Supabase, sans impact tant qu'aucune donnée n'est exposée par ces fonctions) et 39 assistants de politiques RLS préfixés `_` (nécessaires à l'évaluation des politiques pour les visiteurs ; le test vérifie qu'aucun n'écrit en base).

## 3. Fonctions de service (clé `service_role` des fonctions Edge)

Fermées à `anon` **et** `authenticated` (assertion A4 ; appel direct par un client → `permission denied`) : `assessment_dispatch_*` (accepted, claim, failed, provider_failed, result), `assessment_provider_health_report`, `dispatch_key_check`, `dispatch_claim`,
`auth_revoke_sessions`, `auth_throttle_check/clear/hit`, `phone_verify_apply`, `live_recording_egress_*`, `live_recording_start_check/stop_check/declare_track/mark_ready`, `live_access_for`, `translate_store`, `ai_action_record_result`, `grant_credits`, `replay_clip_mark`,
`replay_transcript_store`, `transcription_job_ack`, `send_live_reminders`.

Exceptions documentées : `live_recording_enabled()` (indicateur booléen, sans secret) ; `enforce_mfa_on_sensitive()` (garde de requête PostgREST `db_pre_request` : 2FA et comptes suspendus ; doit être exécutable par tous les rôles).
Non couvert par ce test : le contrôle interne de chaque fonction Edge (en-têtes, secrets) — voir les tests des fonctions Edge (`supabase/functions/**/logic.test.mjs`).

## 4. Limites de débit (`20261128070000`, `20261128070500`)

Mécanisme : `_rpc_throttle(rpc)` compte les appels dans `auth_throttle` (clé `rpc:<nom>:<client>`). Client = compte connecté, sinon adresse IP transmise par la passerelle (`cf-connecting-ip`, `x-real-ip`, premier `x-forwarded-for`), sinon clé commune.
Dépassement : erreur `P0429` « Trop de requêtes : réessayez dans un instant ». **Une panne du compteur n'empêche jamais l'appel** (ouvert en cas de panne, testé). Les refus ne sont pas comptés.
Tables : `rpc_rate_limits` (fermée) ; lecture `admin_rpc_rate_limits_list()` (tech.config, tech.maintenance ou tech.logs) ; réglage `admin_rpc_rate_limit_set(...)` (tech.config, motif obligatoire, journalisé).
Pour chaque RPC limitée, la fonction d'origine est renommée `_rl_<nom>` (jamais supprimée, droits d'exécution retirés) et une enveloppe du même nom, de même signature et mêmes droits, applique la limite.
**Conséquence de maintenance** : pour corriger le corps d'une fonction limitée (ou auditée, `_au_<nom>`), modifier `_rl_<nom>` / `_au_<nom>`, pas l'enveloppe. Pour retirer une limite : `admin_rpc_rate_limit_set(..., enabled=false)`.

| Limite (par client) | RPC |
|---|---|
| 60 / min (plafond global 3 000 / min) | `verify_certificate`, `verify_certificate_public`, `ranking_verify_hash`, `replay_certificate_verify`, `passport_token_verify`, `qr_resolve_public`, `project_proof_verify`, `dept_invite_info`, `promo_preview` |
| 120 / min (plafond global 6 000) | `shared_cv` |
| 300–600 / min | Top 100 (5 listes), historiques de classement, talents (3 listes), `public_projects`, `marketplace_search`, `marketplace_shops`, `replay_search`, `institutions_search`, `talent_public_profile`, `delivery_quote` (120) |
| 5 / heure | `export_my_data` (export complet des données personnelles) |
| 20 / heure | `pool_export`, `admin_export_csv` |

Les valeurs sont volontairement larges (réseaux d'établissement partagés derrière une même adresse) et **ne sont pas des décisions métier** : elles se règlent sans migration. Les RPC définies avec `RETURNS TABLE` / `SETOF` ne sont pas enveloppées (aucune RPC de la liste n'est dans ce cas) ; les enveloppes rendent la fonction `VOLATILE` : appel en POST (comportement par défaut de `supabase-js`).

## 5. Journal d'audit (`20261128070100`)

- `audit_log` : plus aucun droit d'écriture pour `anon`/`authenticated` ; **ajout seul** (déclencheurs refusant `UPDATE`, `DELETE`, `TRUNCATE`, erreur `42501`). Les entrées viennent des fonctions serveur (`log_audit`, `_h13_audit`, fonctions d'administration). Pour une purge de rétention future, désactiver explicitement le déclencheur dans une migration dédiée et validée.
- Actions désormais journalisées (niveau « Sensible », acteur = nom + identifiant du compte, cible limitée à des identifiants/booléens/nombres) : voir le tableau §1. Les valeurs financières ne sont **pas** modifiées par le test (le test réapplique la valeur courante).
- Exports : chaque export écrit « Export CSV : <genre> » avec le nombre de lignes et les filtres (la recherche libre n'est pas recopiée).

## 6. Sessions et suspension (`20261128070100`)

- Déclencheur `profiles_suspension_sessions` : à la suspension (`suspended` false → true), blocage de connexion (`auth.users.banned_until = 2999-01-01`, sans écraser un blocage définitif) et **suppression de toutes les sessions** ; à la réactivation, le blocage posé par la suspension est levé (un blocage « infini » posé pour une autre raison est conservé). Testé : mise à jour directe, `admin_set_account`, sessions d'un autre compte intactes.
- `admin_account_sessions_revoke(compte, motif)` : permission `security.accounts`, motif ≥ 5 caractères, pas sur soi-même, un administrateur ne peut être visé que par un administrateur global ; journalisé « Sessions fermées ».
- **Limite connue** : un jeton d'accès déjà émis reste valide jusqu'à son expiration (1 h par défaut) côté GoTrue ; côté base, un compte suspendu n'a plus aucun accès (`current_role_name()` vide, garde `enforce_mfa_on_sensitive`), testé par un appel d'une RPC protégée avec le jeton d'un compte suspendu. Raccourcir la durée de vie des jetons est un réglage du projet Supabase (décision propriétaire).

## 7. Santé des services (`20261128070300`)

`admin_service_health()` (tech.config, tech.maintenance, tech.logs ou tech.integrations) renvoie un état par service, **uniquement à partir de données enregistrées** :
base de données · envoi des notifications (file `notification_outbox`) · paiements (événements reçus) · évaluations (rapport de configuration de la fonction Edge + file d'envoi) · enregistrement des lives · connexions externes des profils · limites de débit · fonctions Edge et sauvegardes.
Statuts : `ok`, `degrade`, `erreur`, `non_configure`, `inconnu`. **Inconnu = jamais ok, jamais 0** : sans activité enregistrée (base neuve), notifications, paiements et synchronisations sont « inconnu » avec des mesures `null` ; fonctions Edge et sauvegardes sont toujours « inconnu » (non mesurables depuis la base : le dire est l'état honnête). Aucun secret, aucune valeur de configuration, aucun appel externe.
Interface : tuile « Santé des services » dans le tableau de bord de l'équipe Technique (écran 304), avec état de chargement, erreur + « Réessayer », et libellé « Inconnu » pour tout statut hors vocabulaire.

## 8. Exports CSV (`20261128070400`)

`admin_export_csv(genre, filtres)` : `audit` (security.audit ou tech.logs ; filtres catégorie(s), niveau, dates, recherche), `rattachements` (administrateur ; file des comptes Département non rattachés, ou tous), `contestations` (ranking.moderate ; statut).
Refusé sans permission, plafonné à 5 000 lignes (indicateur `truncated`), 20 exports par heure et par compte, neutralisation des formules de tableur (`=`, `+`, `-`, `@`), journalisé. Interface : bouton « Exporter » du journal d'audit (écran 137), « Exporter la file (CSV) » (rattachement des comptes), « Exporter la liste (CSV) » (contestations du Top 100).

## 9. Performance (5.5)

- **Index de clés étrangères** : 380 index `fkix_<table>_<colonnes>_<hash>` créés pour les clés étrangères sans index de tête (suppression d'un profil/boutique/commande sans parcours séquentiel des tables enfants ; jointures). Index non partiels uniquement ; rejouable ; verrou d'écriture de courte durée (tables de taille modeste au lancement). Coût : espace disque et écriture marginale ; retour arrière : `drop index fkix_…`.
- **Requêtes lentes** : non mesurables sur PGlite (volumétrie vide). Procédure recommandée en production (lecture seule) : activer `pg_stat_statements` (Supabase → Database → Extensions), puis `select query, calls, mean_exec_time, rows from pg_stat_statements order by mean_exec_time * calls desc limit 20;` ; vérifier avec `explain (analyze, buffers)` les RPC de liste du Top 100 et de la marketplace une fois les premières données réelles chargées.
- Limites de débit des listes publiques (§4) : protègent aussi la base contre les rafales.

## 10. Reste à faire / décisions

- **Non corrigé par ce lot (hors périmètre, à signaler)** : la migration d'un autre lot `20261128060000_h13_orgs_missions_equipe_avis.sql` accorde `_mission_readable(uuid)` à `authenticated` seulement alors que la politique « missions : propriétaire, publiées, département » s'applique à tous les rôles : une lecture de `missions` par `anon` (ou par `service_role`) échoue avec « permission denied for function _mission_readable » (scénario `etu_money` : 4 ECHEC). À corriger par le lot Organisations (accorder l'exécution à `anon`, comme les autres assistants de politiques, ou limiter la politique à `authenticated`).
- Edge Functions : contrôle interne (en-têtes, secrets, validation) non audité ici au-delà des droits des fonctions SQL qu'elles appellent.
- Durée de vie des jetons d'accès, 2FA du compte Vercel/Supabase, rotation des clés : actions propriétaire (hors base).
- `live_comments` (héritée) et `pgcrypto` dans `public` : nettoyage différé (aucun impact fonctionnel).
- Valeurs des limites de débit : à ajuster après quelques semaines de trafic réel (colonne `hits_last_hour` de `admin_rpc_rate_limits_list`).

## 11. Fichiers

Migrations (rejouables, additives) : `20261128070000_h13_admin_debit_enveloppes.sql`, `…070100_h13_admin_audit_durcissement.sql`, `…070200_h13_admin_index_cles_etrangeres.sql`, `…070300_h13_admin_sante_services.sql`, `…070400_h13_admin_exports_csv.sql`, `…070500_h13_admin_debit_complements.sql`.
Tests : `supabase/tests/marketplace_pglite/h13_audit.mjs` ; `test/journey/h13_admin_test.dart` ; extensions de `test/journey/h6_admin_propre_test.dart` et `test/journey/h8_sources_propres_test.dart`.
Interface : `lib/figma/live/admin_sante.dart`, `lib/figma/live/admin_exports.dart` (+ branchements dans `admin_centre.dart`, `admin_consoles.dart`, `dept_space.dart`, `top100_admin_moderation.dart`).
