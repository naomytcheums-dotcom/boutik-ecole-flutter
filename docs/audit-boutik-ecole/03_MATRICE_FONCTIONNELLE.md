# 03 — Matrice fonctionnelle

Légende des résultats : **Vérifié** (observé dans le navigateur ou par test automatisé) · **Partiel** · **Simulé** (état local, message « Démonstration » ou donnée codée) · **Visuel** (aucune action) · **Absent** · **Impossible** (accès/environnement manquant).
« Preuve » : T = test automatisé du dépôt, N = observation dans le navigateur pendant la session (instance locale du build, sauf mention), C = lecture du code.

| Fonctionnalité | Résultat | Preuve | Limites de vérification |
|---|---|---|---|
| Affichage fidèle des 315 écrans | Vérifié (rendu) | T : 315 tests « golden » ; score de fidélité Figma (écart moyen 2,5/255) | comparaison par image, pas par appareil réel |
| Barre de chargement du démarrage puis écran suivant | Partiel | C : `GSplashBar` (`gen.dart`) ; T : désactivée en test | non revue visuellement après la dernière modification |
| Bienvenue → « Commencer » → connexion | Partiel | C : `g_02.dart` ; T : parcours de démonstration (compte administrateur) | parcours non rejoué à la main après correction |
| Connexion par téléphone/e-mail + mot de passe | Partiel | N : écran sans cadre, validation des champs, redirection vers l'accueil (local) ; C : `submitLogin` | validation faite localement ; session Supabase non vérifiée (AN-006) |
| Case « Se souvenir de moi » | Partiel | N : case cochable ; C : `shared_preferences` | restauration de session après rechargement non testée |
| Inscription, code de vérification | Simulé | C : code constant `482917` | AN-011 |
| Mot de passe oublié / réinitialisation | Simulé | C : `auth.dart` | pas de serveur de messagerie |
| Contrôle d'accès par rôle (10 rôles) | Partiel (client seulement) | T : `access_test.dart` ; C : `access.dart` | aucune protection serveur (AN-013) |
| Catalogue, fiche produit (03, 04, 05) | Partiel | N : écrans 03, 04 ; C : catalogue codé en dur (`store.dart`) | images et produits locaux |
| Recherche et filtres | Partiel | T : `search_favorites_test.dart` | recherche sur le catalogue local uniquement |
| Favoris | Simulé (mémoire) | T ; N : écran 25 | perdus au rechargement (AN-007) |
| Panier (06) | Partiel | T : `purchase_flow_test.dart` | prix et totaux calculés côté client (AN-003) |
| Livraison, choix du mode (07) | Partiel | N : écran 07 ; C : frais de 5 000 FCFA codés | |
| Paiement Mobile Money (08 → 257 → 259) | Impossible à prouver | C : `pay.dart`, `pay/index.ts` ; mesure : la fonction répond « non configurée » | clé Notch Pay absente pendant l'audit (AN-014) |
| Reçu et facture PDF (259, 260) | Partiel | C : `docs.dart` | fichier PDF non ouvert pendant l'audit |
| Mes commandes, suivi (45, 09) | Simulé (mémoire + 4 commandes codées) | N : écran 45 ; C : `_history` | AN-012 |
| Statuts de commande 0→3 | Simulé | C : `Orders.advance` | transitions libres, aucun contrôle (voir 05) |
| Espace vendeur (annonces, stock, commandes reçues) | Simulé (mémoire) | T : `seller_test.dart` | AN-007, AN-008 |
| Validation des annonces par le département | Simulé (mémoire) | T : `review_finance_test.dart` | ne rejoint pas le vendeur sur un autre appareil |
| Console administrateur (comptes, rôles, audit, commissions, signalements) | Simulé (mémoire) | T : `admin_audit_test.dart`, `ops_test.dart` | AN-012 |
| Journal d'audit | Partiel | C : écriture locale + envoi à `audit_log` | forgeable (AN-022) ; envoi silencieux en cas d'échec |
| Talents, projets, opportunités | Simulé (mémoire) | T : `talents_test.dart` | |
| Hackathons | Simulé (mémoire) | T : `hackathon_test.dart` | |
| Borne : code QR à usage unique | Simulé | T : `kiosk_missions_test.dart` | jeton signé côté client (AN-023) |
| Missions sur mesure (jalons, séquestre, preuves) | Simulé (mémoire) | T : `kiosk_missions_test.dart` | aucun mouvement d'argent réel |
| Messagerie (53, 54) : texte | Vérifié (local) | N : message tapé puis affiché, envoi par Entrée | non persisté ; non envoyé à un destinataire |
| Messagerie : photo, fichier, vocal | Code écrit, non vérifié | C : `chat.dart` | pas de test d'appareil photo, de sélecteur de fichier ni de micro |
| Assistante Kéla : transcription vocale | Code écrit, non vérifié | C : `kela.dart` | nécessite micro et navigateur compatible ; non testé |
| Orbe de Kéla animé | Code écrit, non vérifié | C : `kelaOrb` | |
| Partage de profil, liens sociaux | Partiel | C : `share.dart` | pages d'accueil génériques (AN-029) |
| Navigation par onglets, bouton retour | Partiel | C : `nav.dart` (`gTab`, `gBack`) | non rejoué manuellement sur tous les écrans |
| Canal WhatsApp (230–236) | Absent | C | AN-024 |
| Notifications push/SMS/e-mail | Absent | C : écrans seulement | |
| Application Android / iOS | Absent (jamais compilée) | — | exige Android SDK / un Mac |
| Accessibilité (zones tactiles, contraste, lecteur d'écran) | Impossible (non mesurée) | — | AN-021 |

## Comptage des interactions (analyse automatique du code des écrans)
- 948 liens de navigation entre écrans, aucun vers un écran inexistant (analyse statique).
- 192 occurrences de « Démonstration : … » sur 129 écrans (boutons simulés).
- 145 écrans avec champs/bascules locaux sans effet métier, 56 écrans de boutons simulés, 33 de navigation seule, 10 statiques (détail : `02_ROUTES_ET_PAGES.md`).
- Aucune interaction n'a été comptée comme fonctionnelle sur la seule base d'un message ou d'une animation.
