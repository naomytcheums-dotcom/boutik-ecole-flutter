# 09 — Sauvegardes, supervision et conformité (phase 6)

## Sauvegardes réalisées (01/11, avant les migrations) — `%USERPROFILE%\boutik_backups\migrations_20261101_1119\`

| Fichier | Contenu |
|---|---|
| `prod_schema_avant.sql` (193 Ko) | schéma complet de la production |
| `prod_donnees_public_avant.sql` (38 Ko) | données du schéma `public` |
| `catalog_prod_avant.json` / `catalog_prod_apres.json` | instantanés des catalogues |
| `empreintes_avant.json` / `empreintes_apres.json` | 35 empreintes de données |
| `migrations_appliquees\` et `empreintes_migrations.txt` | les 4 fichiers appliqués et leur SHA-256 |
| `migration_list_avant.txt` / `_apres.txt`, `prod_dry_run.txt`, `prod_push.txt` | preuves de l'application exclusive |

Site : le dossier `site_20261101\` contient le build déployé. Le déploiement précédent (`dpl_5VXXmTvNUZzvaU9ZaokJ47SqcrJu`) permet un retour arrière immédiat dans Vercel.

## Retour arrière
- Chaque migration contient sa procédure de retour en commentaire.
- Les 4 migrations n'ajoutent que des objets, sauf 4 fonctions redéfinies dont les versions d'origine sont dans les migrations précédentes.

## Reste à faire
- **Sauvegardes automatiques** : vérifier dans le tableau de bord Supabase le plan (sauvegarde quotidienne, PITR). Cela n'est pas consultable avec nos accès.
- **Test de restauration** du schéma et des données sur une base jetable (procédure prête, non exécutée).
- **Supervision** : alertes Vercel et Supabase (erreurs 5xx, Edge Functions), consultation hebdomadaire de `audit_log`.
- **Conformité** (loi camerounaise n° 2024/017 sur les données personnelles) :
  - page de confidentialité et mentions légales ;
  - registre des traitements (comptes, commandes, adresses, parrainage) ;
  - durées de conservation ;
  - procédure d'export et de suppression d'un compte ;
  - consentement e-mail et SMS (déjà prévu dans la migration notifications).
