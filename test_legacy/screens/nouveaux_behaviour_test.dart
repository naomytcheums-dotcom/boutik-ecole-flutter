import 'package:boutik_ecole/core/utils/money.dart';
import 'package:boutik_ecole/core/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

void main() {
  group('fcfa', () {
    test('sépare les milliers par une espace insécable', () {
      expect(fcfa(330000), '330\u00A0000\u00A0FCFA');
      expect(fcfa(1470), '1\u00A0470\u00A0FCFA');
      expect(fcfa(0), '0\u00A0FCFA');
      expect(fcfa(1200000, withUnit: false), '1\u00A0200\u00A0000');
    });
  });

  group('ventilation 70 / 20 / 10', () {
    test('la somme des parts égale le montant', () {
      for (final amount in [98000, 271770, 1, 333]) {
        final s = splitPayment(amount);
        expect(s.seller + s.institution + s.platform, amount);
      }
    });
    test('montants de la facture 260', () {
      final s = splitPayment(98000);
      expect((s.seller, s.institution, s.platform), (68600, 19600, 9800));
    });
  });

  group('Validators (écran 275)', () {
    test('titre', () {
      expect(Validators.title(''), isNotNull);
      expect(Validators.title('ab'), isNotNull);
      expect(Validators.title('Lampe'), isNull);
      expect(Validators.title('x' * 81), isNotNull);
    });
    test('prix', () {
      expect(Validators.priceFcfa('500'), isNotNull);
      expect(Validators.priceFcfa('25 000'), isNull);
      expect(Validators.priceFcfa('abc'), isNotNull);
    });
    test('image', () {
      expect(Validators.image('a.png', 9 * 1024 * 1024), isNotNull);
      expect(Validators.image('a.gif', 1000), isNotNull);
      expect(Validators.image('a.webp', 1000), isNull);
    });
    test('téléphone camerounais', () {
      expect(Validators.phoneCm('+237 6 99 00 11 22'), isNull);
      expect(Validators.phoneCm('699001122'), isNull);
      expect(Validators.phoneCm('299001122'), isNotNull);
    });
  });

  testWidgets('275 : corriger les champs fait disparaître les erreurs', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '275');
    expect(find.text('3 champs à corriger avant de continuer. Votre brouillon est enregistré.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Lampe en bois recyclé');
    await tester.enterText(find.byType(TextFormField).at(1), '25000');
    await tester.tap(find.textContaining('image-trop-lourde.png'));
    await tester.pumpAndSettle();

    expect(find.textContaining('champs à corriger'), findsNothing);
    expect(find.textContaining('champ à corriger'), findsNothing);
  });

  testWidgets('272 : un code incomplet affiche une erreur', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '272');
    await tester.tap(find.text('Vérifier'));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez les 6 chiffres du code.'), findsOneWidget);
  });

  testWidgets('286 : valider une soumission la retire de la liste', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '286');
    expect(find.text('Soumissions en attente (3)'), findsOneWidget);
    await tester.tap(find.text('Valider').first);
    await tester.pumpAndSettle();
    expect(find.text('Soumissions en attente (2)'), findsOneWidget);
  });

  testWidgets('270 : le filtre par ville réduit la liste', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '270');
    await tester.tap(find.text('Ngaoundéré'));
    await tester.pumpAndSettle();
    expect(find.text('Jus de bissap'), findsOneWidget);
    expect(find.text('Lampe en bois recyclé'), findsNothing);
  });
}
