# 12 — Matrice de traçabilité

Exigence = élément fonctionnel issu des sections de la maquette Figma (A à Y, AA, AD, AI, AM, nouveaux écrans) et des demandes exprimées par le propriétaire pendant le développement. Il n'existe pas de cahier des charges unique dans le dépôt (`docs/QUESTIONS.md` liste des questions ouvertes) : la traçabilité est donc établie par section.

| Section Figma | Écrans (exemples) | Composants/modules | API / données | Tests | Résultat |
|---|---|---|---|---|---|
| A Démarrage et navigation (01–10) | 01, 02, 03, 04, 05, 10 | `gen.dart` (`GSplashBar`), `nav.dart`, `auth.dart` | — | golden ×10, parcours | Écrans codés ; navigation partielle ; logique : connexion locale |
| B Authentification (11–20) | 11–18c | `auth.dart`, `backend.dart` | Supabase Auth, `profiles` | `account_test` | Partiel : OTP simulé (AN-011) |
| C Découverte et achats (21–31) | 19, 22, 25, 06 | `store.dart`, `l06.dart`, `lfav.dart` | (catalogue local) | `purchase_flow_test`, `search_favorites_test` | Partiel : données locales (AN-007) |
| D Fiches produits (32–39) | 05, 33… | `store.dart` | — | golden | Partiel |
| E Commandes, livraison (41–49) | 07, 08, 09, 45 | `store.dart`, `l09.dart`, `pay.dart` | `orders`, `order_lines`, fonction `pay` | `purchase_flow_test` | Partiel ; paiement MTN vérifié en sandbox (AN-014 partiel) |
| F Communication (50–56) | 50–56 | `chat.dart` | — | golden | Messagerie texte locale ; reste simulé |
| G Espace étudiant/vendeur (57–69) | 57–69 | `seller.dart`, `review.dart` | — (`listings` non utilisée) | `seller_test` | En mémoire (AN-007, AN-008) |
| H Talents (70–77) | 70–77 | `talents.dart` | — | `talents_test` | En mémoire |
| I Projets et financement (78–87) | 78–87 | `talents.dart` | — | `talents_test` | Partiel |
| J Entreprises B2B (88–99) | 88–99 | écrans générés | — | golden | Majoritairement visuel/simulé |
| K Événements et communautés (100–107) | 100–107 | écrans générés | — | golden | Visuel/simulé |
| L Département (108–116) | 108–116 | `review.dart` | — | `review_finance_test` | En mémoire |
| M Admin institutionnelle (117–126) | 117–126 | `audit.dart` | `audit_log` (écriture) | `admin_audit_test` | Partiel |
| N Admin globale (127–138) | 127–138 | `admin.dart`, `ops.dart`, `access.dart` | — | `admin_audit_test`, `ops_test`, `access_test` | En mémoire (AN-012, AN-013) |
| O Finance (139–144) | 139–144 | `ops.dart` | — | `review_finance_test` | Partiel |
| P Kiosques, support (145–147) | 145–147 | `ops.dart` | — | `ops_test` | Partiel |
| Q Paramètres et états (148–150) | 148–150 | écrans générés | — | golden | Visuel |
| S Opportunités et alertes IA (151–159) | 151–159 | `talents.dart` | — | `talents_test` | Partiel |
| T Hackathons (160–169) | 160–169 | `hackathons.dart` | `hackathon_teams` (non utilisée) | `hackathon_test` | En mémoire |
| U Confiance, sécurité, partage (170–174) | 170–174 | `share.dart`, `ops.dart` | — | golden | Partage réel ; reste simulé |
| V Onboarding, rôles (175–181) | 175–181 | écrans générés | — | golden | Visuel/simulé |
| W Faible connexion, langues (182–186) | 182–186 | écrans générés | — | golden | Visuel |
| X Web entreprise (187–190) | 187–190 | écrans générés | — | golden | Visuel |
| Y Missions sur mesure (191–205) | 191–205 | `missions.dart` | `missions` (non utilisée) | `kiosk_missions_test` | En mémoire |
| AA Borne phygitale (206–210) | 206–210 | `missions.dart` | `kiosk_sessions` (non utilisée) | `kiosk_missions_test` | En mémoire (AN-023) |
| AD Innovations (216–229) | 216–229 | écrans générés | — | golden | Visuel/simulé |
| AI Kéla et WhatsApp (230–236) | 230–236 | `kela.dart` | — | golden | Transcription code écrit, non vérifié ; WhatsApp absent (AN-024) |
| AM Cercle, parrainage, publication (240–255) | 240–255 | écrans générés | — | golden | Visuel/simulé |
| Nouveaux écrans de l'audit (255–270) | 255–270 | `docs.dart`, `pay.dart`… | `orders`, fonction `pay` | golden | Partiel (reçu/facture, paiement) |
| Doublons à trancher (32 variantes) | — | — | — | — | Non codé (AN-026) |

Détail par écran : `02_ROUTES_ET_PAGES.md`. Anomalies : `09_REGISTRE_ANOMALIES.md`.
