# 03 — Audit des actions « Démonstration » et des comportements simulés

> Lecture seule. Outils : `outils/devenir_192.py` et `outils/persistance_192.py`. Ils lisent le code au commit `b3160af` (192
> occurrences) par `git show`, sans rien modifier. Données : `donnees/devenir_192_demonstrations.csv` et
> `donnees/messages_seuls_ecrans.csv`.

## 1. Occurrences actuelles

| Recherche dans `lib/` | Résultat | Interprétation |
|---|---|---|
| `gToast(context, 'Démonstration : …')` (motif historique) | **0** | toutes retirées |
| `Démonstration :` (toute forme) | **0** | — |
| « démonstration » en minuscules (messages) | 3 : `auth.dart:415` (inscription hors connexion), **`auth.dart:495` (mot de passe oublié, en production)**, `g_14.dart:77` (renvoi du code, écran 14) | la 2ᵉ est un défaut, voir §4 |
| `demoContent` / `demo` | 438 occurrences dans 141 fichiers, dont 238 dans 19 écrans générés | `demoContent = !Backend.ready` (`auth.dart:527`) : le contenu d'exemple de la maquette n'est **affiché que hors connexion** (tests, aperçu). **Faux positif** en production |
| `DemoCatalogRepository`, `demoModeProvider = true` (`lib/data/repositories/repositories.dart:19,81`) | utilisés **seulement** par des widgets morts de `lib/features` (287, 288, 262, 148) | **faux positif** : aucun effet à l'exécution (signalé à tort comme « catalogue faux » par l'exploration automatique) |
| `TODO`, `FIXME`, `mock`, `fake`, `coming soon` | aucun cas significatif dans `lib/` | — |
| `placeholder` | `gen.dart:93,99`, `photo_tile.dart`, `services.dart:37-42`, `seller.dart:213-215` | images de remplacement quand une photo manque : **normal** |
| « bientôt » / « à venir » | `g_164.dart` : « Discussion d'équipe : bientôt disponible » | fonctionnalité non construite |

## 2. Devenir des 192 actions historiques

Chaque action historique (écran et libellé, état `b3160af`) a été retrouvée **à la même position** dans l'écran actuel. Son nouveau
gestionnaire a été analysé, et la fonction appelée suivie jusqu'à un appel Supabase (`Backend.*`, `.rpc`, `.from`,
`functions.invoke`), y compris de manière transitive.

