import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/messages.dart';
import 'package:boutik_ecole/figma/live/notifs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13.2 · états de lecture : une notification ou une conversation illisible n'est jamais présentée comme « aucune » ;
/// « Réessayer » relit le serveur, et la liste déjà affichée survit à une panne passagère. Faux serveur local, aucune donnée d'exemple.
Map<String, dynamic> _session() {
  final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
  String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return {
    'access_token': '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': FakeSupabase.userId, 'role': 'authenticated', 'exp': exp})}.signature',
    'token_type': 'bearer',
    'expires_in': 7200,
    'expires_at': exp,
    'refresh_token': 'refresh-test',
    'user': {'id': FakeSupabase.userId, 'aud': 'authenticated', 'role': 'authenticated', 'email': 'essai.test@example.test', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}, 'created_at': '2026-01-01T00:00:00Z'},
  };
}

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() async {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
    if (Supabase.instance.client.auth.currentUser == null) await Supabase.instance.client.auth.recoverSession(jsonEncode(_session()));
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<ProviderContainer> host(WidgetTester t, Widget body) async {
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: Stack(children: [body])))));
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    c.read(authProvider.notifier).login(demoAccount.copyWith(role: 0, serverId: FakeSupabase.userId));
    await t.pump();
    return c;
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('notifications', () {
    testWidgets('serveur muet : « Réessayer », jamais « Aucune notification » ; le réessai relit puis dit « aucune » si c\'est vrai', (t) async {
      srv.unknownIsError = true;
      await host(t, notificationsFeed());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Aucune notification pour le moment.'), findsNothing);

      srv.unknownIsError = false;
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.text('Aucune notification pour le moment.'));
      expect(find.text('Aucune notification pour le moment.'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      await fin(t);
    });

    testWidgets('panne après une lecture réussie : la liste reste affichée', (t) async {
      srv.tables['notifications'] = [
        {'id': 'n1', 'kind': 'order', 'title': 'Commande confirmée', 'body': 'Votre commande est confirmée.', 'created_at': DateTime.now().toIso8601String(), 'read_at': null, 'data': <String, dynamic>{}},
      ];
      final c = await host(t, notificationsFeed());
      await attendre(t, find.text('Commande confirmée'));
      expect(find.text('Commande confirmée'), findsOneWidget);

      srv.tables.clear();
      srv.unknownIsError = true;
      final before = srv.callsOf('notifications').length;
      unawaited(c.read(notifsProvider.notifier).refresh());
      for (var i = 0; i < 40 && srv.callsOf('notifications').length <= before; i++) {
        await settleReal(t, rounds: 2, ms: 100);
      }
      await settleReal(t, rounds: 4, ms: 100);
      expect(find.text('Commande confirmée'), findsOneWidget);
      expect(find.text('Aucune notification pour le moment.'), findsNothing);
      await fin(t);
    });
  });

  group('messagerie', () {
    testWidgets('serveur muet : « Réessayer », jamais « Aucune conversation » ; le réessai relit le serveur', (t) async {
      srv.unknownIsError = true;
      await host(t, conversationsPanel());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucune conversation pour le moment'), findsNothing);

      srv.unknownIsError = false;
      srv.rpc['my_conversations'] = (_) => [
            {'id': 'c1', 'listing_title': 'Cahier', 'other_name': 'Awa Test', 'last_body': 'Bonjour', 'last_at': DateTime.now().toIso8601String(), 'unread': 0, 'order_number': ''},
          ];
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.text('Awa Test'));
      expect(find.text('Awa Test'), findsOneWidget);
      await fin(t);
    });

    testWidgets('liste vraiment vide : le dit, sans Réessayer', (t) async {
      srv.rpc['my_conversations'] = (_) => <Object>[];
      await host(t, conversationsPanel());
      await attendre(t, find.textContaining('Aucune conversation pour le moment'));
      expect(find.textContaining('Aucune conversation pour le moment'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);
      await fin(t);
    });
  });
}
