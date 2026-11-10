import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boutik_ecole/figma/live/need_pages.dart';
import 'package:boutik_ecole/figma/live/service_pages.dart';
import 'package:boutik_ecole/figma/live/talent_pages.dart';
import 'package:boutik_ecole/figma/live/tp_ui.dart';

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

void main() {
  testWidgets('portfolio sans élément : état vide avec action de création, pas de lien mort', (tester) async {
    await tester.pumpWidget(_wrap(const PortfolioPage()));
    await tester.pumpAndSettle();
    expect(find.text('Votre portfolio est vide'), findsOneWidget);
    expect(find.text('Créer mon portfolio'), findsOneWidget);
  });

  testWidgets('portfolio d’une autre personne : jamais de bouton de création', (tester) async {
    await tester.pumpWidget(_wrap(const PortfolioPage(userId: 'autre', ownerName: 'Test')));
    await tester.pumpAndSettle();
    expect(find.text('Portfolio de Test'), findsOneWidget);
    expect(find.text('Créer mon portfolio'), findsNothing);
  });

  testWidgets('formulaire de service : champs vides, jamais préremplis', (tester) async {
    await tester.pumpWidget(_wrap(const ServiceFormPage()));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, isNotEmpty);
    for (final f in fields) {
      expect(f.controller!.text, isEmpty);
    }
    expect(find.textContaining('Sur devis'), findsWidgets);
  });

  testWidgets('formulaire de besoin : champs vides et publication refusée sans titre', (tester) async {
    await tester.pumpWidget(_wrap(const NeedFormPage()));
    await tester.pumpAndSettle();
    for (final f in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(f.controller!.text, isEmpty);
    }
    await tester.tap(find.text('Publier'));
    await tester.pump();
    expect(find.textContaining('Donnez un titre'), findsOneWidget);
  });

  testWidgets('sélecteur extensible : « Autre » permet de saisir une valeur absente de la liste', (tester) async {
    String? picked;
    await tester.pumpWidget(_wrap(Scaffold(
      body: Builder(builder: (c) => TextButton(onPressed: () async => picked = await tpPick(c, 'Domaine', const ['Génie civil'], customLabel: 'Autre domaine'), child: const Text('ouvrir'))),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Génie civil'), findsOneWidget);
    await tester.tap(find.text('Autre domaine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Architecture');
    await tester.pump();
    await tester.tap(find.textContaining('Utiliser'));
    await tester.pumpAndSettle();
    expect(picked, 'Architecture');
  });

  test('catalogue : domaines, métiers et compétences s’adaptent au choix', () {
    final c = SkillCatalog([
      {'domain': 'Génie civil', 'job': '', 'skill': ''},
      {'domain': 'Génie civil', 'job': 'Topographe', 'skill': ''},
      {'domain': 'Génie civil', 'job': 'Topographe', 'skill': 'Levé topographique'},
      {'domain': 'Génie civil', 'job': 'Ingénieur structures', 'skill': 'Béton armé'},
      {'domain': 'Informatique', 'job': 'Développeur web', 'skill': 'React'},
    ]);
    expect(c.domains, ['Génie civil', 'Informatique']);
    expect(c.jobs('Génie civil'), ['Ingénieur structures', 'Topographe']);
    expect(c.skills('Génie civil', 'Topographe'), ['Levé topographique']);
    expect(c.skills('Génie civil', ''), ['Béton armé', 'Levé topographique']);
    expect(c.skills('Autre', ''), isEmpty);
  });

  test('URL de portfolio : seules les adresses http(s) complètes sont acceptées', () {
    expect(tpValidUrl('https://exemple.cm/portfolio'), isTrue);
    expect(tpValidUrl('javascript:alert(1)'), isFalse);
    expect(tpValidUrl('exemple'), isFalse);
  });
}
