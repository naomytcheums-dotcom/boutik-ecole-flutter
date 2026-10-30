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
