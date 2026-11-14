import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/project_cards.dart';
import 'package:boutik_ecole/figma/live/talents.dart' show projectTabProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(this.v) : super('projects');
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  Future<void> monter(WidgetTester t, List<Map<String, dynamic>> rows) async {
    Backend.ready = true;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [projectsFeedProvider.overrideWith(() => _Rows(rows))],
      child: const MaterialApp(home: Scaffold(body: SizedBox(width: 342, height: 540, child: ProjectCards()))),
    ));
    final c = ProviderScope.containerOf(t.element(find.byType(ProjectCards)));
    c.read(authProvider.notifier).login(demoAccount);
    await t.pumpAndSettle();
  }

  testWidgets('aucun projet : état vide, aucune carte inventée', (t) async {
    await monter(t, const []);
    expect(find.textContaining('Aucun projet validé'), findsOneWidget);
  });

  testWidgets('un projet réel : titre, domaine, état et fiche détaillée', (t) async {
    await monter(t, [
      {'id': '1', 'kind': 'innovation', 'title': 'Serre solaire', 'summary': 'Une serre alimentée par des panneaux.', 'department': 'Génie électrique', 'status': 'approved', 'media': const [], 'details': {'problem': 'Les récoltes chauffent.'}},
    ]);
    expect(find.text('Serre solaire'), findsOneWidget);
    expect(find.text('Validé'), findsOneWidget);
    expect(find.textContaining('Innovation'), findsOneWidget);
    await t.tap(find.text('Serre solaire'));
    await t.pumpAndSettle();
    expect(find.text('Problème résolu'), findsOneWidget);
    expect(find.text('Les récoltes chauffent.'), findsOneWidget);
  });

  testWidgets('pastilles : Prototypes, Recherche et Financement filtrent réellement', (t) async {
    await monter(t, [
      {'id': '1', 'kind': 'projet', 'title': 'Drone', 'summary': '', 'department': '', 'status': 'approved', 'media': const [], 'details': {'progress': 'prototype'}},
      {'id': '2', 'kind': 'projet', 'title': 'Serre', 'summary': '', 'department': '', 'status': 'approved', 'media': const [], 'details': {'progress': 'idee', 'funding_xaf': '500000'}},
      {'id': '3', 'kind': 'projet', 'title': 'Filtre', 'summary': '', 'department': '', 'status': 'approved', 'media': const [], 'details': {'progress': 'conception', 'funding_xaf': ''}},
    ]);
    final c = ProviderScope.containerOf(t.element(find.byType(ProjectCards)));
    expect(find.text('Drone'), findsOneWidget);
    expect(find.text('Serre'), findsOneWidget);
    c.read(projectTabProvider.notifier).set(1);
    await t.pumpAndSettle();
    expect([find.text('Drone').evaluate().length, find.text('Serre').evaluate().length, find.text('Filtre').evaluate().length], [1, 0, 0]);
    c.read(projectTabProvider.notifier).set(2);
    await t.pumpAndSettle();
    expect([find.text('Drone').evaluate().length, find.text('Serre').evaluate().length, find.text('Filtre').evaluate().length], [0, 1, 1]);
    c.read(projectTabProvider.notifier).set(3);
    await t.pumpAndSettle();
    expect([find.text('Drone').evaluate().length, find.text('Serre').evaluate().length, find.text('Filtre').evaluate().length], [0, 1, 0]);
  });

  testWidgets('fiche : avancement et besoin de financement, jamais les contacts', (t) async {
    await monter(t, [
      {'id': '1', 'kind': 'projet', 'title': 'Serre', 'summary': 'Une serre', 'department': '', 'status': 'approved', 'media': const [], 'details': {'progress': 'tests', 'funding_xaf': '500000', 'contact_email': 'a@b.cm', 'contact_phone': '699000000'}},
    ]);
    await t.tap(find.text('Serre'));
    await t.pumpAndSettle();
    expect(find.text('Tests sur le terrain'), findsOneWidget);
    expect(find.text('Besoin de financement'), findsOneWidget);
    expect(find.textContaining('a@b.cm'), findsNothing);
    expect(find.textContaining('699000000'), findsNothing);
  });
}
