import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/g/g_03.dart';
import 'package:boutik_ecole/figma/g/g_175.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Téléphones réels (largeurs et hauteurs variables, barres du navigateur) : l'écran occupe toute la largeur et toute la
/// hauteur, sans fausse barre d'état, le menu du bas reste fixe et la fin du contenu défile au-dessus de lui.
void main() {
  setUp(() {
    GAnim.enabled = false;
    GScreen.mockupFrame = false;
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    GAnim.enabled = true;
  });

  Future<GoRouter> open(WidgetTester tester, String id, Type screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: BoutikEcoleApp(initialLocation: '/s/$id')));
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(screen)));
  }

  for (final size in const [Size(360, 640), Size(390, 664), Size(412, 839), Size(430, 740)]) {
    testWidgets('accueil 03 sur ${size.width.toInt()}×${size.height.toInt()} : plein écran, menu fixe, fin visible', (tester) async {
      final r = await open(tester, '03', G_03, size);
      expect(find.text('9:41'), findsNothing);
      final scroll = find.byType(SingleChildScrollView);
      // contenu à pleine largeur
      final layer = find.descendant(of: scroll, matching: find.byType(FittedBox)).first;
      expect(tester.getSize(layer).width, size.width);
      // le fond couvre tout l'écran
      expect(tester.getSize(find.byType(SingleChildScrollView)), size);
      // le menu fixe est collé en bas de l'écran
      final s = size.width / 390;
      final menu = find.byWidgetPredicate((w) => w is SizedBox && w.width == 390 * s && w.height != null && (w.height! - (915 - 851) * s).abs() < 0.5).first;
      expect(tester.getBottomLeft(menu).dy, closeTo(size.height, 0.5));
      // l'espace du menu est ajouté en bas : la fin du contenu peut défiler au-dessus du menu
      final st = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)));
      final menuH = (915 - 851 + 8) * s;
      expect(st.position.maxScrollExtent, closeTo((939 - 44) * s + menuH - size.height, 1));
      st.position.jumpTo(st.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // le bas du contenu (y = 939 dans la maquette) arrive juste au-dessus du menu
      final contentBottom = tester.getBottomLeft(layer).dy;
      expect(contentBottom, lessThanOrEqualTo(tester.getTopLeft(menu).dy + 0.5));
      // le menu reste utilisable : l'icône Kéla (maquette 255,872) ouvre 230
      await tester.tapAt(Offset(266 * s, size.height - (915 - 883) * s));
      await tester.pumpAndSettle();
      expect(r.state.uri.path, '/s/230');
    });
  }

  for (final size in const [Size(768, 1024), Size(1280, 800), Size(1920, 1080)]) {
    testWidgets('accueil 03 sur ${size.width.toInt()}×${size.height.toInt()} (tablette, ordinateur) : colonne de 480 px, sans fausse barre d’état, menu fixe', (tester) async {
      final r = await open(tester, '03', G_03, size);
      expect(find.text('9:41'), findsNothing);
      final scroll = find.byType(SingleChildScrollView);
      expect(tester.getSize(scroll).width, GScreen.maxColumn);
      expect(tester.getSize(scroll).height, size.height);
      // la colonne est centrée
      expect(tester.getCenter(scroll).dx, closeTo(size.width / 2, 0.5));
      // aucun débordement : le contenu défile jusqu'au bout
      final st = tester.state<ScrollableState>(find.descendant(of: scroll, matching: find.byType(Scrollable)));
      st.position.jumpTo(st.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // le menu du bas reste utilisable : l'icône Kéla ouvre 230
      final s = GScreen.maxColumn / 390;
      final left = (size.width - GScreen.maxColumn) / 2;
      await tester.tapAt(Offset(left + 266 * s, size.height - (915 - 883) * s));
      await tester.pumpAndSettle();
      expect(r.state.uri.path, '/s/230');
    });
  }

  testWidgets('175 sur 412×839 : barre « Passer / Continuer » fixe en bas et active', (tester) async {
    final r = await open(tester, '175', G_175, const Size(412, 839));
    const s = 412 / 390;
    await tester.tapAt(Offset(284 * s, 839 - (844 - 787) * s));
    await tester.pumpAndSettle();
    expect(r.state.uri.path, '/s/57');
  });
}
