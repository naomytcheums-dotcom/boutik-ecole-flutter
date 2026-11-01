import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

/// Chacun des 315 écrans s'ouvre en MODE CONNECTÉ (comme en production, serveur sans réponse) sans aucune erreur :
/// ni exception, ni débordement, ni écran manquant. Complète les golden images, prises en mode maquette.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    // client réel pointé vers une adresse inaccessible : toutes les lectures échouent proprement, comme un serveur muet
    await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'sb_publishable_test',
        authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false));
  });
  setUp(() {
    GAnim.enabled = false;
    Backend.ready = true;
  });
  tearDown(() => Backend.ready = false);

  for (final s in screensById.values) {
    testWidgets('écran ${s.id} · ${s.title} : ouverture en mode connecté sans erreur', (tester) async {
      final w = gWidths[s.id] ?? 390;
      tester.view.physicalSize = w >= 1000 ? const Size(1280, 900) : (w == 720 ? const Size(720, 1280) : const Size(390, 900));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)],
        child: BoutikEcoleApp(initialLocation: '/s/${s.id}'),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.text('Écran introuvable'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
