@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Rendus de référence de chaque écran, à la taille exacte de la maquette (docs/screens.json).
/// Régénérer : `flutter test --update-goldens --tags golden`.
/// Comparer à Figma : `python tool/compare_figma.py <captures>` (côte à côte dans build/compare).
void main() {
  setUpAll(loadAppFonts);

  final heights = <String, int>{
    for (final e in jsonDecode(File('docs/screens.json').readAsStringSync()) as List)
      if (e['h'] != null) e['id'] as String: e['h'] as int,
  };

  for (final s in screensById.values) {
    testWidgets('golden ${s.id} · ${s.title}', (tester) async {
      final base = designSize(s.format);
      final size = Size(base.width, (heights[s.id] ?? base.height).toDouble());
      await pumpScreen(tester, s.id, size: size);
      await expectLater(find.byType(Overlay).first, matchesGoldenFile('goldens/${s.id}.png'));
    });
  }
}
