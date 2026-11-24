import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/f4_api.dart';
import 'package:boutik_ecole/figma/live/talent_pool.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const _alice = {'id': 'a', 'name': 'Alice Ngo', 'department': 'Génie informatique', 'skills': 'Flutter', 'avatar_url': null, 'certified': false};
const _bob = {'id': 'b', 'name': 'Bob Eto', 'department': 'Gestion', 'skills': 'Excel', 'avatar_url': null, 'certified': false};

/// Faux serveur : annuaire de deux étudiants (talents_search) et contenu des listes du vivier (pool_list_members_get).
Future<({Object? data, String? error})> _server(String fn, Map<String, dynamic> p) async => switch (fn) {
      'talents_search' => (data: {'total': 2, 'items': [_alice, _bob], 'locked': false, 'limit': 20, 'offset': 0}, error: null),
      'pool_list_members_get' => (data: p['p_list'] == 'fav' ? [_alice] : <Map<String, dynamic>>[], error: null),
      _ => (data: null, error: 'Fonction $fn non prévue'),
    };

Future<void> _pump(WidgetTester t, {String? only}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final List<Override> overrides = [
    f4RpcProvider.overrideWithValue(_server),
    talentListsProvider.overrideWith((ref) async => [
          {'id': 'fav', 'name': 'Favoris', 'count': 1},
          {'id': 'dev', 'name': 'Développeurs', 'count': 0},
        ]),
    talentListMembersProvider.overrideWith((ref, id) async => id == 'fav' ? {'a'} : <String>{}),
    talentSavedIdsProvider.overrideWith((ref) async => {'a'}),
  ];
  await t.pumpWidget(ProviderScope(overrides: overrides, child: const MaterialApp(home: Scaffold(body: TalentSearchList(width: 380, height: 700)))));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('vivier : puces des listes, étoile allumée pour un étudiant enregistré', (t) async {
    await _pump(t);
    expect(find.text('Tous'), findsOneWidget);
    expect(find.text('Favoris (1)'), findsOneWidget);
    expect(find.text('Développeurs (0)'), findsOneWidget);
    expect(find.text('Alice Ngo'), findsOneWidget);
    expect(find.text('Bob Eto'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget); // Alice
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget); // Bob
  });

  testWidgets('vivier : choisir une liste n\'affiche que ses étudiants', (t) async {
    await _pump(t);
    await t.tap(find.text('Favoris (1)'));
    await t.pumpAndSettle();
    expect(find.text('Alice Ngo'), findsOneWidget);
    expect(find.text('Bob Eto'), findsNothing);
    await t.ensureVisible(find.text('Développeurs (0)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Développeurs (0)'));
    await t.pumpAndSettle();
    expect(find.text('Alice Ngo'), findsNothing);
    expect(find.textContaining('Cette liste est vide'), findsOneWidget);
  });
}
