# H13 — Sauvegarde, chiffrement et restauration de contrôle (Boutik-École, production Supabase `zxqcnmgwhtbxkdpjqtlr`)

Rédigé le 25 novembre 2026. Tout ce qui est décrit ici a été **exécuté** sauf mention contraire ; rien n'a été modifié en production (lectures seules).

## 1. État des sauvegardes

| Élément | Statut | Détail |
|---|---|---|
| Données `public` (JSON) | Terminé et vérifié | 309 tables, 689 lignes au moment de la sauvegarde H12 (avant les migrations `20261127*`) |
| Structure complète (JSON) | Terminé et vérifié | 1 284 fonctions, 235 politiques, 138 déclencheurs, colonnes, droits, historique des 265 migrations, compartiments |
| Auth (comptes, identités, facteurs MFA) | Terminé et vérifié | 26 comptes, 26 identités, 2 facteurs ; **contient des empreintes de mots de passe** : conservé uniquement chiffré |
| Storage (fichiers) | Terminé et vérifié | 15 objets, 67 Mo, taille de chaque fichier comparée aux métadonnées |
| `pg_dump` natif PostgreSQL | **Impossible avec les droits actuels** | voir §5 |
| Sauvegardes automatiques Supabase (quotidiennes / PITR) | Non vérifiable depuis ici | à contrôler dans le tableau de bord (Database → Backups) ; dépend du plan |

