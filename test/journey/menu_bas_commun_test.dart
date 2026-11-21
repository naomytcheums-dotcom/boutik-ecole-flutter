import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/menu_global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Menu du bas commun : les pages écrites à la main ont le même menu que les écrans Figma, pour tous les acteurs connectés,
/// sauf sur les pages qui n'en veulent pas (paiement, partage public de CV) et quand personne n'est connecté.
void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t, String route, {required bool connecte}) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [if (connecte) initialAccountProvider.overrideWithValue(seedAccounts.last)],
      child: BoutikEcoleApp(initialLocation: route),
    ));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 300));
  }

  final menu = find.byKey(const ValueKey('menu-bas-commun'));

  test('routes admissibles : pages à la main oui, écrans Figma / paiement / CV public non', () {
    expect(SharedBottomMenu.eligible('/marche'), isTrue);
    expect(SharedBottomMenu.eligible('/entreprise/espace/abc'), isTrue);
    expect(SharedBottomMenu.eligible('/departement'), isTrue);
    expect(SharedBottomMenu.eligible('/opportunites/mes'), isTrue);
    expect(SharedBottomMenu.eligible('/s/03'), isFalse);
    expect(SharedBottomMenu.eligible('/paiement'), isFalse);
    expect(SharedBottomMenu.eligible('/cv/abc'), isFalse);
    expect(SharedBottomMenu.eligible('/'), isFalse);
  });

  testWidgets('connecté : le menu est présent sur une page écrite à la main, avec cinq onglets', (t) async {
    await monter(t, '/marche', connecte: true);
    expect(menu, findsOneWidget);
    for (final l in ['Kéla', 'Messages', 'Accueil', 'Réseau social', 'Profil']) {
      expect(find.bySemanticsLabel(l), findsWidgets, reason: 'onglet $l');
    }
  });

  testWidgets('visiteur : pas de menu commun sur une page écrite à la main', (t) async {
    await monter(t, '/marche', connecte: false);
    expect(menu, findsNothing);
  });

  testWidgets('écran Figma : un seul menu (celui de l’écran), pas de doublon', (t) async {
    await monter(t, '/s/03', connecte: true);
    expect(menu, findsNothing);
    expect(find.byKey(gMenuKey), findsOneWidget);
  });
}
