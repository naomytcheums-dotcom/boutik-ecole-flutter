import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';

import 'gspeak_stub.dart' if (dart.library.js_interop) 'gspeak_web.dart';

/// Réglages d'accessibilité réellement appliqués : lecture vocale des messages et contraste renforcé des textes.
class GAccess {
  static bool voice = false;
  static bool motionReduced = false;

  /// Lit un message à voix haute (messages et alertes) quand la lecture vocale est activée.
  static void speak(String text) {
    if (!voice || text.trim().isEmpty) return;
    if (kIsWeb) webSpeak(text);
  }

  /// Contraste renforcé : les gris moyens des textes deviennent le noir de l'interface.
  static Color contrast(Color c) {
    final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
    final mx = [r, g, b].reduce((a, b) => a > b ? a : b), mn = [r, g, b].reduce((a, b) => a < b ? a : b);
    final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    if (c.a > 0.5 && mx - mn < 40 && lum > 0.12 && lum < 0.55) return const Color(0xFF111015);
    return c;
  }
}
