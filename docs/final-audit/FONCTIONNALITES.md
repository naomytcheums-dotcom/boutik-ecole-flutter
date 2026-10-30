# Inventaire des fonctionnalités et état réel

Statuts : TERMINÉ ET TESTÉ · IMPLÉMENTÉ MAIS NON TESTÉ · PARTIELLEMENT TERMINÉ · BLOQUÉ — CAUSE IDENTIFIÉE · NON COMMENCÉ.
« Testé » = vérifié sur la base réelle (REST/SQL) ou par test automatisé ; aucun test navigateur automatisé (Playwright) n'existe.

| Fonctionnalité | Statut | Détail et preuve |
|---|---|---|
| Inscription / connexion (Supabase) | IMPLÉMENTÉ MAIS NON TESTÉ | code (`Backend.login/register`) et tests unitaires ; comptes jetables REST OK ; pas de test dans le navigateur |
| Confirmation d'e-mail, code par e-mail/SMS | NON COMMENCÉ | « Confirm email » désactivé ; l'écran de code simulé est sauté avec le serveur |
| Récupération / réinitialisation du mot de passe | PARTIELLEMENT TERMINÉ | écrans 15–16 simulés (code de démonstration) ; pas branchés à Supabase |
| Session, déconnexion, changement de compte | IMPLÉMENTÉ MAIS NON TESTÉ | `loadRemembered`, `AppRoot` ; tests unitaires |
| Profil (nom, description vierge, avatar neutre, compteurs) | TERMINÉ ET TESTÉ (serveur) / non testé en navigateur | `identity_test.dart`, 18 tests REST |
| Édition du profil (bio, compétences, photo) | PARTIELLEMENT TERMINÉ | `Backend.saveProfile` existe, aucun écran ne l'appelle ; pas de téléversement de photo |
| Certification et badge bleu | PARTIELLEMENT TERMINÉ | serveur : TERMINÉ ET TESTÉ ; interface : lien « Demander la certification » seulement ; pas de justificatifs ni d'écran de décision relié |
| Favoris | TERMINÉ ET TESTÉ (serveur) | 9 tests REST ; interface non testée en navigateur |
| Catalogue, recherche, filtres, fiches produits | PARTIELLEMENT TERMINÉ | catalogue de plateforme en base (11 produits) mais l'application lit un catalogue local |
| Panier | IMPLÉMENTÉ MAIS NON PERSISTÉ | mémoire locale |
| Commande | TERMINÉ ET TESTÉ (serveur) | `create_order` recalcule les montants ; tests REST (30/10) |
| Paiement Mobile Money | PARTIELLEMENT TERMINÉ | sandbox MTN testé ; Orange, sous-paiement réel, production : non faits ; webhook réel : BLOQUÉ |
| Annonces vendeur (création, validation, publication) | NON COMMENCÉ (persistance) | écrans et logique locale ; aucune écriture en base |
| Stock | PARTIELLEMENT TERMINÉ | seuil « Stock bas » = 30 en mémoire ; pas de décrément serveur |
| Messagerie | PARTIELLEMENT TERMINÉ | texte, images, fichiers, vocal en mémoire ; pas de tables |
| Notifications | NON COMMENCÉ | aucune table ni écran relié |
| Tableaux de bord, statistiques | PARTIELLEMENT TERMINÉ | calculés sur des données locales ou d'exemple |
| Administration (utilisateurs, rôles) | PARTIELLEMENT TERMINÉ | côté client ; RLS ne couvre que les profils |
| Missions, hackathons, borne | PARTIELLEMENT TERMINÉ | en mémoire ; tables existantes non utilisées |
| Accès à tous les écrans par rôle (`/espace`) | TERMINÉ ET TESTÉ (tests unitaires) | non testé en navigateur |
