import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('11 : la connexion refuse un numéro invalide', (tester) async {
    await pumpScreen(tester, '11');
    await tester.enterText(find.byType(TextFormField).at(0), '123');
    await tester.enterText(find.byType(TextFormField).at(1), 'motdepasse');
    await tester.tap(find.text('Se connecter').first);
    await tester.pumpAndSettle();
    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsOneWidget);
  });

  testWidgets('11 : une connexion valide ouvre l’accueil', (tester) async {
    await pumpScreen(tester, '11');
    await tester.enterText(find.byType(TextFormField).at(0), '699001122');
    await tester.enterText(find.byType(TextFormField).at(1), 'motdepasse');
    await tester.tap(find.text('Se connecter').first);
    await tester.pumpAndSettle();
    expect(find.text('Produits en vedette'), findsOneWidget);
  });

  testWidgets('12 : CGU non acceptées et mots de passe différents', (tester) async {
    await pumpScreen(tester, '12');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mariam Essono');
    await tester.enterText(fields.at(1), '699001122');
    await tester.enterText(fields.at(2), 'mariam@iut.cm');
    await tester.enterText(fields.at(3), 'Boutik2026!');
    await tester.enterText(fields.at(4), 'autre');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);
    expect(find.text('Vous devez accepter les conditions pour continuer.'), findsOneWidget);
  });

  testWidgets('16 : la force du mot de passe suit la saisie', (tester) async {
    await pumpScreen(tester, '16');
    expect(find.text('Fort'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'abc');
    await tester.pumpAndSettle();
    expect(find.text('Faible'), findsOneWidget);
  });

  testWidgets('13 : choisir « Client » change la sélection', (tester) async {
    await pumpScreen(tester, '13');
    await tester.tap(find.text('Client'));
    await tester.pumpAndSettle();
    final badge = find.text('Sélectionné');
    expect(badge, findsOneWidget);
    expect(tester.getTopLeft(badge).dy, lessThan(tester.getTopLeft(find.text('Étudiant vendeur')).dy));
  });

  testWidgets('20 : filtrer par texte réduit les résultats', (tester) async {
    await pumpScreen(tester, '20');
    await tester.enterText(find.byType(TextField).first, 'drone');
    await tester.pumpAndSettle();
    expect(find.text('0 résultat'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'sac');
    await tester.pumpAndSettle();
    expect(find.text('Sac à dos design'), findsOneWidget);
    expect(find.text('Tableau décoratif'), findsNothing);
  });
}
