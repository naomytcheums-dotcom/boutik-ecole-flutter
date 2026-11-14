import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/home_live.dart';
import 'package:boutik_ecole/figma/live/talent_pool.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _FakeTalents extends TalentsNotifier {
  @override
  List<LiveTalent>? build() => const [
        LiveTalent(id: 'a', name: 'Alice Ngo', department: 'Génie informatique', skills: 'Flutter', avatarUrl: '', certified: false),
        LiveTalent(id: 'b', name: 'Bob Eto', department: 'Gestion', skills: 'Excel', avatarUrl: '', certified: false),
      ];
}

Future<void> _pump(WidgetTester t, {String? only}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final List<Override> overrides = [
    liveTalentsProvider.overrideWith(_FakeTalents.new),
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
    expect(find.textContaining('Aucun membre'), findsOneWidget);
  });
}
