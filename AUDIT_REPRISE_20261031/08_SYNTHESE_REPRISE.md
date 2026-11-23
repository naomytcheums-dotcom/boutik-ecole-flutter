# 08 — Synthèse de reprise (pour vous)

> Audit en **lecture seule** du 31/10/2026 : aucun fichier source, aucune donnée, aucun déploiement, aucun commit. Détails et preuves
> dans les rapports 01 à 07 et dans `donnees/`. Outils reproductibles dans `outils/`.

## Ce qui fonctionne réellement (prouvé en production)

- Le **site en ligne** est exactement le build attendu : `main.dart.js` a pour SHA-256 `0e6f976a…`, celui du commit `69753e6`.
- La **base de production** est à jour : 16 migrations sur 16 ; fonctions `pay` v6, `notchpay-webhook` v6 et `notchpay-mcp` v3.
- Le **parcours visiteur** fonctionne : accueil, découverte, « Mes rubriques », page 404 neutre sur les espaces réservés, 5 tailles
  d'écran, rechargement et retour arrière (Playwright 12/12 aujourd'hui).
- L'**écran de retrait** n'affiche jamais de faux « Remise confirmée », même en cas d'erreur réseau, 401, 403, 500 ou double clic
  (Playwright 1/1 aujourd'hui, serveur intercepté).
- La **connexion** fonctionne (preuve en production du 31/10).
- Le **code est sain** : `flutter analyze` 0 erreur ; `flutter test` 405/405 (dont les 315 goldens).

## Ce qui est seulement présent dans le code (testé en local, pas en production)

36 fonctionnalités, dont :
- inscription, MFA, profils, liens et CV partagé ;
- annonces vendeur, validation, favoris, avis, commandes, annulation, suivi vendeur ;
- notifications, messagerie et messagerie de mission ;
- devis, missions, propositions, affectations, dossiers ;
- vœux, campagnes, projets, lives, certificats, incidents de borne ;
- paramètres d'administration, clés d'API, invitations, exports, préférences.

Elles appellent bien Supabase : les 54 RPC utilisées existent toutes côté serveur. Leurs tests ne tournent toutefois que sur la copie
locale.

## Ce qui est simulé (7 fonctionnalités, 15 actions)

- **Mot de passe oublié** : faux envoi de code, faux changement de mot de passe. **C'est un défaut.**
- **Administration des comptes** (écran 128) : « Compte mis à jour » sans effet sur le serveur.
- **9 boutons** annoncent un succès sans rien transmettre : messages au mentor et à l'équipe, question à l'administrateur, brouillons,
  signalement au département, ticket d'imprimante, code SMS.
- **Signalements du support** : données fictives.
- **Classement des hackathons** : équipes fictives.
- **Jeton QR de la borne** : généré dans le navigateur.

## Ce qui est inaccessible

- **3 écrans réellement orphelins** : 176 (bienvenue client), 150-4 et S1.
- **2 écrans** qui ne sont reliés que par du code mort : 150-1 et 275.
- **3 doublons probables** : A2, P4 et 250b.
- **2 fonctions serveur** sans interface : révocation et décision de certification.

Tous ces écrans restent accessibles par leur adresse et par « Mes rubriques ».

## Ce qui est défectueux

Le flux « mot de passe oublié » est défectueux. Les faux succès cités plus haut et, à moindre degré, les erreurs de fichiers qui
passent inaperçues sont aussi à corriger.

## Ce qui manque

- Les paiements Mobile Money annexes (contributions, duels, mise en avant, retrait des gains) et la diffusion vidéo en direct. Ces
  actions l'expliquent honnêtement à l'utilisateur.
- Les notifications push, e-mail et SMS.
- La logistique de livraison.
- L'export automatique des données.

## Ce qui reste à tester (avec votre autorisation)

1. Un **paiement sandbox** de bout en bout, avec un webhook signé, **après renouvellement des clés Notch Pay**.
2. Une **remise réelle** au kiosque par un compte support.
3. Le **MCP** avec la vraie clé. Le code annonce « Verify JWT désactivé », mais la production l'a activé.
4. Les **parcours par rôle** (client, vendeur, entreprise, département, direction, finance, support, admin) en production.
5. Le **nettoyage** des comptes `zz-test`.

## Priorités de développement

| Rang | Tâche |
|---|---|
| P0 | Clés Notch Pay et paiement sandbox · vrai « mot de passe oublié » · administration des comptes côté serveur |
| P1 | Suppression des 9 faux succès · signalements réels · écrans à relier · recette authentifiée · nettoyage `zz-test` |
| P2 | Révocation de certificat · classement réel · jeton de borne côté serveur · tableaux de bord · MCP · export RGPD · paiements annexes |
| P3 | Avertissements d'analyse · doublons à trancher · écran 14 · parcours longs · couche `features` morte · couverture · push · langues |

**Prochaine tâche recommandée** : **P0-2, le vrai flux « mot de passe oublié »**.
- C'est le seul défaut qui bloque directement un utilisateur réel.
- Il ne dépend d'aucune clé externe ni d'aucune migration.
- Il se teste entièrement sur la réplique avant la production.

P0-1 (paiement) reste la première priorité **métier**, mais il commence par **votre** intervention : le renouvellement des clés.

**Aucune correction n'a été commencée. J'attends votre autorisation explicite avant la phase de corrections.**
