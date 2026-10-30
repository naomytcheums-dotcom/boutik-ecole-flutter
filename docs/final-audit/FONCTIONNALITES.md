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

## Mise à jour du 30/10/2026 (nuit)
| Fonctionnalité | Statut | Preuve |
|---|---|---|
| **Mode invité** : « Commencer » ouvre l'accueil ; connexion demandée seulement au moment d'une action qui l'exige (favoris, paiement, contacter un vendeur, modifier son profil), avec « Plus tard » ; retour à l'écran d'origine après connexion ; déconnexion → accueil | IMPLÉMENTÉ ET TESTÉ (widget) ; non testé en navigateur | `test/account/guest_mode_test.dart` (3) |
| **Messagerie, interface** : liste des conversations (52), conversation (53) avec le nom de l'interlocuteur, envoi et lecture de messages texte, non-lus, « Contacter le vendeur » (29, 46, 51) | IMPLÉMENTÉ ET TESTÉ (serveur + unitaire) ; non testé en navigateur | `conversations_list_rest.py` 8/8 ; `messages_test.dart` ; pièces jointes et vocal **non disponibles** en conversation enregistrée (non persistés) ; écran 54 (conversation de commande) : message d'orientation, pas de fil dédié |
| **Édition du profil** : description, compétences, ville (dialogue « Modifier mon profil ») | IMPLÉMENTÉ ET TESTÉ (widget) ; enregistrement serveur non testé en navigateur | `test/account/profile_edit_test.dart` (2) ; la certification n'est pas modifiable |
| Titre d'annonce : règle tranchée — un titre est unique sur la plateforme (le panier commande par titre) ; message d'erreur explicite | TERMINÉ | `listings_titre_unique` |
| Choix du rôle à l'inscription (client / étudiant / entreprise / autre) synchronisé avec le serveur | **BLOQUÉ — décision de sécurité du propriétaire** | `20261030g_choix_du_role.sql` écrite mais **non appliquée** : elle assouplit une protection (seul l'administrateur change un rôle). À appliquer par le propriétaire s'il l'approuve |

