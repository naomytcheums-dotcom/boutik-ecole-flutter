# 08 — Tests et résultats

## Commandes réellement exécutées pendant l'audit
| Commande | Résultat |
|---|---|
| `flutter analyze` | « No issues found! » (183,5 s) |
| `flutter test` (suite complète) | **339 tests réussis, 0 échec** (code de sortie 0) |
| `flutter build web --release` | réussi (build précédent l'audit, même code) |
| Script d'inventaire des écrans (`scan.py`, lecture seule) | 315 écrans analysés ; 948 liens sortants ; 0 cible inexistante |
| Requêtes HTTP en lecture seule sur le site et l'API | voir 06 et 09 |

Non exécutés : lint spécifique au serveur (fonction `pay`), analyse des dépendances vulnérables, tests Android/iOS, tests de charge.

## Contenu de la suite (339 tests)
- 315 tests « golden » (un par écran) : empêchent les régressions visuelles, ne vérifient pas la logique.
- 1 parcours de démonstration de 24 écrans (`test/journey/demo_journey_test.dart`) : suit les liens Figma en mode test ; **le paiement est contourné en test** (`GAnim.enabled == false` dans `pay.dart`) et le compte administrateur est injecté : le test ne prouve ni le paiement réel, ni la connexion réelle.
- ~22 tests de logique métier sur l'état en mémoire (`test/purchase`, `test/account`) : achat, recherche/favoris, vendeur, validation, finance, audit, talents, hackathons, borne/missions, signalements.
- 1 test de textes (`screen_texts`).
- Tests de l'ancienne version archivés dans `test_legacy/` (non exécutés).

## Zones non couvertes
- Aucun test d'API ni de base de données (RLS, fonction `pay`) : AN-001 à AN-005 ne sont attrapés par aucun test.
- Aucun test d'intégration avec Supabase (connexion, inscription, commandes).
- Aucun test de la messagerie (envoi, pièces jointes), de la voix, des PDF.
- Aucun test de navigation arrière/onglets.
- Aucun test responsive/accessibilité.
- Les tests golden sont régénérés à chaque changement du générateur (`--update-goldens`) : un défaut visuel peut ainsi être « accepté » sans revue.

## Limites de l'environnement
Pas de compte de test ni d'environnement Supabase dédié aux tests négatifs ; pas de clé Notch Pay ; pas d'appareil Android/iOS ; pas d'accès aux journaux Vercel/Supabase dans cet audit.

## Stratégie de non-régression proposée (priorisée)
1. **Tests SQL/REST de sécurité** (AN-001, 003, 004, 005) sur un projet Supabase de test : deux comptes standard + un admin.
2. **Test d'intégration commande** : créer, payer (sandbox), vérifier `orders`, stock, reçu.
3. **Test E2E navigateur** (Playwright ou `integration_test`) : démarrage → connexion → achat → commandes, sans contournement de test.
4. **Tests de contrat** de la fonction `pay` avec réponses simulées du fournisseur (succès, échec, annulation, délai).
5. **Tests de persistance** : créer une annonce/un favori, recharger, relire.
6. **Tests de navigation** : retour, onglets, liens entrants (aucun écran métier orphelin).
7. **Tests de performance** : budget de poids (`main.dart.js` < 3 Mo compressé) et temps du premier affichage.

## Deuxième passe (29/10/2026, après correctifs P0/P1)
| Vérification | Résultat |
|---|---|
| `flutter analyze` | « No issues found! » (172 s) |
| `flutter test` | **339 tests réussis, 0 échec** (nombre inchangé) |
| `flutter build web --release` | réussi ; publié sur Vercel ; le bundle en ligne contient `log_audit` |
| Version de la fonction `pay` | confirmée par sondage CORS : une origine étrangère reçoit l'origine du site (l'ancienne version renvoyait `*`) |
| Test de sécurité en base (transaction annulée, aucune donnée conservée) | 7 contrôles : annonce insérée `approved` → `pending` ; auto-approbation refusée ; élévation de rôle refusée ; écriture directe `audit_log` refusée ; `log_audit` fonctionne (acteur issu du profil) ; insertion directe de commande payée refusée |
| Tests P0 précédents (compte jetable, supprimé ensuite) | élévation de rôle refusée ; création de profil admin refusée ; commande directe refusée ; `create_order` recalcule les montants ; ancien mot de passe admin → `user_banned` |
**Non exécutés (cause précise)** : rejeu de référence de paiement et sous-paiement (clé Notch Pay absente côté serveur : la fonction répond `not_configured`) ; cohérence du stock (le stock n'est pas décrémenté, AN-008 ouverte, rien à tester).
