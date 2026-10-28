import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '187': ['Tableau de bord entreprise', '23 propositions', 'Application de suivi clients', 'Besoins pourvus'],
    '188': ['Recherche de talents et d’équipes', 'Enregistrer la recherche', 'Mariam Essono', 'UI/UX, Branding'],
    '189': ['Propositions reçues', 'Toutes (23)', '120 000', 'Analyse IA'],
    '190': ['Devis et négociations', 'DEV-2026-014 · Borne solaire', '450 000', 'Négociation'],
  });

  const web = Size(1280, 900);

  testWidgets('188 : le filtre Audiovisuel ne garde que les profils audiovisuels', (tester) async {
    await pumpScreen(tester, '188', size: web);
    await tester.tap(find.text('Audiovisuel').first);
    await tester.pumpAndSettle();
    expect(find.text('Kouassi Tagne'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
    await tester.tap(find.text('Équipes'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun talent ne correspond à ces critères.'), findsOneWidget);
  });

  testWidgets('189 : l’onglet Présélection masque les propositions à examiner', (tester) async {
    await pumpScreen(tester, '189', size: web);
    expect(find.text('À examiner'), findsNWidgets(2));
    await tester.tap(find.text('Présélection (4)'));
    await tester.pumpAndSettle();
    expect(find.text('À examiner'), findsNothing);
    expect(find.text('Team Innov’'), findsOneWidget);
  });

  testWidgets('190 : les onglets filtrent les devis', (tester) async {
    await pumpScreen(tester, '190', size: web);
    await tester.tap(find.text('Acceptés'));
    await tester.pumpAndSettle();
    expect(find.text('DEV-2026-009 · Logo et charte'), findsOneWidget);
    expect(find.text('DEV-2026-014 · Borne solaire'), findsNothing);
    await tester.tap(find.text('Refusés'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun devis refusé.'), findsOneWidget);
  });

  for (final id in ['187', '188', '189', '190']) {
    testWidgets('$id : pas de débordement en largeur mobile', (tester) async {
      await pumpScreen(tester, id, size: const Size(390, 900));
      expect(tester.takeException(), isNull);
    });
  }
}
