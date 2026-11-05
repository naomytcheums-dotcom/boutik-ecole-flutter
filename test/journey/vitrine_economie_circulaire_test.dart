import 'package:boutik_ecole/figma/g/g_102.dart';
import 'package:boutik_ecole/figma/g/g_106.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/produits_liste.dart';
import 'package:boutik_ecole/figma/live/seller.dart' show allProductsProvider;
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

const _lampe = LiveProduct('Lampe en bois recyclé', 'Génie civil', 25000, 'Alice', 'Lampe fabriquée à partir de bois de récupération.', 'placeholder');
const _sac = LiveProduct('Sac à dos', 'Design', 18000, 'Bruno', 'Sac neuf en toile.', 'placeholder');

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget ecran, {required bool connecte, List<LiveProduct> produits = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [allProductsProvider.overrideWithValue(produits)], child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
  }

  test('reconnaissance des produits de récupération', () {
    expect(isRecycled(_lampe), isTrue);
    expect(isRecycled(_sac), isFalse);
  });

  testWidgets('106 connecté sans produit : aucun produit ni message de maquette, état vide clair', (t) async {
    await monter(t, const G_106(), connecte: true);
    expect(find.text('Sac en bâche recyclée'), findsNothing);
    expect(find.textContaining('Aucune création en matériaux récupérés'), findsOneWidget);
  });

  testWidgets('106 connecté : seuls les produits de récupération réels sont affichés', (t) async {
    await monter(t, const G_106(), connecte: true, produits: [_lampe, _sac]);
    expect(find.text('Lampe en bois recyclé'), findsOneWidget);
    expect(find.text('Sac à dos'), findsNothing);
  });

  testWidgets('102 connecté : compteurs réels, aucun lancement ni collection inventés', (t) async {
    await monter(t, const G_102(), connecte: true, produits: [_lampe, _sac]);
    expect(find.text('Lancement officiel le 24 octobre'), findsNothing);
    expect(find.text('Collection « Recyclé & Design »'), findsNothing);
    expect(find.text('2'), findsNWidgets(3), reason: '2 pièces, 2 créateurs, 2 départements');
    expect(find.text('Sac à dos'), findsOneWidget);
  });

  testWidgets('102 connecté sans produit : état vide', (t) async {
    await monter(t, const G_102(), connecte: true);
    expect(find.textContaining('Aucun produit publié'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('102 et 106 hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_102(), connecte: false);
    expect(find.text('Lancement officiel le 24 octobre'), findsOneWidget);
    await monter(t, const G_106(), connecte: false);
    expect(find.text('Sac en bâche recyclée'), findsOneWidget);
  });
}
