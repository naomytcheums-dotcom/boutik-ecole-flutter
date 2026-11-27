# H13 — Protocole de validation connectée des cinq acteurs

Complète `H8_VALIDATION_CONNECTEE.md` et `H7_SCENARIOS_VALIDATION_CONNECTEE.md` (112 étapes pas à pas). Objectif : tester séparément Visiteur/Client, Étudiant-vendeur, Organisation, Responsable de département et Administrateur avec des **comptes de test autorisés**, sans toucher aux vrais profils ni aux données de production, sans transaction financière réelle.

## 1. Règles
- Les comptes de test sont créés par l'administrateur avec l'écran « Comptes de test » (fonction `admin-test-accounts`, lien à usage unique, journalisés dans `test_login_log`). Jamais de compte réel, jamais de numéro de téléphone réel.
- Environnement recommandé : un **projet Supabase de test** (mêmes migrations que la production). Si seul le projet de production est disponible, seuls les contrôles en **lecture seule** ci-dessous sont autorisés ; toute écriture (commande, publication, contact, classement) reste réservée au projet de test.
- Paiements : sandbox Tara/MoMo seulement (clés de test à fournir) ; aucun transfert réel.
- Les mots de passe des comptes de test sont passés par variables d'environnement, jamais écrits dans un fichier du dépôt.

## 2. Contrôle automatique en lecture seule (livré, exécuté)
`tool/connected/validate_actors.mjs` : appelle l'API REST avec les vraies sessions des comptes de test et vérifie les droits attendus (autorisé / refusé), sans aucune écriture.
```
$env:SUPABASE_URL='https://<ref>.supabase.co'; $env:SUPABASE_ANON_KEY='<clé publique>'
$env:TEST_CLIENT='client@test:motdepasse'; $env:TEST_STUDENT='...'; $env:TEST_ORG='...'; $env:TEST_DEPT='...'; $env:TEST_ADMIN='...'
node tool/connected/validate_actors.mjs
```
Un acteur sans compte est affiché **NON TESTE** (jamais OK). Exécuté le 25/11/2026 sur la production **sans compte** (clé publique seulement) : **Visiteur 11 OK, 0 échec** (classement public lisible, 7 fonctions privées refusées sans session, `profiles` non listable, code de certificat inconnu jamais valide). Les quatre autres acteurs : **non testés (aucun compte de test fourni)**.

## 3. Parcours en écriture à jouer sur le projet de test (checklist)
| Acteur | Parcours | Preuve attendue |
|---|---|---|
| Visiteur → Client | découvrir le catalogue et le Top 100 sans compte ; s'inscrire ; se connecter ; ajouter au panier ; passer une commande (sandbox) | bouton d'action invite à se connecter ; commande visible dans « Mes commandes » ; notification reçue |
| Étudiant-vendeur | demander le rattachement (filière) ; devenir vendeur ; créer une boutique et une annonce avec variantes ; vendre (commande sandbox payée) ; voir son score expliqué ; suivre un replay à 100 % ; passer une évaluation | stock décrémenté une seule fois ; points tracés (`my_talent_score_explain`) ; badge ; quota d'évaluation décompté seulement à l'acceptation |
| Organisation | découvrir un talent publié ; l'ajouter au vivier ; demander un contact/entretien ; créer une mission et suivre une proposition ; créer une campagne d'évaluation | le talent est notifié ; aucune identité de visiteur exposée ; isolation entre deux organisations |
| Responsable de département | valider un rattachement dans son périmètre ; lire les indicateurs de son département | refus hors périmètre ; aucun classement publié par lui |
| Administrateur | activer une règle de score (brouillon → actif) ; publier un classement (2FA) ; corriger ; traiter une contestation ; valider humainement une évaluation ; modérer | publication refusée tant que les règles/réglages manquent ; audit de chaque action |

## 4. Ce qui reste impossible sans éléments externes
SMS/OTP réels, e-mails réels, TOTP, paiements (même sandbox : clés absentes), notifications push sur appareil, enregistrement LiveKit/S3, fournisseurs d'évaluation (URL/clé/secret), exécution sur appareil Android, iOS (reporté).
