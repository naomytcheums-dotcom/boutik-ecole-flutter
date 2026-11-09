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
