import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Abonnement aux notifications du navigateur (Web Push, clés VAPID) : renvoie l'abonnement en JSON, ou null si refusé ou non pris en charge.
bool get webPushSupported => globalContext.has('PushManager') && globalContext.has('Notification');

Uint8List _b64url(String s) {
  final p = s.padRight((s.length + 3) ~/ 4 * 4, '=').replaceAll('-', '+').replaceAll('_', '/');
  return base64.decode(p);
}

Future<String?> subscribeWebPush(String publicKey) async {
  try {
    if (!webPushSupported) return null;
    final perm = await web.Notification.requestPermission().toDart;
    if (perm.toDart != 'granted') return null;
    final reg = await web.window.navigator.serviceWorker.register('push_sw.js'.toJS).toDart;
    await web.window.navigator.serviceWorker.ready.toDart;
    final sub = await reg.pushManager.subscribe(web.PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: _b64url(publicKey).toJS)).toDart;
    return jsonEncode(sub.toJSON().dartify());
  } catch (_) {
    return null;
  }
}
