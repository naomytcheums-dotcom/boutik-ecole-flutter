import 'package:boutik_ecole/figma/g/g_47.dart';
import 'package:boutik_ecole/figma/g/g_90.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/lots.dart';
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:boutik_ecole/figma/live/pay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lots missions, vœux, campagnes, certificats, bornes, exports et annulation avec motif (migration 20261031a).
void main() {
  setUpAll(loadAppFonts);
  setUp(() => Backend.ready = false);

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen) async {
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: Scaffold(body: screen))));
    await tester.pumpAndSettle();
    return c;
  }

  test('montants et durées lus dans les champs préremplis de la maquette', () {
    expect(firstInt('300 000 – 500 000 FCFA'), 300000);
    expect(lastInt('300 000 – 500 000 FCFA'), 500000);
    expect(firstInt('25\u202f000 FCFA'), 25000);
    expect(firstInt('30 jours'), 30);
    expect(firstInt('Quotidienne'), isNull);
    expect(lastInt(''), isNull);
  });

  test('export CSV : séparateur « ; », guillemets et retours à la ligne protégés', () {
    final csv = toCsv(['number', 'note'], [
      {'number': '#BE-2026-0001', 'note': 'simple'},
      {'number': '#BE-2026-0002', 'note': 'avec ; point-virgule et "guillemets"\net retour'},
    ]);
    final lines = csv.split('\r\n');
    expect(lines.first, 'number;note');
    expect(lines[1], '#BE-2026-0001;simple');
    expect(csv, contains('"avec ; point-virgule et ""guillemets""\net retour"'));
  });

  test('hors connexion : aucune fonction serveur n’est simulée', () async {
    expect((await Backend.rpc('save_mission', {})).error, 'Connexion requise.');
    final r = await Backend.rows('missions', 'id');
    expect(r.rows, isEmpty);
    expect(r.error, 'Connexion requise.');
    expect(await Backend.cancelOrderWithReason('#BE-2026-0001', 'other'), 'Connexion requise.');
  });

  test('motifs d’annulation identiques aux valeurs acceptées par le serveur', () {
    expect(cancelReasons, ['wrong_product', 'too_slow', 'better_offer', 'other']);
  });

  testWidgets('écran 90 : « Publier » sans serveur l’explique au lieu de simuler', (tester) async {
    await pump(tester, const G_90());
    await tester.tap(find.text('Publier'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Hors connexion'), findsOneWidget);
    expect(find.textContaining('Besoin publié'), findsNothing);
  });

  testWidgets('écran 47 : le motif choisi est mémorisé', (tester) async {
    final c = await pump(tester, const G_47());
    expect(c.read(cancelReasonProvider), 0);
    await tester.tap(find.text('Délai de livraison trop long'), warnIfMissed: false);
    await tester.pump();
    expect(c.read(cancelReasonProvider), 1);
    await tester.tap(find.text('Autre raison'), warnIfMissed: false);
    await tester.pump();
    expect(c.read(cancelReasonProvider), 3);
  });

  test('borne (207) : le filtre Produits / Services s’applique au catalogue réel', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final all = c.read(kioskProductsProvider).length;
    c.read(kioskKindProvider.notifier).set(1);
    expect(c.read(kioskProductsProvider).every((p) => p.category != 'Services'), isTrue);
    c.read(kioskKindProvider.notifier).set(2);
    expect(c.read(kioskProductsProvider).every((p) => p.category == 'Services'), isTrue);
    c.read(kioskKindProvider.notifier).set(0);
    expect(c.read(kioskProductsProvider).length, all);
  });
}
