import 'package:boutik_ecole/figma/g/g_100.dart';
import 'package:boutik_ecole/figma/g/g_124.dart';
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

class _Admin extends AdminEventsNotifier {
  _Admin(this.v);
  final List<AdminEvent>? v;
  @override
  List<AdminEvent>? build() => v;
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
    expect(find.textContaining('Aucun événement ce mois-ci'), findsOneWidget);
  });

  testWidgets('connecté : les événements du serveur s’affichent avec places, prix et inscription', (t) async {
    final e = AppEvent(id: '1', title: 'Atelier test', kind: 'atelier', startsAt: DateTime(2026, 11, 6, 15), place: 'Salle B2', price: 0, capacity: 12, registered: 2, mine: false);
    await monter(t, connecte: true, events: [e]);
    expect(find.text('Atelier test'), findsWidgets);
    expect(find.text('Ven. 6 nov. · 15 h · Salle B2'), findsOneWidget);
    expect(find.text('Gratuit · 10 places'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
    expect(find.text('Exposition des innovations'), findsNothing);
  });

  testWidgets('connecté : toucher un jour filtre la liste', (t) async {
    final a = AppEvent(id: '1', title: 'Atelier vendredi', kind: 'atelier', startsAt: DateTime(2026, 11, 6, 15), place: '', price: 0, capacity: null, registered: 0, mine: false);
    final b = AppEvent(id: '2', title: 'Expo samedi', kind: 'exposition', startsAt: DateTime(2026, 11, 7, 10), place: '', price: 500, capacity: null, registered: 0, mine: true);
    await monter(t, connecte: true, events: [a, b]);
    expect(find.text('Atelier vendredi'), findsWidgets);
    expect(find.text('Expo samedi'), findsWidgets);
    await t.tap(find.text('7'));
    await t.pumpAndSettle();
    expect(find.text('Inscrit(e)'), findsOneWidget);
  });

  testWidgets('hors connexion : la démonstration de la maquette reste affichée', (t) async {
    await monter(t, connecte: false);
    expect(find.text('Exposition des innovations'), findsOneWidget);
  });

  Future<void> monter124(WidgetTester t, {required bool connecte, List<AdminEvent>? events}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [adminEventsProvider.overrideWith(() => _Admin(events))], child: const MaterialApp(home: G_124())));
    await t.pumpAndSettle();
  }

  testWidgets('124 connecté sans événement : aucun événement de maquette, état vide', (t) async {
    await monter124(t, connecte: true, events: const []);
    expect(find.text('Exposition des innovations'), findsNothing);
    expect(find.text('Aucun événement enregistré.'), findsOneWidget);
  });

  testWidgets('124 connecté : les événements réels avec inscrits et statut', (t) async {
    final e = AdminEvent(title: 'Atelier réel', startsAt: DateTime(2026, 11, 6, 15), place: 'Salle B2', registered: 3, capacity: 12, status: 'published');
    await monter124(t, connecte: true, events: [e]);
    expect(find.text('Atelier réel'), findsOneWidget);
    expect(find.text('3 / 12'), findsOneWidget);
    expect(find.text('Publié'), findsOneWidget);
    expect(find.text('Exposition des innovations'), findsNothing);
  });

  testWidgets('124 hors connexion : la démonstration reste affichée', (t) async {
    await monter124(t, connecte: false);
    expect(find.text('Exposition des innovations'), findsOneWidget);
  });
}
