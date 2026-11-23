# 05 — Tests complets et validation fonctionnelle

> Date : 01/11/2026. Lieu d'exécution indiqué pour **chaque** résultat :
> - **L** = local (code du dépôt, tests Flutter) ;
> - **R** = réplique locale isolée (Docker `supabase_db_boutik_local`, 16 migrations, jamais la production) ;
> - **P** = production (lecture seule ou trafic intercepté).
>
> Aucune donnée n'a été créée en production.

## 1. Tests Flutter (L)

| Commande | Résultat | Preuve |
|---|---|---|
| `flutter analyze --no-pub` (après corrections) | **0 erreur, 0 avertissement**, 21 informations (25 avant : −3 avertissements, −1 import redondant) | `donnees/flutter_analyze_apres.txt` |
| `flutter test --no-pub --concurrency=1` (suite complète, après les corrections des écrans et des modules) | **405 / 405** (= historique), dont les **315 goldens** inchangés | `donnees/flutter_test_1.txt` |
| Nouveaux tests `test/purchase/finalisation_20261101_test.dart` | **16 / 16** | `donnees/flutter_test_finalisation.txt` |
| Régression ciblée après les derniers ajustements : `test/account` (14) et `test/purchase/hackathon_test.dart` (3) | **14 / 14** et **3 / 3** | `donnees/flutter_test_account.txt` |
| **Total des tests Flutter du dépôt** | **421** (405 historiques + 16 nouveaux), tous réussis | — |

Les 16 nouveaux tests couvrent :
- les brouillons : enregistrement, rechargement, reprise par le formulaire, effacement après envoi et à la déconnexion ;
- l'absence de faux succès sur les écrans 64, 110, 164, 165, 167 et 192 ;
- le mode « serveur joignable » :
  - aucun paiement de séquestre simulé ;
  - dépôt et note du jury expliqués ;
  - classement sans équipe fictive ;
  - compteurs de signalements exacts ;
  - réinitialisation par SMS refusée ;
  - nouveau mot de passe refusé sans lien de récupération.

**Limite** : les branches qui appellent réellement Supabase (envoi de l'e-mail de réinitialisation, `updateUser`, lecture des comptes
et des signalements) ne sont **pas** testables sans serveur dans les tests Flutter. Elles sont couvertes, pour la partie serveur, par
les tests SQL (§3) ; le parcours de bout en bout reste à faire **après déploiement**.

## 2. Tests backend sur la réplique locale (R)

