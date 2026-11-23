# 09 — Rapport final : l'application est-elle prête à lancer ?

> État au 01/11/2026. Production inchangée (bundle `0e6f976a…` = `69753e6`, 16 migrations). Corrections locales : commits `6364a6d`
> et `04a0dbd` (non poussés), migration `20261101000000` (non appliquée).

## Réponse courte

**Non, pas encore pour un lancement public avec paiements.** Le parcours de découverte (visiteur, catalogue, connexion) fonctionne en
production. Mais **aucun paiement réel n'a jamais été reçu**, les clés Notch Pay doivent être renouvelées, et les corrections du 01/11
(dont le « mot de passe oublié » réel et l'administration des comptes) ne sont **pas encore en ligne**.

## Ce qui est terminé (prouvé)

- Site en ligne stable : bundle identique au build testé ; parcours visiteur et 5 tailles d'écran vérifiés en production.
- Connexion vérifiée en production ; contrôle d'accès par rôle côté client (page 404 neutre) vérifié en production.
- Base de production :
  - 16 migrations synchronisées ;
  - RLS sur toutes les tables publiques ;
  - toutes les fonctions `SECURITY DEFINER` avec `search_path` ;
  - aucun secret dans le bundle.
- Écran de retrait sans faux succès (production, trafic intercepté).
- Logique serveur des missions, devis, vœux, campagnes, projets, lives, certificats, bornes, messagerie, fichiers, stock et MFA :
  386/386 sur la réplique (01/11).

## Ce qui a été corrigé le 01/11 (local, à déployer)

1. Mot de passe oublié **réel** (Supabase Auth), à la place d'une simulation.
2. Administration des comptes **réelle** (rôle, suspension effective, journal, dernier admin protégé), avec la migration.
3. Signalements du support **réels** et compteurs exacts ; changement de statut avec la migration.
4. Missions sur mesure et concours : **plus aucune action simulée** quand le serveur est joignable, dont **aucun faux paiement de
   séquestre**.
5. **11 faux succès** supprimés (14, 64, 110, 161, 164, 165, 167, 192, 194, 195, 210). Les brouillons sont réellement enregistrés sur
   l'appareil.
6. Certificats : révocation et demandes de badge accessibles ; écran 176 relié.
7. Identité Web (titre, description, langue, manifeste) ; permissions Android et iOS indispensables.
8. 0 avertissement d'analyse ; 16 nouveaux tests.

## Tests

| Réussis | Échoués | Non vérifiables aujourd'hui |
|---|---|---|
| Flutter 421/421 (dont 315 goldens) · analyse 0 erreur · REST réplique 386/386 · migration 20/20 (réplique, annulée) · production en lecture seule : catalogue de sécurité, secrets (noms), bundle, performances | **aucun** dans les résultats finaux | paiement sandbox, webhook signé authentique, MCP avec la clé, remise réelle, parcours par rôle en production, mot de passe oublié en ligne, Playwright locaux (disque saturé), Android, iOS, Firefox, Safari, audit WCAG |

## Risques restants

1. **Paiement jamais éprouvé** de bout en bout. **Critique**.
2. **Clés Notch Pay exposées** non renouvelées. **Critique**.
3. **Aucun administrateur ni support réel** en production : la modération et les retraits sont impossibles le jour du lancement.
4. Écrans de mission et de concours qui **affichent encore des données d'exemple** : montants et avancement fictifs visibles.
5. 46 comptes `zz-test` en production ; 11 annonces « plateforme » à valider.
6. Aucune supervision ni sauvegarde vérifiée.
7. Versions mobiles jamais construites.
8. **Poste de développement saturé** : 0,34 Go libres et fichier d'échange au maximum. Une compilation ou un test supplémentaire peut
   échouer ou bloquer le PC.

## Décisions attendues de votre part

- Produits « plateforme » : réels ou retirés ?
- Écrans 150-1, 150-4, 275, A2, P4, 250b, S1 : à relier ou à garder comme maquette ?
- Notifications push, e-mail et SMS : dans le périmètre du lancement ?
- Textes juridiques (confidentialité, conditions) : à fournir.
- Lancement **Web seulement** (recommandé) ou Web et mobile ?

## Conditions nécessaires au lancement public (dans l'ordre)

1. **Libérer de l'espace** sur C: (voir l'audit de stockage) avant toute compilation.
2. **Appliquer la migration** `20261101000000` (autorisation) et **déployer le site** (`6364a6d`, `04a0dbd`), puis rejouer les tests
   Playwright de production.
3. **Créer un compte administrateur et un compte support réels** (vous).
4. **Renouveler les clés Notch Pay**, puis **un paiement sandbox de bout en bout** avec webhook signé, rejeu et paiement tardif
   (rapport 07 §4).
5. **Une remise réelle** au kiosque (compte support).
6. **Tester le mot de passe oublié en ligne** avec une adresse réelle.
7. **Nettoyer** les comptes `zz-test`.
8. Remplacer l'affichage d'exemple des écrans de mission et de concours (P1), ou les retirer du parcours public jusque-là.
9. Mettre en place une supervision minimale et vérifier les sauvegardes Supabase.
10. Publier les textes juridiques.

## Prochaine action prioritaire

**Libérer de l'espace disque**, puis, avec votre autorisation, **appliquer la migration `20261101000000` et déployer les deux commits**
pour mettre en ligne les corrections, notamment le mot de passe oublié réel et la fin des faux succès. Ensuite viendra le
renouvellement des clés Notch Pay et le paiement sandbox.
