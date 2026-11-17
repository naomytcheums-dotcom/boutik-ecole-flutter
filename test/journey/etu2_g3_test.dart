import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider, CartLine;
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/marche_screens.dart';
import 'package:boutik_ecole/figma/live/order_summary.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot G3 (commande, paiement, livraison, retrait) : statuts de commande fidèles à l'état réel, cibles de toucher de 48 dp à 390 px.
void main() {
  setUpAll(loadAppFonts);
  tearDown(() {
    Backend.ready = false;
    GAnim.enabled = true;
  });

  const pickup = Order(id: '#BE-2026-0200', date: '1 nov. 2026', lines: [], subtotal: 5000, fee: 0, method: 'Mobile Money', reference: 'x', status: 2, paid: true);
  const home = Order(id: '#BE-2026-0201', date: '1 nov. 2026', lines: [], subtotal: 5000, fee: 1000, method: 'Mobile Money', reference: 'x', status: 2, paid: true, home: true);

  group('statut de commande', () {
    test('connecté : « prête » n\'est jamais présentée comme « expédiée » pour un retrait sur campus', () {
      Backend.ready = true;
      expect(orderStatusLabel(pickup), 'Prête à retirer');
      expect(orderStatusLabel(home), 'Prête à livrer');
      expect(orderStepLabel(pickup, 3), 'Livrée');
      expect(orderStepLabel(pickup, 0), 'Confirmée');
    });

    test('commande annulée ou en attente de paiement : le statut le dit', () {
      Backend.ready = true;
      expect(orderStatusLabel(pickup.copyWith(cancelled: true)), 'Annulée');
      expect(orderStatusLabel(pickup.copyWith(paid: false)), 'En attente de paiement');
    });

    test('hors connexion (démonstration) : libellés de la maquette conservés', () {
      Backend.ready = false;
      expect(orderStatusLabel(pickup), 'Expédiée');
    });
  });

  Future<void> monter(WidgetTester t, Widget w) async {
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: w))));
    await t.pumpAndSettle();
  }

  testWidgets('case des conditions de vente : zone de toucher d\'au moins 48 dp, bascule réelle', (t) async {
    await monter(t, const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: OrderTermsCheck()));
    final zone = t.getSize(find.byType(OrderTermsCheck));
    expect(zone.height, greaterThanOrEqualTo(48));
    final c = ProviderScope.containerOf(t.element(find.byType(OrderTermsCheck)));
    expect(c.read(orderTermsProvider), isFalse);
    await t.tap(find.byType(OrderTermsCheck));
    await t.pump();
    expect(c.read(orderTermsProvider), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('panier par boutique à 390 px : boutons quantité et retrait de 48 dp, aucun débordement', (t) async {
    late ProviderContainer c;
    await monter(t, Consumer(builder: (ctx, ref, _) {
      c = ProviderScope.containerOf(ctx);
      return const CartByShopScreen();
    }));
    while (c.read(cartProvider).isNotEmpty) {
      c.read(cartProvider.notifier).remove(0);
    }
    c.read(cartProvider.notifier).add(const CartLine('Lampe en bois recyclé très longue désignation', 'Boutique : Atelier A', 125000, ''));
    await t.pump();
    for (final tip in ['Moins', 'Plus', 'Retirer']) {
      final s = t.getSize(find.byTooltip(tip).first);
      expect(s.width, greaterThanOrEqualTo(48), reason: tip);
      expect(s.height, greaterThanOrEqualTo(48), reason: tip);
    }
    expect(t.takeException(), isNull);
  });
}
