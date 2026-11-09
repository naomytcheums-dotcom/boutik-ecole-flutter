import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

/// Polices agrandies (150 % sur 360 × 640, 200 % sur 412 × 915) : aucun débordement ni exception de rendu, sans désactiver la mise à l'échelle du texte.
/// Écrans signalés par l'audit ; diagnostic écrit dans build/polices_agrandies.txt.
const _ids = ['261', '148-1', '149', '173', '100', '225', '226'];

void main() {
  final out = StringBuffer();
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
  tearDownAll(() => File('build/polices_agrandies.txt').writeAsStringSync(out.toString()));
  for (final id in _ids) {
    for (final (size, scale) in <(Size, double)>[(const Size(360, 640), 1.5), (const Size(412, 915), 2.0)]) {
      testWidgets('police x$scale $id', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final prev = FlutterError.onError;
        final msgs = <String>[];
        FlutterError.onError = (d) => msgs.add(d.toDiagnosticsNode().toStringDeep());
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ProviderScope(overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)], child: BoutikEcoleApp(initialLocation: '/s/$id')),
        ));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 80));
        tester.takeException();
        FlutterError.onError = prev;
        out.writeln('=== $id ${size.width.toInt()}x${size.height.toInt()} x$scale : ${msgs.isEmpty ? 'OK' : 'EXCEPTION (${msgs.length})'}');
        for (final m in msgs.take(3)) {
          final ls = m.split('\n');
          final k = ls.indexWhere((l) => l.contains('relevant'));
          out.writeln(ls.first);
          if (k >= 0) out.writeln(ls.sublist(k, (k + 3).clamp(0, ls.length)).join('\n'));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
}
