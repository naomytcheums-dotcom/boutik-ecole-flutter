import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/live/marche/marche_promotions.dart';
import 'package:boutik_ecole/figma/live/marche/marche_screens.dart';
import 'package:boutik_ecole/figma/live/promo_state.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('hors connexion, aucune réduction : le total reste celui du panier', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final t = c.read(totalsProvider);
    expect(t.discount, 0);
    expect(t.total, t.subtotal + t.fee);
  });

  test('libellé de réduction', () {
    expect(promoValueLabel({'kind': 'percent', 'value': 15}), '−15 %');
    expect(promoValueLabel({'kind': 'fixed', 'value': 2000}), '−2000 FCFA');
  });

  testWidgets('admin : liste des promotions avec période, réduction et état', (t) async {
    await _pump(t, const PromotionsAdminScreen(), overrides: [
      marchePlatformPromosProvider.overrideWith((ref) async => [
            {'id': '1', 'label': 'Nouvel An', 'code': 'NOUVELAN', 'kind': 'percent', 'value': 15, 'min_amount': 0, 'starts_at': '2026-12-28T00:00:00Z', 'ends_at': '2027-01-05T00:00:00Z', 'active': true, 'auto_apply': true, 'used_count': 3},
            {'id': '2', 'label': 'Pâques', 'code': 'PAQUES', 'kind': 'fixed', 'value': 2000, 'min_amount': 10000, 'starts_at': '2027-04-01T00:00:00Z', 'ends_at': '2027-04-06T00:00:00Z', 'active': false, 'auto_apply': false, 'used_count': 0},
          ]),
    ]);
    expect(find.text('Nouvel An'), findsOneWidget);
    expect(find.text('−15 %'), findsOneWidget);
    expect(find.textContaining('Code NOUVELAN'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Désactivée'), findsOneWidget);
    expect(find.text('Désactiver'), findsOneWidget);
    expect(find.text('Activer'), findsOneWidget);
    expect(find.text('Nouvelle promotion'), findsOneWidget);
  });

  testWidgets('panier : promotion automatique = champ verrouillé, rempli, sans bouton Appliquer', (t) async {
    await _pump(t, const CartByShopScreen(), overrides: [
      marcheAutoPromoProvider.overrideWith((ref) async => {'code': 'NOUVELAN', 'label': 'Nouvel An', 'kind': 'percent', 'value': 15}),
    ]);
    expect(find.textContaining('Promotion « Nouvel An » appliquée automatiquement : −15 %'), findsOneWidget);
    expect(find.text('Appliquer'), findsNothing, reason: 'le client ne peut pas changer le code');
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    final field = t.widget<TextFormField>(find.byType(TextFormField));
    expect(field.initialValue, 'NOUVELAN');
    expect(t.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });
}
