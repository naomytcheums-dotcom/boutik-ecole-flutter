import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Dictée vocale du navigateur (Web Speech API, français) : le texte reconnu est renvoyé au fur et à mesure ; `isFinal` vaut vrai
/// quand la phrase est terminée. Disponible dans Chrome et les navigateurs Android ; absente de certains autres (supported = false).
class Dictation {
  JSObject? _rec;

  bool get supported => globalContext.has('SpeechRecognition') || globalContext.has('webkitSpeechRecognition');

  void start({required void Function(String text, bool isFinal) onText, required void Function() onEnd, required void Function(String error) onError}) {
    if (!supported) {
      onError('unsupported');
      return;
    }
    try {
      final ctor = (globalContext.has('SpeechRecognition') ? globalContext['SpeechRecognition'] : globalContext['webkitSpeechRecognition']) as JSFunction;
      final rec = ctor.callAsConstructor<JSObject>();
      rec['lang'] = 'fr-FR'.toJS;
      rec['interimResults'] = true.toJS;
      rec['continuous'] = false.toJS;
      rec['onresult'] = ((JSObject e) {
        final results = e['results'] as JSObject;
        final len = (results['length'] as JSNumber).toDartInt;
        var text = '';
        var fin = false;
        for (var i = 0; i < len; i++) {
          final r = results.getProperty<JSObject>(i.toJS);
          final alt = r.getProperty<JSObject>(0.toJS);
          text += (alt['transcript'] as JSString).toDart;
          fin = (r['isFinal'] as JSBoolean).toDart;
        }
        onText(text.trim(), fin);
      }).toJS;
      rec['onend'] = (() => onEnd()).toJS;
      rec['onerror'] = ((JSObject e) => onError((e['error'] as JSString).toDart)).toJS;
      _rec = rec;
      rec.callMethod('start'.toJS);
    } catch (_) {
      onError('unsupported');
    }
  }

  void stop() {
    try {
      _rec?.callMethod('stop'.toJS);
    } catch (_) {}
  }
}
