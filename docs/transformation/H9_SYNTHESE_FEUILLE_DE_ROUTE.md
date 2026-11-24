# H9 · Synthèse stratégique, feuille de route et traçabilité

Date : 23 novembre 2026. Point de départ : HEAD `90f48686` (branche `cursor-travail`). Ce document est l'index des livrables H9 ; il ne remplace pas les matrices. Il ne présente comme « opérationnel » que ce qui a une chaîne complète (écran → `Backend.*` → RPC/table SQL avec droits → effet) **et** une preuve ; tout est prouvé **en local** (PGlite, faux serveur Flutter), **aucune validation connectée** n'existe.

## 1. Livrables

| Document | Contenu |
|---|---|
| `H9_MATRICE_A_COMMERCE_FINANCE_CONFIANCE.md` | 356 exigences : acteurs, univers, marketplace, FinTech, passeport/certification, bornes |
| `H9_MATRICE_B_TALENTS_EVALUATION_ENTREPRISES.md` | 186 exigences : talents, évaluation, entreprises/missions, learning |
| `H9_MATRICE_C_SOCIAL_IA_INNOVATION.md` | 283 exigences : réseau social, lives, Kéla Translate, innovation/PI, axes §15, Kéla AI |
| `H9_MATRICE_D_PLATEFORME_SECURITE_QUALITE.md` | 344 exigences : réseau institutionnel, intégrations/API, UX/langues, architecture, sécurité, qualité, déploiement, indicateurs |
| `H9_FOURNISSEURS_EVALUATION.md` | comparaison de 26 plateformes d'évaluation et 18 fournisseurs d'entretiens IA, architecture multi-fournisseurs, coûts, risques |
| `H9_STRATEGIE_PARCOURS_INDICATEURS_RISQUES.md` | 10 parcours, 71 indicateurs (+12 anti-gaming/équité), 35 risques, 25 décisions |
| `H8_DECISIONS_PROPRIETAIRE_SEPAREES.md` | les 19 décisions financières (réponse du 21/11 : garder les valeurs actuelles) |

## 2. Traçabilité : comptage global

Chaque ligne des matrices porte : ID, exigence, section du cahier des charges, état, preuves (fichiers, fonctions, tests), tâche restante, tests nécessaires, preuve de validation requise.

| Matrice | Exigences | OP | PART | NV | MANQ | EXT | DEC |
|---|---|---|---|---|---|---|---|
| A | 356 | 136 | 113 | 11 | 69 | 15 | 12 |
| B | 186 | 25 | 70 | 0 | 86 | 3 | 2 |
| C | 283 | 37 | 101 | 9 | 126 | 7 | 3 |
| D | 344 | 60 | 128 | 49 | 59 | 44 | 4 |
| **Total** | **1 169** | **258** | **412** | **69** | **340** | **69** | **21** |

