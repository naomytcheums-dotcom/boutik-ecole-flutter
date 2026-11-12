import 'package:boutik_ecole/figma/live/marche/marche_appels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('appels : paramètres de recherche, tri et filière envoyés au serveur', () {
    const q = CallsQuery();
    expect(q.params, {'p_limit': 50, 'p_sort': 'recent'});
    final f = q.copy(q: ' caisse ', sort: 'budget', dept: 'design');
    expect(f.params['p_q'], 'caisse');
    expect(f.params['p_sort'], 'budget');
    expect(f.params['p_department'], 'design');
    expect(callSorts.keys, ['recent', 'budget', 'fewest']);
    expect(projectSorts.keys, ['best', 'recent']);
  });

  testWidgets('appels : recherche, tri et filière visibles', (t) async {
    await _pump(t, const AppelsScreen(), overrides: [marcheCallsProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.text('Rechercher un besoin…'), findsOneWidget);
    expect(find.text('Plus récents'), findsOneWidget, reason: 'tri par défaut visible');
    expect(find.text('Toutes les filières'), findsOneWidget);
  });

  testWidgets('projets : classement, filière et bouton Soutenir avec le nombre de soutiens', (t) async {
    await _pump(t, const ProjetsIutScreen(), overrides: [
      marcheIutProjectsProvider.overrideWith((ref) async => [
            {'id': 'p1', 'title': 'Caisse intelligente', 'summary': 'Résumé', 'department': 'Informatique', 'owner_id': 'u1', 'owner': 'Awa A.', 'votes': 12, 'voted': false},
            {'id': 'p2', 'title': 'Identité visuelle', 'summary': 'Résumé', 'department': 'Design', 'owner_id': 'u2', 'owner': 'Paul M.', 'votes': 3, 'voted': true},
          ]),
    ]);
    expect(find.text('Les meilleurs'), findsOneWidget, reason: 'classement par défaut');
    expect(find.text('Toutes les filières'), findsOneWidget);
    expect(find.text('Soutenir · 12'), findsOneWidget);
    expect(find.text('Soutenu · 3'), findsOneWidget);
    expect(find.text('Caisse intelligente'), findsOneWidget);
    expect(find.text('Identité visuelle'), findsOneWidget);
  });
}
