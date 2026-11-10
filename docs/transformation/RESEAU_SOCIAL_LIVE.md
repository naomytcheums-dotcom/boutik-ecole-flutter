# Réseau social, Lives et cadeaux virtuels (10 novembre 2026)

Écrans : 244 Cercle, 244b, 245 Reels, 246 Lives, 247 Profil, 249/250/250b/P4 Publier, 252 Commentaires (feuille inférieure), 222 Live (spectateur), L1 Aller en direct (création puis régie de l'hôte).
Migration : `supabase/migrations/20261110000000_reseau_social_live.sql` (additive). Edge Function : `supabase/functions/live-token`.
Tests : `test/purchase/reseau_social_live_test.dart` (Flutter), `supabase/tests/reseau_pglite/` (SQL, 56 contrôles, sans Docker), `supabase/functions/live-token/live_token_test.ts` (Deno).

## Ce qui est fait côté application

- **Cœur** : `LikeHeart` (`social_posts.dart`). Un appui enregistre ou retire la réaction tout de suite (mise à jour optimiste, état rétabli si le serveur refuse), sans jamais quitter l'écran. Sans compte : message bref, aucune redirection. Animation 1 → 1,3 → 1 (l'icône ne rétrécit jamais). Même cœur dans le Cercle et dans les Reels.
- **Commentaires** : « Commenter » ouvre une feuille inférieure (`showCommentsSheet`) au-dessus de l'écran, la publication ou la vidéo reste visible au-dessus. Liste (réponses imbriquées, mentions j'aime sur les commentaires, suppression des siens), saisie, envoi, pièce jointe image, dictée vocale (navigateur), clavier et zone système gérés. L'écran 252 n'est plus une page : il ouvre la feuille et revient à l'écran précédent à la fermeture. Les anciens écrans de démonstration restent affichés hors connexion.
- **Publications** (`PostCard`, `publishPost`) : texte, jusqu'à 10 photos ou vidéos (carrousel horizontal, indicateurs de pagination et compteur « 1/5 », proportions de la première photo préservées, jamais rognées), lien, mots-clés `#`, republication avec mot facultatif, partage (feuille du système, sinon copie du lien, partage déclaré au serveur), enregistrement, signalement, menu à trois points. Angles droits, marges de page de la colonne respectées. Le fil appelle `circle_feed` et retombe sur l'ancien `reels_feed` tant que la migration n'est pas appliquée.
- **Histoires** (`stories.dart`) : barre en tête du Cercle, anneau autour de la photo du profil (le profil ouvre les histoires actives du titulaire), visionneuse plein écran (défilement automatique 5 s ou durée de la vidéo, appui à droite/gauche, pause au maintien, glisser vers le bas pour fermer), bouton « Voir le profil et ses publications ». Photo de profil réelle (`profiles.avatar_url`) partout où le nom apparaît ; à défaut, l'initiale. Les vignettes du profil ouvrent la publication dans les Reels.
- **Navigation immersive** : le menu du bas n'est plus affiché sur Reels (245) ni sur la liste des Lives (246) ; il reste ailleurs. Écrans Live spectateur et hôte en plein écran. Colonne d'interactions des Reels posée directement sur la vidéo (icônes blanches avec ombre, sans disque). Les Reels lisent vraiment la vidéo (lecture automatique, repli sans son si le navigateur l'impose, appui = pause, son).
- **Badge bleu** : composant unique `VerifiedBadge`, affiché uniquement si le serveur renvoie `certification = approved` (profil, publications, commentaires, histoires, Lives, Reels). Jamais déduit du nom ni vendu.
- **Lives** (`lives.dart`) : liste (en direct, programmés, mes lives), création (titre, description, couverture, date facultative), régie de l'hôte (démarrer, caméra, micro, terminer avec confirmation, modération : masquer un message, bannir), spectateur (vidéo, nombre de spectateurs, chat, réactions animées, cadeaux, signalement), notifications de démarrage aux abonnés actifs (côté serveur), reconnexion automatique et bandeau « Reconnexion en cours… », erreurs lisibles (autorisation caméra/micro refusée, aucun appareil, appareil occupé, module indisponible, réseau, live terminé, banni).
- **Cadeaux** : catalogue (Rose 5, Cœur 10, Bravo 20, Flamme 50, Étoile 100, Trophée 500 crédits), quantité, confirmation avant envoi, animation en direct, historique envoyés/reçus, portefeuille, espace créateur (lives, pic de spectateurs, cadeaux reçus, gains, commission). La clé de transaction est conservée tant que l'envoi n'est pas réglé : un second essai (réseau instable) ne débite jamais deux fois.

## Architecture du Live

```
Hôte (navigateur)  --jeton "publier"-->  LiveKit (salle live-<uuid>)  <--jeton "regarder"--  Spectateurs
        ^                                      ^
        | start_live / end_live (RPC)          | jeton émis par l'Edge Function live-token
        v                                      |
   Supabase (tables lives, live_viewers, live_messages ; Realtime : chat, réactions, cadeaux, statut, spectateurs)
```

- Vidéo : **LiveKit** (SDK navigateur chargé à la demande depuis jsDelivr, version figée 2.22.3, par `web/live_bridge.js`). Choix : service managé (WebRTC + SFU), SDK Web, jetons signés côté serveur, offre gratuite pour démarrer, pas de serveur média à héberger.
- L'**Edge Function `live-token`** vérifie la connexion, le rôle (hôte = droit de publier ; spectateur = lecture seule, seulement si le live est « en direct » et qu'il n'est pas banni) et signe un jeton de 2 h. Sans secrets : réponse 503 `not_configured` et message clair dans l'application (aucun jeton inventé).
- L'hôte se connecte et publie **avant** que le live soit déclaré en direct : si la permission caméra/micro est refusée, rien n'est annoncé aux abonnés.
- Compteur de spectateurs : une ligne par spectateur, battement de cœur toutes les 30 s, comptés « actifs » pendant 90 s ; remis à zéro à la fin.
- Chat, réactions, cadeaux : lignes de `live_messages` diffusées par Supabase Realtime (publication `supabase_realtime`). Anti-spam serveur : 5 messages / 10 s, 20 réactions / 10 s.
- Modération : tout spectateur peut signaler un live ou un message (`live_reports`, un signalement par personne) ; l'hôte masque un message et bannit un spectateur ; l'administration et le support peuvent terminer un live.

## Cadeaux : règles d'argent

- Un crédit n'est **jamais** créé par l'application. Il n'existe qu'un seul moyen d'en ajouter : la fonction `grant_credits(user, montant, référence)`, réservée au rôle `service_role`, idempotente par référence de paiement (rejouer un même paiement n'ajoute rien). Aucun solde de démonstration.
- `send_gift(live, cadeau, quantité, clé)` : verrouille le portefeuille de l'expéditeur, refuse si la clé a déjà servi (renvoie la transaction d'origine, sans second débit), vérifie live en direct / pas de cadeau à soi-même / pas banni / solde suffisant, débite, crédite la part du créateur, enregistre la ligne du livre de comptes (`credit_ledger`, unique par type et référence) et publie le cadeau dans le chat. Tout dans une seule transaction.
- Paramètres modifiables en base (`gift_settings`) : part du créateur 70 % (commission plateforme 30 %), 1 crédit = 10 FCFA, quantité maximale 50. **Ce sont des valeurs par défaut proposées, à valider par le propriétaire.**
- **Retraits : non ouverts.** Verser les gains en argent réel suppose un prestataire de paiement agréé (Mobile Money/banque), la déclaration fiscale et un cadre juridique pour les « monnaies virtuelles » : rien de tout cela n'est en place. Les gains s'accumulent dans `creator_earnings` (aucune perte) ; l'espace créateur l'indique (`payout_available: false`).
- **Recharge de crédits : non reliée à un paiement.** Le portefeuille affiche « recharge pas encore ouverte ». À brancher : après le paiement confirmé (webhook Notch Pay / Tara / Mobile Money existant), appeler `grant_credits` avec la référence du paiement. Aucune clé de paiement n'a été lue ni modifiée.

