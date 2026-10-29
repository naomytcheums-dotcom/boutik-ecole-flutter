import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/registry.dart' show gWidths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Parcours de démonstration de la soutenance, suivi avec les liens du prototype Figma :
/// chaque écran doit contenir une zone cliquable qui mène à l'écran suivant.
const path = [
  '03', '19', '22', '05', '33', '10', '40', '06', '07', '08', '257', '259', '260', '44', '09',
  '111', '213', '212', '206', '207', '208', '209', '210', '237',
];

void main() {
  GAnim.enabled = false;
  testWidgets('Parcours de démonstration de bout en bout (liens Figma)', (tester) async {
    Size sizeOf(String id) {
      final w = gWidths[id] ?? 390;
      if (w == 720) return const Size(720, 1280);
      return w >= 1000 ? const Size(1280, 900) : const Size(390, 900);
    }

    void size(Size s) {
      tester.view.physicalSize = s;
      tester.view.devicePixelRatio = 1;
    }

    addTearDown(tester.view.reset);
    size(sizeOf(path.first));
    // Le parcours passe par des écrans réservés (département, administration) : on joue avec le compte administrateur.
    await tester.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)],
      child: const BoutikEcoleApp(initialLocation: '/s/03'),
    ));
    await tester.pumpAndSettle();
    GoRouter router() => GoRouter.of(tester.element(find.byType(Scaffold).last));
    expect(router().state.uri.path, '/s/03');

    final missing = <String>[];
    for (var i = 0; i < path.length - 1; i++) {
      final from = path[i], to = path[i + 1];
      size(sizeOf(from));
      router().go('/s/$from');
      await tester.pumpAndSettle();
      var ok = false;
      final taps = find.descendant(of: find.byType(Scaffold).last, matching: find.byType(GestureDetector));
      // Les boutons principaux sont en bas de l'écran : on les essaie en premier (les poubelles, +/- ne doivent pas vider le panier).
      final order = List<int>.generate(taps.evaluate().length, (k) => k)..sort((a, b) => tester.getCenter(taps.at(b)).dy.compareTo(tester.getCenter(taps.at(a)).dy));
      for (final k in order) {
        if (ok) break;
        final g = tester.widget<GestureDetector>(taps.at(k));
        if (g.onTap == null) continue;
        await tester.tapAt(tester.getCenter(taps.at(k)));
        await tester.pumpAndSettle();
        if (router().state.uri.path == '/s/$to') {
          ok = true;
        } else {
          await tester.pump(const Duration(seconds: 3)); // laisse disparaître un éventuel message bref
          if (find.byType(AlertDialog).evaluate().isNotEmpty) {
            await tester.tapAt(const Offset(3, 3)); // ferme une boîte de dialogue ouverte par l'essai
            await tester.pumpAndSettle();
          }
          router().go('/s/$from');
          await tester.pumpAndSettle();
        }
      }
      if (!ok) missing.add('$from → $to');
    }
    expect(missing, isEmpty, reason: 'liens manquants dans le parcours : $missing');
  });
}
