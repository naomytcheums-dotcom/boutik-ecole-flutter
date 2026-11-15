import 'package:boutik_ecole/figma/g/g_79.dart';
import 'package:boutik_ecole/figma/g/g_81.dart';
import 'package:boutik_ecole/figma/g/g_82.dart';
import 'package:boutik_ecole/figma/g/g_83.dart';
import 'package:boutik_ecole/figma/g/g_84.dart';
import 'package:boutik_ecole/figma/g/g_84b.dart';
import 'package:boutik_ecole/figma/g/g_282.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/project_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {Account? compte}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (compte != null) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(compte);
      await t.pumpAndSettle();
    }
  }

  final client = demoAccount.copyWith(role: 0);

  testWidgets('79 sans projet ouvert : aucun chiffre de maquette', (t) async {
    await monter(t, const G_79(), compte: client);
    expect(find.text('Aucun projet sélectionné'), findsOneWidget);
    expect(find.text('Contributeurs'), findsNothing);
    expect(find.text('Soutenir le projet'), findsNothing);
  });

  testWidgets('79 fiche réelle : soutien proposé, contacts jamais affichés', (t) async {
    Backend.ready = true;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ProjectDetailPage(initial: const {
          'id': null,
          'kind': 'projet',
          'title': 'Serre solaire',
          'summary': 'Une serre alimentée par des panneaux.',
          'status': 'approved',
          'details': {'problem': 'Les récoltes chauffent.', 'ip': {'authors': 'Mariam E.', 'license': 'cc_by'}},
          'votes': 3,
          'team': [{'name': 'Yannick M.', 'role': 'Design'}],
        }),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Serre solaire'), findsOneWidget);
    expect(find.text('Soutenir le projet'), findsOneWidget);
    expect(find.text('3 soutiens'), findsOneWidget);
    expect(find.textContaining('Yannick M. · Design'), findsOneWidget);
    expect(find.textContaining('Auteurs : Mariam E.'), findsOneWidget);
  });

  for (final e in <(String, Widget)>[('81', const G_81()), ('82', const G_82()), ('83', const G_83()), ('84', const G_84())]) {
    testWidgets('${e.$1} : un Client reçoit un message clair avant toute saisie', (t) async {
      await monter(t, e.$2, compte: client);
      expect(find.text('Réservé aux étudiants'), findsOneWidget);
      expect(find.text('Voir les projets validés'), findsOneWidget);
    });
  }

  testWidgets('84 : un étudiant sans projet validé ne voit aucune valeur de maquette', (t) async {
    await monter(t, const G_84(), compte: demoAccount);
    expect(find.text('Aucun projet validé'), findsOneWidget);
    expect(find.text('Serre intelligente'), findsNothing);
    expect(find.text('2 000 000'), findsNothing);
  });

  testWidgets('82 : un étudiant sans projet est invité à en créer un', (t) async {
    await monter(t, const G_82(), compte: demoAccount);
    expect(find.text('Aucun projet'), findsOneWidget);
    expect(find.text('Soumettre un projet'), findsOneWidget);
  });

  testWidgets('84b : le catalogue des campagnes est lisible sans compte', (t) async {
    await monter(t, const G_84b());
    expect(find.text('Financement'), findsWidgets);
    expect(find.text('Contribuer'), findsNothing);
  });

  testWidgets('282 : réservé au support et à l’administration', (t) async {
    await monter(t, const G_282(), compte: client);
    expect(find.text('Réservé au support et à l’administration'), findsOneWidget);
    expect(find.text('Programmer l’événement'), findsNothing);
  });

  testWidgets('282 : le support voit la programmation sans valeur préremplie', (t) async {
    await monter(t, const G_282(), compte: demoAccount.copyWith(staff: 'Support'));
    expect(find.text('Programmer l’événement'), findsOneWidget);
    expect(find.text('Journée de l’innovation'), findsNothing);
    expect(find.text('Aucun code actif'), findsOneWidget);
  });
}
