import 'dart:convert';
import 'dart:io';

import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Appel reçu par le faux serveur : `rpc/<fn>` ou lecture d'une table.
class FakeCall {
  FakeCall(this.kind, this.name, this.args, [this.query = const {}]);
  final String kind; // 'rpc' | 'table' | 'write'
  final String name;
  final Map<String, dynamic> args;
  final Map<String, String> query;
  @override
  String toString() => '$kind:$name $args';
}

/// Faux serveur Supabase (REST + session) pour les tests de fonctions : le vrai client `Supabase.instance.client` est utilisé, ses requêtes
/// arrivent sur un `HttpServer` local. Une fonction non déclarée répond « liste vide » (état vide honnête) ; `fail` simule un refus.
class FakeSupabase {
  FakeSupabase._(this._server);
  final HttpServer _server;

  /// Réponses des fonctions : valeur JSON, ou fonction des paramètres. Lever [FakeRpcError] pour un refus (garde, 2FA…).
  final Map<String, Object? Function(Map<String, dynamic> args)> rpc = {};

  /// Lignes servies pour une table (lecture) ; absent : liste vide.
  final Map<String, List<Map<String, dynamic>>> tables = {};

  /// Lignes renvoyées après une écriture (PATCH/POST avec `select`) : absent, le serveur confirme zéro ligne modifiée (refus par la politique de sécurité).
  final Map<String, List<Map<String, dynamic>>> writeResult = {};
  final List<FakeCall> calls = [];

  /// Vrai : toute fonction ou table non déclarée répond 404 (serveur muet : aucune donnée) au lieu d'une liste vide.
  bool unknownIsError = false;

  /// Panne serveur (HTTP 500) : sur toute écriture de table si [failWrites], et sur les fonctions listées dans [failRpc].
  bool failWrites = false;
  final Set<String> failRpc = {};

  static const userId = '11111111-1111-4111-8111-111111111111';

  static Future<FakeSupabase> start() async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final f = FakeSupabase._(s);
    s.listen(f._handle);
    return f;
  }

  Future<void> close() => _server.close(force: true);

  String get url => 'http://127.0.0.1:${_server.port}';

  List<FakeCall> callsOf(String fn) => [for (final c in calls) if (c.name == fn) c];

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers.contentType = ContentType.json;
    try {
      final body = await utf8.decoder.bind(req).join();
      final path = req.uri.path;
      if (path.startsWith('/rest/v1/rpc/')) {
        final fn = path.substring('/rest/v1/rpc/'.length);
        final decoded = body.isEmpty ? null : jsonDecode(body);
        final args = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
        calls.add(FakeCall('rpc', fn, args));
        final h = rpc[fn];
        if (failRpc.contains(fn)) {
          res.statusCode = 500;
          res.write(jsonEncode({'message': 'panne simulée'}));
        } else if (h == null) {
          if (unknownIsError) {
            res.statusCode = 404;
            res.write(jsonEncode({'code': 'PGRST202', 'message': 'Could not find the function public.$fn'}));
          } else {
            res.write('[]');
          }
        } else {
          try {
            res.write(jsonEncode(h(args)));
          } on FakeRpcError catch (e) {
            res.statusCode = e.status;
            res.write(jsonEncode({'code': e.code, 'message': e.message}));
          }
        }
      } else if (path.startsWith('/rest/v1/')) {
        final table = path.substring('/rest/v1/'.length);
        final write = req.method != 'GET' && req.method != 'HEAD';
        calls.add(FakeCall(write ? 'write' : 'table', table, body.isEmpty ? {} : (jsonDecode(body) is Map ? Map<String, dynamic>.from(jsonDecode(body) as Map) : {}), req.uri.queryParameters));
        if (write && failWrites) {
          res.statusCode = 500;
          res.write(jsonEncode({'message': 'panne simulée'}));
        } else if (!write && unknownIsError && !tables.containsKey(table)) {
          res.statusCode = 404;
          res.write(jsonEncode({'code': 'PGRST205', 'message': 'Could not find the table public.$table'}));
        } else {
          res.write(write ? jsonEncode(writeResult[table] ?? const []) : jsonEncode(tables[table] ?? const []));
        }
      } else {
        res.statusCode = 404;
        res.write('{}');
      }
    } catch (_) {
      res.statusCode = 500;
      res.write('{"message":"fake server"}');
    }
    await res.close();
  }

  /// Initialise le vrai client sur ce faux serveur, avec une session déjà ouverte (aucun appel d'authentification).
  Future<void> initSupabase() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
    String b64(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final jwt = '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64({'sub': userId, 'role': 'authenticated', 'exp': exp})}.signature';
    final session = jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'expires_in': 7200,
      'expires_at': exp,
      'refresh_token': 'refresh-test',
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'admin.test@example.test',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00Z',
      },
    });
    await Supabase.initialize(
      url: url,
      publishableKey: 'sb_publishable_test',
      authOptions: FlutterAuthClientOptions(localStorage: _SessionStorage(session), autoRefreshToken: false),
    );
    Backend.ready = true;
  }
}

class FakeRpcError implements Exception {
  const FakeRpcError(this.message, {this.status = 400, this.code = 'P0001'});
  final String message;
  final int status;
  final String code;
}

class _SessionStorage extends LocalStorage {
  _SessionStorage(this._s);
  String? _s;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => _s != null;
  @override
  Future<String?> accessToken() async => _s;
  @override
  Future<void> removePersistedSession() async => _s = null;
  @override
  Future<void> persistSession(String persistSessionString) async => _s = persistSessionString;
}

/// Laisse le temps réel s'écouler (entrées/sorties réelles du faux serveur) puis rejoue les minuteries du test.
@visibleForTesting
Future<void> settleReal(WidgetTester tester, {int rounds = 6, int ms = 40}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}
