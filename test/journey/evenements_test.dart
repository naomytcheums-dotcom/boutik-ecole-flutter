import 'package:boutik_ecole/figma/g/g_100.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/evenements.dart';
import 'package:boutik_ecole/figma/live/store.dart' show nowProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Events extends EventsNotifier {
  _Events(this.v);
  final List<AppEvent>? v;
  @override
  List<AppEvent>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  // jeudi 5 novembre 2026 : la semaine va du lundi 2 au dimanche 8
  final now = DateTime(2026, 11, 5, 10);

  Future<void> monter(WidgetTester t, {required bool connecte, List<AppEvent>? events}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [nowProvider.overrideWithValue(now), eventsProvider.overrideWith(() => _Events(events))],
      child: const MaterialApp(home: G_100()),
    ));
    await t.pumpAndSettle();
  }

  test('semaine et libellé de date', () {
    expect(weekStart(DateTime(2026, 11, 5)), DateTime(2026, 11, 2));
    final e = AppEvent(id: '1', title: 'Atelier', kind: 'atelier', startsAt: DateTime(2026, 11, 6, 15), place: 'Salle B2', price: 0, capacity: 12, registered: 11, mine: false);
    expect(e.when, 'Ven. 6 nov. · 15 h · Salle B2');
    expect(e.left, 1);
    expect(e.full, isFalse);
  });

  testWidgets('connecté sans événement : aucun événement inventé, état vide clair', (t) async {
    await monter(t, connecte: true, events: const []);
    expect(find.text('Exposition des innovations'), findsNothing);
    expect(find.text('Salon des créations étudiantes'), findsNothing);
    expect(find.textContaining('Aucun événement cette semaine'), findsOneWidget);
  });

  testWidgets('connecté : les événements du serveur s’affichent avec places, prix et inscription', (t) async {
    final e = AppEvent(id: '1', title: 'Atelier test', kind: 'atelier', startsAt: DateTime(2026, 11, 6, 15), place: 'Salle B2', price: 0, capacity: 12, registered: 2, mine: false);
    await monter(t, connecte: true, events: [e]);
    expect(find.text('Atelier test'), findsOneWidget);
    expect(find.text('Ven. 6 nov. · 15 h · Salle B2'), findsOneWidget);
    expect(find.text('Gratuit · 10 places'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.text('Exposition des innovations'), findsNothing);
  });

  testWidgets('connecté : toucher un jour filtre la liste', (t) async {
    final a = AppEvent(id: '1', title: 'Atelier vendredi', kind: 'atelier', startsAt: DateTime(2026, 11, 6, 15), place: '', price: 0, capacity: null, registered: 0, mine: false);
    final b = AppEvent(id: '2', title: 'Expo samedi', kind: 'exposition', startsAt: DateTime(2026, 11, 7, 10), place: '', price: 500, capacity: null, registered: 0, mine: true);
    await monter(t, connecte: true, events: [a, b]);
    expect(find.text('Atelier vendredi'), findsOneWidget);
    expect(find.text('Expo samedi'), findsOneWidget);
    await t.tap(find.text('7'));
    await t.pumpAndSettle();
    expect(find.text('Atelier vendredi'), findsNothing);
    expect(find.text('Expo samedi'), findsOneWidget);
    expect(find.text('Inscrit(e)'), findsOneWidget);
  });

  testWidgets('hors connexion : la démonstration de la maquette reste affichée', (t) async {
    await monter(t, connecte: false);
    expect(find.text('Exposition des innovations'), findsOneWidget);
  });
}
