# 04 — Audit des parcours utilisateur

> Lecture seule. Aucun parcours **écrivant** en production n'a été déclenché. Seuls ont été rejoués aujourd'hui en production le
> parcours visiteur et l'écran de retrait, avec le serveur entièrement intercepté (Playwright 13/13). Les autres parcours sont
> analysés dans le code ; les tests locaux sont cités avec leur portée.

## 1. Parcours principaux

| # | Parcours | Point d'entrée → écrans | Services appelés (code) | Données lues / écrites | Contrôles d'accès | Erreurs, annulation | Vérification |
|---|---|---|---|---|---|---|---|
| P1 | **Visiteur** : découvrir sans compte | 01 → 03 → 04/19/22/05 ; « Mes rubriques » | `Backend.listings` (lecture `listings`) | lecture seule | `AccessGuard` (404 neutre sur les écrans réservés) | écran inexistant → `MissingScreen` | **Production : 9/9** (`visiteur.spec.ts`), 5 tailles d'écran |
| P2 | **Inscription** | 12 → 13 (rôle) → profil | `Backend.register` (`auth.signUp`), `Backend.createProfile` (`profiles`) — `auth.dart:358-379` | écrit `auth.users`, `profiles` | rôle protégé par le déclencheur `protect_profile_authority` | compte existant, erreur serveur, confirmation par e-mail → 11 | tests Flutter locaux ; **non rejoué en production** (créerait un compte) |
| P3 | **Connexion / déconnexion** | 11 → 03 ; menu → déconnexion (y compris de tous les appareils) | `signInWithPassword`, `logoutEverywhere` | session | — | identifiants faux → message | historique : `connexion_en_ligne.spec` 1/1 en production le 31/10 ; non rejoué aujourd'hui (connexion d'un compte) |
| P4 | **Mot de passe oublié** | 11 → 15 → 16 → 11 | **aucun appel serveur** (`submitForgot`/`submitReset`, `auth.dart:488-517`) | liste locale | — | **faux succès** | **DÉFECTUEUX** (code) |
| P5 | **Achat** | 05 → panier → 07 (livraison) → 08/171 (paiement) → 257 (attente) → 45 (commandes) | `create_order` (RPC), `functions.invoke('pay')` (`pay.dart:85`), `cancel_order_with_reason` | `orders`, `order_lines`, stock | commande liée à `auth.uid()` ; `pay` vérifie le propriétaire, l'annulation, le montant | paiement échoué → 258 ; annulation avec motif (47) ; paiement tardif refusé | tests Flutter et Deno locaux ; contrôles non financiers en production (historique 21/21) ; **paiement réel ou sandbox jamais validé** |
| P6 | **Retrait** | client : code de retrait (`showPickupCode` → `my_pickup_code`) ; support : 146-2 (`confirm_pickup`) | RPC `my_pickup_code`, `confirm_pickup` (31b/31c) | `orders` (remise), journal des essais | rôle support ou admin ; 5 essais maximum (31c) | code faux → « Code incorrect » ; délai de 20 s ; réseau, 401, 403, 500 → jamais de faux succès | **Production (serveur intercepté) 1/1 aujourd'hui** ; local `retrait.spec` (historique) ; **remise réelle jamais testée** |
| P7 | **Vendeur** | menu → 57 (tableau de bord) → 58/62 (annonces) → 63/66 (commandes reçues) | `listings` (CRUD), `listing-images`, `seller_orders`, `set_seller_order_status` | annonces, photos, statuts de préparation | rôles student, dept, admin (57-69) ; RLS sur le propriétaire | erreurs → alertes | tests REST et Flutter locaux ; non rejoué en production |
| P8 | **Validation des annonces** (département) | menu dept → file de validation | RPC de décision (`on_listing_decided`) | `listings.status` | dept, admin | — | local |
| P9 | **Messagerie** | 05 « Contacter » → 53/54 ; commandes → conversation | `start_conversation`, `start_order_conversation`, `messages`, `chat-files` | messages, pièces jointes | participants seulement (RLS) | envoi échoué → message | tests REST locaux (`messaging_rest`, `chat_attachments_rest`) |
| P10 | **Services et devis** | 22b → 36 → 95b (demande) → réponse → décision | `request_quote`, `answer_quote`, `decide_quote`, `cancel_quote` | `quote_requests` | demandeur et prestataire | refus, annulation | `quotes_rest` local ; `devis.spec` **non rejouable** sans le propriétaire (historique) |
| P11 | **Missions sur mesure** | 191 (besoin) → propositions → 192/193 (devis, paiement) → 194/197 (jalons) → dossier et messagerie | `save_mission`, `propose_on_mission`, `decide_proposal`, `assign_mission`, `submit_milestone`, `decide_milestone`, `project-files` | `missions`, `mission_proposals`, `mission_milestones`, `mission_messages` | parties de la mission (RLS `is_mission_party`) | — ; **« Poser une question » (192) et « Brouillon » (195) simulés** | `lots_rest`, `lots2_rest` et `lots.spec` locaux |
| P12 | **Vœux, campagnes, projets, lives** | 216-218, 84, 78-87, 223/246/L1 | `save_wish`, `save_campaign`, `review_campaign`, `save_project`, `add_project_step`, `review_project`, `save_live` | tables correspondantes | auteur ; revue par dept ou admin | contributions et diffusion **non disponibles** (`unavailableAction`) | local |
| P13 | **Certificats** | « Mes certificats », vérification publique, émission (dept) | `request_certification`, `issue_certificate`, `verify_certificate` | `certificates` | émission par dept ou admin ; vérification publique contrôlée | **révocation et décision de certification sans interface** | local |
| P14 | **Bornes** | 206-210 (borne), incidents, événements | `report_kiosk_incident`, `schedule_kiosk_event`, `kioskNetworkCheck` | `kiosk_incidents`, `kiosk_events` | support, admin | **jeton QR et ticket d'impression simulés** | local |
| P15 | **Administration** | menu admin → paramètres d'établissement, modèles, clés d'API, invitations, journal | `save_institution`, `save_notification_template`, `create_api_key`/`revoke_api_key`, `invite_department_member`, `log_audit` | tables d'administration | admin ou dept | — ; **comptes (128) simulés** ; **signalements (131/170) fictifs** | local |
| P16 | **Sécurité du compte** | 272 (2FA), 273 (export et suppression) | MFA Supabase (TOTP), `engage('account_deletion'…)` | facteurs MFA, demandes | compte connecté | 3 essais par facteur (historique) | `mfa_rest` local ; `mfa.spec` non rejoué (créerait un compte) |
| P17 | **CV partagé** | profil → lien → `/cv/:token` | `regenerate_cv_link`, `shared_cv` | lien régénérable | jeton de 32 caractères hexadécimaux | jeton invalide → vide | route servie en production (HTTP 200) ; contenu non vérifié (pas de jeton réel) |

