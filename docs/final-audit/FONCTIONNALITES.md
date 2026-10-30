# Inventaire des fonctionnalités et état réel (mis à jour le 30/10/2026, soir)

Statuts : TERMINÉ ET TESTÉ · IMPLÉMENTÉ MAIS NON TESTÉ · PARTIELLEMENT TERMINÉ · BLOQUÉ — CAUSE IDENTIFIÉE · NON COMMENCÉ.
« Testé » = vérifié sur la base réelle (REST/SQL) ou par test automatisé. **Aucun test navigateur automatisé (Playwright) n'existe** : les cases « interface » restent donc « non testées en navigateur ».

| Fonctionnalité | Statut | Détail et preuve |
|---|---|---|
| Inscription / connexion (Supabase) | IMPLÉMENTÉ MAIS NON TESTÉ | code + tests unitaires + comptes jetables REST ; pas de test navigateur |
| Confirmation d'e-mail, code e-mail/SMS | NON COMMENCÉ | « Confirm email » désactivé ; l'étape de code simulé est sautée avec le serveur |
| Mot de passe oublié / réinitialisation | PARTIELLEMENT TERMINÉ | écrans 15–16 encore simulés |
| Session, déconnexion, changement de compte | IMPLÉMENTÉ MAIS NON TESTÉ | `AppRoot` + tests unitaires |
| Profil : identité, avatar neutre, compteurs | TERMINÉ ET TESTÉ (serveur) | 18 tests REST, `identity_test.dart` |
| Édition du profil (bio, compétences, photo) | PARTIELLEMENT TERMINÉ | `Backend.saveProfile` existe, aucun écran ne l'appelle ; bucket d'images créé mais pas d'écran de téléversement |
| Certification et badge bleu | PARTIELLEMENT TERMINÉ | serveur : TERMINÉ ET TESTÉ ; interface : lien « Demander la certification » ; pas de justificatifs ni d'écran de décision |
| Favoris | TERMINÉ ET TESTÉ (serveur) | 9 tests REST |
| **Annonces vendeur** (créer, brouillon, soumettre, supprimer) | TERMINÉ ET TESTÉ (serveur) ; interface IMPLÉMENTÉE MAIS NON TESTÉE en navigateur | migration `20261030c`, 17 tests REST (propriété forcée, transitions, validations, doublons) ; `Listings`/`submitListing` |
| **Modification d'une annonce** (titre, prix, description) | PARTIELLEMENT TERMINÉ | autorisée par le serveur (historisée) ; aucun écran de modification n'existe dans la maquette câblée |
| Validation par le département | TERMINÉ ET TESTÉ (serveur) ; interface IMPLÉMENTÉE MAIS NON TESTÉE | `decideListing`, file `ReviewQueue` ; approbation prouvée en SQL (transaction annulée) et par la file |
| **Stock** (initial, décrément atomique, annulation, historique) | TERMINÉ ET TESTÉ (serveur) | 23 tests REST : vente au-delà du stock refusée, deux commandes simultanées → une seule, stock restitué à l'annulation, mouvements lisibles par le seul vendeur |
| Annulation / paiement échoué → stock libéré | IMPLÉMENTÉ MAIS NON TESTÉ | `cancel_order` testé en REST ; branché sur l'échec de paiement dans l'application, non testé en navigateur |
| Images d'annonces (Storage) | PARTIELLEMENT TERMINÉ | bucket + politiques testés (dépôt dans son dossier, refus ailleurs, refus de `text/html`) ; pas d'écran de téléversement |
| Catalogue acheteur : annonces approuvées des autres vendeurs | IMPLÉMENTÉ MAIS NON TESTÉ | `publicListingsProvider` + test unitaire ; le catalogue de plateforme reste local |
| Panier | IMPLÉMENTÉ MAIS NON PERSISTÉ | mémoire locale |
| Commande | TERMINÉ ET TESTÉ (serveur) | `create_order` recalcule les montants et réserve le stock |
| Paiement Mobile Money | PARTIELLEMENT TERMINÉ | sandbox MTN testé ; Orange, sous-paiement réel, production : non faits ; webhook réel : BLOQUÉ |
| Commandes reçues par le vendeur | NON COMMENCÉ | encore des commandes d'exemple en mémoire |
| **Messagerie** (conversations, messages, historique) | TERMINÉ ET TESTÉ (serveur) ; **interface NON RELIÉE** | migration `20261030d/e`, 26 tests REST ; les écrans 52–54 affichent encore la conversation de démonstration |
| **Notifications** (liste, non-lus, « tout lire ») | TERMINÉ ET TESTÉ (serveur) ; écran 50 IMPLÉMENTÉ MAIS NON TESTÉ en navigateur | déclencheurs : message, décision d'annonce, paiement ; compteurs `unread_counts` ; pastille de non-lus codée mais non posée sur les icônes |
| Avis et évaluations | NON COMMENCÉ | |
| Tableaux de bord, statistiques | PARTIELLEMENT TERMINÉ | données locales ou d'exemple |
| Administration (utilisateurs, rôles) | PARTIELLEMENT TERMINÉ | côté client ; RLS ne couvre que profils, annonces, certification |
| Missions, hackathons, borne | PARTIELLEMENT TERMINÉ | en mémoire |
| Accès à tous les écrans par rôle (`/espace`) | TERMINÉ ET TESTÉ (unitaire) | non testé en navigateur |
| Serveur MCP Notch Pay (lecture seule) | TERMINÉ ET TESTÉ (déployé, client MCP officiel) ; **BLOQUÉ pour Claude** tant que « Verify JWT » n'est pas désactivé et `MCP_ACCESS_KEY` défini | voir `MCP_NOTCHPAY.md` |
