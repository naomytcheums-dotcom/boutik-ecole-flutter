import 'package:boutik_ecole/figma/g/g_198.dart';
import 'package:boutik_ecole/figma/g/g_199.dart';
import 'package:boutik_ecole/figma/g/g_200.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/missions_console.dart';
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

class _Sel extends SelectedMission {
  _Sel(this.v);
  final String? v;
  @override
  String? build() => v;
}

Map<String, dynamic> _m(String id, String title, String status, {int proposals = 0, String team = ''}) => {
      'id': id, 'number': 'M-$id', 'title': title, 'status': status, 'created_at': '2026-11-01T10:00:00Z', 'deadline': null,
      'budget_min': 100000, 'budget_max': 200000, 'team': team, 'client': 'Société Test', 'proposals': proposals,
      'milestones_total': 90000, 'milestones_validated': 30000, 'milestones_count': 3,
    };

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

  testWidgets('198 connecté : briefs réels, aucune entreprise de maquette', (t) async {
    await monter(t, const G_198(), connecte: true, overrides: [
      staffMissionsProvider.overrideWith(() => _Rows('staff_missions', [_m('1', 'Logo Test', 'published', proposals: 2), _m('2', 'Site Test', 'assigned')]))
    ]);
    expect(find.text('Logo Test'), findsOneWidget);
    expect(find.text('Site Test'), findsNothing);
    expect(find.text('Parfums Mbella'), findsNothing);
  });

  testWidgets('198 connecté sans droit : message d’accès', (t) async {
    await monter(t, const G_198(), connecte: true, overrides: [staffMissionsProvider.overrideWith(() => _Rows('staff_missions', const [], fail: true))]);
    expect(find.textContaining('Accès réservé'), findsWidgets);
    expect(find.text('Parfums Mbella'), findsNothing);
  });

  testWidgets('199 connecté : besoin choisi et propositions réelles', (t) async {
    await monter(t, const G_199(), connecte: true, overrides: [
      staffMissionsProvider.overrideWith(() => _Rows('staff_missions', [_m('1', 'Logo Test', 'published', proposals: 1)])),
      selectedMissionProvider.overrideWith(() => _Sel('1')),
      missionProposalsProvider.overrideWith(() => _Rows('staff_mission_proposals', [{'id': 'p', 'author': 'Alice Test', 'amount': 150000, 'delay_days': 14, 'status': 'submitted', 'department': 'GI'}]))
    ]);
    expect(find.text('Logo Test'), findsOneWidget);
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Attribuer'), findsOneWidget);
    expect(find.text('Aminata Bello'), findsNothing);
  });

  testWidgets('199 connecté sans besoin choisi : invitation à choisir', (t) async {
    await monter(t, const G_199(), connecte: true, overrides: [staffMissionsProvider.overrideWith(() => _Rows('staff_missions', const []))]);
    expect(find.textContaining('Choisissez d’abord'), findsOneWidget);
    expect(find.text('Aminata Bello'), findsNothing);
  });

  testWidgets('200 connecté : missions attribuées avec jalons réels', (t) async {
    await monter(t, const G_200(), connecte: true, overrides: [
      staffMissionsProvider.overrideWith(() => _Rows('staff_missions', [_m('2', 'Site Test', 'assigned', team: 'Alice Test'), _m('1', 'Logo Test', 'published')]))
    ]);
    expect(find.text('Site Test'), findsOneWidget);
    expect(find.text('Logo Test'), findsNothing);
    expect(find.textContaining('3 jalons'), findsOneWidget);
    expect(find.text('Logo Mbella'), findsNothing);
  });

  for (final c in <(String, Widget, String)>[('198', const G_198(), 'Parfums Mbella'), ('199', const G_199(), 'Aminata Bello'), ('200', const G_200(), 'Logo Mbella')]) {
    testWidgets('${c.$1} hors connexion : la démonstration reste affichée', (t) async {
      await monter(t, c.$2, connecte: false);
      expect(find.text(c.$3), findsWidgets);
    });
  }
}