## À fournir par le propriétaire

1. **Compte LiveKit Cloud** (https://livekit.io/) → créer un projet, puis fournir trois valeurs :
   - `LIVEKIT_URL` (de la forme `wss://<projet>.livekit.cloud`)
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
   Les enregistrer sans les écrire dans le dépôt : `npx supabase@2.122.0 secrets set LIVEKIT_URL=... LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... --project-ref zxqcnmgwhtbxkdpjqtlr`
2. **Décisions commerciales** : prix des paquets de crédits, part du créateur (70 % proposé), valeur du crédit (10 FCFA proposé), catalogue de cadeaux.
3. **Paiement des crédits** : choisir le moyen (Notch Pay, Tara, Mobile Money) et autoriser le branchement du webhook sur `grant_credits`.
4. **Retraits des gains** : prestataire de versement et validation juridique (monnaie virtuelle, fiscalité, âge minimum, conditions d'utilisation).
5. **Application installée (Android/iOS natifs)** : la diffusion fonctionne dans le navigateur (Chrome, Safari, Firefox, y compris sur téléphone). Dans l'application native il faudra ajouter le SDK `livekit_client` (non fait : impossible à valider sans appareil, et risque de casser la compilation).

## Limites connues

- Aucun échange réel avec LiveKit n'a pu être exécuté (pas de clés) : le pont `web/live_bridge.js`, le jeton et la séquence hôte/spectateur sont écrits d'après la documentation du SDK mais **non testés de bout en bout**. Le jeton HS256 est couvert par un test Deno ; le reste est à vérifier avec un compte LiveKit réel et deux appareils.
- Pas d'enregistrement ni de rediffusion des lives. Pas de webhook LiveKit : si l'hôte ferme son navigateur sans terminer, le live reste « en direct » jusqu'à ce qu'il (ou l'administration) le termine ; les spectateurs inactifs sortent du compteur après 90 s.
- Les vidéos de Reels sont lues depuis le stockage public `post-media` (50 Mo, MP4/MOV) ; pas de transcodage.
- Dictée vocale des commentaires : navigateurs compatibles uniquement (Chrome, navigateurs Android) ; message explicite ailleurs.
- L'écran 227 est « Mon CV vivant » dans le projet : la régie de l'hôte est portée par l'écran **L1** (`?live=<id>`).
- Le menu du bas reste affiché sur le Cercle quand le filtre « Vidéos » est choisi (les vidéos s'ouvrent dans les Reels, où il est masqué).
