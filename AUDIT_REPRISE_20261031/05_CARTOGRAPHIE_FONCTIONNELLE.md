# 05 — Cartographie fonctionnelle

> Statuts appliqués strictement : **TERMINÉE ET VÉRIFIÉE** exige une preuve en **production** (rejouée aujourd'hui ou documentée
> le 31/10 avec preuve). Un test uniquement local donne au mieux **IMPLÉMENTÉE NON VÉRIFIÉE**. « Code présent » n'est jamais
> considéré comme « terminé ». Abréviations : *L* = test local (Flutter, Deno ou REST sur la réplique) ; *P* = vérifié en production.

| # | Module | Fonctionnalité | Statut | Écrans | Backend | Preuve (fichier / test) | Travail restant |
|---|---|---|---|---|---|---|---|
| 1 | Navigation | Exploration visiteur, accueil, « Mes rubriques », 404 neutre, écrans inexistants, responsive, rechargement et retour | **TERMINÉE ET VÉRIFIÉE** | 01-05, 19, 22, `/espace` | lecture `listings` | *P* `visiteur.spec.ts` 12/12 aujourd'hui | — |
| 2 | Navigation | Liens contextuels vers les 315 écrans | **PARTIELLEMENT IMPLÉMENTÉE** | 315 | — | 303 atteignables depuis 01 (02 §2) | relier 176, 150-1, 150-4, 275 ; trancher A2, P4, 250b, S1 |
| 3 | Auth | Connexion e-mail et mot de passe | **TERMINÉE ET VÉRIFIÉE** | 11 | Supabase Auth | *P* historique `connexion_en_ligne.spec` 1/1 (31/10) ; non rejoué aujourd'hui | — |
| 4 | Auth | Inscription (serveur) et confirmation par e-mail | IMPLÉMENTÉE NON VÉRIFIÉE | 12, 13 | `auth.signUp`, `profiles` | `auth.dart:358-379` ; *L* `test/account/*` | recette en production avec un compte autorisé |
| 5 | Auth | Choix du rôle et création du profil | IMPLÉMENTÉE NON VÉRIFIÉE | 13 | `createProfile`, déclencheur `protect_profile_authority` | `auth.dart:440+` ; *L* | idem |
| 6 | Auth | **Mot de passe oublié et réinitialisation** | **DÉFECTUEUSE** (simulée) | 15, 16 | aucun | `auth.dart:488-517` | brancher `resetPasswordForEmail` et `updateUser` ; supprimer le code `482917` |
| 7 | Auth | Code SMS de vérification | **SIMULÉE** (hors parcours serveur) | 14 | aucun | `auth.dart:415-437`, `g_14.dart:77` | retirer du parcours ou brancher un vrai OTP |
| 8 | Auth | Mode invité (connexion demandée seulement à l'action) | **TERMINÉE ET VÉRIFIÉE** | 01-05 | — | *P* `visiteur.spec` (« aucune inscription imposée ») | — |
| 9 | Auth | Déconnexion de tous les appareils | IMPLÉMENTÉE NON VÉRIFIÉE | menu | `signOut(global)` | `logoutEverywhere` | recette |
| 10 | Sécurité | Double authentification TOTP | IMPLÉMENTÉE NON VÉRIFIÉE | 272 | Supabase MFA | *L* `mfa_rest.py`, `mfa.spec` (non rejoué) | recette avec un compte autorisé |
| 11 | Rôles | Filtrage des écrans par rôle (client) | **TERMINÉE ET VÉRIFIÉE** | 99 écrans réservés | — | *P* `visiteur.spec` (404 sur un écran vendeur) ; `access.dart` | une page « connectez-vous » plutôt qu'une 404 pour un visiteur (choix métier) |
| 12 | Rôles | Sécurité serveur (RLS, RPC, droits `EXECUTE`) | **TERMINÉE ET VÉRIFIÉE** (structure) / À CONFIRMER (par rôle) | — | 16 migrations | *P* historique : catalogue = réplique (0 écart), 41/41 contrôles 31c ; *L* sécurité 24/24 | recette par rôle réel (support, dept, admin) en production |
| 13 | Administration | **Gestion des comptes (rôle, suspension)** | **SIMULÉE** (faux succès) | 128 | **aucune RPC** | `admin.dart:24-70` | créer les RPC d'administration (rôle, suspension) + interface |
| 14 | Administration | Paramètres d'établissement, modèles de notification, clés d'API, invitations | IMPLÉMENTÉE NON VÉRIFIÉE | 118, 127, 145, 265, 280 (menus) | `save_institution`, `save_notification_template`, `create_api_key`/`revoke_api_key`, `invite_department_member` | commit `6ae90f5` ; *L* `lots2_rest`, `lots2.spec` | recette admin en production |
| 15 | Administration | Journal d'audit | IMPLÉMENTÉE NON VÉRIFIÉE | 129-130… | `log_audit` | `audit.dart` ; *L* `admin_audit_test` | recette |
| 16 | Administration | Signalements du support | **SIMULÉE** (données fictives) | 131, 170 | `report_listing` existe côté serveur mais n'est pas lu ici | `ops.dart:26-67` | lire `listing_reports`, actions de modération serveur |
| 17 | Administration | Tableaux de bord (plateforme, institution, département, finance, entreprise) | **À CONFIRMER** | 57, 108, 117, 127, 139, 187 | partiel | `demoContent` masque la maquette en production ; indicateurs réels non établis | inventaire écran par écran des chiffres affichés |
| 18 | Administration | Exports CSV | IMPLÉMENTÉE NON VÉRIFIÉE | menus | lecture de tables | commit `5862ab2` | recette |
| 19 | Profils | Édition du profil et de l'identité | IMPLÉMENTÉE NON VÉRIFIÉE | 57, 148-1 | `profiles` | *L* `profile_edit_test` | recette |
| 20 | Profils | Liens de profil et de projet | IMPLÉMENTÉE NON VÉRIFIÉE | profil | `save_profile_links` | *L* `lots2_rest` | recette |
| 21 | Profils | CV partagé (lien régénérable, page publique) | IMPLÉMENTÉE NON VÉRIFIÉE | 227, `/cv/:token` | `regenerate_cv_link`, `shared_cv` | route 200 en production ; `shared_cv.dart` | recette avec un vrai jeton |
| 22 | Catalogue | Annonces publiques (lecture) | IMPLÉMENTÉE NON VÉRIFIÉE | 03, 04, 22, 05 | `listings` | `backend.dart:231-242` | vérifier en production avec des annonces approuvées |
| 23 | Catalogue | Gestion des annonces par le vendeur (CRUD, photos, stock, soumission) | IMPLÉMENTÉE NON VÉRIFIÉE | 58-75 | `listings`, `listing-images`, historique, stock | *L* `listings_stock_rest`, `seller_test` | recette vendeur |
| 24 | Catalogue | Validation des annonces par le département | IMPLÉMENTÉE NON VÉRIFIÉE | menu dept | `on_listing_decided` | *L* | recette dept |
| 25 | Catalogue | Recherche et filtres | PARTIELLEMENT IMPLÉMENTÉE | 19, 21, 23 | `listings` | filtres locaux ; recherche serveur partielle | recherche plein texte côté serveur |
| 26 | Catalogue | Favoris | IMPLÉMENTÉE NON VÉRIFIÉE | 25, 25b | `favorites` | *L* `favorites_rest`, `search_favorites_test` | recette |
| 27 | Catalogue | Avis, réclamations, signalements | IMPLÉMENTÉE NON VÉRIFIÉE | 30, 48, 170 | `submit_review`, `submit_claim`, `report_listing` | *L* `feedback_rest`, `avis.spec` (préparé, non rejoué) | recette |
| 28 | Commandes | Panier | PARTIELLEMENT IMPLÉMENTÉE (local par conception) | 06-09 | aucun | `section_a_demo.CartLine`, providers | décider : panier persistant ou non |
| 29 | Commandes | Création de commande | IMPLÉMENTÉE NON VÉRIFIÉE | 08, 45 | `create_order` | *L* `orders_real_test` | recette en production (commande réelle) |
| 30 | Commandes | Annulation avec motif et restitution du stock | IMPLÉMENTÉE NON VÉRIFIÉE | 47 | `cancel_order_with_reason` | *L* `listings_stock_rest` | recette |
| 31 | Commandes | Suivi de préparation par le vendeur et notification de l'acheteur | IMPLÉMENTÉE NON VÉRIFIÉE | 63, 66 | `seller_orders`, `set_seller_order_status` | *L* `seller_orders_rest` | recette |
| 32 | Livraison | Livraison et logistique | PARTIELLEMENT IMPLÉMENTÉE | 07, 40-49 | statuts seulement | aucun transporteur | définir le besoin |
| 33 | Paiements | Démarrage du paiement (`pay`) | **À CONFIRMER** | 08, 171, 257, 258 | `pay` v6 | *L* Deno 16/16 ; *P* historique contrôles non financiers | renouveler les clés, puis **paiement sandbox de bout en bout** |
| 34 | Paiements | Webhook signé, anti-rejeu, paiement tardif après annulation | IMPLÉMENTÉE NON VÉRIFIÉE (événement réel) | — | `notchpay-webhook` v6, `payment_events` | *L* 21/21 ; *P* POST non signé → 401 (historique) | recevoir un **événement sandbox authentique** |
| 35 | Paiements | MCP Notch Pay (lecture) | **À CONFIRMER** | — | `notchpay-mcp` v3 (`verify_jwt=true`) | clé uniquement dans l'en-tête ; jamais testé avec la vraie clé | test avec la clé ; aligner la documentation et `verify_jwt` |
| 36 | Paiements | Paiements Mobile Money annexes (contributions, duels, mise en avant, retrait des gains) | **NON CONNECTÉE** | 84b, 219, 243, 250 | — | `unavailableAction` | après validation du paiement de base |
| 37 | Retraits | Code de retrait du client | IMPLÉMENTÉE NON VÉRIFIÉE | 45 / commande | `my_pickup_code` (génération sûre, 31c) | *L* `security_31_rest` | recette avec une commande payée |
| 38 | Retraits | Remise au kiosque (`confirm_pickup`) : jamais de faux succès, 5 essais maximum, journal | **TERMINÉE ET VÉRIFIÉE** (interface) / À CONFIRMER (remise réelle) | 146-2 | `confirm_pickup` | *P* `retrait_en_ligne.spec` 1/1 aujourd'hui (serveur intercepté) ; *L* `retrait.spec` | remise réelle par un compte support |
| 39 | Bornes | Jeton QR de session de borne | **SIMULÉE** | 208-210 | aucun | `missions.dart:31-55` | session signée côté serveur |
| 40 | Bornes | Ticket d'impression | **SIMULÉE** | 210 | aucun | `g_210.dart:113` | intégration matérielle |
| 41 | Bornes | Incidents et événements de borne, contrôle réseau | IMPLÉMENTÉE NON VÉRIFIÉE | 145-147, 277, menu | `report_kiosk_incident`, `schedule_kiosk_event` | *L* `lots_rest` | recette support |
| 42 | Notifications | Notifications dans l'application (liste, lu, compteurs) | IMPLÉMENTÉE NON VÉRIFIÉE | 50, 155, 156 | `notifications`, `mark_notifications_read`, `unread_counts` | *L* `notifs_test` | recette |
| 43 | Notifications | Push, e-mail, SMS | **ABSENTE** | — | — | aucun service | à définir |
| 44 | Messagerie | Messagerie (texte, photo, fichier, vocal) | IMPLÉMENTÉE NON VÉRIFIÉE | 52-54 | conversations, `messages`, `chat-files` | *L* `messaging_rest`, `chat_attachments_rest` | recette |
| 45 | Messagerie | Messagerie de mission | IMPLÉMENTÉE NON VÉRIFIÉE | dossier de mission | `mission_messages`, `project-files` | *L* `security_31_rest` | recette |
| 46 | Messagerie | Message au mentor, à l'équipe, discussion d'équipe | **SIMULÉE** / ABSENTE | 164, 194 | aucun | `g_164.dart:101`, `g_194.dart:174` | brancher sur la messagerie |
| 47 | Services | Demande de devis, réponse, décision, annulation | IMPLÉMENTÉE NON VÉRIFIÉE | 22b, 36, 95b, 57 | `quote_requests` et RPC | *L* `quotes_rest` ; `devis.spec` non rejouable | recette (approbation d'un service de test) |
| 48 | Missions | Besoins, propositions, comparaison, affectation | IMPLÉMENTÉE NON VÉRIFIÉE | 191, 93, 151, 230-235, 285 | `save_mission`, `propose_on_mission`, `decide_proposal`, `assign_mission` | *L* `lots_rest`, `lots.spec` | recette |
| 49 | Missions | Jalons, preuves, séquestre, libération | PARTIELLEMENT IMPLÉMENTÉE | 194, 197 | `submit_milestone`, `decide_milestone` ; séquestre lié au paiement | *L* `kiosk_missions_test` | dépend du paiement réel |
| 50 | Missions | Dossier de mission et dépôt de fichiers | IMPLÉMENTÉE NON VÉRIFIÉE | dossier | `project-files`, `register_file` | *L* `lots2_rest` | recette |
| 51 | Missions | Question à l'administrateur, brouillons de mission | **SIMULÉE** | 192, 195 | aucun | 03 §3 A | brancher |
| 52 | Engagements | Inscriptions, candidatures, votes, alertes, suivis, consentement | IMPLÉMENTÉE NON VÉRIFIÉE | 13 écrans | `engage`, `cancel_engagement` | *L* `engagements_rest` 18/18 ; `engagements.spec` (historique en production, avec comptes `zz-test`) | nettoyage des comptes `zz-test` ; recette |
| 53 | Projets | Projets étudiants (création, étapes, revue) | IMPLÉMENTÉE NON VÉRIFIÉE | 78-87 | `save_project`, `add_project_step`, `review_project` | *L* `lots_rest` | recette |
| 54 | Campagnes | Création et revue de campagnes | IMPLÉMENTÉE NON VÉRIFIÉE | 84, 218 | `save_campaign`, `review_campaign` | *L* | recette |
| 55 | Campagnes | Contribution financière | **NON CONNECTÉE** | 84b | — | `unavailableAction` | paiements |
| 56 | Vœux | Marché des vœux (publication, revue, suppression) | IMPLÉMENTÉE NON VÉRIFIÉE | 216-218 | `save_wish`, `review_wish`, `delete_wish` | *L* | recette |
| 57 | Lives | Programmation d'un live | IMPLÉMENTÉE NON VÉRIFIÉE | 223, 246 | `save_live` | *L* | recette |
| 58 | Lives | Diffusion vidéo en direct | **NON CONNECTÉE** | L1 | — | `unavailableAction` | service de diffusion |
| 59 | Certificats | Demande, émission, vérification publique, « Mes certificats » | IMPLÉMENTÉE NON VÉRIFIÉE | 73, 283 | `request_certification`, `issue_certificate`, `verify_certificate` | *L* `security_31_rest` | recette |
| 60 | Certificats | Révocation et décision de certification | **NON ACCESSIBLE** (serveur sans interface) | — | `revoke_certificate`, `decide_certification` | absence d'appel dans `lib/` | interface dept ou admin |
| 61 | Événements | Hackathons et concours (inscription, dépôt, jury) | PARTIELLEMENT IMPLÉMENTÉE | 160-169 | `engage` (inscriptions) | `hackathons.dart` | classement réel (actuellement fictif) |
| 62 | Événements | Événements et communautés | PARTIELLEMENT IMPLÉMENTÉE | 100-107 | `engage` (inscriptions, suivis) | commit `8df0f0e` | contenus réels |
| 63 | Communauté | Cercle, reels, publication, parrainage, gains | PARTIELLEMENT IMPLÉMENTÉE | 238-255 | `uploadMedia` (publication) ; gains non retirables | 03 | recette ; retrait des gains |
| 64 | Kéla | Assistante vocale et transcription | À CONFIRMER | 230-237 | `speech_to_text` (navigateur) | — | recette multi-navigateurs |
| 65 | Confidentialité | Consentement aux conditions d'utilisation | IMPLÉMENTÉE NON VÉRIFIÉE | CGU | `engage('terms_accepted')` | `engage.dart:190` | recette |
| 66 | Confidentialité | Demande d'export et de suppression de compte | PARTIELLEMENT IMPLÉMENTÉE | 273 | demande enregistrée (`engage`) ; **traitement manuel**, sans export automatique | `engage.dart:198+` | procédure de traitement, ou export automatique |
| 67 | Paramètres | Préférences persistantes | IMPLÉMENTÉE NON VÉRIFIÉE | 148 | `savePrefs` (serveur) | commit `980f163` | recette |
| 68 | Système | États système (hors connexion, session expirée) | IMPLÉMENTÉE NON VÉRIFIÉE | 150-2, 150-3, 182, 183 | — | `system_states.dart` | test navigateur hors connexion |
| 69 | Langues | Localisation (plusieurs langues) | PARTIELLEMENT IMPLÉMENTÉE | 184-186 | — | `lib/l10n` présent ; textes des écrans en dur | décider du périmètre |

## Totaux (69 fonctionnalités, comptés automatiquement dans ce tableau)

| Statut | Nombre | Numéros |
|---|---|---|
| TERMINÉE ET VÉRIFIÉE | **6** | 1, 3, 8, 11, 12, 38 |
| IMPLÉMENTÉE NON VÉRIFIÉE | **36** | 4, 5, 9, 10, 14, 15, 18, 19, 20, 21, 22, 23, 24, 26, 27, 29, 30, 31, 34, 37, 41, 42, 44, 45, 47, 48, 50, 52, 53, 54, 56, 57, 59, 65, 67, 68 |
| PARTIELLEMENT IMPLÉMENTÉE | **10** | 2, 25, 28, 32, 49, 61, 62, 63, 66, 69 |
| SIMULÉE | **7** | 7, 13, 16, 39, 40, 46, 51 |
| À CONFIRMER | **4** | 17, 33, 35, 64 |
| NON CONNECTÉE | **3** | 36, 55, 58 |
| DÉFECTUEUSE | **1** | 6 |
| NON ACCESSIBLE | **1** | 60 |
| ABSENTE | **1** | 43 |
| **Total** | **69** | |

Note : 12 (sécurité serveur) et 38 (remise au kiosque) sont vérifiés en production pour la **structure** et pour l'**interface**. Leur
**recette réelle**, avec des comptes par rôle et une remise effective, reste à confirmer. Ils sont comptés une seule fois.
