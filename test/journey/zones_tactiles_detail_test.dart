import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

/// Audit d'accessibilité DÉTAILLÉ par écran (qualification) : pour chaque écran mobile ouvert en mode connecté à 412 × 915 et à l'échelle de police 1,0 :
/// identifiant et nom, nombre et exemples de zones tactiles de moins de 48 × 48 dp, nombre de zones tactiles sans étiquette TalkBack, nombre
/// d'éléments de contraste insuffisant (WCAG AA) et pire rapport mesuré, débordement de rendu. Résultat : build/audit_accessibilite_detail.csv.
/// Mesure seulement : ce test ne bloque pas.
/// Zones tactiles de moins de 48 dp mesurées à l'échelle réelle (ratio 1) sur 412 × 915 : écran | taille | libellé. Mesure seulement ; résultat : build/petites_zones.txt.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'sb_publishable_test', authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage(), autoRefreshToken: false));
  });
  setUp(() { GAnim.enabled = false; Backend.ready = true; });
  tearDown(() => Backend.ready = false);
  final out = StringBuffer();
  tearDownAll(() => File('build/petites_zones.txt').writeAsStringSync(out.toString()));
  for (final s in screensById.values) {
    if ((gWidths[s.id] ?? 390) != 390) continue;
    testWidgets('petites zones ${s.id}', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)], child: BoutikEcoleApp(initialLocation: '/s/${s.id}')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      void walk(SemanticsNode n) {
        final d = n.getSemanticsData();
        final tappable = d.hasAction(SemanticsAction.tap) || d.hasAction(SemanticsAction.longPress);
        final r = n.rect;
        if (tappable && (r.width < 47.5 || r.height < 47.5)) out.writeln('${s.id}|${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}|${d.label}');
        n.visitChildren((c) { walk(c); return true; });
      }
      walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
