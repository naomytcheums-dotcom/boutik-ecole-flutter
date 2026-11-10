import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'live_transport.dart';

LiveTransport createTransport() => _WebTransport();

bool _registered = false;

class _WebTransport implements LiveTransport {
  String? _elementId;
  bool _closed = false;

  JSObject? get _bridge {
    if (!globalContext.has('boutikLive')) return null;
    return globalContext['boutikLive'] as JSObject;
  }

  @override
  bool get supported {
    final b = _bridge;
    if (b == null) return false;
    try {
      return (b.callMethod('supported'.toJS) as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget videoView() {
    if (!_registered) {
      _registered = true;
      ui_web.platformViewRegistry.registerViewFactory('boutik-live-video', (int id) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = 'boutik-live-video-$id';
        div.style.width = '100%';
        div.style.height = '100%';
        div.style.background = '#000';
        return div;
      });
    }
    return HtmlElementView(viewType: 'boutik-live-video', onPlatformViewCreated: (id) => _elementId = 'boutik-live-video-$id');
  }

  @override
  Future<bool> connect({required String url, required String token, required bool publish, required void Function(String) onState, required void Function(int) onParticipants, required void Function(String) onError}) async {
    final b = _bridge;
    if (b == null) {
      onError('sdk_unavailable');
      return false;
    }
    // la surface vidéo doit exister avant la connexion
    for (var i = 0; i < 40 && _elementId == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final cb = JSObject()
      ..['state'] = ((JSString s) {
        if (!_closed) onState(s.toDart);
      }).toJS
      ..['participants'] = ((JSNumber n) {
        if (!_closed) onParticipants(n.toDartInt);
      }).toJS
      ..['error'] = ((JSString e) {
        if (!_closed) onError(e.toDart);
      }).toJS;
    try {
      await (b.callMethodVarArgs('connect'.toJS, [url.toJS, token.toJS, publish.toJS, (_elementId ?? '').toJS, cb]) as JSPromise).toDart;
      return true;
    } catch (_) {
      return false; // l'erreur a déjà été signalée par le pont (code précis)
    }
  }

  @override
  Future<void> setCamera(bool on) async {
    try {
      await (_bridge?.callMethod('setCamera'.toJS, on.toJS) as JSPromise?)?.toDart;
    } catch (_) {}
  }

  @override
  Future<void> setMic(bool on) async {
    try {
      await (_bridge?.callMethod('setMic'.toJS, on.toJS) as JSPromise?)?.toDart;
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    _closed = true;
    try {
      await (_bridge?.callMethod('disconnect'.toJS) as JSPromise?)?.toDart;
    } catch (_) {}
  }
}
