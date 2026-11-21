# H8 · Validation connectée : ce qui a été exécuté, préparé ou est impossible

État au 21 novembre 2026, commit de départ `04a0de87`. Aucune validation connectée (Supabase réel ou de test avec de vraies sessions) n'a été exécutée en H8.

## Exécuté (preuves locales, sans serveur Supabase)

| Niveau | Outil | Ce que cela prouve | Ce que cela ne prouve pas |
|---|---|---|---|
| SQL | 77 scénarios PGlite (`supabase/tests/marketplace_pglite/*.mjs`), 4 827 contrôles OK, 0 échec ; 239 fichiers de migration rejoués sur base vierge | logique des fonctions, RLS, gardes par rôle et permission, isolation entre comptes, cloisonnement des départements (`h7_cloisonnement`), 2FA, commissions non appliquées (`h8_commissions`) | comportement sur les données réelles de production, JWT réels, PostgREST, Edge Functions, e-mails |
| Flutter | faux serveur HTTP local (`test/helpers/fake_supabase.dart`) exerçant le vrai client Supabase et `Backend.*` | absence de données de maquette en connecté (états muet, vide), erreurs honnêtes, déconnexion et changement de compte sans état hérité (`h7_isolation_comptes`, `h8_sources_propres`), échecs d'écriture sans fausse confirmation (`h8_ecritures_500`) | persistance réelle en base, notifications réellement émises, réseau réel |

## Tentative de Supabase local (non aboutie)

Docker Desktop a pu être démarré sur ce poste après réparation de dossiers de sockets corrompus (`%LOCALAPPDATA%\Docker\run`), mais `supabase start` a échoué : délais dépassés vers le registre `docker.io` (image gotrue), mémoire libre inférieure à 1 Go et disque inférieur à 4 Go libres sur C:. Aucun conteneur Supabase n'a tourné. Docker a ensuite été arrêté et les dossiers de travail supprimés. Aucun script de validation connectée n'a été écrit en H8 : rien d'exécutable n'est fourni ici, pour ne pas laisser croire à un outil testé.

## Ce qu'il faut pour exécuter la validation connectée

1. Un environnement Supabase de TEST jetable (projet dédié, ou `supabase start` sur une machine avec au moins 8 Go de RAM libres et 15 Go de disque), jamais la production.
2. Les 238 migrations appliquées sur cet environnement (les 201 de production puis les 37 en attente, voir `H7_PLAN_PRODUCTION.md` §0).
3. Des comptes de test créés par l'administrateur avec l'écran « Comptes de test » (fonction `admin-test-accounts`, lien à usage unique) : un administrateur global, un agent par équipe (Finance, Support, Sécurité, Technique) avec ses permissions attribuées explicitement, un compte Département rattaché à un département vérifié, un second compte Département d'un autre département, un compte Direction, un compte client, un étudiant éligible vendeur (vérifié, téléphone vérifié) et un étudiant non vendeur, une organisation par type (8).
4. Le scénario pas à pas : `H7_SCENARIOS_VALIDATION_CONNECTEE.md` (112 étapes, six parcours, avec le test local qui couvre chaque étape).
5. Paiements : sandbox Tara/MoMo uniquement ; aucun transfert réel.

## Impossible à valider depuis cet environnement

SMS/OTP réel, paiements Tara, MoMo et Notch Pay (même en sandbox : clés absentes), Kéla (clé API absente), e-mails réels, TOTP, stockage de fichiers réel, notifications push sur un appareil, exécution sur appareil ou émulateur Android, tout ce qui touche iOS (macOS et Xcode requis).

## Statut par niveau

| Niveau | État |
|---|---|
| Implémenté | oui, six parcours |
| Testé localement (faux serveur et PGlite) | oui |
| Validé en conditions connectées | non |
| Prêt pour la production | non : voir `H7_PLAN_PRODUCTION.md` (sauvegarde, répétition sur copie restaurée, dry-run) et les décisions de `H8_DECISIONS_PROPRIETAIRE_SEPAREES.md` |
| Déployé | non |
