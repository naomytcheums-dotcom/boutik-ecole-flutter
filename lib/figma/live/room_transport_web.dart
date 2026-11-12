import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'room_transport.dart';

RoomTransport createTransport() => _WebTransport();

class _WebTransport implements RoomTransport {
  bool _closed = false;

  JSObject? get _bridge => globalContext.has('boutikRoom') ? globalContext['boutikRoom'] as JSObject : null;

  bool _flag(String name) {
    final b = _bridge;
    if (b == null) return false;
    try {
      return (b.callMethod(name.toJS) as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get supported => _flag('supported');
  @override
  bool get canShareScreen => _flag('canShareScreen');

  @override
  Future<bool> start({required String selfId, required void Function(String to, String payload) sendSignal, required void Function(String code) onError, required void Function(String from) onRemoteScreen, required void Function() onScreenEnded}) async {
    final b = _bridge;
    if (b == null) {
      onError('unsupported');
      return false;
    }
    final cb = JSObject()
      ..['error'] = ((JSString e) {
        if (!_closed) onError(e.toDart);
      }).toJS
      ..['remoteScreen'] = ((JSString who) {
        if (!_closed) onRemoteScreen(who.toDart);
      }).toJS
      ..['screenEnded'] = ((JSString _) {
        if (!_closed) onScreenEnded();
      }).toJS;
    final send = ((JSString to, JSString payload) {
      if (!_closed) sendSignal(to.toDart, payload.toDart);
    }).toJS;
    try {
      await (b.callMethodVarArgs('start'.toJS, [selfId.toJS, send, cb]) as JSPromise).toDart;
      return true;
    } catch (_) {
      return false; // le pont a déjà signalé le code d'erreur précis
    }
  }

  @override
  void peerJoined(String id) => _bridge?.callMethod('peerJoined'.toJS, id.toJS);
  @override
  void peerLeft(String id) => _bridge?.callMethod('peerLeft'.toJS, id.toJS);
  @override
  void signal(String from, String payload) {
    final b = _bridge;
    if (b == null) return;
    try {
      (b.callMethodVarArgs('signal'.toJS, [from.toJS, payload.toJS]) as JSPromise).toDart.catchError((_) => null);
    } catch (_) {}
  }

  @override
  void setMic(bool on) => _bridge?.callMethod('setMic'.toJS, on.toJS);

  @override
  Future<bool> startScreen() async {
    final b = _bridge;
    if (b == null) return false;
    try {
      return ((await (b.callMethod('startScreen'.toJS) as JSPromise).toDart) as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  void stopScreen() => _bridge?.callMethod('stopScreen'.toJS);

  @override
  void leave() {
    _closed = true;
    _bridge?.callMethod('leave'.toJS);
  }
}
