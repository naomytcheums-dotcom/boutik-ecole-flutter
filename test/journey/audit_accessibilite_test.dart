import 'dart:io';

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

/// Audit d'accessibilité (qualification) : mesure, sans bloquer, sur CHAQUE écran mobile ouvert en mode connecté :
///  - zones tactiles d'au moins 48 × 48 dp (androidTapTargetGuideline),
///  - zones tactiles étiquetées pour TalkBack (labeledTapTargetGuideline),
///  - contraste des textes (textContrastGuideline, WCAG AA),
///  - tenue à des polices agrandies (échelle 1,5 puis 2,0) : exception de rendu = échec,
///  - taille d'écran modeste (360 × 640) et grande (412 × 915).
/// Résultat écrit dans build/audit_accessibilite.csv ; référence : Android Core App Quality, WCAG 2.2 AA, Flutter Accessibility Guideline API.
void main() {
  final rows = <String>['ecran;taille;echelle_police;zones_tactiles_48dp;etiquettes_talkback;contraste;rendu'];
  setUpAll(() async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'sb_publishable_test', authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false));
  });
  setUp(() {
    GAnim.enabled = false;
    Backend.ready = true;
  });
  tearDown(() => Backend.ready = false);
  tearDownAll(() => File('build/audit_accessibilite.csv').writeAsStringSync('${rows.join('\n')}\n'));

  Future<String> check(WidgetTester t, Finder _, dynamic m) async {
    try {
      await expectLater(t, m);
      return 'OK';
    } on TestFailure {
      return 'ECHEC';
    } catch (_) {
      return 'ERREUR';
    }
  }

  for (final s in screensById.values) {
    final w = gWidths[s.id] ?? 390;
    if (w != 390) continue; // téléphones : les consoles web et bornes ont leurs propres tailles
    for (final (size, scale) in <(Size, double)>[(const Size(412, 915), 1.0), (const Size(360, 640), 1.0), (const Size(360, 640), 1.5), (const Size(412, 915), 2.0)]) {
      testWidgets('a11y ${s.id} ${size.width.toInt()}x${size.height.toInt()} x$scale', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String tap = '-', label = '-', contrast = '-', render = 'OK';
        try {
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: ProviderScope(overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)], child: BoutikEcoleApp(initialLocation: '/s/${s.id}')),
          ));
          await tester.pump(const Duration(milliseconds: 80));
          await tester.pump(const Duration(milliseconds: 80));
          if (tester.takeException() != null) render = 'EXCEPTION';
          if (scale == 1.0 && size.width == 412) {
            tap = await check(tester, find.byType(Scaffold), meetsGuideline(androidTapTargetGuideline));
            label = await check(tester, find.byType(Scaffold), meetsGuideline(labeledTapTargetGuideline));
            contrast = await check(tester, find.byType(Scaffold), meetsGuideline(textContrastGuideline));
          }
        } catch (_) {
          render = 'ERREUR';
        }
        rows.add('${s.id};${size.width.toInt()}x${size.height.toInt()};$scale;$tap;$label;$contrast;$render');
        handle.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
}