| Catégorie demandée | Nombre | Détail |
|---|---|---|
| 1 · Vraie fonctionnalité opérationnelle | **168** | **94 écrivent ou lisent côté serveur** (Supabase) · **63 naviguent** vers l'écran prévu · **11 actions locales légitimes** : partage WhatsApp ×2, copie d'une référence, aperçu de pages, ajout d'un lien avant enregistrement, nouvelle tentative réseau, 3 filtres de la borne 207, « Filtres réinitialisés » ×2 |
| 2 · Démonstration interactive sans persistance | 0 | — |
| 3 · Simulation (succès affiché sans serveur) | **6** | `submitReset` (16, mot de passe), « Brouillon enregistré » (165, 195), « Note enregistrée en brouillon » (167), « Question envoyée à l'administrateur » (192), « Signalement envoyé au département » (64) |
| 4 · Bouton sans véritable action | **11** | ce ne sont pas des boutons : des **bulles de conversation** et des **cartes d'information** de la maquette (55 ×2, 95 ×2, 196 ×3, 18c ×2, 237, l1) qui portaient à tort un gestionnaire « Démonstration ». Plus aucune action : **comportement correct** (faux positifs historiques) |
| 5 · Partiellement implémentée | 0 | — |
| 6 · En attente d'une API ou d'un service | **7** | `unavailableAction` ×6 (219 duel payant, 243 retrait des gains, 250/250b mise en avant payante, 84b contribution à une campagne, l1 diffusion en direct), qui l'**expliquent honnêtement** sans simuler · 164 « Discussion d'équipe : bientôt disponible » |
| 7 · Validation humaine nécessaire | 0 en tant que telle (la demande de suppression de compte, 273, est enregistrée côté serveur puis traitée par l'équipe) | — |
| 8 · Obsolète | 0 | — |
| 9 · Impossible à déterminer | 0 | — |
| **Total** | **192** | sur 129 écrans |

Résultat : **168 / 192 (87,5 %) sont devenues de vraies actions** ; 6 restent des simulations ; 7 attendent un service externe ; 11
étaient des faux positifs.

## 3. Comportements simulés aujourd'hui, avec ou sans le mot « Démonstration »

Recherche sur **tout** le code actuel, et pas seulement sur les 192 historiques. Les 22 éléments ci-dessous sont les **actions ou
flux simulés ou incomplets** :

### A. Boutons qui affichent un succès sans rien transmettre (9)

Analyse de tous les gestionnaires `gToast` sans autre appel (`donnees/messages_seuls_ecrans.csv`) :

| Écran | Fichier:ligne | Message affiché | Réalité |
|---|---|---|---|
| 14 | `g_14.dart:77` | « Nouveau code envoyé (démonstration : 482917) » | aucun envoi ; écran hors du parcours serveur d'inscription |
| 64 | `g_64.dart:93` | « Signalement envoyé au département » | rien n'est envoyé |
| 164 | `g_164.dart:101` | « Message envoyé au mentor » | rien n'est envoyé |
| 165 | `g_165.dart:90` | « Brouillon enregistré » | rien n'est enregistré |
| 167 | `g_167.dart:83` | « Note enregistrée en brouillon » | rien n'est enregistré |
| 192 | `g_192.dart:96` | « Question envoyée à l'administrateur » | rien n'est envoyé |
| 194 | `g_194.dart:174` | « Message envoyé à l'équipe » | rien n'est envoyé |
| 195 | `g_195.dart:88` | « Brouillon enregistré » | rien n'est enregistré |
| 210 | `g_210.dart:113` | « Ticket envoyé à l'imprimante de la borne » | aucune impression |

### B. Actions en attente d'un service externe (7) — comportement honnête

219, 243, 250, 250b, 84b, l1 (`unavailableAction`, `lib/figma/live/engage.dart:187`) et 164 (« bientôt disponible »).

### C. Flux métier simulés en logique (6), visibles en production

| Flux | Preuve | Effet réel |
|---|---|---|
| **Mot de passe oublié** (écran 15) | `submitForgot`, `lib/figma/live/auth.dart:488-497` | cherche le compte dans une **liste locale** ; affiche « Code de réinitialisation envoyé (démonstration : 482917) » ou « Si un compte existe, un code a été envoyé » ; **aucun e-mail ni SMS**. Aucun appel à `resetPasswordForEmail` dans tout `lib/` |
| **Nouveau mot de passe** (écran 16) | `submitReset`, `auth.dart:499-517` | modifie le mot de passe d'un compte **local** et affiche « Mot de passe modifié. Connectez-vous. » ; le mot de passe serveur **ne change pas** |
| **Administration des comptes** (écran 128) | `userDialog`, `lib/figma/live/admin.dart:24-70` | rôle et suspension modifiés dans `authProvider.accounts` (local) ; « Compte mis à jour » ; **aucune fonction serveur** n'existe pour cela (aucune RPC d'administration des rôles dans les migrations) |
| **Signalements du support** (131, 170) | `lib/figma/live/ops.dart:26-67` | 4 signalements fictifs (`_seedReports`) et compteurs fixes (27 ouverts, 11 en traitement, 142 résolus) affichés **sans condition `demoContent`** ; changements de statut locaux, alors que la table serveur `listing_reports` existe |
| **Classement des hackathons** (160-169) | `lib/figma/live/hackathons.dart:220-232` | 3 équipes fictives (`_seedRanking`) mêlées au projet déposé ; note du jury locale |
| **Jeton QR de la borne** (208-210) | `lib/figma/live/missions.dart:31-55` | jeton « pseudo-signé (démonstration) » calculé **dans le navigateur** avec un secret écrit en dur ; contrôle d'expiration et de réutilisation **local**. Ne concerne **pas** les codes de retrait des commandes, qui sont côté serveur (`my_pickup_code` / `confirm_pickup`) |

**Total : 9 + 7 + 6 = 22 actions ou flux simulés ou incomplets** (dont 15 simulés au sens strict, A + C).

## 4. Faux positifs écartés

