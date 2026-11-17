import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/social_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t) async {
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        publicProfileProvider('u1').overrideWith((ref) async => SocialProfile.fromJson({'id': 'u1', 'name': 'Brice Recette', 'role': 'student', 'department': 'Informatique'})),
        authorPostsProvider('u1').overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: Scaffold(body: SocialProfilePanel(userId: 'u1'))),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('profil d’un autre : bouton Bloquer présent, cible >= 48 dp, état vide réel, aucun débordement à 390 px', (t) async {
    await monter(t);
    expect(t.takeException(), isNull);
    final block = find.byKey(const Key('social-block'));
    expect(block, findsOneWidget);
    expect(t.getSize(block).height, greaterThanOrEqualTo(48));
    expect(find.text('Aucune publication pour le moment.'), findsOneWidget);
  });
}
