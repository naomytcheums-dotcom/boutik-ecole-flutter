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

/// Audit d'accessibilité DÉTAILLÉ par écran (qualification) : pour chaque écran mobile ouvert en mode connecté à 412 × 915 et à l'échelle de police 1,0 :
/// identifiant et nom, nombre et exemples de zones tactiles de moins de 48 × 48 dp, nombre de zones tactiles sans étiquette TalkBack, nombre
/// d'éléments de contraste insuffisant (WCAG AA) et pire rapport mesuré, débordement de rendu. Résultat : build/audit_accessibilite_detail.csv.
/// Mesure seulement : ce test ne bloque pas.
void main() {
  final rows = <String>['id;nom;section;categorie;taille;echelle;zones_tactiles_trop_petites;exemples_zones;sans_etiquette_talkback;exemples_sans_etiquette;contraste_insuffisant;pire_contraste;debordement'];
  String categorie(double w) => w == 390 ? 'mobile' : w >= 1500 ? 'borne' : w >= 1200 ? 'console web' : 'tablette';
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
  tearDownAll(() => File('build/audit_accessibilite_detail_APRES.csv').writeAsStringSync('${rows.join('\n')}\n'));

  Future<String> message(WidgetTester t, dynamic m) async {
    try {
      await expectLater(t, m);
      return '';
    } on TestFailure catch (e) {
      return e.message ?? 'echec';
    } catch (e) {
      return 'erreur: $e';
    }
  }

  String clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').replaceAll(';', ',');

  for (final s in screensById.values) {
    final w = gWidths[s.id] ?? 390;
    testWidgets('a11y detail ${s.id}', (tester) async {
      final handle = tester.ensureSemantics();
      final size = w == 390 ? const Size(412, 915) : Size(w, 900);
      // Le contrôle de contraste de Flutter génère l'image à 1/ratio : un ratio de 1/3 donne 3 pixels par point (texte net comme sur téléphone).
      tester.view.physicalSize = Size(size.width / 3, size.height / 3);
      tester.view.devicePixelRatio = 1 / 3;
      addTearDown(tester.view.reset);
      var overflow = 'non';
      String tap = '', label = '', contrast = '';
      try {
        await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)], child: BoutikEcoleApp(initialLocation: '/s/${s.id}')));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 80));
        final ex = tester.takeException();
        if (ex != null) overflow = clean('$ex').substring(0, clean('$ex').length.clamp(0, 90));
        tap = await message(tester, meetsGuideline(androidTapTargetGuideline));
        label = await message(tester, meetsGuideline(labeledTapTargetGuideline));
        contrast = await message(tester, meetsGuideline(textContrastGuideline));
      } catch (e) {
        overflow = 'erreur de rendu';
      }
      final tapN = RegExp('expected tap target size').allMatches(tap).length;
      final lblN = RegExp('expected tappable node to have semantic label').allMatches(label).length;
      final conMatches = RegExp(r'Expected contrast ratio of at least ([\d.]+) but found ([\d.]+)').allMatches(contrast).toList();
      final worst = conMatches.isEmpty ? '' : conMatches.map((m) => double.tryParse(m.group(2) ?? '') ?? 99).reduce((a, b) => a < b ? a : b).toStringAsFixed(2);
      final tapEx = RegExp(r'but found Size\(([\d.]+), ([\d.]+)\)').allMatches(tap).take(3).map((m) => '${m.group(1)}x${m.group(2)}').join(' / ');
      final lblEx = RegExp(r'SemanticsNode#\d+\(Rect\.fromLTRB\(([^)]*)\)').allMatches(label).take(3).map((m) => m.group(1)).join(' / ');
      rows.add('${s.id};${clean(s.title)};${clean(s.section)};${categorie(w)};${size.width.toInt()}x${size.height.toInt()};1.0;$tapN;$tapEx;$lblN;$lblEx;${conMatches.length};$worst;$overflow');
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