| Suite | Résultat (01/11) |
|---|---|
| `lots_rest.py` (missions, propositions, affectations, jalons, vœux, campagnes, projets, lives, certificats, bornes) | 77/77 |
| `lots2_rest.py` (paramètres, fichiers, dossiers, liens de CV, codes de retrait, messagerie de mission, invitations) | 59/59 |
| `security_31_rest.py` (codes de retrait, 5 essais, journal, pièces jointes d'autrui, droits) | 24/24 |
| `quotes_rest`, `listings_stock_rest`, `feedback_rest`, `messaging_rest`, `chat_attachments_rest`, `seller_orders_rest`, `engagements_rest`, `conversations_list_rest`, `favorites_rest`, `mfa_rest` | 31, 40, 32, 31, 30, 18, 18, 9, 9, 8 — tous complets |
| **Total `run_all_local.py`** | **386 / 386** (`donnees/rest_local_run_all.txt`) |

## 3. Nouvelle migration `20261101000000` (R, transaction annulée)

`outils/test_migration_20261101_replique.sql` : la migration est appliquée **dans une transaction terminée par `ROLLBACK`**. Les rôles
sont simulés comme le fait PostgREST (`role` et `request.jwt.claims`). **20 / 20 contrôles réussis**
(`donnees/test_migration_20261101_replique.txt`) :

| Cas | Résultat |
|---|---|
| T1 client → `admin_set_account` | refusé |
| T2 admin change un rôle ; T2b journal d'audit | accepté et journalisé |
| T3 suspension : profil suspendu, `banned_until` = 2999, **0 session restante** | conforme |
| T4 réactivation : `banned_until` levé | conforme |
| T5 modification de soi ; T6 rôle `visitor` | refusés |
| T7 dernier administrateur actif | protégé |
| T8 / T8b anonyme | « permission denied » sur les deux fonctions |
| T9a client → `set_report_status` | refusé |
| T9b support lit le signalement (RLS) ; T9c passe en traitement ; T9d statut invalide ; T9e journal | conforme |
| T10a admin voit tous les profils (84) ; T10b client voit 1 profil | RLS conforme |
| T11 département → administration des comptes | refusé |
| T12 après `ROLLBACK` : fonctions et données de test absentes | réplique inchangée |

## 4. Navigation (P, historique du 31/10, déploiement inchangé depuis)

Playwright sur le site en ligne, en lecture seule : `visiteur.spec.ts`, 12/12, et `retrait_en_ligne.spec.ts`, 1/1 (trafic Supabase
intercepté). Ils couvrent :
- le chargement sans erreur JavaScript ;
- l'accès sans inscription ;
- « Mes rubriques » ;
- la page 404 neutre pour un visiteur ;
- l'écran inexistant ;
- 5 tailles d'écran ;
- le rechargement et le retour arrière.

Ils ne sont **pas rejoués aujourd'hui** : le site en ligne n'a pas changé, puisque les corrections ne sont pas déployées. Les rejouer
n'aurait rien prouvé de plus.

**Non exécutés** :
- les tests Playwright locaux (`lots`, `lots2`, `retrait`) exigent `flutter build web`. Avec **0,34 Go libres** sur C: et un fichier
  d'échange monté à 48 Go pendant la suite Flutter, la compilation dart2js (plusieurs Go de mémoire) risquait de **saturer le disque**.
  Ils sont reportés après libération d'espace ;
- les autres tests Playwright de production créent des comptes `zz-test` : ils sont interdits.

## 5. Paiements Notch Pay

| Contrôle | Statut |
|---|---|
| Code `pay` : refus des commandes annulées, montant et référence vérifiés, pas de double paiement, statut relu chez Notch Pay | revue de code (31/10) ; tests Deno 16/16 (historique, R) |
| Webhook : HMAC `x-notch-signature` en temps constant, anti-rejeu (empreinte du corps), paiement tardif après annulation refusé et journalisé | tests 21/21 (historique, R) ; POST non signé → 401 (historique, P) |
| `payment_events` en production | **0 événement** (lecture seule du 01/11) : aucun paiement réel ni sandbox n'a jamais été reçu |
| Secrets présents (noms seulement) | `NOTCHPAY_KEY`, `NOTCHPAY_HASH`, `MCP_ACCESS_KEY` présents ; `NOTCHPAY_API` absent mais facultatif (valeur par défaut `https://api.notchpay.co`) |
| **Paiement sandbox complet, webhook signé réel, parcours authentifié, MCP avec la vraie clé** | **NON RÉALISÉS** : clés exposées à renouveler d'abord ; aucune autorisation de paiement. Procédure prête : rapport 07 §4 |

## 6. Retraits

| Exigence | Où | Résultat |
|---|---|---|
| Génération du code (cryptographiquement sûre, 31c) | R | `security_31_rest` 24/24 |
| Nombre d'essais, blocage après 5 essais, journal des essais | R | idem |
| Interface : jamais « Remise confirmée » sans réponse `delivered` ; délai de 20 s ; erreur réseau, 401, 403, 500 ; double clic | P (serveur intercepté, 31/10) et L (`retrait.spec`, historique) | conforme |
| Annulation : pas de remise d'une commande annulée | R (`lots2_rest`) | conforme |
| Prévention des doubles remises | R | conforme |
| **Remise réelle** | — | **non réalisée** (commande payée et compte support requis, autorisation) |

## 7. Tests échoués

Aucun échec dans les résultats finaux. Échecs intermédiaires, corrigés, et tous dus aux tests eux-mêmes :
- un test de l'écran 164 touchait des coordonnées décalées par le centrage de l'écran ; il touche désormais le libellé « Message » ;
- deux scripts PowerShell d'édition ont été interrompus avant toute écriture (vérifié par `git diff` vide).
