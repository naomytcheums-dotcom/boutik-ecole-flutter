import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Navigateur : téléchargement réel du fichier (Blob + lien temporaire).
Future<bool> saveTextFile(String name, String content, String mime) async {
  final blob = web.Blob(['\uFEFF$content'.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

/// Navigateur : téléchargement réel d'un fichier distant (récupéré puis enregistré sous son nom).
Future<bool> saveRemoteFile(String url, String name) async {
  try {
    final res = await web.window.fetch(url.toJS).toDart;
    if (!res.ok) return false;
    final blob = await res.blob().toDart;
    final obj = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = obj
      ..download = name;
    web.document.body?.append(a);
    a.click();
    a.remove();
    web.URL.revokeObjectURL(obj);
    return true;
  } catch (_) {
    return false;
  }
}
