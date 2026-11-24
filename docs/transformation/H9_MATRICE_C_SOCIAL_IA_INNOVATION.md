# H9 — Matrice C : Creator Economy / Réseau social, Live, Kéla Translate, Innovation & PI, Innovations complémentaires, Kéla AI (CDC §9, 10, 11, 12, 15, 20)

Lot MATRICE C. Audit en lecture seule : **aucune modification de code**, aucun commit, aucun accès à la production. Point de départ : HEAD `90f48686`.
Méthode : pour chaque exigence atomique, lecture réelle de la chaîne UI (`lib/figma/live/*.dart`, écrans `g_xx`) → `Backend.*` / `Backend.rpc` / `functions.invoke` → RPC ou table SQL (RLS, `grant`/`revoke`) ou Edge Function → effet persistant, puis recherche du test qui la couvre. Les documents `docs/transformation/*.md` sont traités comme des **déclarations** : plusieurs sont périmés (voir « Écarts documentation/code »).

## Légende des états (consigne H9)
OP = chaîne complète + preuve · PART = partiel (manque précisé) · NV = présent mais non vérifié de bout en bout · MANQ = absent · EXT = dépend d'un service ou d'une décision externe (précisé) · DEC = décision du propriétaire requise.

**Portée de « OP »** : chaîne lisible dans le code **et** preuve automatisée dans le dépôt (scénario PGlite/SQL ou test Flutter avec faux serveur). Les scénarios n'ont **pas été rejoués dans ce lot** (RAM limitée, aucune exécution demandée) ; aucune vérification sur la production (`supabase/tests/live/*` exige `LIVE_PASSWORD`, non utilisé). Aucune ligne n'est « validée en production ».

## Abréviations de chemins
`L/` = `lib/figma/live/` · `M/` = `supabase/migrations/` (préfixe de date seul) · `F/` = `supabase/functions/` · `PG/` = `supabase/tests/marketplace_pglite/` · `PGR` = `supabase/tests/reseau_pglite/scenario.mjs` · `T/` = `test/`.
Migrations clés : **RSL** = `20261110000000_reseau_social_live` · **AV** = `20261113000000_reseau_avance` · **CO** = `20261113000100_duo_cohost_gif` · **GP** = `20261117070000_gardes_publications_communautes` · **G6** = `20261119060000_g6_reseau_visibilite` · **MOD** = `20261117071000_moderation_reseau` · **COM** = `20261103000100_communautes_notifications_sociales` · **COMT** = `20261114000900_communautes_types` · **COME** = `20261114001000_communautes_echanges` · **COMA** = `20261119060200_g6_communautes_adhesion` · **EV** = `20261105000000_evenements` · **EVP** = `20261116100000_evenements_payants` · **EVG** = `20261117050000_s5_evenements_gestion` · **L10L** = `20261115200200_l10_ateliers_lives` · **S6L** = `20261117060300_s6_duels_lives` · **L9** = `20261115190000_l9_projets_innovations`.

## Écarts documentation / code constatés (à corriger dans les documents)
1. `RESEAU_SOCIAL_LIVE.md` dit que le SDK `livekit_client` natif n'est « pas fait » : **faux au HEAD** — `pubspec.yaml` contient `livekit_client ^2.13.2` et `L/live_transport_native.dart` implémente le transport Android/iOS (jamais exécuté sur appareil).
2. `RESEAU_SOCIAL_LIVE.md` dit « pas de webhook LiveKit » (vrai) mais ne mentionne pas l'Edge Function `live-moderate` (kick/ban/mute) ni la co-diffusion (`live_cohosts`, migration CO) ni l'agenda/rappels (`lives_agenda`, `send_live_reminders`).
3. `IMPLEMENTATION_RESEAU_SOCIAL.md`, `FONCTIONNALITES_RESTANTES.md`, `COMMUNAUTES_ET_PREMIUM.md`, `ETAT_ECRANS.md` (3 novembre) : « Communautés = conception », « publications/commentaires non implémentés » sont **périmés** (≥ 30 migrations de communautés/réseau depuis). Ne pas s'y fier.
4. `save_live`/`live_set_state`/`live_comment` (modules_restants) et la table `scheduled_lives` (`starts_at text`) sont **des reliques sans appelant dans `lib/`** (grep `'save_live'`, `'live_set_state'`, `'live_comment'` : 0 résultat) : à ne pas compter comme fonctionnalités.
5. `L/seller_live.dart` n'est **pas** un « live shopping » : c'est le tableau de bord vendeur (`seller_overview`, `seller_settings_*`).
6. « Radar des compétences » (`skills_radar`, écran 269, `L/modules.dart`) est un agrégat de compétences pour la gestion, **pas** l'Opportunity Radar du §15.3.

## Comptage par état (283 exigences atomiques)

| État | Total | §9 (66) | §10 (28) | §11 (30) | §12 (68) | §15 (50) | §20 (41) |
|---|---|---|---|---|---|---|---|
| OP | **37** | 15 | 4 | 0 | 10 | 8 | 0 |
| PART | **101** | 20 | 6 | 5 | 37 | 23 | 10 |
| NV | **9** | 2 | 3 | 0 | 0 | 3 | 1 |
| MANQ | **126** | 26 | 12 | 25 | 19 | 16 | 28 |
| EXT | **7** | 2 | 3 | 0 | 0 | 0 | 2 |
| DEC | **3** | 1 | 0 | 0 | 2 | 0 | 0 |
| **Total** | **283** | 66 | 28 | 30 | 68 | 50 | 41 |

(§10 : 28 exigences = 13 formats + 15 fonctions ; §11 : 30 ; la ligne C-242 est comptée dans §15.) Aucune ligne n'est « OP en production » : les OP reposent sur la lecture du code et sur des scénarios du dépôt non rejoués ici.

Lecture : **seulement 13 % des exigences sont opérationnelles** ; l'essentiel de l'OP se concentre sur le réseau social de base (publications, stories, commentaires, communautés, messagerie, modération, événements), les projets/campagnes, l'intelligence institutionnelle. Les blocs **Replay, Kéla Translate, AI Content Assistant, agents Kéla, IP Hub, Proof Registry** sont absents ou à l'état de simples approximations.

