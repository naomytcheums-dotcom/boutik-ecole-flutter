import 'package:boutik_ecole/data/demo/section_a_demo.dart';
import 'package:boutik_ecole/figma/g/g_29.dart';
import 'package:boutik_ecole/figma/g/g_45.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _NoOrders extends Orders {
  @override
  List<Order> build() => const [];
}

class _OneOrder extends Orders {
  @override
  List<Order> build() => const [
        Order(id: '#BE-2026-0161', date: '30 oct. 2026', lines: [CartLine('Casque audio', 'Département : GE', 30000, 'placeholder', qty: 2)], subtotal: 60000, fee: 0, method: 'Mobile Money', reference: '', status: 1, paid: true),
      ];
}

Future<void> _pump(WidgetTester tester, Widget screen, Orders Function() orders) async {
  GAnim.enabled = false;
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [ordersProvider.overrideWith(orders)], child: MaterialApp(home: Scaffold(body: screen))));
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => Backend.ready = true);
  tearDown(() => Backend.ready = false);

  testWidgets('compte réel sans commande : message clair, pas de « 8 commandes » ni de lignes fictives', (tester) async {
    await _pump(tester, const G_45(), _NoOrders.new);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('pas encore de commande'), findsOneWidget);
    expect(find.text('8 commandes'), findsNothing);
    expect(find.text('0 commande'), findsOneWidget);
  });

  testWidgets('compte réel avec une commande : liste et détail montrent les données du serveur', (tester) async {
    await _pump(tester, const G_45(), _OneOrder.new);
    expect(find.text('#BE-2026-0161'), findsOneWidget);
    expect(find.text('1 commande'), findsOneWidget);
    await _pump(tester, const G_29(), _OneOrder.new);
    expect(find.text('#BE-2026-0161'), findsOneWidget);
    expect(find.text('Casque audio'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text(fcfa(60000)), findsWidgets);
    expect(find.text('Sac à dos design'), findsNothing);
  });
}