## Mise à jour du 31/10/2026 (messagerie complète, vendeur, acheteur)
| Fonctionnalité | Statut | Preuve |
|---|---|---|
| Rôle fixé à la création du profil (créé au choix du rôle, écran 13) ; seul l'administrateur peut ensuite le modifier | TERMINÉ ET TESTÉ (serveur) | 6 contrôles REST ; migration `20261030g_choix_du_role` **supprimée** (inutile) |
| **Messagerie liée à une commande** (écran 54) : l'acheteur écrit au vendeur de sa commande, le vendeur à l'acheteur ; une seule conversation par commande | TERMINÉ ET TESTÉ (serveur) ; interface non testée en navigateur | `chat_attachments_rest.py` |
| **Pièces jointes, photos, fichiers et messages vocaux** (stockage privé `chat-files`, 10 Mo, images/PDF/Word/Excel/texte/audio, liens signés de 1 h réservés aux participants, suppression de ses propres fichiers) | TERMINÉ ET TESTÉ (serveur : 29/29) ; l'enregistrement vocal et l'ouverture des fichiers n'ont pas été essayés dans un navigateur | permissions, isolation, taille, type, persistance |
| États d'envoi (« Envoi… », « Échec · Réessayer »), chargement, non-lus, actualisation toutes les 4 s | IMPLÉMENTÉ ET TESTÉ (unitaire/widget partiel) ; non testé en navigateur | `chat_server_test.dart` |
| **Modifier une annonce** (titre, prix, stock, description) | TERMINÉ ET TESTÉ (serveur) ; dialogue non testé en navigateur | écran 60 relié à « Mon catalogue » (61) |
| **Photos d'annonce** (ajout, suppression, 8 max, 5 Mo, JPEG/PNG/WebP, dossier du vendeur) | TERMINÉ ET TESTÉ (serveur : 8/8) ; non testé en navigateur ; **les photos ne s'affichent pas encore dans le catalogue acheteur** | |
| Suppression d'une annonce (archivage), soumission au département, motif de refus visible du vendeur | TERMINÉ ET TESTÉ (serveur) | |
| **Commandes reçues par le vendeur** (liste des commandes payées, acheteur abrégé, statut de préparation, notification à l'acheteur) | TERMINÉ ET TESTÉ (serveur : 15/15) ; écrans 63-65 branchés, non testés en navigateur | migration `20261030h` |
| Statuts « en préparation » (2) et « livrée » (4) | PARTIELLEMENT TERMINÉ | gérés par le serveur ; aucun bouton correspondant dans les maquettes 63-65 (décision de conception) |
| **Parcours acheteur** : ajouter au panier (fiches 32, 35), contacter le créateur (33), annuler une commande impayée avec restitution du stock (47), copier la référence et vérifier le paiement (43), reçu (29), détail (30), suivi (51), filtres, déconnexion de tous les appareils | IMPLÉMENTÉ ET TESTÉ (unitaire) ; serveur : `cancel_order` testé en REST | `order_actions_test.dart` |
| Actions « Démonstration » : **127 restantes sur 91 écrans** (175 au début de la journée) | PARTIELLEMENT TERMINÉ | `tool/audit/out/demos_triage.txt` |

## Complément du 30/10/2026 (lots 2 à 5)
- **Avis vérifiés** (écran 30) : seul l'acheteur d'une commande payée, une fois l'article préparé, un avis par article ; note moyenne publique affichée dans le catalogue (22) et sur la fiche produit (05).
- **Réclamations** (écran 48) : motif, description (10 caractères minimum), une réclamation ouverte par commande ; le vendeur concerné (tableau de bord, « Réclamations ›») et la modération répondent ; l'acheteur est notifié.
- **Signalements d'annonces** (fiche produit → écran 170) : un par personne et par annonce, jamais sur sa propre annonce ; visibles de la seule modération.
- **Services et devis** : un service est une annonce validée de catégorie « Services » (liste 22b, fiche 36) ; demande de devis (95b), réponse du prestataire (montant, délai, message), acceptation, refus ou annulation par le demandeur, notifications à chaque étape. Le paiement du devis accepté n'est pas implémenté (dépend des paiements réels).
- **Commandes du compte** lues sur le serveur (état de préparation du vendeur reflété côté acheteur).
- **Engagements réels** : inscription à un événement (101), candidature (153), précommande (217), vote (220), proposition de stage et demande de contact (229), alerte de disponibilité (35), suivi d'entreprise (89), consentement aux conditions (17, 274), demande d'export (273) et de suppression de compte (273, avec confirmation), partage WhatsApp réel (241).
- **Parcours** : menu du compte par rôle (profil, ⋮), menus latéraux des consoles département / direction / administration / finance, chips « Produits / Services / Projets » du profil, 172 liens contextuels, notifications → ressource concernée.

## Reprise du 30/10/2026 (soir)
| Fonctionnalité | Statut | Preuve |
|---|---|---|
| Inscription à un événement : état affiché, désinscription | TERMINÉ ET TESTÉ (navigateur) | `engagements.spec.ts` ; serveur `engage`/`cancel_engagement` |
| Candidature : postuler, « Candidature envoyée », « Mes candidatures », retrait | TERMINÉ ET TESTÉ (navigateur) | `engagements.spec.ts` |
| Précommande (217), suivi d'entreprise (89), alerte de stock (35) : état et annulation | IMPLÉMENTÉ MAIS NON TESTÉ en navigateur | même mécanisme que l'inscription, testé en widget |
| Préférences d'alertes (156) et canaux (236) | 236 TERMINÉ ET TESTÉ (navigateur, relu après rechargement) ; 156 IMPLÉMENTÉ, testé en widget | `alert_prefs` / `channel_prefs` |
| Portfolio (72), écrire à un mentor (77) | IMPLÉMENTÉ MAIS NON TESTÉ en navigateur | `portfolio_item` / `contact_request` |
| Question au vendeur (39) | TERMINÉ ET TESTÉ (navigateur, contrôle de saisie et réponse serveur) | conversation réelle si l'annonce a un vendeur |
| Navigation contextuelle | 302 écrans sur 315 atteignables depuis l'accueil par des liens métier ou le menu du compte filtré par rôle | `nav_graph.py`, `links_test.dart` |
