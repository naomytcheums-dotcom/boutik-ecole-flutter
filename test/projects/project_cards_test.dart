import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/project_cards.dart';
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
}
