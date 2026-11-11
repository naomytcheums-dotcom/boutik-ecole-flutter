import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Navigateur : type de connexion annoncé (Network Information API). Inconnu = on ne bloque rien.
Future<bool> isCellularNetwork() async {
  try {
    final nav = globalContext['navigator'] as JSObject?;
    if (nav == null || !nav.has('connection')) return false;
    final c = nav['connection'] as JSObject?;
    if (c == null) return false;
    final type = c.has('type') ? (c['type'] as JSString?)?.toDart : null;
    if (type != null) return type == 'cellular';
    // Chrome sur Android n'annonce souvent que le débit effectif et le mode « économiseur de données »
    final save = c.has('saveData') ? (c['saveData'] as JSBoolean?)?.toDart ?? false : false;
    if (save) return true;
    final eff = c.has('effectiveType') ? (c['effectiveType'] as JSString?)?.toDart : null;
    return eff == 'slow-2g' || eff == '2g';
  } catch (_) {
    return false;
  }
}
