import 'package:boutik_ecole/figma/g/g_101.dart';
import 'package:boutik_ecole/figma/g/g_156.dart';
import 'package:boutik_ecole/figma/g/g_236.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/engage.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Engagements réversibles (inscription, candidature, suivi…) et préférences enregistrées (156, 236).
void main() {
  setUpAll(loadAppFonts);
  setUp(() => Backend.ready = false);

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen, {List overrides = const []}) async {
    GAnim.enabled = false;
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: overrides.cast());
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: Scaffold(body: screen))));
    await tester.pumpAndSettle();
    return c;
  }

  test('hors connexion : aucun engagement lu ni inventé', () async {
    expect(await Backend.myEngagements(), isEmpty);
    expect(await Backend.myEngagement('event_registration', 'event:101'), isNull);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(engagementProvider('event_registration|event:101').future), isNull);
  });

  test('date d’enregistrement lisible', () {
    expect(engagementDate('2026-10-30T09:15:00Z').length, 10);
    expect(engagementDate(null), '');
    expect(engagementDate('pas une date'), '');
  });

  test('prix et vendeur du produit consulté (écran 39)', () {
    expect(productPriceAndSeller(liveCatalog.first), '25 000 FCFA · Yannick M.');
  });

  testWidgets('événement 101 : le bouton reflète l’inscription enregistrée sur le serveur', (tester) async {
    await pump(tester, const G_101());
    expect(find.text('S’inscrire'), findsOneWidget);
    expect(find.textContaining('Gérer mon inscription'), findsNothing);

    await pump(tester, const G_101(), overrides: [
      engagementProvider.overrideWith((ref, key) async => key == 'event_registration|event:101' ? {'status': 'active', 'created_at': '2026-10-30T09:15:00Z'} : null),
    ]);
    expect(find.textContaining('Gérer mon inscription'), findsOneWidget);
    expect(find.text('S’inscrire'), findsNothing);
  });

  testWidgets('événement 101 : une inscription annulée n’apparaît plus comme active', (tester) async {
    await pump(tester, const G_101(), overrides: [
      engagementProvider.overrideWith((ref, key) async => {'status': 'cancelled'}),
    ]);
    expect(find.text('S’inscrire'), findsOneWidget);
  });

  testWidgets('préférences d’alertes 156 : les interrupteurs alimentent l’état enregistré', (tester) async {
    final c = await pump(tester, const G_156());
    expect(c.read(alertPrefsProvider), alertPrefsDefaults);
    await tester.tap(find.byType(GToggle).at(1)); // SMS
    await tester.pump();
    expect(c.read(alertPrefsProvider)['sms'], isFalse);
    await tester.tap(find.byType(GToggle).at(2)); // WhatsApp (éteint dans la maquette)
    await tester.pump();
    expect(c.read(alertPrefsProvider)['whatsapp'], isTrue);
  });

  testWidgets('canaux 236 : chaque canal s’active ou se désactive, l’enregistrement hors connexion ne simule rien', (tester) async {
    final c = await pump(tester, const G_236());
    expect(find.text('Activé'), findsNWidgets(3));
    expect(find.text('Désactivé'), findsOneWidget);
    await tester.tap(find.text('Désactivé'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(c.read(channelPrefsProvider)['email'], isTrue);
    expect(find.text('Activé'), findsNWidgets(4));
    await tester.tap(find.text('Activé').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(c.read(channelPrefsProvider)['whatsapp'], isFalse);
    await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Hors connexion'), findsOneWidget);
    expect(find.text('Préférences enregistrées.'), findsNothing);
  });
}
