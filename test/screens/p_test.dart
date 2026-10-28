import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '145': ['Points de retrait et kiosques', 'Kiosque Bibliothèque', '3 en ligne'],
    '146-1': ['Kiosque Bloc A', 'Casier 12 bloqué', '#BE-2026-0139'],
    '146-2': ['Remise d’une commande', '25 000 FCFA', 'Confirmer la remise'],
    '147-1': ['Incidents et maintenance', '98,6 %', 'Écran tactile figé'],
    '147-2': ['Tickets de support', 'Paiement non reconnu', 'Escaladé'],
    '147-3': ['Interventions et résolutions', 'Pièce commandée', 'Mise à jour logiciel'],
  });

  testWidgets('146-2 : un code de retrait erroné est refusé, le bon confirme la remise', (tester) async {
    await pumpScreen(tester, '146-2');
    await tester.tap(find.textContaining('saisissez le code de retrait'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '111111');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Code de retrait incorrect.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '482915');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Remise confirmée'), findsOneWidget);
  });

  testWidgets('147-2 : l’onglet « Escaladés » ne garde que #T-2035', (tester) async {
    await pumpScreen(tester, '147-2', size: const Size(1280, 900));
    await tester.tap(find.text('Escaladés'));
    await tester.pumpAndSettle();
    expect(find.text('#T-2035'), findsOneWidget);
    expect(find.text('#T-2041'), findsNothing);
  });
}

