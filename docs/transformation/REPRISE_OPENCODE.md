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
- Migrations de production : dossier de travail temporaire contenant TOUTES les migrations locales, `npx supabase@2.122.0 link --project-ref zxqcnmgwhtbxkdpjqtlr --workdir <dossier>`, sauvegarde `db dump --linked` (schéma puis `--data-only`) hors du dépôt (dossier `Downloads\boutik_sauvegardes_prod`), `db push --linked --dry-run` (doit lister exactement les fichiers attendus), puis `db push --linked --yes`. Dernière migration appliquée : `20261114004300` (14 novembre 2026). Pièges vécus : lancer le `db dump` en boucle puis l'interrompre laisse une session `pg_dump` « idle in transaction » côté serveur qui bloque `create trigger` (délai dépassé) : ne jamais interrompre un dump, et vérifier `pg_stat_activity` avant un `db push`. `db dump` demande Docker Desktop démarré (images à re-télécharger, environ 3 Go) ; en cas d'échec `EAUTHQUERY`, réessayer. `db query --linked -f fichier.sql` permet de lire la production sans mot de passe.
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

Migration `supabase/migrations/20261114004100_correctifs_profil_visiteur.sql` (appliquée en production le 14 novembre 2026, sauvegarde `prod_schema_20261114_avant_correctifs_visiteur.sql` et `prod_data_20261114_avant_correctifs_visiteur.sql`) : projets privés exclus de `iut_projects`, nom abrégé dans `duels_list`,
vues comptées une fois par compte et par jour (`view_seen`), note de modération d'annonce masquée, lecture directe de `posts.review_note`, `post_likes` et `post_boosts` retirée,
`unregister_all_devices`, `my_referral_code` enregistre enfin le code, paiement par messagerie (finance prévenue, `payments_to_verify`, commande marquée payée à la confirmation),
`company_subscription_request(p_plan, p_owner)`, `product_reviews`, `opp_save` (rôle client refusé, département prévenu), `create_community` (admin et support prévenus), notification du département à la soumission d'un projet.
Test SQL : `supabase/tests/marketplace_pglite/correctifs_visiteur.mjs` (`node replay.mjs all ./correctifs_visiteur.mjs`, attendu 28/28).
Edge Function `auth-recovery` : redéployée (v9, `--no-verify-jwt`) pour que l'envoi du code ne révèle plus l'existence d'un compte par le délai de réponse.

Migration `supabase/migrations/20261114004200_correctifs_visiteur_suite.sql` (appliquée en production le 14 novembre 2026 après 4100 ; `20261114004300` verrouille `block_suspended_author`. Fonction Edge `auth-recovery` redéployée en v9) : `current_role_name()` nul pour un compte suspendu, déclencheurs `trg_block_suspended` sur les écritures de contenu,
messages exacts de `create_post*`/`create_story`/`create_live`, rappels de date limite envoyés par `send_due_reminders()` (pg_cron toutes les 15 min ; vérifier que pg_cron existe, sinon les rappels ne partent pas) et non plus par `opps_list`/`anns_list`,
`public_sellers`, `seller_public(p_name, p_id)` (homonymes signalés), `public_projects` (catalogue public sans contacts), `opp_alert_set` désactivable sans filière, titres des collections synchronisés.
Test SQL : `correctifs_visiteur_suite.mjs` (attendu 26/26) ; `concours.mjs` (28) et `opportunites.mjs` (36) adaptés aux rappels planifiés.

## Correctifs du profil Client (15 novembre 2026) — APPLIQUÉS EN PRODUCTION LE 15 NOVEMBRE 2026

