# H9 — Fournisseurs externes d'évaluation des compétences et d'entretiens IA

**Étude comparative, architecture multi-fournisseurs et plan de validation** · Boutik-École · date de consultation des sources : **2026-11-23**

> **Statut de ce document : étude. Aucun fournisseur ci-dessous n'est intégré.** Aucune API n'a été appelée, aucun compte ni sandbox n'a été ouvert, aucun code ni migration n'a été écrit. Matrice : **EXT** (dépend d'un service externe) + **DEC** (décisions du propriétaire listées en §13). Aucune règle financière non décidée n'est appliquée : les prix de ce document sont des prix de fournisseurs, pas des tarifs Boutik-École.

---

## 0. Méthode, légende et limites de vérification

**Périmètre demandé** : CDC §7 (Talent Intelligence), §8 (Talent Assessment et AI Job Simulator : 33 familles de métiers en §8.1, modes en §8.2, gratuité 1 évaluation IA/étudiant/mois en §8.4, transparence/contestation/non-discrimination en §8.5, « une IA ne doit jamais prétendre certifier un geste technique qu'elle n'a pas réellement observé »), §21 (§21.5 : « Ne pas supposer qu'une API publique existe pour chaque fournisseur » ; §21.6 : documentation, OAuth, coûts, quotas, restrictions géographiques, protection des données, mode de test, statut réel).

**Limite majeure de la vérification (à lire avant tout)** : l'outil `web_fetch` et `curl` n'ont pas pu joindre les sites des fournisseurs (échec DNS/TLS lors de la session). **Tous les faits proviennent d'extraits renvoyés par un moteur de recherche web** (URL + date de crawl fournies par le moteur). Aucune page n'a été relue en entier, aucun PDF de contrat/DPA n'a été lu, et des extraits de tableaux de prix peuvent mélanger des colonnes. La « date de consultation » est le 2026-11-23 ; la date de crawl de l'extrait est donnée dans la table des sources (§13) quand elle est connue.

**Légende des faits**

| Code | Sens |
|---|---|
| **V** | Vérifié : extrait d'une page officielle du fournisseur ou d'un texte légal |
| **S** | Source secondaire (G2, Capterra, agrégateurs, blogs, cabinets) : indicatif, à re-vérifier |
| **NV** | Non vérifié : aucune source exploitable trouvée dans cette session |
| **NP** | Non publié : cherché, le fournisseur ne publie pas l'information (ex. « sur devis ») |

**Règles appliquées** : aucun prix inventé ; pas de conversion en XAF (taux non vérifié) ; tous les prix sont en USD sauf mention ; les prix G2/Capterra divergent parfois des prix officiels (exemples relevés : HackerRank 165 $/mois G2 vs 79 $/mois officiel ; TestGorilla 1 700 $/an G2 vs 215 $/mois officiel) : seul le prix officiel est retenu quand il existe.

**Constat transversal (vérifié par absence)** : **aucun** fournisseur étudié ne publie, dans les extraits obtenus, sa disponibilité au **Cameroun** ni son comportement sur les **accents d'Afrique francophone** (hors une mention marketing de Speechmatics, §5). Chaque « disponibilité Cameroun » ci-dessous est donc **NV** sauf OpenAI, Anthropic et Google (pays supportés, V).

---

## 1. Synthèse (résumé exécutif)

1. **Aucun fournisseur SaaS ne couvre à lui seul les 33 familles de §8.1.** Les plateformes « tout métier » (TestGorilla, Mercer Mettl, Testlify, Canditech, Vervoe) sont essentiellement des **QCM/études de cas/simulations** ; les plateformes de code (Codility, HackerRank, CodeSignal, HackerEarth, WeCP) ne couvrent que l'informatique/data.
2. **Métiers manuels et techniques (BTP, mécanique, électricité, soudure, plomberie, menuiserie, froid, agriculture…)** : aucune offre automatisée d'évaluation pratique n'a été trouvée. Ce qui existe : QCM de connaissances (SHL Mechanical Comprehension en français ; tests Mettl pour ingénieurs électrique/mécanique ; TestGorilla GD&T/SolidWorks) et **évaluation pratique par évaluateur humain** (NCCER, City & Guilds : via centres agréés, hors API, Cameroun/français **NV**). **Conséquence de conception : une IA/un QCM n'attestent jamais un geste ; le résultat doit porter la mention « théorie évaluée ; geste non observé » et un chemin de validation humaine/présentiel (CDC §8.2).**
3. **Compatibilité avec « 1 évaluation IA gratuite par étudiant et par mois »** : au prix unitaire public des SaaS (≈ 5 à 32 $ par candidat/évaluation, §8.1), la gratuité mensuelle universelle est **financièrement incompatible** avec un déploiement large (ex. 2 000 étudiants × 12 mois × 15 $ = 360 000 $/an, §11). Elle n'est tenable qu'avec des évaluations légères à coût marginal de l'ordre du centime (chaîne LLM/transcription, **mais** cela revient de fait à bâtir un évaluateur sur des rubriques Boutik-École : **décision DEC n° 1, §13**) ou avec un volume/tarif négocié, ou via des campagnes financées par des organisations.
4. **Protection des données** : la loi camerounaise n° 2024/017 (23 déc. 2024) soumet le **transfert de données personnelles vers l'étranger à autorisation préalable de l'Autorité** (art. 32) avec sanctions pénales (art. 69). Tout fournisseur hébergé hors Cameroun (c'est le cas de tous) impose donc un **dossier juridique avant production** ; l'état opérationnel de l'Autorité (création par décret, art. 53) est **NV**.
5. **AI Act** : l'évaluation/sélection de candidats relève de l'**Annexe III point 4(a) (haut risque)** ; l'**inférence d'émotions au travail/éducation est interdite (art. 5(1)(f))** → exclure tout produit à analyse d'émotion/d'expression faciale ou vocale. Hume AI (voix) est de toute façon **fermé** (13 nov. 2026).
6. **Top 3 recommandé pour un pilote (sous réserve des essais réels du §10)** :
   1. **TestGorilla** (évaluations tous métiers, API REST sur plan Plus, 10 crédits gratuits/mois sur plan Free sans API, DPA public, expérience candidat en français) ;
   2. **Mercer Mettl** (API signée + webhook de notation, hôte UE `api.mercermettl.eu`, tests techniques électrique/électronique/mécanique ; prix sur devis) ;
   3. **Willo** (entretien asynchrone vidéo/audio/texte à faible bande passante, API REST + webhooks, DPA et Trust Center publics ; prix publics secondaires 209–409 $/mois).
   Briques d'infrastructure à garder en réserve (pas des évaluateurs) : **Mistral** (UE, Voxtral, français), plus un repli **Anthropic/OpenAI/Google** (Cameroun listé).
7. **Architecture** : couche d'abstraction provider-agnostique (§9) : interface unique, registre par famille de métiers, routage/repli, schéma de résultat normalisé (compétences, critères, preuves, limites, recommandations, contestation), journal de quotas (gratuité mensuelle), consentement/réutilisation, journal et webhooks signés.

---

## 2. Familles de métiers (CDC §8.1) → modes d'évaluation réalistes

| Grappe | Familles §8.1 couvertes | Modes possibles (§8.2) | Fournisseurs candidats (statut) | Limite structurelle |
|---|---|---|---|---|
| **A. Numérique** | Informatique et développement ; Data et IA | Questions, exercices de code, simulations (« corriger un problème logiciel ») | Codility, HackerRank, CodeSignal, HackerEarth, WeCP, Adaface (APIs V) ; TestGorilla (tests code) | Informatique seule ; 10–32 $ par candidat ; coût incompatible avec gratuité universelle |
| **B. Tertiaire / gestion** | Finance et comptabilité ; Gestion et management ; Commerce et vente ; Marketing ; Communication et médias ; RH ; Droit et conformité ; Entrepreneuriat ; Éducation et formation ; Sciences et recherche ; Environnement ; Approvisionnement ; Logistique et transport | QCM, études de cas, simulations de poste, entretien oral/asynchrone | TestGorilla (catalogue 350+ tests ; V), Testlify (3 500+ tests ; V), Mercer Mettl, Canditech (500+ tests + simulations), Vervoe (simulations notées par IA), Adaface (compta/finance/Excel) | Surtout QCM ; qualité française variable (TestGorilla : « plus de 40 tests » traduits en français sur 350+) |
| **C. Techniques / manuelles** | BTP et génie civil ; Architecture et construction ; Mécanique ; Automobile ; Maintenance industrielle ; Électricité ; Électronique ; Électrotechnique ; Énergies renouvelables/solaire ; Soudure ; Plomberie ; Menuiserie ; Froid et climatisation ; Artisanat | QCM théorie (raisonnement mécanique, lecture de plans), **dépôt de preuves** (photos/vidéos/dossier) évalué par un humain, **validation humaine/présentiel** | SHL Mechanical Comprehension (FR ; pas d'API publique), Mettl (tests ingénieurs électrique/électronique/mécanique), TestGorilla (GD&T, SolidWorks) ; pratique : NCCER (EN/ES, USA), City & Guilds (centres agréés) | **Aucune évaluation pratique automatisée trouvée.** Le geste ne peut être certifié que par un humain qui l'observe (§8.2). Cameroun/français pour NCCER/City & Guilds : **NV** |
| **D. Agri / hôtellerie** | Agriculture ; Agro-industrie ; Hôtellerie et tourisme | QCM, études de cas, entretien ; pratique par humain | TestGorilla (test « Hospitality » cité en exemple, V) ; agriculture/agro : **aucun fournisseur vérifié (NV)** | Catalogue agricole spécifique **non trouvé** → validation humaine locale |
| **E. Langues** | transversal (français/anglais) | Test CEFR parlé/écrit | Hallo AI (CEFR ; 19 $/test, page 2024), TestGorilla (37 tests CEFR en 16 langues dont français) | Hallo : ne couvre pas les métiers |
| **F. Compétences comportementales / entretien** | transversal | Entretien oral/asynchrone IA | Willo, Ribbon, Spark Hire, Sapia.ai (chat), HireVue | Génériques ; pas de preuve d'accents camerounais ; scoring de traits = haut risque |
| **G. Autres métiers** | Autres métiers et spécialités | Questions + validation humaine | Catalogue extensible : le registre (§9) doit accepter une nouvelle famille sans modification structurelle (exigence §8.1) | — |

---

## 3. (a) Plateformes d'évaluation de compétences

Légende prix : **V**/**S**. Les « coûts unitaires » sont des calculs arithmétiques sur les prix cités ; ils ne sont pas des prix catalogue.

### 3.1 TestGorilla (existe encore : V)
- **API** : V — REST, authentification `Authorization: Token …`, invitation de candidat (`/api/assessments/<ID>/invite_candidate/`, option `no_email=true`), résultats, export PDF. **Plans Plus et External Recruitment uniquement.** Webhooks et SDK : **NP** dans les extraits ; white-label : S (le plan Plus « supprime la marque »), iframe : NP.
- **Prix** : V — Free 0 $/mois, 10 crédits/mois (1 crédit = 1 candidat) ; Core « à partir de 215 $/mois » (annuel) ; Plus « à partir de 520 $/mois » (annuel) ; nombre de crédits inclus Core/Plus : **NP** → coût unitaire **non estimable**.
- **Accès** : Free/Core en libre-service ; **l'API exige Plus (≥ 520 $/mois, ≈ 6 240 $/an d'engagement annuel)**. Un essai API sans abonnement Plus n'est donc **pas garanti** (NV).
- **Cameroun / langues** : Cameroun NV. Expérience candidat en français ; « la bibliothèque complète n'est disponible qu'en anglais ; plus de 40 tests sont proposés dans chacune des autres langues » (V) ; 37 tests CEFR en 16 langues dont français (V).
- **Données** : V — DPA public avec engagement de **zéro rétention chez les fournisseurs de LLM** et non-entraînement ; accord de co-responsabilité publié ; proctoring par captures caméra « non biométrique » (V). SOC 2 Type II : S. Localisation : NP.
- **IA/biais** : rapport de biais/AI Act : NP.
- **Couverture** : 350+ tests (V : exemples GD&T, SolidWorks, Hospitality) ; surtout QCM ; pas de pratique soudure/électricité (NV).

### 3.2 Mercer | Mettl (existe : V)
- **API** : V — clés publique/privée, signature HMAC (`ak`, `ts`, `asgn`), endpoints tests prêts à l'emploi, inscription de candidats (lien chiffré), résultats/rapports ; **webhook** `testGradedNotificationURL` ; hôtes `api.mettl.com` (Inde), **`api.mercermettl.eu` (UE)**, `api.mercermettl.com` (Chine) ; logo personnalisable via API. SDK et plan requis : NP.
- **Prix** : **NP (sur devis)**. S : Capterra « à partir de 25 000 $/an » (coding) ; ITQlick 3 000–15 000 $ la 1re année (équipe de 10, non sourcé) ; « 15 $ par tentative supplémentaire » (source unique, S). Hypothèse de calcul : 25 000 $/an ÷ 1 000 candidats = **25 $** ; ÷ 5 000 = **5 $** (scénarios, non des prix).
- **Cameroun / langues** : site en français (V) ; certains tests en français, ex. « Digital Readiness » (V) ; Cameroun NV ; présence Afrique générale (page mercer.com/en-za, V), Cameroun NV.
- **Données** : V — ISO 27001:2013, ISO 9001, « GDPR compliant », hébergement UE disponible (domaine `.eu` de l'API). DPA : NP.
- **IA** : proctoring assisté par IA et opérateurs humains (V, page FR) ; biais/AI Act : NP.
- **Couverture** : tests prêts à l'emploi par rôle, dont « Aptitude and Technical Test for Electrical / Electronics / Mechanical Engineers » (V) ; QCM, simulateurs de code, centre d'évaluation virtuel ; nombre total : NP.

### 3.3 SHL (existe : V)
- **API publique** : **NP** (aucune documentation développeur trouvée). Intégration ATS Greenhouse documentée (V, via champs personnalisés `shl_assessment_tag`, `shl_candidate_url`, `shl_overall_status`, `shl_reports_url`, `overall_score`) → une intégration directe par **partenariat** est plausible mais **non documentée publiquement (NV)**.
- **Prix** : NP ; S : 15–40 $ par candidat/assessment (assessing.ai) ; SelectHub 100–500 $ (S, écart important).
- **Langues** : V — *Verify Mechanical Comprehension (Semi-skilled Technical)* en français, français (Canada), allemand, néerlandais, anglais, portugais, chinois. Cameroun NP.
- **Conformité** : V — page officielle SHL sur l'AI Act (SHL déclare ses évaluations IA alignées sur les exigences « haut risque » et l'absence de rejet automatique ; report des obligations au 2 déc. 2027 mentionné) : **déclaration du fournisseur**, non auditée par nous. ISO 27001 (V, page de conformité). DPA/localisation : NP.
- **Couverture** : raisonnement mécanique (QCM : poulies, engrenages, leviers) → utile famille C **côté théorie seulement**.

### 3.4 Vervoe (existe : V)
- **API/webhooks** : « API et webhooks pour intégrations personnalisées » (V, site) ; détail : S (api-evangelist : webhook de rapport signé HMAC SHA-256 en-tête `Vervoe-Signature`, 14 événements) ; API réservée au plan **Enterprise** (S, G2).
- **Prix** : S (G2) — Pay & Go 19 $/mois (2 assessments, candidats plafonnés) ; Growth 250 $/mois ; Enterprise sur devis. Coût unitaire non calculable.
- **Données** : V — ISO 27001, AES-256, TLS 1.3, AWS avec **souveraineté US/UE/Australie** ; **audits annuels indépendants de biais** ; un modèle IA **par client** entraîné sur les notes manuelles du client.
- **Couverture** : tâches simulant le travail réel notées par IA (V) ; nombre de tests NP ; langues/Cameroun NP.

### 3.5 iMocha (existe : V)
- **API** : V — `developer.imocha.io` : tests, invitations (y compris en masse), rapports, Skills Intelligence API, callbacks ; authentification (section dédiée, détail non relu) ; pagination 100/requête. SDK NP.
- **Prix** : NP ; S : 5 000 $/an (SpotSaaS) ; 4 800 $/an pour 10 utilisateurs (ITQlick), incohérents entre eux.
- **Données/IA** : V — ISO 27001 et SOC 2 Type 2 ; fiche « Ethical & Responsible AI » : atténuation de biais sur 14 facteurs. DPA/localisation : NP. Langues/Cameroun : NP.

### 3.6 Harver (dont pymetrics) (existe : V)
- Outmatch devenu Harver (2021), pymetrics acquis (2022), **Symphony Talent acquis le 17 sept. 2026** (V). API REST v1.0 OAuth2 client-credentials, environnement de test `api.harver-test.com`, webhooks (S). Prix NP ; clientèle « volume hiring » entreprise. Audit de biais indépendant 2025 (BABL AI, loi NYC LL144 : race/genre seulement). **Couverture comportementale/soft skills, pas de compétences métiers.**

### 3.7 Plateformes de code (informatique seule)
| Fournisseur | Existe | API (V) | Prix officiels (V) | Coût unitaire calculé | Données |
|---|---|---|---|---|---|
| **HackerRank** | V | HTTP Basic, clé API ; 10 req/s ; webhooks NV | Starter 79 $/mois (60 tentatives/an) ; Pro 419 $/mois (360/an) | 948/60 = **15,80 $** ; 5 028/360 = **13,97 $** | DPA public (SCC), ISO 27001 |
| **Codility** | V | Token ; OAuth2 pour intégrateurs ; 500 req/h/utilisateur ; webhooks NV | dès 4 800 $/an (200–1 400 invitations) ; dès 800 $/mois (25–100/mois) | 4 800/200 = **24 $** ; 800/25 = **32 $** | SOC 2 Type II, ISO 27001, **hébergement UE ou US**, DPA |
| **CodeSignal** | V | GraphQL + webhooks (`companyTestSessionCreated`, `…Started`, `preScreenIntegrityReviewUpdated`…) ; auth NV | Build 79 $/mois (60 crédits/an) ; Grow 479 $/mois (420 crédits/an) ; crédit supp. 20 $ | 79×12/60 = **15,80 $** ; 479×12/420 = **13,69 $** par crédit (crédits/candidat NV) | NP |
| **HackerEarth** | V | API v4, en-tête `client-secret`, webhook `CANDIDATE_TEST_FINISHED` ; API sur plan Custom (S) | S (G2) : 99 $/mois (10 invitations) ; 399 $/mois (25) | 9,90 $ ; 15,96 $ (S) | NP |
| **WeCP** | V | API + Postman ; webhooks NV | 100 $ pour 10 crédits/mois ; crédit supp. 10 $ | **10 $** | NP |
| **Adaface** | V | API : S seulement | 180 $/an ; 500 $/an ; 900 $/an ; 3 000 $/an ; 1 crédit/invitation | prix du crédit NP | NP |
| **DevSkiller** | S | NV | NP ; S : 3 000–7 000 $/an | NV | NV (ne pas confondre avec « Devskills », société distincte rachetée par Alva Labs en 2022) |

### 3.8 Autres plateformes
- **Testlify** (V) : API REST + serveur de staging, notifications temps réel ; **API/webhooks sur plan entreprise**, add-ons intégrations/marque blanche **2 388 $ chacun** (plan standard) ; 3 500+ tests, 180 000+ questions ; plateforme en 16+ langues, **tests en 7** (français non confirmé) ; SOC 2 Type 2, ISO 27001, RGPD, stockage régional ; entretiens téléphone IA à 0,18 $/min. Prix de base : non lus dans l'extrait.
- **Canditech** (V) : Team 150 $/mois facturé annuellement pour **100 candidats** ; Pro 200 $/mois ; API « pour intégrations personnalisées » sur le plan supérieur (doc NP) ; 500+ tests, simulations (texte, vidéo, Excel, fichiers). Calcul : 150×12/100 = **18 $/candidat** si quota annuel (non confirmé) ; G2 (S) donne d'autres paliers (écart non résolu). Pro : ISO 27001.
- **Criteria Corp** (V existe) : API non documentée publiquement (intégrations ATS) ; prix NP, S : contrats annuels ≥ 12 mois, 30–60 $/test en starter ; raisonnement mécanique CMRA en français (Canada) (extrait mélangé, à reconfirmer).
- **eSkill** (V) : **racheté par Scaleworks le 18 juillet 2024** ; API NP (45+ intégrations ATS) ; S : dès 400 $/mois ; langues EN/FR/ES (S).
- **Talview** (V) : API GraphQL + **webhooks signés HMAC-SHA256** ; prix sur devis avec **engagement minimum ≈ 150–200 candidats** (V) ; hébergement US/Europe (Pays-Bas)/Australie, pas d'Afrique (V) ; surtout proctoring/examens, pas une bibliothèque de tests métier.
- **Hallo AI (hallo.ai)** (V existe ; l'identification avec le « Hallo AI » du CDC §21.5 est une hypothèse non confirmée) : tests de langue CEFR (« 100+ langues » vs « 50+ » selon pages : contradiction), entretiens IA « 100+ soft skills », prix **19 $/test (1–10 tests)** sur une page mise à jour en 2024 (V, ancienne), sur devis au-delà ; API/white-label : S (plan Business). Conditions : peut réutiliser des données désidentifiées pour entraîner ses modèles sauf restriction DPA (V). Données : SOC 2 Type 2, ISO 27001, RGPD (V).
- **Glider AI** (V : documentation API `hire.glider.ai/api`) : invitation `POST https://api.glider.ai/v2/assessments/:test_id/candidates`, callback de résultat (score, `report_url`, `skill_evaluation`) ; auth NP ; prix S (dès 299 $/mois, Capterra). Ne pas confondre avec « Glider » (glider.fi).
- **Arctic Shores** (S) : psychométrie par tâches, français ; API contradictoire selon les sources → non retenu. **Plum** (S) : **racheté par Phenom (annoncé le 28 avril 2026)**, psychométrie → hors périmètre.
- **VirtualAC** (**Talogy**, V) : assessment center virtuel de bureau (cols blancs, 45+ exercices), API NP → **ne convient pas aux métiers manuels**.
- **Liste du CDC §21.5** (HackerRank, CodeSignal, Codility, HackerEarth, TestGorilla, Canditech, eSkill, VirtualAC, Hallo AI) : les neuf existent encore (V ; eSkill racheté en 2024). API publique documentée trouvée pour HackerRank, CodeSignal, Codility, HackerEarth, TestGorilla ; **non trouvée (NP)** pour Canditech (mention seule), eSkill, VirtualAC et Hallo AI (S seulement).

### 3.9 Validation pratique / présentielle (familles C et D)
| Organisme | Nature | Éléments (statut) | Intégrable par API ? |
|---|---|---|---|
| **NCCER** (USA, construction) | Évaluations « Knowledge Verified » + « Performance Verified » par évaluateurs/centres | V : 36 à 50+ métiers (tuyauteur, électricien, chaudronnier, CVC, plombier) ; surveillées ; anglais, quelques métiers en espagnol ; **français NP** ; prix S (centres US : 175–275 $ ; écrit+pratique 550 $) | **NP** |
| **City & Guilds** (UK) | Qualifications professionnelles via **centres agréés** (évaluations pratiques) | V : processus d'approbation de centre ; S : centres au Nigeria (ingénierie, plomberie, maçonnerie) ; **Cameroun NV** | **NP** |
| **Pearson VUE / Prometric** | Livraison d'examens (centre/en ligne surveillé) pour propriétaires d'examens | V existence ; centres au Cameroun : S seulement (sites tiers) ; ce ne sont pas des bibliothèques de tests métiers | NP |

→ **Conclusion** : pour la famille C, le registre doit contenir un **fournisseur interne de type « validation humaine »** (enseignants IUT, évaluateurs, centres partenaires) et non seulement des API.

---

## 4. (b) Entretiens vidéo / oraux par IA

| Fournisseur | Existe ? | API / webhooks / white-label | Prix publics | Français / Afrique | Données / IA | Verdict |
|---|---|---|---|---|---|---|
| **HireVue** | V | REST + webhooks via `developer.hirevue.com` pour clients/partenaires certifiés (S) ; auth/SDK/white-label NV | **Sur devis** (S) ; pas de free tier | « French, English, Spanish, Portuguese… » (V) ; accents/Cameroun NP | GDPR/CPA cités (V) ; **analyse faciale retirée en 2021** + audit ORCAA (V) ; haut risque Annexe III 4(a) (S) | Marché entreprise/volume ; hors budget de démarrage |
| **Hume AI** | Entité oui ; **EVI et TTS fermés le 13 nov. 2026** (V, changelog) | Expression Measurement : accès limité sur contact (V) | NP | EVI 11 langues (S, produit disparu) | Mesure d'expression émotionnelle → **interdit en recrutement UE (art. 5(1)(f))** | **Exclu** |
| **Sapia.ai** | V | REST ; régions APAC/US/**EMEA (eu-west-1)** ; webhooks (l'URL ne doit pas exiger d'authentification : V) ; auth/SDK/white-label NV | Par embauche, tarif NP | Chat en anglais, espagnol, **français**, etc. (V) ; Cameroun NP | UE avec stockage local (V, page 2022) ; **conservation indéfinie de données anonymisées pour entraîner les modèles (V)** ; SOC 2/ISO 42001 (S) | Conçu > 500 embauches/an ; vigilance rétention |
| **Willo** | V | API REST V2, clé dans `Authorization`, staging ; webhooks New Response / Stage Change / New Comment / New Score (V site + S détail) ; OpenAPI formelle réservée Enterprise (S) | S : Growth 279 $/mois (209 $ annuel), Scale 409 $/mois (307 $ annuel), Enterprise devis | 18 langues, page FR, réponses vidéo/audio/texte, **faible bande passante** (V) ; accents : N/A (asynchrone) | RGPD, **DPA publié**, Trust Center, rétention 6 mois–10 ans, AES-256, sous-traitants IA sans entraînement (V) ; localisation NP | **Retenu pour pilote** |
| **Spark Hire** | V | `docs.sparkhire.com` : utilisateurs, jobs, entretiens `one_way`/`live` ; accès API activé par compte ; auth/webhooks NV | V : dès **249 $/mois**, entretiens illimités | Transcriptions 50+ langues dont français (V) ; **scoring IA de traits : anglais seulement (V)** | Hébergement **US**, SCC, Data Privacy Framework (V) ; scoring de traits = profilage | Alternative ; scoring à désactiver |
| **Ribbon AI** | V | `docs.ribbon.ai` : clé Bearer, flows d'entretien, lien de session unique, révocation d'accès aux enregistrements, serveur MCP (V) ; webhooks NV | V : Growth **499 $/mois** (100 entretiens/mois inclus, dépassement 4 $/entretien) ; G2 (S) : Business 999 $/mois | 12 langues dont **fr-FR** (V), pas de variante africaine | RGPD/DPA : NV | Meilleur prix par entretien vérifié (≈ 5 $) mais données NV |
| **micro1 (Zara)** | V | `ai-recruiter.micro1.ai/llms.txt` : création d'entretien, clé API, webhooks de résultats (V) | S : dès 89 $/mois ; 399 $/mois | NP | **Se réserve l'entraînement sur données d'entretien désidentifiées (V)** ; analyses comportementales de proctoring | Non recommandé (données, profil ingénieurs) |
| **Tenzo** | V | API/webhooks « pour toutes les organisations » (V) ; natifs iCIMS/Workday (S) | NP (par « screens », paliers) | EN/ES/FR (S) | Mentionne des identifiants biométriques (V) ; DPA/UE NP | Volume/frontline ; devis |
| **Alex (alex.com, ex-Apriora)** | V ; **Apriora et Alex = même entité (S)** | `docs.alex.com` : webhooks `X-API-KEY`, suppression en masse (V) | S : contrats dès **36 000 $/an** | 26+ langues (S), liste NP | Données **UE stockées dans l'UE**, pas d'entraînement sur données clients (V) | Prix hors budget |
| **Jobma** | V | API : NV (tracker S) | Plans (montants non vus) ; ≈ 1 $/entretien (avis G2, S) | Transcription 67+ langues (V) | **Données aux États-Unis (GCP Iowa), conservation ≥ 1 an (V)** | Non recommandé (pas d'hébergement UE) |
| **Retorio** | V, **repositionné « AI sales coaching »** | API publique non trouvée | Par utilisateur, montant NP | 14 langues | UE (GCP, ISO 27001) ; **Big Five à partir du comportement vidéo = profilage** | Exclu (risque AI Act) |
| **Mercor** | V | Place de marché de talents/données IA ; API non publiée (S) | NP | NP | — | **Hors périmètre** (pas une brique d'entretien) |
| **Paradox (Workday)** | Racheté par Workday (finalisé oct. 2025, V communiqué janv. 2026) | NV | NP | NV | — | Hors périmètre (ATS conversationnel) |
| **Hallo AI / VirtualAC / Canditech / Talview** | voir §3 | | | | | |

---

## 5. (c) Briques LLM / voix / transcription — **options d'infrastructure, pas des fournisseurs d'évaluation**

> **Avertissement (DEC n° 1)** : utiliser un LLM pour **noter** des candidats selon des rubriques Boutik-École revient à fabriquer un évaluateur propre, ce que les consignes écartent (« intégrer des services externes »). Ces briques sont listées pour (i) alimenter un adaptateur d'un fournisseur externe qui n'a pas d'API de résultat normalisé, (ii) transcrire/traduire, (iii) **résumer, normaliser et expliquer** des résultats de fournisseurs, (iv) un éventuel mode « évaluation légère » **sous décision explicite du propriétaire**. Les politiques d'usage des éditeurs classent l'emploi comme domaine sensible : OpenAI et Google interdisent les décisions automatisées à fort impact (emploi, éducation) **sans revue humaine** (V) ; Anthropic impose une personne qualifiée en revue et l'information de la personne concernée pour les usages à haut risque (V/S) ; Mistral : texte emploi **NV**.

| Fournisseur | Prix publics (USD, V sauf mention) | Cameroun | Français / accents | Données | Notes |
|---|---|---|---|---|---|
| **OpenAI** | gpt-5.4-mini 0,75 / 4,50 $ par M tokens (entrée/sortie) ; gpt-5.4-nano 0,20 / 1,25 ; gpt-6-luna 0,10 / 0,50 ; `gpt-live-transcribe` 0,017 $/min ; Realtime audio 32/64 $ par M tokens ; Batch ≈ −50 % ; transcription ≈ 0,003–0,006 $/min (S) | **Pays supporté : V** | 99+ langues (S) ; accents africains NP | Pas d'entraînement sur l'API par défaut ; abus 30 jours ; ZDR sur approbation ; résidence UE sur approbation (S) | Structured Outputs JSON Schema (V) ; pas de SDK Dart officiel (REST) |
| **Anthropic (Claude)** | Haiku 5.5 0,10 / 0,50 $ (≤ 100k tokens) ; Sonnet 5.5 2 / 10 $ ; Batch −50 % | **Pays supporté : V** (maj 2026-11-12) | NP | Pas d'entraînement par défaut ; ZDR sur demande ; `inference_geo` : « us » ou « global » seulement (UE via Bedrock/Vertex) | Pas d'API voix/transcription |
| **Google (Gemini / Chirp)** | Gemini 3 Flash 0,50 / 3 $ (S) ; transcription ≈ 0,005–0,009 $/min (extrait partiel) | **Pays supporté : V** (Gemini API, maj 2026-10-22) | Chirp 3 : fr-FR, fr-CA ; **pas de fr-CM** vu | Services payants : pas d'amélioration produit ; DPA ; Vertex avec résidence UE ; **UE/EEE : Paid Services uniquement (V)** | SDK Dart : Genkit Dart / Firebase AI Logic |
| **Mistral AI** | Small 4 0,15 / 0,6 $ ; Large 4 : 0,7/2,1 (extrait) vs 1,36/4,18 (S) → **NV** ; Voxtral Mini Transcribe 0,0035 $/min ; Small 0,004 ; Realtime 0,008 | **NV** | Voxtral 13 langues dont français, ≈ 4 % WER FLEURS annoncé ; accents NP | DPA publié, sous-traitants (Trust Center), ZDR possible ; hébergement UE par défaut (S) ; SOC 2/ISO 27001 (S) | Option « UE/français » la plus cohérente |
| **ElevenLabs** | Scribe v2 0,20 $/h ; Realtime 0,22 $/h ; TTS 0,08 $/1 000 car. ; agents 0,08 $/min | NP | 90 langues (V) | SOC 2/ISO 27001/RGPD, résidence UE (S) | |
| **Deepgram** | Nova-3 0,0048 $/min (promo) ; streaming 0,29 $/h ; Voice Agent 0,075–0,163 $/min | NP | fr, fr-CA | **Programme d'amélioration des modèles actif par défaut** (`mip_opt_out=true` nécessaire) ; endpoint UE | |
| **AssemblyAI** | 0,15–0,21 $/h (S) | NP | 18 langues (S) | Non-entraînement sur comptes payants ; UE ; suppression 24-48 h (V) | |
| **Azure OpenAI / Speech** | GPT-Transcribe 0,27 $/h ; GPT-5.5 5/30 $ | NV | fr-FR, fr-CA | Pas d'entraînement ; abus-monitoring | |
| **Amazon Transcribe / Bedrock** | batch ≈ 0,006 $/min (exemple) | NV | NV | Pas de partage avec fournisseurs de modèles ; région Paris (S) | |
| **Speechmatics** | dès 0,12 $/h | NV | « African French (West and Central Africa) » listé sur page marketing, **sans WER publié** | NV | Seul fournisseur annonçant un français africain |
| **Whisper (open source)** | gratuit (MIT) + hébergement | n/a | benchmarks recherche sur langues africaines (S) | contrôle total | coût d'infra non estimable ; à tester sur voix locales |
| **Vapi / Retell / LiveKit** | ≈ 0,05 / 0,055 / 0,01 $ par min (S) + fournisseurs | NV | — | Retell : **pas de service dans l'UE** (V) | agents vocaux optionnels |
| **Supabase Edge Functions** | — | — | — | — | V : durée « wall clock » 150 s (gratuit) / 400 s (payant) ; CPU 2 s ; timeout de requête 150 s → **traitements asynchrones obligatoires** |

**Coût d'une chaîne type (hypothèse : audio 10 min ; 20 000 tokens entrée, 3 000 sortie ; calculs depuis les prix ci-dessus)** : transcription 0,025–0,060 $ + notation LLM 0,0035–0,095 $ → **≈ 0,04 $ (Voxtral Mini + Mistral Small : 0,035 + 0,0048)** à **≈ 0,155 $ (gpt-4o-transcribe + gpt-5.4)**. Entretien vocal **interactif** (temps réel/agent) : **non estimable de façon vérifiée**.

---

## 6. Données personnelles et encadrement réglementaire

### 6.1 Loi camerounaise n° 2024/017 du 23 décembre 2024 (texte hébergé par un site tiers ; Journal officiel non consulté)
- **Champ** (art. 2) : tout traitement de données de personnes établies, résidant ou en transit au Cameroun, ou par un responsable établi au Cameroun (V sur le texte, S sur l'hébergeur).
- **Consentement** préalable, libre, éclairé, spécifique, univoque (art. 9) ; **mineurs de moins de 18 ans** : accord d'un parent/représentant (art. 9) → à traiter pour les étudiants mineurs.
- **Autorisation préalable** de l'Autorité pour tout traitement (art. 19) et **registre des traitements** (art. 29) ; notification de violation (art. 22).
- **Transfert vers un État étranger** : **autorisation préalable de l'Autorité** (art. 32) ; sanction de **3 à 10 ans d'emprisonnement et 2 à 20 millions FCFA** (art. 69). Clauses contractuelles types publiées par l'Autorité.
- **Autorité** : « création par décret » (art. 53) ; **son fonctionnement effectif est NV** → qualification juridique obligatoire avant la production.
- **Conséquence** : tout envoi d'une voix/vidéo/réponse d'étudiant à un fournisseur hébergé hors Cameroun (tous) est un transfert transfrontalier. À gérer par : consentement par fournisseur affiché avant l'évaluation, minimisation (pseudonymes, pas de vidéo si un mode texte suffit), contrats/DPA, clauses types de l'Autorité, registre.

### 6.2 RGPD (applicable si une entité ou un destinataire UE est impliqué, ou pour l'extension internationale)
Éléments vérifiés par fournisseur : DPA publics (TestGorilla, HackerRank, Willo, Mistral, Codility), hébergement UE (Mettl `.eu`, Sapia EMEA, Alex UE, Codility UE/US, Vervoe US/UE/AU, Mistral UE par défaut S), hébergement US seul (Jobma, Spark Hire), **réutilisation des données pour entraîner** (micro1, Hallo, Sapia anonymisé, Deepgram par défaut : à refuser contractuellement).

### 6.3 EU AI Act
- **Annexe III point 4(a)** : IA pour recruter/sélectionner/évaluer des candidats = **haut risque** (S : regulatoryai.eu, euaiact.com).
- **Art. 5(1)(f)** : **interdiction d'inférer les émotions** d'une personne au travail et en éducation (sauf raison médicale/sécurité), en vigueur depuis le 2 fév. 2025, amendes jusqu'à 35 M€/7 % (S). Les lignes directrices de la Commission précisent que l'interdiction vise le déployeur même si le fournisseur l'exclut contractuellement (V, PDF Commission, d'après extrait) ; **l'inclusion de la phase de recrutement dans « workplace » est NV dans cette session** → à confirmer par un juriste ; prudence : exclure toute analyse d'émotion, de visage, de ton de voix.
- **Calendrier** : le « Digital Omnibus on AI » (Règlement (UE) 2026/1744, publié au JO le 24 juillet 2026 d'après un extrait EUR-Lex rapporté) reporterait les obligations Annexe III autonomes au **2 déc. 2027** (S : Gibson Dunn ; texte intégral non relu) : **NV à confirmer sur EUR-Lex**.
- **Applicabilité territoriale pour des candidats au Cameroun** : **NV** (dépend de l'établissement du fournisseur/déployeur et de l'usage des résultats dans l'UE). **Décision de conception : s'aligner par défaut** (supervision humaine, transparence, journalisation ≥ 6 mois (S), droit de contestation/explication, aucune décision automatisée d'embauche), car l'extension internationale et les recruteurs UE sont prévus (CDC §7).
- Qualification Boutik-École : **à valider par un juriste** — analyse non sourcée : si les scores servent à classer des candidats, Boutik-École est fournisseur/déployeur d'un système Annexe III, pas simple revendeur.

---

## 7. Tableau comparatif et notation

### 7.1 Critères et pondérations (0 à 5 ; la valeur 1 est attribuée par défaut à toute information non vérifiée — principe de prudence)

| Id | Critère | Poids | Barème |
|---|---|---|---|
| C1 | Couverture des métiers (§8.1, hors informatique) | 20 % | 5 = tous métiers y compris pratique ; 4 = catalogue large (QCM/simulations) incl. technique ; 3 = large mais partiel ; 2 = générique ; 1 = informatique ou psychométrie seule |
| C2 | API / white-label / webhooks | 20 % | 5 = API + webhooks + sandbox + embed documentés ; 4 = API + webhooks documentés ; 3 = API documentée sans webhooks ou sous conditions ; 2 = API mentionnée sans doc ; 1 = aucune API publique |
| C3 | Prix par évaluation compatible avec 1 gratuite/étudiant/mois | 20 % | 5 = < 0,5 $ ; 4 = 0,5–2 $ ; 3 = 2–10 $ ; 2 = 10–20 $ ou prix par plan élevé/incertain ; 1 = > 20 $ ou NP ; 0 = ≥ 36 000 $/an plancher |
| C4 | Disponibilité Cameroun | 10 % | 5 = officiellement listé et paiement possible ; 3 = non restreint par une source ; 1 = NV |
| C5 | Français | 10 % | 5 = natif complet ; 3 = partiel (une partie du catalogue/UI) ; 1 = NP |
| C6 | Protection des données | 10 % | 5 = DPA public + UE + non-entraînement + audits ; 3 = DPA ou certifications sans localisation ; 1 = NV ; ≤ 1 si réutilisation pour entraînement/US seul |
| C7 | Maturité (existence, doc, pérennité) | 10 % | 5 = leader établi, doc/prix publics ; 3 = établi, doc partielle ; 1 = incertain/repositionné |

### 7.2 Notes (fournisseurs d'évaluation et d'entretien)

Score = Σ poids × note. **Aucune note n'est une preuve de qualité d'évaluation : elle mesure l'adéquation d'intégration sur des faits vérifiés.**

| Fournisseur | C1 | C2 | C3 | C4 | C5 | C6 | C7 | **Score /5** | Justification brève |
|---|---|---|---|---|---|---|---|---|---|
| **Mercer Mettl** | 4 | 4 | 1 | 1 | 3 | 4 | 5 | **3,1** | API signée + webhook + hôte UE ; prix sur devis |
| **Willo** | 2 | 4 | 3 | 2 | 3 | 4 | 4 | **3,1** | Asynchrone/low-bandwidth, DPA public ; générique |
| **TestGorilla** | 4 | 3 | 2 | 1 | 3 | 3 | 5 | **3,0** | Catalogue large ; API seulement plan Plus ≥ 520 $/mois ; crédits NP |
| **Testlify** | 4 | 3 | 2 | 1 | 2 | 4 | 3 | **2,8** | 3 500+ tests ; API/white-label payants en options |
| **Vervoe** | 3 | 4 | 2 | 1 | 1 | 4 | 4 | **2,8** | Simulations IA, audits de biais ; API Enterprise |
| **Spark Hire** | 2 | 3 | 3 | 1 | 3 | 2 | 4 | **2,6** | 249 $/mois illimité ; scoring IA en anglais, hébergement US |
| **iMocha** | 3 | 4 | 1 | 1 | 1 | 3 | 4 | **2,5** | API + callbacks ; prix/langues NP |
| **Ribbon AI** | 2 | 4 | 3 | 1 | 2 | 1 | 3 | **2,5** | ~5 $/entretien ; données NV |
| **SHL** | 4 | 1 | 1 | 1 | 4 | 2 | 5 | **2,4** | Mécanique en français ; pas d'API publique |
| **HireVue** | 2 | 3 | 1 | 1 | 4 | 2 | 5 | **2,4** | Entreprise/devis |
| **Talview** | 2 | 4 | 1 | 1 | 1 | 4 | 4 | **2,4** | API + webhooks signés ; minimum 150–200 candidats |
| **Sapia.ai** | 2 | 3 | 1 | 1 | 3 | 3 | 4 | **2,3** | Région EMEA ; rétention indéfinie anonymisée |
| **Codility** | 1 | 4 | 1 | 1 | 1 | 4 | 5 | **2,3** | Informatique seule ; 24–32 $ |
| **HackerRank** | 1 | 4 | 1 | 1 | 1 | 3 | 5 | **2,2** | Informatique seule ; ≈ 14–16 $ |
| **WeCP** | 2 | 3 | 3 | 1 | 1 | 1 | 3 | **2,2** | 10 $/candidat ; surtout tech |
| **Canditech** | 3 | 2 | 2 | 1 | 1 | 3 | 3 | **2,2** | 18 $/candidat (hypothèse) ; API non documentée |
| **Hallo AI** | 2 | 2 | 2 | 1 | 2 | 3 | 3 | **2,1** | Langues CEFR ; 19 $/test (page 2024) ; entraînement sur données désidentifiées |
| **CodeSignal** | 1 | 4 | 1 | 1 | 1 | 1 | 5 | **2,0** | Informatique ; ≈ 14–16 $/crédit |
| **Harver** | 1 | 4 | 1 | 1 | 1 | 2 | 4 | **2,0** | Soft skills |
| **Criteria** | 3 | 1 | 1 | 1 | 3 | 1 | 5 | **2,0** | Pas d'API publique, contrats ≥ 12 mois |
| **Alex** | 2 | 3 | 0 | 1 | 2 | 4 | 3 | **2,0** | Plancher ≈ 36 000 $/an (S) |
| **Tenzo** | 1 | 3 | 1 | 1 | 3 | 2 | 3 | **1,9** | Volume/frontline ; prix NP |
| **eSkill** | 3 | 1 | 1 | 1 | 3 | 1 | 3 | **1,8** | Pas d'API publique ; racheté 2024 |
| **micro1** | 1 | 3 | 2 | 1 | 1 | 1 | 3 | **1,8** | Entraînement sur données d'entretien |
| **Jobma** | 2 | 1 | 3 | 1 | 1 | 1 | 3 | **1,8** | Données US seules |
| *Hume AI, Retorio, Mercor, Paradox, VirtualAC* | — | — | — | — | — | — | — | **exclus** | Fermé / profilage-émotion / hors périmètre |

**Lecture** : les scores tiennent dans une fourchette serrée (1,8–3,1) : **aucun fournisseur n'est satisfaisant sur tous les critères**, d'où l'architecture multi-fournisseurs. Ce que les notes ne disent pas : qualité psychométrique, validité prédictive, comportement sur voix camerounaises, légalité : à tester (§10).

### 7.3 Choix par rôle (recommandation)
| Rôle dans l'orchestrateur | Candidat n° 1 | Candidat n° 2 | Repli |
|---|---|---|---|
| Évaluation tous métiers (grappes B, C-théorie, D) | **TestGorilla** | **Mercer Mettl** | Testlify, Canditech, Vervoe |
| Entretien oral/asynchrone (grappe F) | **Willo** (asynchrone, faible débit) | Ribbon AI (données à documenter), Spark Hire (sans scoring de traits) | Sapia.ai (texte) |
| Code/data (grappe A) | WeCP (10 $/candidat, V) ou HackerRank (≈ 14–16 $) | Codility (UE/US) | CodeSignal, HackerEarth |
| Langues (grappe E) | TestGorilla tests CEFR | Hallo AI | — |
| Pratique (grappe C) | **Validation humaine interne** (IUT/évaluateur partenaire) | NCCER/City & Guilds via partenariat (Cameroun NV) | — |
| Transcription / résumé / traduction | **Mistral** (UE, français) | OpenAI / Anthropic / Google (Cameroun listé) | Whisper auto-hébergé (test accents requis) |

---

## 8. Cout unitaire et tarification interne

### 8.1 Coûts unitaires indicatifs (arithmétique sur prix publics ; **pas des tarifs Boutik-École**)
| Famille de coût | Valeur par évaluation | Fiabilité |
|---|---|---|
| Chaîne LLM + transcription (10 min d'oral, hypothèse §5) | 0,04 à 0,155 $ | Prix V, hypothèses de tokens non vérifiées |
| Entretien asynchrone Ribbon (inclus / dépassement) | ≈ 5 $ / 4 $ | V |
| WeCP | 10 $ | V |
| HackerRank / CodeSignal | ≈ 14–16 $ | V |
| Candidature type Canditech Team | 18 $ | V, quota annuel supposé |
| Hallo AI | 19 $ | V, page 2024 |
| Codility | 24–32 $ | V |
| Mettl (scénarios) | 5–25 $ | S, scénarios |
| SHL (S) | 15–40 $ | S |
| TestGorilla Free | 0 $ (10 crédits/mois) ; Core/Plus : crédits inclus NP | V |

Frais fixes annuels à connaître : TestGorilla Plus ≈ 6 240 $ (520×12, « à partir de ») ; Willo Growth/Scale ≈ 2 508–4 908 $ (209–409 $ ×12, S) ; Testlify add-ons 2 388 $ chacun ; Ribbon Growth ≈ 5 988 $ (499×12).

### 8.2 Politique de gratuité et de financement (CDC §8.4) → conséquences de conception (décisions DEC)
- **1 évaluation IA gratuite/étudiant/mois** : à comptabiliser dans un **registre de quotas interne** (pas chez le fournisseur). Tant que le fournisseur le moins cher vérifié coûte ≥ 5 $, la gratuité doit être réservée à un **mode d'évaluation « léger »** (par exemple QCM court d'un fournisseur au coût marginal faible, ou chaîne LLM si DEC n° 1 = oui), et les évaluations de fournisseurs premium doivent être **payantes ou financées par une organisation**.
- **Évaluations supplémentaires payantes** : le **tarif doit être affiché et confirmé avant tout débit** (CDC §8.4) : le prix de revente est une **décision du propriétaire (DEC n° 2)** ; ne pas coder de tarif.
- **Campagnes financées par des organisations** : facturation interne par campagne (réservation de budget) ; le fournisseur n'est jamais payé par l'étudiant directement sans écran de confirmation.
- **Non-conditionnement abusif** : la candidature à une offre ne doit pas être bloquée par l'achat d'une évaluation payante (CDC §8.4) → champ « évaluation requise » doit être **financeable par l'organisation** ou remplaçable par une évaluation gratuite équivalente.
- **Réutilisation** : une évaluation récente est réutilisable **uniquement avec l'accord de l'étudiant**, et si le référentiel/la version de rubrique et la famille de métiers correspondent.

---

## 9. Architecture recommandée : orchestrateur multi-fournisseurs provider-agnostique

> **Proposition de conception, non implémentée.** Chaque composant sera **EXT/NV** tant qu'un appel réel n'a pas réussi (§10).

### 9.1 Principes
1. **Aucun évaluateur propriétaire** : l'orchestrateur transporte, normalise, journalise ; il ne note pas (sauf DEC n° 1).
2. **Aucune clé dans l'application mobile/web** : tous les appels fournisseurs partent d'**Edge Functions** (secrets Supabase) ; l'app n'appelle que `Backend.*` → RPC/Edge. Les webhooks entrants sont reçus par une Edge Function dédiée.
3. **Asynchrone par défaut** : limites Edge (150/400 s) ⇒ création de session → lien fournisseur ou jeton éphémère → webhook/poll de résultat. Aucune attente synchrone d'une évaluation.
4. **Observation explicite** : chaque résultat porte `observation_mode` ∈ {`observed_remote`, `observed_human`, `not_observed`, `self_declared`} ; pour la grappe C, un score QCM est toujours `not_observed` pour les gestes (« théorie évaluée ; geste non observé ») et la certification d'un geste exige `observed_human`.
5. **Validation humaine** : aucune décision d'embauche/exclusion n'est calculée par l'orchestrateur (CDC §7.5 : « décision humaine »).

### 9.2 Interface commune (pseudo-contrat, sans lien avec un langage)
```
ProviderAdapter {
  id, version, kind: 'assessment' | 'interview' | 'human_validation' | 'transcription'
  capabilities(): { jobFamilies[], modes[], languages[], maxDurationMin, supportsWebhook, supportsEmbed, requiresHumanReview }
  createSession(request: AssessmentRequest): { providerSessionId, candidateUrl | embedToken, expiresAt }
  getResult(providerSessionId): RawProviderResult
  handleWebhook(headers, body): { verified: boolean, providerSessionId, event }   // signature vérifiée ; sinon re-lecture via getResult
  cancel(providerSessionId), deleteCandidateData(candidateRef)                     // droit à l'effacement
  health(): { ok, latencyMs, quotaRemaining? }
}
```
`AssessmentRequest` : `studentId`, `jobFamily` (clé du catalogue §8.1), `modes`, `language`, `consentIds[]`, `funding` ∈ {`free_monthly`, `student_paid`, `org_campaign:<id>`}, `quoteId` (tarif confirmé), `idempotencyKey`.

### 9.3 Registre et routage
- Tables proposées (**non créées**) : `assessment_providers` (statut `draft|sandbox|live|disabled`, région de données, DPA signé O/N, entraînement interdit O/N), `assessment_provider_capabilities` (fournisseur × famille × mode × langue × coût estimé), `assessment_routes` (règles ordonnées par famille), `assessment_requests`, `assessment_results`, `assessment_quota_ledger`, `assessment_consents`, `assessment_provider_events` (journal de webhooks/appels), `assessment_appeals`.
- **Routage** : (famille de métier, mode, langue, financement, budget, région de données autorisée) → fournisseur éligible `status='live'` de meilleur rang ; **repli** si `health()` KO/timeout/quota (ordre : fournisseur 2 de même famille → mode alternatif (texte au lieu de vidéo) → file d'attente + message à l'étudiant ; **jamais** de repli silencieux vers un fournisseur dont le consentement n'a pas été donné par l'étudiant).
- **Catalogue extensible** : la famille de métiers est une donnée (code §8.1 + libellé + grappe), pas un type ; ajouter une famille = insérer des lignes de capacités.
- **Famille C** : route par défaut = QCM théorie (si fournisseur disponible) + `human_validation` obligatoire pour toute mention de geste.

### 9.4 Résultat normalisé (conforme CDC §8.5)
```
NormalizedResult {
  resultId, requestId, providerId, providerVersion, rubricVersion, observationMode,
  competencies: [ { code, label, level|score, scale, confidence? } ],
  criteria:     [ { code, label, weight, outcome, explanation } ],
  evidence:     [ { type: 'answer'|'file'|'transcript_excerpt'|'provider_report', ref, excerpt?, observed: bool } ],
  limits:       [ strings OBLIGATOIRE non vide ],   // ex. « geste non observé », « langue d'évaluation : fr-FR »
  recommendations: [ ... ],
  overall?: { score, label },                       // jamais une décision d'embauche
  contestation: { allowed: true, deadlineDays?, humanReviewer?, channel },
  fairness: { sensitiveAttributesUsed: false, accentOrAppearanceUsed: false, providerBiasAuditUrl? },
  rawRef: stockage chiffré du rapport brut, retention
}
```
Règles de validation : refus d'enregistrer un résultat sans `limits`, sans `rubricVersion`, ou avec `observationMode='not_observed'` combiné à une compétence de geste certifiée ; les champs d'analyse faciale, émotionnelle ou de ton de voix sont **rejetés à l'ingestion**.

### 9.5 Quotas, facturation interne, consentement, journalisation
- **Quota gratuit** : `assessment_quota_ledger(student_id, period='YYYY-MM', free_used, ...)` ; la consommation est écrite **avant** l'appel fournisseur (idempotente) et restituée si le fournisseur échoue avant ouverture de session. Calendrier de période (fuseau) à décider.
- **Facturation interne** : débit uniquement après affichage du **tarif annoncé** et confirmation explicite (`quoteId`) ; campagnes d'organisation avec budget réservé. Montants = décisions propriétaire (DEC n° 2) ; aucun paiement réel avant autorisation.
- **Consentement** : un consentement **par fournisseur, par finalité** (évaluation, transfert hors Cameroun, enregistrement audio/vidéo, réutilisation pour une organisation) ; horodaté, versionné, révocable ; **mineurs** : accord du représentant (loi 2024/017, art. 9).
- **Réutilisation** : `reuse_policy` : fenêtre (ex. durée à décider), même famille, même version de rubrique, **accord explicite** ; l'organisation ne voit que ce que l'étudiant a partagé.
- **Journal** : chaque appel (qui, quand, fournisseur, requête hors données sensibles, latence, statut, coût estimé), chaque webhook (signature vérifiée O/N), conservation ≥ 6 mois (alignement AI Act, S) à confirmer.
- **Webhooks** : endpoint public par fournisseur ; **vérification de signature** (HMAC pour Mettl/Vervoe/Talview) ; pour les fournisseurs sans authentification (Sapia : URL publique sans auth) ⇒ **ne jamais se fier au corps de la requête : re-lire le résultat via l'API**. Rejouabilité et idempotence.
- **Contestation** : l'étudiant ouvre un recours depuis le résultat ; un humain (enseignant/évaluateur désigné) réexamine ; la décision et l'éventuel nouveau résultat sont versionnés ; accès aux données et suppression (`deleteCandidateData`) relayés aux fournisseurs.
- **Non-discrimination** : ne transmettre aux fournisseurs que ce qui est nécessaire (pas de photo, sexe, origine) ; exiger des fournisseurs retenus un rapport de biais (Vervoe, iMocha, Harver ont publié des éléments) ; **suivi interne des écarts de résultats** par groupes de langue/accent/handicap quand la base légale l'autorise.

### 9.6 Sécurité
Secrets en variables Supabase uniquement ; clés distinctes sandbox/production ; allow-list d'IP si le fournisseur l'impose (WeCP) ; limites de débit par fournisseur (HackerRank 10 req/s ; Codility 500 req/h/utilisateur) ; journal sans contenu sensible ; chiffrement des rapports bruts.

---

## 10. Plan de validation avant d'annoncer une intégration

Un fournisseur n'est annoncé « intégré » que lorsque **toutes** les étapes d'une ligne sont validées et prouvées (test automatisé ou procès-verbal de test conservé dans `docs/transformation/`), sans appel à la production Supabase pour les phases fournisseur.

| Phase | Action | Critère d'acceptation (preuve) |
|---|---|---|
| **P0 — Juridique** | Qualification (loi 2024/017 art. 32 ; AI Act Annexe III) ; DPA signé ; clause « pas d'entraînement » ; hébergement choisi | Dossier validé par un juriste ; liste des sous-traitants ; registre de traitement |
| **P1 — Accès** | Compte sandbox/essai réel chez chaque candidat ; confirmer **par écrit** disponibilité Cameroun, paiement (carte/Mobile Money), plan donnant l'API | E-mail/ticket du fournisseur ; **TestGorilla : confirmer si un essai API existe sans plan Plus** |
| **P2 — Appel réel** | Un appel authentifié réussi (création de session/lecture de test) depuis une Edge Function de test | Réponse HTTP 2xx journalisée ; clé hors dépôt ; statut matrice passe de EXT à PART seulement |
| **P3 — Cycle complet** | Invitation → passage par un testeur réel → webhook ou lecture de résultat → normalisation | `NormalizedResult` valide (limits non vides, observationMode correct) ; webhook rejoué sans doublon ; signature invalide rejetée |
| **P4 — Francophonie** | 20 passages réels avec voix/accents de Douala (si voix) ; test sur 5 familles dont C | Taux d'erreur de transcription et jugement humain documentés ; **seuil à fixer avant le test** (par exemple écart ≤ à l'évaluateur humain de référence) |
| **P5 — Équité** | Revue de biais sur sous-groupes (langue, genre, handicap) | Rapport interne + rapport fournisseur ; plan correctif |
| **P6 — Quota & coût** | Simulation du registre de quotas ; coût réel d'une évaluation mesuré sur 30 passages | Coût unitaire mesuré ≤ plafond défini par le propriétaire ; aucune double consommation en cas de repli |
| **P7 — Contestation** | Recours bout en bout (étudiant → humain → nouveau résultat) | Scénario de test connecté |
| **P8 — Repli et pannes** | Coupure simulée du fournisseur 1 | Bascule documentée vers le fournisseur 2 sans perte de quota ni fuite de données |
| **P9 — Production** | Activation `live` par fournisseur sur décision propriétaire | Statut « OP » seulement quand UI → `Backend.*` → RPC/table → effet persistant + test existent |

Pour chaque fournisseur retenu, rédiger la **fiche §21.6** (doc officielle, disponibilité API, authentification, permissions, coûts, quotas, restrictions géographiques, CGU, protection des données, limites, mode de test, **statut réel**).

---

## 11. Coût prévisionnel par scénario

Hypothèses (à valider) : **1 évaluation gratuite par étudiant et par mois** ; taux d'utilisation de la gratuité **u** = 100 % (plafond) ou 30 % (hypothèse, non sourcée) ; 12 mois ; hors campagnes d'organisations ; hors frais fixes d'abonnement ; coûts unitaires du §8.1 (USD, pas de conversion XAF). Évaluations/an = N × u × 12.

| Étudiants N | u | Éval./an | LLM léger 0,04 $ | LLM haut de gamme 0,155 $ | ≈ 5 $ (Ribbon / bas Mettl, S) | ≈ 15 $ (HackerRank/CodeSignal) | ≈ 25 $ (Mettl haut, S) |
|---|---|---|---|---|---|---|---|
| **500** (pilote IUT Douala : ordre de grandeur, non sourcé) | 100 % | 6 000 | 240 $ | 930 $ | 30 000 $ | 90 000 $ | 150 000 $ |
| 500 | 30 % | 1 800 | 72 $ | 279 $ | 9 000 $ | 27 000 $ | 45 000 $ |
| **2 000** | 100 % | 24 000 | 960 $ | 3 720 $ | 120 000 $ | 360 000 $ | 600 000 $ |
| 2 000 | 30 % | 7 200 | 288 $ | 1 116 $ | 36 000 $ | 108 000 $ | 180 000 $ |
| **10 000** | 100 % | 120 000 | 4 800 $ | 18 600 $ | 600 000 $ | 1 800 000 $ | 3 000 000 $ |
| 10 000 | 30 % | 36 000 | 1 440 $ | 5 580 $ | 180 000 $ | 540 000 $ | 900 000 $ |

**Lectures** : (1) la gratuité mensuelle est **supportable seulement avec une évaluation à coût marginal de l'ordre de quelques centimes** (chaîne LLM/transcription), ce qui impose la décision DEC n° 1 ; (2) avec les SaaS à 5–25 $, 500 étudiants à 30 % d'usage coûtent déjà 9 000–45 000 $/an ; (3) les évaluations payantes et campagnes d'organisations doivent couvrir au moins le coût fournisseur + frais fixes (**marge = décision propriétaire**, non traitée ici) ; (4) à ajouter : frais fixes de plan (ex. TestGorilla Plus ≈ 6 240 $/an), hébergement, juridique, évaluateurs humains pour la grappe C.

---

## 12. Risques

| Catégorie | Risque | Mesure |
|---|---|---|
| **Juridique** | Transferts transfrontaliers sans autorisation (loi 2024/017 art. 32/69) ; Autorité NV | Avis juridique avant P1 ; consentement par fournisseur ; minimisation |
| | AI Act : système haut risque, éventuelle application extraterritoriale ; interdiction d'émotions | S'aligner par défaut ; exclure émotion/visage/ton ; revue humaine ; journalisation |
| | Mineurs (art. 9) | Consentement du représentant |
| | CGU des fournisseurs (réutilisation de données : micro1, Hallo, Deepgram défaut, Sapia anonymisé) | DPA « pas d'entraînement » ; sinon exclure |
| **Financier** | Prix par évaluation 5–32 $ incompatible avec gratuité universelle ; abonnements fixes (2 500–6 300 $/an) ; paliers G2 ≠ prix officiels ; devis (Mettl, SHL, HireVue) inconnus ; devise USD | Mode léger pour la gratuité ; plafonds de dépense par fournisseur ; négocier volume ; ne coder aucun tarif sans décision |
| | Paiement des fournisseurs depuis le Cameroun (carte internationale, USD/XAF) : NV | Test au P1 |
| **Biais / qualité** | Accents/voix africains non documentés par aucun fournisseur ; scoring de traits | Test P4/P5 ; modes texte/asynchrone ; pas de scoring de traits |
| | QCM présentés comme preuve de compétence pratique | `observationMode`, mention de limites, validation humaine |
| **Dépendance** | Rachats/fermetures observés (Hume fermé 13 nov. 2026 ; eSkill, Plum rachetés ; Harver rachète Symphony ; Retorio repositionné) | Abstraction + ≥ 2 fournisseurs par grappe ; export/suppression des données ; clauses de réversibilité |
| | API verrouillées par plan (TestGorilla Plus, Vervoe Enterprise, Testlify entreprise) | Vérifier avant engagement annuel |
| **Technique** | Limites Edge (150/400 s) ; webhooks non authentifiés (Sapia) ; déduplication | Asynchrone ; re-lecture ; idempotence |
| **Qualité métiers manuels** | Aucune évaluation pratique automatisée ; centres NCCER/City & Guilds non vérifiés au Cameroun | Validation humaine locale ; partenariats centres/IUT |

---

## 13. Décisions du propriétaire requises (DEC) et prochaines étapes
1. **DEC n° 1** — Autoriser (ou non) un mode « évaluation légère » reposant sur des briques LLM/voix avec rubriques Boutik-École (équivaut à un évaluateur propre) ; sinon, la gratuité mensuelle doit être financée autrement ou réduite aux fournisseurs à coût marginal faible.
2. **DEC n° 2** — Tarif des évaluations supplémentaires, marge, devise (non traité ici ; voir H8_DECISIONS_PROPRIETAIRE_SEPAREES.md et CDC §30).
3. **DEC n° 3** — Choix des 2–3 fournisseurs à essayer en P1 (proposition : TestGorilla, Mercer Mettl, Willo ; infrastructure : Mistral + un repli).
4. **DEC n° 4** — Partenariats de validation pratique (IUT de Douala, centres agréés).
5. **Juridique** — Qualification loi 2024/017 / AI Act avant tout envoi de données réelles.
6. Statut de la matrice pour toutes les lignes « fournisseurs d'évaluation » : **EXT / non intégré**.

---

## 14. Table des sources

Date de consultation : **2026-11-23** pour tous les liens ; la date entre parenthèses est la date de crawl/mise à jour rapportée par le moteur (« — » = non rapportée). Les extraits n'ont pas été relus en intégralité.

### 14.1 Plateformes d'évaluation
| Réf. | URL | Crawl / maj | Utilisée pour |
|---|---|---|---|
| T1 | https://docs.testgorilla.com/ | 2026-11-23 | API TestGorilla |
| T2 | https://support.testgorilla.com/hc/en-us/articles/9025312232731-TestGorilla-s-API-documentation | 2026-11-17 | API réservée Plus/External Recruitment |
| T3 | https://www.testgorilla.com/pricing/ | 2026-11-19 | Prix TestGorilla |
| T4 | https://support.testgorilla.com/hc/fr-fr/articles/30469765739931 | 2026-09-24 | Français (≈ 40+ tests) |
| T5 | https://www.testgorilla.com/language-tests/ | 2026-11-14 | Tests CEFR |
| T6 | https://www.testgorilla.com/dpa/ ; https://www.testgorilla.com/joint-controller-arrangement/ | — ; 2026-05-05 | DPA, co-responsabilité |
| M1 | https://support.mettl.com/portal/en/kb/articles/api-integration-with-mettl | 2026-11-23 | API Mettl |
| M2 | https://support.mettl.com/portal/en/kb/articles/mettl-api-integration-flow | 2026-11-21 | Webhook |
| M3 | https://mettl.com/en/information-security-features/ ; https://mettl.com/en-gb/generic-tests/ ; https://mettl.com/fr/ | 2026-11-18 ; 2026-11-17 ; — | Sécurité, tests |
| M4 | https://assessing.ai/blog/mercer-mettl-pricing-cost | 2026-11-20 | Prix (S) |
| SH1 | https://www.shl.com/legal/eu-ai-act/ | 2026-11-17 | AI Act SHL |
| SH2 | https://online.shl.com/om/en-us/products/verifymechanicalcomprehensionsemiskilledtechnical | 2026-09-17 | Mécanique en français |
| SH3 | https://support.greenhouse.io/hc/en-us/articles/54572973840667-SHL-integration ; https://assessing.ai/blog/shl-assessment-cost-pricing | 2026-11-12 ; 2026-11-14 | Intégration ATS ; prix (S) |
| CR1 | https://www.criteriacorp.com/test-languages ; https://www.compono.com/articles/criteria-corp-pricing-guide-2026 | 2026-11-15 ; — | Langues ; prix (S) |
| IM1 | https://developer.imocha.io/ | 2026-11-22 (maj 2026-04-17) | API iMocha |
| IM2 | https://mochaworks.imocha.io/hubfs/Trust%20Center%20-%20iMocha/Ethical%20&%20Responsible%20AI%20Datasheet.pdf ; https://www.spotsaas.com/product/imocha/pricing | 2026-09-16 ; — | Biais ; prix (S) |
| V1 | https://vervoe.com/trust-and-security/ ; https://www.g2.com/products/vervoe/pricing ; https://github.com/api-evangelist/vervoe/blob/main/README.md | 2026-11-17 ; 2026-11-23 ; — | Sécurité ; prix (S) ; API (S) |
| H1 | https://api.harver.com/docs ; https://harver.com/security/ ; https://www.symphonytalent.com/blog/harver-acquires-symphony-talent/ ; https://harver.com/wp-content/uploads/2025/11/pymetrics-Soft-Skills-Platform-2025-Bias-Audit.pdf | 2026-11-18 ; 2026-11-04 ; 2026-11-19 ; 2026-09-25 | Harver |
| HR1 | https://www.hackerrank.com/work/apidocs ; https://support.hackerrank.com/articles/2067417637-api-overview | 2026-11-21 | API HackerRank ; (page tarifs officielle consultée, URL exacte non rapportée, 2026-11-17) |
| HR2 | https://pages.hackerrank.com/blog/hackerranks-approach-gdpr | — | RGPD/DPA |
| CO1 | https://codility.com/api-documentation/ ; https://www.codility.com/pricing/ ; https://www.codility.com/why-codility/security-and-compliance/ | 2026-11-04 ; 2026-11-17 ; 2026-11-19 | Codility |
| CS1 | https://developer.codesignal.com/webhooks/ ; https://codesignal.com/pricing/ | 2026-11-22 ; 2026-11-23 | CodeSignal |
| HE1 | https://www.hackerearth.com/docs/wiki/developers/v4/ ; https://www.hackerearth.com/docs/webhooks/recruiter/v1/assessments-webhooks/ | 2026-11-20 ; 2026-10-25 | HackerEarth |
| TL1 | https://testlify.com/api/ ; https://testlify.com/pricing/ ; https://testlify.com/security-and-compliance/ | 2026-11-19 ; 2026-11-16 ; 2026-11-15 | Testlify |
| ES1 | https://eskill.com/resources/blog/scaleworks-acquires-leading-pre-hire-assessment-platform-eskill-appoints-new-ceo ; https://eskill.com/integrations | 2026-11-21 ; 2026-11-20 | eSkill |
| TV1 | https://www.talview.com/en/proctoring-apis ; https://docs.talview.com/graph-api-reference/webhooks/overview ; https://www.talview.com/en/pricing ; https://www.talview.com/en/privacy-and-security | — ; 2026-10-20 ; 2026-11-19 ; 2026-11-14 | Talview |
| CA1 | https://www.canditech.io/pricing/ ; https://www.canditech.io/pricing-md/ | 2026-11-22 ; 2026-10-28 | Canditech |
| HA1 | https://hallo.ai/ ; https://hallo.ai/terms-of-service-tp/ ; https://hallo.ai/security/ ; https://apis.io/plans/hallo/hallo-plans-pricing/ | 2026-11-16 ; 2026-11-16 ; 2026-10-16 ; 2026-10-10 | Hallo AI |
| AD1 | https://www.adaface.com/pricing | 2026-11-17 | Adaface |
| WE1 | https://www.wecreateproblems.com/pricing ; https://help.wecreateproblems.com/en/articles/9520530-working-with-wecp-s-apis | 2026-11-18 ; 2026-11-04 | WeCP |
| GL1 | https://hire.glider.ai/api/index.html | 2026-11-23 | Glider AI |
| VA1 | https://talogy.com/en/talent-management-solutions/assessments/virtual-business-simulations/ ; https://www.jvrafricagroup.com/catalogue/virtualacs | 2026-11-16 ; 2026-11-12 | VirtualAC |
| NC1 | https://hs.nccer.org/assess-verify-upskill | 2026-11-15 | NCCER |
| CG1 | https://www.cityandguilds.com/delivering-our-qualifications/centre-development/centre-document-library ; https://moaetscandg.org.ng/vocational-education/leading-nigerian-vocational-institutes-that-provide-international-certifications/ | 2026-11-22 ; 2026-11-05 | City & Guilds |
| PV1 | https://www.prometric.com/remote-delivery/ ; https://pearson.htti.net/ ; https://www.paked.net/q/detail/prometric-centers-in-cameroon_5683.html | 2026-11-21 ; 2026-11-21 ; 2026-07-29 | Pearson VUE/Prometric (centres Cameroun : S) |

### 14.2 Entretiens IA
| Réf. | URL | Crawl | Utilisée pour |
|---|---|---|---|
| HV1 | https://www.hirevue.com/solutions/ai-interviewer ; https://www.hirevue.com/blog/hiring/industry-leadership-new-audit-results-and-decision-on-visual-analysis ; https://apis.io/providers/hirevue/ | 2026-11-23 ; 2026-11-17 ; 2026-11-14 | HireVue |
| HU1 | https://dev.hume.ai/voice/changelog ; https://dev.hume.ai/voice/intro ; https://dev.hume.ai/expression-measurement/changelog/2026/10/6 | 2026-10-25 ; 2026-11-01 ; 2026-11-08 | Fermeture EVI/TTS le 13 nov. 2026 |
| SA1 | https://developer.sapia.ai/ ; https://sapia.ai/security/ ; https://sapia.ai/data-governance/ ; https://sapia.ai/resources/blog/elevating-candidate-experience-empowering-candidates-with-language-choice/ | 2026-11-22 ; 2026-11-09 ; 2026-11-23 ; 2026-11-20 | Sapia.ai |
| WI1 | https://www.willo.video/api ; https://www.willo.video/features ; https://trust.willo.video/ ; https://support.willo.video/article/217-data-processing-agreement ; https://github.com/api-evangelist/willo/blob/main/README.md | 2026-11-17 ; 2026-11-18 ; 2026-11-13 ; 2026-11-19 ; 2026-07-10 | Willo |
| SP1 | https://www.sparkhire.com/pricing/ ; https://docs.sparkhire.com/ ; https://support.sparkhire.com/hc/en-us/articles/39488633780379-AI-for-One-Way-Video-Interviews-Overview-for-recruiters-and-managers ; https://www.sparkhire.com/privacy/ | 2026-11-22 ; 2026-11-22 ; 2026-11-17 ; — | Spark Hire |
| MI1 | https://ai-recruiter.micro1.ai/llms.txt ; https://www.micro1.ai/legal/privacy-notice-candidates | 2026-10-30 ; 2026-11-23 | micro1 |
| TE1 | https://trust.tenzo.ai/ ; https://www.tenzo.ai/privacy-policy | 2026-11-23 ; 2026-11-18 | Tenzo |
| AL1 | https://docs.alex.com/api-reference/webhooks ; https://docs.alex.com/compliance-faq | 2026-11-17 ; 2026-09-26 | Alex / Apriora |
| RI1 | https://www.ribbon.ai/pricing ; https://docs.ribbon.ai/ ; https://docs.ribbon.ai/docs/supported-languages | 2026-10-27 ; 2026-10-19 ; 2026-11-19 | Ribbon AI |
| JO1 | https://www.jobma.com/plans-and-pricing ; https://www.jobma.com/gdpr-compliance | 2026-11-13 ; 2026-11-19 | Jobma |
| RE1 | https://www.retorio.com/ ; https://www.retorio.com/en/pricing | 2026-11-22 ; 2026-11-23 | Retorio |
| ME1 | https://talent.docs.mercor.com/support/ai-interview ; https://talent.docs.mercor.com/policies/data-ai-usage | 2026-11-23 | Mercor |
| PA1 | https://investor.workday.com/news-and-events/press-releases/news-details/2026/Paradox-Conversational-Applicant-Tracking-System-ATS-Now-Available-Through-Workday-Helping-Organizations-Hire-Frontline-Workers-Faster/default.aspx | 2026-11-23 | Paradox/Workday |

### 14.3 Infrastructure LLM / voix
| Réf. | URL | Crawl / maj | Utilisée pour |
|---|---|---|---|
| OA1 | https://developers.openai.com/api/docs/pricing ; https://developers.openai.com/api/docs/supported-countries ; https://developers.openai.com/api/docs/guides/your-data ; https://developers.openai.com/api/docs/guides/structured-outputs ; https://openai.com/policies/usage-policies/ ; https://openai.com/business-data/ | 2026-11-23 ; 2026-11-23 ; — ; 2026-11-23 ; 2026-11-21 ; — | OpenAI |
| AN1 | https://platform.claude.com/docs/en/about-claude/pricing ; https://www.anthropic.com/legal/supported-regions ; https://platform.claude.com/docs/en/manage-claude/data-residency ; https://platform.claude.com/docs/en/manage-claude/api-and-data-retention ; https://www.anthropic.com/legal/aup | 2026-11-19 ; maj 2026-11-12 ; — ; — ; — | Anthropic |
| GO1 | https://ai.google.dev/gemini-api/docs/available-regions ; https://ai.google.dev/gemini-api/docs/pricing ; https://ai.google.dev/gemini-api/docs/zdr ; https://aistudio.google.com/docs/terms ; https://policies.google.com/terms/generative-ai/use-policy ; https://docs.cloud.google.com/speech-to-text/docs/models/chirp-3 | maj 2026-10-22 ; — ; — ; — ; — ; — | Google |
| MS1 | https://docs.mistral.ai/inference/pricing ; https://mistral.ai/news/voxtral-transcribe-2/ ; https://legal.mistral.ai/terms/data-processing-addendum/?lang=en ; https://legal.mistral.ai/terms/usage-policy/?lang=en ; https://docs.mistral.ai/studio/audio/speech_to_text | 2026-11-23 ; — ; — ; — ; — | Mistral |
| EL1 | https://elevenlabs.io/pricing/api ; https://elevenlabs.io/blog/introducing-scribe-v2-realtime | 2026-11-23 ; — | ElevenLabs |
| DG1 | https://deepgram.com/pricing ; https://developers.deepgram.com/trust-security/ ; https://developers.deepgram.com/docs/models-languages-overview | 2026-11-21 ; — ; — | Deepgram |
| AA1 | https://www.assemblyai.com/security ; https://dupple.com/learn/assemblyai-pricing | — ; 2026-10 | AssemblyAI (prix : S) |
| AZ1 | https://azure.microsoft.com/en-us/pricing/details/azure-openai/ ; https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/openai/data-privacy ; https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support | 2026-11-22 ; — ; — | Azure |
| AW1 | https://aws.amazon.com/fr/transcribe/pricing/ ; https://aws.amazon.com/bedrock/security-privacy-responsible-ai/ | — | Amazon |
| SM1 | https://www.speechmatics.com/pricing ; https://docs.speechmatics.com/speech-to-text/languages ; https://www.speechmatics.com/speech-to-text/french | — | Speechmatics |
| WH1 | https://github.com/openai/whisper | — | Whisper |
| VP1 | https://docs.vapi.ai/billing/pricing-and-success-packages ; https://docs.retellai.com/general/compliance ; https://livekit.com/security | — | Vapi/Retell/LiveKit |
| SU1 | https://supabase.com/docs/guides/functions/limits | maj 2026-11-20 | Limites Edge Functions |

### 14.4 Droit
| Réf. | URL | Crawl / maj | Utilisée pour |
|---|---|---|---|
| L1 | https://droit-et-politique-en-afrique.info/wp-content/uploads/2024/12/Loi-du-23-decembre-2024-protection-des-donnees-personnelles-au-Cameroun.pdf | maj 2024-12-27 ; crawl 2026-09-26 | Loi n° 2024/017 : champ, art. 15, 32, 69 (copie hébergée par un site tiers ; Journal officiel non consulté) |
| L2 | https://lexlint.io/l/cm-loi-n-2024-017-du-23-d-cembre-2024 | maj 2026-09-04 ; crawl 2026-11-10 | Art. 2, 9, 19, 22, 27, 29, 53 (S) |
| AI1 | https://www.regulatoryai.eu/playbooks/eu-ai-act-hr/ ; https://www.euaiact.com/guides/hr-and-recruitment | maj 2026-06-18 ; crawl 2026-11-03 / 2026-10-08 | Annexe III pt 4, art. 5(1)(f) (S) |
| AI2 | https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=oj:L_202601744 ; https://www.europarl.europa.eu/legislative-train/package-digital-package/file-digital-omnibus-on-ai ; https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/ | 2026-11-16 ; 2026-11-23 ; 2026-11-23 | Calendrier « Digital Omnibus » (texte intégral non relu : NV) |
| AI3 | https://ai-act-service-desk.ec.europa.eu/sites/default/files/2025-08/guidelines_on_prohibited_artificial_intelligence_practices_established_by_regulation_eu_20241689_ai_act_english_ied3r5nwo50xggpcfmwckm3nuc_112367-1.PDF | 2026-08-18 | Lignes directrices pratiques interdites |

---

## 15. Limites de vérification (récapitulatif)
- Aucune page lue en entier ; extraits de moteur de recherche uniquement ; pas de PDF/DPA/contrat lu.
- Disponibilité Cameroun : **vérifiée seulement** pour OpenAI, Anthropic, Google ; **NV** pour tous les autres.
- Accents et français d'Afrique : **NP** chez tous (Speechmatics : affirmation marketing sans mesure).
- Prix : plusieurs prix sont **S** (Mettl, SHL, Criteria, Willo, Vervoe, HackerEarth, micro1, Alex) ; la page tarifs Hallo date de 2024 ; l'écart G2/officiel a été constaté sur HackerRank et TestGorilla.
- Calendrier AI Act (« Digital Omnibus », 2 déc. 2027) : extraits S/EUR-Lex non relus intégralement ; applicabilité extraterritoriale : **NV**.
- Loi 2024/017 : lue sur une copie hébergée hors Journal officiel ; fonctionnement de l'Autorité : **NV**.
- Les noms/prix de modèles d'IA et les politiques d'usage évoluent vite : à re-vérifier le jour de la décision.
- Aucun appel d'API, aucun sandbox, aucun compte : **tout fournisseur reste « non intégré » (EXT)**.
