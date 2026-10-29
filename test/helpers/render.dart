import 'package:boutik_ecole/figma/live/store.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/screen_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

bool _fontsLoaded = false;

/// Charge Plus Jakarta Sans et Inter pour que les rendus de test ressemblent à l'app.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  for (final family in ['PlusJakartaSans', 'Inter']) {
    final loader = FontLoader(family);
    for (final w in [400, 500, 600, 700, 800]) {
      final bytes = File('assets/fonts/$family-$w.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
  _fontsLoaded = true;
}

/// Taille logique de la maquette selon le format.
Size designSize(ScreenFormat f) => switch (f) {
  ScreenFormat.mobile => const Size(390, 900),
  ScreenFormat.tablet => const Size(768, 1024),
  ScreenFormat.web => const Size(1280, 900),
  ScreenFormat.kiosk => const Size(720, 1280),
};

/// Monte l'application directement sur l'écran `id`.
Future<void> pumpScreen(WidgetTester tester, String id, {Size size = const Size(390, 900)}) async {
  GAnim.enabled = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Les rendus de référence sont pris avec le compte administrateur (tous les écrans sont accessibles).
  await tester.pumpWidget(ProviderScope(
    overrides: [
      initialAccountProvider.overrideWithValue(seedAccounts.last),
      nowProvider.overrideWithValue(DateTime(2026, 10, 27, 10, 42)),
    ],
    child: BoutikEcoleApp(initialLocation: '/s/$id'),
  ));
  await tester.pumpAndSettle();
  await precacheVisibleImages(tester);
}

/// Les images d'assets se décodent hors de la boucle de test : on les précharge pour les goldens.
Future<void> precacheVisibleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      await precacheImage((el.widget as Image).image, el);
    }
    for (final el in find.byType(DecoratedBox).evaluate()) {
      final deco = (el.widget as DecoratedBox).decoration;
      if (deco is BoxDecoration && deco.image != null) await precacheImage(deco.image!.image, el);
    }
    for (final el in find.byType(Container).evaluate()) {
      final deco = (el.widget as Container).decoration;
      if (deco is BoxDecoration && deco.image != null) await precacheImage(deco.image!.image, el);
    }
  });
  await tester.pumpAndSettle();
}
