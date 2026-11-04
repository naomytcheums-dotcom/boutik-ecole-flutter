import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/core/router/screen_entry.dart';
import 'package:boutik_ecole/figma/g/g_108.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Consoles web (toile de 1272 px) sur tablette et téléphone : barre d'application, menu latéral en tiroir, contenu défilant.
/// Écrans de borne et de tablette plus larges que l'écran : largeur adaptée avec défilement vertical.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() => GScreen.mockupFrame = true);

  Future<int> entrees(WidgetTester tester) async {
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).last);
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    return find.descendant(of: find.byType(Drawer), matching: find.byType(ListTile)).evaluate().length;
  }

  for (final size in const [Size(768, 1024), Size(360, 740)]) {
    testWidgets('108 à ${size.width.toInt()}×${size.height.toInt()} : tiroir avec les entrées du menu, navigation opérationnelle', (tester) async {
      await pumpScreen(tester, '108', size: size);
      expect(tester.takeException(), isNull);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Boutik-École'), findsOneWidget);
      // le menu latéral n'est plus dans la page : seul le tiroir le porte
      expect(find.text('Étudiants et vendeurs'), findsNothing);
      final router = GoRouter.of(tester.element(find.byType(G_108)));
      expect(await entrees(tester), greaterThanOrEqualTo(5));
      expect(find.text('Étudiants et vendeurs'), findsOneWidget);
      await tester.tap(find.text('Étudiants et vendeurs'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/s/109');
    });
  }

  // un test par écran : l'application monte son routeur une seule fois par test
  for (final s in screensById.values.where((s) => s.format == ScreenFormat.web)) {
    for (final size in const [Size(768, 1024), Size(360, 740)]) {
      testWidgets('console ${s.id} à ${size.width.toInt()}×${size.height.toInt()} : barre, tiroir avec au moins une entrée', (tester) async {
        await pumpScreen(tester, s.id, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(AppBar), findsOneWidget);
        expect(await entrees(tester), greaterThan(0), reason: 'aucune entrée de menu reconstruite sur ${s.id}');
      });
    }
  }

  for (final id in ['206', '207', '208', '209', '210', '287']) {
    testWidgets('borne ou tablette $id : largeur adaptée au téléphone, sans exception', (tester) async {
      await pumpScreen(tester, id, size: const Size(390, 800));
      expect(tester.takeException(), isNull);
      final scroll = find.byType(SingleChildScrollView);
      expect(scroll, findsWidgets);
      expect(tester.getSize(scroll.first).width, 390);
    });
  }
}
