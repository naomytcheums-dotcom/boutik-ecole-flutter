import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/home_hero.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Appuie réellement sur chaque zone de navigation de chaque écran (au centre de la zone, à la taille de la maquette,
/// compte administrateur) et vérifie l'écran ouvert. Rapport : build/interactions_navigation.csv.
void main() {
  final sizes = <String, (double, double)>{
    for (final e in jsonDecode(File('docs/screens.json').readAsStringSync()) as List)
      e['id'] as String: ((e['w'] as num).toDouble(), (e['h'] as num).toDouble()),
  };
  final nav = RegExp(r"g(?:Open|Tab)\(context, '([^']+)'\)");
  final num4 = RegExp(r'^\s*(?:gTap|gP)\(\s*([-\d.]+),\s*([-\d.]+),\s*([\d.]+),\s*([\d.]+)');
  final simpleTap = RegExp(r"^\s*gTap\([^,]+,[^,]+,[^,]+,[^,]+,\s*\(\)\s*(?:=>\s*g(?:Open|Tab)\(context, '[^']+'\)\)|\{\s*g(?:Open|Tab)\(context, '[^']+'\);\s*\}\))");
  final simpleP = RegExp(r"tap: \(\) => g(?:Open|Tab)\(context, '[^']+'\)\),?\s*$");

  // Écarts expliqués : 03 (plusieurs zones sur une ligne : l'analyse prend la 1re position et la dernière cible),
  // 08 (« Payer » ouvre d'abord « Paiement en attente » 257, comportement réel), 117 (icône incluse dans une rangée plus large
  // qui ouvre la bonne rubrique).
  const expliques = {'03>78', '08>09', '117>10', '117>53'};
  final rows = <String>['ecran;x;y;cible;resultat;ecran_ouvert'];
  var ok = 0, ko = 0;

  setUpAll(loadAppFonts);
  tearDownAll(() {
    File('build/interactions_navigation.csv')
      ..createSync(recursive: true)
      ..writeAsStringSync('${rows.join('\n')}\n');
    // ignore: avoid_print
    print('INTERACTIONS NAVIGATION : $ok conformes, $ko non conformes, total ${ok + ko}');
  });

  for (final s in screensById.values) {
    // 271, 280, P3, P5 : remplacés par le hub d'intégrations (test/integrations), plus d'éléments à coordonnées fixes.
    if (const {'271', '280', 'P3', 'P5'}.contains(s.id)) continue;
    final file = File('lib/figma/g/g_${s.id.replaceAll('-', '_')}.dart');
    if (!file.existsSync()) continue;
    final taps = <(double, double, String)>[];
    for (final l in file.readAsLinesSync()) {
      // zones dont l'action est uniquement une navigation (gTap simple, ou gP terminé par tap: () => gOpen/gTab)
      final m = num4.firstMatch(l);
      if (m == null || !(simpleTap.hasMatch(l) || (l.trimLeft().startsWith('gP(') && simpleP.hasMatch(l)))) continue;
      final t = nav.allMatches(l).last.group(1)!;
      taps.add((double.parse(m.group(1)!) + double.parse(m.group(3)!) / 2, double.parse(m.group(2)!) + double.parse(m.group(4)!) / 2, t));
    }
    if (taps.isEmpty) continue;
    testWidgets('interactions ${s.id} (${taps.length})', (tester) async {
      GAnim.enabled = false;
      final (w, h) = sizes[s.id] ?? (390.0, 900.0);
      tester.view.physicalSize = Size(w, h.ceilToDouble());
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          initialAccountProvider.overrideWithValue(seedAccounts.last),
          nowProvider.overrideWithValue(DateTime(2026, 10, 27, 10, 42)),
        ],
        child: BoutikEcoleApp(initialLocation: '/s/${s.id}'),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      final router = GoRouter.of(tester.element(find.byType(Overlay).first));
      for (final (x, y, t) in taps) {
        HomeHero.index.value = 0;
        router.go('/s/${s.id}');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tapAt(Offset(x, y + (h.ceilToDouble() - h) / 2), kind: PointerDeviceKind.touch);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        final got = router.state.uri.path;
        String norm(String p) => p.replaceAll('_', '-').toLowerCase();
        final good = norm(got) == norm('/s/$t');
        good ? ok++ : ko++;
        if (!good) expect(expliques, contains('${s.id}>$t'), reason: '${s.id} : la zone ($x, $y) devait ouvrir $t, a ouvert $got');
        rows.add('${s.id};${x.toStringAsFixed(0)};${y.toStringAsFixed(0)};$t;${good ? 'OK' : 'ECART'};$got');
        // referme une éventuelle boîte de dialogue ouverte par erreur
        if (find.byType(Dialog).evaluate().isNotEmpty || find.byType(BottomSheet).evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(2, 2));
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
