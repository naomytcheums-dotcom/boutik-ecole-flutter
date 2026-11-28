# H13.2 · Anciens médias de `post-media` : inventaire, bascule vérifiée, retour arrière

Agent 6 (administration, sécurité, données). Complète `H131_MATRICE_ACCES_MEDIAS.md` (conception de la bascule, politiques, Flutter). **La création de `post-media-private` ne migre rien** : les anciens fichiers restent dans `post-media` (public) tant que la procédure ci-dessous n'a pas été exécutée **par le propriétaire**. Aucun accès à la production n'a eu lieu pendant ce lot : tout est prouvé sur base de test et contre un faux serveur Storage.

## 1. État de production connu (lu en lecture seule par le chef, avant ce lot)

`post-media` = 17 objets : 13 publics, 1 en attente de validation, 1 histoire expirée, 2 orphelins. Décision proposée par catégorie (aucune n'est exécutée automatiquement) :

| Catégorie | Nb | Niveau | Traitement proposé |
|---|---|---|---|
| Contenu publié / couverture / logo | 13 | publique | **reste** dans `post-media` (URL publique voulue, les anciennes URL continuent de fonctionner) |
| Publication en attente de validation | 1 | en_attente_validation | **jamais basculée** (la publication peut être validée ; l'URL reste lisible par qui la connaît : limite résiduelle documentée, décision propriétaire §7) |
| Histoire expirée | 1 | restreinte (`story_expired`, non réversible) | bascule vérifiée vers `post-media-private`, puis suppression **humaine** de l'ancien fichier |
| Orphelins (jamais rattachés, > 24 h) | 2 | non_rattachee (`orphan`) | bascule avec `--orphans`, puis suppression humaine après contrôle |

## 2. Outils (code livré, testé, non exécuté en production)

| Fichier | Rôle |
|---|---|
| `supabase/migrations/20261130060200_h132_media_inventaire_verifie.sql` | RPC `media_inventory_objects` (une ligne par objet), `media_inventory_buckets`, `media_migrate_confirm_checked(chemin, sha256, taille)`, colonnes `media_migration.sha256` / `verified_size`. Lecture seule sauf la confirmation ; `service_role` uniquement. Additive, rejouable. |
| `tool/backup/media_lib.mjs` | Bibliothèque : client REST/Storage (nouvelles tentatives sur 5xx/429/réseau), inventaire, rapport anonymisé, bascule, retour arrière. **Ne contient aucun appel de suppression.** |
| `tool/backup/media_inventory.mjs` | Inventaire complet par objet (`--out`, `--orphans`) ou compteurs seuls (`--linked`). |
| `tool/backup/media_migrate_private.mjs` | Bascule (`--apply`, `--limit`, `--orphans`, `--state`, `--report`) et `--rollback`. **Dry-run par défaut.** |
| `tool/backup/media_tools.test.mjs` | Tests contre un faux serveur PostgREST + Storage local : `node --test tool/backup/media_tools.test.mjs`. |
| `supabase/tests/marketplace_pglite/h132_media.mjs` | Scénario SQL (PGlite) de l'inventaire et de la confirmation vérifiée, à la forme exacte de la production (17 objets). |

Variables d'environnement (jamais écrites dans un fichier, un rapport ou un journal) : `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Les rapports et le fichier d'état sont créés dans le répertoire courant : ne pas les ajouter au dépôt.

## 3. Procédure (propriétaire, dans l'ordre)

0. **Sauvegarde vérifiable** avant toute écriture : `tool\backup\backup_prod.ps1` (base) et export du compartiment `post-media` (tableau de bord Storage ou `supabase storage cp -r`), puis contrôle du nombre d'objets et des tailles. Appliquer d'abord les migrations (dont `20261130060200`, après celles de H13.1 déjà en production), puis seulement ensuite utiliser les outils.
1. **Inventaire (lecture seule)** : `node tool/backup/media_inventory.mjs --orphans --out media_inventaire.json`. Contrôler : 17 objets ; `par_confidentialite` = 13 publique / 1 en_attente_validation / 1 restreinte / 2 non_rattachee ; `eligibles_a_la_bascule` = 3 avec `--orphans`. Toute différence avec la production lue par le chef est à expliquer avant de continuer.
2. **Plan (dry-run, défaut)** : `node tool/backup/media_migrate_private.mjs --orphans` : affiche le nombre de fichiers éligibles, n'écrit rien (ni copie, ni file d'attente, ni référence, ni fichier d'état).
3. **Exécution** : `node tool/backup/media_migrate_private.mjs --apply --orphans --limit 50`. Pour chaque fichier : (a) mise en file côté base (`media_migrate_private_batch`), (b) copie par l'API Storage `/object/copy`, (c) relecture des octets **des deux compartiments**, taille **et** SHA-256 identiques, (d) seulement alors `media_migrate_confirm_checked` : la base revérifie la taille et le type, met à jour `post_media.storage_bucket`, enregistre l'empreinte et **marque** l'ancien fichier supprimable. Un écart d'empreinte ou de taille laisse la référence inchangée (état `mismatch`, code de sortie 1).
4. **Reprise sur incident** : relancer la même commande. Le fichier d'état (`media_migration_state.json`, identifiants d'objet seulement) et la file côté base évitent de refaire les fichiers confirmés ; une copie déjà présente est relue et vérifiée, pas recopiée.
5. **Contrôle** : relancer l'inventaire ; `media_migration_report()` doit donner `to_queue = 0`, `failed = 0`, `verified = 3`. Ouvrir une histoire/une publication concernée depuis un compte propriétaire, un compte tiers (refus) et la modération (accès) ; l'application lit alors l'URL signée (1 h) du compartiment privé.
6. **Seulement après contrôle et accord du propriétaire** : supprimer **à la main** les anciens fichiers listés par `media_old_deletion_candidates()` (histoire expirée : non réversible ; les orphelins sont réversibles, donc listés avec `media_old_deletion_candidates(true)`). C'est cette suppression, et elle seule, qui ferme l'ancienne URL publique. **Aucun script ne supprime.**

## 4. Retour arrière

- Un fichier : `node tool/backup/media_migrate_private.mjs --rollback --path <chemin> --apply` ; tous : `--rollback --all --apply` (dry-run sans `--apply`). La base repasse `post_media.storage_bucket` à `post-media` ; la copie privée est **conservée**. Refusé si l'ancien fichier a déjà été supprimé : recopier d'abord depuis `post-media-private` vers `post-media` (copie Storage), puis rejouer.
- Complet (migrations) : voir les en-têtes de `20261129010000` à `20261129010200` et `20261130060200` (suppression des fonctions ; la colonne `sha256` nullable peut rester).
- Données : la sauvegarde de l'étape 0 est la référence ultime ; la procédure n'écrit que des copies et des lignes de suivi.

## 5. Garanties démontrées (tests)

- Rapport sans donnée personnelle : identifiants `obj-<12 hex>` = empreinte du chemin ; aucun chemin, nom de fichier, identifiant de compte, URL ni clé (test d'absence sur le rapport, le fichier d'état et les journaux). Le propriétaire retrouve un objet en calculant `sha256(chemin)`.
- Vérification : copie corrompue **de même taille** détectée par l'empreinte, référence non modifiée, les autres fichiers continuent.
- Dry-run : aucun appel d'écriture, aucun fichier créé. `--apply` explicite.
- Aucune suppression : aucun appel `DELETE`/`remove` émis ; 17 objets toujours présents dans `post-media` après bascule.
- Publics et « en attente » : jamais en file, jamais copiés, référence inchangée.
- Résilience : 503/500 transitoires réessayés, panne persistante d'un fichier isolée, reprise sans recopier, mauvaise clé refusée sans écriture.
- SQL : `h132_media.mjs` (34 OK / 0 ECHEC) : droits (client, étudiant, anonyme refusés), forme 17 = 13/1/1/2, motifs, pagination, empreinte invalide/NULL/majuscule refusée, taille incohérente → `failed`, `missing_destination`, rien de supprimé, rejeu de la migration.

## 6. Ce qui ne peut être prouvé que contre Supabase réel

(a) Que `/object/copy` conserve contenu, type et taille entre compartiments ; (b) que `GET /storage/v1/object/public/post-media-private/…` est refusé et que l'API authentifiée applique les politiques ; (c) l'état réel des 17 objets (le chef l'a lu ; l'inventaire par objet doit le confirmer) ; (d) la forme exacte des métadonnées `size` / `mimetype` de `storage.objects` en production (les RPC lisent `metadata->>'size'` et `'mimetype'`, comme `media_migrate_confirm` de H13.1).

## 7. En attente d'une décision du propriétaire

1. Suppression des anciens fichiers (étape 6) : jamais automatique.
2. Publication **en attente de validation** : son média reste dans `post-media` (URL lisible par qui la connaît). Faire passer ces envois par le compartiment privé jusqu'à la validation est un chantier distinct.
3. Orphelins : confirmer qu'ils peuvent être déplacés puis supprimés (ils peuvent être des brouillons que l'utilisateur n'a pas encore rattachés ; seuls ceux de plus de 24 h sont éligibles).

## 8. Autres compartiments (Storage, tous inspectés)

Politiques `storage.objects` des 13 compartiments relues et rejouées par `h132_admin.mjs` (B1 à B5) : aucun dépôt dans le dossier d'un autre compte, aucun dépôt anonyme, compartiments privés illisibles pour un tiers/anonyme, aucune modification de fichier d'autrui dans les compartiments publics. Correctif `20261130060100` : politique **restrictive** `H13.2 session ouverte` (compte suspendu / session fermée refusés par Storage, `service_role` non concerné) et lecture du dossier propriétaire sur `avatars`, `portfolio-media`, `project-media`, `listing-videos` (sans quoi la suppression de son propre fichier public n'avait aucun effet : l'API lit la ligne avant de la supprimer). Non vérifié en conditions réelles : comportement exact de l'API Storage sur ces deux points.