Lecture : environ 22 % des exigences sont opérationnelles **en local**, 35 % partielles, 29 % absentes ; 0 % validées en conditions connectées. Les lignes de la section 5 de la matrice A qui renvoient aux matrices B, C ou D reprennent leur état à titre indicatif : le total compte donc certaines exigences deux fois (la somme surestime légèrement le nombre d'exigences distinctes). Les états sont ceux relevés à la lecture du code au 23 novembre ; la matrice B a été mise à jour pour le socle d'évaluation (voir §5).

## 3. Dépendances entre modules (ordre imposé)

1. **Environnement de test + application des migrations en attente + CI** : prérequis de toute validation connectée. Aujourd'hui, un seul projet Supabase existe (la production) ; aucune CI.
2. **Décisions du propriétaire** (CDC §30) : règles financières, prix des évaluations, fournisseurs, textes juridiques. Elles conditionnent paiements, évaluations payantes, commissions, séquestre, remboursements.
3. **Paiements sandbox réels** (Notch Pay, Tara, MoMo : jamais appelés avec succès) → rapprochement → missions par jalons, billetterie, financement de projets, cadeaux de live, ressources numériques payantes.
4. **Livraison numérique sécurisée** (absente) → ressources numériques, Knowledge Marketplace, Virtual Labs, licences.
5. **Modèle de compétences structuré** (`talent_skills`, expériences, formations) → skill graph → matching explicable → Team Builder → Career Twin.
6. **Fournisseurs d'évaluation** (aucun intégré) → évaluations réelles → résultats dans le passeport → matching et Talent Cloud.
7. **Clé IA (Kéla)** → agents spécialisés → assistant business, assistant de contenu, Career Coach.
8. **LiveKit + fournisseur de traduction/STT/TTS** → lives privés/événementiels, replay, Kéla Translate.
9. **Multi-tenant institutionnel** (aujourd'hui une seule ligne `institution_settings`) → réseau interinstitutionnel, direction par établissement.

## 4. Feuille de route priorisée

**Priorité 0 : fiabiliser et prouver (avant toute nouvelle ambition)**
- Environnement de test jetable ; application contrôlée des migrations en attente (plan : `H7_PLAN_PRODUCTION.md`) ; validation connectée des six parcours (112 étapes, `H7_SCENARIOS_VALIDATION_CONNECTEE.md`).
- Android : lancement sur appareil réel, notifications push ; iOS : environnement macOS/Xcode.
- Analyse réglementaire des fonds détenus (CEMAC/BEAC) : le code détient déjà des fonds (séquestre, soldes, versements) sans analyse documentée ; décision et confirmation écrite des règles financières.
- Clés externes à obtenir par le propriétaire : Kéla, LiveKit, paiement sandbox, FCM/APNs.

**Priorité 1 : valeur commerciale directe**
- Évaluations de compétences : valider le socle (`20261125095000` et suivantes), choisir 1 à 3 fournisseurs pilotes (étude `H9_FOURNISSEURS_EVALUATION.md`), test sandbox réel, adaptateur serveur par fournisseur, écrans organisation (campagnes financées).
- Paiements sandbox complets par prestataire + rapprochement réel (le journal financier marque aujourd'hui les encaissements « rapprochés » par défaut : à corriger après décision 13).
- Matching et recherche de talents sur les compétences structurées et les preuves (aujourd'hui sur du texte libre).

**Priorité 2 : différenciation**
- Ressources numériques (livraison sécurisée, licences) ; certificats signés avec page publique de vérification ; passeport Talent 360° ; Enterprise Talent Cloud rattaché à l'organisation ; Mission Workspace (historique, objectifs, plusieurs participants).
- Kéla : clé IA, outils, contexte autorisé, journal d'actions ; Kéla Translate (choix de fournisseur + consentement vocal).

**Priorité 3 : expansion**
- Lives privés/événementiels, replay, Creator Studio et analytics ; passerelle API Developer Hub (clés existantes, aucune passerelle) ; langues (2 sur 6) ; hors-ligne ; multi-tenant institutionnel ; Virtual Labs ; bornes (projets, talents, événements) ; axes §15 (spécification avant développement).

## 5. Innovations à plus fort potentiel (jugement qualitatif, sans donnée de marché)

Classement fondé sur : lien direct avec un revenu possible, dépendances déjà levées, différenciation, risque.
1. **Évaluation de compétences multi-métiers + Talent Cloud/matching explicable** : financement possible par les organisations ; couverture non limitée à l'informatique ; dépend de fournisseurs externes et du coût de la gratuité mensuelle (décision du propriétaire).
2. **Marketplace + ressources numériques** : cœur transactionnel ; bloqué par les paiements réels et la livraison numérique.
3. **Missions par jalons avec paiements** : lien entreprises-talents ; bloqué par les règles financières (jalons 30/40/30 codés en dur dans `_mission_accept`, décision 16).
4. **Passeport/certificats vérifiables** : confiance ; aucune dépendance externe lourde.
5. **Kéla Translate** : portée internationale ; dépend d'un fournisseur et du consentement vocal.
6. **Lives commerce/replay** : dépend de LiveKit, jamais exercé.

## 6. Travail réalisé en H9 (code)

Socle **fournisseur-agnostique** d'évaluation (aucun fournisseur réel, aucun appel externe) :
- SQL : `20261125095000_h9_eval_socle_fournisseur_agnostique.sql` (33 familles de métiers, registre de fournisseurs vide, demandes, résultats normalisés, contestations, campagnes, RLS, quota d'une évaluation gratuite par étudiant et par mois consommé seulement quand un fournisseur **actif** accepte la demande, prix des évaluations supplémentaires lu dans `platform_settings 'assessment.extra_price'` : absent = indisponible, jamais inventé) ; migrations de complément `20261125096000+`.
- Flutter : écran étudiant « Évaluations » (`/evaluations`), écran admin « Fournisseurs d'évaluation » (`/admin/evaluations`, permission `tech.integrations`), entrées de menu.
- Tests : `h9_evaluation.mjs`, `h9_evaluations_test.dart`.
- **Non intégré** : aucun fournisseur, aucun paiement des évaluations supplémentaires, aucun test d'intégration enregistré (l'activation d'un fournisseur reste impossible depuis l'application sans adaptateur serveur).

## 7. Résultats des validations H9 (24 novembre 2026, exécutées sur ce poste)

| Validation | Résultat |
|---|---|
| Suite Flutter hors Golden (`flutter test -j 1 --exclude-tags golden`) | 7 874 OK, 1 échec : `h8_ecritures_500_test` (profil), fragilité de temps sous charge ; corrigé par attente active, test relancé seul : 5/5 OK. Je n'ai **pas** relancé la suite complète après ce correctif de test |
| Tests ciblés après les derniers changements (`h8_ecritures_500`, `h9_evaluations`, `act_h4`, `h6_centre`, `fin_k1`, `h8_generes_garde`, `h8_sources_propres`) | 103 OK, 0 échec |
| Goldens | 322/322 |
| `flutter analyze` | 0 erreur, 138 alertes (une seule nouvelle par rapport au socle de 137 ; aucune dans les fichiers de ce lot) |
| Scénarios SQL PGlite | 81 scénarios, 246 migrations rejouées sur base vierge : 5 316 contrôles OK, 0 échec ; scénarios concernés rejoués après renumérotation d'une migration (voir ci-dessous) : 0 échec |

**Défauts trouvés par ces validations et corrigés** :
1. **Régression de sécurité (cloisonnement des départements)** : `20261124050000_equipe_entreprise_offres.sql` recréait `opp_close` et `opp_my_posted` depuis leur définition d'avant H2, ce qui rendait de nouveau visibles les offres en attente de tous les départements et permettait à un département de fermer l'offre d'un autre. Corrigé par la nouvelle migration `20261125030000_h9_offres_cloisonnement_departement.sql` ; le scénario `h7_cloisonnement` contrôle maintenant aussi `opp_close` (193 OK, 0 échec ; échec prouvé sans la migration).
2. **Scénario `etu_s8`** : il lisait deux établissements préchargés que le commit `90f48686` a retirés ; il crée maintenant ses propres établissements (fixture de test, aucune attente modifiée) : 85 OK.
3. **Numéro de migration en double** : ma migration portait la version `20261125010000`, déjà prise par les invitations ; renumérotée `20261125030000` (aucune version dupliquée sur 246 fichiers).
4. **Plan de production** : le §0 affirmait à tort que les définitions recréées par `20261124050000` étaient inchangées ; corrigé dans `H7_PLAN_PRODUCTION.md` (§00).

**Non validé** : aucune validation connectée ; aucun fournisseur d'évaluation appelé ; Android non exécuté sur appareil ; iOS non compilé ; les migrations H9 ne sont pas appliquées en production.

## 8. Reste à faire pour le socle d'évaluation

UI Flutter pour les organisations (campagnes), la validation humaine et l'arbitrage des contestations ; reconnaissance de la permission `tech.assessments` dans le catalogue Dart (`admin_access.dart`) ; les 3 modes supplémentaires dans `evaluations.dart` ; adaptateurs serveur par fournisseur après test sandbox réel ; décisions du propriétaire : financement qui ouvre une campagne, durée de réutilisation (`assessment.reuse_days`), tarif des évaluations supplémentaires (`assessment.extra_price`), délai de réponse aux contestations, mode « léger » de la gratuité mensuelle (qui reviendrait à construire un évaluateur propre).

## 9. Alertes relevées pendant l'analyse

- **Migrations appliquées puis modifiées dans le dépôt** : le commit `90f48686` (décision du propriétaire) a retiré le préchargement des établissements/départements de `20261104000100` et `20261106000300`, déjà appliquées en production. La production en contient donc très probablement encore ; les bases neuves seront vides ; la somme de contrôle diverge. Une migration appliquée ne se rejoue pas : un nettoyage éventuel des données de production est une opération distincte, à décider. Autre risque d'ordre : les migrations d'invitations (`20261125010000` et `20261125020000`) seraient déjà appliquées en production sans les migrations H2 dont elles dépendent (`department_accounts`) : voir `H7_PLAN_PRODUCTION.md` §00.
- **Journal financier** : `finance_journal` marque toujours « rapproché » pour les encaissements, sans rapprochement avec un prestataire (écran 141, colonne « Rapproché »). Le propriétaire a répondu « garder l'actuel » à la décision 13 : le comportement est donc accepté, mais il reste trompeur pour un agent de finance.
- **Fournisseurs** : l'étude s'appuie sur des extraits de recherche, pas sur des pages officielles lues (accès bloqué) ; aucune disponibilité au Cameroun n'est vérifiée hors OpenAI, Anthropic et Google. Tout doit être revérifié avant décision.
- **Loi camerounaise 2024/017** : le transfert de données personnelles vers l'étranger y est soumis à autorisation ; qualification juridique nécessaire avant d'envoyer la moindre donnée réelle à un fournisseur étranger.