## 2. Ruptures et anomalies de parcours

| Type | Cas | Preuve |
|---|---|---|
| Actions qui affichent un succès sans confirmation serveur | 9 boutons + mot de passe oublié + administration des comptes | 03 §3 A et C |
| Formulaires qui n'enregistrent rien | brouillons 165, 167, 195 ; question 192 ; signalement 64 ; message au mentor 164 ; message à l'équipe 194 | 03 §3 A |
| Données fictives présentées comme réelles | signalements du support (131/170) et leurs compteurs ; classement des hackathons | `ops.dart:26-67`, `hackathons.dart:220` |
| Parcours interrompus | « Mot de passe oublié » (P4) : l'utilisateur croit son mot de passe changé, mais la connexion échoue | `auth.dart:488-517` |
| Écrans atteints seulement par des chemins inattendus | 150-1, 275 (liens dans du code mort) ; 176 (onboarding client jamais montré) ; 150-4 | 02 §4 |
| Parcours longs | une vingtaine d'écrans à 6-10 étapes de l'accueil | 02 §2 |
| Fonctionnalités réservées à certains rôles | 99 écrans réservés ; un visiteur reçoit une **404 neutre** (et non une invitation à se connecter) | `access.dart:115-139` |
| Fonctions serveur sans interface | `revoke_certificate`, `decide_certification` | 01 §5 |
| Routes cassées | **aucune** : les 315 routes `/s/:id` résolvent un écran ; les identifiants inconnus affichent `MissingScreen` (vérifié en production) | Playwright |
| États de chargement et d'erreur | modules `lots.dart` (`_run` : alerte sur erreur serveur, « hors connexion » expliqué), `engage.dart`, `pay.dart` (délais), `system_states.dart` (hors connexion, session expirée) | code |
| Erreurs masquées | `backend.dart:307-346, 541-570, 710-726` : certaines erreurs d'envoi de fichier ou d'URL signée sont converties en chaîne vide ou en `false` | rapport d'exploration (à confirmer ligne par ligne) |

## 3. Dépendances entre parcours (et blocages)

| Parcours | Dépend de | Statut de la dépendance | Bloqué ? |
|---|---|---|---|
| Retrait réel (P6) | commande **payée** (P5) + compte **support** | paiement réel jamais validé ; aucun compte support de recette en production | **oui**, en recette réelle |
| Paiement (P5) | clés Notch Pay **renouvelées** + webhook signé reçu | clés à renouveler (exposées) ; aucun événement authentique reçu | **oui** |
| Jalons et séquestre (P11) | paiement (P5) | idem | **oui** pour le séquestre réel |
| Contributions aux campagnes, duels, mise en avant, retrait des gains | paiements Mobile Money en production | non activés | **oui** (et expliqué à l'utilisateur) |
| Validation des annonces, vœux, campagnes et projets (P8, P12) | comptes **dept** ou **admin** en production | rôle attribuable seulement par le propriétaire de la base | recette **bloquée** sans intervention du propriétaire |
| Tableaux de bord (57, 108, 117, 127, 139, 187) | données et rôle | partiellement alimentés (à confirmer écran par écran) | partiel |
| Notifications | événements réels (commandes, messages) | déclencheurs serveur présents (`on_order_paid`, `on_message_inserted`) | non |
| Mot de passe oublié (P4) | Supabase Auth (`resetPasswordForEmail`) + modèle d'e-mail | **non branché** | **oui** |
