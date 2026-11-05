import 'package:boutik_ecole/figma/g/g_152.dart';
import 'package:boutik_ecole/figma/g/g_157.dart';
import 'package:boutik_ecole/figma/g/g_203.dart';
import 'package:boutik_ecole/figma/g/g_204.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/opportunites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  testWidgets('152 connecté : offres réelles, aucun pourcentage de maquette', (t) async {
    await monter(t, const G_152(), connecte: true, overrides: [
      openMissionsProvider.overrideWith(() => _Rows('table:missions', [
            {'title': 'Affiche Test', 'budget_min': 50000, 'budget_max': 80000, 'status': 'published', 'created_at': '2026-11-01T10:00:00Z'},
            {'title': 'Brouillon', 'budget_min': null, 'budget_max': null, 'status': 'draft', 'created_at': '2026-11-01T10:00:00Z'},
          ]))
    ]);
    expect(find.text('Affiche Test'), findsOneWidget);
    expect(find.text('Brouillon'), findsNothing);
    expect(find.text('Stage développeur web'), findsNothing);
    expect(find.text('92 %'), findsNothing);
  });

  testWidgets('152 connecté sans offre : état vide', (t) async {
    await monter(t, const G_152(), connecte: true, overrides: [openMissionsProvider.overrideWith(() => _Rows('table:missions', const []))]);
    expect(find.textContaining('Aucune offre ouverte'), findsOneWidget);
  });

  testWidgets('157 connecté : résumé calculé', (t) async {
    await monter(t, const G_157(), connecte: true, overrides: [
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', [
            {'author': 'Alice Test', 'mission': 'Logo', 'status': 'submitted'},
            {'author': 'Bob Test', 'mission': 'Site', 'status': 'accepted'},
          ])),
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'title': 'Logo', 'deadline': null}
          ])),
    ]);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Propositions reçues'), findsOneWidget);
    expect(find.text('Application de suivi clients'), findsNothing);
    expect(find.text('23'), findsNothing);
  });

  testWidgets('203 connecté : compétences du profil, aucun score inventé', (t) async {
    await monter(t, const G_203(), connecte: true);
    expect(find.text('Domaines déclarés'), findsOneWidget);
    expect(find.text('Community management'), findsNothing);
    expect(find.text('Score global'), findsNothing);
  });

  testWidgets('204 connecté : projets réels', (t) async {
    await monter(t, const G_204(), connecte: true, overrides: [
      projectsCatalogProvider.overrideWith(() => _Rows('table:projects', [
            {'title': 'Projet Test', 'summary': 'Résumé', 'department': 'GI', 'status': 'approved'}
          ]))
    ]);
    expect(find.text('Projet Test'), findsOneWidget);
    expect(find.text('Projets validés : 1'), findsOneWidget);
    expect(find.text('Serre intelligente'), findsNothing);
  });

  for (final c in <(String, Widget, String)>[('152', const G_152(), 'Stage développeur web'), ('157', const G_157(), 'Mariam Essono'), ('203', const G_203(), 'Community management'), ('204', const G_204(), 'Serre intelligente')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
