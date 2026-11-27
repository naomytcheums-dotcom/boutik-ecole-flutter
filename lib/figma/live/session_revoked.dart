import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session fermée ou compte suspendu côté serveur (lot SESSIONS H13.1).
/// La base refuse toute requête dont la session n'existe plus (PostgREST : HTTP 401, code PT401, indice « session_revoked » ; fonctions Edge : 401 « session_revoked ») ou dont le
/// compte est suspendu (403, « account_suspended »). Le jeton, lui, reste valable pour GoTrue jusqu'à son expiration : c'est l'application qui doit se déconnecter proprement.

/// Vrai si le corps d'une réponse 401/403 signale une session révoquée, un compte suspendu ou un compte bloqué.
bool isSessionRevokedBody(List<int> body) {
  if (body.isEmpty || body.length > 4096) return false;
  try {
    final d = jsonDecode(utf8.decode(body, allowMalformed: true));
    if (d is! Map) return false;
    const codes = {'session_revoked', 'account_suspended', 'session_not_found', 'user_banned'};
    return [d['hint'], d['error'], d['code'], d['error_code']].any((v) => v is String && codes.contains(v));
  } catch (_) {
    return false;
  }
}

/// Vrai pendant que l'écran de reconnexion doit expliquer que la session a été fermée par le serveur (et non simplement expirée).
bool sessionRevokedByServer = false;

bool _revoking = false;

/// Déconnexion locale propre : la session est supprimée de l'appareil (événement signedOut, traité comme une expiration : états privés purgés,
/// brouillons effacés, écran de reconnexion). Sans effet s'il n'y a pas de session ouverte ou si la déconnexion est déjà en cours.
Future<void> onServerSessionRevoked(SupabaseClient? client) async {
  if (_revoking || client == null || client.auth.currentSession == null) return;
  _revoking = true;
  sessionRevokedByServer = true;
  try {
    await client.auth.signOut(scope: SignOutScope.local);
  } catch (_) {
    // la session locale est supprimée même si la requête de déconnexion échoue
  } finally {
    _revoking = false;
  }
}

/// Client HTTP des appels Supabase (à passer à `Supabase.initialize(httpClient: …)`) : une session révoquée ferme la session locale.
http.Client sessionAwareHttpClient() => RevokedSessionClient(http.Client(), () {
      try {
        unawaited(onServerSessionRevoked(Supabase.instance.client));
      } catch (_) {
        // client non initialisé : rien à fermer
      }
    });

/// Client HTTP des appels Supabase : observe les réponses 401/403 et signale une session révoquée. Le corps est relu puis restitué intact.
class RevokedSessionClient extends http.BaseClient {
  RevokedSessionClient(this._inner, this.onRevoked);
  final http.Client _inner;
  final void Function() onRevoked;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _inner.send(request);
    if (res.statusCode != 401 && res.statusCode != 403) return res;
    final bytes = await res.stream.toBytes();
    if (isSessionRevokedBody(bytes)) scheduleMicrotask(onRevoked);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      res.statusCode,
      contentLength: bytes.length,
      request: res.request,
      headers: res.headers,
      isRedirect: res.isRedirect,
      persistentConnection: res.persistentConnection,
      reasonPhrase: res.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
