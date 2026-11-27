# H13.1 · Lot C — Matrice d'accès aux médias (public / privé)

Périmètre : compartiments Supabase Storage, leurs usages dans l'application Flutter, règles d'accès, migration `20261129010000` → `20261129010200`, procédure de bascule et de retour arrière.
Aucune donnée de production n'a été lue ni modifiée pour ce lot (accès interdit pendant H13.1) : l'état réel doit être constaté avec `tool\backup\media_inventory.mjs` (lecture seule) par le propriétaire.

## 1. Le problème

Le compartiment `post-media` est `public = true` (migration 20261101000600). La route `/storage/v1/object/public/post-media/<chemin>` **ne passe pas par les politiques RLS** : toute personne qui connaît l'URL lit le fichier.
H13 (20261128050500) a restreint la lecture via `storage.objects` (`_post_media_readable`), ce qui n'empêche que la liste et l'API authentifiée, pas l'URL publique.
Un média non public (publication retirée/masquée, communauté fermée, histoire expirée, brouillon) reste donc lisible par URL directe tant qu'il est dans un compartiment public.

## 2. Inventaire des compartiments

| Compartiment | Public ? | Migration | Contenu | Usage Flutter |
|---|---|---|---|---|
| `post-media` | oui | 20261101000600 (+GIF 20261113000100) | photos/vidéos de publications, reels, histoires (avant H13.1), couvertures de profil, logos/couvertures de communautés et d'organisations, couvertures de lives, médias d'offres, pièces jointes de commentaires | `Backend.postMediaUrl`, `uploadPostMedia`, `purgeReplacedPostMedia` |
| **`post-media-private`** (nouveau) | **non** | 20261129010000 | médias NON publics déposés à partir de H13.1 : histoires, publications de communautés non publiques ; destination de la bascule des anciens médias non publics | `MediaAccess` (URL signée 1 h) |
| `avatars` | oui | 20261104000100 | photos de profil | `Backend.publicFileUrl('avatars', …)` |
| `listing-images` | oui | 20261030000200 | photos d'annonces, de variantes, de boutique | `Backend.uploadPublic`, `getPublicUrl` |
| `listing-videos` | oui | 20261107000000 | vidéos d'annonces | `Backend.uploadPublic` |
| `portfolio-media` | oui | 20261110010000 | médias du portfolio (profil public) | `tpUpload` |
| `project-media` | oui | 20261110010000 | médias des projets publics | `tpUpload` |
| `project-files` | non | 20261031000100 | fichiers de projets | `createSignedUrl` 1 h |
| `chat-files` | non | 20261030000600 | pièces jointes des conversations | `createSignedUrl` 1 h |
| `profile-documents` | non | 20261104000100 | justificatifs / documents de profil et d'organisation | `createSignedUrl` 10 min |
| `community-files` | non | 20261114001000 | fichiers partagés d'une communauté (membres seulement) | `downloads.dart` (URL signée) |
| `digital-files` | non | 20261126050000 | ressources numériques achetées | URL signée |
| `live-replays` | non | 20261127300000 | enregistrements de lives (accès contrôlé) | URL signée |

Décision : `avatars`, `listing-images`, `listing-videos`, `portfolio-media`, `project-media` sont destinés à être publics (profil public, catalogue) : **inchangés**. Les compartiments déjà privés sont inchangés.
Seul `post-media` mélange des contenus publics et non publics : c'est lui qui est traité.

## 3. Matrice d'accès par type de contenu

| Contenu | Compartiment | Qui lit | Qui écrit / modifie / supprime | Mode |
|---|---|---|---|---|
| Publication publiée (hors communauté fermée) | `post-media` | tout le monde | auteur : dépôt et suppression dans son dossier `<uid>/` ; pas de modification (remplacement = nouveau fichier) | public (URL publique) |
| Publication en attente de validation | `post-media` | URL publique (connue) ; liste : auteur et modération | auteur | public — **limite résiduelle** (voir §7) |
| Publication retirée / masquée | `post-media` puis `post-media-private` après bascule | après bascule : auteur, modération | auteur | signé après bascule |
| Publication d'une communauté **publique** | `post-media` | tout le monde | auteur | public |
| Publication d'une communauté **fermée** (nouveau) | `post-media-private` | membres (statut actif), auteur, modération | auteur (dossier `<uid>/private/`) | **signé 1 h** |
| Publication d'une communauté fermée (ancien) | `post-media` → bascule | idem après bascule | auteur | signé après bascule |
| Histoire (nouveau) | `post-media-private` | personnes pouvant voir l'histoire : active, visible, auteur non suspendu, profil visible, pas de blocage ; auteur ; modération | auteur | **signé 1 h** ; illisible dès l'expiration (hors URL déjà signée, ≤ 1 h) |
| Histoire expirée / masquée (ancienne) | `post-media` → bascule | auteur, modération | auteur | signé après bascule |
| Brouillon / envoi non rattaché | `post-media` (anciens) ou privé | auteur et modération | auteur | privé après bascule explicite des orphelins (`--orphans`) |
| Pièce jointe de commentaire | `post-media` | comme la publication parente | auteur | public / signé selon la publication |
| Couverture de profil, logo/couverture de communauté ou d'organisation, couverture de live, média d'offre | `post-media` | tout le monde (page publique) | propriétaire | public (conservé) |
| Avatars | `avatars` | tout le monde | propriétaire (dossier) | public |
| Annonces (images, vidéos) | `listing-images`, `listing-videos` | tout le monde | vendeur | public |
| Documents de profil / justificatifs | `profile-documents` | propriétaire, administration | propriétaire | signé 10 min |
| Fichiers de conversation | `chat-files` | participants | participants | signé 1 h |
| Fichiers de communauté | `community-files` | membres | déposant | signé |
| Ressources numériques, replays | `digital-files`, `live-replays` | acheteurs / ayants droit | vendeur, service | signé |

