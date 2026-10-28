import 'package:boutik_ecole/features/aa_borne/s210_envoye_borne/envoye_borne_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '206': [
      'Touchez pour commencer',
      'Achetez, commandez un service ou lancez une mission.',
      'Borne prête · réseau OK',
    ],
    '207': ['Lampe en bois recyclé', 'Kit solaire portable', '25 000 FCFA', 'Mon QR'],
    '208': ['Lampe en bois recyclé', '4,8 · 12 avis', '25 000 FCFA', 'Sur mon téléphone'],
    '209': ['Continuez sur votre téléphone', '4:59', 'Ouvrez la fiche', 'Annuler'],
    '210': ['C’est envoyé !', 'BE-2210-7F3A', 'Atelier GC', 'Retour à l’accueil dans 15 s'],
  });

  const kiosk = Size(720, 1280);

  test('code39Pattern : départ et arrêt, largeur fixe par caractère', () {
    final p = code39Pattern('BE-2210');
    // 9 caractères (avec * de début et de fin) × 15 modules + 8 séparateurs.
    expect(p.length, 9 * 15 + 8);
    expect(p.first, isTrue);
    expect(p.last, isTrue);
    expect(() => code39Pattern('é'), throwsArgumentError);
  });

  testWidgets('207 : choisir un article ouvre sa fiche', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '207', size: kiosk);
    await tester.tap(find.text('Kit solaire portable'));
    await tester.pumpAndSettle();
    expect(find.text('Sur mon téléphone'), findsOneWidget);
    expect(find.text('18 000 FCFA'.replaceAll(' ', '\u00A0')), findsOneWidget);
  });

  testWidgets('207 : l’onglet Services est vide, la recherche filtre', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '207', size: kiosk);
    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour le moment.'), findsOneWidget);
    await tester.tap(find.text('Tout'));
    await tester.enterText(find.byType(TextField), 'bissap');
    await tester.pumpAndSettle();
    expect(find.text('Jus de bissap'), findsOneWidget);
    expect(find.text('Lampe en bois recyclé'), findsNothing);
  });

  testWidgets('209 : le QR expire au bout du délai puis se renouvelle', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '209', size: kiosk);
    await tester.pump(const Duration(seconds: 300));
    expect(find.text('Code expiré'), findsOneWidget);
    await tester.tap(find.text('Nouveau code'));
    await tester.pump();
    expect(find.text('5:00'), findsOneWidget);
  });

  testWidgets('210 : retour automatique à l’accueil après 15 s', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '210', size: kiosk);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.text('Touchez pour commencer'), findsOneWidget);
  });

  testWidgets('206 : le bouton EN traduit la borne', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '206', size: kiosk);
    await tester.tap(find.bySemanticsLabel('English'));
    await tester.pumpAndSettle();
    expect(find.text('Touch to start'), findsOneWidget);
  });
}
