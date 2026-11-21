# H8 · Les 19 décisions de H7, séparées : à décider (A) / corrections techniques (B)

Source : `H7_DECISIONS_PROPRIETAIRE.md`. **Rien n'est décidé ici et aucune règle financière n'est activée.** Types : **A** = décision métier, juridique ou financière du propriétaire ; **B** = correction technique (sans effet sur l'argent). Statuts : « fait en H8 » (B réalisé) ou « à faire par le propriétaire ». Cochez une seule case par ligne ; sans case cochée, le code reste tel quel (comportement actuel = première option).

## Tableau

| N° | Sujet | Type | Statut | Choix proposés | Fichiers / fonctions concernés |
|---|---|---|---|---|---|
| 1 | Taux de commission (écran 135) face à 70/20/10 | A (+ B : message) | **A : à faire par le propriétaire.** B (message de l'écran 135 : « taux journalisés, non appliqués ») : fait en H7 ; sous-titre de la tuile « Commissions » du centre admin corrigé en H8 | ☐ A : taux = part plateforme (fonds 20 % gardé) · ☐ B : prélèvement en plus avant répartition · ☐ C : taux remplacent la règle · ☐ D : supprimer les 3 lignes de l'écran 135 · ☐ Rien (actuel) | `money_split_amounts`, `money_split_rules`, `commission_preview`, `commission_rate_for`, `commission_engine_set`, `lib/figma/live/ops.dart` (`commissionDialog`), `lib/figma/g/g_135.dart`, `lib/figma/live/admin_centre.dart` |
| 2 | Répartition 70/20/10 | A | à faire par le propriétaire | ☐ Garder 70/20/10 partout (actuel) · ☐ Autres pourcentages : ___/___/___ · ☐ Une règle par type d'opération · ☐ Plus de fonds institutionnel | `money_split_rules`, `money_split_get`, `money_split_set` (permission `finance.split`), `money_order_paid` |
| 3 | Assiette (brut/net) et arrondi | A | à faire par le propriétaire | ☐ Brut après remise (actuel) · ☐ Net de TVA · ☐ Net des frais d'opérateur · ☐ Arrondi au plus proche | `_money_rule_parts`, `money_split_amounts`, `commission_preview` (assiettes `gross`, `net_vat`, `net_fees` + pourcentage d) |
| 4 | Taux par type d'opération | A | à faire par le propriétaire | ☐ Taux unique · ☐ Un taux par type · ☐ Par vendeur/établissement · ☐ Rien | `commission.product/service/financing`, `commission_rate_for`, écran 135 |
| 5 | Frais de livraison | A | à faire par le propriétaire | ☐ 100 % vendeur (actuel) · ☐ Part plateforme · ☐ Coût réel transporteur · ☐ Gratuité au-delà de ___ FCFA | `money_order_paid` (ligne `delivery`), `institution_settings.home_delivery_fee` |
| 6 | Remboursement, réclamation, litige | A | à faire par le propriétaire | ☐ Intégral sans retenue (actuel) · ☐ Retenue ___ · ☐ Délai maximal ___ jours · ☐ Frais d'opérateur à la charge de ___ · ☐ Traitement du déficit : ___ | `money_remboursements`, `g4_remboursements_partiels` |
| 7 | Délai de garde | A | à faire par le propriétaire | ☐ 72 h (actuel) · ☐ Autre : ___ h · ☐ Par type | réglage `money.hold_hours` (1 à 720 h), `money_try_release` |
| 8 | Retrait : min, max, frais, délais | A | à faire par le propriétaire | ☐ La finance respecte aussi le seuil · ☐ Seuil sur le solde · ☐ Frais de retrait ___ · ☐ Retrait automatique · ☐ Rien | `request_seller_payout`, `payout_create`, `payouts.min/max`, `commission.payout_threshold` |
| 9 | Décaissement Mobile Money | A | à faire par le propriétaire | ☐ Manuel (actuel) · ☐ API MTN + rapprochement · ☐ Orange après contrat | `payout_set_status`, fonctions Edge `momo`, `momo-callback`, `payout_batches` ↔ `momo_transactions` (liaison à créer) |
| 10 | TVA et facture légale | A | à faire par le propriétaire | ☐ Reçus non fiscaux (actuel) · ☐ Facture avec TVA 19,25 % · ☐ Mentions légales de l'émetteur · ☐ Numérotation serveur | `InvoiceTotals` (`lib/figma/live/docs.dart`), `order_billing_get` |
| 11 | Frais de l'opérateur de paiement | A | à faire par le propriétaire | ☐ Plateforme · ☐ Client en supplément · ☐ Déduits de la part plateforme · ☐ Répartis | Edge `tara-pay`, `tara-webhook`, `payment_transactions.amount` |
| 12 | Forfaits et abonnements | A | à faire par le propriétaire | ☐ Rien (actuel) · ☐ Remboursement au prorata · ☐ TVA sur forfaits · ☐ Renouvellement automatique | `company_plans.price_fcfa`, `on_subscription_paid` |
| 13 | Rapprochement comptable | A | à faire par le propriétaire | ☐ Rapprochement quotidien · ☐ Export mensuel · ☐ Contrôle de cohérence · ☐ Rien | `finance_overview`, `finance_journal` |
| 14 | Texte des CGV | A | à faire par le propriétaire | ☐ Texte validé tel quel · ☐ Relecture juridique · ☐ Modifié (nouvelle version) | `lib/figma/live/legal.dart`, `kSalesTermsVersion` (`lib/figma/live/auth.dart`) |
| 15 | Version des CGU | A | à faire par le propriétaire | ☐ Inchangée `cgu-2026-10` (actuel) · ☐ Nouvelle version après texte validé | `kTermsVersion` (`lib/figma/live/auth.dart`) |
| 16 | Missions : 30/40/30, commission 10 %, gain 70 % codés en dur | B (+ A pour la future règle) | **B : fait en H8.** A (la règle des missions) : à faire par le propriétaire | ☐ Missions suivent la règle 70/20/10 · ☐ Taux propre (décision 4) · ☐ Pas de gain affiché tant que le serveur ne le calcule pas (**état actuel, connecté**) | `lib/figma/live/missions.dart` (`Mission.fee`, `studentEarned`, `knownAmountOf`, `amountLabel`, `pendingAmount`), `lib/figma/g/g_193.dart`, `g_201.dart` |
| 17 | Cadeaux de live (70/30, 1 crédit = 10 FCFA, max 50) | A | à faire par le propriétaire | ☐ Valeurs validées · ☐ Autres : ___ | `gift_settings` |
| 18 | Parrainage | A | à faire par le propriétaire | ☐ Seuil propre 1 000 FCFA (actuel) · ☐ Même seuil que l'écran 135 · ☐ Paliers modifiables en administration | `20261101000400_parrainage_gains.sql`, `20261115170000_l7_parrainage_social_lives_defis.sql` |
| 19 | Plafond des taux (30 %) | A | à faire par le propriétaire | ☐ 30 % (actuel) · ☐ Autre plafond : ___ % | `_h7_commission_settings_check`, `commission_rate_for` (0 à 30), validation de l'écran 135 |

### Ce que H8 a corrigé (type B)

- **Décision 16** : une mission du serveur n'affiche plus ni répartition 30/40/30, ni commission 10 %, ni gain étudiant 70 % inventés. Montants de jalon = ceux du serveur, sinon « — » ; commission et gain = « — » (calculés à l'encaissement). L'aperçu hors connexion garde ses estimations. Test : `test/journey/h8_missions_sans_taux_test.dart`. Aucune règle changée ; `money_split_get` n'a pas de lecture côté missions (le serveur n'écrit aucune ligne « mission » dans le séquestre).
- **Décision 1 (message)** : la tuile « Commissions et règles économiques » du centre admin ne dit plus « Règles de répartition appliquées » (faux pour les taux). L'écran 135 connecté disait déjà « taux journalisés, non appliqués » (H7).
- Décisions 11 et 10 : « Frais de paiement 1,5 % » et « Taxes applicables » n'apparaissent qu'en démonstration (`g_260.dart`, `show: demoContent`) : rien à corriger.

## Préparation technique des taux (migration `20261124040000_h8_commission_previsualisation.sql`)

Déjà en place, **sans effet sur les calculs réels** : `commission_rate_for(kind)` (taux enregistré ou null), `commission_preview(montant, kind, assiette, déduction)` (simulation des hypothèses A, B, C de la décision 1 à côté de la répartition actuelle), interrupteur `commission.engine_enabled` (false par défaut, administrateur global + 2FA, audité niveau Critique, lu par **aucun** calcul). Preuve : `supabase/tests/marketplace_pglite/h8_commissions.mjs` (90/90).

## Procédure d'activation des taux (une fois les décisions 1, 3 et 4 approuvées)

Ne rien exécuter avant l'approbation écrite du propriétaire. Tout se fait sur une copie, puis en production selon `REPRISE_OPENCODE.md` (sauvegarde, migration, déploiement, vérification).

1. **Simuler** (lecture seule, finance) : `select commission_preview(10000, 'product', 'gross', null);` pour chaque type et chaque assiette ; comparer `current` aux hypothèses `replace_platform` (A), `additional_levy` (B), `replace_split` (C). Les assiettes nettes exigent le pourcentage de déduction décidé (décisions 3 et 11).
2. **Enregistrer les taux** (admin, écran 135 ou `setting_set('commission.product', 5)` …) : entiers 0 à 30. Vérifier avec `commission_rate_for`.
3. **Point d'insertion unique** : nouvelle migration (jamais de modification d'une migration existante) qui redéfinit `money_split_amounts` en plaçant **comme première instruction** :
   ```sql
   if _commission_engine_enabled() then
     -- calcul de l'option approuvée (A, B ou C), lisant commission_rate_for-équivalent interne ; return;
   end if;
   ```
   Le reste de la fonction (lecture de `money_split_rules`, 70/20/10) reste intact : c'est le chemin « interrupteur éteint ». Contraintes à traiter dans cette migration : `money_split_amounts(p_gross)` ne reçoit pas le type → ajouter un paramètre `p_kind text default null` (null = règle actuelle) transmis par `money_order_paid` et la clôture des campagnes ; `commission_preview` appelle aussi `money_split_amounts` pour sa colonne `current` : ce paramètre doit rester nul dans cet appel, sinon « current » changerait avec l'interrupteur. Garder `money_split_rules` inchangée ; ne jamais réécrire les lignes `money_entries` existantes.
4. **Prouver** : ajouter à `h8_commissions.mjs` (ou à `h7_facturation.mjs`) les cas chiffrés : interrupteur éteint → 70/20/10 inchangé ; allumé → montants de la simulation ; anciennes lignes non réécrites ; refus d'activation hors administrateur global. Rejouer le scénario : `node replay.mjs all ./h8_commissions.mjs`, compter les lignes ECHEC/KO.
5. **Activer** : en tant qu'administrateur global (2FA active) : `select commission_engine_set(true);` (écriture auditée Critique). Mettre à jour en même temps le message de l'écran 135 (`ops.dart`), la tuile du centre admin, le texte des CGV (décision 14) et la facture.
6. **Retour arrière immédiat** : `select commission_engine_set(false);` : la première instruction ne s'exécute plus, la répartition revient à `money_split_rules`, sans migration. Les paiements déjà répartis sous le nouveau régime restent tels quels (aucune réécriture) ; les suivants reprennent 70/20/10.
7. **Retour arrière complet de H8** (avant toute activation) : voir l'en-tête de la migration `20261124040000` (`drop trigger trg_h8_commission_engine …`, `drop function …`, `delete from platform_settings where key = 'commission.engine_enabled'`).

## Réponse du propriétaire (21 novembre 2026)

Pour les 19 décisions, le propriétaire a choisi de **garder les valeurs actuelles** (cases « actuel » : 70/20/10, garde 72 h, assiette brute après remise, frais de livraison 100 % vendeur, reçus non fiscaux, remboursement intégral, retrait manuel, parrainage à seuil propre, plafond de taux 30 %, versions CGU/CGV inchangées). **Aucune règle financière n'est modifiée ni activée** : l'interrupteur `commission.engine_enabled` reste à faux ; les taux de commission enregistrés restent non appliqués aux calculs. Toute évolution (taux par type d'opération, TVA, frais d'opérateur, texte des CGV/CGU) reste à décider explicitement par le propriétaire.
