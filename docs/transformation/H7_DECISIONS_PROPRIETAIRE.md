# H7 · Décisions métier à faire approuver par le propriétaire (facturation et argent)

État : lot H7 « facturation », examen du moteur d'argent au 20 novembre 2026 (base : commit `a5a9dff0`, migrations locales `20261123010000`).
Rien ci-dessous n'est décidé par le code : chaque point décrit ce que le système fait **aujourd'hui**, les choix possibles et leurs effets. Les recommandations sont neutres (elles indiquent le choix qui demande le moins de travail ou de risque, pas un choix commercial).

## Ce que le lot H7 a réellement branché

| Réglage de l'écran 135 | Clé enregistrée (`platform_settings`) | Lu par la facturation ? |
|---|---|---|
| Seuil de paiement vendeur (FCFA) | `commission.payout_threshold` | **Oui** : c'est le retrait minimum d'une demande du vendeur (`request_seller_payout`, `my_payouts.min`, contrôle de suppression de compte). Remplace `payouts.min` (1 000 FCFA par défaut) dès qu'il est enregistré ; borné par `payouts.max`. Sans seuil enregistré : comportement inchangé. |
| Commission sur les produits (%) | `commission.product` | **Non** (décision 1) |
| Commission sur les services (%) | `commission.service` | **Non** (décision 1) |
| Commission financement participatif (%) | `commission.financing` | **Non** (décision 1) |

Autres changements : le serveur refuse désormais une valeur `commission.*` invalide (taux : entier de 0 à 30 ; seuil : entier de 0 à 100 000 000), même par écriture directe (déclencheur `trg_h7_commission_settings`). La répartition `money_split_rules` (70/20/10) n'a **pas** été modifiée. Preuve : `supabase/tests/marketplace_pglite/h7_facturation.mjs` (41 contrôles) ; fichier de migration `supabase/migrations/20261123010000_h7_seuil_paiement_commission_reglages.sql`.

Point d'attention pour l'écran 135 : en mode connecté il affiche « Enregistré et journalisé » (`lib/figma/g/g_135.dart`). C'est exact pour le seuil (appliqué) mais les trois taux sont seulement enregistrés. Tant que la décision 1 n'est pas prise, un administrateur peut croire qu'ils s'appliquent.

---

## 1. Les taux de commission de l'écran 135 face à la répartition 70/20/10

