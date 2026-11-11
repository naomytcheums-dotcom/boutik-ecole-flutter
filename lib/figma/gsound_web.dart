import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Son du navigateur via Web Audio : le contexte est débloqué au premier toucher et chaque son est lu SANS attente, dans le geste de
/// l'utilisateur (obligatoire sur iPhone et sur Android, où un son lancé après une attente est bloqué).
void webSoundPlay(String name, double volume) {
  try {
    if (!globalContext.has('boutikSound')) return;
    final o = globalContext['boutikSound'] as JSObject;
    o.callMethod('play'.toJS, 'assets/assets/sounds/$name.wav'.toJS, volume.toJS);
  } catch (_) {}
}

/// Débloque l'audio (à appeler depuis un geste) et précharge les sons usuels.
void webSoundUnlock() {
  try {
    if (!globalContext.has('boutikSound')) return;
    final o = globalContext['boutikSound'] as JSObject;
    o.callMethod('unlock'.toJS);
  } catch (_) {}
}
