# Audit de régularisation des migrations Supabase — 31/10

Projet de production : `zxqcnmgwhtbxkdpjqtlr` (West EU, Paris).
Périmètre : `supabase/migrations` (15 fichiers d'origine + correctif `20261031c` écrit pendant cet audit), sauvegarde `supabase/migrations_backup_20261031`.

**Aucune écriture n'a été faite en production.** Toutes les requêtes distantes passent par
[`tool/audit/prod_readonly_probe.py`](../../tool/audit/prod_readonly_probe.py), qui n'accepte qu'un
`SELECT`/`WITH` unique et l'exécute dans `begin transaction read only; … commit;`.
Le schéma a été lu par `pg_dump --schema-only` (lecture seule) via `npx supabase db dump --linked`.
Ni `db push`, ni `migration repair`, ni renommage, ni suppression n'ont été effectués.

Légende utilisée pour chaque conclusion :

- **[F] Fait vérifié** : constaté par une requête, une comparaison ou un test reproductible.
- **[H] Hypothèse** : déduction plausible non démontrée.
- **[I] Inconnu** : information impossible à établir avec les accès disponibles.

---

## 1. Méthode et outils (reproductibles)

| Outil | Rôle |
|---|---|
| `tool/audit/prod_readonly_probe.py` | requête en lecture seule sur `linked` (production) ou `local` (Docker) |
| `tool/audit/catalog_snapshot.py` | 15 instantanés de catalogue : tables, colonnes, fonctions (md5 du corps), politiques, déclencheurs, contraintes, index, enums, compartiments, extensions, droits de table, droits de colonne, EXECUTE, nombre de lignes, configuration auth |
| `tool/audit/stage_snapshots.py` | base locale vierge : `schema.sql`, puis chaque migration une par une, instantané après chaque étape |
| `tool/audit/migration_audit.py` | delta de chaque migration (objets ajoutés, modifiés, supprimés) comparé à l'instantané de production |
| `tool/audit/build_prod_replica.py` | réplique locale **exacte** de la production (dump + compartiments + politiques de stockage + droits), comparaison catalogue ; `--with-pending` applique ensuite 31a → 31b → 31c |

Statuts de comparaison (par objet du delta) : `identique` (même définition en production),
`ulterieure` (la production a la version d'une migration suivante), `different`, `absent`,
`retire` (objet supprimé par la migration et effectivement absent en production).

---

## 2. Inventaire des fichiers

**[F]** Les 15 fichiers de la sauvegarde sont identiques octet pour octet aux fichiers de `supabase/migrations` (empreintes SHA-256 comparées).
**[F]** `npx supabase migration list --linked` ne reconnaît que `20261029` et `20261030` (format `<chiffres>_nom.sql`) ; les 13 autres sont ignorés car le préfixe contient une lettre (`20261029b_…`). La colonne « distant » est vide pour tous.

| # | Fichier | Taille | Nom reconnu par la CLI |
|---|---|---|---|
| 1 | `20261029_p0_securite.sql` | 6 498 | oui (version `20261029`) |
| 2 | `20261029b_p1_securite.sql` | 2 796 | non |
| 3 | `20261030_webhook_paiement.sql` | 773 | oui (version `20261030`) |
| 4 | `20261030b_profils_identite.sql` | 5 655 | non |
| 5 | `20261030c_annonces_stock.sql` | 13 304 | non |
| 6 | `20261030d_messagerie_notifications.sql` | 10 531 | non |
| 7 | `20261030e_messagerie_non_lus.sql` | 1 851 | non |
| 8 | `20261030f_liste_conversations.sql` | 1 753 | non |
| 9 | `20261030g_messagerie_commande_pieces_jointes.sql` | 6 777 | non |
| 10 | `20261030h_commandes_vendeur.sql` | 3 457 | non |
| 11 | `20261030i_avis_reclamations_signalements.sql` | 9 648 | non |
| 12 | `20261030j_services_devis.sql` | 7 078 | non |
| 13 | `20261030k_engagements.sql` | 4 337 | non |
| 14 | `20261031a_missions_voeux_campagnes_certificats_bornes.sql` | 53 647 | non |
| 15 | `20261031b_parametres_fichiers_dossiers_cv_retrait.sql` | 25 266 | non |
| + | `20261031c_correctifs_securite_audit.sql` (nouveau, cet audit) | 22 011 | non (volontairement, voir §7) |

Remarque **[F]** : l'ordre lexicographique utilisé par la CLI place `20261030_webhook` **après** `20261029b` ;
c'est aussi l'ordre réel d'écriture. Les deux seuls fichiers reconnus ont des versions courtes (8 chiffres),
inférieures à tout horodatage à 14 chiffres futur : un fichier renommé `20261031120000_…` serait trié après eux.

---

## 3. Historique distant

- **[F]** Le schéma `supabase_migrations` **n'existe pas** en production (`select count(*) from pg_namespace where nspname='supabase_migrations'` → 0). Aucune migration n'a jamais été enregistrée par la CLI.
- **[F]** Conséquence : toutes les migrations présentes en production y ont été exécutées **manuellement** (SQL Editor), ce que confirme `INTERVENTIONS_PROPRIETAIRE.md`.
- **[F]** Un `db push` aujourd'hui créerait l'historique puis tenterait d'appliquer **tous** les fichiers reconnus (`20261029`, `20261030`), alors qu'ils sont déjà en place (§6.3).

---

## 4. Dépendances et ordre réel

```
schema.sql (base : profiles, listings, orders, order_lines, missions, favorites, hackathon_teams,
            kiosk_sessions, audit_log ; enum app_role ; current_role_name())
 └─ 20261029_p0        create_order, protect_profile_authority, trg_protect_profile ; retire 2 politiques d'insertion directe
     └─ 20261029b_p1   log_audit, protect_listing_status, trg_protect_listing
         └─ 20261030_webhook   payment_events
             └─ 20261030b      enum certification_status, request/decide_certification ; redéfinit protect_profile_authority
                 └─ 20261030c  listing_history, stock_movements ; redéfinit create_order, protect_listing_status ; cancel_order
                     └─ 20261030d  conversations, messages, notifications, is_participant, déclencheurs on_*
                         └─ 20261030e  start_conversation (redéfinie)
                             └─ 20261030f  my_conversations (v1), listing_contact
                                 └─ 20261030g  chat-files, my_conversations (v2 : type de retour changé), start_order_conversation
                                     └─ 20261030h  seller_orders, set_seller_order_status
                                         └─ 20261030i  reviews, claims, listing_reports
                                             └─ 20261030j  quote_requests
                                                 └─ 20261030k  engagements
                                                     └─ 20261031a  (dépend de profiles, orders, notifications, current_role_name, missions)
                                                         └─ 20261031b  (dépend de missions, mission_proposals, projects, certificates, orders)
                                                             └─ 20261031c  (redéfinit des fonctions de 31a et 31b)
```

Dépendances transverses **[F]** :
- Extensions : `pgcrypto` (`gen_random_bytes`, `digest`) — présente en production dans le schéma `extensions` ; les fonctions qui l'utilisent ont `search_path = public, extensions` dans 31b/31c.
- Enums : `app_role` (schema.sql), `certification_status` (30b). Aucune migration en attente n'ajoute de valeur d'enum.
- `notifications` (30d) est requis par 31a (missions, vœux, campagnes, projets) et 31b (invitations, fichiers).
- `is_mission_participant` (31b) est utilisé par la politique `missions` réécrite en 31c → 31c **doit** suivre 31b.
- `orders.pickup_code` (31b) est requis par `orders.pickup_attempts` / `confirm_pickup` (31c).

---

## 5. Comparaison migration par migration avec la production

Les compteurs proviennent de `migration_audit.py` (delta propre à chaque migration, comparé à l'instantané de production du 31/10).
Les droits EXECUTE et les droits de colonne sont exclus des compteurs (comparés séparément, §5.2).

| Migration | État local | État distant (prod) | Preuves |
|---|---|---|---|
| `schema.sql` | base | **appliqué avec noms de politiques sans accents** | 9 tables, 70 colonnes identiques ; 11 politiques présentes sous un nom ASCII (`un client cree sa mission`, `annonces approuvees visibles par tous`…) ; `current_role_name` « different » (fins de ligne) |
| `20261029_p0_securite` | fichier valide | **appliqué** | identique 6, ultérieure 1, différent 1 (`create_order`, remplacée par 30c), retiré 2 (politiques d'insertion directe absentes) |
| `20261029b_p1_securite` | nom ignoré | **appliqué** | identique 5 ; `protect_listing_status` « différent » = version 30c (commentaires seulement) |
| `20261030_webhook_paiement` | fichier valide | **appliqué** | identique 8 (table `payment_events`, index unique, contrainte) |
| `20261030b_profils_identite` | nom ignoré | **appliqué** | identique 13 |
| `20261030c_annonces_stock` | nom ignoré | **appliqué** | identique sauf `create_order` / `protect_listing_status` : corps égaux après normalisation des espaces et commentaires |
| `20261030d_messagerie_notifications` | nom ignoré | **appliqué** | identique 71, ultérieure 2 (redéfinis par 30e/30g) |
| `20261030e_messagerie_non_lus` | nom ignoré | **appliqué** | identique 1 |
| `20261030f_liste_conversations` | nom ignoré | **appliqué** | identique 3, ultérieure 1 (`my_conversations` v2 de 30g) |
| `20261030g_messagerie_commande_pieces_jointes` | nom ignoré | **appliqué** | identique 17 (compartiment `chat-files` et ses 4 politiques inclus) |
| `20261030h_commandes_vendeur` | nom ignoré | **appliqué** | identique 6 |
| `20261030i_avis_reclamations_signalements` | nom ignoré | **appliqué** | identique 73 |
| `20261030j_services_devis` | nom ignoré | **appliqué** | identique 37 |
| `20261030k_engagements` | nom ignoré | **appliqué** | identique 24 |
| `20261031a_missions_…` | nom ignoré, testé en local | **absent** (1 exception) | absent 306 / 311 objets : 12 tables, 111 colonnes, 23 fonctions, 16 politiques, 87 contraintes, 19 index, 1 déclencheur absents ; **droits `missions` déjà conformes** (identique 2) ; 3 politiques « retirées » (voir §5.1) |
| `20261031b_parametres_…` | nom ignoré, testé en local | **absent** | absent 162 / 162 : 7 tables, 53 colonnes, 13 fonctions, 10 politiques, 42 contraintes, 11 index, compartiment `project-files` |
| `20261031c_correctifs_…` | nouveau, testé sur réplique | **absent** (attendu) | dépend de 31a + 31b |

Contrôle global **[F]** : la réplique construite à partir du dump de production (`build_prod_replica.py`) et la production
ont **0 écart sur 13 catégories** du catalogue. La réplique est donc une base de test fidèle.

### 5.1 Modifications partielles et anomalies

1. **[F] Droits sur `missions` déjà retirés en production.** `INSERT/UPDATE/DELETE` sont absents pour `anon` et `authenticated` sur `public.missions`, exactement comme après la ligne 30 de 31a. Aucun autre objet de 31a n'existe (aucune table, aucune fonction, aucune contrainte `missions_status_chk`).
   - **[H]** Un `revoke` isolé a été exécuté à la main (par exemple lors d'un essai ou d'un durcissement manuel). Une exécution partielle de 31a dans le SQL Editor est peu probable : il exécute le script dans une seule transaction, une erreur annulerait aussi le `revoke`.
   - **[I]** Date et auteur de ce `revoke` (pas d'historique ni de journal d'audit DDL accessible).
   - Impact : aucun ; la ligne 30 de 31a est idempotente.
2. **[F] Noms de politiques sans accents.** La production a été créée avec une version de `schema.sql` dont les noms de politiques sont translittérés (`missions du client ou de l administration`, `un client cree sa mission`, `profil cree a l inscription`, `journal lisible par l administration`…). Le dépôt a toujours eu les noms accentués (vérifié dans l'historique Git).
   - Conséquence **[F]** : les `drop policy if exists "…accentué…"` de 31a ne trouvent rien en production. Sur la réplique, après 31a, la politique ASCII `missions du client ou de l administration` (SELECT) et `un client cree sa mission` (INSERT) **restent actives** à côté de la nouvelle politique. La politique SELECT héritée laisse lire les missions de tout client à l'administration — ce qui recoupe l'intention — mais rend la nouvelle politique sans effet restrictif. Corrigé par 31c (§7).
   - **[F]** Deux politiques permissives du `schema.sql` du dépôt (`journal alimenté…` INSERT sur `audit_log`, `validation par le département` UPDATE sans `WITH CHECK` sur `listings`) **n'existent pas** en production. Les tests locaux antérieurs, construits depuis `schema.sql`, étaient donc plus permissifs que la production. Corrigé dans 31c pour les environnements reconstruits depuis le dépôt.
   - **[I]** Outil ou personne ayant translittéré le script.
3. **[F] Corps de fonctions « différents »** (`create_order`, `protect_listing_status`, `current_role_name`) : écarts limités aux fins de ligne CRLF/LF et aux commentaires ; comparaison après normalisation → égaux.
4. **[F] Objet présent uniquement en production** : `rls_auto_enable()` + déclencheur d'événement `ensure_rls` (fonction de la plateforme Supabase activant RLS sur les nouvelles tables). Ne pas supprimer ; il ne gêne aucune migration (toutes les tables créées activent RLS explicitement).

### 5.2 Droits et données (production)

- **[F]** Données : 53 utilisateurs (dont 44 comptes `zz-test` créés par les tests de production), 0 compte personnel (`dept`, `admin`, `support`, `finance`), 2 facteurs MFA, 11 annonces, 0 commande, 0 `payment_events`, 0 objet de stockage.
- **[F]** Les 8 comptes de démonstration visés par `p0` sont déjà bannis.

---

## 6. Risques de réexécution

### 6.1 Rejouabilité fichier par fichier (sur la réplique, état = production)

**[F]** Chaque fichier a été rejoué seul sur la réplique (tests reproductibles avec `stage_snapshots.py`) :

| Fichier | Rejouable | Effet d'un rejeu |
|---|---|---|
| p0 | oui | **écritures de données** : `insert … on conflict do nothing` (catalogue, sans effet), `update auth.users set banned_until…, encrypted_password = <aléatoire>` sur 8 comptes de démonstration, `delete from auth.sessions` de ces comptes |
| p1, webhook, b, c, d, e, g, h, i, j, k | oui | `create or replace`, `if not exists`, `drop policy if exists` ; pas d'écriture de données |
| **f** | **non** | `my_conversations` a changé de type de retour en 30g → `ERROR: cannot change return type of existing function` |
| 31a, 31b, 31c | oui (31a/31b rejoués lors des reconstructions ; 31c rejoué sur une base qui l'avait déjà : sortie 0, seulement des `NOTICE … skipping`) | idempotents ; 31a/31b insèrent des données de référence avec `on conflict do nothing` (bornes, paramètres, modèles de notification) |

### 6.2 Conflits entre migrations

- **[F]** `f` ↔ `g` : `my_conversations` (voir ci-dessus). Ne jamais rejouer `f` seule.
- **[F]** `p0` ↔ `c` ; `p1` ↔ `c` ; `b` ↔ `p0` : redéfinitions successives de `create_order`, `protect_listing_status`, `protect_profile_authority`. Rejouer une migration ancienne **rétrograderait** la fonction (la production a la version la plus récente). Risque réel en cas de `db push` ou d'application dans le désordre.
- **[F]** 31c redéfinit `assign_mission`, `submit_milestone`, `decide_milestone`, `save_project` (31a) et `send_mission_message`, `register_file`, `my_pickup_code`, `confirm_pickup` (31b). Rejouer 31a ou 31b **après** 31c ré-ouvrirait les failles (§7). Ordre impératif : 31a → 31b → 31c.

### 6.3 Simulation `db push`

**[F]** `npx supabase db push --dry-run` contre la réplique locale (même état que la production, historique vide) :
il appliquerait `20261029_p0_securite.sql` puis `20261030_webhook_paiement.sql`. Donc :

- écritures sur 8 comptes `auth.users` réels (mots de passe régénérés, sessions supprimées) ;
- rien de 31a/31b/31c (noms ignorés).

**Conclusion : `db push` ne doit pas être utilisé tant que l'historique n'est pas régularisé (§8).**

---

## 7. Points de sécurité — 31a, 31b et corrections nécessaires

Tous les constats ci-dessous ont été démontrés par [`supabase/tests/security_31_rest.py`](../../supabase/tests/security_31_rest.py)
sur la réplique + 31a + 31b : **13/24 contrôles réussis → 10 défauts**. Avec 31c : **24/24**.

| Point | Constat | Classe | Correction (31c) |
|---|---|---|---|
| `assign_mission` (31a l.157) | pas de contrôle explicite `auth.uid() is null` ; la protection repose sur `current_role_name()`, qui renvoie `null` pour `anon` → refus effectif, mais implicite | **[F]** pas exploitable aujourd'hui ; défense en profondeur | `if auth.uid() is null then raise 'Connexion requise'` en tête |
| `submit_milestone` (31a l.171) | idem ; protection implicite par la jointure `author_id = auth.uid()` | **[F]** non exploitable | contrôle explicite ajouté |
| `decide_milestone` (31a l.186) | idem ; `client_id = auth.uid()` | **[F]** non exploitable | contrôle explicite ajouté |
| `save_project` (31a l.518) | un projet **`approved`** reste modifiable (titre, résumé, liens) **sans nouvelle validation** : il reste public avec un contenu non revu. Un projet `submitted` est modifiable pendant l'examen | **[F]** défaut démontré | `submitted` non modifiable ; `approved` modifié → repasse `submitted` + notification au département |
| `verify_certificate` (31a l.412, l.681-682) | `EXECUTE` accordé à `anon` ; renvoie nom du titulaire, département, empreinte, motif de révocation ; codes de 8 hexadécimaux (`md5(random())`, 32 bits) → énumérables | **[F]** ; exposition du nom = choix fonctionnel (vérification publique d'un certificat par QR) | codes à 16 hexadécimaux `gen_random_bytes(8)` (64 bits), contrainte acceptant 8 ou 16 pour les anciens ; exposition du nom conservée **[H : choix produit à confirmer]** |
| Politiques `missions` | sur la production, les politiques ASCII héritées restent actives après 31a (§5.1) ; nouvelle politique visible par le personnel au sens large | **[F]** démontré sur réplique | suppression des variantes accentuées **et** ASCII ; politique unique `missions : visibilité restreinte` (client, missions publiées pour les connectés, participants via `is_mission_participant`) |
| Droits directs `missions` | `INSERT/UPDATE/DELETE` déjà retirés en prod ; 31a les retire aussi | **[F]** conforme | — |
| `send_mission_message` / `register_file` (31b) | le personnel (`dept/admin`) était traité comme participant et pouvait écrire dans la messagerie privée d'une mission ; `p_file` pouvait référencer un fichier d'un autre utilisateur | **[F]** démontré | nouvelle fonction `is_mission_party` (client ou prestataire accepté uniquement) ; fichier attaché obligatoirement à l'expéditeur et à la mission |
| `my_pickup_code` / `confirm_pickup` (31b) | code de retrait par `random()` ; un code faux faisait `raise`, ce qui **annulait** l'écriture du journal d'audit (tentatives invisibles, pas de limite) | **[F]** démontré | `gen_random_bytes` ; `orders.pickup_attempts` ; renvoie `'incorrect'` et journalise ; blocage à 5 essais puis nouveau code |
| Fonctions de déclencheur | `EXECUTE` par défaut à `public` (donc `anon`) sur toutes les fonctions de déclencheur (`on_order_paid`, `log_audit`…) | **[F]** non exploitable via PostgREST (une fonction `returns trigger` n'est pas appelable en RPC), mais hygiène | `revoke execute … from public, anon, authenticated` ; déclencheurs toujours fonctionnels (testé) |
| `sync_order_cancelled` (31a l.632) | `search_path` non fixé | **[F]** | `set search_path = public` |
| Politiques permissives du `schema.sql` du dépôt | absentes en production, présentes sur toute base reconstruite depuis le dépôt | **[F]** | suppression (sans effet en production) |

Recommandations **non appliquées** (risque faible, à décider) :
- **[F]** `TRUNCATE/REFERENCES/TRIGGER` accordés par défaut à `anon`/`authenticated` sur les tables `public` (comportement standard Supabase ; PostgREST ne permet pas `TRUNCATE`). Une révocation globale est possible mais touche tout le schéma.
- **[H]** Limiter les champs de `verify_certificate` pour `anon` (masquer le motif de révocation) si le produit l'accepte.

---

## 8. Stratégie de régularisation de l'historique

Objectif : que `migration list --linked` reflète la réalité, sans réexécuter ce qui est déjà en production.
**Rien de ce qui suit n'a été exécuté. Chaque étape distante nécessite l'autorisation du propriétaire.**

1. **Renommage local** (sans effet distant) en horodatages à 14 chiffres, ordre conservé, sur une branche dédiée :
   `20261029_p0_securite.sql` → `20261029000000_p0_securite.sql`, `20261029b_…` → `20261029000100_…`, `20261030_webhook…` → `20261030000000_…`, `20261030b…k` → `20261030000100` … `20261030001000`, `20261031a/b/c` → `20261031000000/000100/000200`.
   Conserver `supabase/migrations_backup_20261031` comme référence.
2. **Vérifier** sur la réplique (`build_prod_replica.py`) : `npx supabase migration list --local` doit lister 16 versions, distant vide.
3. **Enregistrer comme appliquées** les 13 premières versions, **sans les exécuter** — avec autorisation :
   `npx supabase migration repair --linked --status applied 20261029000000 20261029000100 … 20261030001000`
   (crée `supabase_migrations.schema_migrations` et y insère les versions ; aucune exécution de SQL de migration).
   Alternative équivalente : insertion manuelle dans `supabase_migrations.schema_migrations` depuis le SQL Editor.
4. **Contrôle** : `migration list --linked` → 13 versions appliquées des deux côtés, 3 en attente (31a, 31b, 31c).
5. **Appliquer** 31a, 31b, 31c selon la procédure du §9, soit par `db push` (qui n'appliquera plus que les 3 en attente : vérifier d'abord avec `db push --dry-run`), soit au SQL Editor puis `migration repair --status applied` pour chacune.
6. **Option** : remplacer `schema.sql` par la base issue du dump de production (noms ASCII) afin que toute base reconstruite depuis le dépôt soit identique à la production.

Risques de cette stratégie :
- **[F]** Sans l'étape 3, un `db push` rejouerait `p0` (écritures sur `auth.users`).
- **[F]** Ne jamais marquer 31a/31b/31c comme appliquées avant leur exécution réelle.
- **[H]** Le renommage n'a aucun effet distant tant que rien n'est enregistré (historique vide aujourd'hui).

---

## 9. Procédure d'application future (31a → 31b → 31c)

Prérequis communs :
- Sauvegarde : `npx supabase db dump --linked -f backup_schema_<date>.sql` **et** `--data-only` (ou sauvegarde PITR de la plateforme).
- Répétition générale : `python tool/audit/build_prod_replica.py --with-pending` (dump frais de production → réplique → 31a, 31b, 31c), puis `python supabase/tests/run_all_local.py` → attendu **386/386**.
- Fenêtre calme ; prévenir les utilisateurs ; garder le SQL de retour arrière de chaque fichier (commentaires en fin de 31a et 31b).

### 31a — contrôles

Avant :
```sql
select to_regclass('public.mission_proposals') is null as absent_ok;                  -- true
select count(*) from pg_policies where tablename = 'missions';                         -- 2 (politiques ASCII)
select privilege_type from information_schema.role_table_grants
 where table_name = 'missions' and grantee = 'authenticated';                          -- pas d'INSERT/UPDATE/DELETE
```
Après :
```sql
select count(*) from pg_tables where schemaname = 'public' and tablename in
 ('mission_proposals','mission_milestones','wishes','campaigns','certificates','kiosks','kiosk_incidents',
  'kiosk_events','projects','project_steps','scheduled_lives','order_cancellations');  -- 12
select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public'
 and proname in ('save_mission','propose_on_mission','decide_proposal','assign_mission','submit_milestone',
  'decide_milestone','verify_certificate','issue_certificate','save_project','save_wish','save_campaign');  -- 11
select count(*) from kiosks;                                                           -- données de référence
```

### 31b — contrôles

Avant : `select to_regclass('public.mission_messages') is null;` → true ; `select count(*) from storage.buckets where id = 'project-files';` → 0.
Après : 7 tables (`api_keys`, `cv_links`, `department_invitations`, `files`, `institution_settings`, `mission_messages`, `notification_templates`) ; compartiment `project-files` **privé** (`public = false`) ; `select column_name from information_schema.columns where table_name = 'orders' and column_name = 'pickup_code';` → 1 ligne.

### 31c — contrôles

Avant : 31a et 31b appliquées (contrôles ci-dessus).
Après :
```sql
select policyname from pg_policies where tablename = 'missions';                       -- 1 : « missions : visibilité restreinte »
select count(*) from pg_proc where proname = 'is_mission_party';                       -- 1
select column_name from information_schema.columns where table_name = 'orders' and column_name = 'pickup_attempts';  -- 1
select count(*) from information_schema.routine_privileges rp join pg_proc p on p.proname = rp.routine_name
 where rp.grantee in ('anon','authenticated','PUBLIC') and p.prorettype = 'trigger'::regtype;  -- 0
```

Après les trois :
- Recharger PostgREST : `notify pgrst, 'reload schema';`.
- Tests de production : `npx playwright test production.spec.ts` (27 contrôles), puis les suites REST pointées vers la production avec des comptes `zz-test` (`BE_URL`/`BE_KEY` de production) : `lots_rest.py`, `lots2_rest.py`, `security_31_rest.py`.
- Comparaison : `python tool/audit/catalog_snapshot.py linked snap_prod_apres.json` puis comparaison à l'instantané de la réplique `--with-pending` (`catalog_snapshot.py local snap_replica.json`) → attendu 0 écart.

Retour arrière : blocs `-- rollback` en fin de 31a et 31b (suppression des tables et fonctions ajoutées) ; pour 31c, réappliquer les définitions de 31a/31b des fonctions concernées. Les tables ajoutées étant vides au moment de l'application, le retour arrière ne détruit aucune donnée existante.

---

## 10. Synthèse

| Conclusion | Classe |
|---|---|
| Les 13 premières migrations sont en production, définitions identiques | **[F]** |
| 31a et 31b sont absentes, sauf le retrait des droits d'écriture sur `missions` | **[F]** |
| L'historique distant n'existe pas ; la CLI ne voit que 2 fichiers | **[F]** |
| `db push` en l'état rejouerait `p0` (écritures sur des comptes) | **[F]** (simulation) |
| `20261030f` n'est pas rejouable | **[F]** |
| 31a appliquée telle quelle laisserait actives les politiques ASCII de `missions` | **[F]** (réplique) |
| 10 défauts de 31a/31b démontrés et corrigés par 31c (24/24) | **[F]** |
| Origine du `revoke` manuel sur `missions` et de la translittération de `schema.sql` | **[I]** |
| Le SQL Editor n'a pas exécuté 31a partiellement | **[H]** |

Opérations nécessitant l'autorisation du propriétaire : renommage + `migration repair` (§8), application de 31a/31b/31c (§9).