Emplacement (hors dépôt Git) : `C:\Users\NITROV15\Downloads\boutik_sauvegardes_prod\`
- `sauvegarde_20261125_avant_h12.enc` : archive chiffrée (AES-256-GCM, clé dérivée PBKDF2-SHA256 600 000 itérations) contenant les données, la structure, Auth + métadonnées Storage et les 15 fichiers. SHA-256 : `5DF74293763FE817B0BB74E663F3EC4D49D79FE3099CDF1B70765326C253FF98`.
- `prod_donnees_public_20261125_avant_h12.json` et `prod_structure_complete_20261125_avant_h12.json` : copies en clair (sans mot de passe, mais données personnelles : dossier à accès restreint).
- `_cle\phrase_secrete_sauvegardes.txt` : phrase secrète de l'archive. **À copier dans un gestionnaire de mots de passe hors de cet ordinateur puis à ne pas laisser seule sur la machine** : sans elle l'archive est irrécupérable.
- Permissions : le dossier n'est accessible qu'à l'utilisateur Windows, à SYSTEM et aux administrateurs locaux (héritage retiré).
- **H13.1 (27/11)** : les 38 anciennes sauvegardes en clair (SQL du 4 au 17 novembre, JSON des 21 au 27 novembre) ont été regroupées dans `sauvegarde_historique_20261104_a_20261127.enc` (4,2 Mo, SHA-256 `5EDF730CC11DA65CEF186E2F1E4521A1D66356776DD28243AB3B24BD87ECBA72`). L'archive a été déchiffrée et les 38 fichiers comparés par SHA-256 à l'original (38/38 identiques) **avant** de supprimer les copies en clair. Deux sauvegardes de schéma vides (échecs anciens, 0 octet) ont aussi été supprimées. Il ne reste plus aucune sauvegarde de données en clair dans le dossier, hors `_cle`.
- Une sauvegarde plus récente (`apres_h13`, produite le 27/11 par `backup_prod.ps1`) sert aux répétitions de migration ; elle est dans `C:\tmp\h131\bk_now` (temporaire, hors dépôt) et sera chiffrée avant toute publication.

Les copies en clair des comptes Auth et des fichiers Storage ont été **supprimées** après vérification du déchiffrement (empreintes identiques).

## 2. Vérifications effectuées

1. **Intégrité** : JSON valides, clés attendues, 15 fichiers Storage de la taille enregistrée (`tool/backup/restore_drill.mjs`, étape 1).
2. **Déchiffrement** : l'archive chiffrée est déchiffrée et chaque fichier est identique (SHA-256) à l'original ; une mauvaise clé est refusée (« authentication tag did not match »).
3. **Restauration de contrôle en environnement isolé** (PGlite, aucune connexion réseau) : base vierge reconstruite avec les 286 migrations, rechargement des 689 lignes de 309 tables, comptage table par table identique, aucune colonne de production absente de la reconstruction : **9 OK, 0 échec**, y compris à partir de la copie déchiffrée.
4. **Réutilisabilité** : `tool/backup/backup_prod.ps1` refait la sauvegarde complète (testé le 25/11 : 347 tables, 721 lignes, 1 497 fonctions, 15 fichiers Storage OK).

## 3. Écart production / dépôt découvert pendant la restauration de contrôle

La comparaison des 664 index de production avec la reconstruction locale ne montre **qu'une différence** : l'index `profiles_phone_verified_uk` (migration `20261117990100`, unicité des 9 derniers chiffres d'un téléphone vérifié) **n'existe pas en production**. Cause : deux profils vérifiés de production (un étudiant et un administrateur) partagent les mêmes 9 derniers chiffres : l'index ne peut pas être créé tant que la donnée n'est pas corrigée. Aucune donnée n'a été modifiée. Action de l'administration : décider quel compte garde le numéro, corriger l'autre puis créer l'index ; en attendant, la garantie d'unicité des téléphones vérifiés n'est pas appliquée côté base (seul l'index d'unicité exacte `profiles_phone_key` l'est).

### 3 bis. Comparaison de la structure (H13.1) : écart sur les politiques RLS

`restore_drill.mjs` compare désormais (étape 7) fonctions, politiques, déclencheurs et index de la sauvegarde à la base reconstruite à partir des seules migrations listées dans la sauvegarde. Sur la sauvegarde H13 : 12 OK, 1 échec (politiques introuvables). Cause : 10 politiques de production portent un nom **sans accents** (ex. « profil cree a l inscription ») alors que les migrations du dépôt suppriment et recréent des politiques **accentuées**. Les `drop policy if exists "<nom accentué>"` des migrations H1, H2 et H13 n'ont donc rien supprimé en production, et les anciennes politiques (permissives, cumulées en OU) sont restées actives :

- `kiosk_sessions` : deux politiques ouvertes à tout compte connecté (fermeture H13 inopérante) ;
- `listings` : l'ancienne politique de lecture publique coexiste avec la nouvelle (isolation Département inopérante en lecture) ;
- `profiles` : l'ancienne politique d'insertion accepte encore le rôle `other`.

Correctif : migration `20261129900000_h131_alignement_politiques_production.sql` (idempotente : supprime les doublons, renomme les autres) ; répétée sur une copie restaurée de la production (0 échec, aucune ligne perdue) ; scénario `h131_alignement_politiques.mjs` : 16 OK. **Non appliquée en production tant que le lot n'est pas publié.** `rehearse_migrations.mjs` recrée maintenant toutes les politiques de production depuis la sauvegarde avant de rejouer les migrations en attente : une répétition faite uniquement avec les migrations du dépôt n'est pas fidèle.

## 4. Procédure de restauration

### 4.1 Restauration de contrôle (sans risque, à répéter après chaque grosse migration)
```
node tool/backup/restore_drill.mjs <dossier_sauvegardes> <suffixe> <chemin_node_modules_pglite>
```
Pour une archive chiffrée : déchiffrer d'abord dans un dossier temporaire (§4.2), lancer le contrôle, puis supprimer le dossier temporaire.

### 4.2 Déchiffrer une archive
```
pwsh tool/backup/protect_backup.ps1 -Mode decrypt -Source sauvegarde_XXXX.enc -Output <dossier_temporaire> -KeyFile <fichier_phrase_secrete>
```
(sans `-KeyFile`, la phrase secrète est demandée à l'écran).

### 4.3 Restauration réelle après incident (à faire avec le propriétaire, jamais par-dessus des données saines)
1. **Ne rien supprimer** dans la production endommagée : créer d'abord un **nouveau projet Supabase** (ou utiliser la restauration PITR / sauvegarde du plan Supabase si disponible : c'est la voie la plus fiable).
2. Appliquer sur le nouveau projet **toutes** les migrations du dépôt dans l'ordre (`supabase db push`) pour recréer schéma, fonctions, politiques et déclencheurs.
3. Retirer l'index `profiles_phone_verified_uk` s'il bloque (voir §3).
4. Recharger les données `public` depuis `prod_donnees_public_*.json` : pour chaque table, `insert into public."<table>" overriding system value select * from jsonb_populate_recordset(null::public."<table>", '<json>')` avec `set session_replication_role = replica` pendant le chargement (comme dans `restore_drill.mjs`), puis réaligner les séquences : `select setval(pg_get_serial_sequence('public."<table>"', '<col>'), coalesce(max(<col>),1)) from public."<table>"` pour chaque colonne identité.
5. Auth : recréer les comptes à partir de la section `users` / `identities` / `mfa_factors` de l'archive (import via l'API d'administration Auth ou SQL avec le rôle `supabase_auth_admin`) ; les empreintes de mots de passe sont conservées, les utilisateurs gardent leurs mots de passe. Vérifier ensuite qu'il y a autant de comptes que de profils.
6. Storage : recréer les compartiments (liste dans la structure) puis téléverser chaque fichier avec le même nom (`<compartiment>__<chemin>` dans l'archive) et les mêmes métadonnées.
7. Redéployer les Edge Functions (`supabase functions deploy ...`) et reposer les secrets (jamais stockés dans la sauvegarde : à retrouver dans le coffre du propriétaire).
8. Vérifier : nombre de lignes par table, `select count(*)` des tables sans RLS = 0, connexion d'un compte de test, ouverture d'un fichier Storage.
Cette procédure complète sur un projet neuf n'a **pas** été rejouée (aucun projet Supabase de test disponible) : seule la partie données/structure l'a été (§2.3).

## 5. Sauvegarde PostgreSQL native (`pg_dump`) : ce qui manque
La CLI Supabase se connecte avec un rôle temporaire (`cli_login_postgres`) qui n'a pas le droit de lire les tables (`permission denied for table profiles`) : `pg_dump` échoue, schéma comme données. Il manque **le mot de passe de la base** (rôle `postgres`). Pour l'obtenir : tableau de bord Supabase → Project Settings → Database → Connection string (ou « Reset database password » : **opération du propriétaire**, elle change le mot de passe utilisé par d'éventuels services directs). Ensuite, sur une machine où PostgreSQL 17 est installé :
```
$env:PGPASSWORD = '<mot de passe>'      # ne jamais l'écrire dans un fichier ni l'envoyer
pg_dump -Fc -h aws-1-eu-west-3.pooler.supabase.com -p 5432 -U postgres.zxqcnmgwhtbxkdpjqtlr -d postgres -n public -n auth -n storage -f prod_YYYYMMDD.dump
pg_restore --list prod_YYYYMMDD.dump | Select -First 20      # vérification
```
Puis chiffrer avec `protect_backup.ps1`. Tant que ce mot de passe n'est pas fourni, la sauvegarde logique JSON (§1) est la sauvegarde exploitable disponible : elle ne contient ni séquences, ni rôles, ni extensions (à recréer par les migrations).

## 6. Compte Vercel : 2FA
Vercel signale à chaque déploiement que le compte du propriétaire n'a pas la double authentification activée. **Je ne peux pas l'activer** (action du propriétaire, dans un navigateur) : https://vercel.com/account/settings/authentication → « Authenticator app » (et conserver les codes de secours). Statut : **bloqué par une intervention du propriétaire**.
