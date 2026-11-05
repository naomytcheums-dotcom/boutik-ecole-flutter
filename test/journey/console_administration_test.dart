import 'package:boutik_ecole/figma/g/g_119.dart';
import 'package:boutik_ecole/figma/g/g_120.dart';
import 'package:boutik_ecole/figma/g/g_121.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v, {this.fail = false});
  final List<Map<String, dynamic>>? v;
  final bool fail;
  @override
  List<Map<String, dynamic>>? build() {
    error = fail;
    return v;
  }
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const [], bool login = false}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (login) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés de rôle et de dernière connexion', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(roleLabel('dept'), 'Responsable');
    expect(roleLabel('student'), 'Étudiant');
    expect(lastLoginLabel(null, now), 'Jamais');
    expect(lastLoginLabel(DateTime(2026, 11, 5, 9, 12).toUtc().toIso8601String(), now), 'Aujourd’hui 09:12');
    expect(lastLoginLabel(DateTime(2026, 11, 4, 9, 12).toUtc().toIso8601String(), now), 'Hier 09:12');
  });

  testWidgets('119 connecté : départements réels, aucun département de maquette', (t) async {
    await monter(t, const G_119(), connecte: true, login: true, overrides: [
      adminDepartmentsProvider.overrideWith(() => _Rows('admin_departments', [{'name': 'Informatique', 'status': 'verified', 'students': 12, 'head': 'Dr Test'}]))
    ]);
    expect(find.text('Informatique'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.text('Génie informatique'), findsNothing);
  });

  testWidgets('119 connecté sans département : état vide', (t) async {
    await monter(t, const G_119(), connecte: true, login: true, overrides: [adminDepartmentsProvider.overrideWith(() => _Rows('admin_departments', const []))]);
    expect(find.textContaining('Aucun département enregistré'), findsOneWidget);
  });

  testWidgets('120 connecté : personnes réelles avec rôle, département et état', (t) async {
    await monter(t, const G_120(), connecte: true, login: true, overrides: [
      consoleUsersProvider.overrideWith(() => _Rows('admin_users', [{'name': 'Alice Test', 'role': 'student', 'department': 'Informatique', 'last_login': null, 'suspended': true, 'students': 0}]))
    ]);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Étudiant'), findsOneWidget);
    expect(find.text('Suspendu'), findsOneWidget);
    expect(find.text('Jamais'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
  });

  testWidgets('120 connecté sans droit : message d’accès, aucune ligne de maquette', (t) async {
    await monter(t, const G_120(), connecte: true, login: true, overrides: [consoleUsersProvider.overrideWith(() => _Rows('admin_users', const [], fail: true))]);
    expect(find.textContaining('Accès réservé à la gestion'), findsOneWidget);
    expect(find.text('Mariam Essono'), findsNothing);
  });

  testWidgets('121 connecté : responsables réels', (t) async {
    await monter(t, const G_121(), connecte: true, login: true, overrides: [
      adminResponsablesProvider.overrideWith(() => _Rows('admin_users', [{'name': 'Dr Réel', 'role': 'dept', 'department': 'Génie civil', 'last_login': null, 'suspended': false, 'students': 7}]))
    ]);
    expect(find.text('Dr Réel'), findsOneWidget);
    expect(find.text('Responsable'), findsWidgets);
    expect(find.text('7 étudiants'), findsOneWidget);
  });

  for (final c in <(String, Widget, String)>[('119', const G_119(), 'Génie informatique'), ('120', const G_120(), 'Mariam Essono'), ('121', const G_121(), 'Génie informatique')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
