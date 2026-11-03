# Réseau social : état réel et plan d'implémentation

**Rien de nouveau n'est livré côté interface ou base dans ce lot pour le réseau social.** Ce document dit ce qui existe, ce qui manque et dans quel ordre le construire sans dupliquer.

## Existant (lu dans les migrations)

| Fonction | Table / module | Appliqué en production ? | Écrans |
|---|---|---|---|
| Publications médias (reels) : vidéo ou image, légende 300 car., 10 étiquettes, lien vers une annonce, modération `pending / published / hidden` | `posts` (migration 20261101000600) | **non** (local, réplique 12/12 selon `02_ETAT_FONCTIONNALITES.md`) | 245, 250, P4, 250b, 253, 253b |
| J'aime, signalement | `post_likes`, `post_reports` | non | idem |
| Visibilité gratuite par série de 6 jours, points | `post_boosts`, `points_ledger`, `daily_checkins` | non | idem |
| Suivre | `engagements` (`kind = 'follow'`) | oui (migration 20261030001000) | profils |
| Messagerie 1-à-1, non-lus, pièces jointes de commande | `conversations`, `conversation_participants`, `messages` + vues | oui | 52, 53 |
| Notifications, préférences, appareils, file d'envoi | `notifications`, `notification_preferences`, `device_tokens`, `notification_outbox` | partiel (canaux : local ; aucun envoi réel) | 50, 51 |

## Manques par rapport à la mission

Publications texte, lien, projet, produit, service, événement, opportunité ; visibilité ; commentaires et réponses ; partages ; enregistrements ; masquer ; ne plus suivre ; listes d'abonnés et d'abonnements ; suggestions ; couverture et visibilité par champ du profil ; blocage et signalement de conversation ; accusés de réception ; fil classé.

## Ordre de construction (sans nouvelle table parallèle)

1. Étendre `posts` : colonne `kind`, `body`, `visibility`, `community_id` (nullable), `media_path` devenu facultatif pour les types sans média ; migration **non appliquée**, testée sur réplique locale.
2. Tables nouvelles minimales : `post_comments`, `post_saves`, `post_shares` (compteurs dérivés par vues), `user_blocks`.
3. Abonnements : fonctions `follow_user` / `unfollow_user` au-dessus de `engagements` ; vues `my_followers`, `my_following`.
4. Écrans existants à connecter : 245 (fil), 10 et 74 (profil public), 52 et 53 (conversations), 50 et 51 (notifications). Aucun nouvel écran tant qu'un écran existant convient.
5. Brancher `FeedRanker` sur la lecture du fil (RLS : lecture selon `visibility`).

## Prérequis

Autorisation d'appliquer des migrations sur une base de test isolée (R-02 de la phase 7) ; règles de visibilité et de modération validées.

## Lot 2 (03/11/2026) : tranche « publications » branchée sur les écrans 245 et 252

| Élément | État |
|---|---|
| Migration `20261103000000_commentaires_publications.sql` (`post_comments`, `post_saves`, `post_shares`, 5 fonctions, `reels_feed` v2) | écrite, **non appliquée, non exécutée contre une base** |
| `Reel` : auteur, compteurs de commentaires, d'enregistrements et de partages, état « enregistré » ; 0 quand le serveur n'est pas migré | implémenté, testé |
| Fil classé par `FeedRanker` (`rankReels`), boosts gagnés d'abord | implémenté, testé avec un serveur simulé |
| 245 : compteurs réels, balayage vertical, enregistrer, partage compté, s'abonner via `engagements.follow` | implémenté, testé avec un serveur simulé ; **l'abonnement n'est pas testé** (appel serveur) |
| 252 : commentaires réels (chargement, vide, erreur, suppression des siens), en-tête de la publication, commentaires et avis fictifs masqués en mode connecté | implémenté, testé avec un serveur simulé |
| Ajout d'un commentaire (saisie, `add_post_comment`) | implémenté, **non testé** (dialogue de saisie et serveur) |
| Mode démonstration (hors connexion au serveur) | inchangé : les données de la maquette restent affichées, marquées comme démonstration par `demoContent` |

Reste pour que la tranche soit « de bout en bout » : appliquer la migration sur une base isolée, jouer le parcours avec deux comptes (publier, commenter, enregistrer, suivre, supprimer), vérifier les politiques RLS (lecture anonyme, écriture refusée hors fonctions).
