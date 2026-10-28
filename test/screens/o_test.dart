import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '139': ['Tableau de bord financier', '48 200 000 FCFA', 'Derniers flux'],
    '140': ['Paiements déclarés', '#BE-2026-0138', 'Rejeté'],
    '141': ['Journal financier', '43 250 FCFA', '19 500 FCFA'],
    '142': ['Rapports financiers', '1 245 000', 'Exporter le rapport'],
    '143': ['Versements et montants dus', '44 590 000 FCFA', 'Prochain lot le 26 oct.'],
    '144': ['Moyens de paiement et règles', '10 000 FCFA', 'FCFA (XAF)'],
  });

  testWidgets('140 : vérifier un paiement le passe dans « Vérifiés »', (tester) async {
    await pumpScreen(tester, '140', size: const Size(1280, 900));
    await tester.tap(find.text('À vérifier').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifiés'));
    await tester.pumpAndSettle();
    expect(find.text('TX-88420'), findsOneWidget);
    expect(find.text('TX-88417'), findsOneWidget);
    expect(find.text('TX-88410'), findsNothing);
  });
}
