import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/premium_pub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

class _Ent extends EntitlementsNotifier {
  _Ent(this.v);
  final Map<String, dynamic> v;
  @override
  Map<String, dynamic>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {List<Override> overrides = const []}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
    await t.pumpAndSettle();
  }

  final plans = [
    {'code': 'gratuit', 'name': 'Gratuit', 'audience': 'Tous', 'price_xaf': 0, 'period_days': 30, 'features': <String>[], 'active': true},
    {'code': 'vendeur_pro', 'name': 'Vendeur professionnel', 'audience': 'Vendeurs', 'price_xaf': null, 'period_days': 30, 'features': ['boost_campagnes'], 'active': true},
    {'code': 'entreprise', 'name': 'Entreprise', 'audience': 'Entreprises', 'price_xaf': 15000, 'period_days': 30, 'features': ['stats_avancees'], 'active': true},
  ];

  testWidgets('offres : prix à définir tant que non fixé, jamais de prix inventé', (t) async {
    await monter(t, const PlansScreen(), overrides: [plansProvider.overrideWith(() => _Rows('table:plans', plans)), entitlementsProvider.overrideWith(() => _Ent(const {'subscriptions': [], 'features': []}))]);
    expect(find.text('Tarif non défini'), findsWidgets);
    expect(find.text('Gratuit'), findsWidgets);
    expect(find.textContaining('15'), findsWidgets);
    expect(find.text('Campagnes sponsorisées'), findsOneWidget);
  });

  testWidgets('offres : un abonnement en vigueur est listé avec son état', (t) async {
    await monter(t, const PlansScreen(), overrides: [
      plansProvider.overrideWith(() => _Rows('table:plans', plans)),
      entitlementsProvider.overrideWith(() => _Ent(const {'subscriptions': [{'plan': 'entreprise', 'status': 'active', 'period_end': '2026-12-01T10:00:00Z', 'name': 'Entreprise'}], 'features': ['stats_avancees']})),
    ]);
    expect(find.textContaining('Entreprise · actif'), findsOneWidget);
    expect(find.text('Annuler à la fin de la période'), findsOneWidget);
  });

  testWidgets('campagnes : liste avec statistiques réelles et bouton de paiement du budget', (t) async {
    await monter(t, const AdsScreen(), overrides: [
      myAdsProvider.overrideWith(() => _Rows('my_ad_campaigns', [
            {'id': 'a1', 'title': 'Ma promo', 'status': 'draft', 'budget': 5000, 'spent': 0, 'review_note': null, 'payment_id': null, 'impressions': 0, 'clicks': 0, 'ctr': null},
            {'id': 'a2', 'title': 'Campagne active', 'status': 'active', 'budget': 10000, 'spent': 500, 'review_note': null, 'payment_id': null, 'impressions': 40, 'clicks': 4, 'ctr': 10.0},
          ]))
    ]);
    expect(find.text('Ma promo'), findsOneWidget);
    expect(find.text('Payer le budget'), findsOneWidget);
    expect(find.text('Mettre en pause'), findsOneWidget);
    expect(find.textContaining('40 impressions · 4 clics · 10.0 % de clics'), findsOneWidget);
  });

  testWidgets('campagnes à valider : seules les campagnes en attente', (t) async {
    await monter(t, const AdReviewScreen(), overrides: [
      pendingAdsProvider.overrideWith(() => _Rows('table:ad_campaigns', [
            {'id': 'a1', 'title': 'À valider', 'body': 'x', 'budget_xaf': 5000, 'status': 'pending_review', 'created_at': '2026-11-01T10:00:00Z'},
            {'id': 'a2', 'title': 'Déjà active', 'body': 'x', 'budget_xaf': 5000, 'status': 'active', 'created_at': '2026-11-01T10:00:00Z'},
          ]))
    ]);
    expect(find.text('À valider'), findsOneWidget);
    expect(find.text('Déjà active'), findsNothing);
    expect(find.text('Valider'), findsOneWidget);
  });

  testWidgets('publicité du fil : toujours marquée Sponsorisé', (t) async {
    await monter(t, const Scaffold(body: SponsoredCard(ad: {'id': 'a1', 'title': 'Promo test', 'body': 'Texte', 'owner': 'Alice Test', 'sponsored': true})));
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.text('Promo test'), findsOneWidget);
  });

  test('libellés des états de campagne', () {
    expect(adStatus('pending_review'), 'En attente de validation');
    expect(adStatus('awaiting_payment'), 'Paiement du budget en attente');
  });
}
