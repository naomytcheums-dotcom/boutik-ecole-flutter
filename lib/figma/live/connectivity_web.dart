import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// État réseau annoncé par le navigateur.
bool browserOnline() => web.window.navigator.onLine;

/// Événements « online » / « offline » du navigateur (coupure et retour du réseau).
void Function() listenConnectivity(void Function(bool online) onChange) {
  final on = ((web.Event _) => onChange(true)).toJS;
  final off = ((web.Event _) => onChange(false)).toJS;
  web.window.addEventListener('online', on);
  web.window.addEventListener('offline', off);
  return () {
    web.window.removeEventListener('online', on);
    web.window.removeEventListener('offline', off);
  };
}
