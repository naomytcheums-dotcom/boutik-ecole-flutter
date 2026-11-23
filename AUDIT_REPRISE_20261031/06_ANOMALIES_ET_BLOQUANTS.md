# 06 — Anomalies, bloquants, risques et tests impossibles

> Constatés en lecture seule le 31/10/2026. Aucune anomalie n'a été corrigée (consigne de la phase d'audit).

## 1. Anomalies (bugs et faux succès)

| Réf. | Gravité | Anomalie | Preuve | Effet pour l'utilisateur |
|---|---|---|---|---|
| R-01 | **Élevée** | « Mot de passe oublié » entièrement simulé : aucun e-mail ou SMS ; le message annonce un envoi ; la réinitialisation modifie un compte **local** et affiche « Mot de passe modifié » | `lib/figma/live/auth.dart:488-517` ; aucun `resetPasswordForEmail` dans `lib/` | un utilisateur qui a oublié son mot de passe **croit l'avoir changé** et ne peut plus se connecter. L'alerte « Compte déjà existant » (`auth.dart:362`) l'oriente pourtant vers ce flux |
| R-02 | **Élevée** | Administration des comptes (écran 128) : changement de rôle et suspension **locaux**, avec le message « Compte mis à jour » | `lib/figma/live/admin.dart:24-70` ; aucune RPC d'administration des rôles | un administrateur croit avoir suspendu un compte, qui reste actif côté serveur. **Pas de faille** : le serveur reste protégé par `protect_profile_authority` |
| R-03 | Moyenne | 9 boutons affichent un succès sans rien transmettre (14, 64, 164, 165, 167, 192, 194, 195, 210) | 03 §3 A | messages, brouillons, signalements et tickets perdus sans que l'utilisateur le sache |
| R-04 | Moyenne | Signalements du support (131, 170) : 4 signalements fictifs et compteurs figés (27, 11, 142), affichés en production | `lib/figma/live/ops.dart:26-67` | le support voit de faux signalements ; les vrais (`listing_reports`) n'apparaissent pas ici |
| R-05 | Moyenne | Classement des hackathons mêlant 3 équipes fictives | `lib/figma/live/hackathons.dart:216-228` | classement faux |
| R-06 | Moyenne | Jeton QR de borne « pseudo-signé » dans le navigateur, avec un secret en dur (`boutik-secret`) | `lib/figma/live/missions.dart:31-55` | aucune garantie d'authenticité ; **sans impact** sur les codes de retrait, qui sont côté serveur |
| R-07 | Faible | Écran 14 : « Nouveau code envoyé (démonstration : 482917) » | `g_14.dart:77`, `auth.dart:67,415,425` | écran hors du parcours serveur, mais atteignable |
| R-08 | Faible | Certaines erreurs de fichiers (envoi, URL signée) converties en chaîne vide ou en `false` | `lib/figma/live/backend.dart:307-346, 541-570, 710-726` (signalé par l'exploration, à confirmer ligne par ligne) | échec d'envoi peu explicite |
| R-09 | Faible | `flutter analyze` : 3 imports inutilisés, 13 `use_build_context_synchronously` (risque de contexte invalide après `await`) | `donnees/flutter_analyze.txt` | rares erreurs d'affichage après une action asynchrone |
| R-10 | Faible (documentation) | `notchpay-mcp` : le code annonce « Verify JWT désactivé », la production a `verify_jwt=true` | `supabase/functions/notchpay-mcp/index.ts:1-8` ; `donnees/supabase_functions_list.txt` | un client MCP qui ne fournirait que la clé MCP serait refusé par la passerelle |

## 2. Fonctionnalités incomplètes (détail dans 05)

- Révocation et décision de certification : fonctions serveur sans interface.
- Contributions, duels, mise en avant, retrait des gains, diffusion en direct : en attente des paiements ou du streaming (comportement
  honnête).
- Notifications push, e-mail et SMS : absentes.
- Export et suppression des données : simple demande, traitée manuellement.
- Livraison : statuts seulement, sans transporteur.
- Recherche : surtout locale.
- Panier : local.
- 8 écrans sans parcours (176, 150-1, 150-4, 275, S1, A2, P4, 250b).

## 3. Points de sécurité

| Point | Constat | Statut |
|---|---|---|
| Contrôle des rôles côté client | `access.dart` filtre l'affichage seulement ; la sécurité réelle repose sur RLS et RPC | conforme, si RLS est correcte (vérifiée historiquement : catalogue = réplique, 41/41 contrôles) |
| Escalade de rôle | empêchée par le déclencheur `protect_profile_authority` (migration p0) | historique vérifié |
| Paiement | `pay` : propriétaire, annulation, montant, référence, pas de double paiement ; webhook : HMAC `x-notch-signature` en temps constant, anti-rejeu par empreinte du corps, paiement tardif refusé | code vérifié par l'exploration ; tests locaux ; **événement réel non reçu** |
| Clés Notch Pay | **exposées, à renouveler** (historique) | **bloquant** pour toute validation de paiement |
| MCP | clé uniquement dans l'en-tête (pas `?key=`), méthodes de découverte publiques ; `verify_jwt=true` | à tester avec la vraie clé |
| Codes de retrait | génération sûre, 5 essais maximum, journal (31c) ; interface sans faux succès (vérifiée en production aujourd'hui, serveur intercepté) | conforme |
| Secrets dans le bundle | clé **publiable** Supabase (`sb_publishable_…`) présente, ce qui est normal ; aucune clé de service dans le code client (historique) | conforme |
| Comptes de test en production | comptes `zz-test-*` créés par les recettes passées ; script `supabase/maintenance/cleanup_test_accounts.sql` | **nettoyage en attente d'autorisation** |
| Points de restauration du PC | (hors projet) disque presque plein : risque pour tout `build` ou `test` local | voir l'audit de stockage |

## 4. Tests impossibles dans le cadre de cet audit (et ce qui manque)

| Test | Pourquoi impossible | Ce qu'il faudrait |
|---|---|---|
| Paiement sandbox de bout en bout, webhook signé réel | clés exposées non renouvelées ; aucun paiement autorisé | renouveler `NOTCHPAY_KEY`/`NOTCHPAY_HASH`, autoriser **un** paiement sandbox |
| Remise réelle au kiosque | exige une commande **payée** et un compte **support** | autorisation de créer un compte support de recette et une commande sandbox |
| MCP avec la vraie clé | clé jamais communiquée | la clé, ou un test lancé par le propriétaire |
| Parcours authentifiés en production (inscription, MFA, engagements, devis, avis) | créent des comptes `zz-test` ou des données | autorisation explicite, ou une base de recette isolée |
| Parcours dept, admin, finance, direction | rôles attribuables seulement par le propriétaire | comptes de recette avec ces rôles |
| Suites REST et sécurité (`supabase/tests/*.py`), `lots.spec`, `lots2.spec`, `retrait.spec` | écrivent dans une base (même locale) | accord pour les rejouer sur la réplique locale |
| Lecture des politiques RLS et des droits `EXECUTE` en production | exige une connexion SQL (lecture) à la base | accord pour une session en lecture seule (`begin transaction read only`) |
| Identifiant de déploiement Vercel | exige l'accès au compte Vercel | accès en lecture au tableau de bord |
| Couverture de code | aurait créé `coverage/` | accord pour `flutter test --coverage` |

## 5. Informations à obtenir auprès de vous

1. Le flux « mot de passe oublié » doit-il passer par l'e-mail (Supabase) ou par un SMS (fournisseur à choisir) ?
2. L'administration des rôles (128) doit-elle être réservée à « Admin global », avec quelle traçabilité ?
3. A2, P4, 250b, S1 : écrans à garder (et à relier) ou échantillons de maquette à retirer du parcours ?
4. Panier : doit-il être persistant d'un appareil à l'autre ?
5. Notifications push, e-mail et SMS : dans le périmètre ?
6. Livraison : un transporteur ou un retrait uniquement à la borne ?
7. Visiteur sur un écran réservé : 404 neutre (choix actuel, pour la confidentialité) ou invitation à se connecter ?
