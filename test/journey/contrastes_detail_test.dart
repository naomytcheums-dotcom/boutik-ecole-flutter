import 'dart:io';

import 'package:boutik_ecole/app.dart';
import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/render.dart';

/// Extraction ciblée (correction des contrastes) : message complet du contrôle de contraste pour les écrans signalés.
const _ids = ['255','250b','04','06','10','11','18','22','22b','22c','146-1','149','150-4','151','154','155','156','158','160','162','163','179','182','186','45','50','58','59','61','62','63','66','67','69','70','73','75','78','84','100','102','103','105','106','32','33','39','91','93','99','243','244','247','248','250','251','254','218','224','226','191','196','201','204','205','231','A2','P5'];
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
  tearDownAll(() => File('build/contrastes_detail_APRES.txt').writeAsStringSync(out.toString()));
  for (final id in _ids) {
    testWidgets('contraste $id', (tester) async {
      final handle = tester.ensureSemantics();
      // Le contrôle de Flutter génère l'image à 1/ratio : un ratio de 1/3 donne 3 pixels par point (texte net comme sur téléphone).
      tester.view.physicalSize = const Size(412 / 3, 915 / 3);
      tester.view.devicePixelRatio = 1 / 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(seedAccounts.last)], child: BoutikEcoleApp(initialLocation: '/s/$id')));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 80));
      tester.takeException();
      try {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } on TestFailure catch (e) {
        out.writeln('=== $id ===');
        out.writeln(e.message);
      }
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
