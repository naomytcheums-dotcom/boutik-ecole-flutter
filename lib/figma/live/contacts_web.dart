import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Sélecteur de contacts du téléphone (Contact Picker API : Chrome sur Android). Renvoie les numéros choisis, ou null si indisponible.
bool get contactPickerSupported {
  try {
    final nav = globalContext['navigator'] as JSObject?;
    return nav != null && nav.has('contacts');
  } catch (_) {
    return false;
  }
}

/// Contacts choisis : liste vide si l'utilisateur a fermé le sélecteur sans choisir ; null si le sélecteur a échoué ou n'est pas pris en charge.
Future<List<String>?> pickContactNumbers() async {
  try {
    final nav = globalContext['navigator'] as JSObject;
    final contacts = nav['contacts'] as JSObject;
    final opts = JSObject();
    opts['multiple'] = true.toJS;
    final res = await (contacts.callMethod('select'.toJS, ['tel'.toJS].toJS, opts) as JSPromise<JSAny?>).toDart;
    final arr = (res as JSArray<JSAny?>).toDart;
    final out = <String>[];
    for (final c in arr) {
      final tel = (c as JSObject)['tel'];
      if (tel == null) continue;
      for (final t in (tel as JSArray<JSAny?>).toDart) {
        final n = (t as JSString).toDart.replaceAll(RegExp(r'[^0-9+]'), '');
        if (n.isNotEmpty) out.add(n);
      }
    }
    if (arr.isNotEmpty && out.isEmpty) return null;
    return out;
  } catch (e) {
    return '$e'.contains('AbortError') ? <String>[] : null;
  }
}
