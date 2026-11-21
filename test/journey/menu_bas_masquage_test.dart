import 'package:boutik_ecole/figma/gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Menu du bas façon Facebook : il disparaît quand on fait défiler la page vers le bas et réapparaît dès qu'on remonte
/// ou qu'on est en haut de la page.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() => GScreen.mockupFrame = true);

  Offset decalage(WidgetTester t) => t.widget<AnimatedSlide>(find.ancestor(of: find.byKey(gMenuKey), matching: find.byType(AnimatedSlide)).first).offset;

  testWidgets('le menu se masque en descendant, revient en remontant et en haut de page', (tester) async {
    await pumpScreen(tester, '03', size: const Size(360, 640));
    final vue = find.byType(SingleChildScrollView).first;
    final scroll = tester.state<ScrollableState>(find.descendant(of: vue, matching: find.byType(Scrollable)).first);
    expect(scroll.position.maxScrollExtent, greaterThan(150));
    expect(decalage(tester), Offset.zero, reason: 'menu visible au chargement');

    await tester.drag(vue, const Offset(0, -140), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(scroll.position.pixels, greaterThan(60));
    expect(decalage(tester).dy, greaterThan(1), reason: 'menu masqué en descendant');

    await tester.drag(vue, const Offset(0, 60), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(decalage(tester), Offset.zero, reason: 'menu de retour dès qu’on remonte');

    await tester.drag(vue, const Offset(0, -140), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(decalage(tester).dy, greaterThan(1));
    for (var i = 0; i < 12 && scroll.position.pixels > 0; i++) {
      await tester.drag(vue, const Offset(0, 300), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(scroll.position.pixels, 0);
    expect(decalage(tester), Offset.zero, reason: 'menu visible en haut de page');
  });

  testWidgets('menu masqué : ses boutons ne reçoivent plus de toucher', (tester) async {
    await pumpScreen(tester, '03', size: const Size(360, 640));
    final vue = find.byType(SingleChildScrollView).first;
    await tester.drag(vue, const Offset(0, -140), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    final ignore = tester.widget<IgnorePointer>(find.ancestor(of: find.byKey(gMenuKey), matching: find.byType(IgnorePointer)).first);
    expect(ignore.ignoring, isTrue);
  });
}
