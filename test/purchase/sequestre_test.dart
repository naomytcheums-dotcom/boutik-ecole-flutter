import 'package:boutik_ecole/figma/live/money_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('montants et états lisibles', () {
    expect(moneyFcfa(7000), '7 000 FCFA');
    expect(moneyFcfa(1250000), '1 250 000 FCFA');
    expect(moneyFcfa(null), '0 FCFA');
    expect(moneyStatusLabel('held'), 'En séquestre');
    expect(moneyStatusLabel('frozen'), 'Bloqué');
    expect(moneyStatusLabel('cod_due'), 'À recouvrer');
    expect(moneyStatuses.keys, ['', 'held', 'frozen', 'released', 'cod_due', 'refunded']);
  });

  testWidgets('séquestre : vue d’ensemble, règle et lignes', (t) async {
    await _pump(t, const MoneyAdminScreen(), overrides: [
      moneyOverviewProvider.overrideWith((ref) async => {'rule': '70/20/10', 'held': 20000, 'frozen': 5000, 'released_beneficiaries': 14000, 'institution_fund': 6000, 'platform': 3000, 'cod_due': 900}),
      moneyRuleProvider.overrideWith((ref) async => {
            'current': {'beneficiary_pct': 70, 'institution_pct': 20, 'platform_pct': 10},
            'history': [],
          }),
      moneyEntriesProvider('held').overrideWith((ref) async => [
            {'id': 'e1', 'ref': '#BE-2026-0001', 'kind': 'order', 'gross': 10000, 'beneficiary': 'Awa V.', 'beneficiary_amount': 7000, 'institution_amount': 2000, 'platform_amount': 1000, 'split': '70/20/10', 'status': 'held', 'frozen_reason': null},
          ]),
    ]);
    expect(find.text('Séquestre'), findsOneWidget);
    expect(find.text('20 000 FCFA'), findsOneWidget);
    expect(find.text('Règle : 70 % étudiant · 20 % institution · 10 % plateforme'), findsOneWidget);
    expect(find.text('#BE-2026-0001 · 10 000 FCFA'), findsOneWidget);
    expect(find.text('En séquestre'), findsWidgets);
    expect(find.textContaining('Awa V. : 7 000 FCFA'), findsOneWidget);
  });
}
