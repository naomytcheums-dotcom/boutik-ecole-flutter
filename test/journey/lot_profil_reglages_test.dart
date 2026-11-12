import 'package:boutik_ecole/figma/g/g_184.dart';
import 'package:boutik_ecole/figma/g/g_186.dart';
import 'package:boutik_ecole/figma/g/g_211.dart';
import 'package:boutik_ecole/figma/g/g_227.dart';
import 'package:boutik_ecole/figma/g/g_229.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/device_prefs.dart';
import 'package:boutik_ecole/figma/live/profile_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/render.dart';

class _Docs extends DocsNotifier {
  @override
  List<UserDoc>? build() => const [];
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    GScreen.mockupFrame = false;
    SharedPreferences.setMockInitialValues({});
  });
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

  testWidgets('184 : un interrupteur change et est mémorisé sur l’appareil', (t) async {
    final c = await monter(t, const G_184(), connecte: false);
    expect(c.read(dataPrefsProvider)['wifi_sync'], true, reason: 'par défaut : Wi-Fi uniquement');
    expect(c.read(dataPrefsProvider)['sync_never'], false);
    await c.read(dataPrefsProvider.notifier).set('sync_never', true);
    await t.pumpAndSettle();
    expect(c.read(dataPrefsProvider)['sync_never'], true);
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('dev_sync_never'), true, reason: 'choix « Jamais » mémorisé sur l’appareil');
  });

  testWidgets('184 connecté : plus de consommation inventée', (t) async {
    await monter(t, const G_184(), connecte: true);
    expect(find.text('182 Mo'), findsNothing);
    expect(find.textContaining('pas mesurée'), findsOneWidget);
  });

  testWidgets('184 hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_184(), connecte: false);
    expect(find.text('182 Mo'), findsOneWidget);
  });

  testWidgets('186 : réglage d’accessibilité mémorisé', (t) async {
    final c = await monter(t, const G_186(), connecte: false);
    await c.read(accessPrefsProvider.notifier).set('reduce_motion', true);
    expect(c.read(accessPrefsProvider)['reduce_motion'], true);
  });

  testWidgets('227 connecté : profil réel, aucun CV de maquette', (t) async {
    await monter(t, const G_227(), connecte: true, overrides: [myDocsProvider.overrideWith(_Docs.new)]);
    expect(find.text('Compétences'), findsOneWidget);
    expect(find.textContaining('Aucun CV envoyé'), findsOneWidget);
  });

  testWidgets('229 connecté : profil réel', (t) async {
    await monter(t, const G_229(), connecte: true, overrides: [myDocsProvider.overrideWith(_Docs.new)]);
    expect(find.text('CV envoyé'), findsOneWidget);
    expect(find.text('Score 88 · Disponible · IUT de Douala'), findsNothing);
  });

  testWidgets('211 connecté : produit choisi', (t) async {
    await monter(t, const G_211(), connecte: true);
    expect(find.textContaining('Vendeur :'), findsOneWidget);
  });

  testWidgets('227 et 229 hors connexion : la démonstration reste affichée', (t) async {
    await monter(t, const G_229(), connecte: false);
    expect(find.text('Score 88 · Disponible · IUT de Douala'), findsWidgets);
  });
}
