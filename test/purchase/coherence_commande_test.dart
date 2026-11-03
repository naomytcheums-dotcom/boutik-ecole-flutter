import 'package:boutik_ecole/figma/g/g_03.dart';
import 'package:boutik_ecole/figma/gen.dart' show GPos;
import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/order_summary.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Cohérence de la chaîne de commande (D-011, D-082, D-083), onglet Messages (D-005) et message d'erreur visiteur (D-024).
/// Cas de contre-recette NR-001 à NR-006, NR-011, NR-016 et NR-022 ; paniers de test fictifs, aucun paiement.
void main() {
  setUp(() => GAnim.enabled = false);

  GoRouter router(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first));

  ProviderContainer container(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(MaterialApp)));

  testWidgets('NR-002 : retrait sur campus, 42 et 08 affichent le même total, sans frais', (t) async {
    await pumpScreen(t, '08');
    final c = container(t);
    final total = c.read(totalsProvider);
    expect(total.fee, 0);
    expect(total.total, 325000);
    expect(find.text(fcfa(325000)), findsWidgets);

    router(t).go('/s/42');
    await t.pumpAndSettle();
    // sous-total et total identiques, livraison gratuite, plus aucune ligne figée de la maquette
    expect(find.text(fcfa(325000)), findsNWidgets(2));
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text(fcfa(330000)), findsNothing);
    expect(find.text(fcfa(5000)), findsNothing);
    expect(find.text('Retrait sur campus'), findsOneWidget);
  });

  testWidgets('NR-003 : livraison avec frais, 42 et 08 affichent les mêmes frais et le même total', (t) async {
    await pumpScreen(t, '08');
    final c = container(t);
    c.read(homeDeliveryProvider.notifier).set(true);
    await t.pumpAndSettle();
    final total = c.read(totalsProvider);
    expect(total.fee, 5000);
    expect(find.text(fcfa(total.total)), findsWidgets);

    router(t).go('/s/42');
    await t.pumpAndSettle();
    expect(find.text(fcfa(5000)), findsOneWidget);
    expect(find.text(fcfa(330000)), findsOneWidget);
    expect(find.text('Livraison à domicile'), findsOneWidget);
  });

  testWidgets('NR-001 : 43 affiche le montant à payer du panier, sans référence inventée', (t) async {
    await pumpScreen(t, '43');
    expect(find.text(fcfa(325000)), findsOneWidget);
    expect(find.text(fcfa(330000)), findsNothing);
    expect(find.text('Attribuée à la validation'), findsOneWidget);
    expect(find.textContaining('BE-2026-0142'), findsNothing);
  });

  testWidgets('NR-006 : 43 reprend le montant et la référence de la commande créée', (t) async {
    await pumpScreen(t, '43');
    final c = container(t);
    final o = c.read(ordersProvider.notifier).place();
    await t.pumpAndSettle();
    expect(find.text(fcfa(o.total)), findsOneWidget);
    expect(find.text(o.id.replaceFirst('#', '')), findsOneWidget);
  });

  testWidgets('NR-011 : un seul statut sur le suivi (46) et l\'annulation (47) pour une commande', (t) async {
    await pumpScreen(t, '46');
    final c = container(t);
    final o = c.read(ordersProvider.notifier).place();
    await t.pumpAndSettle();
    expect(find.text('Confirmée'), findsNWidgets(2));
    expect(find.text('En route'), findsNothing);
    expect(find.text('Remise au transporteur'), findsNothing);

    c.read(ordersProvider.notifier).advance(o.id);
    await t.pumpAndSettle();
    // badge « En préparation » + étape « En préparation » ; « Confirmée » n'est plus que le nom d'une étape terminée
    expect(find.text('En préparation'), findsNWidgets(2));
    expect(find.text('Confirmée'), findsOneWidget);

    router(t).go('/s/47');
    await t.pumpAndSettle();
    expect(find.text('En préparation'), findsOneWidget);
    expect(find.text('Confirmée'), findsNothing);
  });

  testWidgets('NR-007 : 29 et 09 affichent toutes les lignes de la même commande, avec le même total', (t) async {
    await pumpScreen(t, '29');
    final c = container(t);
    final lines = c.read(cartProvider);
    expect(lines.length, 3);
    final o = c.read(ordersProvider.notifier).place();
    await t.pumpAndSettle();
    // 29 : liste défilante, les trois articles et le total de la commande
    expect(find.text(lines.first.title), findsOneWidget);
    expect(find.text(fcfa(o.total)), findsWidgets);
    final liste = find.byType(ListView);
    for (final l in lines) {
      await t.scrollUntilVisible(find.text(l.title), 40, scrollable: find.descendant(of: liste.first, matching: find.byType(Scrollable)).first);
      expect(find.text(l.title), findsOneWidget);
    }
    router(t).go('/s/09');
    await t.pumpAndSettle();
    for (final l in lines) {
      expect(find.text(l.title), findsOneWidget);
      expect(find.text(fcfa(l.price * l.qty)), findsWidgets, reason: 'prix de ${l.title}');
    }
    expect(lines.fold<int>(0, (a, l) => a + l.price * l.qty), o.subtotal);
  });

  test('NR-008 : connecté sans aucune commande, les écrans 09, 29, 46 et 47 sont quittés ; sinon ils restent', () {
    for (final id in orderDetailScreens) {
      expect(redirectOrderDetail(ready: true, loaded: true, orders: const [], screen: id), isTrue, reason: id);
      expect(redirectOrderDetail(ready: false, loaded: true, orders: const [], screen: id), isFalse, reason: 'hors connexion : démonstration');
      expect(redirectOrderDetail(ready: true, loaded: false, orders: const [], screen: id), isFalse, reason: 'lecture non terminée');
    }
    expect(redirectOrderDetail(ready: true, loaded: true, orders: const [], screen: '45'), isFalse);
    final o = Order(id: '#BE-1', date: 'd', lines: const [], subtotal: 1, fee: 0, method: 'm', reference: 'r');
    expect(redirectOrderDetail(ready: true, loaded: true, orders: [o], screen: '29'), isFalse);
  });

  testWidgets('NR-022 : l\'onglet Messages de la barre du bas ouvre la liste des conversations (52)', (t) async {
    await pumpScreen(t, '03');
    final router = GoRouter.of(t.element(find.byType(G_03)));
    // l'icône de messagerie du menu du bas : zone de 21 × 21 à x = 113,5 dans la maquette
    final chat = find.byWidgetPredicate((w) => w is GPos && w.tap && w.gw == 21 && w.left == 113.5);
    expect(chat, findsOneWidget);
    await t.tap(chat);
    await t.pumpAndSettle();
    expect(router.state.uri.path, '/s/52');
  });

  test('NR-016 : une erreur technique du serveur n\'est jamais montrée telle quelle', () {
    const brutes = [
      'permission denied for function request_certification',
      'new row violates row-level security policy for table "orders"',
      'JWT expired',
      'null value in column "title" violates not-null constraint',
      'ClientException: Failed host lookup: zxqcnmgwhtbxkdpjqtlr.supabase.co',
      'SocketException: Connection refused',
      'PostgrestException(message: boom, code: 42P01)',
    ];
    for (final raw in brutes) {
      final m = Backend.userMessage(raw);
      for (final mot in ['permission', 'denied', 'function', 'request_certification', 'row-level', 'violates', 'null value', 'JWT', 'Exception', 'supabase', 'lookup']) {
        expect(m.toLowerCase().contains(mot.toLowerCase()), isFalse, reason: '« $raw » a produit « $m »');
      }
    }
    // un message métier lisible est conservé
    expect(Backend.userMessage('Stock insuffisant pour cet article.'), 'Stock insuffisant pour cet article.');
  });

  test('libellés et montants du récapitulatif', () {
    expect(feeLabel(0), 'Gratuit');
    expect(feeLabel(5000), fcfa(5000));
    expect(deliveryChoice(false).title, 'Retrait sur campus');
    expect(deliveryChoice(true).title, 'Livraison à domicile');
    expect(payMethodLabel(0), 'Orange Money');
    expect(payMethodLabel(1), 'Mobile Money');
    expect(orderReferenceLabel(const []), 'Attribuée à la validation');
    expect(amountToPay(const [], const Totals(3, 325000, 0)), 325000);
  });
}
