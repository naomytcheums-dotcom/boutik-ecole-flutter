import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// État réseau annoncé par le navigateur.
bool browserOnline() => web.window.navigator.onLine;

/// Événements « online » / « offline » du navigateur (coupure et retour du réseau).
void listenConnectivity(void Function(bool online) onChange) {
  web.window.addEventListener('online', ((web.Event _) => onChange(true)).toJS);
  web.window.addEventListener('offline', ((web.Event _) => onChange(false)).toJS);
}
