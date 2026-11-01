import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/g/g_02.dart';
import 'package:boutik_ecole/figma/g/g_03.dart';
import 'package:boutik_ecole/figma/g/g_175.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/home_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Retours du 01/11 : « Commencer » (02) déroule les 3 écrans d'accueil avant l'accueil 03,
/// et la flèche « À la une » de 03 fait défiler les 3 visuels annoncés par les points.
void main() {
  setUp(() {
    GAnim.enabled = false;
    HomeHero.index.value = 0;
  });
  tearDown(() => GAnim.enabled = true);

  Future<GoRouter> open(WidgetTester tester, String location, Type screen, {Size size = const Size(390, 939)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: BoutikEcoleApp(initialLocation: location)));
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(screen)));
  }

  testWidgets('02 « Commencer » : 176 → 175 → 177 → accueil 03', (tester) async {
    final r = await open(tester, '/s/02', G_02);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(r.state.uri.path, '/s/176');
    expect(find.text('Achetez local et étudiant'), findsOneWidget);
    for (final (next, title) in [('/s/175', 'Vendez vos créations'), ('/s/177', 'Recrutez les talents de demain')]) {
      await tester.tap(find.text('Continuer').last);
      await tester.pumpAndSettle();
      expect(r.state.uri.path, next);
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('Continuer').last);
    await tester.pumpAndSettle();
    expect(r.state.uri.path, '/s/03');
  });

  testWidgets('hors visite, « Continuer » garde la destination du rôle (175 → 57)', (tester) async {
    final r = await open(tester, '/s/175', G_175);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(r.state.uri.path, '/s/57');
  });

  testWidgets('maquette d’ordinateur sur téléphone : agrandissable, et ses liens restent actifs', (tester) async {
    final r = await open(tester, '/s/237', InteractiveViewer, size: const Size(390, 844));
    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(iv.maxScale, closeTo(1280 / 390, 0.01));
    const s = 390 / 1280;
    await tester.tapAt(Offset(202 * s, (844 - 820 * s) / 2 + 141 * s));
    await tester.pumpAndSettle();
    expect(r.state.uri.path, '/s/238');
  });

  testWidgets('maquette d’ordinateur sur ordinateur : rendu inchangé, sans zoom', (tester) async {
    await open(tester, '/s/237', Scaffold, size: const Size(1280, 900));
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('03 : la flèche et le glissement changent le visuel « À la une »', (tester) async {
    await open(tester, '/s/03', G_03);
    expect(find.text('L’innovation\nétudiante en action'), findsOneWidget);
    await tester.tapAt(const Offset(37.917 + 15, 463.125 + 15));
    await tester.pumpAndSettle();
    expect(HomeHero.index.value, 1);
    expect(find.text('Vendez vos\ncréations'), findsOneWidget);
    expect(find.text('L’innovation\nétudiante en action'), findsNothing);
    await tester.tapAt(const Offset(37.917 + 15, 463.125 + 15));
    await tester.pumpAndSettle();
    expect(find.text('Recrutez les\ntalents de demain'), findsOneWidget);
    await tester.tapAt(const Offset(37.917 + 15, 463.125 + 15));
    await tester.pumpAndSettle();
    expect(HomeHero.index.value, 0);
    await tester.dragFrom(const Offset(300, 400), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(HomeHero.index.value, 1);
    await tester.dragFrom(const Offset(100, 400), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(HomeHero.index.value, 0);
  });
}
