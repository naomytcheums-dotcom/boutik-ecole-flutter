import 'package:flutter/services.dart';

/// Hors navigateur : le fichier est copié dans le presse-papiers (pas de système de fichiers commun aux plateformes).
Future<bool> saveTextFile(String name, String content, String mime) async {
  await Clipboard.setData(ClipboardData(text: content));
  return false;
}
