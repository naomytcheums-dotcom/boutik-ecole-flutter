import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Décisions du 01/11 : S1 est l'écran de démarrage (passage seul à 01) ; A2 a les mêmes destinations que 231.
void main() {
  tearDown(() => GAnim.enabled = true);

  testWidgets('S1 : écran de lancement, puis l’accueil 01 s’ouvre seul', (tester) async {
    GAnim.enabled = true;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: BoutikEcoleApp(initialLocation: '/s/S1')));
    await tester.pump();
    GoRouter router() => GoRouter.of(tester.element(find.byType(SplashAdvance)));
    expect(router().state.uri.path, '/s/S1');
    expect(find.text('Chargement…'), findsOneWidget);
    await tester.pump(SplashAdvance.delay + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(SplashAdvance), findsNothing);
    expect(find.text('Chargement…'), findsNothing);
    GAnim.enabled = false; // arrête les animations de l'accueil avant la fin du test
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('S1 sans animation (rendus de référence) : aucun minuteur, l’écran reste affiché', (tester) async {
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: BoutikEcoleApp(initialLocation: '/s/S1')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Chargement…'), findsOneWidget);
  });

  test('A2 a les mêmes destinations que 231 (dont « Voix en texte » → a3)', () {
    final a2 = File('lib/figma/g/g_a2.dart').readAsStringSync();
    final k = File('lib/figma/g/g_231.dart').readAsStringSync();
    Set<String> targets(String s) => {for (final m in RegExp(r"(?:gOpen|gTab)\(context, '([^']+)'\)").allMatches(s)) m.group(1)!};
    expect(targets(a2), targets(k));
  });
}
