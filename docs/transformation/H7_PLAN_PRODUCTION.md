# H7 — Plan d'application en production des migrations locales en attente

Établi le 20 novembre 2026 (lecture du dépôt local à partir de 09:35 ; liste des migrations relue à 10:13 : inchangée, 35 fichiers dont 1 non versionné). Document de **préparation** : aucune commande de ce plan n'a été exécutée, aucun accès à la production
(même en lecture) n'a eu lieu pour l'écrire. Tout ce qui suit vient de la lecture des fichiers de `supabase/migrations/` ; les requêtes SQL ci-dessous ont été relues mais **pas exécutées** (pas de base
disponible pour ce lot) : leurs résultats de référence doivent d'abord être établis sur la répétition générale (§5), puis comparés à la production.

## 1. Périmètre exact

Règle donnée par le propriétaire : sont appliquées en production les 201 migrations dont la version est **≤ 20261119070000** (recompté : 201 fichiers, dossier de 235 fichiers `.sql`, aucun autre type de fichier).
Sont **en attente** les fichiers de version **> 20261119070000**.

### 1.1 Liste figée au moment de la lecture

34 fichiers versionnés (commits `ef48863c`, `853b6158`, `a5a9dff0` ; `git status` propre sur ces fichiers ; `git diff --name-only c339d83f..HEAD -- supabase/migrations` = ces 34 fichiers, rien d'autre)
+ **1 fichier non versionné, en cours d'écriture par un autre lot** (apparu à 09:50, modifié depuis : sa taille et son hash ne sont pas figés).

| # | Fichier (ordre d'application = ordre des noms) | Octets | SHA-256 (12 premiers car.) |
|---|---|---|---|
| 1 | 20261120010000_h1_types_organisation.sql | 17 987 | a63cb05e545c |
| 2 | 20261120010100_h1_fiche_justificatifs_par_type.sql | 21 823 | 0b2195253a13 |
| 3 | 20261120010200_h1_forfaits_par_type.sql | 12 319 | 43d48cb6aedc |
| 4 | 20261120010300_h1_fusion_autre_dans_organisation.sql | 4 286 | 91647116b87d |
| 5 | 20261120010400_h1_libelles_organisation.sql | 2 799 | 0abf5fcb293d |
| 6 | 20261120020000_h2_departement_rattachement.sql | 19 840 | 649777130e22 |
| 7 | 20261120020100_h2_departement_identite_vues.sql | 12 646 | 1917325efd84 |
| 8 | 20261120020200_h2_departement_suivi_rapports.sql | 53 222 | 898affcd2f76 |
| 9 | 20261120020300_h2_departement_cloisonnement_rpc.sql | 49 281 | 473ad0b7367e |
| 10 | 20261120020400_h2_departement_cloisonnement_rls.sql | 15 759 | 4760062f5f5a |
| 11 | 20261120020500_h2_departement_sponsoring.sql | 3 060 | 28393d34ac37 |
| 12 | 20261120030000_h3_direction_sans_pouvoirs_techniques.sql | 7 413 | faf49675d669 |
| 13 | 20261120030100_h3_partenariats_validations.sql | 25 654 | f81199e38554 |
| 14 | 20261120030200_h3_direction_vision_transversale.sql | 29 060 | bf10f10e1eeb |
| 15 | 20261120040000_h4_equipes_permissions.sql | 27 435 | 72b52cb0d283 |
| 16 | 20261120041000_h4_gardes_par_permission.sql | 12 718 | af19a2e497b2 |
| 17 | 20261120042000_h4_securite_comptes_suspects_et_lecture.sql | 13 517 | 63160c70b520 |
| 18 | 20261120043000_h4_tableaux_equipes_et_2fa.sql | 10 579 | 8a9aea92a20e |
| 19 | 20261120050000_h5_parcours_continu_vendeur.sql | 7 094 | 2bfcbf43a747 |
| 20 | 20261121010000_k1_mfa_operations_sensibles.sql | 3 334 | c81692dff159 |
| 21 | 20261121010100_k1_notifications_par_permission.sql | 7 562 | c69da63f88a9 |
| 22 | 20261121010200_k1_droits_minimaux_heritage.sql | 10 974 | e2d9f80570c5 |
| 23 | 20261121010300_k1_isolation_lectures_equipes.sql | 6 255 | 84e688a46daf |
| 24 | 20261121020000_k2_eligibilite_vendeur.sql | 23 474 | ea552e41e525 |
| 25 | 20261121030000_k3_rattachement_controles.sql | 20 854 | 72020d3ed3dc |
| 26 | 20261121031000_k3_non_rattache_gardes.sql | 10 710 | 9d7edc607375 |
| 27 | 20261121040000_k4_partenariats_organisation.sql | 43 115 | c1f1e459fb56 |
| 28 | 20261121040100_k4_libelles_organisation_equipes.sql | 4 074 | f632daf65ac8 |
| 29 | 20261121040200_k4_forfaits_organisation_visee.sql | 2 059 | ea4a3ca32569 |
| 30 | 20261122010000_l2_admin_commandes.sql | 2 059 | d1a3cf3619de |
| 31 | 20261122011000_l2_incidents_resolution.sql | 2 074 | 9a53dd7c959e |
| 32 | 20261122020000_l3_rattachement_historique_2fa.sql | 10 455 | 0dad64f06ee4 |
| 33 | 20261122021000_l3_comptes_suspects_revue_equipes.sql | 12 386 | c326e59d77f4 |
| 34 | 20261122030000_l4_missions_campagnes_capacite.sql | 6 373 | f6d1482bf070 |
| 35 (en cours, non versionné) | 20261123010000_h7_seuil_paiement_commission_reglages.sql | 3 831 à 09:50 | non figé |

**À la date de lecture : 34 fichiers figés + 1 en cours = 35 fichiers.** Les lots `20261123*` encore en création par d'autres agents ne sont pas décrits au-delà de ce qui précède : ce plan s'arrête à l'état du dépôt lu.
Le fichier 35 recrée `_payout_limit(text, integer)` (seuil de retrait lu depuis le réglage `commission.payout_threshold`) et pose un déclencheur `trg_h7_commission_settings` sur `platform_settings` (contrôle de `commission.*`) ; retour arrière dans son en-tête.

### 1.2 Procédure pour une liste générée (à refaire le jour de l'application)

La liste du jour est celle du dépôt **au commit à déployer**, pas celle de ce tableau. La générer, la figer dans un manifeste et ne rien appliquer qui n'y figure pas :

```powershell
cd C:\Users\NITROV15\Downloads\boutik_ecole_flutter
git status --short supabase/migrations        # doit être vide : un fichier non versionné ou modifié n'est pas appliqué
$attendu = Get-ChildItem supabase\migrations\*.sql |
  Where-Object { [int64]($_.Name.Split('_')[0]) -gt 20261119070000 } | Sort-Object Name
$attendu.Count
$attendu | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name } |
  Set-Content "$env:USERPROFILE\Downloads\boutik_sauvegardes_prod\manifeste_migrations_<date>.txt"
```

Contrôles du manifeste : (a) aucun nom en double de version ; (b) aucune version ≤ 20261119070000 absente de la liste des 201 appliquées (sinon `db push` voudrait l'inclure) ; (c) un fichier `20261123*` n'entre dans le manifeste que s'il est **commité** et que son auteur confirme qu'il est terminé.
Pour chaque nouveau lot `20261123*` : refaire l'analyse du §2 (objets, DML, contraintes, retour arrière) avant de l'ajouter ; ne jamais appliquer un lot qui n'a pas de scénario SQL vert.

## 2. Ce que font réellement les migrations (relu fichier par fichier ; chiffres recalculés)

### 2.1 Chiffres recalculés sur les 34 fichiers figés

- **17 tables créées** (toutes `if not exists`, vides à la création) : `org_types`, `org_type_docs`, `department_accounts`, `department_profiles`, `department_partnerships`, `department_highlights`, `institutional_partnerships`, `institutional_validations`, `institutional_decision_log`, `admin_teams`, `admin_permissions`, `admin_team_members`, `admin_team_history`, `account_flags`, `seller_pauses`, `k2_pause_holds`, `department_assignment_history`.
- **198 fonctions distinctes définies** : 162 nouvelles, **36 recréées** (`CREATE OR REPLACE`, sans changement de signature ni de type de retour : comparé par script avec la dernière définition ≤ 20261119070000) :
  `_company_page, _dept_scope, _listing_staff_scope, _need_poster, _notify_finance, _payout_blocker, _project_reviewers, _review_scope_ok, _scope_recipients, ad_feed, admin_departments, admin_users, company_dashboard, company_decide, company_doc_add, company_get, company_plan_checkout, company_plan_save, company_plans_list, company_queue, company_save, company_submit, company_subscription_request, department_detail, dept_students, is_contest_staff, is_platform_manager, is_platform_staff, mentor_create, platform_overview, production_create, production_update, profile_set_academic, sponsor_report, staff_mentors, staff_productions`.
  22 fonctions sont définies dans plusieurs fichiers de la liste (la dernière gagne ; ordre impératif) : `_admin_team_autoenroll, _admin_team_defaults, _dept_account_covers, _dept_id, _owner_reviewers, _project_reviewers, _scope_recipients, _seller_capability, admin_dept_accounts, admin_dept_assign, admin_dept_unassign (×3), admin_team_accounts_review, company_plans_list, dept_partnership_save, dept_partnerships, direction_dept_partnerships, my_department, my_seller_capability, partnership_decide, partnership_save, partnerships_list, security_flags_list`.
- **Fonctions réécrites SUR PLACE** à partir de leur définition en vigueur (`pg_get_functiondef` puis `EXECUTE`) : c'est le point de fragilité principal (§2.3).
  H1-5 (libellés : toutes les fonctions plpgsql/sql dont le texte contient « entreprise », nombre affiché par `NOTICE`), **H2-4 : 80 fonctions**, H3-1 : 4 ciblées + retrait du rôle `direction` dans 7 fonctions, H4-2 : 58, K1-2 : 31, K1-4 : 5, K3-2 : 16 (+ `is_contest_staff`, `is_platform_manager`), K4-2 (libellés), K1-1 / H4-4 (liste 2FA de `enforce_mfa_on_sensitive`), K1-3 (`admin_team_dashboard`, `my_admin_access`).
- **Politiques RLS** : 35 recréées en H2-5 (33 tables : `drop policy` puis `create policy`) + 2 en H2-6 (`sponsors`, `sponsorships`) + 1 en H1-4 (`profil créé à l'inscription`) ; `alter policy` automatiques : H3-1 sur 11 tables (retrait du rôle `direction` : `plans, subscriptions, ad_campaigns, payout_batches, payment_transactions, payment_messages, event_receipts, cms_items, pickups, audit_log, profiles`), K1-4 sur 14 tables ; **23 politiques restrictives nouvelles** (`équipes : <table>`) en H4-3.
- **25 déclencheurs créés** : `trg_company_subscription_audience` (company_subscriptions), `trg_a_profile_role_no_other`, `trg_dept_profile_lock`, `trg_admin_team_autoenroll`, `trg_dept_role_notify` (profiles), `trg_dept_sync_profile` (department_accounts), `trg_admin_team_members_check`, `trg_zz_k2_seller_listing` (listings), `trg_zz_k2_seller_shop` (shops), `trg_zz_k2_seller_owner` (delivery_zones, seller_settings), `trg_zz_k2_seller_asset` (promo_codes, flash_sales, shop_packs, shop_campaigns), `trg_zz_k2_quote_provider` (quote_requests), `trg_k2_order_line_seller` et `trg_k2_order_line_fulfil` (order_lines), `trg_departments_unique_name` (departments), `trg_partnership_org_guard` et `trg_partnership_org_after` (×2 tables), `trg_zz_l4_proposal` (mission_proposals), `trg_zz_l4_ad_campaign` (ad_campaigns).
- **Aucune** dépendance à `pg_cron`, à `create extension`, au DDL de `storage`, à `vault`, à une publication Realtime, ni `drop table`, `truncate`, `drop column`, `set not null` sur table existante. Lectures à l'exécution seulement : `storage.objects` (dans `company_doc_add`) et `auth.users`.

### 2.2 Dépendances entre migrations (ordre impératif)

- H1-1 → H1-2…5 (colonne `org_type`, tables `org_types`/`org_type_docs`). H1-5 doit précéder H2-4 : les motifs de H2-4 sont cherchés dans les définitions **après** les libellés H1.
- H2-1 (`department_accounts`, `_dept_*`) → H2-2…6, H3-3, K3, L3-1. H2-3 (colonnes `department_id` de `productions`/`mentors`) → H2-4.
- H3-1 (`_finance_read_consolidated`) → H4-2 (garde `finance.read`). H3-2 (tables partenariats) → K4-1 (colonnes `organization_*`) ; H2-3 (`department_partnerships`) → K4-1.
- H4-1 (tables d'équipes, `has_admin_permission`) → H4-2, H4-3, H4-4, K1-2, K1-3, K1-4, L3-2. **H4-1 migre les comptes finance/support avec leurs droits « d'avant », puis K1-3 les ramène à zéro** : l'état final dépend de l'enchaînement complet (§2.4).
- K2 (`seller_capable`, `seller_open`, `_seller_block_reason`) → L4 (`l4_proposal_guard`, `ad_feed`). H5 (`_seller_capability`) est redéfinie par K2.
- L3-1 recrée `admin_dept_assign/unassign/accounts` de K3-1 ; L3-2 recrée `admin_team_accounts_review` de K1-3 et `security_flags_list` de H4-3.
- Fonctions externes à la liste, déjà présentes (≤ 20261119070000) et vérifiées par recherche : `notify_user` (20261103000100), `admin_set_account` (20261101000000), `is_verified_student` (20261117010000), `_require_staff_aal2` (20261117010100), `company_is_org`, `company_effective_owner`, `current_role_name`, `protect_profile_authority` (ne bloque pas sans `auth.uid()`, donc les `UPDATE profiles` de migration passent).
- Conséquence : la production doit être **exactement** à l'état 201 fichiers ; une fonction modifiée à la main côté production ferait échouer les migrations à motifs (§2.3).

### 2.3 Fragilités : réécritures à motifs

Deux familles :
- **Échec franc (la migration s'arrête, rien n'est appliqué pour ce fichier)** : H2-4 `_h2_patch_fn` (80 fonctions : « motif absent » ou « fonction introuvable »), K3-2 `_k3_patch_fn` (16), K1-1 (liste de `enforce_mfa_on_sensitive` introuvable ou remplacement sans effet), K1-3 (`admin_team_dashboard` : remplacement sans effet), K1-2 (fonction non `security definer`).
- **Sans effet silencieux si le motif n'est pas trouvé** : H1-5 et K4-2 (libellés), H3-1 (retrait du rôle `direction`), H4-2 (`_h4_guard_fn`, 58 fonctions), H4-3 (`_h4_team_policy` ignore une table absente), H4-4 (liste 2FA), K1-2 (`_k1_patch_recipients`, 31), K1-4 (`_k1_patch_policies` / `_k1_patch_fn`). **Une migration « verte » peut donc ne pas avoir posé une garde** : c'est ce que les contrôles post-migration du §8 (V6 à V9) vérifient.
- Le propriétaire des fonctions doit être le rôle qui exécute `db push` (`postgres`) : `CREATE OR REPLACE` par `EXECUTE` échoue sinon (contrôle pré-migration Q9).

### 2.4 DML sur les données existantes (tout ce qui écrit dans des lignes déjà en production)

| Fichier | Effet sur les données existantes |
|---|---|
| 1 (H1-1) | `company_profiles` : colonnes `org_type` (**NOT NULL, défaut `entreprise_commerciale`**, clé étrangère), `tax_number`, `mission` ajoutées ; toutes les fiches existantes deviennent « entreprise commerciale ». `company_documents` : contrainte de nature remplacée (élargie : les 5 natures d'origine restent valides → ne peut pas échouer sur des données réelles). `org_type_docs` : `delete`+`insert` sur la table neuve. |
| 3 (H1-3) | `company_plans` : `pro` renommé « Organisation » et ses avantages réécrits (seulement si le nom est encore « Entreprise ») ; forfait `solidaire` (10 000 FCFA, 30 j) inséré (`on conflict (code) do nothing`) ; colonne `audience_types`. |
| **4 (H1-4)** | **`profiles.role = 'other'` → `'company'` pour tous** ; fiches `company_profiles` existantes de ces comptes → `org_type = 'autre_reconnue'` (si encore par défaut) ; fiche **brouillon créée** pour ceux qui n'en ont pas et dont le nom a ≥ 2 caractères ; politique d'inscription restreinte à client/student/company. **Irréversible hors sauvegarde** (l'ancien rôle n'est conservé nulle part). |
| 5 (H1-5), 28 (K4-2) | Réécriture de libellés dans des fonctions ; `plans.name` / `plans.audience` (forfait premium `entreprise`). |
| **6 (H2-1)** | **`department_accounts` : reprise des comptes `dept`** (a) ayant `profiles.department_id`, (b) sinon par nom exact d'un unique département *vérifié* de l'établissement. Le déclencheur `trg_dept_sync_profile` **réécrit `profiles.department/institution/…` de ces comptes**. Les autres comptes dept restent **sans rattachement** (aucune donnée visible). |
| 8 (H2-3) | `productions.department_id` et `mentors.department_id` renseignés depuis le rattachement du créateur. |
| **15 (H4-1)** | `admin_team_members` : un compte `finance` → équipe finance avec 5 permissions (`finance.read/payments/payouts/refunds/transfers`) ; un compte `support` → équipe support (6 permissions) **et** équipe sécurité (4) ; historique `migration`. |
| **22 (K1-3)** | **Réduction à zéro permission de toutes ces lignes** (aucune n'a jamais été attribuée par un administrateur : `granted_by` nul et aucun événement `grant`/`update`) ; lignes d'autres équipes supprimées ; historique `reduce` (permissions d'avant conservées) ; audit `Équipe : droits hérités réduits` (niveau Critique) ; notification « Comptes Finance / Support à réviser » à chaque administrateur actif. Nombre d'historiques `reduce` attendu = comptes finance + 2 × comptes support (hors lignes déjà vides). |
| 25 (K3-1) | Notification de synthèse « Comptes Département à rattacher » à chaque administrateur (≤ 50) si des comptes dept ne sont pas rattachés valablement ; **index unique** `departments_norm_name_key` posé seulement si aucun doublon de nom normalisé parmi les départements vérifiés (sinon `NOTICE` et pas d'index ; le déclencheur `trg_departments_unique_name` reste actif et bloquera ensuite toute modification des départements en doublon). |
| 27 (K4-1) | `institutional_partnerships` / `department_partnerships` : mises à jour de reprise (organisation, réponse) — **tables créées vides par les fichiers 8 et 13 : 0 ligne en production si elles n'existaient pas** (à confirmer par la requête Q2). |
| 32 (L3-1) | `department_assignment_history` : une ligne `existing` par rattachement présent (ceux repris par le fichier 6 sont « repris par le système, à confirmer »). |
| 24 (K2), 34 (L4) | Aucune écriture à la migration : les gardes jouent seulement sur les **écritures futures** (déclencheurs `auth.uid()` non nul). Les annonces/boutiques existantes ne sont pas modifiées. |

### 2.5 Colonnes NOT NULL et contraintes pouvant échouer sur données réelles

Évalué fichier par fichier ; rien de certain sans les requêtes de pré-contrôle :
- `org_type NOT NULL DEFAULT … REFERENCES org_types` : sûr (défaut valide, table de référence remplie juste avant).
- `company_documents_kind_check` : sûr (ensemble élargi). `shops_status_check` (ajout de `paused`) : sûr, et enveloppé dans un bloc qui n'échoue pas (`NOTICE`) ; K2 assume « statut non modifié » si la contrainte ne pose pas.
- `account_flags_status_check`, `admin_team_history_action_check` (K1-3, L3-2) : tables créées dans la même séquence, sans donnée hors liste.
- `department_accounts.department_id NOT NULL` : reprise par identifiant (insère aussi un département **non vérifié** → état `unverified`, aucune donnée visible) ; reprise par nom exige exactement 1 département vérifié : sûr.
- Index unique `departments_norm_name_key` : échec **absorbé** (bloc `exception when unique_violation`).
- `company_profiles (owner_id, company_name…)` : insertion de fiches « autre » avec `left(btrim(name),120)` et nom ≥ 2 caractères : respecte `check (char_length(btrim(company_name)) between 2 and 120)`.
- Verrous : `ALTER TABLE … ADD COLUMN … DEFAULT`, `ADD CONSTRAINT`, `CREATE TRIGGER` sur `profiles`, `listings`, `shops`, `order_lines`, `departments`, `company_*`, `mission_proposals`, `ad_campaigns` prennent des verrous courts ; un `pg_dump` interrompu laissé « idle in transaction » bloque `create trigger` (incident déjà vécu, REPRISE_OPENCODE.md) → contrôle Q1.

### 2.6 Opérations irréversibles ou difficilement réversibles

1. **Fichier 4 : `other → company`** (perte de l'information « ancien rôle »). Exporter la liste Q6 avant.
2. **Fichier 22 : réduction des droits finance/support** : réversible par SQL grâce à `admin_team_history` (action `reduce`, `before_permissions`) mais **contraire à la règle métier** (les droits sont attribués explicitement) : ne pas restaurer, attribuer.
3. **Fichier 6 : réécriture de `profiles.department/institution`** des comptes dept repris.
4. **Fichiers 5, 28 et les 9, 12, 16, 21, 23, 26 (réécritures sur place)** : plus de retour automatique ; le retour passe par les définitions du dump de schéma pris avant (R-DUMP, §7).
5. Notifications, audit et historiques écrits (fichiers 22, 25, 32) : non supprimés par un retour arrière (ils décrivent un événement réel).
6. Comportements métier ensuite **actifs et visibles des utilisateurs** (§3) : un retour arrière de schéma ne les « annule » pas pour ce qui a déjà été fait entre-temps.

## 3. Compatibilité et effets visibles sur la production existante

- **Département** : un compte dept sans rattachement valide ne voit **plus aucune donnée** (avant : repli « établissement entier »). Les comptes repris automatiquement sont marqués « à confirmer » (`assigned_by` nul).
- **Direction** : perd les lectures techniques (réglages, liste des comptes avec e-mails, journal d'audit, profils des autres, paiements individuels, retraits en borne, écriture mentors/productions). Garde la vue consolidée et les nouveaux écrans `direction_*`.
- **Finance / Support** : après K1-3, **aucune permission** ; toutes les opérations sensibles (validation de paiement, retraits, remboursements, virements, répartition, litiges, réclamations, modération, 2FA, clés d'API, réglages, journal d'audit) exigent une permission attribuée par l'administrateur global ; les notifications d'équipe ne partent plus qu'aux administrateurs et aux agents ayant la permission ; lectures directes de tables d'une autre équipe fermées (23 politiques restrictives). `is_platform_staff()` n'accepte plus un support sans permission.
- **Inscription** : le rôle `other` n'est plus attribuable ; l'attribution du rôle `other` par l'administrateur donne `company`.
- **Organisation** : huit types ; pièces exigées par type avant l'envoi pour vérification ; une fiche approuvée repasse en vérification si nom/type/immatriculation/NIU changent ; forfait `solidaire` pour les types non commerciaux ; partenariats avec l'établissement (K4).
- **Vendeur** : seul un étudiant vérifié, téléphone vérifié, non suspendu et boutique non en pause peut publier, recevoir de nouvelles commandes, répondre à un devis, proposer ses services sur un besoin, lancer une campagne, demander un retrait ; les commandes déjà engagées se poursuivent.
- **2FA** : les nouvelles opérations sensibles (liste de K1-1/H4-4/L3-2) exigent aal2 pour un compte ayant un facteur TOTP vérifié.
- **Anciens clients de l'application** : tant que le build web n'est pas redéployé, l'ancienne version reste servie sur la nouvelle base (écrans de rattachement/équipes absents) → enchaîner push, build, déploiement sans délai (§9).
- **Edge Functions** : voir §10.

## 4. Sauvegarde complète avant toute application

Principe : **pg_dump natif PostgreSQL 17**, schéma **et** données, stocké **hors du dépôt** (dossier existant `Downloads\boutik_sauvegardes_prod`, jamais dans `boutik_ecole_flutter`), exécuté par le propriétaire.
Le mot de passe de la base n'est jamais tapé en clair dans une commande, jamais affiché, jamais enregistré (ni transcript, ni historique) :

```powershell
$dest  = "$env:USERPROFILE\Downloads\boutik_sauvegardes_prod"
$stamp = Get-Date -Format 'yyyyMMdd_HHmm'
$pg    = 'C:\Program Files\PostgreSQL\17\bin'                      # & "$pg\pg_dump.exe" --version doit afficher 17.x
$sec   = Read-Host 'Mot de passe de la base (saisie masquée)' -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $sec).Password
$env:PGSSLMODE  = 'require'
$h = @('-h', '<hôte direct ou pooler « session » du projet zxqcnmgwhtbxkdpjqtlr>', '-p', '5432', '-U', '<utilisateur postgres>', '-d', 'postgres')

# 1. Copie complète (schéma + données) des schémas applicatifs, format custom (restaurable partiellement)
& "$pg\pg_dump.exe" @h -Fc --schema=public --schema=auth --schema=storage --schema=supabase_migrations -f "$dest\prod_complet_${stamp}_avant_h7.dump"
# 2. Schéma seul de public en SQL lisible (sert au retour arrière des fonctions/politiques, §7, et à la comparaison avant/après)
& "$pg\pg_dump.exe" @h --schema-only --schema=public -f "$dest\prod_schema_public_${stamp}_avant_h7.sql"
# 3. Données seules de public (SQL COPY), second filet
& "$pg\pg_dump.exe" @h --data-only --schema=public -Fc -f "$dest\prod_data_public_${stamp}_avant_h7.dump"

Remove-Item Env:PGPASSWORD
Get-ChildItem "$dest\*_${stamp}_*" | ForEach-Object { '{0}  {1}  {2}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Length, $_.Name } | Set-Content "$dest\sha256_${stamp}.txt"
& "$pg\pg_restore.exe" --list "$dest\prod_complet_${stamp}_avant_h7.dump" | Measure-Object -Line
```

Le schéma `auth` appartient à un rôle Supabase : `pg_dump` peut émettre des avertissements de privilèges ; ce qui compte est que `pg_restore --list` affiche les tables `auth.users` et `public.*` et que les nombres de lignes concordent après restauration sur la copie (§5).
Règles : ne jamais ajouter `-W` ni passer le mot de passe dans une URL de connexion ; ne jamais interrompre un `pg_dump` en cours (session « idle in transaction » côté serveur : bloque ensuite `create trigger`) ; vérifier Q1 avant et après ; l'hôte, l'utilisateur et le mot de passe viennent du tableau de bord Supabase (non reproduits ici).
Si Docker Desktop est démarré, la procédure habituelle `supabase db dump --linked` (schéma puis `--data-only`) reste valable et peut servir de seconde copie.

### 4.1 Ce que la sauvegarde ne couvre pas (à traiter à part)

| Hors périmètre du dump | Pourquoi / quoi faire |
|---|---|
| **Fichiers du stockage** (compartiments, ex. `profile-documents`, images) | `pg_dump` ne contient que les lignes `storage.objects` (métadonnées), pas les octets. Les migrations ne touchent pas aux objets ; exporter les compartiments critiques seulement si l'on veut un filet total. |
| **`cron.job`** (planifications pg_cron) | Le schéma `cron` n'est pas dans le dump ci-dessus : exporter `select jobid, jobname, schedule, command, active from cron.job order by jobid` (CSV via `\copy`) et le comparer après (aucune migration de la liste ne touche `cron`). |
| **Secrets** (secrets des Edge Functions : Tara/Notch Pay, LiveKit, clé interne `dispatch-notifications`, jetons…) | Jamais exportés ni lus par ce plan. Noter seulement les **noms** (`supabase secrets list`) ; les valeurs restent chez le propriétaire. Les clés Notch Pay ne sont ni lues ni modifiées. |
| **Réglages de rôles / base** (ex. `alter role authenticator set pgrst.db_pre_request`) | Hors dump par schéma : `select r.rolname, s.setconfig from pg_db_role_setting s join pg_roles r on r.oid = s.setrole` et sauvegarde du résultat. |
| **Configuration Auth** (URL de redirection, fournisseurs, modèles d'e-mail, SMTP) et **Edge Functions déployées** (code, options `--no-verify-jwt`) | Captures d'écran / `supabase functions list` ; le code est dans le dépôt. |
| Rôles, extensions | `select extname, extversion from pg_extension` ; `select rolname from pg_roles` (noms seuls). |
| Données écrites **après** la sauvegarde | Un retour par restauration les perd : informer les utilisateurs, choisir une fenêtre calme, refaire un dump différentiel (ou le même dump) juste avant le push. |

Vérifier aussi dans le tableau de bord Supabase si des sauvegardes quotidiennes / PITR existent pour ce projet (dépend du forfait) : un second filet, pas un remplacement.

## 5. Répétition générale hors production (obligatoire avant la production)

Les scénarios PGlite (`supabase/tests/marketplace_pglite/*.mjs`) rejouent les 34 fichiers sur une base **vide** : ils prouvent la logique, pas la compatibilité avec les données réelles ni avec des définitions de fonctions de production modifiées à la main. Seule une **copie restaurée** teste les réécritures à motifs (§2.3) :

1. Restaurer `prod_complet_<stamp>_avant_h7.dump` dans une base **locale** jetable (conteneur Supabase local / Docker, jamais la production) : `pg_restore -d <base_locale> --no-owner --clean --if-exists …`.
2. Y appliquer les fichiers du manifeste, **dans l'ordre**, un par un (`psql -v ON_ERROR_STOP=1 -1 -f <fichier>`) ; noter le fichier en échec, le `NOTICE` de H1-5 / K4-2 (nombre de fonctions réécrites), la durée.
3. Rejouer les requêtes de contrôle du §8 : leurs résultats sont les **résultats de référence** pour la production.
4. Rejouer les scénarios SQL de non-régression sur cette copie quand c'est possible (`supabase/tests/run_all_local.py`) ; au minimum `act_h1…h5`, `fin_k1…k4`, `h6_*`.
5. Mesurer les verrous et le temps total ; décider de la fenêtre.

## 6. Pré-contrôles en lecture seule (à exécuter par le propriétaire AVANT, sur la production)

À lancer dans l'éditeur SQL du projet ou via `psql` avec `PGOPTIONS='-c default_transaction_read_only=on'`. Ce sont des `SELECT` seulement. Conserver les résultats (export CSV) dans `boutik_sauvegardes_prod` : Q6 et Q3 documentent l'état d'avant.

```sql
-- Q0. Version de la base et état exact des migrations : attendu 201 lignes, max 20261119070000, aucune version supérieure
select count(*) as appliquees, max(version) as derniere from supabase_migrations.schema_migrations;
select version from supabase_migrations.schema_migrations where version > '20261119070000' order by 1;   -- attendu : 0 ligne

-- Q1. Sessions bloquantes (pg_dump interrompu) : attendu 0 ligne
select pid, state, xact_start, left(query, 80) as requete from pg_stat_activity
where datname = current_database() and state in ('idle in transaction', 'idle in transaction (aborted)');

-- Q2. Objets que la liste va créer : tout est attendu NULL (sinon la production a dérivé du dépôt : s'arrêter)
select to_regclass('public.org_types') a, to_regclass('public.department_accounts') b, to_regclass('public.department_partnerships') c,
       to_regclass('public.institutional_partnerships') d, to_regclass('public.admin_team_members') e, to_regclass('public.account_flags') f,
       to_regclass('public.seller_pauses') g, to_regclass('public.department_assignment_history') h;
-- Partenariats existants : les tables de partenariats n'existent qu'à partir de cette liste ; s'il existe des conventions saisies ailleurs, les lister ici à la main
select code, name, price_fcfa, active from company_plans order by position;                          -- 'pro' doit encore s'appeler « Entreprise » ; 'solidaire' absent
select plan_code, status, count(*) from company_subscriptions group by 1, 2 order by 1, 2;

-- Q3. Comptes Département : sort de chacun après la migration (rattachement automatique par identifiant ou par nom unique, sinon « sans donnée »)
select p.id, p.name, p.email, coalesce(p.suspended, false) as suspendu, p.department_id, d.status as statut_dept_par_id, p.institution_id, p.department as dept_texte,
  case
    when p.department_id is not null and d.id is not null and d.status = 'verified' then 'H2 : rattaché par identifiant (valide)'
    when p.department_id is not null and d.id is not null then 'H2 : rattaché par identifiant mais département NON vérifié -> aucune donnée'
    when p.institution_id is not null and nullif(btrim(coalesce(p.department, '')), '') is not null and
         (select count(*) from departments x where x.institution_id = p.institution_id and lower(btrim(x.name)) = lower(btrim(p.department)) and x.status = 'verified') = 1
      then 'H2 : rattaché par nom unique (à confirmer par l''administrateur)'
    else 'NON RATTACHÉ -> aucune donnée visible tant que l''administrateur ne le rattache pas'
  end as sort_apres_migration
from profiles p left join departments d on d.id = p.department_id
where p.role::text = 'dept' order by sort_apres_migration, p.name;

-- Q4. Noms de départements vérifiés en doublon (index unique non posé, déclencheur bloquant) : attendu 0 ligne
select institution_id, lower(btrim(regexp_replace(coalesce(name, ''), '\s+', ' ', 'g'))) as nom_normalise, count(*) as n, array_agg(id) as ids
from departments where status = 'verified' group by 1, 2 having count(*) > 1;

-- Q5. Comptes finance / support : tous seront ramenés à AUCUNE permission (K1-3) ; la liste sert à préparer les attributions explicites
select p.id, p.name, p.email, p.role::text as role, coalesce(p.suspended, false) as suspendu, p.created_at from profiles p where p.role::text in ('finance', 'support') order by p.role::text, p.name;
select count(*) filter (where role::text = 'finance') as finance, count(*) filter (where role::text = 'support') as support from profiles;   -- historiques « reduce » attendus = finance + 2 x support

-- Q6. Profils « other » (migrés en company) : à EXPORTER avant (seule trace de l'ancien rôle)
select p.id, p.name, p.email, c.owner_id is not null as fiche_existante, c.status, c.company_name, char_length(btrim(coalesce(p.name, ''))) >= 2 as nom_valide_pour_fiche
from profiles p left join company_profiles c on c.owner_id = p.id where p.role::text = 'other' order by p.name;
select role::text, count(*) from profiles group by 1 order by 1;                                      -- répartition de référence avant/après

-- Q7. Contraintes qui pourraient échouer : attendus = ensembles inclus dans les nouveaux
select kind, count(*) from company_documents group by 1 order by 1;                                  -- natures d'origine seulement
select status, count(*) from shops group by 1 order by 1;                                            -- draft/pending/active/suspended/closed seulement

-- Q8. Étudiants vendeurs non éligibles après K2 / L4 (étudiant vérifié = carte ou certificat validé, ou certification approuvée ; téléphone vérifié ; non suspendu)
with s as (
  select p.id, p.name, p.email, coalesce(p.suspended, false) as suspendu, coalesce(p.phone_verified, false) as tel_verifie,
         (p.certification::text = 'approved' or exists (select 1 from user_documents d where d.owner_id = p.id and d.kind in ('student_card', 'enrollment_certificate') and d.status = 'verified')) as etudiant_verifie
  from profiles p where p.role::text = 'student')
select s.*, (select count(*) from listings l where l.seller_id = s.id and l.status in ('approved', 'pending')) as annonces_actives_ou_en_attente,
            (select count(*) from shops h where h.owner_id = s.id and h.status in ('active', 'pending')) as boutiques_actives
from s where not (tel_verifie and etudiant_verifie and not suspendu)
  and ((select count(*) from listings l where l.seller_id = s.id and l.status in ('approved', 'pending')) > 0 or exists (select 1 from shops h where h.owner_id = s.id and h.status in ('active', 'pending')))
order by 8 desc, 2;
-- Vendeurs qui ne sont pas des étudiants (organisations, clients…) ayant des annonces actives : ne pourront plus publier ni recevoir de commandes neuves
select p.role::text, count(distinct l.seller_id) as vendeurs, count(*) as annonces from listings l join profiles p on p.id = l.seller_id where l.status in ('approved', 'pending') group by 1 order by 1;

-- Q9. Propriétaire des fonctions : toutes doivent appartenir au rôle qui exécutera db push (postgres) ; attendu 0 ligne
select p.proname, pg_get_userbyid(p.proowner) as proprietaire from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and pg_get_userbyid(p.proowner) <> 'postgres';

-- Q10. Fonctions que les réécritures à échec franc (H2-4 : 80, K3-2 : 16) vont chercher : attendu 0 ligne manquante
select n as fonction_absente from unnest(array[
 '_notify_shop_validators','_post_accessible','ann_close','ann_decide','ann_detail','ann_my_posted','ann_win_decide','ann_wins_list','answer_claim','assign_contest_juror','assign_mission','campaign_backers',
 'campaign_milestone_done','campaign_milestone_review','campaign_milestones_to_review','campaigns_overview','claim_thread','comment_report_close','comment_reports_list','contest_ranking','delete_post_comment',
 'hide_story','is_mission_participant','issue_certificate','listing_review_queue','marketplace_moderation','mentor_validate','mentors_pending','moderate_contest_team','moderate_post','moderate_story',
 'moderation_posts_list','moderation_stories_list','opp_close','opp_decide','opp_detail','opp_my_posted','opp_save','pickup_collect','pickup_register','pickups_list','post_reports_dismiss','product_detail',
 'project_files_list','project_members_list','project_save_full','protect_listing_status','public_project_get','qr_issue','quote_thread','report_comment','report_post','report_story','review_campaign',
 'review_project','review_wish','revoke_certificate','save_campaign','save_contest','save_project','save_wish','set_contest_status','set_listing_showcase','set_report_status','shop_decide','shop_public',
 'shop_report_set_status','skills_radar','staff_mission_proposals','staff_missions','storage_file_allowed','submit_claim','support_request_create','support_request_handle','support_requests_to_handle',
 'talents_search','trg_notify_pending_post','wish_get','wish_preorderers','wishes_to_review',
 'admin_users','ann_save','challenge_create','event_cancel','event_create','event_registrants','event_update','events_managed','invite_department_member','open_calls','open_needs','open_needs_list',
 'profiles_name_recertify','save_mission','sos_list','enforce_mfa_on_sensitive' ]) n
where not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n);
-- les 97 noms (80 de H2-4, 16 de K3-2, enforce_mfa_on_sensitive) existent tous dans les migrations ≤ 20261119070000 du dépôt (vérifié par script) ; une ligne ici = dérive de la production

-- Q11. Références de l'état d'avant (à comparer au §8) : volumes des tables de base et planifications
select 'profiles' t, count(*) from profiles union all select 'listings', count(*) from listings union all select 'orders', count(*) from orders union all
select 'order_lines', count(*) from order_lines union all select 'shops', count(*) from shops union all select 'company_profiles', count(*) from company_profiles union all
select 'departments', count(*) from departments union all select 'notifications', count(*) from notifications union all select 'audit_log', count(*) from audit_log;
select jobid, jobname, schedule, active from cron.job order by jobid;
select policyname, tablename from pg_policies where schemaname = 'public' order by tablename, policyname;   -- à exporter : base de comparaison des 35+2+11+14 politiques touchées
```

Lecture des résultats : toute ligne de Q4 (doublons), Q2 non nul, Q0 ≠ 201, Q9 non vide ou Q10 non vide = **arrêt** et analyse avant de continuer. Q3, Q5, Q6, Q8 ne bloquent pas : ils décident des **opérations manuelles** du §9 et de l'information des utilisateurs concernés.

## 7. Retour arrière par migration

Codes : **FICHIER n** = redéfinition posée par le fichier n de la liste (état intermédiaire ; en retour complet 35 → 1 on rejoint ensuite la définition du dump, ou on supprime l'objet s'il n'existait pas avant la liste) ; **SQL** = contre-migration écrivable à partir de l'en-tête « Retour arrière » du fichier (à rédiger et tester sur la copie, **non fournie** dans le dépôt) ; **DUMP** = recréer les définitions (fonctions / politiques) depuis `prod_schema_public_<stamp>_avant_h7.sql` ; **DONNÉES** = nécessite aussi les données sauvegardées ; **RESTAURATION** = seule la restauration de la sauvegarde rétablit l'état.

| # | Fichier | Retour arrière |
|---|---|---|
| 1 | H1-1 types | SQL (en-tête : drop fonctions, colonnes, tables ; recréer la contrainte `company_documents_kind_check`) — perd les types choisis ; convertir/supprimer d'abord les pièces de nouvelle nature |
| 2 | H1-2 fiche | DUMP (8 fonctions : `company_get`, `company_save`, `company_doc_add`, `company_submit`, `company_queue`, `company_decide`, `_company_page`, `company_dashboard`) |
| 3 | H1-3 forfaits | SQL (drop trigger/fonctions, `delete … 'solidaire'`, drop column) + DUMP (4 fonctions : `company_plans_list`, `company_plan_checkout`, `company_subscription_request`, `company_plan_save`) + DONNÉES (nom/avantages d'origine du forfait `pro`) |
| 4 | H1-4 fusion `other` | **RESTAURATION** (ou DONNÉES : remettre `role = 'other'` sur la liste Q6 exportée, après `alter table profiles disable trigger trg_a_profile_role_no_other`) ; politique : DUMP |
| 5 | H1-5 libellés | DUMP (liste des fonctions réécrites inconnue d'avance : la comparer au schéma d'avant) ; `plans.name` : DONNÉES |
| 6 | H2-1 rattachement | SQL (en-tête) + DUMP (6 fonctions recréées : `_dept_scope`, `_review_scope_ok`, `_scope_recipients`, `_listing_staff_scope`, `_project_reviewers`, `profile_set_academic`) + DONNÉES (`profiles.department/institution` réécrits par le déclencheur) |
| 7 | H2-2 identité | SQL (drop table/fonctions) + DUMP (`admin_users`, `admin_departments`, `platform_overview`) |
| 8 | H2-3 suivi | SQL (drop tables et colonnes `department_id`) + DUMP (7 fonctions recréées : `staff_mentors`, `staff_productions`, `mentor_create`, `production_create`, `production_update`, `dept_students`, `department_detail`) |
| 9 | H2-4 RPC | DUMP (80 fonctions ; la fonction inverse de l'en-tête est supprimée en fin de fichier) |
| 10 | H2-5 RLS | DUMP (35 politiques) |
| 11 | H2-6 sponsoring | DUMP (2 politiques, `sponsor_report`) |
| 12 | H3-1 direction sans pouvoirs | DUMP (fonctions et politiques de 11 tables, renommage de politique `payout_batches`) |
| 13 | H3-2 partenariats | SQL (drop tables/fonctions) |
| 14 | H3-3 vision transversale | SQL (drop des 10 fonctions `direction_*`) |
| 15 | H4-1 équipes | SQL (en-tête) + DUMP (`is_platform_staff`) |
| 16 | H4-2 gardes | DUMP (58 fonctions) |
| 17 | H4-3 sécurité / lecture | SQL (drop des 23 politiques, table `account_flags`, fonctions) |
| 18 | H4-4 tableaux / 2FA | SQL (drop fonctions) + DUMP (`enforce_mfa_on_sensitive`) |
| 19 | H5 parcours vendeur | SQL (drop des 5 fonctions, toutes nouvelles) |
| 20 | K1-1 2FA | DUMP (`enforce_mfa_on_sensitive`) |
| 21 | K1-2 notifications | DUMP (31 fonctions) + drop `_team_recipients`, `notify_team_permission` |
| 22 | K1-3 droits minimaux | **Ne pas annuler** (règle métier). Techniquement : SQL depuis `admin_team_history` (`reduce`, `before_permissions`) ou RESTAURATION |
| 23 | K1-4 isolation | DUMP (14 politiques, 5 fonctions) + drop `_staff_perm` |
| 24 | K2 éligibilité vendeur | SQL (en-tête) ; si des boutiques ont été mises en pause : rétablir d'abord annonces/boutiques depuis `k2_pause_holds` ; contrainte `shops_status_check` d'origine ; DUMP (`_payout_blocker`, `_seller_capability`) |
| 25 | K3-1 rattachement | SQL (en-tête : triggers, index, fonctions) + FICHIERS 6 et 9 (définitions intermédiaires de `_dept_id`, `_scope_recipients`, `_owner_reviewers`, `_project_reviewers`, `_dept_account_covers`, `my_department`, `admin_dept_*`) |
| 26 | K3-2 gardes non rattaché | DUMP (16 fonctions + `is_contest_staff`, `is_platform_manager`) |
| 27 | K4-1 partenariats organisation | SQL (en-tête : drop fonctions, triggers, colonnes) + FICHIERS 8, 13, 14 (définitions intermédiaires de `partnership_save/decide`, `partnerships_list`, `dept_partnership_save`, `dept_partnerships`, `direction_dept_partnerships`) — perd les rattachements/réponses saisis depuis |
| 28 | K4-2 libellés | DUMP |
| 29 | K4-3 forfaits visés | FICHIER 3 (`company_plans_list`) |
| 30 | L2-1 `admin_orders` | SQL (drop function) |
| 31 | L2-2 `kiosk_incident_resolve` | SQL (drop function) ; les incidents résolus restent résolus |
| 32 | L3-1 historique rattachement | SQL (drop function/table) + FICHIER 25 (`admin_dept_assign`, `admin_dept_unassign`, `admin_dept_accounts`) |
| 33 | L3-2 comptes suspects / revue | SQL (en-tête : convertir `suspended`→`escalated`, supprimer `keep_minimal`, remettre les contraintes) + FICHIERS 17 et 22 (`security_flags_list`, `admin_team_accounts_review`) |
| 34 | L4 missions / campagnes | SQL (drop triggers, fonctions) + DUMP (`ad_feed`) |
| 35 | (en cours) seuil de retrait | SQL (en-tête : drop trigger/fonction) + DUMP (`_payout_limit`) |

Stratégie de décision :
1. **Échec pendant `db push`** : le CLI s'arrête au premier fichier en erreur ; les fichiers précédents restent appliqués (à confirmer à la répétition : un fichier = une transaction). Corriger **en avant** par une nouvelle migration (jamais en modifiant un fichier déjà appliqué) ; ne jamais lancer `--include-all` ni appliquer un fichier à la main hors ordre.
2. **Défaut fonctionnel après application** : correction en avant par migration ciblée ; retour par SQL/DUMP uniquement pour le ou les fichiers concernés, **en ordre inverse** (35 → 1), en respectant les dépendances du §2.2.
3. **Restauration complète** : dernier recours (pertes des données écrites depuis la sauvegarde) ; restaurer dans une base neuve, vérifier, puis basculer ; ne jamais restaurer par-dessus la production sans copie intacte du dump.

## 8. Vérifications post-migration (SELECT)

Chaque requête est comparée au **résultat de référence de la répétition** (§5). Aucune de ces requêtes n'a été exécutée à ce stade.

```sql
-- V1. Historique : exactement les fichiers du manifeste, rien d'autre
select count(*) as nouvelles from supabase_migrations.schema_migrations where version > '20261119070000';   -- attendu : 34 (ou N du manifeste)
select version from supabase_migrations.schema_migrations where version > '20261119070000' order by 1;

-- V2. Objets créés : 17 tables
select count(*) from information_schema.tables where table_schema = 'public' and table_name in (
 'org_types','org_type_docs','department_accounts','department_profiles','department_partnerships','department_highlights','institutional_partnerships','institutional_validations',
 'institutional_decision_log','admin_teams','admin_permissions','admin_team_members','admin_team_history','account_flags','seller_pauses','k2_pause_holds','department_assignment_history');   -- attendu 17
select count(*) from org_types;                                           -- 8
select count(*) from admin_teams;  select count(*) from admin_permissions;   -- 4 ; 20 (H4-1) (6 finance, 6 support, 4 sécurité, 4 technique)

-- V3. Déclencheurs : 25 posés (vérifier aussi les 4 tables de trg_zz_k2_seller_asset)
select tgname, tgrelid::regclass from pg_trigger where not tgisinternal and tgname in ('trg_company_subscription_audience','trg_a_profile_role_no_other','trg_dept_sync_profile','trg_dept_profile_lock',
 'trg_admin_team_members_check','trg_admin_team_autoenroll','trg_zz_k2_seller_listing','trg_zz_k2_seller_shop','trg_zz_k2_seller_owner','trg_zz_k2_seller_asset','trg_zz_k2_quote_provider','trg_k2_order_line_seller',
 'trg_k2_order_line_fulfil','trg_departments_unique_name','trg_dept_role_notify','trg_partnership_org_guard','trg_partnership_org_after','trg_zz_l4_proposal','trg_zz_l4_ad_campaign') order by 1, 2;

-- V4. Données : aucun « other » ; fiches ; types
select count(*) from profiles where role::text = 'other';                  -- 0
select role::text, count(*) from profiles group by 1 order by 1;           -- égal à Q6 sauf other -> company
select org_type, status, count(*) from company_profiles group by 1, 2 order by 1, 2;
select code, name, price_fcfa, audience_types from company_plans order by position;   -- 'pro' = « Organisation », 'solidaire' présent
select count(*) from profiles where role::text = 'company' and not exists (select 1 from company_profiles c where c.owner_id = profiles.id);  -- comptes sans fiche (nom < 2 car.)

-- V5. Rattachements Département et équipes
select _dept_attachment_state(p.id) as etat, count(*) from profiles p where p.role::text = 'dept' group by 1 order by 1;        -- ok / none / unverified / ambiguous : à comparer à Q3
select count(*) filter (where assigned_by is null) as a_confirmer, count(*) from department_accounts;
select action, count(*) from department_assignment_history group by 1;
select m.team_code, cardinality(m.permissions) as nb_permissions, count(*) from admin_team_members m group by 1, 2 order by 1, 2;   -- attendu : nb_permissions = 0 partout
select action, count(*) from admin_team_history group by 1 order by 1;                                                          -- migration = reduce lignes avant suppression ; reduce = finance + 2 x support
select count(*) from notifications where title in ('Comptes Finance / Support à réviser', 'Comptes Département à rattacher');  -- 1 par administrateur actif

-- V6. Gardes à échec silencieux : chaque garde est bien posée (comparer au résultat de la répétition, pas à un chiffre absolu)
select count(*) filter (where prosrc ~ 'has_admin_permission|has_any_admin_permission|is_admin_team_member|_staff_perm') as fonctions_gardees_par_permission from pg_proc where pronamespace = 'public'::regnamespace;
select count(*) filter (where prosrc like '%_team_recipients%') as notifications_par_permission from pg_proc where pronamespace = 'public'::regnamespace;   -- >= 31
select count(*) from pg_policies where schemaname = 'public' and policyname like 'équipes : %' and permissive = 'RESTRICTIVE';      -- 23 (moins les tables absentes)
select tablename, policyname from pg_policies where schemaname = 'public' and tablename in ('plans','subscriptions','ad_campaigns','payout_batches','payment_transactions','payment_messages','event_receipts','cms_items','pickups','audit_log','profiles')
  and (coalesce(qual, '') like '%''direction''%' or coalesce(with_check, '') like '%''direction''%');                              -- attendu : 0 ligne (rôle direction retiré)
select policyname, tablename from pg_policies where schemaname = 'public' and qual like '%_staff_perm%' order by 2, 1;           -- >= 14 tables de K1-4

-- V7. 2FA : liste étendue
select prosrc ~ 'admin_team_member_set' as h4, prosrc ~ 'partnership_decide' as k1, prosrc ~ 'security_flag_resolve' as l3, prosrc ~ 'admin_dept_assign' as k1b from pg_proc where proname = 'enforce_mfa_on_sensitive';   -- tout vrai

-- V8. Libellés : plus aucun ancien libellé d'acteur
select proname from pg_proc where pronamespace = 'public'::regnamespace and (prosrc ilike '%Votre entreprise%' or prosrc ilike '%Entreprise vérifiée%' or prosrc ilike '%Réservé à la finance%');   -- attendu : 0 ligne

-- V9. Éligibilité vendeur et contraintes
select pg_get_constraintdef(oid) from pg_constraint where conname = 'shops_status_check';                -- contient 'paused'
select indexname from pg_indexes where indexname = 'departments_norm_name_key';                              -- NULL = doublons (Q4) : à traiter
select prosrc like '%seller_open%' as ad_feed_garde from pg_proc where proname = 'ad_feed';                 -- vrai

-- V10. Volumes inchangés (Q11) et planifications
select 'profiles' t, count(*) from profiles union all select 'listings', count(*) from listings union all select 'orders', count(*) from orders union all
select 'order_lines', count(*) from order_lines union all select 'shops', count(*) from shops union all select 'company_profiles', count(*) from company_profiles union all
select 'departments', count(*) from departments;                                                          -- identique à Q11 (company_profiles : + fiches créées par H1-4)
select jobid, jobname, schedule, active from cron.job order by jobid;                                       -- identique à Q11
```

Contrôles d'usage (hors SQL) : ouvrir l'application déployée et dérouler les parcours du document `H7_SCENARIOS_VALIDATION_CONNECTEE.md` avec des comptes de test ; consulter les journaux Postgres/API Supabase pendant 30 minutes (erreurs `permission denied`, `Réservé…`, `Accès refusé` anormales).

## 9. Opérations manuelles après migration (propriétaire / administrateur global)

1. **Rattacher les comptes Département** : écran « Départements — rattachements » de la console d'administration (`admin_dept_accounts`, `admin_dept_unassigned_accounts`, `admin_dept_assign`) pour chaque compte de Q3 non rattaché, `unverified` ou `ambiguous` (vérifier ou renommer d'abord le département) ; confirmer les rattachements « à confirmer » ; l'administrateur doit être en session **aal2** s'il a une 2FA (garde interne `_require_staff_aal2` et liste de `enforce_mfa_on_sensitive`).
2. **Revue des anciens comptes Finance / Support** : écran 305 « Équipes et permissions », liste « à réviser » (`admin_team_accounts_review`) ; pour chaque compte de Q5, **attribuer explicitement** les permissions (`admin_team_member_set`, aal2) ou confirmer les droits minimaux avec un motif (`admin_team_account_keep_minimal`) ; tant que ce n'est pas fait, plus aucune alerte d'équipe ne part à ces comptes. Attribution explicite des permissions d'équipe Sécurité et Technique pour les agents concernés (aucune n'est créée par la migration).
3. **Prévenir** : anciens `other` (devenus Organisation, fiche en brouillon à compléter), comptes Département non rattachés, vendeurs non éligibles de Q8 (vérifier le téléphone / l'étudiant).
4. **Vérifier la configuration externe** (inchangée par ce lot, à ne pas modifier) : URL de redirection Auth, `payments.manual_number`, secrets : ne rien lire ni changer des clés Notch Pay.
5. **Edge Functions** (§10).
6. **Comptes de test** : voir `H7_SCENARIOS_VALIDATION_CONNECTEE.md` (rattachement et permissions des comptes de test à faire explicitement).

## 10. Edge Functions

Comparaison `git diff c339d83f..HEAD -- supabase/functions` (c339d83f = commit qui apporte la migration 20261119070000) : **seulement deux fichiers modifiés, et uniquement des libellés** :
- `admin-test-accounts/index.ts` : noms de comptes de test « Test Organisation » et « Test Organisation (ancien rôle fusionné) ». **Point d'attention** : la fonction continue de créer un compte de rôle `other` par `upsert` (service role) ; le déclencheur `trg_a_profile_role_no_other` ne s'applique qu'aux `UPDATE of role`, pas aux insertions : un nouveau compte test `other` réapparaîtrait donc, malgré la fusion. Aucune modification de code dans ce lot ; à traiter dans un lot code.
- `tara-pay/index.ts` : messages « organisation » à la place de « entreprise » (aucune logique modifiée).

Aucun redéploiement n'est **nécessaire** au fonctionnement des migrations. Redéploiement facultatif (cosmétique) : `npx supabase@2.122.0 functions deploy admin-test-accounts --project-ref zxqcnmgwhtbxkdpjqtlr` (le réglage JWT actuellement servi pour cette fonction n'est pas connu du dépôt : vérifier avant, la fonction contrôle elle-même l'appelant) et `functions deploy tara-pay …` **avec** vérification du JWT (ne pas ajouter `--no-verify-jwt`, comme `pay`). Les fonctions `tara-webhook`, `notchpay-webhook`, `dispatch-notifications`, `auth-recovery`, `live-*`, `pay` ne sont pas modifiées depuis. Déployer sans Docker possible : `--use-api`.
Pas de modification d'un secret ; aucune clé Notch Pay lue.

## 11. Ordre d'exécution le jour J

1. Gel : dernier commit identifié, `git status` propre, suite de tests complète verte (lancée par le chef de projet, jamais en parallèle), manifeste du §1.2 figé.
2. Q0–Q11 (§6), puis répétition générale (§5) validée.
3. Sauvegarde (§4) + `sha256` + `pg_restore --list` ; Q1 de nouveau (aucune session bloquante).
4. Dossier de travail temporaire contenant **toutes** les migrations locales ; `npx supabase@2.122.0 link --project-ref zxqcnmgwhtbxkdpjqtlr --workdir <dossier>`.
5. **Dry-run** : `npx supabase@2.122.0 db push --linked --dry-run --workdir <dossier>` : la liste affichée doit être **exactement** le manifeste (mêmes noms, même ordre, même nombre), aucun fichier ≤ 20261119070000, aucun fichier en plus. Comparer par script (liste du CLI vs `$attendu.Name`) ; en cas d'écart, **arrêt**.
6. `npx supabase@2.122.0 db push --linked --yes --workdir <dossier>` (ordre des noms ; aucune application partielle manuelle).
7. Contrôles V1–V10 (§8) ; si un contrôle diffère de la répétition : décision selon §7.
8. Edge Functions éventuelles (§10).
9. Build web : `flutter build web --release --pwa-strategy=none` (PATH : `C:\Users\NITROV15\dev\flutter\bin`, Git, Node), puis dans `build/web` : `npx vercel link --yes --project boutik-ecole`, supprimer `.env.local` et `.gitignore` créés par le lien, `npx vercel deploy --prod --yes`.
   `web/vercel.json` est réglé sur `echo skip` : un push GitHub seul ne met **pas** le site à jour.
10. Vérifier la version servie : SHA-256 de `main.dart.js` local = servi (comparer au fichier téléchargé depuis le domaine de production).
11. Opérations manuelles (§9) puis parcours connectés (`H7_SCENARIOS_VALIDATION_CONNECTEE.md`) avec comptes de test.
12. Mettre à jour `docs/transformation/REPRISE_OPENCODE.md` (dernière migration appliquée, noms des sauvegardes) **après** application réelle seulement.

Règles transverses : aucune clé ni secret poussé ou affiché ; pas de paiement réel pendant la validation ; commit et push seulement après tests ; ne jamais interrompre un dump ; ne jamais modifier une migration déjà appliquée (ni `20261122*`).

## 12. Ce qui n'a pas pu être vérifié ici

- Aucun résultat SQL (aucune base, aucun accès production autorisé) : toutes les requêtes ci-dessus sont à valider sur la répétition générale ; leur syntaxe a été relue, pas exécutée.
- Le comportement transactionnel exact de `db push` (un fichier = une transaction) et la durée des verrous : à constater à la répétition.
- Les réécritures à motifs réussissent sur les définitions **du dépôt** (scénarios PGlite) ; leur réussite sur les définitions réelles de production n'est démontrée que par la répétition sur la copie restaurée.
- Le contenu exact des 36+ fonctions réécrites par H1-5 / K4-2 (nombre affiché par `NOTICE` à l'exécution).
- Les fichiers `20261123*` autres que celui nommé au §1.1 : non lus (inexistants à la lecture).

