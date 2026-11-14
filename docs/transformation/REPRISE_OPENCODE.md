# Reprise du travail (état au 4 novembre 2026)

Projet : application Flutter Boutik-École (mobile d'abord, web et tablette adaptés), Supabase, Vercel. Branche de travail : `transformation-ecosysteme-20261103`.

## Règles du propriétaire (à respecter)

- Mobile d'abord ; fond de l'écran jusqu'aux bords, jamais de cadre de téléphone ; boutons posés directement sur le fond.
- Ne jamais supprimer de contenu existant sans le dire. Données de maquette : conservées en démonstration (hors connexion au serveur) ; connecté, un vrai contenu remplace la maquette, et la maquette reste affichée tant qu'aucune donnée réelle n'existe (talents, fil du réseau social).
- Aucune clé ni secret poussé. Ne jamais lire ni modifier les clés Notch Pay.
- Chaque correction terminée : tests, commit, push, build, déploiement, vérification de la version servie.

## Procédures

- Tests : `flutter test -j 1 --exclude-tags golden` ; rendus de référence : `flutter test -j 1 --tags golden test/golden/screens_golden_test.dart` (ajouter `--update-goldens` pour les régénérer volontairement). Un fichier de tests à la fois si le disque est juste.
- Base locale isolée : conteneur Docker `supabase_db_boutik_local`. Tests SQL : `docker exec -i supabase_db_boutik_local psql -U postgres < supabase/tests/<fichier>.sql`.
- Migrations de production : dossier de travail temporaire contenant TOUTES les migrations locales, `npx supabase@2.122.0 link --project-ref zxqcnmgwhtbxkdpjqtlr --workdir <dossier>`, sauvegarde `db dump --linked` (schéma puis `--data-only`) hors du dépôt (dossier `Downloads\boutik_sauvegardes_prod`), `db push --linked --dry-run` (doit lister exactement les fichiers attendus), puis `db push --linked --yes`. Dernière migration appliquée : `20261104000300`.
- Déploiement : `flutter build web --release --pwa-strategy=none` (pas de cache hors ligne : les mises à jour arrivent tout de suite), puis dans `build/web` : `npx vercel link --yes --project boutik-ecole`, supprimer `.env.local` et `.gitignore` créés par le lien, `npx vercel deploy --prod --yes`, comparer le SHA-256 de `main.dart.js` local et servi. `web/vercel.json` est réglé sur `echo skip` : un push GitHub seul ne met PAS le site à jour.
- Pièges : disque souvent presque plein (suppression de `build/test_cache`, caches Flutter et journaux de session si besoin, jamais des sauvegardes) ; un test qui reste bloqué sur « loading » signale en général un disque plein ; dans le shell, éviter les apostrophes dans des here-documents (utiliser l'outil d'écriture de fichier).

## Ce qui est fait

Défilement tactile (menu du bas transmet les glissements), barres de défilement retirées, plein écran téléphone, consoles web adaptatives, profil (photo, pièces justificatives dans un compartiment privé, matricule saisi par l'étudiant, référentiel des établissements et départements avec propositions relues par l'équipe), talents publics et message direct pour proposer une mission, fil du réseau social réel, vidéos phares du profil (trois dernières vidéos publiées), menu du bas à cinq onglets avec pastille mobile cerclée d'argent, œil du mot de passe, filtres qui défilent, aucune lueur au toucher.

## Reste à faire (par ordre)

1. Écrans du réseau social hors 244 : 244b, 245, 246, 247, 248 et suivants à relier au serveur (publications, abonnements, enregistrements).
2. Onglet « Abonnements » du fil : relier au suivi (`follow`).
3. Catalogue : statuts « Disponible / Occupé » cohérents avec le modèle métier.
4. Formulaires : messages d'erreur rouges, espacements, écran de choix du profil « trop zoomé ».
5. Icônes photo et vidéo sans effet sur les écrans 48 (litige) et 58 (produit).
6. IA d'entretien dans Kéla : service côté serveur avec clé d'API (décision de coût à prendre par le propriétaire).
7. Établissements privés agréés : importer la liste officielle du MINESUP (PDF) ; départements : renseigner ou valider.
8. Application qui se fige après une action sur téléphone : cause non trouvée ; demander l'action exacte et lire la console du navigateur.
9. Vérification sur Android réel ou émulateur (jamais faite).
10. Environ 100 écrans ont encore des données de maquette sans source réelle (voir `ETAT_ECRANS.md`).

## Hub d'intégrations (9 novembre 2026)

Écrans 271, 280, P3, P5 = quatre vues d'un même hub (réseaux, productivité, collaboration, Mobile Money). Tout est décrit dans `docs/transformation/INTEGRATIONS_HUB.md`
(architecture, fonctions à déployer, secrets que le propriétaire doit fournir, limites officielles des API). Tests : `test/integrations`, scénario SQL PGlite
`supabase/tests/integrations_pglite/scenario.mjs` (voir son en-tête), tests Deno `supabase/functions/_shared/shared_test.ts`.
Aucune clé développeur n'existe encore : aucun échange réel avec un fournisseur n'a été exécuté.

## Correctifs du profil Visiteur (14 novembre 2026)

Migration `supabase/migrations/20261114004100_correctifs_profil_visiteur.sql` (NON appliquée en production : à pousser avec la procédure habituelle) : projets privés exclus de `iut_projects`, nom abrégé dans `duels_list`,
vues comptées une fois par compte et par jour (`view_seen`), note de modération d'annonce masquée, lecture directe de `posts.review_note`, `post_likes` et `post_boosts` retirée,
`unregister_all_devices`, `my_referral_code` enregistre enfin le code, paiement par messagerie (finance prévenue, `payments_to_verify`, commande marquée payée à la confirmation),
`company_subscription_request(p_plan, p_owner)`, `product_reviews`, `opp_save` (rôle client refusé, département prévenu), `create_community` (admin et support prévenus), notification du département à la soumission d'un projet.
Test SQL : `supabase/tests/marketplace_pglite/correctifs_visiteur.mjs` (`node replay.mjs all ./correctifs_visiteur.mjs`, attendu 28/28).
Edge Function `auth-recovery` : à redéployer (`--no-verify-jwt`) pour que l'envoi du code ne révèle plus l'existence d'un compte par le délai de réponse.

Migration `supabase/migrations/20261114004200_correctifs_visiteur_suite.sql` (NON appliquée en production, à appliquer après 4100) : `current_role_name()` nul pour un compte suspendu, déclencheurs `trg_block_suspended` sur les écritures de contenu,
messages exacts de `create_post*`/`create_story`/`create_live`, rappels de date limite envoyés par `send_due_reminders()` (pg_cron toutes les 15 min ; vérifier que pg_cron existe, sinon les rappels ne partent pas) et non plus par `opps_list`/`anns_list`,
`public_sellers`, `seller_public(p_name, p_id)` (homonymes signalés), `public_projects` (catalogue public sans contacts), `opp_alert_set` désactivable sans filière, titres des collections synchronisés.
Test SQL : `correctifs_visiteur_suite.mjs` (attendu 26/26) ; `concours.mjs` (28) et `opportunites.mjs` (36) adaptés aux rappels planifiés.
