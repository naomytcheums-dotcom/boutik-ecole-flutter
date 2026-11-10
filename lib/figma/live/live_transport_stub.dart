import 'package:flutter/widgets.dart';

import 'live_transport.dart';

LiveTransport createTransport() => _Unsupported();

class _Unsupported implements LiveTransport {
  @override
  bool get supported => false;
  @override
  Widget videoView() => const SizedBox.expand();
  @override
  Future<bool> connect({required String url, required String token, required bool publish, required void Function(String) onState, required void Function(int) onParticipants, required void Function(String) onError}) async {
    onError('unsupported');
    return false;
  }

  @override
  Future<void> setCamera(bool on) async {}
  @override
  Future<void> setMic(bool on) async {}
  @override
  Future<void> disconnect() async {}
}
