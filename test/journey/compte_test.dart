import 'package:boutik_ecole/figma/g/g_27.dart';
import 'package:boutik_ecole/figma/g/g_31.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/compte.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<ProviderContainer> monter(WidgetTester t, Widget ecran, {required bool connecte, List<Override> overrides = const []}) async {
    Backend.ready = connecte;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: ecran)));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byWidget(ecran)));
    if (connecte) {
      c.read(authProvider.notifier).login(demoAccount);
      await t.pumpAndSettle();
    }
    return c;
  }

  test('ligne d’adresse', () {
    expect(addressLine({'line': 'Rue 1', 'district': 'Akwa', 'city': 'Douala', 'landmark': 'Pharmacie'}), 'Rue 1, Akwa, Douala, Repère : Pharmacie');
    expect(addressLine({'line': 'Rue 1', 'district': '', 'city': 'Douala', 'landmark': ''}), 'Rue 1, Douala');
  });

  testWidgets('27 connecté : adresses réelles, aucune adresse de maquette', (t) async {
    await monter(t, const G_27(), connecte: true, overrides: [
      addressesProvider.overrideWith(() => _Rows('table:addresses', [
            {'id': '1', 'recipient': 'Alice Test', 'phone': '699000000', 'city': 'Douala', 'district': 'Akwa', 'line': 'Rue 5', 'landmark': ''}
          ]))
    ]);
    expect(find.textContaining('Alice Test'), findsOneWidget);
    expect(find.text('Ajouter une adresse'), findsOneWidget);
    expect(find.textContaining('Ndokoti'), findsNothing);
  });

  testWidgets('27 connecté sans adresse : état vide', (t) async {
    await monter(t, const G_27(), connecte: true, overrides: [addressesProvider.overrideWith(() => _Rows('table:addresses', const []))]);
    expect(find.textContaining('Aucune adresse enregistrée'), findsOneWidget);
    expect(find.textContaining('Ndokoti'), findsNothing);
  });

  testWidgets('31 connecté : avis réels du produit choisi', (t) async {
    final c = await monter(t, const G_31(), connecte: true, overrides: [
      productReviewsProvider.overrideWith((ref, title) async => const <Map<String, dynamic>>[])
    ]);
    final titre = c.read(selectedProductProvider).title;
    expect(find.textContaining('Aucun avis pour'), findsOneWidget);
    expect(find.textContaining('dont l’article a été préparé'), findsOneWidget);
    expect(find.textContaining(titre), findsWidgets);
    expect(find.text('(24 avis)'), findsNothing);
  });

  testWidgets('31 : erreur de lecture distinguée du vide', (t) async {
    await monter(t, const G_31(), connecte: true, overrides: [
      productReviewsProvider.overrideWith((ref, title) async => throw StateError('x'))
    ]);
    expect(find.textContaining('Les avis ne peuvent pas être chargés'), findsOneWidget);
    expect(find.textContaining('Aucun avis pour'), findsNothing);
  });

  testWidgets('31 : avis publics affichés et texte vide exact', (t) async {
    await monter(t, const G_31(), connecte: true, overrides: [
      productReviewsProvider.overrideWith((ref, title) async => [
            {'rating': 4, 'comment': 'Très bien fini', 'created_at': '2026-11-01T10:00:00Z'}
          ])
    ]);
    expect(find.text('Très bien fini'), findsOneWidget);
    expect(find.text('1 avis'), findsOneWidget);
  });

  testWidgets('27 et 31 hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_27(), connecte: false);
    expect(find.textContaining('Ndokoti'), findsWidgets);
  });
}
