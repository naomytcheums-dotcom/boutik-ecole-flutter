import 'room_transport.dart';

RoomTransport createTransport() => _Unsupported();

class _Unsupported implements RoomTransport {
  @override
  bool get supported => false;
  @override
  bool get canShareScreen => false;
  @override
  Future<bool> start({required String selfId, required void Function(String to, String payload) sendSignal, required void Function(String code) onError, required void Function(String from) onRemoteScreen, required void Function() onScreenEnded}) async {
    onError('unsupported');
    return false;
  }

  @override
  void peerJoined(String id) {}
  @override
  void peerLeft(String id) {}
  @override
  void signal(String from, String payload) {}
  @override
  void setMic(bool on) {}
  @override
  Future<bool> startScreen() async => false;
  @override
  void stopScreen() {}
  @override
  void leave() {}
}
