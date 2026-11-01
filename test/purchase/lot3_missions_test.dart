import 'package:boutik_ecole/figma/g/g_192.dart';
import 'package:boutik_ecole/figma/g/g_201.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot 3 (phase 4) : le suivi de mission (192 à 201) montre la mission réelle du compte, jamais la mission d'exemple.

final _row = {
  'id': 'm1',
  'number': '#BR-2026-754495',
  'title': 'Affiche du gala',
  'description': 'Affiche A2 et déclinaisons réseaux.',
  'status': 'assigned',
  'assigned_team': 'MMI',
  'deadline': '15 déc. 2026',
  'created_at': '2026-10-30T09:00:00Z',
  'total': 0,
};
final _miles = [
  {'position': 1, 'title': 'Esquisses', 'amount': 30000, 'status': 'validated'},
  {'position': 2, 'title': 'Version finale', 'amount': 50000, 'status': 'submitted'},
];

class _Real extends MissionNotifier {
  @override
  Mission build() => Mission.fromServer(_row, 80000, _miles);
}

Future<void> _pump(WidgetTester tester, Widget screen, MissionNotifier Function() mission) async {
  GAnim.enabled = false;
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [missionProvider.overrideWith(mission)], child: MaterialApp(home: Scaffold(body: screen))));
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  test('mission serveur : numéro, titre, montant accepté, jalons réels, rien de « financé »', () {
    final m = Mission.fromServer(_row, 80000, _miles);
    expect(m.real, isTrue);
    expect(m.id, '#BR-2026-754495');
    expect(m.kind, 'Affiche du gala');
    expect(m.total, 80000);
    expect(m.accepted, isTrue);
    expect(m.funded, 0, reason: 'le séquestre n’est pas activé');
    expect(m.released, 1);
    expect(m.proof, 2);
    expect(m.amountOf(1), 50000);
    expect(m.pct, 50);
    expect(m.step(0), ('Esquisses', 'Validé'));
    expect(m.step(1), ('Version finale', 'Livré, à valider'));
    expect(m.step(3), ('', ''));
    expect(missionTeamLine(m), 'Équipe MMI · livraison le 15 déc. 2026');
    expect(missionDate('2026-10-30T09:00:00Z'), '30 oct. 2026');
  });

  test('sans mission réelle : les écrans de suivi renvoient vers « Votre besoin »', () {
    expect(Mission.none.real, isFalse);
    expect(redirectMissionScreen(ready: true, loaded: true, mission: Mission.none), isTrue);
    expect(redirectMissionScreen(ready: true, loaded: false, mission: Mission.none), isFalse, reason: 'lecture pas encore aboutie');
    expect(redirectMissionScreen(ready: false, loaded: true, mission: Mission.none), isFalse, reason: 'maquette');
    expect(redirectMissionScreen(ready: true, loaded: true, mission: Mission.fromServer(_row, null, const [])), isFalse);
    expect(missionScreens, containsAll(['192', '194', '197', '201']));
  });

  test('hors serveur : la mission d’exemple de la maquette ; connecté : jamais', () {
    final demo = ProviderContainer();
    addTearDown(demo.dispose);
    expect(demo.read(missionProvider).id, '#BR-0412');
    Backend.ready = true;
    final live = ProviderContainer();
    addTearDown(live.dispose);
    expect(live.read(missionProvider).id, isEmpty);
    expect(live.read(missionProvider).real, isFalse);
  });

  testWidgets('201 connecté : la vraie mission, sans mission inventée, note ni gains gonflés', (tester) async {
    Backend.ready = true;
    await _pump(tester, const G_201(), _Real.new);
    expect(find.text('Affiche du gala'), findsOneWidget);
    expect(find.text('Emballage savons Kamga'), findsNothing);
    expect(find.text('Spot promo parfums'), findsNothing);
    expect(find.text('4,9'), findsNothing);
    expect(find.text('21 k'), findsOneWidget, reason: '70 % des 30 000 FCFA validés, sans les 245 000 de la maquette');
  });

  testWidgets('192 connecté : statut, date et équipe réels', (tester) async {
    Backend.ready = true;
    await _pump(tester, const G_192(), _Real.new);
    expect(find.text('Équipe attribuée'), findsOneWidget);
    expect(find.text('30 oct. 2026'), findsOneWidget);
    expect(find.text('MMI'), findsOneWidget);
    expect(find.text('12 oct. · 09:14'), findsNothing);
  });
}
