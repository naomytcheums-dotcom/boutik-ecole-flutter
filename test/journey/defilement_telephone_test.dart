import 'package:boutik_ecole/figma/gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Défilement tactile des écrans de téléphone (hors cadre de maquette) : le geste vertical doit faire défiler la page
/// du premier au dernier contenu, y compris lorsqu'il démarre sur un bouton ou une zone cliquable, et le menu du bas
/// ne doit jamais empêcher d'atteindre la dernière section.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() => GScreen.mockupFrame = true);

  const tailles = [Size(360, 640), Size(393, 852)];
  for (final id in ['03', '04', '20', '24', '32', '45']) {
    for (final size in tailles) {
      testWidgets('défilement tactile de $id à ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        await pumpScreen(tester, id, size: size);
        final vue = find.byType(SingleChildScrollView).first;
        final scroll = tester.state<ScrollableState>(find.descendant(of: vue, matching: find.byType(Scrollable)).first);
        final max = scroll.position.maxScrollExtent;
        expect(max, greaterThan(0), reason: '$id ne défile pas alors que son contenu dépasse l’écran');

        // glisser vers le haut à partir d'un point libre
        await tester.drag(vue, const Offset(0, -200), warnIfMissed: false);
        await tester.pump();
        expect(scroll.position.pixels, greaterThan(0), reason: 'le geste vers le haut ne fait pas défiler $id');

        // glisser à partir d'un élément cliquable (bouton, carte) : le défilement doit prendre le dessus sur le toucher
        final cibles = find.descendant(of: vue, matching: find.byType(GPress));
        var essayees = 0;
        for (final e in cibles.evaluate()) {
          final c = tester.getCenter(find.byWidget(e.widget));
          if (c.dy < 80 || c.dy > size.height - 160 || c.dx < 0 || c.dx > size.width) continue;
          final avant = scroll.position.pixels;
          await tester.dragFrom(c, const Offset(0, -40));
          await tester.pump();
          if (scroll.position.pixels <= avant && scroll.position.pixels < max) {
            fail('un glissement démarré sur une zone cliquable de $id est absorbé (${c.dx.round()},${c.dy.round()})');
          }
          if (++essayees >= 4) break;
        }

        // glisser à partir du menu du bas : le geste fait défiler la page au lieu d'être absorbé
        if (id == '03') {
          final avant = scroll.position.pixels;
          await tester.dragFrom(Offset(size.width / 2, size.height - 40), const Offset(0, 60));
          await tester.pump();
          expect(scroll.position.pixels, lessThan(avant), reason: 'le menu du bas absorbe le glissement sur $id');
        }

        // jusqu'en bas : la dernière section est atteinte, puis retour en haut
        for (var i = 0; i < 40 && scroll.position.pixels < max; i++) {
          await tester.dragFrom(Offset(size.width / 2, size.height / 2), const Offset(0, -300));
          await tester.pump();
        }
        expect(scroll.position.pixels, max, reason: 'le bas de $id n’est pas atteignable');
        for (var i = 0; i < 40 && scroll.position.pixels > 0; i++) {
          await tester.dragFrom(Offset(size.width / 2, size.height / 2), const Offset(0, 300));
          await tester.pump();
        }
        expect(scroll.position.pixels, 0, reason: 'le haut de $id n’est pas atteignable');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
