import 'package:boutik_ecole/figma/g/g_108.dart';
import 'package:boutik_ecole/figma/g/g_123.dart';
import 'package:boutik_ecole/figma/g/g_127.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/overview.dart';
import 'package:boutik_ecole/figma/live/store.dart' show fcfa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Écran 108 : chiffre d'affaires lu sur le serveur (fonction platform_overview, testée sur la base locale isolée par
/// supabase/tests/vue_ensemble_local.sql) ; jamais le chiffre de la maquette quand l'application est connectée.
class _Vue extends OverviewNotifier {
  _Vue(this.v);
  final Overview? v;
  @override
  Overview? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  Future<void> monter(WidgetTester t, {required bool connecte, Overview? vue, Widget ecran = const G_108()}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [overviewProvider.overrideWith(() => _Vue(vue))], child: MaterialApp(home: Scaffold(body: ecran))));
    await t.pumpAndSettle();
  }

  test('lecture de la vue serveur', () {
    final o = Overview.fromJson({'students': 75, 'sellers': 25, 'listings_approved': 11, 'listings_pending': 2, 'orders': 52, 'orders_paid': 34, 'paid_revenue': 980500});
    expect([o.students, o.sellers, o.orders, o.ordersPaid, o.paidRevenue], [75, 25, 52, 34, 980500]);
    expect(overviewRevenue(o), fcfa(980500));
    expect(overviewRevenueK(o), '981 k');
    expect(overviewRevenue(null), '—');
  });

  testWidgets('108 connecté : le chiffre d\'affaires est celui du serveur', (t) async {
    await monter(t, connecte: true, vue: const Overview(students: 75, sellers: 25, listingsApproved: 11, listingsPending: 2, orders: 52, ordersPaid: 34, paidRevenue: 980500));
    expect(find.text(fcfa(980500)), findsOneWidget);
    expect(find.text('981 k'), findsOneWidget);
    expect(find.text(fcfa(4820000)), findsNothing);
    expect(find.text('Dr Mbarga'), findsNothing);
  });

  testWidgets('108 connecté, chiffres non lus : « — » plutôt qu\'un montant de maquette', (t) async {
    await monter(t, connecte: true);
    expect(find.text('—'), findsWidgets);
    expect(find.text(fcfa(4820000)), findsNothing);
  });

  testWidgets('108 hors connexion : la démonstration de la maquette reste affichée', (t) async {
    await monter(t, connecte: false);
    expect(find.text('Dr Mbarga'), findsOneWidget);
  });

  const vue = Overview(students: 75, sellers: 25, listingsApproved: 11, listingsPending: 2, orders: 52, ordersPaid: 34, paidRevenue: 980500);

  testWidgets('123 connecté : chiffre d’affaires, commandes et vendeurs viennent du serveur', (t) async {
    await monter(t, connecte: true, vue: vue, ecran: const G_123());
    expect(find.text(fcfa(980500)), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('1 482'), findsNothing);
    expect(find.textContaining('28 400 000'), findsNothing);
  });

  testWidgets('127 connecté : volume des transactions du serveur, jamais 182 500 000', (t) async {
    await monter(t, connecte: true, vue: vue, ecran: const G_127());
    expect(find.text(fcfa(980500)), findsOneWidget);
    expect(find.textContaining('182 500 000'), findsNothing);
  });

  testWidgets('123 hors connexion : démonstration conservée', (t) async {
    await monter(t, connecte: false, ecran: const G_123());
    expect(find.text('1 482'), findsOneWidget);
  });
}
