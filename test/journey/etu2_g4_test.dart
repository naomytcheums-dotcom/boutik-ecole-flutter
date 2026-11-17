import 'package:boutik_ecole/core/utils/money.dart';
import 'package:boutik_ecole/features/nouveaux/s260_facture/facture_screen.dart';
import 'package:boutik_ecole/features/nouveaux/s284_registre_financier/registre_financier_screen.dart';
import 'package:boutik_ecole/features/y_missions/s197_valider_jalon/valider_jalon_screen.dart';
import 'package:boutik_ecole/figma/g/g_66.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/impact.dart' show RpcMap;
import 'package:boutik_ecole/figma/live/money_admin.dart' show splitRuleProvider;
import 'package:boutik_ecole/figma/live/vendeur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Map extends RpcMap {
  _Map(super.fn, this.v);
  final Map<String, dynamic>? v;
  @override
  Map<String, dynamic>? build() => v;
}

const _base = {
  'total': 100000, 'paid_out': 0, 'scheduled': 0, 'requested': 0, 'available': 0, 'orders': 3, 'pending_count': 0, 'pending_amount': 0,
  'months': [], 'weeks': [],
};

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  group('règle de répartition', () {
    test('SplitRule.fromServer : lue telle quelle, refusée si incohérente', () {
      final r = SplitRule.fromServer({'beneficiary_pct': 60, 'institution_pct': 25, 'platform_pct': 15});
      expect(r?.label, '60 / 25 / 15');
      expect(SplitRule.fromServer({'beneficiary_pct': 60, 'institution_pct': 25, 'platform_pct': 10}), isNull);
      expect(SplitRule.fromServer({'beneficiary_pct': 100}), isNull);
      expect(SplitRule.fromServer(null), isNull);
    });

    test('splitPayment : suit la règle fournie, le reliquat va à la plateforme', () {
      final s = splitPayment(10001, const SplitRule(60, 25, 15));
      expect((s.seller, s.institution, s.platform), (6000, 2500, 1501));
      expect(s.seller + s.institution + s.platform, 10001);
    });
  });

  Future<void> monter(WidgetTester t, Widget ecran, {bool connecte = true, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  testWidgets('66 : la règle affichée vient du serveur, base « hors livraison », aucun 70/20/10 ni 72 h en dur', (t) async {
    await monter(t, const G_66(), overrides: [
      sellerRevenueProvider.overrideWith(() => _Map('seller_revenue', {..._base, 'rule': '60/25/15', 'hold_hours': 48})),
    ]);
    expect(find.textContaining('règle 60/25/15'), findsOneWidget);
    expect(find.textContaining('hors livraison'), findsOneWidget);
    expect(find.textContaining('48 h'), findsOneWidget);
    expect(find.textContaining('70/20/10'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('66 : sans règle ni délai lus, libellé neutre (rien d’inventé)', (t) async {
    await monter(t, const G_66(), overrides: [sellerRevenueProvider.overrideWith(() => _Map('seller_revenue', {..._base, 'hold_hours': 0}))]);
    expect(find.textContaining('règle de répartition en vigueur'), findsOneWidget);
    expect(find.textContaining('le délai prévu'), findsOneWidget);
    expect(find.textContaining('70/20/10'), findsNothing);
    expect(find.textContaining('72 h'), findsNothing);
    expect(t.takeException(), isNull);
  });

  group('écrans de ventilation (390 px)', () {
    final regle = splitRuleProvider.overrideWith((ref) async => const SplitRule(60, 25, 15));
    final inconnue = splitRuleProvider.overrideWith((ref) async => null);

    testWidgets('facture : pourcentages de la règle lue', (t) async {
      await monter(t, const FactureScreen(), overrides: [regle]);
      expect(find.textContaining('(60 %)'), findsOneWidget);
      expect(find.textContaining('(25 %)'), findsOneWidget);
      expect(find.textContaining('(15 %)'), findsOneWidget);
      expect(find.textContaining('(70 %)'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('registre : règle illisible, aucun montant ventilé', (t) async {
      await monter(t, const RegistreFinancierScreen(), overrides: [inconnue]);
      expect(find.text('Règle en cours de lecture'), findsOneWidget);
      expect(find.textContaining('Part étudiants'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('registre : règle lue', (t) async {
      await monter(t, const RegistreFinancierScreen(), overrides: [regle]);
      expect(find.textContaining('Part étudiants (60 %)'), findsOneWidget);
      expect(find.textContaining('60 / 25 / 15'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('valider le jalon : parts selon la règle lue', (t) async {
      await monter(t, const ValiderJalonScreen(), overrides: [regle]);
      expect(find.textContaining('Part étudiants (60 %)'), findsOneWidget);
      expect(find.textContaining('Plateforme (15 %)'), findsOneWidget);
      expect(find.textContaining('(70 %)'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
