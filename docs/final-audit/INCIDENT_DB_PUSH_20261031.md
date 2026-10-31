# Incident du 31/10 — échec de `supabase db push` sur `20261029_p0_securite.sql`

Erreur signalée : `ERROR: function gen_salt(unknown) does not exist (SQLSTATE 42883)` à l'instruction 16.
Diagnostic **strictement en lecture seule** (`tool/audit/prod_readonly_probe.py` : un seul SELECT/WITH, dans `begin transaction read only`), vers 13 h 55-14 h 05 (heure de Paris).
Aucune écriture, aucune nouvelle tentative, aucun `migration repair`.

Légende : **[F]** fait vérifié · **[H]** hypothèse · **[I]** inconnu.

## Chronologie (identifiants de transaction `xmin`, heures UTC)

| xid | Événement |
|---|---|
| ~1245-1246 | 29/10 : neutralisation manuelle des 8 comptes de démonstration (état actuel de leurs lignes) |
| 2164-2175 | 08:31-08:32 : 2 comptes `zz-test-prod` créés par la régression navigateur |
| 2183-2184 | 12:32:43 : connexion du compte `test1@…` (sans rapport avec `p0`) |
| **2187** | création de `supabase_migrations.schema_migrations` par `db push` (**seule trace validée**) |
| 2188-2235 | aucune ligne validée dans `auth.users`, `auth.sessions`, `auth.identities`, `profiles`, `audit_log` ni dans le catalogue `public` |

## Constats

1. **[F] La transaction de `p0` a été entièrement annulée.**
   - Catalogue `public` + stockage + droits comparé à l'instantané de 08:41 (avant le push) : **0 écart sur 13 catégories** (tables 21, colonnes 174, fonctions 36 avec empreintes md5 des corps, EXECUTE 36, politiques 38, déclencheurs 7, contraintes 94, index 32, enums 2, compartiments 2, extensions 5, droits 30).
   - `create_order` et `protect_profile_authority` ont gardé la version de `30c`/`30b` (empreinte md5 inchangée, `xmin` anciens 873/906). Si `p0` avait été validée, elles seraient revenues à la version de `p0`, qui est différente.
   - Le déclencheur `trg_protect_profile` (oid 17849) et la politique `profil modifiable par soi` (oid 17811) sont les objets d'origine : `drop`/`create` aurait changé l'oid et le `xmin`.
   - L'instruction précédant l'échec (`update profiles … where email in (8 comptes)`) aurait créé de nouvelles versions de lignes : leur `xmin` est resté ~1246 (29/10).
2. **[F] Les 8 comptes sont intacts.** Pour chacun : `banned_until = 2999-01-01`, mot de passe présent au format bcrypt (`$2…`, valeur non lue), `updated_at` et `last_sign_in_at` du 29/10, `xmin` ~1245. Profils `role = client`, `suspended = true`. 0 session.
   Identifiants : `6ad405f7…` (admin@boutik-ecole.cm), `715f0793…` (carine@), `b41d5792…` (contact@orange.cm), `9e4b5b0d…` (direction@), `3e190dd0…` (finance@), `9487bb69…` (mariam@), `b26f4f84…` (mbarga@), `8d8dc8f9…` (support@).
3. **[F] `20261030_webhook_paiement.sql` n'a pas été exécutée par le push.** `schema_migrations` contient **0 ligne** ; la table `payment_events` est d'origine (`xmin` ancien, 5 colonnes, 0 ligne). Elle était déjà en place avant (exécution manuelle du 30/10).
4. **[F] `pgcrypto` 1.3 est installé dans le schéma `extensions`** : `extensions.gen_salt(text)`, `gen_salt(text, integer)`, `crypt(text, text)`, `gen_random_bytes(integer)`, `digest(…)`.
   - Le rôle `postgres` a `search_path = "$user", public, extensions` ; le rôle de connexion de la CLI, `cli_login_postgres`, n'a **aucun** `search_path` configuré.
   - **[H]** `db push` exécute les migrations dans une session dont le `search_path` ne contient pas `extensions` ; l'appel non qualifié `gen_salt('bf')` (seul appel `pgcrypto` hors fonction des 16 fichiers) est donc introuvable.
   - Les appels `pgcrypto` de 31a/31b/31c sont tous dans des fonctions `set search_path = public, extensions` et ne sont pas concernés.
5. **[F] Seule modification persistante : le schéma `supabase_migrations` et la table `schema_migrations` (vide)**, créés par la CLI dans une transaction séparée avant l'application de `p0`. Elle n'a aucun effet sur l'application. Ne pas la supprimer sans décision.
6. **[F] Données** (comptages exacts) : 55 utilisateurs (53 ce matin + 2 `zz-test` de la régression), 54 profils (28 `client`, 26 `student`, aucun rôle du personnel), 2 facteurs MFA, 11 annonces (catalogue de la plateforme), 0 commande, 0 `payment_events`, 18 engagements, 86 entrées d'audit (les plus récentes : 2 connexions des comptes `zz-test` à 08:31-08:32). Aucune session ni transaction restée ouverte.
7. **[I]** Journal détaillé du push (instructions exécutées avant l'erreur) : non accessible sans les journaux de la plateforme ; l'absence de toute trace validée le rend sans conséquence.

## Correction de l'audit précédent

Le rapport d'audit indiquait « `p0` rejouable » : c'était vrai dans `psql` connecté en `postgres`, dont le `search_path` contient `extensions`. Avec la CLI (`db push`), `p0` échoue sur `gen_salt`.
La recommandation reste valable et se trouve renforcée : `p0` ne doit **jamais** être rejouée ; elle doit être enregistrée comme appliquée (régularisation de l'historique, rapport §8), sur autorisation.
