import 'package:boutik_ecole/figma/live/litiges_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('état d’un litige en toutes lettres', () {
    expect(disputeStateLabel({'status': 'open', 'buyer_reply': null}), 'Ouvert · en attente de réponse');
    expect(disputeStateLabel({'status': 'open', 'buyer_reply': 'Abîmé'}), 'Ouvert · l’acheteur a répondu');
    expect(disputeStateLabel({'status': 'resolved', 'decision': 'cancel'}), 'Tranché · commande annulée');
    expect(disputeStateLabel({'status': 'resolved', 'decision': 'close'}), 'Tranché · litige clos');
  });

  testWidgets('aucun litige : message clair', (t) async {
    await _pump(t, const DisputesScreen(), overrides: [disputesProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.textContaining('Aucun litige.'), findsOneWidget);
  });

  testWidgets('acheteur : peut répondre ; équipe : peut clore ou annuler', (t) async {
    await _pump(t, const DisputesScreen(), overrides: [
      disputesProvider.overrideWith((ref) async => [
            {'id': 'd1', 'order_number': '#BE-2026-0001', 'note': 'Le client refuse de payer', 'buyer_reply': null, 'status': 'open', 'decision': null, 'decision_note': null, 'as': 'buyer'},
            {'id': 'd2', 'order_number': '#BE-2026-0002', 'note': 'Refus à la remise', 'buyer_reply': 'Produit abîmé', 'status': 'open', 'decision': null, 'decision_note': null, 'as': 'staff'},
            {'id': 'd3', 'order_number': '#BE-2026-0003', 'note': 'Refus', 'buyer_reply': null, 'status': 'resolved', 'decision': 'cancel', 'decision_note': 'Abîmé', 'as': 'seller'},
          ]),
    ]);
    expect(find.text('Commande #BE-2026-0001'), findsOneWidget);
    expect(find.text('Répondre'), findsOneWidget);
    expect(find.text('Clore'), findsOneWidget);
    expect(find.text('Annuler la commande'), findsOneWidget);
    expect(find.text('Tranché · commande annulée'), findsOneWidget);
    expect(find.text('Équipe : Abîmé'), findsOneWidget);
  });
}