- **Contexte** : l'écran 135 permet d'écrire trois taux (produits, services, financement participatif ; maquette : 5 %, 7 %, 4 %) et un seuil. La répartition de l'argent d'une vente est, elle, définie par `money_split_rules` (70 % prestataire, 20 % fonds de l'institution, 10 % plateforme). Les deux notions se recouvrent (la « commission » de la plateforme) sans que rien ne dise comment.
- **Ce que fait le code aujourd'hui** : `money_split_amounts` (`20261114002800_sequestre_70_20_10.sql`) ne lit que `money_split_rules` ; elle est utilisée par `money_order_paid` (commandes, devis), la clôture des campagnes (`20261117050300_s5_campagnes_cloture.sql`) et les forfaits (100 % plateforme, aucune part). Aucune fonction ne lit `commission.product/service/financing`. Ils sont écrits (`setting_set`) et journalisés (`audit_log`), c'est tout. Le scénario H7 prouve qu'un taux enregistré ne change aucune ligne de séquestre.
- **Questions sans réponse dans le code ni dans `docs/`** : (a) la commission est-elle la part « plateforme » (alors 5 % contredit les 10 % de la règle), un prélèvement en plus de la répartition, ou le remplaçant de la répartition ? (b) sur quelle base (décision 3) ? (c) qu'est-ce qu'un « service » face à un « produit » (une ligne de commande n'a pas de type fiable ; un devis crée une commande) ? (d) le financement participatif a déjà une part du porteur à 70 % : le 4 % s'y ajoute-t-il ?
- **Options** :
  - A. Les taux **sont** la part plateforme par type ; le fonds de l'institution reste 20 % et le prestataire reçoit le reste (produits : 75 / 20 / 5). Il faut alors rendre `money_split_rules` dépendante du type.
  - B. Les taux sont un **prélèvement supplémentaire** sur la part du prestataire avant la répartition (10 000 FCFA, 5 % : 500 FCFA de commission, répartition 70/20/10 du reste).
  - C. Les taux **remplacent** la règle 70/20/10 ; le fonds d'innovation disparaît ou devient un réglage séparé.
  - D. On **supprime** les trois lignes de l'écran 135 (ne garder que le seuil) et on garde la règle 70/20/10 comme seule source.
- **Impact** : A, B, C changent les montants versés aux étudiants et la comptabilité ; D ne change rien aux flux. Dans tous les cas, appliquer à une commande déjà payée est exclu (les lignes `money_entries` existantes ne sont jamais réécrites).
- **Recommandation neutre** : D est la seule option sans effet financier ; A, B ou C exigent d'abord les décisions 2, 3 et 4. Une fois l'option choisie, le branchement tient dans `money_split_amounts` (une seule fonction centrale), avec un scénario de non-régression.

## 2. La répartition 70 / 20 / 10 elle-même

- **Contexte** : règle de départ posée par migration, modifiable par l'administrateur (`money_split_set`, permission `finance.split`).
- **Code** : `money_split_rules` (migration `20261114002800`) ; lue par `money_split_get` pour l'application (écrans 260, 284, 197, texte des CGV). Reliquat d'arrondi (tronqué) au profit de la plateforme (`p := p_gross - b - i`). Appliquée aux commandes et devis (`money_order_paid`, `20261119040000_g4_money_arithmetique_garde.sql`) et à la clôture des campagnes réussies. Non appliquée : forfaits (100 % plateforme), frais de livraison (100 % au vendeur), récompenses de défis (100 % au gagnant), cadeaux de live (70/30, décision 17).
- **Options** : garder 70/20/10 pour tout ; une règle par type d'opération (commande, financement, mission) ; modifier les pourcentages ; ne plus prélever de fonds institutionnel.
- **Impact** : toute modification ne vaut que pour les paiements futurs ; les écrans lisent la règle en base, aucun changement d'application n'est nécessaire pour un simple changement de pourcentages.
- **Recommandation neutre** : confirmer ou modifier les trois pourcentages et préciser s'ils valent pour toutes les opérations listées ; sinon le code continue tel quel.

## 3. Assiette : brut ou net ; arrondi

- **Contexte** : `docs/QUESTIONS.md` n°7–8 (restée sans réponse) : la maquette de facture affiche « TVA 19,25 % = 53 280 FCFA » qui ne correspond à aucune assiette.
- **Code** : la base est le **prix des articles après remise, hors frais de livraison et hors frais de plateforme** (texte dans `_money_rule_parts`, `20261119040000`). Répartition par vendeur ; remise d'un code promo répartie au prorata, dernier groupe = reliquat (somme exacte). Chaque part est tronquée à l'entier inférieur, reliquat à la plateforme.
- **Options** : (a) brut après remise (actuel) ; (b) net de TVA ; (c) net des frais de paiement de l'opérateur (décision 11) ; (d) arrondi au plus proche au lieu du tronqué.
- **Impact** : (b) et (c) réduisent la part de chaque bénéficiaire de quelques pour cent ; (d) change au plus de 1 FCFA par ligne.
- **Recommandation neutre** : indiquer l'assiette officielle ; le code actuel correspond à (a).

## 4. Taux de commission par type d'opération

- **Contexte** : la maquette de l'écran 135 distingue produits, services, financement participatif ; `docs/audit-boutik-ecole/11_QUESTIONS_METIER_A_TRANCHER.md` Q-03 demande « valeurs officielles et qui les modifie ».
- **Code** : aucun type n'a de taux propre côté serveur (voir décision 1). Les missions ont des valeurs écrites en dur côté application (décision 16), les parrainages des paliers (décision 18), les cadeaux de live 70/30 (décision 17), les événements payants aucune commission (`20261116100000_evenements_payants.sql`).
- **Options** : un taux unique ; un taux par type ; un taux par vendeur ou par établissement.
- **Impact** : plus la grille est fine, plus il faut de lecture/validation côté serveur et d'explications dans les CGV.
- **Recommandation neutre** : fournir la grille complète (type, taux, base, bénéficiaires, qui peut la modifier) ; l'écran 135 et le serveur sont déjà prêts à la stocker.

## 5. Frais de livraison

- **Contexte** : frais payés en plus du prix des articles.
- **Code** : valeur par défaut 5 000 FCFA (`institution_settings.home_delivery_fee`, `20261101000300_livraison.sql`), tarifs par ville et par vendeur (`20261114000800_livraison_villes.sql`). Dans `money_order_paid`, les frais sont versés **à 100 % aux vendeurs** (ligne `delivery`, split `100/0/0`), au prorata de leurs tarifs, sans part plateforme ni fonds. Aucune ligne pour un paiement à la livraison. Ils sont remboursés avec la commande, au prorata, dans un remboursement partiel.
- **Options** : 100 % vendeur (actuel) ; part de la plateforme sur la livraison ; livraison facturée au coût réel d'un transporteur ; gratuité au-delà d'un montant.
- **Impact** : toute part plateforme sur la livraison réduit le revenu des vendeurs ; la facture doit alors la mentionner.
- **Recommandation neutre** : confirmer que la livraison appartient entièrement au vendeur.

## 6. Remboursement, réclamation et litige

- **Contexte** : une commande payée peut être remboursée en totalité ou en partie, sur demande, réclamation ou décision de litige.
- **Code** : `20261117040100_money_remboursements.sql`, `20261119040100_g4_remboursements_partiels.sql` : demande par l'acheteur ou le vendeur, décision par support/finance, remboursement **partiel** réparti au prorata sur chaque ligne de séquestre (somme exacte), puis la finance inscrit à la main la référence du remboursement Mobile Money. Argent déjà débloqué puis remboursé : le vendeur a un solde négatif (« deficit ») compensé sur ses prochains déblocages ; la finance est prévenue. Les frais de livraison sont remboursables. Aucun frais de gestion n'est retenu ; les frais d'opérateur éventuels ne sont pas pris en compte.
- **Options** : remboursement intégral sans retenue (actuel) ; retenue forfaitaire ou en % ; qui supporte les frais d'opérateur ; délai maximal de demande ; récupération du déficit par prélèvement sur d'autres revenus ou par recouvrement.
- **Impact** : une retenue doit figurer dans les CGV et dans les montants affichés au client.
- **Recommandation neutre** : fixer les cas ouvrant un remboursement, le délai maximal, le traitement du déficit et les éventuelles retenues.

## 7. Délai de garde avant déblocage

- **Code** : 72 h après la livraison déclarée si l'acheteur ne confirme pas ; réglable (`money.hold_hours`, 1 à 720 h, `20261117040000_money_sequestre_garde.sql`). Réclamation, litige ou remboursement en cours : déblocage suspendu.
- **Options** : 72 h (actuel) ; plus court (compétitivité) ou plus long (protection). Délai différent par type (service, produit).
- **Recommandation neutre** : valider 72 h ou en indiquer un autre ; aucun changement de code n'est nécessaire (réglage serveur).

## 8. Retrait : minimum, maximum, frais, délais

- **Contexte** : le seuil de l'écran 135 est maintenant lu (voir tableau ci-dessus). Plusieurs règles voisines restent à valider.
- **Code** : minimum par demande = `commission.payout_threshold` s'il est enregistré, sinon `payouts.min`, sinon 1 000 FCFA ; maximum `payouts.max` (500 000 FCFA par défaut) ; un seul retrait en cours par vendeur ; numéro Mobile Money enregistré obligatoire et inutilisable pendant 24 h (`payouts.number_delay_hours`) ; téléphone vérifié, étudiant vérifié (`20261119040200_g4_retraits_securises.sql`). **Aucun frais de retrait** n'est prélevé ni affiché. La finance peut créer un versement (`payout_create`) **sans minimum** (elle peut solder un reste inférieur au seuil). Le seuil enregistré ne dépasse jamais le maximum.
- **Options** : (a) la finance respecte aussi le seuil ; (b) le seuil s'applique au solde disponible et non à chaque demande ; (c) frais de retrait fixes ou en % ; (d) retrait automatique mensuel.
- **Impact** : (a) empêcherait de solder un petit reste ; (c) nécessite un affichage avant confirmation et une écriture comptable.
- **Recommandation neutre** : indiquer si le seuil engage aussi la finance ; si des frais de retrait existent. Les valeurs « minimum » et « maximum » se règlent déjà depuis l'écran 135 (minimum) et `payouts.max` (maximum, sans écran).

## 9. Décaissement Mobile Money (MoMo / Orange Money)

- **Contexte** : les retraits des vendeurs sont versés par la finance.
- **Code** : `payout_set_status` exige une **référence de transaction** saisie à la main (« verse »). Les fonctions Edge `momo` et `momo-callback` (lecture) préparent et envoient un virement (`confirm_transfer`, finance/admin seulement, confirmation explicite, un seul débit par transaction) mais **rien ne relie** `momo_transactions` à `payout_batches` : un versement envoyé par l'API n'est pas rapproché automatiquement du retrait du vendeur. Orange Money : réponse `501` (contrat marchand requis) ; MTN : « non configuré » tant que contrat et clés manquent.
- **Options** : versement manuel hors application (actuel) ; envoi par l'API MTN, puis rapprochement automatique ; Orange en attente de contrat.
- **Impact** : l'automatisation exige contrats, clés (jamais dans le dépôt) et une migration de liaison.
- **Recommandation neutre** : décider du mode (manuel ou API) et de l'opérateur prioritaire ; la liaison `payout_batches` ↔ `momo_transactions` est un travail distinct.

## 10. TVA et facture légale

- **Contexte** : la maquette affiche « Taxes applicables 0 FCFA » et, en démonstration, « TVA 19,25 % ».
- **Code** : la facture connectée (`InvoiceTotals`, `lib/figma/live/docs.dart`) affiche articles, remise, livraison et statut de paiement ; **aucune TVA** n'est calculée ni stockée ; le PDF mentionne NIU et RCCM de l'entreprise cliente (`order_billing_get`, `20261118040100_f4_achats_b2b.sql`) mais pas ceux de Boutik-École. Numérotation : `documentNumber` côté application.
- **Options** : documents non fiscaux (reçus) ; facture avec TVA 19,25 % (assiette à fixer, décision 3) ; mentions légales de l'émetteur (NIU, RCCM, adresse) ; numérotation continue côté serveur.
- **Impact** : toute TVA change le total payé et la répartition ; exige un avis d'un comptable.
- **Recommandation neutre** : indiquer si les documents doivent être fiscaux ; sinon les intituler « reçu » et préciser qu'ils ne valent pas facture légale.

## 11. Frais de l'opérateur de paiement

- **Code** : aucune ligne de frais n'est calculée côté serveur ; le montant payé est exactement `payment_transactions.amount` (Edge Function `tara-pay`, lecture) et `tara-webhook` accepte un montant reçu **supérieur ou égal** au montant attendu. La ligne « Frais de paiement 1,5 % » n'existe qu'en démonstration (`g_260.dart`).
- **Options** : la plateforme supporte les frais ; le client les paie en supplément ; ils sont déduits de la part plateforme ; ils sont répartis.
- **Recommandation neutre** : désigner qui supporte les frais ; puis les faire apparaître sur la facture.

## 12. Forfaits et abonnements d'organisation

- **Code** : prix par forfait dans `company_plans.price_fcfa` ; un paiement confirmé crée une ligne `subscription` 100 % plateforme (`on_subscription_paid`, `20261118020100_f2_forfaits_paiements.sql`) ; jours restants reportés ; un forfait inférieur ne remplace pas un supérieur sans confirmation ; un paiement confirmé mais non activé alerte la finance (remboursement manuel). Aucune TVA, aucun prorata, aucune facture d'abonnement dédiée, aucun remboursement automatique.
- **Options** : remboursement au prorata à la résiliation ; TVA sur les forfaits ; renouvellement automatique.
- **Recommandation neutre** : fixer la règle de résiliation/remboursement ; les prix restent gérés depuis l'administration.

## 13. Rapprochement comptable

- **Code** : aucun rapprochement automatique entre `payment_transactions` (encaissé), `money_entries` (réparti), `payout_batches` (versé) et les virements opérateur. La finance dispose de `finance_overview` et `finance_journal`. Une notification « Paiement Tara à vérifier » est créée quand le fournisseur confirme sans montant vérifiable.
- **Options** : rapprochement quotidien automatique ; export mensuel pour le comptable ; contrôle de cohérence (encaissé = réparti + remboursé).
- **Recommandation neutre** : dire si la finance a besoin d'un export ou d'un rapprochement avant le lancement.

## 14. Texte des CGV

- **Code** : version `cgv-2026-11` (`kSalesTermsVersion`, `lib/figma/live/auth.dart`), texte dans `lib/figma/live/legal.dart` ; la phrase de répartition est lue en base (`money_split_get`), jamais écrite en dur. Acceptée séparément à la confirmation d'une commande.
- **À valider** : ce que le texte promet sur la répartition, le délai de garde (72 h), les remboursements (décision 6), les frais (décisions 5, 8, 11) et l'absence de TVA.
- **Recommandation neutre** : faire relire le texte par le propriétaire ou un juriste avant la publication ; toute modification de version redemande l'acceptation.

## 15. Version des CGU

- **Code** : `kTermsVersion = 'cgu-2026-10'` (`lib/figma/live/auth.dart`). **Inchangée** dans ce lot : changer la version force tous les comptes à réaccepter les conditions.
- **Recommandation neutre** : ne changer la version qu'avec un texte validé ; prévoir une communication aux utilisateurs.

## 16. Missions : jalons et commission codés en dur côté application

- **Code** : `lib/figma/live/missions.dart` (lignes 463 à 467) : répartition 30/40/30 des jalons, commission `total ~/ 10`, gain étudiant `releasedAmount * 70 ~/ 100`. L'écran 201 affiche ce gain en mode connecté. Le serveur n'écrit aucune ligne `mission` dans `money_entries` : l'argent des missions n'est pas séquestré par le moteur 70/20/10.
- **Options** : brancher les missions sur `money_split_get` ; leur donner un taux propre (décision 4) ; ne pas afficher de gain tant que le serveur ne le calcule pas.
- **Impact** : la valeur affichée peut différer de la règle réellement appliquée si le propriétaire modifie 70/20/10.
- **Recommandation neutre** : décider si les missions suivent la même règle ; ce point n'a pas été corrigé dans H7 (hors périmètre et dépend de la décision 2).

## 17. Cadeaux de live

- **Code** : `gift_settings` (`20261110000000_reseau_social_live.sql`) : part du créateur 70 % (30 % plateforme), 1 crédit = 10 FCFA, quantité maximale 50, « valeurs proposées à valider » (`docs/transformation/RESEAU_SOCIAL_LIVE.md`).
- **Recommandation neutre** : valider ces trois valeurs ou les modifier (réglage serveur, sans changement d'application).

## 18. Parrainage

- **Code** : prime selon le palier du parrain (Bronze 500 F ; Argent 750 F + 2 % ; Or 1 000 F + 3 %), filleul actif à partir de 10 000 FCFA dans les 90 jours (`20261101000400_parrainage_gains.sql`) ; retrait des gains avec minimum 1 000 (`20261115170000_l7_parrainage_social_lives_defis.sql`), **distinct** du seuil de l'écran 135.
- **Options** : même seuil que les ventes ; seuil propre ; palier modifiable depuis l'administration.
- **Recommandation neutre** : indiquer si le seuil de l'écran 135 doit aussi gouverner les gains de parrainage ; sinon ils restent à 1 000 FCFA.

## 19. Bornes des taux acceptées par le serveur

- **Code** : depuis H7, un taux `commission.*` est un entier de 0 à 30 (identique à la validation de l'écran 135) ; le seuil est un entier de 0 à 100 000 000 FCFA.
- **Recommandation neutre** : confirmer le plafond de 30 % ou indiquer un autre plafond ; sinon il reste.

---

## Pour brancher les taux après décision

1. Choisir l'option de la décision 1 et trancher les décisions 3 et 4.
2. Modifier `money_split_amounts` (point d'entrée unique de `money_order_paid` et de la clôture des campagnes) pour lire les clés `commission.*`, **sans** modifier `money_split_rules`.
3. Ajouter au scénario `h7_facturation.mjs` les cas chiffrés (aucun taux : 70/20/10 inchangé ; taux enregistré : montants attendus ; anciennes lignes non réécrites).
4. Mettre à jour l'écran 135 et les CGV pour ne plus laisser croire à un effet que le serveur n'a pas, puis suivre la procédure de production de `REPRISE_OPENCODE.md` (sauvegarde, migration, déploiement).
