import 'package:boutik_ecole/figma/g/g_89.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_home.dart';
import 'package:boutik_ecole/figma/live/company_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Écran 89 « Profil de l'entreprise » : en mode connecté il affiche la fiche réelle de l'entreprise (jamais le texte de la maquette),
/// les vrais compteurs, et ne propose pas de « Suivre » sur sa propre fiche.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, {required bool connecte}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        companyProvider.overrideWith((ref) async => {
              'company_name': 'Sonel Distribution',
              'sector': 'Énergie',
              'city': 'Yaoundé',
              'description': 'Distribution d’électricité et stages ingénieurs.',
              'status': 'approved',
            }),
        companyDashboardProvider.overrideWith((ref) async => {'offers_active': 3, 'contests_active': 1, 'needs_open': 2, 'recruits': 5}),
      ],
      child: const MaterialApp(home: G_89()),
    ));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byType(G_89))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  testWidgets('connecté : fiche réelle, compteurs réels, aucun texte de maquette', (t) async {
    await monter(t, connecte: true);
    expect(find.text('Sonel Distribution'), findsOneWidget);
    expect(find.text('Énergie · Yaoundé'), findsOneWidget);
    expect(find.text('#Énergie #Yaoundé'), findsOneWidget);
    expect(find.text('Distribution d’électricité et stages ingénieurs.'), findsOneWidget);
    expect(find.text('2 Besoins'), findsOneWidget);
    expect(find.text('3 Offres'), findsOneWidget);
    expect(find.text('5 Recrutés'), findsOneWidget);
    // textes de la maquette absents
    expect(find.text('Télécommunications · Douala'), findsNothing);
    expect(find.text('#Stages   #Hackathons   #Innovation'), findsNothing);
    expect(find.textContaining('Partenaire de l’IUT'), findsNothing);
    expect(find.text('Orange Cameroun'), findsNothing);
    // pas de bouton « Suivre » sur sa propre fiche, mais « Publier un besoin »
    expect(find.text('Suivre'), findsNothing);
    expect(find.text('Publier un besoin'), findsOneWidget);
  });

  testWidgets('démonstration : la maquette reste affichée', (t) async {
    await monter(t, connecte: false);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Télécommunications · Douala'), findsOneWidget);
    expect(find.text('Suivre'), findsOneWidget);
  });
}