Politiques `storage.objects` du compartiment privé (migration 20261129010000) : lecture = `_post_media_private_readable(name)` (propriétaire du dossier, modération (permissions `security.moderation` / `security.reports`) ; **un compte Département n'a aucun accès particulier** (retiré à l'intégration : il lisait tous les fichiers privés, contraire au cloisonnement ; test `h131_media.mjs` et `h7_cloisonnement.mjs` 9.d), ou contenu référençant le fichier accessible : publication accessible, commentaire d'une publication accessible, histoire active et visible) ; dépôt, modification, suppression = dossier `<uid>/` seulement (un membre, un tiers, la modération ne suppriment pas via le stockage ; la modération agit sur le contenu par les fonctions serveur existantes). Un fichier non référencé n'est lisible que par son propriétaire et la modération. Un anonyme ne lit que ce qui est publiquement visible (histoire active, publication publique).

## 4. Conception de la migration (additive, aucune suppression)

1. `20261129010000_h131_media_bucket_prive.sql` : compartiment `post-media-private` (`public = false`, mêmes limite et types que `post-media`), fonction `_post_media_private_readable`, 4 politiques (lecture, dépôt, modification, suppression).
2. `20261129010100_h131_media_suivi_cibles.sql` : colonne `post_media.storage_bucket` (défaut `post-media`), table `media_migration` (file et état de la bascule, RLS sans accès client), `_media_ref_state(chemin)` (public / pending / restricted / unreferenced, indépendant de la personne connectée), `post_media_signed_target(chemin)` et `post_media_targets(chemins[])` (appelables par anon et connectés : indiquent seulement si le fichier est servi par le compartiment privé).
3. `20261129010200_h131_media_bascule_privee.sql` (réservé au `service_role`, clé de service côté serveur) :
   - `media_migrate_private_batch(limite, avec_orphelins)` : met en file les fichiers dont **tous** les contenus sont restreints (publication retirée / masquée, communauté fermée, histoire expirée ou masquée, commentaire non public ; orphelins de plus de 24 h seulement sur demande). **Jamais** : un fichier encore utilisé par un contenu public (ex. couverture partagée), une publication en attente.
   - Copie du fichier : par l'API Storage (`tool\backup\media_migrate_private.mjs`) car une copie SQL de la ligne `storage.objects` ne copie pas le contenu binaire.
   - `media_migrate_confirm(chemin)` : vérifie l'existence de la copie, la taille et le type identiques ; `verified` → met à jour `post_media.storage_bucket` et marque l'ancien fichier supprimable (`old_delete_marked_at`) ; sinon `failed` / `missing_destination`.
   - `media_old_deletion_candidates(avec_reversibles)` : liste en lecture seule ce qu'un humain peut supprimer de `post-media` (vérifié, copie présente, toujours restreint, motif non réversible : publication retirée, histoire expirée). Les motifs réversibles (masquée, communauté fermée, commentaire) ne sont proposés que sur demande explicite.
   - `media_migrate_rollback(chemin | tout)` : annule (la lecture revient à `post-media` tant que l'ancien fichier existe) ; la copie privée est conservée ; refuse si l'ancien fichier a été supprimé (recopier d'abord).
   - `media_migration_report()` : compteurs (objets par état, restreints encore exposés par URL publique, en file, vérifiés, en échec, annulés, supprimables).
   - **Aucune suppression automatique, nulle part** : ni dans les migrations, ni dans les fonctions, ni dans les scripts.
4. Le compartiment `post-media` n'est **pas** passé en privé : les anciennes URL des contenus publics continuent de fonctionner.

### Procédure d'exploitation (propriétaire, après application des migrations)

1. Constat (lecture seule) : `node tool\backup\media_inventory.mjs --linked` (ou `--rest` avec `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` dans l'environnement).
2. File d'attente sans copie : `node tool\backup\media_migrate_private.mjs --dry-run`.
3. Copie + vérification par lots : `node tool\backup\media_migrate_private.mjs --limit 50` (clé de service lue dans l'environnement, jamais dans le dépôt). Relancer jusqu'à ce que `to_queue`, `queued` et `failed` soient à 0.
4. Contrôle : `media_migration_report()` ; ouvrir quelques médias concernés depuis un compte membre / non membre.
5. Seulement après contrôle, supprimer **à la main** (tableau de bord Storage ou API avec confirmation humaine) les anciens fichiers listés par `media_old_deletion_candidates()`. C'est l'étape qui ferme réellement l'URL publique ancienne ; tant qu'elle n'est pas faite, le fichier d'origine reste lisible par son URL.

### Retour arrière

- Par fichier ou global : `select media_migrate_rollback('<chemin>')` / `select media_migrate_rollback()` (service_role). Les lectures reviennent à `post-media` (ancien fichier conservé).
- Complet : retirer les 4 politiques « médias privés : … » et les fonctions (en-têtes des 3 migrations). Le compartiment `post-media-private` et ses fichiers ne sont supprimés qu'à la main, après copie.
- Application : les nouveaux envois privés retombent sur `post-media` si `post_media_targets` est indisponible pour les anciens ; pour de nouveaux fichiers `…/private/…` l'application a besoin du compartiment privé (déployer les migrations avant l'application).

## 5. Flutter

- `lib/figma/live/media_access.dart` : `MediaAccess` (repère `<uid>/private/…`, signature `createSignedUrl` 3600 s au plus, réutilisée 50 min, `warm()` pour préparer une liste, `post_media_targets` pour les anciens fichiers basculés).
- `Backend.postMediaUrl` renvoie l'URL signée si elle est prête, sinon l'URL publique (repli = ancien comportement) ; `Backend.removeFile` choisit le bon compartiment.
- `uploadPostMedia(…, private: true)` pour les histoires (`stories.dart`) et les publications de communautés non publiques (`communities_screens.dart` → `chooseAttachment(private: c.privacy != 'public')`).
- Listes qui préparent les URL signées : histoires (`storiesProvider`), fil de communauté (`communityFeedProvider`), vignettes de modération (`moderation_reseau.dart`).
- Publications publiques, reels, avatars, annonces : **inchangés**.
- Limite : une URL signée expire au bout de 1 h ; un écran resté ouvert plus d'une heure doit être rafraîchi (retour à la liste) pour obtenir de nouvelles URL.

## 6. Preuves

- `supabase\tests\marketplace_pglite\h131_media.mjs` : 76 contrôles (voir le rapport) : compartiment `public = false`, lecture refusée à un tiers / anonyme / non-membre, acceptée à l'auteur / membre / modération, histoire expirée ou blocage, écriture-modification-suppression limitées au dossier de l'auteur, cibles, bascule (rien supprimé, rejeu sans doublon, vérification taille/type, retour arrière, liste de suppression en lecture seule), refus des comptes applicatifs, rejeu des migrations.
- `test\journey\h131_media_test.dart` : chemins privés, URL signée ≤ 3600 s, URL publique inchangée pour les médias publics, anciens fichiers basculés, dépôt dans le bon compartiment, suppression dans le bon compartiment.
- Preuve en base de test que « le média privé n'est pas lisible par URL directe » : le compartiment est `public = false` et aucune politique `storage.objects` n'autorise un tiers ou un anonyme à le lire ; c'est la règle de Supabase Storage que la route `/object/public/` ne sert que les compartiments `public = true`.
- **Ne peut être prouvé que contre Supabase réel** : (a) qu'une requête HTTP `GET /storage/v1/object/public/post-media-private/<chemin>` renvoie bien une erreur (comportement du service Storage, absent de PGlite) ; (b) que `createSignedUrl` d'un tiers non autorisé est refusé par le service ; (c) que la copie `/object/copy` entre compartiments conserve contenu, taille et type ; (d) l'état réel des objets de production (nombre de médias restreints encore exposés) via `media_inventory.mjs`.

## 7. Risques résiduels

- Tant que les anciens fichiers restreints de `post-media` ne sont pas supprimés à la main (étape 5), leur URL directe reste lisible.
- Les publications **en attente de validation** et les nouveaux envois de publications ordinaires (avant publication) sont déposés dans `post-media` : leur URL est lisible par qui la connaît pendant l'attente. Un passage de ces envois par le compartiment privé demanderait de déplacer le fichier à la publication (décision et chantier distincts).
- Un média migré dont le contenu redevient public (publication réaffichée, communauté rouverte) reste lisible par l'URL publique tant que l'ancien fichier existe ; c'est pourquoi la liste de suppression exclut les motifs réversibles par défaut et ce qui est redevenu public.
- Une histoire privée expirée reste lisible au plus 1 h par les URL signées déjà émises.
