import 'package:boutik_ecole/figma/g/g_113.dart';
import 'package:boutik_ecole/figma/g/g_114.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/encadrement.dart';
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

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(1280, 890);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    if (connecte) {
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
  }

  test('libellés des états', () {
    expect(productionStatus('en_retard'), 'En retard');
    expect(productionStatus('terminee'), 'Terminée');
    expect(productionStatus('en_cours'), 'En cours');
  });

  testWidgets('113 connecté : productions réelles et compteurs calculés', (t) async {
    await monter(t, const G_113(), connecte: true, overrides: [
      staffProductionsProvider.overrideWith(() => _Rows('staff_productions', [
            {'id': '1', 'title': 'Lot Test', 'team': 'Équipe A', 'mentor': 'Dr Test', 'progress': 40, 'status': 'en_cours', 'finished_at': null},
            {'id': '2', 'title': 'Appli Test', 'team': 'Équipe B', 'mentor': '', 'progress': 20, 'status': 'en_retard', 'finished_at': null},
          ]))
    ]);
    expect(find.text('Lot Test'), findsOneWidget);
    expect(find.text('En retard'), findsWidgets);
    expect(find.text('Lot de 50 lampes recyclées'), findsNothing);
  });

  testWidgets('113 connecté vide : état vide, aucune ligne de maquette', (t) async {
    await monter(t, const G_113(), connecte: true, overrides: [staffProductionsProvider.overrideWith(() => _Rows('staff_productions', const []))]);
    expect(find.textContaining('Aucune production'), findsOneWidget);
    expect(find.text('Lot de 50 lampes recyclées'), findsNothing);
  });

  testWidgets('114 connecté : mentors réels', (t) async {
    await monter(t, const G_114(), connecte: true, overrides: [
      staffMentorsProvider.overrideWith(() => _Rows('staff_mentors', [
            {'id': '1', 'name': 'Dr Test', 'role': 'Mentor', 'specialty': 'Réseaux', 'active': true, 'productions': 2}
          ]))
    ]);
    expect(find.text('Dr Test'), findsOneWidget);
    expect(find.text('Dr Paul Tchoupo'), findsNothing);
  });

  testWidgets('114 connecté sans droit : message d’accès', (t) async {
    await monter(t, const G_114(), connecte: true, overrides: [staffMentorsProvider.overrideWith(() => _Rows('staff_mentors', const [], fail: true))]);
    expect(find.textContaining('Accès réservé'), findsWidgets);
    expect(find.text('Dr Paul Tchoupo'), findsNothing);
  });

  for (final c in <(String, Widget, String)>[('113', const G_113(), 'Lot de 50 lampes recyclées'), ('114', const G_114(), 'Dr Paul Tchoupo')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
