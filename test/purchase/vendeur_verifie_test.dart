import 'package:boutik_ecole/figma/live/marche/marche_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w) => t.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: w))));

void main() {
  testWidgets('carte vendeur : filière, année, encadrant et badge validé par l’IUT', (t) async {
    await _pump(t, const SellerCard(
      seller: {'name': 'Awa Mballa', 'department': 'Génie civil', 'study_level': 'Licence 2', 'institution': 'IUT de Douala', 'certified': true},
      supervisor: 'M. Nkoulou',
      validated: true,
    ));
    expect(find.text('Awa Mballa'), findsOneWidget);
    expect(find.text('Vendeur vérifié'), findsOneWidget);
    expect(find.text('Génie civil · Licence 2 · IUT de Douala'), findsOneWidget);
    expect(find.text('Encadré par M. Nkoulou'), findsOneWidget);
    expect(find.text('Projet validé par l’IUT de Douala'), findsOneWidget);
  });

  testWidgets('carte vendeur : rien d’inventé quand les informations manquent', (t) async {
    await _pump(t, const SellerCard(seller: {'name': 'Paul', 'certified': false}));
    expect(find.text('Étudiant vendeur'), findsOneWidget);
    expect(find.textContaining('Encadré par'), findsNothing);
    expect(find.textContaining('validé par'), findsNothing);
    expect(find.text('Vendeur vérifié'), findsNothing);
  });

  testWidgets('carte vendeur : sans nom, rien n’est affiché', (t) async {
    await _pump(t, const SellerCard(seller: {'name': ''}));
    expect(find.byType(Container), findsNothing);
  });
}
