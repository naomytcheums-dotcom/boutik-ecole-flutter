import 'package:boutik_ecole/figma/g/g_10.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// L'auteur retrouve sur son profil ses publications qui attendent une validation.
void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());
  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
  });
  tearDown(() => GScreen.mockupFrame = true);

  testWidgets('profil : « 2 publications en attente de validation »', (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    srv.rpc['my_posts_status'] = (_) => [
          {'id': 'a', 'status': 'pending', 'text': 'Un', 'media_kind': 'image'},
          {'id': 'b', 'status': 'pending', 'text': 'Deux', 'media_kind': 'video'},
        ];
    await t.pumpWidget(ProviderScope(
      overrides: [initialAccountProvider.overrideWithValue(Account(name: 'Nina Test', phone: '690000001', email: 'nina@example.com', password: '', serverId: FakeSupabase.userId))],
      child: const MaterialApp(home: G_10()),
    ));
    await settleReal(t, rounds: 5, ms: 30);
    expect(find.text('2 publications en attente de validation'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  });
}
