@Tags(['a11y'])
library;

import 'dart:io';

import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Audit d'accessibilité de chaque écran : zones tactiles de 44 px, zones tactiles étiquetées,
/// contraste du texte ≥ 4,5:1 (3:1 pour les grands textes).
/// Rapport : build/a11y_report.txt. Lancer : `flutter test --tags a11y`.
void main() {
  setUpAll(loadAppFonts);
  final report = StringBuffer();
  tearDownAll(() {
    Directory('build').createSync(recursive: true);
    File('build/a11y_report.txt').writeAsStringSync(report.toString());
  });

  final guidelines = {
    'cible44': iOSTapTargetGuideline,
    'etiquette': labeledTapTargetGuideline,
    'contraste': textContrastGuideline,
  };

  for (final s in screensById.values) {
    testWidgets('a11y ${s.id}', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, s.id, size: designSize(s.format));
      for (final g in guidelines.entries) {
        final result = await g.value.evaluate(tester);
        if (!result.passed) report.writeln('## ${s.id} ${g.key}\n${result.reason}\n');
      }
      handle.dispose();
    });
  }
}
