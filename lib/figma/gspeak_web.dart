import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Lecture vocale du navigateur (synthèse vocale en français).
void webSpeak(String text) {
  try {
    if (!globalContext.has('speechSynthesis') || !globalContext.has('SpeechSynthesisUtterance')) return;
    final synth = globalContext['speechSynthesis'] as JSObject;
    final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
    final u = ctor.callAsConstructor<JSObject>(text.toJS);
    u['lang'] = 'fr-FR'.toJS;
    synth.callMethod('cancel'.toJS);
    synth.callMethod('speak'.toJS, u);
  } catch (_) {}
}
