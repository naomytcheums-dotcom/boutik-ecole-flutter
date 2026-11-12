import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hors navigateur : le fichier est copié dans le presse-papiers (pas de système de fichiers commun aux plateformes).
Future<bool> saveTextFile(String name, String content, String mime) async {
  await Clipboard.setData(ClipboardData(text: content));
  return false;
}

/// Hors navigateur : le fichier s'ouvre dans l'application du système (enregistrement depuis le lecteur).
Future<bool> saveRemoteFile(String url, String name) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