Migrations (ordre = ordre des noms) : `20261115000100_securite_client` (blocages, `public_profile`, `seller_public`, droits `profiles`, RLS `projects`, clé de `dispatch-notifications`), `000200_commandes_paiements_client` (`marketplace_checkout`, `cancel_order`, `expire_unpaid_orders` + cron, `payment_start`), `110000_l1` … `210000_l11` (un fichier par lot de fonctionnalités ; L10 en compte cinq), `220000_planification_cron` (`expire_subscriptions`, `send_event_reminders`), `220100_auth_recovery_durcissement` (`auth_throttle_*`, `auth_revoke_sessions`).
Test SQL : `node replay.mjs all ./<scénario>.mjs` avec TOUTES les migrations (`securite_client.mjs` 50/50, `l6_*` 39, `l11_*` 31, tous les scénarios existants verts).
ORDRE DE DÉPLOIEMENT : sauvegarde, `db push` (les migrations posent la clé interne et l'en-tête du cron), PUIS `dispatch-notifications` (`--no-verify-jwt`), puis `pay`, `notchpay-webhook`, `tara-pay`, `tara-webhook`, `auth-recovery`, puis le build web. Déployer `dispatch-notifications` avant les migrations arrête les envois (401).
Réglages externes : ajouter `cm.iutdouala.boutik_ecole://reset-callback/**` aux « Redirect URLs » de Supabase Auth ; renseigner `payments.manual_number` si le paiement manuel est proposé ; secrets IA / LiveKit / Twilio non fournis (Kéla, lives natifs) : non touchés.
État de production : dernière migration `20261115220100` ; sauvegarde `prod_schema_20261115_avant_correctifs_client.sql` et `prod_data_20261115_avant_correctifs_client.sql` ; fonctions déployées (`dispatch-notifications`, `notchpay-webhook`, `tara-webhook`, `auth-recovery`, `integrations-oauth` en `--no-verify-jwt` ; `pay` et `tara-pay` AVEC vérification du JWT, ne pas leur mettre `--no-verify-jwt`) ; 9 tâches pg_cron actives ; web servi identique au build local. À faire sur appareil : lien de réinitialisation Android, rendu de g_13 / g_153 / g_156 / g_159.

## Finalisation du profil Client (15 novembre 2026) — appliquée en production

Migrations : `20261116000100_mfa_serveur` (garde `enforce_mfa_on_sensitive` branchée par `alter role authenticator set pgrst.db_pre_request` : les RPC sensibles exigent une session aal2 si le compte a un facteur TOTP vérifié ; retour arrière dans le fichier), `20261116100000_evenements_payants` (`event_checkout`, réservation 30 min, `expire-event-holds` toutes les 10 min, confirmation par trigger ; `tara-pay` accepte `evt:<uuid>`), `20261116120000_droits_abonnements` (`seller_advanced_stats`, `company_team_access`, portfolio 300 éléments ; `visiteurs_profil`, `outils_vendeur_pro` et `gestion_communaute` retirés des plans), `20261116130000_createur_pro_non_vendable` (`createur_pro` reste fermé à la vente : à ouvrir par `update plans set sellable = true where code = 'createur_pro'`).
Edge Functions : `live-moderate` (nouvelle : expulsion, bannissement et coupure du micro réels dans la salle LiveKit ; `--no-verify-jwt`), `live-token` (comptes suspendus refusés, jeton spectateur 1 h), `tara-pay`. Déploiement sans Docker possible avec `functions deploy <nom> --use-api`.
Sauvegarde : `prod_schema_20261115_avant_finalisation.sql` et `prod_data_20261115_avant_finalisation.sql`.
Flutter : transport LiveKit natif (`live_transport_native.dart`, jamais exécuté sur appareil), filtre Services et commande réelle du showroom 207/208 (le panier 06 est réutilisé), paiement des événements (`evenements.dart`). Android : `POST_NOTIFICATIONS` ajoutée et `flutter_deeplinking_enabled=false` (le lien `cm.iutdouala.boutik_ecole://reset-callback` est traité par supabase_flutter, pas par le routeur).
Limites connues : le build Android (`flutter build apk`) échoue sur cette machine par expiration de la génération des accesseurs Kotlin DSL de Gradle (disque lent) : jamais validé ici, à refaire ailleurs ; Kéla exige le secret `ANTHROPIC_API_KEY` (absent) ; la 2FA serveur n'a pas été éprouvée avec une vraie session aal1 ; le remboursement d'une inscription payante à un événement est manuel.

## Profil Entreprise (16 novembre 2026) — branche `profil-entreprise`, NON appliquée en production

Acteurs officiels (`roleNames` de `lib/figma/live/access.dart`, 10) : Visiteur, Client, Étudiant-vendeur, Entreprise, Autre rôle, Responsable de département, Direction, Finance, Support, Administrateur global. Étudiés : Visiteur, Client, Étudiant (en cours, autre branche). Traité ici : **Entreprise**. Suivant : Autre rôle (`other`), puis Responsable de département.
Travail mené dans un worktree séparé (`../boutik_entreprise`, branche `profil-entreprise` issue de `cc266099`) pour ne pas toucher aux modifications non validées du profil Étudiant.
Audit : sonde de sécurité `supabase/tests/marketplace_pglite/audit_entreprise.mjs` (76 contrôles) : écritures directes (auto-vérification, publication d'offre, abonnement actif, ajout d'équipe, recrutement par le candidat), accès entre entreprises, étudiant/client sur les fonctions d'entreprise, entreprise non vérifiée ou suspendue, lectures directes des données privées (pièces, équipe, listes de talents, invitations, coordonnées). Résultat : aucune faille d'accès ; un défaut fonctionnel d'équipe et un écran de maquette.
Corrigé : (1) migration `20261118000100_equipe_entreprise_offres.sql` : `_opp_can(poster, écriture)` ; un membre actif « admin » peut fermer une offre, décider une candidature et changer le média ; « finance » et « viewer » consultent (candidatures, statistiques, liste) ; `opp_my_posted` et `opp_applications_for` renvoient `can_manage` (l'interface masque Clôturer et les décisions en lecture seule) ; publication (`opp_save`), invitations (`opp_invite`) et suggestions restent au propriétaire (`opp_invite` et `opp_suggested_students` sont redéfinies par les migrations du profil Étudiant : non touchées pour éviter un conflit). (2) Écran 89 « Profil de l'entreprise » : fiche, secteur, ville, tags, présentation, logo et compteurs réels ; photos et icônes d'exemple, texte « Télécommunications · Douala / Partenaire de l'IUT » et bouton « Suivre » (qui créait un faux abonnement `company:89` partagé) réservés à la démonstration ; « Publier un besoin » ouvre l'écran 90. (3) Espace entreprise d'un membre d'équipe : les cases Offres actives, Candidatures et Recrutés ouvrent `/opportunites/mes`.
À traiter dans le profil « Autre rôle » : `company_gate` ne s'applique qu'au rôle `company` ; un compte `other` publie des offres, besoins et concours sans vérification ni quota de forfait (limite de 10 offres par jour seulement). Écrans web 187 à 190 et 262 : pastilles « +3 », badge « 2 » et cartes de talents d'exemple de la maquette encore affichés hors démonstration (non corrigés ici : consoles web).
