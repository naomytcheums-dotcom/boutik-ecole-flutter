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

/// Mesure (et ne bloque pas) : pour chaque écran ouvert en mode connecté, serveur muet, liste les noms, références et montants de
/// maquette encore affichés. Le résultat est écrit dans build/audit_maquette.txt ; le test échoue seulement si le fichier ne peut pas être écrit.
const _interdits = [
  'Aminata Bello', 'Yannick Mouanga', 'Mouanga Yannick', 'Brice Ndoumbe', 'Kouassi Tagne', 'Rose Etoga', 'Carine Mbarga', 'Parfums Mbella',
  'Savonnerie Kamga', 'Mairie de Douala', 'Atelier Tchoupo', 'BE-2026-0142', 'BE-2026-0138', 'BE-2026-0141', 'Team Innov', 'Orange Cameroun',
  'Mme Etoga', 'Dr Paul Tchoupo', 'Pr Jean Ngassa', 'Camlight', 'Studio Kreatif', 'CV_Mariam_Essono', 'A. Kamga', 'M. Essono', 'DEV-2026-014',
  'RV-1204', 'TX-88420', 'Lampe en bois recyclé', 'Sac à dos design', 'Drone éducatif', 'Support téléphone', 'Pots connectés', 'Tableau décoratif',
  'Logo et identité visuelle', 'Sandra Tchoua', 'Éric Biyick', 'Amina T.', 'Mbella', 'Kamga', 'Tchoupo', 'Ndoumbe', 'Bello', 'Mouanga', 'Tagne',
  'Serre intelligente', 'Borne solaire', '98,6 %', '25 000 FCFA', 'Orange Digital', 'Hackathon Orange', 'Atelier Krea', '12 480 000', '845 000', '4 280', '182 Mo',
];

void main() {
  final trouves = <String, List<String>>{};
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
  tearDownAll(() {
    final b = StringBuffer();
    for (final e in trouves.entries) {
      b.writeln('${e.key}: ${e.value.join(' | ')}');
    }
    b.writeln('TOTAL ${trouves.length}');
    File('build/audit_maquette.txt').writeAsStringSync(b.toString());
  });

  for (final s in screensById.values) {
    testWidgets('audit ${s.id}', (tester) async {
      final w = gWidths[s.id] ?? 390;
      tester.view.physicalSize = w >= 1000 ? const Size(1280, 900) : (w == 720 ? const Size(720, 1280) : const Size(390, 900));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)], child: BoutikEcoleApp(initialLocation: '/s/${s.id}')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final textes = <String>[];
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        textes.add(t.data ?? t.textSpan?.toPlainText() ?? '');
      }
      final hits = <String>{};
      for (final t in textes) {
        for (final m in _interdits) {
          if (t.contains(m)) hits.add(m);
        }
      }
      if (hits.isNotEmpty) trouves[s.id] = hits.toList();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
