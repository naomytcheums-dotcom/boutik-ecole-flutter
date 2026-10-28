import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render.dart';

/// Vérifie, pour chaque écran de [keyTexts], qu'il s'affiche sans exception et contient ses textes clés.
/// Les espaces insécables (montants FCFA) sont normalisés.
void expectScreenTexts(Map<String, List<String>> keyTexts) {
  setUpAll(loadAppFonts);

  for (final MapEntry(key: id, value: texts) in keyTexts.entries) {
    final entry = screensById[id];
    testWidgets('$id · ${entry?.title ?? '?'} : textes clés', (tester) async {
      expect(entry, isNotNull, reason: 'Écran $id non enregistré dans lib/features/screens.dart');
      await pumpScreen(tester, id, size: designSize(entry!.format));
      expect(tester.takeException(), isNull);
      for (final t in texts) {
        final finder = find.byWidgetPredicate((w) {
          final text = switch (w) {
            Text(:final data?) => data,
            RichText(:final text) => text.toPlainText(),
            _ => null,
          };
          return text != null && text.replaceAll('\u00A0', ' ').contains(t);
        });
        expect(finder, findsWidgets, reason: 'Texte « $t » absent de l’écran $id');
      }
    });
  }
}
