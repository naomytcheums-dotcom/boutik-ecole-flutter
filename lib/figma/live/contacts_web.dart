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

Future<List<String>?> pickContactNumbers() async {
  try {
    final nav = globalContext['navigator'] as JSObject;
    final contacts = nav['contacts'] as JSObject;
    final opts = JSObject();
    opts['multiple'] = true.toJS;
    final res = await (contacts.callMethod('select'.toJS, ['tel'.toJS].toJS, opts) as JSPromise<JSAny?>).toDart;
    final out = <String>[];
    final arr = res as JSArray<JSAny?>;
    for (final c in arr.toDart) {
      final tel = (c as JSObject)['tel'];
      if (tel == null) continue;
      for (final t in (tel as JSArray<JSAny?>).toDart) {
        final n = (t as JSString).toDart.replaceAll(RegExp(r'[^0-9+]'), '');
        if (n.isNotEmpty) out.add(n);
      }
    }
    return out;
  } catch (_) {
    return null;
  }
}
