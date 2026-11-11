import 'package:boutik_ecole/figma/live/delivery.dart';
import 'package:boutik_ecole/figma/live/marche/marche_livraison.dart';
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
  testWidgets('tarifs du vendeur : villes, frais et livraison gratuite indiquée', (t) async {
    await _pump(t, const LivraisonTarifsScreen(), overrides: [
      marcheDeliveryZonesProvider(false).overrideWith((ref) async => [
            {'id': '1', 'to_city': 'Yaoundé', 'from_city': null, 'fee': 1000, 'active': true},
            {'id': '2', 'to_city': 'Bafoussam', 'from_city': 'Douala', 'fee': 10000, 'active': true},
            {'id': '3', 'to_city': 'Kribi', 'from_city': null, 'fee': 0, 'active': true},
          ]),
    ]);
    expect(find.text('Mes tarifs de livraison'), findsOneWidget);
    expect(find.text('Yaoundé'), findsOneWidget);
    expect(find.text('Depuis Douala'), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget, reason: '0 FCFA = livraison gratuite, indiquée comme telle');
    expect(find.text('Ajouter une ville'), findsOneWidget);
  });

  testWidgets('tarifs de la plateforme : titre et état vide clairs', (t) async {
    await _pump(t, const LivraisonTarifsScreen(platform: true), overrides: [marcheDeliveryZonesProvider(true).overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.text('Livraison de la plateforme'), findsOneWidget);
    expect(find.text('Aucun tarif de plateforme.'), findsOneWidget);
  });

  test('hors connexion : les frais restent ceux de la maquette (5 000) et le devis ne s’applique pas', () {
    expect(deliveryFee(true, null), 5000);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(totalsProvider).fee, isNonNegative);
  });
}
