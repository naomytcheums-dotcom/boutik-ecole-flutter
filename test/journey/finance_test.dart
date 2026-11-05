import 'package:boutik_ecole/figma/g/g_139.dart';
import 'package:boutik_ecole/figma/g/g_140.dart';
import 'package:boutik_ecole/figma/g/g_141.dart';
import 'package:boutik_ecole/figma/g/g_142.dart';
import 'package:boutik_ecole/figma/g/g_143.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/finance.dart';
import 'package:boutik_ecole/figma/live/impact.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v, {this.fail = false});
  final List<Map<String, dynamic>>? v;
  final bool fail;
  @override
  List<Map<String, dynamic>>? build() {
    error = fail;
    return v;
  }
}

class _Journal extends JournalRows {
  _Journal(this.v, this.t);
  final List<Map<String, dynamic>> v;
  final Map<String, dynamic> t;
  @override
  List<Map<String, dynamic>>? build() {
    totals = t;
    return v;
  }
}

class _Map extends RpcMap {
  _Map(super.fn, this.v);
  final Map<String, dynamic>? v;
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

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés et ancienneté', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(paymentState('to_verify'), 'À vérifier');
    expect(payoutStatus('verse'), 'Versé');
    expect(agoLabel(DateTime(2026, 11, 5, 10).toUtc().toIso8601String(), now), 'Il y a 2 h');
    expect(agoLabel(DateTime(2026, 11, 4, 10).toUtc().toIso8601String(), now), 'Hier');
  });

  testWidgets('140 connecté : paiements déclarés réels avec compteurs', (t) async {
    await monter(t, const G_140(), connecte: true, overrides: [
      financePaymentsProvider.overrideWith(() => _Rows('finance_payments', [
            {'reference': 'MP-1', 'order': 'BE-2026-1', 'method': 'Orange Money', 'amount': 25000, 'declared_at': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(), 'state': 'to_verify'},
            {'reference': 'MP-2', 'order': 'BE-2026-2', 'method': 'Mobile Money', 'amount': 8000, 'declared_at': null, 'state': 'verified'},
          ]))
    ]);
    expect(find.text('MP-1'), findsOneWidget);
    expect(find.text('Il y a 2 h'), findsOneWidget);
    expect(find.text('À vérifier (1)'), findsOneWidget);
    expect(find.text('Vérifiés (1)'), findsOneWidget);
    expect(find.text('TX-88420'), findsNothing);
  });

  testWidgets('140 connecté sans droit : message d’accès, aucune ligne de maquette', (t) async {
    await monter(t, const G_140(), connecte: true, overrides: [financePaymentsProvider.overrideWith(() => _Rows('finance_payments', const [], fail: true))]);
    expect(find.textContaining('Accès réservé'), findsWidgets);
    expect(find.text('TX-88420'), findsNothing);
  });

  testWidgets('141 connecté : journal réel et synthèse calculée', (t) async {
    await monter(t, const G_141(), connecte: true, overrides: [
      financeJournalProvider.overrideWith(() => _Journal([
            {'date': '2026-11-04', 'label': 'Encaissement BE-1', 'debit': 0, 'credit': 25000, 'reconciled': true},
            {'date': '2026-11-05', 'label': 'Reversement RV-1000', 'debit': 10000, 'credit': 0, 'reconciled': false},
          ], const {'total_credit': 25000, 'total_debit': 10000, 'to_reconcile': 1}))
    ]);
    expect(find.text('Encaissement BE-1'), findsOneWidget);
    expect(find.text('Solde'), findsOneWidget);
    expect(find.text('Encaissement #0142'), findsNothing);
    expect(find.text('Lignes à rapprocher'), findsOneWidget);
  });

  testWidgets('143 connecté : lots de reversement réels, jamais de vendeur de maquette', (t) async {
    await monter(t, const G_143(), connecte: true, overrides: [
      financeOverviewProvider.overrideWith(() => _Map('finance_overview', const {'paid_out_30d': 10000, 'due': 15000, 'collected': 0, 'orders_paid': 0, 'to_verify': 0, 'months': []})),
      financePayoutsProvider.overrideWith(() => _Rows('finance_payouts', [{'number': 'RV-1000', 'seller': 'Alice Test', 'amount': 15000, 'method': 'Orange Money', 'date': '2026-11-05', 'status': 'prevu'}]))
    ]);
    expect(find.text('RV-1000'), findsOneWidget);
    expect(find.text('Prévu'), findsOneWidget);
    expect(find.text('Yannick Mouanga'), findsNothing);
  });

  testWidgets('139 connecté : tableau de bord calculé, aucun chiffre de maquette', (t) async {
    await monter(t, const G_139(), connecte: true, overrides: [
      financeOverviewProvider.overrideWith(() => _Map('finance_overview', const {'collected': 980500, 'orders_paid': 34, 'to_verify': 2, 'due': 15000, 'paid_out_30d': 10000, 'months': [{'month': '2026-11', 'amount': 980500}]}))
    ]);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('Paiements à vérifier'), findsWidgets);
    expect(find.textContaining('+ 5 100 000'), findsNothing);
  });

  testWidgets('142 connecté : ventes par département réelles', (t) async {
    await monter(t, const G_142(), connecte: true, overrides: [
      financeByDepartmentProvider.overrideWith(() => _Rows('finance_by_department', [{'department': 'Informatique', 'sales': 170000, 'orders': 9, 'sellers': 4}]))
    ]);
    expect(find.text('Informatique'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('M. Essono'), findsNothing);
  });

  for (final c in <(String, Widget, String)>[('140', const G_140(), 'TX-88420'), ('141', const G_141(), 'Encaissement #0142'), ('143', const G_143(), 'RV-1204'), ('142', const G_142(), 'M. Essono')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