- `demoContent` (238 occurrences dans les écrans) : n'affiche la maquette que sans serveur.
- `lib/data/demo/*` et `DemoCatalogRepository` : couche `features` morte.
- `seller.dart:319` « commandes de démonstration » : remplacées par les commandes serveur quand `Backend.ready`.
- `store.dart:236` historique : soumis à `demoContent`.
- `Démo en ligne` (`lots.dart:494`) : libellé d'un champ de lien de projet (« démo en ligne »), pas une simulation.

## 5. Annexe — les 192 actions historiques une par une

| # | Écran | Libellé historique « Démonstration : … » | Devenir actuel | Persistance | Fonction(s) | Message actuel |
|---|---|---|---|---|---|---|
| 1 | 101 | S’inscrire | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageOrManage | — |
| 2 | 102 | Voir la collection | navigation vers un écran | — | — | — |
| 3 | 11 | Créer un compte | navigation vers un écran | — | — | — |
| 4 | 118 | Enregistrer les modifications | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | editInstitutionDialog | — |
| 5 | 148_2 | Se déconnecter de tous les appareils | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | logoutEverywhere | — |
| 6 | 150_2 | Se reconnecter | navigation vers un écran | — | — | — |
| 7 | 150_3 | Réessayer | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | retryNetwork | — |
| 8 | 150_3 | Voir le mode hors ligne | navigation vers un écran | — | — | — |
| 9 | 150_4 | Découvrir la boutique | navigation vers un écran | — | — | — |
| 10 | 153 | Ignorer | navigation vers un écran | — | — | Offre ignorée : elle ne vous sera plus proposée en priorité. |
| 11 | 153 | Postuler | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageOrManage | — |
| 12 | 154 | Compléter mon dossier | navigation vers un écran | — | — | — |
| 13 | 156 | Enregistrer les préférences | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | savePrefs | — |
| 14 | 158 | Comparer la sélection | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | compareProposalsDialog | — |
| 15 | 159 | Mes candidatures | navigation vers un écran | — | — | — |
| 16 | 159 | Autres offres | navigation vers un écran | — | — | — |
| 17 | 16 | Réinitialiser le mot de passe | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | submitReset | — |
| 18 | 161 | S’inscrire | navigation vers un écran | — | — | Votre équipe est déjà inscrite. |
| 19 | 162 | Retour | navigation vers un écran | — | — | — |
| 20 | 162 | Valider l’inscription | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitRegistration | — |
| 21 | 164 | Discussion d’équipe | message seulement (gToast sans « Démonstration ») | — | — | Discussion d’équipe : bientôt disponible |
| 22 | 164 | Déposer le projet | navigation vers un écran | — | — | — |
| 23 | 165 | Enregistrer | message seulement (gToast sans « Démonstration ») | — | — | Brouillon enregistré |
| 24 | 165 | Soumettre | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitDeposit | — |
| 25 | 166 | Voir le certificat | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | myCertificatesDialog | — |
| 26 | 167 | Enregistrer | message seulement (gToast sans « Démonstration ») | — | — | Note enregistrée en brouillon |
| 27 | 167 | Valider la note | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | validateJury | — |
| 28 | 17 | Accepter et continuer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | acceptTerms | — |
| 29 | 170 | Annuler | navigation vers un écran | — | — | — |
| 30 | 170 | Envoyer le signalement | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitReport | — |
| 31 | 171 | Annuler le paiement | navigation vers un écran | — | — | — |
| 32 | 171 | Continuer en sécurité | navigation vers un écran | — | — | — |
| 33 | 173 | Fermer | navigation vers un écran | — | — | — |
| 34 | 175 | Passer | navigation vers un écran | — | — | — |
| 35 | 175 | Continuer | navigation vers un écran | — | — | — |
| 36 | 176 | Passer | navigation vers un écran | — | — | — |
| 37 | 176 | Continuer | navigation vers un écran | — | — | — |
| 38 | 177 | Passer | navigation vers un écran | — | — | — |
| 39 | 177 | Continuer | navigation vers un écran | — | — | — |
| 40 | 178 | Passer | navigation vers un écran | — | — | — |
| 41 | 178 | Commencer | navigation vers un écran | — | — | — |
| 42 | 18 | Retour à l’accueil | navigation vers un écran | — | — | — |
| 43 | 18 | Contacter le support | navigation vers un écran | — | — | — |
| 44 | 189 | Comparer la sélection | navigation vers un écran | — | — | — |
| 45 | 18c | Ces informations permettent de confirmer\nvotre statut d’étudiant de l’IUT de Douala. | 4 · plus aucune action (bouton inerte) | — | — | — |
| 46 | 18c | Vos documents sont chiffrés et ne sont\nconsultés que par l’équipe de validation. | 4 · plus aucune action (bouton inerte) | — | — | — |
| 47 | 191 | Envoyer mon besoin | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitBrief | — |
| 48 | 192 | Poser une question | message seulement (gToast sans « Démonstration ») | — | — | Question envoyée à l’administrateur |
| 49 | 192 | Accepter le devis | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | acceptQuote | — |
| 50 | 193 | Payer 54 000 FCFA | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | payNextMilestone | — |
| 51 | 194 | Écrire à l’équipe | navigation vers un écran | — | — | — |
| 52 | 194 | Voir le dossier | navigation vers un écran | — | — | — |
| 53 | 195 | Brouillon | message seulement (gToast sans « Démonstration ») | — | — | Brouillon enregistré |
| 54 | 195 | Envoyer pour validation | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitProof | — |
| 55 | 196 | Bonjour, voici les trois pistes de logo. Qu’en pensez-vous ? | 4 · plus aucune action (bouton inerte) | — | — | — |
| 56 | 196 | La piste 2 me plaît. Pouvez-vous essayer une version plus sobre ? | 4 · plus aucune action (bouton inerte) | — | — | — |
| 57 | 196 | Bien sûr, nouvelle version sous 48 h. | 4 · plus aucune action (bouton inerte) | — | — | — |
| 58 | 196 | Ajouter un fichier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | missionFileUpload | — |
| 59 | 196 | Envoyer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | missionDossierDialog | — |
| 60 | 197 | Valider et libérer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | releaseMilestone | — |
| 61 | 198 | Qualifier | navigation vers un écran | — | — | — |
| 62 | 198 | Qualifier | navigation vers un écran | — | — | — |
| 63 | 198 | Qualifier | navigation vers un écran | — | — | — |
| 64 | 198 | Qualifier | navigation vers un écran | — | — | — |
| 65 | 199 | Attribuer à cette équipe | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | assignNeedDialog | — |
| 66 | 202 | Personnaliser | navigation vers un écran | — | — | — |
| 67 | 202 | Commander le pack | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | orderPack | — |
| 68 | 205 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveProject | — |
| 69 | 205 | Envoyer à l’IUT | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveProject | — |
| 70 | 206 | Borne prête · réseau OK | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | kioskNetworkCheck | — |
| 71 | 207 | Tout | autre gestionnaire (à examiner) | — | — | — |
| 72 | 207 | Produits | autre gestionnaire (à examiner) | — | — | — |
| 73 | 207 | Services | autre gestionnaire (à examiner) | — | — | — |
| 74 | 207 | Missions | navigation vers un écran | — | — | — |
| 75 | 21 | Réinitialiser | message seulement (gToast sans « Démonstration ») | — | — | Filtres réinitialisés |
| 76 | 21 | Rechercher | navigation vers un écran | — | — | — |
| 77 | 211 | Voir le certificat | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | verifyCertificateDialog | — |
| 78 | 213 | Émettre un certificat | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | issueCertificateDialog | — |
| 79 | 215 | Déposer un brief au département | navigation vers un écran | — | — | — |
| 80 | 217 | Précommander · 25 000 FCFA | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageOrManage | — |
| 81 | 218 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveWish | — |
| 82 | 218 | Publier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveWish | — |
| 83 | 219 | Lancer le duel | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | unavailableAction | — |
| 84 | 220 | Voter pour la lampe | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageAction | — |
| 85 | 220 | Voter pour le jus | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageAction | — |
| 86 | 221 | Voir le dossier du gagnant | navigation vers un écran | — | — | — |
| 87 | 224 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveLive | — |
| 88 | 224 | Planifier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveLive | — |
| 89 | 228 | Régénérer le lien | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | regenerateCvLink | — |
| 90 | 229 | Proposer un stage | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageAction | — |
| 91 | 229 | Contacter | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageAction | — |
| 92 | 23 | Innovations | navigation vers un écran | — | — | — |
| 93 | 23 | Réinitialiser | message seulement (gToast sans « Démonstration ») | — | — | Filtres réinitialisés |
| 94 | 23 | Appliquer | navigation vers un écran | — | — | — |
| 95 | 231 | Commencer | navigation vers un écran | — | — | — |
| 96 | 233 | Voir les propositions | navigation vers un écran | — | — | — |
| 97 | 233 | Écrire à l’équipe | navigation vers un écran | — | — | — |
| 98 | 234 | ✓  Valider et libérer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | myNeedsDialog | — |
| 99 | 234 | Demander une correction | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | myNeedsDialog | — |
| 100 | 236 | Enregistrer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | savePrefs | — |
| 101 | 237 | Impact territorial | 4 · plus aucune action (bouton inerte) | — | — | — |
| 102 | 241 | Salut ! Rejoins Boutik-École, la marketplace des talents de l’IUT de Douala : boutik-ecole | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | shareViaWhatsApp | — |
| 103 | 241 | Envoyer via WhatsApp (3) | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | shareViaWhatsApp | — |
| 104 | 243 | Retirer vers Orange Money | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | unavailableAction | — |
| 105 | 250 | Propulser | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | unavailableAction | — |
| 106 | 250b | Propulser | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | unavailableAction | — |
| 107 | 26 | Voir les détails | navigation vers un écran | — | — | — |
| 108 | 263 | Téléverser un média | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | uploadMedia | — |
| 109 | 264 | Aperçu | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | previewPagesDialog | — |
| 110 | 265 | Modifier le modèle | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | editTemplatesDialog | — |
| 111 | 271 | +  Ajouter un autre lien (portfolio, site, Drive…) | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | addProfileLink | — |
| 112 | 271 | Enregistrer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveProfileLinks | — |
| 113 | 272 | Vérifier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | twoFactorDialog | — |
| 114 | 273 | Demander l’export | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageAction | — |
| 115 | 273 | Supprimer le compte | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | requestAccountDeletion | — |
| 116 | 274 | Accepter et continuer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | acceptTerms | — |
| 117 | 275 | Continuer | navigation vers un écran | — | — | — |
| 118 | 276 | Parcourir le catalogue hors ligne | navigation vers un écran | — | — | — |
| 119 | 277 | Voir les journaux d’incidents | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | kioskIncidentsDialog | — |
| 120 | 278 | Enregistrer les informations | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveProjectLinks | — |
| 121 | 279 | Ajouter un fichier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | uploadProjectFileFor | — |
| 122 | 280 | Créer une clé | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | apiKeysDialog | — |
| 123 | 282 | Programmer l’événement | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | scheduleKioskEvent | — |
| 124 | 283 | Émettre un certificat | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | issueCertificateDialog | — |
| 125 | 284 | Exporter le registre (CSV) | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | exportFinancialRegister | — |
| 126 | 285 | Valider le jalon 3 | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | myNeedsDialog | — |
| 127 | 286 | Inviter un membre | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | inviteMemberDialog | — |
| 128 | 287 | + Nouvelle fiche | navigation vers un écran | — | — | — |
| 129 | 288 | Exporter | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | exportCatalog | — |
| 130 | 288 | + Nouvelle fiche | navigation vers un écran | — | — | — |
| 131 | 29 | Contacter le vendeur | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | contactOrderSeller | — |
| 132 | 29 | Voir le reçu | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | downloadDocument | — |
| 133 | 30 | Évaluer la commande | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | reviewOrderDialog | — |
| 134 | 30 | Voir le détail | navigation vers un écran | — | — | — |
| 135 | 30 | Contacter le support | navigation vers un écran | — | — | — |
| 136 | 32 | Ajouter au panier | navigation vers un écran | — | — | Ajouté au panier |
| 137 | 33 | Contacter le créateur | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | contactSeller | — |
| 138 | 35 | Me prévenir | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageOrManage viewedProductTitle | — |
| 139 | 35 | Ajouter au panier | navigation vers un écran | — | — | Ajouté au panier |
| 140 | 36 | Demander un devis | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | askQuote | — |
| 141 | 36 | Commander | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | orderService | — |
| 142 | 39 | Envoyer la question | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | sendProductQuestion | — |
| 143 | 41 | Continuer | navigation vers un écran | — | — | — |
| 144 | 42 | Confirmer la commande | navigation vers un écran | — | — | — |
| 145 | 43 | Copier la référence | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | copyOrderRef | — |
| 146 | 43 | J’ai payé | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | checkPaymentNow | — |
| 147 | 44 | Accueil | navigation vers un écran | — | — | — |
| 148 | 46 | Contacter le vendeur | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | contactOrderSeller | — |
| 149 | 46 | Voir le code de retrait | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | showPickupCode | — |
| 150 | 47 | Garder | navigation vers un écran | — | — | — |
| 151 | 47 | Annuler la commande | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | cancelViewedOrder | — |
| 152 | 48 | Envoyer la demande | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitClaimForm | — |
| 153 | 51 | Contacter le vendeur | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | contactOrderSeller | — |
| 154 | 51 | Suivre ma commande | navigation vers un écran | — | — | — |
| 155 | 55 | Bonjour, voici mon portfolio et deux références. | 4 · plus aucune action (bouton inerte) | — | — | — |
| 156 | 55 | Parfait, nous planifions un entretien jeudi. | 4 · plus aucune action (bouton inerte) | — | — | — |
| 157 | 58 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitListing | — |
| 158 | 58 | Publier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitListing | — |
| 159 | 59 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveService | — |
| 160 | 59 | Publier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveService | — |
| 161 | 60 | Modifier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | editListingDialog | — |
| 162 | 60 | Publier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitCurrentListing | — |
| 163 | 64 | Signaler un souci | message seulement (gToast sans « Démonstration ») | — | — | Signalement envoyé au département |
| 164 | 64 | Marquer prête | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) via sellerStatusProvider.advance → Backend.setSellerOrderStatus (seller.dart:306) | advanceCurrentOrder | — |
| 165 | 65 | Marquer comme prête | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) via sellerStatusProvider.advance → Backend.setSellerOrderStatus (seller.dart:306) | advanceCurrentOrder | — |
| 166 | 69 | Compléter mon dossier | navigation vers un écran | — | — | — |
| 167 | 72 | Ajouter à mon portfolio | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | addPortfolioItem | — |
| 168 | 76 | Retirer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | withdrawLatestApplication | — |
| 169 | 76 | Contacter | navigation vers un écran | — | — | — |
| 170 | 77 | Écrire | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageAction | — |
| 171 | 79 | Soutenir le projet | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | supportDialog | — |
| 172 | 80 | Continuer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitProject | — |
| 173 | 82 | Ajouter une étape | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | addProjectStep | — |
| 174 | 83 | Téléverser | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | uploadProjectFileFor | — |
| 175 | 84 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveCampaign | — |
| 176 | 84 | Continuer | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveCampaign | — |
| 177 | 84b | Contribuer | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | unavailableAction | — |
| 178 | 87 | Déclarer une innovation | navigation vers un écran | — | — | — |
| 179 | 89 | Suivre | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | engageOrManage | — |
| 180 | 90 | Brouillon | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveNeed | — |
| 181 | 90 | Publier | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveNeed | — |
| 182 | 93 | Comparer la sélection | navigation vers un écran | — | — | — |
| 183 | 93b | Refuser | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | myNeedsDialog | — |
| 184 | 93b | Accepter | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | myNeedsDialog | — |
| 185 | 94 | Choisir une proposition | navigation vers un écran | — | — | — |
| 186 | 95 | Pouvez-vous livrer sous 10 jours pour 420 000 FCFA ? | 4 · plus aucune action (bouton inerte) | — | — | — |
| 187 | 95 | Oui, à condition de démarrer lundi. | 4 · plus aucune action (bouton inerte) | — | — | — |
| 188 | 95b | Envoyer la demande | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | submitQuoteRequest | — |
| 189 | a2 | Commencer | navigation vers un écran | — | — | — |
| 190 | l1 | Atelier : fabrication de la lampe en bois recyclé | 4 · plus aucune action (bouton inerte) | — | — | — |
| 191 | l1 | Lancer le live | 1 · appel d'un module métier (lib/figma/live) | local (mémoire, presse-papiers, fichier ou dialogue sans appel serveur) | unavailableAction | — |
| 192 | p5 | Enregistrer mes outils | 1 · appel d'un module métier (lib/figma/live) | serveur (Supabase) | saveProfileLinks | — |
