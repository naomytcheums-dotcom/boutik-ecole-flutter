import 'dart:convert';

import 'package:boutik_ecole/figma/i18n.dart' show I18n;
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/session_revoked.dart';
import 'package:boutik_ecole/figma/live/system_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fake_supabase.dart' hide settleReal;
import '../helpers/fake_supabase.dart' as fs show settleReal;

Future<void> settleReal(WidgetTester t) => fs.settleReal(t, rounds: 8, ms: 40);

/// H13.1 · SESSIONS : le serveur refuse une requête dont la session est fermée (PostgREST : 401 PT401 / indice « session_revoked » ; fonctions Edge : 401 « session_revoked » ;
/// compte suspendu : 403 « account_suspended »). L'application ferme alors la session locale (événement signedOut), purge les états privés (via SystemStates -> appSessionExpired)
/// et affiche « Session expirée ou révoquée, reconnectez-vous ». Un 401/403 ordinaire (jeton expiré, politique RLS) ne déconnecte jamais.
/// Le jeton n'est pas révoqué au sens GoTrue : c'est la base qui refuse ; la déconnexion locale évite d'insister avec un jeton refusé.
void main() {
  late FakeSupabase fake;

  String sessionJson() {
    final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
    String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return jsonEncode({
      'access_token': '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': FakeSupabase.userId, 'role': 'authenticated', 'session_id': '22222222-2222-4222-8222-222222222222', 'exp': exp})}.signature',
      'token_type': 'bearer',
      'expires_in': 7200,
      'expires_at': exp,
      'refresh_token': 'refresh-test',
      'user': {'id': FakeSupabase.userId, 'aud': 'authenticated', 'role': 'authenticated', 'email': 'a@example.test', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{}, 'created_at': '2026-01-01T00:00:00Z'},
    });
  }

  GoTrueClient auth() => Supabase.instance.client.auth;
  Future<void> signIn() async {
    await auth().recoverSession(sessionJson());
    expect(auth().currentSession, isNotNull);
  }

  setUpAll(() async {
    fake = await FakeSupabase.start();
    await fake.initSupabase(sessionAware: true);
  });
  tearDownAll(() => fake.close());

  setUp(() async {
    Backend.ready = true;
    fake.rpc.clear();
    fake.functions.clear();
    fake.calls.clear();
    sessionRevokedByServer = false;
    I18n.lang = 'fr';
    if (auth().currentSession == null) await signIn();
  });
  tearDown(() => Backend.ready = false);

  test('isSessionRevokedBody : reconnaît les motifs serveur, ignore les refus ordinaires', () {
    bool f(Object body) => isSessionRevokedBody(utf8.encode(body is String ? body : jsonEncode(body)));
    expect(f({'code': 'PT401', 'message': 'Session expirée ou révoquée, reconnectez-vous', 'hint': 'session_revoked'}), isTrue);
    expect(f({'error': 'session_revoked', 'code': 'session_revoked', 'message': 'x'}), isTrue);
    expect(f({'code': '42501', 'message': 'Compte suspendu', 'hint': 'account_suspended'}), isTrue);
    expect(f({'code': 'session_not_found', 'message': 'Session from session_id claim in JWT does not exist'}), isTrue);
    expect(f({'code': 'PGRST301', 'message': 'JWT expired'}), isFalse);
    expect(f({'code': '42501', 'message': 'new row violates row-level security policy'}), isFalse);
    expect(f({'error': 'unauthorized', 'code': 'unauthorized', 'message': 'Connexion requise.'}), isFalse);
    expect(f('pas du json'), isFalse);
    expect(f(<String, Object>{}), isFalse);
    expect(isSessionRevokedBody(const []), isFalse);
  });

  test('RPC refusée en 401 PT401 « session_revoked » : session locale fermée (signedOut), message d erreur conservé', () async {
    fake.rpc['mon_action'] = (_) => throw const FakeRpcError('Session expirée ou révoquée, reconnectez-vous', status: 401, code: 'PT401', hint: 'session_revoked');
    final events = <AuthChangeEvent>[];
    final sub = auth().onAuthStateChange.listen((s) => events.add(s.event));
    final r = await Backend.rpc('mon_action', const {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await sub.cancel();
    expect(r.error, contains('Session expirée ou révoquée'));
    expect(events, contains(AuthChangeEvent.signedOut));
    expect(auth().currentSession, isNull);
    expect(sessionRevokedByServer, isTrue);
  });

  test('RPC de lecture refusée en 401 session_revoked : même déconnexion', () async {
    fake.rpc['lecture'] = (_) => throw const FakeRpcError('Session expirée ou révoquée, reconnectez-vous', status: 401, code: 'PT401', hint: 'session_revoked');
    await Backend.rpc('lecture', const {});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(auth().currentSession, isNull);
  });

  test('fonction Edge : 401 session_revoked ferme la session ; 403 account_suspended aussi', () async {
    fake.functions['pay'] = (_) => (status: 401, body: {'error': 'session_revoked', 'code': 'session_revoked', 'message': 'Session expirée ou révoquée, reconnectez-vous'});
    try {
      await Supabase.instance.client.functions.invoke('pay', body: {'order_number': 'X'});
    } on FunctionException catch (e) {
      expect(e.status, 401);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(auth().currentSession, isNull);

    await signIn();
    fake.functions['tara-pay'] = (_) => (status: 403, body: {'error': 'account_suspended', 'code': 'account_suspended', 'message': 'Compte suspendu'});
    try {
      await Supabase.instance.client.functions.invoke('tara-pay', body: {});
    } on FunctionException catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(auth().currentSession, isNull);
  });

  test('refus ordinaires : jeton expiré (401), politique de sécurité (403), erreur métier : la session reste ouverte', () async {
    fake.rpc['expire'] = (_) => throw const FakeRpcError('JWT expired', status: 401, code: 'PGRST301');
    fake.rpc['rls'] = (_) => throw const FakeRpcError('permission denied', status: 403, code: '42501');
    fake.rpc['metier'] = (_) => throw const FakeRpcError('Stock insuffisant');
    fake.functions['pay'] = (_) => (status: 401, body: {'error': 'unauthorized', 'code': 'unauthorized', 'message': 'Connexion requise.'});
    await Backend.rpc('expire', const {});
    await Backend.rpc('rls', const {});
    await Backend.rpc('metier', const {});
    try {
      await Supabase.instance.client.functions.invoke('pay', body: {});
    } on FunctionException catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(auth().currentSession, isNotNull);
    expect(sessionRevokedByServer, isFalse);
  });

  test('plusieurs refus simultanés : une seule déconnexion (pas de boucle)', () async {
    fake.rpc['a'] = (_) => throw const FakeRpcError('Session expirée ou révoquée, reconnectez-vous', status: 401, code: 'PT401', hint: 'session_revoked');
    final events = <AuthChangeEvent>[];
    final sub = auth().onAuthStateChange.listen((s) => events.add(s.event));
    await Future.wait([for (var i = 0; i < 5; i++) Backend.rpc('a', const {})]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    expect(events.where((e) => e == AuthChangeEvent.signedOut), hasLength(1));
    // plus de session : un nouveau refus ne déclenche rien
    sessionRevokedByServer = false;
    await Backend.rpc('a', const {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sessionRevokedByServer, isFalse);
  });

  testWidgets('SystemStates : session révoquée => état privé purgé (rappel d expiration) et message clair', (tester) async {
    var purged = 0;
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('accueil')))]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => SystemStates(router: router, onSessionExpired: () => purged++, child: child!),
    ));
    await tester.pump();
    fake.rpc['x'] = (_) => throw const FakeRpcError('Session expirée ou révoquée, reconnectez-vous', status: 401, code: 'PT401', hint: 'session_revoked');
    await tester.runAsync(() => Backend.rpc('x', const {}));
    await settleReal(tester);
    expect(purged, 1);
    expect(Backend.sessionWasLost, isTrue);
    expect(find.text('Session expirée ou révoquée, reconnectez-vous'), findsOneWidget);
    expect(sessionRevokedByServer, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('déconnexion demandée par l utilisateur : aucun message de session révoquée', (tester) async {
    var purged = 0;
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('accueil')))]);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => SystemStates(router: router, onSessionExpired: () => purged++, child: child!),
    ));
    await tester.pump();
    await tester.runAsync(() => Backend.signOut());
    await settleReal(tester);
    expect(purged, 0);
    expect(find.text('Session expirée ou révoquée, reconnectez-vous'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