## Top 10 des manques critiques
1. **Kéla Translate absent (§11, C-095..C-124)** : aucune traduction de messages, voix, appels ou lives, aucun glossaire, aucune détection de langue ; aucun fournisseur choisi ni consentement vocal (C-120/121). Les « langues » du dépôt sont l'interface FR/EN statique et un champ de profil.
2. **Architecture multi-agents absente (§20, C-246..C-273)** : un seul assistant `kela-chat` (prompt statique, sans outil, sans contexte utilisateur, historique fourni par le client) ; les 20 agents, la coordination et la validation d'actions sont à concevoir. Et l'assistant lui-même est **EXT** (clé `ANTHROPIC_API_KEY` absente, jamais appelé en test).
3. **Live Replay Studio absent (C-039..C-047, C-086..C-089)** : ni enregistrement (LiveKit Egress), ni replay, transcription, chapitres, extraits ; prérequis juridique : consentement d'enregistrement (C-120).
4. **Contrôle d'accès des lives (C-091)** : `live-token` autorise tout compte connecté non banni à rejoindre tout live « en direct » ; pas de live privé, d'inscription préalable ni de billet ; pas de lien événement ↔ live (C-073, C-079).
5. **LiveKit jamais exercé (C-012, C-080, C-082, C-068)** : secrets absents ; `live-moderate` (kick/ban/mute) et la co-diffusion n'ont aucun test ; le transport natif `livekit_client` existe mais n'a jamais tourné sur appareil ; les formats de live (recrutement, soutenance, shopping, consultation) n'ont aucune structure (`lives` sans type/visibilité).
6. **Creator Studio et Analytics (C-018..C-022, C-048..C-055)** : pas de capture caméra, montage, découpage, sous-titres ni miniatures ; aucune vue/portée/durée de visionnage de publication ; programmation de publications **sans test** (C-025).
7. **AI Content Assistant absent (C-029..C-037)** : aucune fonction IA de contenu ; l'adaptation multi-plateformes est une troncature par règles, sans appel réel aux réseaux (EXT OAuth).
8. **IP Hub et Proof Registry (C-146..C-170)** : pas de registre de PI ; l'empreinte des certificats (`fingerprint`) hache des métadonnées + `now()` (non recalculable, aucun fichier) ; aucun avertissement « pas un brevet » (C-157) ; pas de versions, ni licences, ni NDA.
9. **Financement et monétisation bloqués par décisions/paiements (C-054, C-066, C-093, C-136, C-178)** : cadeaux de live (70/30, 1 crédit = 10 FCFA) non validés et recharge non reliée (`grant_credits` n'a aucun appelant) ; billetterie, campagnes de financement et prix de défis dépendent de Tara (jamais appelé réellement) et des décisions §30.
10. **Accessibilité non vérifiée (C-216..C-224)** : pas de texte alternatif ni de sous-titres, lecteur d'écran non testé sur appareil (écrans `g_xx` en toile absolue), préférences stockées sur l'appareil seulement ; et **aucun test pour l'échéance des opportunités** (C-205) alors que l'exigence « aucune opportunité expirée active » est explicite.

## Dépendances
- **LiveKit Cloud** (`LIVEKIT_URL/KEY/SECRET`) : prérequis de C-012, C-067, C-068, C-080..C-089, C-097..C-102 (traduction temps réel), enregistrement (C-039) via Egress.
- **Fournisseur de traduction/STT/TTS** (à comparer, DEC §31.6, avec clause « pas d'entraînement sur données privées », C-124) : prérequis de tout §11, de C-043..C-045 (transcription/sous-titres), C-022, C-088, C-218.
- **Clé IA** (`ANTHROPIC_API_KEY`, `KELA_MODEL`) + modèle de permissions/outils/journal d'actions : prérequis de §9.3, §20, C-206..C-210. Dépend aussi de la matrice d'accès aux données (RLS) pour tout contexte autorisé et de l'isolation par organisation (C-275).
- **Décisions propriétaire (§30)** : commissions/70-20-10 et cadeaux (décision 17), tarifs d'événements, remboursements, conditions de financement, textes juridiques (PI, CGU, consentement) : C-054, C-066, C-093, C-136, C-157, C-165..C-169, C-178, C-180.
- **Paiement Tara/Mobile Money** (appel réel en bac à sable) : C-059, C-093, C-136, C-178 ; recharge de crédits (C-066).
- **OAuth des réseaux** (Meta, LinkedIn, TikTok, Google) : C-034 (publication multi-plateformes réelle), C-019 (import).
- **Modèle `lives` enrichi** (type, visibilité, lien événement/mission/annonce, enregistrement) : prérequis de C-070..C-079, C-091, C-073, C-085.
- **Table de vues/événements de lecture** : prérequis de C-048..C-055 (analytics) et du classement serveur (C-015).
- **Spécifications §15** (Digital Twin, Expert Network, Trust Graph, Supply Chain, Franchise) : C-242 avant tout développement.
- **Tests à écrire en priorité** (sans dépendance externe) : `schedule_post`/`publish_due_posts` (C-025), co-hôtes (C-068), `send_live_reminders`, échéance des opportunités (C-205), `kela-chat` en Deno avec faux fournisseur (quota 429, 401, validation du `BRIEF`, C-276/C-280), refus d'accès `live-token` pour live privé (C-091).

---

# Tableau de la matrice

Colonnes : ID | exigence | § CDC | état | preuves | manque / tâche restante | tests nécessaires (existants → *E:* ; à écrire → *À écrire*) | preuve de validation requise.

## §9.1 Expérience sociale

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests nécessaires (existants) | Preuve de validation requise |
|---|---|---|---|---|---|---|---|
| C-001 | Publications (texte, lien, mots-clés, visibilité de base) | 9.1 | OP | UI `L/social_posts.dart` (`publishPost` → `Backend.rpc('create_post_v2')`), `L/reels.dart`, écrans 249/250/P4 ; SQL RSL `create_post_v2`, `circle_feed`, GP `_post_accessible`, G6 `circle_feed` (RLS + gardes `_assert_active`, modération `pending/published` selon certification) | Pas de « visibilité » par publication (public/abonnés/privé) hors communauté ; pas de types projet/produit/événement/opportunité (IMPLEMENTATION_RESEAU_SOCIAL §Manques) | E: `PGR` (texte + lien, republication), `PG/etu_s7.mjs`, `PG/publication_tous_profils.mjs`, `T/purchase/reseau_social_live_test.dart`, `T/purchase/publications_sociales_test.dart` | Rejouer `PGR`+`etu_s7` ; parcours 2 comptes (publier/voir) sur base isolée |
| C-002 | Photos (carrousel, ≤10) | 9.1 | OP | `post_media` (RSL), `create_post_v2(p_media jsonb)`, carrousel `PostCard` ; bucket `post-media` | Pas de texte alternatif (voir C-219) | E: `PGR` « publication de 5 images », `T/purchase/reseau_social_live_test.dart` (carrousel 5 photos) | Téléversement réel Storage sur base isolée (les tests PGlite utilisent un substitut `storage`) |
| C-003 | Vidéos (publication) | 9.1 | PART | `FilePicker` mp4/mov (`L/social_posts.dart:157,1223`), `video_player`, `post-media` 50 Mo ; lecture auto Reels | Aucun transcodage/compression/miniature ; lecture non testée sur appareil ni en navigateur automatisé ; image de fond Reels = maquette si média absent (ETAT_ECRANS 3/11, non revérifié) | E: `T/purchase/reseau_social_live_test.dart` (menu masqué, colonne d'interactions) — ne lit pas de vraie vidéo | Lecture d'une vraie vidéo MP4 sur Chrome + Android ; borne de taille 50 Mo testée |
| C-004 | Stories | 9.1 | OP | `L/stories.dart` → `create_story`, `stories_active`, `mark_story_seen`, `hide_story`, `answer_story`, `story_results`, `report_story`, `moderate_story` ; SQL RSL, AV (stickers/sondages), G6, MOD | Expiration 24 h non couplée à une purge de média Storage | E: `PGR` (actives, expirée disparue), `PG/etu2_g6.mjs` (answer_story), `PG/etu_s7.mjs` | Rejouer scénarios ; vérifier la suppression Storage à l'expiration (À écrire) |
| C-005 | Reels (fil vidéo vertical) | 9.1 | OP | `L/reels.dart` (`reels_feed`, `circle_feed`, `toggle_post_like`, `toggle_post_save`, `record_post_share`), écran 245 | Voir C-003 pour la vidéo ; pas de transcodage | E: `PG/etu2_g6.mjs`, `PG/act_h5.mjs`, `supabase/tests/commentaires_local.sql`, `T/purchase/publications_sociales_test.dart` (245 : compteurs, balayage) | Idem C-003 |
| C-006 | Commentaires (réponses, j'aime, suppression, pièce jointe) | 9.1 | OP | `add_post_comment_v2`, `post_comment_list_v2`, `toggle_comment_like`, `delete_post_comment`, `report_comment` (RSL, GP, G6) ; feuille 252 (`showCommentsSheet`) | — | E: `PGR` (réponse à réponse, likes, pièce jointe), `T/purchase/publications_sociales_test.dart` (252) | Rejouer `PGR` |
| C-007 | Réactions (j'aime, émojis, réactions de live) | 9.1 | OP | `toggle_post_like`, `react_post`/`post_reactions` (AV), `react_live` ; `LikeHeart` | — | E: `PG/etu_s7.mjs`, `PGR` (réactions live), `T/purchase/reseau_social_live_test.dart` | Rejouer scénarios |
| C-008 | Partages (partage, republication, duo/remix) | 9.1 | OP | `record_post_share`, `create_post_v2(p_repost_of)`, `create_remix` (CO) ; feuille de partage du système | Partage externe = lien copié/partage OS, pas d'intégration réseau (voir C-034) | E: `PGR` (republication), `PG/etu_s7.mjs` (remix, share) | Rejouer |
| C-009 | Abonnements (suivre / ne plus suivre) | 9.1 | PART | `Backend.engage('follow', …)` (`L/reels.dart:308`, `L/social_profile.dart:650`), `engagements` (M/20261030001000), `toggle_follow_shop`, `followers_count` (M/20261115000100) ; notification `trg_notify_follow` | Pas de liste d'abonnés/abonnements, pas de suggestions (IMPLEMENTATION_RESEAU_SOCIAL « Manques ») ; test d'abonnement jugé non couvert par la doc d'origine | E: `T/purchase/engagements_test.dart`, `supabase/tests/engagements_rest.py` (serveur réel, non rejoué) | Parcours 2 comptes (suivre, notification, ne plus suivre) ; écrire listes + test |
| C-010 | Communautés | 9.1 | OP | `L/communities*.dart`, `community_*`; SQL COM, `20261111000000`, COMT (5 types, sondages, épingles), COME (chat, Q&R, événements, fichiers), COMA (adhésion), MOD ; 3 modes `privacy` (public/approval/invite), rôles owner/admin/moderator | Catégories métier/secteur/région absentes (voir C-230 à C-235) | E: `PG/communities.mjs`, `PG/communautes_medias.mjs`, `supabase/tests/communautes_local.sql`, `supabase/tests/communautes_pglite/scenario.mjs`, `T/purchase/communautes_*_test.dart`, `T/journey/paiement_communaute_test.dart` | Rejouer ; parcours approbation/invitation avec 3 comptes |
| C-011 | Messagerie (1-à-1, pièces jointes, messages vocaux, non-lus, blocage) | 9.1 | OP | `Backend.conversations/messages/sendMessage/sendAttachment` (`L/backend.dart`), `L/chat_server.dart` (voix via `record`), M/20261030000300…0600, `block_user`, `report_conversation` ; Realtime | Pas de messagerie de groupe hors communautés ; pas de traduction (voir C-092) | E: `T/purchase/chat_server_test.dart`, `T/purchase/messages_test.dart`, `supabase/tests/messaging_rest.py`, `chat_attachments_rest.py` (REST réel : non rejoués), `PG/messagerie_coequipiers.mjs`, `etu2_g5/g6.mjs` (block_user) | Rejouer REST contre base isolée ; test 2 appareils |
| C-012 | Lives (diffusion en direct) | 9.1 | EXT | `L/lives.dart`, `L/live_transport*.dart`, `web/live_bridge.js`, `F/live-token`, `F/live-moderate` ; SQL RSL (`create_live`, `start_live`, `join_live`, `heartbeat_live`, `post_live_message`…) | **Jamais exécuté contre LiveKit** (secrets `LIVEKIT_URL/KEY/SECRET` non fournis, doc RESEAU_SOCIAL_LIVE « Limites connues »). Partie SQL/chat OP, partie vidéo EXT | E: `PGR` (démarrage, rejoindre, chat, signalement), `F/live-token/live_token_test.ts` (signature HS256 seulement), `T/purchase/reseau_social_live_test.dart` | Compte LiveKit réel, 2 appareils, jeton → publication → visionnage |
| C-013 | Événements | 9.1 | OP | `L/evenements.dart`, `L/evenements_gestion.dart` ; EV, EVP, EVG : `event_create/update/cancel`, `event_register/unregister`, `event_registrants`, `events_upcoming`, rappels `send_event_reminders` (cron) | Billetterie payante : voir C-070. Pas de lien événement ↔ live | E: `PG/etu_s5.mjs`, `PG/evenements_payants.mjs`, `supabase/tests/evenements_local.sql`, `T/journey/evenements_test.dart`, `T/journey/evenements_payants_test.dart` | Rejouer ; parcours inscription gratuite 2 comptes |
| C-014 | Découverte de créateurs | 9.1 | PART | `talents_search`, `L/talents_directory.dart`, barre d'histoires, `community_explore.dart`, `top_helpers` | Pas de page « créateurs à suivre », pas de recommandation de comptes ; aucun classement créateur | E: `supabase/tests/talents_pglite/scenario.mjs`, `supabase/tests/talents_local.sql` (talents, pas créateurs) | Concevoir (suggestions fondées sur centres d'intérêt/abonnements) + tests |
| C-015 | Flux personnalisé | 9.1 | PART | `FeedRanker` (`lib/core/domain/feed_ranker.dart`) appelé par `rankReels` (`L/reels.dart:117,227`) avec signaux `followed/interests/affinity` ; `docs/transformation/ALGORITHME_RECOMMANDATION.md` | Classement **côté client** sur les 30 éléments chargés par `circle_feed` ; pas de classement serveur, pas d'apprentissage ; modes `FeedMode` | E: `T/purchase/publications_sociales_test.dart` (récent > populaire, boosts, ≤2 par auteur) | Test d'intégration `circle_feed`→ranker avec données réelles ; mesure de pertinence (À écrire) |
| C-016 | Modération (réseau) | 9.1 | OP | `L/moderation_reseau.dart`, `moderate_post`, `moderate_story`, `moderation_posts_list`, `moderation_stories_list`, `community_report_*`, `comment_report_close`, `live_report_close`, `post_reports_dismiss` (MOD, L7) ; droits par permission (H4) | Pas de modération automatique (filtre) ; pas de file de modération des lives en temps réel | E: `PG/etu_s7.mjs`, `act_h2.mjs`, `act_h4.mjs`, `h7_cloisonnement.mjs`, `T/journey/s7_reseau_social_test.dart` | Rejouer |
| C-017 | Signalements (publication, commentaire, histoire, live, conversation, communauté) | 9.1 | OP | `report_post`, `report_comment`, `report_story`, `report_live`, `report_conversation`, `community_report` ; UI menu « Signaler » | — | E: `PG/etu_s7.mjs`, `etu2_g6.mjs`, `PGR` (signalement unique), `fin_k1.mjs` | Rejouer |

## §9.2 Creator Studio

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-018 | Enregistrement vidéo (caméra dans l'app pour un contenu) | 9.2 | MANQ | La publication n'utilise que `FilePicker` (mp4/mov/jpg…) ; `image_picker` n'apparaît que dans chat, profil, vendeur ; la caméra n'est utilisée que par le transport live | Capture caméra pour post/reel/story | À écrire (widget + appareil) | Essai Android/iOS |
| C-019 | Importation de médias | 9.2 | NV | `FilePicker` + `Backend.uploadFile('post-media', …)` (posts, stories, commentaires, communautés) ; `integrations_*` pour importer depuis des services (EXT) | Aucune preuve automatisée du téléversement réel (substitut `storage` PGlite) ; limites 50 Mo | E: indirect `PGR` | Test sur Storage réel d'une base isolée |
| C-020 | Montage simple | 9.2 | MANQ | Aucun code (pas de FFmpeg/éditeur ; pubspec sans `video_compress`/ffmpeg) | Éditeur ou service externe de montage (DEC fournisseur) | À écrire | — |
| C-021 | Découpage | 9.2 | MANQ | Idem | Idem | À écrire | — |
| C-022 | Sous-titres (création pour un contenu) | 9.2 | MANQ | Aucun | Transcription + piste VTT ; service STT externe (EXT) | À écrire | — |
| C-023 | Descriptions (légende, mots-clés, lien, annonce liée) | 9.2 | OP | `create_post_v2(p_caption,p_tags,p_link,p_listing)` | — | E: `PGR` | Rejouer |
| C-024 | Miniatures | 9.2 | PART | Couverture de live (`lives.cover_path`), logo/couverture de communauté ; **aucune** miniature pour posts/reels/stories | Sélecteur d'image de couverture / extraction d'image | À écrire | — |
| C-025 | Programmation de publications | 9.2 | NV | UI `L/social_posts.dart:1197-1290` (`schedule_post`, liste `scheduled_posts` L1431) ; SQL AV (`schedule_post`, `cancel_scheduled_post`, `publish_due_posts`) ; cron `publish-due-posts` (AV, révoqué aux clients par M/20261115000100) | **Aucun test SQL de `schedule_post`/`publish_due_posts`** (grep dans `supabase/tests` : seul un `revoke` dans `securite_client.mjs`) ; réservé à student/dept/admin (autres créateurs exclus) ; cron non vérifié | À écrire : SQL (`schedule_post`, publication à l'échéance, annulation, quota 200) + Flutter | Scénario PGlite avec horloge simulée ; vérifier `cron.job` en base isolée |
| C-026 | Publication (depuis le Studio) | 9.2 | OP | Voir C-001 | — | E: voir C-001 | — |
| C-027 | Gestion des brouillons | 9.2 | PART | Brouillons de **formulaires** locaux (`L/drafts.dart`, SharedPreferences, jamais serveur) ; brouillons serveur pour live/projet/campagne/annonce (`status='draft'`) ; **pas** de brouillon de publication | Statut `draft` pour posts + liste | À écrire | — |
| C-028 | Bibliothèque de contenus | 9.2 | PART | `my_posts_status`, `author_posts`, liste des programmées, enregistrés (`toggle_post_save`), `user_collections` (M/20261114001600) | Pas de bibliothèque unifiée (médias, brouillons, extraits, modèles) | E: `PG/collections.mjs`, `T/purchase/collections_test.dart` (collections, pas Studio) | À concevoir |

## §9.3 AI Content Assistant

Constat : la seule IA du dépôt est `F/kela-chat` (assistant générique orienté « besoin à confier à des étudiants ») ; **aucune fonction dédiée au contenu**. Les exigences ci-dessous ne sont donc pas couvertes.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-029 | Préparer des publications | 9.3 | MANQ | Aucun appel IA depuis `L/social_posts.dart`/`publish_page.dart` | Fonction Edge dédiée (prompt contenu) + UI dans le Studio | À écrire | Appel réel fournisseur IA (EXT : `ANTHROPIC_API_KEY` ou autre) |
| C-030 | Rédiger des descriptions | 9.3 | MANQ | Idem | Idem | À écrire | Idem |
| C-031 | Construire des scripts | 9.3 | MANQ | Idem | Idem | À écrire | Idem |
| C-032 | Proposer des titres | 9.3 | MANQ | Idem | Idem | À écrire | Idem |
| C-033 | Générer des idées de contenus | 9.3 | MANQ | Idem | Idem | À écrire | Idem |
| C-034 | Adapter un contenu à plusieurs plateformes | 9.3 | PART | `F/_shared/adapt.ts` ↔ `adaptForPlatform` (`L/integrations_model.dart`), `F/integrations-publish`, écrans « Publier sur mes réseaux » (`L/integrations_ui.dart`) : règles de longueur/lien **sans IA** | Publication réelle exige les apps OAuth (EXT : Meta, LinkedIn, TikTok, Google… secrets non fournis, aucun appel réel — INTEGRATIONS_HUB) ; adaptation = troncature/règles, pas réécriture | E: `F/_shared/shared_test.ts`, `T/integrations/integrations_model_test.dart`, `supabase/tests/integrations_pglite/scenario.mjs` | Appel réel par plateforme avec compte de test ; (matrice C1 couvre §21) |
| C-035 | Traduire des contenus | 9.3 | MANQ | Seule la traduction **statique** FR/EN de l'interface (`lib/figma/i18n.dart`, `assets/i18n/en.json`) | Voir §11 | À écrire | Voir §11 |
| C-036 | Produire des résumés | 9.3 | MANQ | Aucun | Fonction IA | À écrire | EXT IA |
| C-037 | Identifier des extraits intéressants | 9.3 | MANQ | Aucun (dépend de C-043..047) | Idem | À écrire | EXT IA |
| C-038 | Contenus générés modifiables et jamais publiés sans autorisation | 9.3 | PART | Précédent : Kéla ne crée qu'un **brouillon** de besoin (`L/kela.dart:143-167`, `myNeedsDialog`) que l'utilisateur valide ; aucune publication automatique n'existe | Règle à imposer dans toute future fonction (publication = action utilisateur explicite) | À écrire (test « pas d'insert sans confirmation ») | Revue de conception |

## §9.4 Live Replay Studio

Constat : `RESEAU_SOCIAL_LIVE.md` : « Pas d'enregistrement ni de rediffusion des lives » ; aucune table `live_recordings`, aucun appel LiveKit Egress, aucune route de replay (grep `replay|recording|egress|chapter` : seuls des faux positifs). Le fichier `PG/replay.mjs` est un **harnais de rejeu de migrations**, pas un replay de live.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-039 | Enregistrement des lives | 9.4 | MANQ | Aucun | LiveKit Egress (EXT : compte LiveKit + stockage) ; consentement (C-120) | À écrire | Enregistrement réel d'un live de test |
| C-040 | Replay | 9.4 | MANQ | `lives.status` n'a que `scheduled/live/ended/cancelled`, pas de média | Table + lecteur | À écrire | Idem |
| C-041 | Découpage en extraits | 9.4 | MANQ | Aucun | Éditeur/service | À écrire | — |
| C-042 | Chapitres | 9.4 | MANQ | Aucun | Table `live_chapters` + UI | À écrire | — |
| C-043 | Transcriptions | 9.4 | MANQ | Aucun | STT externe (EXT) | À écrire | Appel réel STT |
| C-044 | Sous-titres (du replay) | 9.4 | MANQ | Aucun | Piste VTT | À écrire | — |
| C-045 | Résumés | 9.4 | MANQ | Aucun | IA (EXT) | À écrire | — |
| C-046 | Moments importants | 9.4 | MANQ | `peak_viewers` seul indicateur | Détection (pics de chat/cadeaux) | À écrire | — |
| C-047 | Publication d'extraits | 9.4 | MANQ | Aucun | Dépend de C-040/041 | À écrire | — |

## §9.5 Creator Analytics (statistiques réelles uniquement)

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-048 | Vues | 9.5 | PART | Vues d'histoires (`story_views`, `story_results`), pic de spectateurs de live (`creator_dashboard`), `listing_views`, `shop_views`, `opportunity_views` | **Aucune table de vues de publications/reels** (grep `post_views|impressions|watch_time` : ads seulement) | E: `PGR` (`creator_dashboard`), `PG/offres_statistiques.mjs` | Concevoir compteur de vues dédupliqué + RLS |
| C-049 | Portée | 9.5 | MANQ | Aucun | Idem | À écrire | — |
| C-050 | Engagement | 9.5 | PART | Compteurs j'aime/commentaires/enregistrements/partages/republications par publication (`circle_feed`, `Reel`) | Pas de tableau de bord auteur (agrégats par période) | E: `T/purchase/publications_sociales_test.dart` (compteurs lus) | Écran + RPC agrégée |
| C-051 | Durée de visionnage | 9.5 | MANQ | Aucun | Événements de lecture | À écrire | — |
| C-052 | Abonnements (croissance) | 9.5 | PART | `followers_count` dans le profil public (M/20261115000100) | Pas de série temporelle, pas de liste | E: `supabase/tests/profil_public_local.sql` | RPC d'évolution |
| C-053 | Conversions | 9.5 | PART | Annonces vendeur : `seller_overview`, `shop_views` → commandes ; `opportunity_views` → candidatures (`PG/offres_statistiques.mjs`) | Pas de lien publication → vente | E: `PG/etu_s3.mjs`, `revenus_vendeur_local.sql` | Attribution de conversion à concevoir |
| C-054 | Revenus | 9.5 | PART | Revenus vendeur réels (`M/20261105000800_revenus_vendeur`, `money_revenus_releve`), cadeaux reçus (`creator_earnings`, `creator_dashboard`, `payout_available:false`) | Cadeaux : règle 70/30 **non validée** (décision 17, H8) ; retraits de gains non ouverts | E: `PGR` (21/9), `PG/etu_money.mjs` | Décision propriétaire ; prestataire de versement |
| C-055 | Performances des contenus | 9.5 | MANQ | Aucun classement de performance par contenu | Dépend de C-048..051 | À écrire | — |

## §9.6 Monétisation

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-056 | Vente de ressources | 9.6 | PART | Marketplace : 4 types d'offre dont « solution numérique » (`L/offer_types.dart`, M/20261114000100), commande/paiement (autres lots) | Livraison de fichiers téléchargeables après paiement non établie ici (§6.3, lot B) | E: `T/purchase/types_offres_test.dart` | Voir matrice B |
| C-057 | Vente de modèles | 9.6 | PART | Idem (catégorie « Solutions numériques ») | Pas de notion de « modèle » ni de licence d'usage | Idem | Idem |
| C-058 | Vente de formations | 9.6 | PART | Offres « service/expertise », ateliers `lives_agenda` gratuits, événements payants | Pas d'objet « formation » (cours, modules, accès) | À écrire | — |
| C-059 | Masterclasses payantes | 9.6 | EXT | Événements payants `event_checkout` (EVP) avec `payment_start('event')` provider `tara`/`manual` | Pas de live payant ; paiement Tara non appelé réellement en preuve (EXT Tara Money) ; prix/remboursement = DEC (§30) | E: `PG/evenements_payants.mjs`, `T/journey/evenements_payants_test.dart` | Paiement réel en bac à sable Tara ; décision tarifs |
| C-060 | Conférences (payantes/ouvertes) | 9.6 | PART | Événement `kind='conference'` + inscription ; pas de diffusion liée | Lien événement → live | E: `PG/etu_s5.mjs` | — |
| C-061 | Prestations à la demande | 9.6 | OP | Devis/services : `request_quote`, `answer_quote`, `decide_quote`, négociation (`L/quote_negotiation.dart`), missions | Prix/commission = DEC (couvert par lot B) | E: `PG/etu_devis.mjs`, `devis_litige.mjs`, `supabase/tests/quotes_rest.py` | Voir matrice B |
| C-062 | Packs de contenus | 9.6 | PART | `shop_packs` (M/20261107000000 marketplace) | Packs de **produits** de boutique, pas de contenus | E: `PG/scenario.mjs` | — |
| C-063 | Licences | 9.6 | MANQ | Catégorie « Projets et licences » = libellé de catégorie ; aucune table de licence (grep `licen*` : libellés) | Modèle de licence (type, durée, exclusivité) | À écrire | Décision juridique (DEC) |
| C-064 | Contrats de création | 9.6 | PART | `mission_agreements`, jalons (missions) | Contrat légal officiel = DEC §30 ; pas de modèle « création de contenu » | E: `T/purchase/lot3_missions_test.dart` | DEC |
| C-065 | Ateliers multi-sessions | 9.6 | MANQ | `lives_agenda`/événements = séance unique | Entité « série de sessions » | À écrire | — |
| C-066 | Cadeaux virtuels (extension validée) | 9.6 | DEC | `send_gift`, `grant_credits`, `my_wallet` (RSL) : OP côté SQL (`PGR` 8 contrôles) | Décision 17 : 70/30, 1 crédit=10 FCFA, plafond 50 non validés ; **recharge non reliée à un paiement** (`grant_credits` n'a aucun appelant hors migration) ; retraits fermés | E: `PGR` (idempotence, solde, tableau créateur) | Décisions propriétaire + branchement webhook de paiement |

## §10.1 Formats de Live

Constat : `lives` n'a ni colonne `format`/`kind`, ni visibilité, ni lien événement/produit/mission. Tous les formats sont donc un même « live ouvert de créateur » ; seuls certains peuvent être approximés par l'usage.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-067 | Live vertical de créateur | 10.1 | EXT | `L/lives.dart` (création, régie, spectateur plein écran) ; RSL | EXT LiveKit (C-012) ; cadrage vertical imposé par `live_bridge.js`/native non vérifié | E: `PGR`, Flutter `reseau_social_live_test` (modèle) | Essai appareil |
| C-068 | Live multi-invités | 10.1 | NV | `live_cohosts` (CO) : `request_cohost`, `respond_cohost`, `list_cohost_requests`, `remove_cohost` ; `live-token` rôle `cohost` (publier) ; UI `L/lives.dart` | **Aucun test** (`request_cohost` absent de `supabase/tests`) ; grille multi-vidéo non vérifiée | À écrire (SQL + Deno : jeton cohost `canPublish`) | Essai LiveKit à 3 comptes |
| C-069 | Duel professionnel | 10.1 | PART | `duels`, `duel_create/enter/vote/withdraw`, `duels_list` (S6L, L10) : **concours de vote d'entrées**, pas un live à deux | Pas de live duel temps réel | E: `PG/etu_s6.mjs`, `modules_restants_local.sql` | Concevoir si « duel live » voulu |
| C-070 | Recrutement en direct | 10.1 | MANQ | Aucun lien live ↔ `opportunities`/`mission` (`lives` sans FK ; `_can_broadcast` exclut les comptes entreprise non certifiés) | Live d'entretien (salle privée, candidat, recruteur) | À écrire | — |
| C-071 | Live shopping | 10.1 | MANQ | `scheduled_lives.product_title` (relique, aucun appelant) ; `L/seller_live.dart` ≠ live shopping | Lien live ↔ annonces + achat en direct | À écrire | — |
| C-072 | Formation (live) | 10.1 | PART | Ateliers programmés (`lives_agenda`, `live_remind_set`, écran 223/227) = lives ordinaires | Pas de format formation, présence, supports | E: `T/journey/lot_reseau_test.dart` (223) | — |
| C-073 | Conférence (live) | 10.1 | PART | Événement `conference` sans diffusion liée | Lier événement ↔ live ; accès | — | — |
| C-074 | Atelier (live) | 10.1 | PART | Écran 227 `regie_ateliers` / L10 ateliers (`L/l10_ateliers.dart` : `lives_agenda`, `live_remind_set`) | Idem C-072 | E: `T/journey/lot_reseau_test.dart` | — |
| C-075 | Consultation (live) | 10.1 | MANQ | Mentors : `mentor_request` (demande/acceptation, pas de salle) | Salle privée 1-à-1 + facturation | À écrire | — |
| C-076 | Démonstration technique | 10.1 | PART | Live ordinaire + partage d'écran **uniquement dans les salons vocaux** (`room_bridge.js getDisplayMedia`) | Partage d'écran dans les lives | E: `T/purchase/salons_vocaux_test.dart` | — |
| C-077 | Présentation de projet | 10.1 | MANQ | Pitch de projets en pages statiques (`L/project_pages.dart`) ; pas de live lié au projet | Lien projet ↔ live | À écrire | — |
| C-078 | Soutenance | 10.1 | MANQ | Aucun (jury concours = notation, pas de live) | Salle privée avec jury, enregistrement avec consentement | À écrire | — |
| C-079 | Salon professionnel numérique | 10.1 | MANQ | Événement `kind='salon'` sans espace virtuel ; salons vocaux = audio de communauté | Salle virtuelle multi-stands | À écrire | — |

## §10.2 Fonctions du Live

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-080 | Audio et vidéo | 10.2 | EXT | Voir C-012 ; `live_transport_web.dart` (`web/live_bridge.js`, SDK jsDelivr figé), `live_transport_native.dart` (`livekit_client`) | Secrets LiveKit absents ; **aucun échange réel**. Audit LiveKit « avant remplacement » (CDC) = non documenté | E: `F/live-token/live_token_test.ts` | Compte LiveKit + 2 appareils ; comparatif fournisseurs (À écrire) |
| C-081 | Invités | 10.2 | NV | Voir C-068 | Idem | À écrire | Idem |
| C-082 | Modération (live) | 10.2 | NV | SQL OP : `moderate_live_viewer`, `report_live`, `live_bans`, `live_report_close` ; Edge `live-moderate` (kick/ban/mute via API Twirp LiveKit) appelé par `L/lives.dart:104` | `live-moderate` jamais testé (aucun test Deno, EXT LiveKit) ; `live-token` refuse les bannis (code lu) | E: `PGR` (ban, message masqué) ; `live-moderate` : aucun | Test Deno avec faux LiveKit + essai réel |
| C-083 | Chat | 10.2 | OP | `post_live_message` (anti-spam 5/10 s), Realtime sur `live_messages` ; UI `L/lives.dart` | Realtime non exécuté en test (publication `supabase_realtime`) | E: `PGR` (messages lisibles par tous), `PG/etu_s7.mjs` | Essai 2 clients Realtime |
| C-084 | Réactions | 10.2 | OP | `react_live` (20/10 s) | — | E: `PGR` | Rejouer |
| C-085 | Partage de documents | 10.2 | MANQ | Aucun envoi de fichier dans un live (fichiers existent dans communautés : `community_file_add`) | Pièces jointes de live | À écrire | — |
| C-086 | Enregistrement | 10.2 | MANQ | Voir C-039 | — | — | — |
| C-087 | Replay | 10.2 | MANQ | Voir C-040 | — | — | — |
| C-088 | Sous-titres (live) | 10.2 | MANQ | Aucun | STT temps réel (EXT) | À écrire | — |
| C-089 | Traduction (live) | 10.2 | MANQ | Aucun (voir §11) | EXT | À écrire | — |
| C-090 | Gestion des événements | 10.2 | OP | Voir C-013 (`event_create/update/cancel`, `events_managed`, remboursements `event_refund_done`) | Pas de gestion d'événement **en ligne** (salle) | E: `PG/etu_s5.mjs` | Rejouer |
| C-091 | Accès public ou privé | 10.2 | MANQ | `lives` sans colonne de visibilité ; `live-token` n'autorise que « en direct » + non banni : **tout compte connecté peut rejoindre tout live** ; événements : `status published` pour tous | Live privé (invitation/inscrits/communauté) côté SQL **et** Edge | À écrire (SQL + Deno) | Test négatif d'accès |
| C-092 | Gestion des inscriptions | 10.2 | OP | `event_register/unregister`, `event_registrants`, `live_remind_set`/`live_reminders` | Pas d'inscription à un live (seulement rappel) | E: `PG/etu_s5.mjs`, `T/journey/evenements_test.dart` | — |
| C-093 | Billetterie selon règles validées | 10.2 | EXT | `event_checkout` (EVP), `event_receipts`, `on_event_paid`, remboursement `refund_status` (EVG) | Prestataire Tara jamais appelé réellement ; **règles de billetterie/remboursement/prix = DEC §30** ; pas de QR billet d'entrée événement (qr_codes existent pour autre usage) | E: `PG/evenements_payants.mjs`, `T/journey/evenements_payants_test.dart` | Décision + paiement bac à sable |
| C-094 | Statistiques (live/événement) | 10.2 | PART | `creator_dashboard` (nb lives, pic), `peak_viewers`, inscrits `event_registrants` | Pas de durée moyenne, rétention, engagement par live | E: `PGR` | RPC d'analyse + test |

## §11 Kéla Translate

Constat global : **aucune fonction de traduction runtime** dans le dépôt (pas de table `translations`/`languages`, aucune Edge Function, aucun appel à un fournisseur ; grep `translat|traduction` = UI statique). `speech_to_text`/`Dictation` fournit de la **dictée** (navigateur) et `webSpeak` de la lecture vocale **d'alertes** (`GAccess.speak`), rien de plus. `student_languages` (M/20261114003000) déclare les langues parlées des étudiants (profil).

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-095 | Traduction : messagerie écrite | 11.1 | MANQ | `L/chat_server.dart` sans traduction | Edge `translate` + colonne/vue par message | À écrire | Appel réel fournisseur (EXT : choix fournisseur = DEC/recherche) |
| C-096 | Traduction : messages vocaux | 11.1 | MANQ | Messages vocaux stockés (`kind='voice'`, webm/m4a) sans transcription | STT + traduction | À écrire | EXT |
| C-097 | Traduction : appels audio | 11.1 | MANQ | **Aucun appel 1-à-1** : seuls les salons vocaux de communauté (`study_rooms`, WebRTC maillé P2P, STUN public seulement, pas de TURN) | Appels + pipeline temps réel | À écrire | EXT |
| C-098 | Traduction : appels vidéo | 11.1 | MANQ | Aucun appel vidéo (hors lives) | Idem | À écrire | EXT |
| C-099 | Traduction : lives | 11.1 | MANQ | Voir C-089 | Idem | À écrire | EXT |
| C-100 | Traduction : conférences | 11.1 | MANQ | Aucun | Idem | À écrire | EXT |
| C-101 | Traduction : entretiens de recrutement | 11.1 | MANQ | Pas d'entretien en direct (C-070) | Idem | À écrire | EXT |
| C-102 | Traduction : formations | 11.1 | MANQ | Aucun | Idem | À écrire | EXT |
| C-103 | Traduction : communautés | 11.1 | MANQ | `community_messages` sans traduction | Idem | À écrire | EXT |
| C-104 | Traduction : consultations | 11.1 | MANQ | Aucun | Idem | À écrire | EXT |
| C-105 | Traduction : événements | 11.1 | MANQ | Aucun | Idem | À écrire | EXT |
| C-106 | Traduction : échanges commerciaux (devis, commandes, litiges) | 11.1 | MANQ | `quote_messages`, `claim_messages` sans traduction | Idem | À écrire | EXT |
| C-107 | Scénario recruteur chinois ↔ candidat francophone (audio traduit par participant, transcription/texte original consultables) | 11.2 | MANQ | Aucun | Pipeline STT→MT→TTS par participant ; EXT | À écrire | Essai réel bout en bout |
| C-108 | Détection de langue | 11.3 | MANQ | Aucun | EXT/DEC fournisseur | À écrire | Appel réel |
| C-109 | Langue préférée par utilisateur | 11.3 | PART | Langue d'interface FR/EN (`I18n.lang`, `assets/i18n/en.json`, stockage local, pas serveur) ; `student_languages` (profil, déclaratif) | Préférence de **traduction** par compte (serveur) | E: `T/account/*` (réglages), pas de test dédié | Colonne profil + test |
| C-110 | Traduction bidirectionnelle | 11.3 | MANQ | Aucun | — | À écrire | EXT |
| C-111 | Sous-titres (traduits) | 11.3 | MANQ | Aucun | — | À écrire | EXT |
| C-112 | Transcription | 11.3 | PART | Dictée seule (`L/dictation_web.dart`, `speech_to_text`) de la voix de l'utilisateur vers un champ texte ; pas de transcription de conversation/média | Service STT serveur | E: aucun test de dictée | EXT |
| C-113 | Synthèse vocale | 11.3 | PART | `lib/figma/gspeak_web.dart` : `speechSynthesis` du navigateur fr-FR pour lire les alertes quand « lecteur d'écran » est activé (web uniquement) | Pas de TTS multilingue ni de voix traduite ; mobile natif non géré (`if (kIsWeb)`) | Aucun test | Essai appareil |
| C-114 | Traduction multi-intervenants | 11.3 | MANQ | Aucun | — | À écrire | EXT |
| C-115 | Glossaires professionnels | 11.3 | MANQ | Aucun (le glossaire `skill_catalog` est un référentiel de compétences) | Table de glossaires par organisation/métier | À écrire | — |
| C-116 | Conservation facultative des transcriptions | 11.3 | MANQ | Aucune transcription n'existe | Option par utilisateur + purge | À écrire | — |
| C-117 | Choix audio original / audio traduit | 11.3 | MANQ | Aucun | Pistes audio dans LiveKit (EXT) | À écrire | — |
| C-118 | Gestion des langues par événement | 11.3 | MANQ | `events` sans colonne de langue | Colonne + UI | À écrire | — |
| C-119 | Vidéos externes (pistes audio officielles/import autorisé ; ne pas promettre le remplacement) | 11.4 | MANQ | Aucun import de vidéo externe traduite ; `integrations_imported_items` (import de contenus connectés, sans audio) | Aucune promesse affichée (conforme) ; fonction non démarrée | À écrire | Étude de faisabilité YouTube (EXT) |
| C-120 | Consentement pour l'enregistrement | 11.5 | MANQ | Aucun enregistrement existe ; consentements existants = coéquipiers (`mate_consents`), documents/CGU | À concevoir avant tout enregistrement (C-039) | À écrire | Revue juridique |
| C-121 | Consentement explicite pour imitation/clonage vocal | 11.5 | MANQ | Aucun clonage (conforme : rien d'activé) ; aucun mécanisme de consentement | Tant que non implémenté, interdire dans les CGU (DEC) | À écrire | — |
| C-122 | Contrôle de conservation | 11.5 | PART | Suppression de compte/`process_account_deletions`, export de données (`L/data_export.dart`) ; rien pour transcriptions | À spécifier | E: `PG/etu2_g1.mjs` (suppression de compte) | — |
| C-123 | Protection des conversations privées | 11.5 | PART | RLS des messages (participants), `user_blocks`, `message_reports` | Aucun traitement tiers existant ; à garantir lors de l'ajout de traduction (envoi au fournisseur = flux de données privées) | E: `PG/securite_client.mjs`, `supabase/tests/messaging_rest.py` | Revue de conception + DPA fournisseur |
| C-124 | Pas d'entraînement sur voix privées sans autorisation | 11.5 | MANQ | Aucun traitement de voix ; clause contractuelle fournisseur à obtenir | Choisir un fournisseur à politique « no training » (DEC) | — | Contrat/DPA |

## §12.1 Innovation Investment Hub

Socle réel : `projects` + `project_steps` + `project_members` + `project_files` (M/20261031000000, L9, `20261117050200_s5_projets_equipe`), `campaigns` + `campaign_milestones` + `campaign_contributions` (L9, `20261117050300_s5_campagnes_cloture`), écrans `L/l9_projets.dart`, `L/l9_campagnes.dart`, `L/project_pages.dart`, `L/project_cards.dart`, `L/innovations_screens.dart`. Validation par le département/l'administration (`review_project`, `review_campaign`).

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-125 | Présentation des projets | 12.1 | OP | `save_project`, `public_project_get`, `iut_projects`, `project_upvote_toggle` ; pages `L/project_pages.dart` ; RLS « approuvés pour tous » | Projets limités aux étudiants/IUT ; pas de projets d'organisations externes | E: `PG/etu_s5.mjs`, `act_h5.mjs`, `etu2_g6.mjs`, `T/projects/l9_projets_test.dart` | Rejouer |
| C-126 | Dossier de projet | 12.1 | PART | `projects` (titre, résumé ≤4000, filière, liens jsonb) + fichiers (`register_file`, `project_files_list`) | Pas de dossier structuré (problème, marché, équipe, risques) ni modèle | E: `PG/etu_s5.mjs` | Spécifier le gabarit de dossier |
| C-127 | Besoins de financement | 12.1 | PART | `campaigns` (`goal` 1 000–1 Md, `duration_days` 7–90, `kind` project/preorder/sponsoring) | Pas de ventilation des besoins (équipement, salaires…) | E: `PG/etu_s5.mjs` | — |
| C-128 | Budget | 12.1 | PART | Seulement `campaign_milestones.target_xaf` | Pas de budget détaillé (lignes, postes, justificatifs) | À écrire | — |
| C-129 | Objectifs | 12.1 | PART | `campaigns.presentation`/`rewards` (texte libre), jalons | Pas d'objectifs mesurables (KPIs) | — | — |
| C-130 | Étapes | 12.1 | OP | `add_project_step`, `project_step_update/delete`, `campaign_milestone_save/done/review` | — | E: `PG/etu_s5.mjs`, `T/projects/l9_projets_test.dart` | Rejouer |
| C-131 | Porteurs | 12.1 | OP | `projects.owner_id`, `campaigns.owner_id`, affichage porteur | Porteur organisation non prévu | E: `PG/etu_s5.mjs` | — |
| C-132 | Contributeurs (équipe) | 12.1 | OP | `project_member_invite/respond/remove`, `project_member_search`, `my_member_projects`, notifications | — | E: `PG/etu_s5.mjs`, `etu2_g6.mjs` | Rejouer |
| C-133 | Documents | 12.1 | PART | `register_file`, `storage_file_allowed` (S5), `project_file_remove` | Pas de contrôle de confidentialité par document, pas de version (voir C-150) | E: `PG/etu_s5.mjs` | — |
| C-134 | Avancement | 12.1 | PART | Étapes datées + jalons (`done_at`, revue `campaign_milestone_review`) | Pas de % d'avancement ni de tableau de bord de suivi | E: `PG/etu_s5.mjs` | — |
| C-135 | Partenaires | 12.1 | MANQ | Aucun lien projet ↔ partenaires ; `institutional_partnerships` concerne les départements/institutions | Table `project_partners` + invitation | À écrire | — |
| C-136 | Campagnes de financement autorisées | 12.1 | DEC | `campaign_contribute` (paiement requis `payment_id` unique), revue `review_campaign` (autorisation dept/admin), clôture `campaign_close_due`, remboursements `campaign_refund_done`, contributeurs `campaign_backers`, UI `L/l9_campagnes.dart` | **Conditions de financement, séquestre/remboursement = décisions §30** ; prestataire de paiement non appelé réellement (EXT) ; remboursement = marquage manuel | E: `PG/etu_s5.mjs`, `PG/fin_k1.mjs`, `T/projects/l9_projets_test.dart` | Décisions propriétaire + paiement bac à sable |

## §12.2 Startup Pitch Arena

Socle : concours/hackathons (`contests`, `contest_teams`, `contest_submissions`, `contest_jurors`, `contest_scores`, M/20261101000200, 20261115200400, 20261117060100 ; écrans `L/concours_screens.dart`, `L/l10_hackathons.dart`, `L/hackathons.dart`). Ce n'est pas une « arène de pitch » dédiée aux startups : les dépôts sont des projets de concours.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-137 | Pitch vidéo | 12.2 | PART | `contest_submissions.video_url` (lien externe validé par regex), pas de téléversement vidéo | Lecture intégrée / hébergement | E: `PG/etu2_g6.mjs` (`submit_contest_project`) | Décision d'hébergement |
| C-138 | Présentation (deck) | 12.2 | OP | `deck_path` (Storage), dépôt `submit_contest_project` | — | E: `PG/etu2_g6.mjs`, `T/journey/l10_hackathons_test.dart` | Rejouer |
| C-139 | Documents | 12.2 | PART | `deck_path` unique ; `contest_team_space` | Un seul document par dépôt | E: `PG/etu2_g6.mjs` | — |
| C-140 | Démonstrations | 12.2 | PART | `demo_url` (lien externe) | Pas d'hébergement/session de démo | E: idem | — |
| C-141 | Jury | 12.2 | OP | `assign_contest_juror`, `is_contest_juror`, `my_judging_projects`, `score_contest_submission` (innovation/faisabilité/impact/pitch 0-10), `contest_ranking` | Jury réservé aux concours créés par dept/admin ; pas de jury d'investisseurs | E: `PG/etu_s6.mjs`, `PG/concours.mjs`, `T/purchase/lot4_concours_test.dart` | Rejouer |
| C-142 | Mentors (accompagnement des équipes) | 12.2 | PART | Module mentors (`mentor_request/decide`, `mentors_list`) distinct des concours | Pas d'affectation mentor ↔ équipe de concours | E: `PG/mentors.mjs` | — |
| C-143 | Votes lorsque le format l'autorise | 12.2 | PART | `project_upvote_toggle` (projets), `challenge_vote`, `duel_vote` ; scores de jury | Pas de réglage « vote public autorisé » par format de concours | E: `PG/etu_s6.mjs`, `T/purchase/innovations_test.dart` | — |
| C-144 | Mise en relation avec partenaires et investisseurs | 12.2 | MANQ | Aucun rôle investisseur (grep `investor|investisseur` : 0) ; seulement messagerie et `talent_contact_request` | Rôle/annuaire d'investisseurs, demandes d'introduction ; **conformité/financement = DEC §30** | À écrire | — |
| C-145 | Suivi des projets | 12.2 | PART | `contest_team_space` (tâches `contest_tasks`, échéances), étapes de projet | Pas de suivi post-concours | E: `T/journey/l10_hackathons_test.dart` | — |

## §12.3 Innovation Proof Registry

Socle le plus proche : certificats (`certificates` avec `subject_kind='project'`, `issue_certificate`, `verify_certificate`, `certificate_checks`, M/20261031000000 et 20261115140000) et `user_document_history`. Aucun registre de **preuves de projet** dédié.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-146 | Auteur | 12.3 | PART | `projects.owner_id`, `certificates.holder_id/holder_name` | Pas d'auteur certifié au moment de la preuve (pas de snapshot) | E: `PG/act_h5.mjs` | — |
| C-147 | Contributeurs | 12.3 | PART | `project_members` (statut accepté) | Non figés dans une preuve | E: `PG/etu_s5.mjs` | — |
| C-148 | Versions | 12.3 | MANQ | `projects` sans historique de version (`listing_history`/`user_document_history` concernent annonces et documents) | Table de versions immuables | À écrire | — |
| C-149 | Dates | 12.3 | PART | `created_at`, `issued_at`, `happened_on` d'étapes | Pas d'horodatage de tiers (RFC 3161) | — | — |
| C-150 | Documents | 12.3 | PART | `register_file` | Empreinte du **fichier** non calculée | À écrire | — |
| C-151 | Prototypes | 12.3 | MANQ | Aucun | — | À écrire | — |
| C-152 | Étapes | 12.3 | PART | `project_steps` (modifiables par le porteur : non immuables) | Journal append-only | E: `PG/etu_s5.mjs` | — |
| C-153 | Validation | 12.3 | PART | `review_project` (dept/admin), `issue_certificate`/`revoke_certificate` | Validation de la preuve elle-même absente | E: `PG/act_h2.mjs`, `h7_cloisonnement.mjs` | — |
| C-154 | Historique | 12.3 | PART | `institutional_decision_log`, audit général | Pas d'historique par projet | — | — |
| C-155 | Empreintes cryptographiques | 12.3 | PART | `certificates.fingerprint` = SHA-256 (`digest(...)`) du **code, type, titre, titulaire et `now()`** : non recalculable par un tiers, ne couvre aucun fichier | Hash de contenu + horodatage vérifiable | E: `PG/etu_s2.mjs` (émission) | Spécifier puis tester le recalcul |
| C-156 | Vérification | 12.3 | OP | `verify_certificate(p_code)` (anon), `L/verification.dart`, `L/certificates_page.dart`, journal `certificate_checks` | Vérifie l'existence/révocation d'un **certificat**, pas l'intégrité d'un projet | E: `PG/act_h5.mjs`, `etu_s2.mjs`, `supabase/tests/lots_rest.py` | Rejouer |
| C-157 | Ne pas présenter l'horodatage comme un brevet / reconnaissance de propriété intellectuelle | 12.3 | PART | Aucun texte ne parle de brevet (grep `brevet|patent` : 0) ; aucun avertissement non plus | Ajouter la mention explicite dans l'UI et les CGU (DEC textes juridiques) | À écrire (test de texte) | Validation du texte par le propriétaire |

## §12.4 Intellectual Property Hub

Constat : **aucune table, RPC ni écran de propriété intellectuelle** (grep `intellectual|invention|brevet` : 0 ; `licence` = libellés de catégorie marketplace/portfolio). Les éléments ci-dessous s'appuient sur des modules voisins.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-158 | Idées | 12.4 | PART | Projets au statut `draft` privés (RLS porteur) | Pas de « dépôt d'idée » horodaté | E: `PG/etu_s5.mjs` | — |
| C-159 | Inventions | 12.4 | MANQ | Aucun | Registre | À écrire | — |
| C-160 | Prototypes | 12.4 | MANQ | Aucun | — | À écrire | — |
| C-161 | Créations | 12.4 | PART | `portfolio_items` (`portfolio_save`, M/20261110010000), attestations de projet | Pas de statut PI | E: `PG/portfolio_etudiant.mjs` | — |
| C-162 | Versions | 12.4 | MANQ | Voir C-148 | — | À écrire | — |
| C-163 | Contributions | 12.4 | PART | `project_members.role` (texte) | Pas de part/droit par contributeur | E: `PG/etu_s5.mjs` | — |
| C-164 | Collaborateurs | 12.4 | PART | `project_members` | Pas d'accord de collaboration signé | E: idem | — |
| C-165 | Licences | 12.4 | MANQ | Voir C-063 | Modèle de licence (DEC juridique) | À écrire | — |
| C-166 | Autorisations | 12.4 | MANQ | Aucun | — | À écrire | — |
| C-167 | Conditions de commercialisation | 12.4 | MANQ | Aucune (campagnes `preorder` ≠ conditions de PI) | — | À écrire | DEC |
| C-168 | Partenariats | 12.4 | MANQ | `institutional_partnerships` = convention d'établissement, pas de PI | — | — | DEC |
| C-169 | Demandes de transfert technologique | 12.4 | MANQ | Aucun | Workflow dept/admin | À écrire | DEC |
| C-170 | Confidentialité avant publication d'une invention | 12.4 | PART | Visibilité de projet : non publié tant que non `approved` (RLS `projets : porteur, approuvés, département`) ; documents en Storage privé | Pas de NDA, pas de niveau de confidentialité par document ; le département voit les brouillons soumis | E: `PG/etu_s5.mjs`, `h7_cloisonnement.mjs` | Politique de confidentialité PI à valider |

## §12.5 Open Innovation Challenges

Socle : annonces de concours/défis d'organisations (`contest_announcements`, M/20261114001400, `ann_save` réservé aux comptes non étudiants/visiteurs : département, entreprises, ONG ; `L/concours_screens.dart`, `L/contests.dart`, `L/challenges_panel.dart`), prix avec séquestre (`ann_prize_*`, M/20261114004000), défis hebdomadaires étudiants (`weekly_challenges`, **autre fonction**). Écrans `s96_defis_innovation` (g_96) : liaison à `ann_*` **non vérifiée**.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-171 | Problématique | 12.5 | PART | `contest_announcements.why` ≤1000 + `description` | Pas de champ « problématique » structuré | E: `T/purchase/concours_annonces_test.dart` | — |
| C-172 | Objectifs | 12.5 | PART | `description` libre | Idem | — | — |
| C-173 | Contraintes | 12.5 | PART | `conditions[]` (≤12), `eligible_*` | — | E: `PG/concours.mjs` | — |
| C-174 | Livrables attendus | 12.5 | PART | `documents[]` (pièces demandées), `steps[]` | Livrables non typés | E: `T/purchase/concours_annonces_test.dart` | — |
| C-175 | Compétences recherchées | 12.5 | MANQ | Pas de colonne `skills` sur les annonces (existe sur `opportunities`) | Ajouter | À écrire | — |
| C-176 | Calendrier | 12.5 | OP | `opens_on`, `deadline`, `results_on`, `program_start` ; filtre des échus | — | E: `PG/opportunites.mjs`, `T/purchase/concours_annonces_test.dart` | Rejouer |
| C-177 | Conditions de participation | 12.5 | OP | `conditions[]`, éligibilité niveau/âge/filière/pays, `iut_only` | — | E: idem | — |
| C-178 | Récompenses éventuelles | 12.5 | DEC | `reward` texte + `ann_prize_set/checkout/award/refund` (séquestre) | Règles de prix/séquestre/remboursement = DEC §30 ; paiement Tara EXT | E: `PG/defis_sequestre.mjs`, `fin_k1.mjs`, `T/purchase/defis_sequestre_test.dart` | Décisions + paiement bac à sable |
| C-179 | Critères de sélection | 12.5 | PART | `criteria[]` (texte, ≤10) ; notation des concours de département à 4 critères fixes | Critères d'annonces non liés à la notation | E: `PG/etu_s6.mjs` | — |
| C-180 | Propriété intellectuelle (clause) | 12.5 | MANQ | Seule `original_certified` (case à cocher du dépôt) | Clause PI choisie par l'organisation | À écrire | DEC |
| C-181 | Jury | 12.5 | PART | Jury des concours de département (C-141) ; **pas de jury d'organisation** pour `contest_announcements` | Étendre jury aux annonces | E: `PG/etu_s6.mjs` | — |
| C-182 | Résultats | 12.5 | PART | `ann_win_submit`, `contest_ranking`, `_contest_podium`, `set_contest_status('results')`, `ann_prize_award` | Pas de publication de résultats structurée pour annonces externes | E: `PG/concours.mjs`, `T/journey/l10_hackathons_test.dart` | — |

## §12.6 Project Factory

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-183 | Formalisation du besoin | 12.6 | PART | Besoins/missions (`save_mission`, `L/need_pages.dart`, brouillon via Kéla), vœux (`save_wish`) | Pas de passage idée → projet structuré | E: `T/purchase/lot3_missions_test.dart` | — |
| C-184 | Étude de faisabilité | 12.6 | MANQ | Seule la note « faisabilité » d'un jury de concours | Gabarit + évaluation | À écrire | — |
| C-185 | Équipe | 12.6 | OP | `project_members`, `teammate_invite`, `contest_team_space` | — | E: `PG/etu_s5.mjs`, `coequipiers.mjs` | Rejouer |
| C-186 | Budget | 12.6 | MANQ | Voir C-128 | — | À écrire | — |
| C-187 | Planning | 12.6 | PART | `project_steps`, `contest_tasks` | Pas de diagramme/échéancier | E: `PG/etu_s5.mjs` | — |
| C-188 | Prototype | 12.6 | MANQ | Aucun | — | À écrire | — |
| C-189 | Documentation | 12.6 | PART | Fichiers de projet | Pas de wiki/versions | E: `PG/etu_s5.mjs` | — |
| C-190 | Tests | 12.6 | MANQ | Aucun | — | À écrire | — |
| C-191 | Partenaires | 12.6 | MANQ | Voir C-135 | — | À écrire | — |
| C-192 | Commercialisation | 12.6 | PART | Campagnes `preorder`, vœux/précommandes (`wish_preorders`), offre « projet à vendre ou licence » | Prix = DEC ; pas de plan de commercialisation | E: `PG/etu_s6.mjs`, `T/purchase/types_offres_test.dart` | — |

## §15 Innovations complémentaires

Règle du CDC : ces axes « doivent être spécifiés et étudiés sans être confondus avec des fonctions déjà implémentées » et « faire l'objet d'une conception détaillée et d'une validation technique avant activation ». Aucun document de conception de §15 n'existe dans `docs/` (grep `digital twin|expert network|supply chain|franchise` : 0 dans tout le dépôt).

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-193 | Digital Twin d'un talent (modèle évolutif, informations autorisées et vérifiables) | 15.1 | PART | Équivalent partiel : passeport/CV vivant (`L/l10_cv.dart`, `L/talent_passport.dart`, `cv_sends`), compétences (`talent_skills`), portfolio, certificats, visibilité (`talent_visibility_set`) | Pas de modèle « twin » unifié ni d'évolution calculée ; concept non spécifié | E: `PG/etu_s2.mjs`, `portfolio_etudiant.mjs`, `T/journey/lot_reseau_test.dart` | Document de conception + validation |
| C-194 | Digital Twin d'une organisation | 15.1 | MANQ | `company_profiles`, `L/company_public_page.dart` = fiche, pas de twin | Conception | À écrire | — |
| C-195 | Digital Twin d'un parcours de formation | 15.1 | MANQ | Aucun | Conception | À écrire | — |
| C-196 | Alimentation uniquement par informations autorisées/vérifiables | 15.1 | PART | `talent_visibility_get/set`, `document_review`, `mate_consents`, `profile_verified` | À généraliser à tout twin | E: `PG/etu_s2.mjs` | — |
| C-197 | Expert Network : identifier des experts | 15.2 | PART | `mentors_list`, `mentor_match`, `_mentor_has_proof` (preuve d'expertise), `talents_search` ; mentors validés par département (`mentor_validate`) | Annuaire limité aux mentors/talents IUT ; pas d'experts externes | E: `PG/mentors.mjs`, `etu_s8.mjs` | — |
| C-198 | Solliciter des experts pour des missions | 15.2 | OP | `talent_contact_request`, `propose_on_mission`, invitations `opp_invite` | Dépend des règles missions (lot B) | E: `PG/ent_f1.mjs`, `invitations_offres.mjs` | — |
| C-199 | …pour des consultations | 15.2 | PART | `mentor_request/decide` (demande, pas de séance) | Réservation, paiement, salle (C-075) | E: `PG/mentors.mjs` | — |
| C-200 | …pour des formations | 15.2 | MANQ | Aucun | — | À écrire | — |
| C-201 | …pour des collaborations | 15.2 | PART | `teammate_invite`, `project_member_invite` | Réservés aux étudiants | E: `PG/coequipiers.mjs` | — |
| C-202 | Opportunity Radar : opportunités internes (offres, missions, concours) | 15.3 | OP | `opps_list`, `opps_recommended`, `opp_detail`, `opp_alert_set`, `contest_announcements`, `open_calls` ; UI `L/opportunites_screens.dart` | Modules séparés, pas de vue unifiée « radar » | E: `PG/opportunites.mjs`, `etu_s8.mjs`, `T/journey/opportunites_test.dart`, `T/purchase/opportunites_test.dart` | Rejouer |
| C-203 | Opportunités externes autorisées (appels à projets, financements, partenariats) | 15.3 | MANQ | Aucune ingestion de sources externes ; saisie manuelle par organisations | Veille/connecteurs (EXT), validation de source | À écrire | — |
| C-204 | Chaque opportunité : source, date, lien, état de validité | 15.3 | PART | `org_name`, `created_at`, `deadline`, `status`, `verified`, `review_note` ; **pas de lien source** ni de date de vérification | Champs `source_url`, `verified_at` | E: `PG/opportunites.mjs` | — |
| C-205 | Aucune opportunité expirée ou inventée présentée comme active | 15.3 | NV | Filtre `status='published' and (deadline is null or deadline >= current_date)` dans `opps_list` (`M/20261114004200_correctifs_visiteur_suite`) ; modération avant publication ; UI sans données de maquette en mode connecté (`T/journey/maquette_interdite_test.dart`) | **Aucun test de l'échéance** (`opportunites.mjs` teste filtres type/rémunération/compétence/validation, pas la date) ; annonces sans `deadline` actives indéfiniment ; `contest_announcements` et `open_calls` : filtre d'échéance non vérifié | E: `PG/opportunites.mjs` (partiel) → *À écrire* : scénario avec échéance passée sur `opps_list`, `open_calls`, `contest_announcements` | Scénario PGlite avec date passée |
| C-206 | Autonomous Workspace : plusieurs agents IA collaborant sur des tâches | 15.4 | MANQ | Aucun agent (voir §20) | Conception complète | À écrire | — |
| C-207 | …contrôle humain | 15.4 | MANQ | Précédent : brouillon de besoin validé (C-038) | — | À écrire | — |
| C-208 | …permissions des agents | 15.4 | MANQ | Permissions humaines par équipe existent (`admin_permissions`, H4), pas pour agents | — | À écrire | — |
| C-209 | …journalisation | 15.4 | PART | Audit général (`Backend.audit`, `L/audit.dart`, `admin_team_history`) ; `kela_usage` (compteur seulement) | Journal d'actions d'agent | E: `T/purchase/admin_audit_test.dart` | — |
| C-210 | …validation des actions sensibles | 15.4 | PART | MFA par opération sensible côté humain (`20261121010000_k1_mfa_operations_sensibles`) | Pas appliqué à des agents | E: `PG/fin_k1.mjs` | — |
| C-211 | Reputation & Trust Graph : réputation fondée sur preuves, réalisations, transactions, validations | 15.5 | PART | Avis (`reviews`, `shop_reviews`, `mentor_reviews`), `SellerReputationBlock` (note moyenne + répartition, `L/vendeur_public.dart`), badge certifié (`certification=approved`), `vendeur_verifie`, niveaux/points (`user_level`), certificats | Pas de graphe (liens entre preuves/validateurs) ; écran 38 en maquette hors connexion (`demoContent`) | E: `T/purchase/vendeur_verifie_test.dart`, `supabase/tests/vendeur_public_local.sql`, `PG/niveau_profils.mjs` | Conception du modèle de preuves |
| C-212 | Ne pas réduire la réputation à une note opaque unique | 15.5 | PART | Composantes séparées : note + répartition d'avis, badge, niveau, ventes ; aucun score global | Pas de page de détail des composantes pour tous les rôles | E: idem | — |
| C-213 | Team Intelligence : complémentarités de compétences | 15.6 | PART | `_opp_match` (score de correspondance offre ↔ étudiant, M/20261114003700), `mates_search`, catégories `mate_categories` | Aucune analyse de complémentarité d'équipe | E: `PG/score_correspondance.mjs`, `coequipiers.mjs` | — |
| C-214 | …disponibilités | 15.6 | PART | `student_availability` (M/20261114003000) | Non agrégé par équipe | E: `PG/portfolio_etudiant.mjs` | — |
| C-215 | …besoins et possibilités de collaboration | 15.6 | MANQ | Aucun | — | À écrire | — |
| C-216 | Accessibility Intelligence : lecteurs d'écran | 15.7 | NV | `Semantics` dans ≈43 fichiers `lib/figma/live` ; audits `T/journey/audit_accessibilite_test.dart` (`labeledTapTargetGuideline`, rapport par écran) ; `GAccess.speak` (web) lit seulement les alertes | Les écrans `g_xx` sont des toiles à positions absolues : étiquettes non garanties ; aucun test TalkBack/VoiceOver réel | E: `audit_accessibilite_test`, `audit_accessibilite_detail_test` | Essai TalkBack/VoiceOver + seuil bloquant dans les tests |
| C-217 | Navigation accessible (clavier, focus) | 15.7 | PART | Anneau de focus sur zones cliquables ; D-085 « clavier non implémenté » pour listes déroulantes (ETAT_ECRANS) | Parcours clavier complet | E: `T/journey/interactions_navigation_test.dart`, `zones_tactiles_detail_test.dart` | Essai clavier |
| C-218 | Sous-titres | 15.7 | MANQ | Voir C-022/C-088 | — | À écrire | — |
| C-219 | Descriptions d'images (texte alternatif) | 15.7 | MANQ | Aucun champ alt (grep `alt text|texte alternatif` : 0), `post_media` sans description | Colonne `alt_text` + saisie + lecture | À écrire | — |
| C-220 | Commandes vocales | 15.7 | PART | Dictée dans Kéla/commentaires (`Dictation`, `speech_to_text`) ; **pas de commandes de navigation** | Commandes vocales d'app (DEC périmètre) | Aucun test | — |
| C-221 | Contrastes adaptés | 15.7 | PART | Réglage « contraste » (`GAccess.contrast`, `MediaQuery.highContrast`), gris relevé `#57545F` (306 écrans) | Seuils par écran testés (`contrastes_detail_test`) mais maquettes régénérées ; effet partiel (gris moyens seulement) | E: `T/journey/contrastes_detail_test.dart`, `audit_accessibilite_test` | Mesure WCAG sur captures réelles |
| C-222 | Formulaires accessibles | 15.7 | NV | `form_inputs.dart`, `form_fields.dart`, `form_dialog_test` ; zones ≥48 dp testées | Pas d'audit label/erreur associé par champ | E: `T/account/form_dialog_test.dart`, `zones_tactiles_detail_test.dart` | Audit formulaire par formulaire |
| C-223 | Expérience faible débit | 15.7 | PART | `GData` (`lib/figma/gdata.dart`) : `reduceImages` (images réduites hors Wi-Fi), `blockVideo` (lecture auto bloquée : `home_live.dart:187`, `project_cards.dart:312`, `social_posts.dart:220`), `blockDownload` (`social_posts.dart:855`), `blockSync` ; `connectivity_*` ; **« économie de données » activée par défaut** (`dataPrefsDefaults`), donc les lectures automatiques sont bloquées par défaut | Aucun mode hors ligne (PWA désactivée par `--pwa-strategy=none`) ; effet des réglages jamais testé ni mesuré sur réseau réel | Aucun test dédié aux réglages 184/150 | Test d'effet des réglages + mesure réseau |
| C-224 | Adaptation aux besoins des utilisateurs (taille texte, mouvement) | 15.7 | PART | `textSizeProvider` (0,9–1,25), `reduce_motion`, `large_text`, `contrast`, `screen_reader` (écrans 149/186), **stockés sur l'appareil** (SharedPreferences) | Pas de préférence liée au compte ; pas d'adaptation automatique | E: `T/journey/polices_agrandies_test.dart` | — |
| C-225 | Supply Chain Network : réseau fournisseurs/producteurs/distributeurs/acheteurs/partenaires | 15.8 | PART | Boutiques/vendeurs (`shops`), achats B2B (`L/company_purchases.dart`, `F4_achats_b2b`), appels d'entreprises (`open_calls`), livraison (`delivery_zones`) | Pas de rôles fournisseur/producteur/distributeur ni de graphe de relations | E: `PG/ent_f4.mjs`, `PG/scenario.mjs` | Conception |
| C-226 | …traçabilité | 15.8 | MANQ | Écrans passeport produit 211 en maquette ; aucun événement de traçabilité en base | §17.3 (autre matrice) | À écrire | — |
| C-227 | …gestion des relations commerciales | 15.8 | PART | Devis/négociation (`L/quote_negotiation.dart`, `negotiation devis`), `supplier` absent | Contrats cadres, historiques | E: `PG/ent_f4.mjs` | — |
| C-228 | Franchise & Business Replication : étudier/structurer la reproduction de modèles | 15.9 | MANQ | Aucun (grep `franchise` : 0) | Étude de conception ; droits/accords = DEC | — | — |
| C-229 | …boutiques et services dans d'autres zones sous réserve de droits | 15.9 | MANQ | `delivery_zones`/`neighborhoods` = livraison locale uniquement | Multi-zone géographique | — | DEC |
| C-230 | Professional Communities : par centre d'intérêt | 15.10 | OP | `communities.kind='interest'`, `category` | — | E: `PG/communities.mjs`, `T/purchase/communautes_types_test.dart` | Rejouer |
| C-231 | …par établissement | 15.10 | PART | Types `filiere`/`promo`/`alumni` rattachés au contexte IUT ; pas de FK vers `institutions` | Communautés multi-établissements | E: `PG/communities.mjs` | — |
| C-232 | …par métier | 15.10 | PART | `category` texte libre (≤40) | Référentiel de métiers | — | — |
| C-233 | …par secteur | 15.10 | PART | Idem | Référentiel de secteurs | — | — |
| C-234 | …par compétence | 15.10 | MANQ | Aucun lien `community` ↔ `skill_catalog` | — | À écrire | — |
| C-235 | …par région | 15.10 | MANQ | Aucun champ de région/ville | — | À écrire | — |
| C-236 | Institutional Intelligence : suivi des productions | 15.11 | OP | `productions` (`production_create/update`, `staff_productions`), `dept_projects`, `direction_*` | Tableaux fondés sur données saisies | E: `supabase/tests/encadrement_local.sql`, `act_h2.mjs`, `act_h3.mjs` | Rejouer |
| C-237 | …compétences | 15.11 | OP | `dept_skills`, `dept_student_detail`, `skills_radar` (admin) | — | E: `PG/act_h2.mjs`, `h7_cloisonnement.mjs` | Rejouer |
| C-238 | …projets | 15.11 | OP | `dept_projects`, `direction_performance`, `direction_dashboard` | — | E: `PG/act_h3.mjs`, `h7_cloisonnement.mjs` | — |
| C-239 | …partenariats | 15.11 | OP | `partnership_save/decide`, `institutional_validation_*`, `org_partnership_respond`, `direction_dept_partnerships` | Partenariats institutionnels = DEC §30 pour les règles | E: `PG/act_h3.mjs`, `fin_k4.mjs` | — |
| C-240 | …besoins | 15.11 | PART | `dept_opportunities`, `open_needs` du radar, besoins d'entreprises | Pas d'analyse de besoins institutionnels agrégée | E: `PG/act_h2.mjs` | — |
| C-241 | …dans le respect des permissions | 15.11 | OP | Cloisonnement RLS/RPC (H2, H7 : `_dept_scope`, droits minimaux K1) | — | E: `PG/h7_cloisonnement.mjs` (49 Ko), `T/journey/h7_org_dept_direction_propre_test.dart` | Rejouer |
| C-242 | Conception détaillée + validation technique avant activation en production (§15) | 15.x | MANQ | Aucun document de conception pour Digital Twin, Expert Network, Autonomous Workspace, Trust Graph, Supply Chain, Franchise ; seul `docs/transformation/ALGORITHME_RECOMMANDATION.md` existe (fil social) | Rédiger les spécifications | — | Revue propriétaire |

## §20 Kéla AI et architecture multi-agents

Constat : **un seul assistant** (`F/kela-chat`, un seul prompt système statique, appel unique à l'API Anthropic `claude-haiku-5-5` par défaut, sans outil, sans lecture de données utilisateur). L'application l'appelle depuis `L/kela.dart` et `L/decisions.dart` (`KelaBrief`). **Sans `ANTHROPIC_API_KEY` la fonction répond 503 `not_configured`** : l'IA est donc **EXT**. Aucune exécution réelle n'a été prouvée (un seul test : `T/journey/etu_s9_test.dart` S9-20, sans serveur). Aucune coordination multi-agents, aucun registre d'agents, aucune table d'actions.

| ID | Exigence | § | État | Preuves | Manque / tâche | Tests | Preuve requise |
|---|---|---|---|---|---|---|---|
| C-243 | Kéla assistant intelligent transversal | 20.1 | EXT | `F/kela-chat/index.ts`, `kelaThreadProvider`, `kelaAvailableProvider`, écrans 230/231/232 (`lib/features/ai_kela`) | Clé IA (EXT : `ANTHROPIC_API_KEY`, `KELA_MODEL`) ; périmètre = « décrire un besoin » seulement | E: `T/journey/etu_s9_test.dart` (S9-20) | Appel réel avec clé ; test Deno de la fonction (À écrire) |
| C-244 | Comprendre le contexte de l'utilisateur | 20.1 | MANQ | Le prompt ne reçoit ni rôle, ni profil, ni commandes ; seul l'historique **fourni par le client** (≤8 messages) | Contexte autorisé injecté côté serveur selon le rôle | À écrire | — |
| C-245 | L'aider dans les tâches autorisées | 20.1 | PART | Création d'un brouillon de besoin (`BRIEF={…}` → `myNeedsDialog`, L/kela.dart:143-167) | Aucune autre tâche (commande, paiement, mission) n'est exécutable ; pas d'outils | E: aucun | Test de parcours avec clé |
| C-246 | Agent Talent | 20.2 | MANQ | Équivalents **non-IA** : `talents_search`, `opp_suggested_students` (règles SQL) | Agent | À écrire | EXT IA |
| C-247 | Agent Recrutement | 20.2 | MANQ | `opps_recommended`, `L/talent_search_panel.dart` (règles) | Agent | À écrire | EXT IA |
| C-248 | Agent Évaluation | 20.2 | MANQ | Voir §8 (lot dédié) | — | À écrire | EXT IA |
| C-249 | Agent Carrière | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-250 | Agent Commerce | 20.2 | MANQ | `trending_products`, `marketplace_search` (règles) | — | À écrire | — |
| C-251 | Agent Vendeur | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-252 | Agent Client | 20.2 | PART | Seul comportement spécialisé : brief de besoin du client (C-245), prompt « comprendre une commande, un paiement ou une mission » sans accès aux données | Accès contextuel autorisé | À écrire | EXT clé |
| C-253 | Agent Entreprise | 20.2 | MANQ | Aucun (les besoins d'entreprise utilisent le même brouillon) | — | À écrire | — |
| C-254 | Agent Procurement | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-255 | Agent Innovation | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-256 | Agent Projet | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-257 | Agent Créateur | 20.2 | MANQ | Aucun (voir §9.3) | — | À écrire | — |
| C-258 | Agent Contenu | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-259 | Agent Traduction | 20.2 | MANQ | Aucun (voir §11) | — | À écrire | EXT |
| C-260 | Agent Formation | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-261 | Agent Support | 20.2 | MANQ | Support humain : `support_ticket_create/reply/close`, `L/support_screens.dart`, `L/support_staff.dart` | Agent | E: `PG/l6_aide_notifications.mjs` (humain) | — |
| C-262 | Agent Finance | 20.2 | MANQ | Aucun | Décisions financières = DEC | À écrire | — |
| C-263 | Agent Institution | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-264 | Agent Administration | 20.2 | MANQ | Aucun | — | À écrire | — |
| C-265 | Agent Sécurité et conformité | 20.2 | MANQ | Modération humaine (C-016) ; `account_flags`, `security_accounts_search` | — | À écrire | — |
| C-266 | Recevoir une mission | 20.3 | MANQ | Aucune file de missions d'agents (les « missions » du code sont des missions étudiants) | Modèle `agent_tasks` | À écrire | — |
| C-267 | Analyser le contexte autorisé | 20.3 | MANQ | Voir C-244 | — | À écrire | — |
| C-268 | Consulter les données permises | 20.3 | MANQ | Aucun accès de lecture pour l'IA | Outils en lecture seule avec RLS | À écrire | — |
| C-269 | Se répartir des tâches | 20.3 | MANQ | Aucun | Orchestrateur | À écrire | — |
| C-270 | Produire des résultats | 20.3 | PART | Réponse texte + `BRIEF` | Résultats structurés | À écrire | — |
| C-271 | Vérifier leurs résultats | 20.3 | MANQ | Aucun (le brief est JSON-parsé sans validation de schéma côté fonction ; le client le prévisualise) | Étape de vérification | À écrire | — |
| C-272 | Transmettre des éléments à un autre agent | 20.3 | MANQ | Aucun | — | À écrire | — |
| C-273 | Demander une validation humaine si nécessaire | 20.3 | PART | Brouillon de besoin non publié sans clic de l'utilisateur ; MFA humaine sur opérations sensibles | Mécanisme générique d'approbation d'actions d'agent | E: aucun | — |
| C-274 | Sécurité : permissions minimales | 20.4 | PART | `kela-chat` n'a aucun outil et ne lit aucune donnée (minimal par absence) ; `kela_usage` inaccessible aux clients (`revoke all`) ; fonction exige un utilisateur connecté (`auth.getUser`) | Modèle de permissions par agent à construire | À écrire (Deno) | Revue |
| C-275 | Sécurité : isolation des organisations | 20.4 | MANQ | Aucun contexte d'organisation dans l'IA ; à concevoir avant tout accès aux données | Multi-tenant des agents | À écrire | — |
| C-276 | Sécurité : protection contre les injections de prompt | 20.4 | NV | Historique filtré (rôles `user`/`assistant`, 8 derniers, 2 000 car.) ; mais le client peut forger des tours « assistant » ; le JSON `BRIEF` issu du modèle n'est pas validé en schéma | Tests d'injection, validation de schéma, séparation des rôles | À écrire | Jeu de tests adversariaux |
| C-277 | Sécurité : contrôle des outils | 20.4 | MANQ | Aucun outil à contrôler | Registre d'outils et liste blanche | À écrire | — |
| C-278 | Sécurité : journalisation | 20.4 | PART | `kela_usage` (user_id + horodatage) ; **ni contenu, ni coût, ni résultat** ; audit général hors IA | Journal d'actions d'agents | À écrire | — |
| C-279 | Sécurité : limites de dépenses | 20.4 | PART | Plafond 30 messages/h/utilisateur, `max_tokens: 600`, entrée ≤2 000 car. | Plafond global/par organisation, suivi du coût ; seuils = DEC §30 | À écrire | DEC |
| C-280 | Sécurité : quotas | 20.4 | EXT | Quota 30/h (`kela_usage` + 429) dans `kela-chat` ; actif seulement avec clé | Aucun test du 429 | À écrire (Deno) | Appel réel |
| C-281 | Sécurité : validation humaine des opérations sensibles | 20.4 | PART | Voir C-273 | — | À écrire | — |
| C-282 | Sécurité : interdiction de divulguer des données privées | 20.4 | PART | Aucune donnée privée n'est transmise au modèle (prompt statique) ; en revanche les messages de l'utilisateur partent chez Anthropic (DPA/politique de confidentialité à valider) | Consignes de confidentialité dans le prompt, tests | À écrire | Revue juridique |
| C-283 | Sécurité : pas de paiement, suppression ou modification sensible sans autorisation | 20.4 | PART | Conforme par construction (aucune écriture possible depuis l'IA) ; non couvert par un test | Test statique « aucun outil d'écriture » + garde-fou futur | À écrire | — |
