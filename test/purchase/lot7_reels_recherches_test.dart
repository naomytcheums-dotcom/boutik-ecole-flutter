import 'dart:io';

import 'package:boutik_ecole/features/design_lab/design_lab_screen.dart';
import 'package:boutik_ecole/figma/g/g_253.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:boutik_ecole/figma/live/searches.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot 7 : reels et défis (migration 20261101000600), recherches des écrans 49, 52, 25b, 104, 179, page de design.

class _Ch extends ChallengesNotifier {
  @override
  Challenges? build() => const Challenges(streak: 3, nextIn: 3, weekEndDays: 2, postsWeek: 1, points: 200);
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  test('défis : libellés réels', () {
    final c = Challenges.fromJson({'streak': 6, 'next_reward_in': 0, 'streak_reward_claimable': true, 'week_end_days': 2, 'posts_week': 3, 'posts_claimable': true, 'points': 200});
    expect(c.streakLabel, 'Série de 6 jours');
    expect(c.nextLabel, contains('récupérez votre boost'));
    expect(const Challenges(streak: 1, nextIn: 5).nextLabel, 'Encore 5 jours pour gagner un boost de 24 h');
    expect(compactCount(2600), '2,6 k');
    expect(compactCount(312), '312');
  });

  testWidgets('253 connecté : série et progression réelles, pas les chiffres de la maquette', (tester) async {
    Backend.ready = true;
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [challengesProvider.overrideWith(_Ch.new)], child: const MaterialApp(home: Scaffold(body: G_253()))));
    await tester.pump();
    expect(find.text('Série de 3 jours'), findsOneWidget);
    expect(find.text('Série de 5 jours'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('2 / 3'), findsNothing);
  });

  test('aide : les articles trouvés ouvrent un écran réel', () {
    expect(searchHelp('mot de passe').map((a) => a.$3), contains('15'));
    expect(searchHelp('hackathon').map((a) => a.$3), contains('160'));
    expect(searchHelp('x'), isEmpty);
    final screens = {for (final f in Directory('lib/figma/g').listSync()) f.uri.pathSegments.last};
    for (final a in helpArticles) {
      expect(screens, contains('g_${a.$3.toLowerCase().replaceAll('-', '_')}.dart'), reason: a.$1);
    }
  });

  testWidgets('page de design : bannières et pieds de page proposés', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DesignLabScreen()));
    await tester.pump();
    expect(find.text('Nouvelle direction visuelle'), findsOneWidget);
    expect(find.byType(HeroBanner), findsWidgets);
  });
}
