import 'dart:convert';

import 'package:boutik_ecole/data/demo/section_a_demo.dart' show CartLine;
import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/docs.dart' show orderPaymentStatus;
import 'package:boutik_ecole/figma/live/pay.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13.2 · commerce : un double appui sur « Payer » ne crée qu'une commande, une réponse perdue pendant la demande de paiement reste « vérification en cours »
/// (jamais payée, jamais annulée à l'aveugle), un refus net annule et restitue le stock, un visiteur n'a ni panier ni commande simulés. Faux serveur local.
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
    SharedPreferences.setMockInitialValues({});
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.functions.clear();
    srv.unknownIsError = false;
    srv.failWrites = false;
    if (Supabase.instance.client.auth.currentUser == null) await Supabase.instance.client.auth.recoverSession(jsonEncode(_session()));
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Future<({ProviderContainer c, BuildContext ctx, WidgetRef ref})> host(WidgetTester t, {bool login = true}) async {
    late ProviderContainer c;
    late BuildContext ctx;
    late WidgetRef wref;
    t.view.physicalSize = const Size(420, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, _) => Consumer(builder: (cx, ref, _) {
        c = ProviderScope.containerOf(cx);
        wref = ref;
        ctx = cx;
        return const Scaffold(body: Text('accueil'));
      })),
      GoRoute(path: '/s/:id', builder: (context, s) => Scaffold(body: Text('écran ${s.pathParameters['id']}'))),
    ]);
    await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await t.pump(const Duration(milliseconds: 200));
    if (login) c.read(authProvider.notifier).login(demoAccount.copyWith(role: 0, serverId: FakeSupabase.userId));
    await t.pump(const Duration(milliseconds: 100));
    c.read(cartProvider);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150))); // laisse finir le chargement du panier enregistré
    return (c: c, ctx: ctx, ref: wref);
  }

  void serveur() {
    srv.rpc['cart_check'] = (_) => {'ok': true, 'lines': <Map<String, dynamic>>[], 'shops': <Map<String, dynamic>>[]};
    srv.rpc['marketplace_checkout'] = (_) => {'number': '#BE-2026-0300', 'subtotal': 9500, 'fee': 0, 'discount': 0};
  }

  void panier(ProviderContainer c) {
    c.read(cartProvider.notifier).add(const CartLine('Robe H132', 'Boutique : A', 9500, '', qty: 1));
    c.read(payPhoneProvider.notifier).type('690112233');
  }

  group('paiement : jamais simulé, jamais en double', () {
    testWidgets('double appui sur « Payer maintenant » : une seule commande créée, une seule demande de paiement', (t) async {
      serveur();
      srv.functions['pay'] = (_) => (status: 200, body: {'reference': 'NP-1'});
      final h = await host(t);
      panier(h.c);
      await t.runAsync(() => Future.wait([startPayment(h.ref, h.ctx), startPayment(h.ref, h.ctx)]));
      await t.pump(const Duration(milliseconds: 300));
      expect(srv.callsOf('marketplace_checkout'), hasLength(1), reason: 'un seul appel de création de commande');
      expect(srv.callsOf('pay').where((x) => x.args['action'] == 'start'), hasLength(1), reason: 'une seule demande au fournisseur');
      expect(h.c.read(payProvider).phase, PayPhase.pending);
      expect(h.c.read(ordersProvider).where((o) => o.id == '#BE-2026-0300'), hasLength(1));
      expect(h.c.read(ordersProvider).first.paid, isFalse, reason: 'jamais payée avant la confirmation du serveur de paiement');
      await fin(t);
    });

    testWidgets('réponse perdue (502) à la demande de paiement : « vérification en cours », commande conservée, ni payée ni annulée ; un nouvel appui ne recrée rien', (t) async {
      serveur();
      srv.rpc['cancel_order'] = (_) => 'cancelled';
      srv.functions['pay'] = (_) => (status: 502, body: null);
      final h = await host(t);
      panier(h.c);
      await t.runAsync(() => startPayment(h.ref, h.ctx));
      await t.pump(const Duration(milliseconds: 300));
      final s = h.c.read(payProvider);
      expect(s.phase, PayPhase.pending);
      expect(s.message, contains('Vérification en cours'));
      final o = h.c.read(ordersProvider).firstWhere((x) => x.id == '#BE-2026-0300');
      expect(o.paid, isFalse);
      expect(o.cancelled, isFalse);
      expect(srv.callsOf('cancel_order'), isEmpty, reason: 'la commande n’est pas annulée à l’aveugle : le prélèvement a pu partir');
      expect(find.text('écran 257'), findsOneWidget);

      await t.runAsync(() => startPayment(h.ref, h.ctx));
      expect(srv.callsOf('marketplace_checkout'), hasLength(1), reason: 'un paiement est déjà en cours de vérification : aucune seconde commande');
      await fin(t);
    });

    testWidgets('refus net du fournisseur (400) : commande annulée, stock restitué, paiement « échoué » (jamais en attente)', (t) async {
      serveur();
      srv.rpc['cancel_order'] = (_) => 'cancelled';
      srv.functions['pay'] = (_) => (status: 400, body: {'message': 'Numéro refusé par l’opérateur.'});
      final h = await host(t);
      panier(h.c);
      await t.runAsync(() => startPayment(h.ref, h.ctx));
      await t.pump(const Duration(milliseconds: 300));
      expect(h.c.read(payProvider).phase, PayPhase.failed);
      expect(srv.callsOf('cancel_order'), hasLength(1));
      expect(h.c.read(ordersProvider).where((o) => o.id == '#BE-2026-0300'), isEmpty);
      await fin(t);
    });
  });

  group('visiteur et compte neuf : aucune commande ni panier simulés', () {
    testWidgets('visiteur non connecté : panier vide, aucune commande, « Payer » ne crée rien sur le serveur', (t) async {
      await t.runAsync(() => Supabase.instance.client.auth.signOut());
      addTearDown(() async => Supabase.instance.client.auth.recoverSession(jsonEncode(_session())));
      serveur();
      final h = await host(t, login: false);
      expect(h.c.read(cartProvider), isEmpty);
      expect(h.c.read(ordersProvider), isEmpty);
      expect(h.c.read(lastOrderProvider).id, '#----');
      h.c.read(cartProvider.notifier).add(const CartLine('Robe H132', 'Boutique : A', 9500, '', qty: 1));
      startPayment(h.ref, h.ctx);
      await t.pump(const Duration(milliseconds: 300));
      expect(srv.callsOf('marketplace_checkout'), isEmpty, reason: 'la connexion est exigée avant toute commande');
      expect(srv.callsOf('pay'), isEmpty);
      await fin(t);
    });

    testWidgets('compte neuf connecté : la lecture serveur sans commande donne « aucune commande », jamais une commande d’exemple', (t) async {
      srv.tables['orders'] = [];
      final h = await host(t);
      await t.runAsync(() => h.c.read(ordersProvider.notifier).refresh());
      expect(h.c.read(ordersProvider), isEmpty);
      expect(h.c.read(ordersLoadedProvider), isTrue);
      expect(h.c.read(lastOrderProvider).id, '#----');
      await fin(t);
    });
  });

  test('document : une commande payée puis annulée n’affiche pas simplement « Payé »', () {
    const o = Order(id: '#BE-2026-0400', date: '27 nov. 2026', lines: [], subtotal: 9500, fee: 0, method: 'Mobile Money', reference: '', paid: true, cancelled: true);
    expect(orderPaymentStatus(o), 'Payée, commande annulée');
    expect(orderPaymentStatus(o.copyWith(cancelled: false)), 'Payé');
  });
}
