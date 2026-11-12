import 'room_transport_stub.dart' if (dart.library.js_interop) 'room_transport_web.dart' as impl;

/// Transport son + partage d'écran d'un salon vocal (WebRTC entre les appareils des membres). Sur navigateur : `web/room_bridge.js`.
/// Ailleurs (application native) : indisponible tant que le module natif n'est pas ajouté ; l'écran l'indique clairement.
abstract class RoomTransport {
  bool get supported;
  bool get canShareScreen;

  /// Ouvre le micro et prépare les connexions. `sendSignal` transmet un message de négociation à une personne précise.
  Future<bool> start({
    required String selfId,
    required void Function(String to, String payload) sendSignal,
    required void Function(String code) onError,
    required void Function(String from) onRemoteScreen,
    required void Function() onScreenEnded,
  });

  void peerJoined(String id);
  void peerLeft(String id);
  void signal(String from, String payload);
  void setMic(bool on);
  Future<bool> startScreen();
  void stopScreen();
  void leave();
}

RoomTransport createRoomTransport() => impl.createTransport();

/// Message lisible pour un code d'erreur du transport.
String roomErrorMessage(String code) => switch (code) {
      'permission_denied' => 'Autorisez le micro dans votre navigateur ou les réglages de l’appareil, puis réessayez.',
      'device_not_found' => 'Aucun micro n’a été trouvé sur cet appareil.',
      'device_busy' => 'Le micro est utilisé par une autre application. Fermez-la puis réessayez.',
      'unsupported' => 'Les salons vocaux fonctionnent dans le navigateur (Chrome, Safari, Firefox). Ils ne sont pas encore activés dans l’application installée.',
      'autoplay_blocked' => 'Touchez l’écran pour activer le son des autres participants.',
      'screen_unsupported' => 'Le partage d’écran n’est pas proposé par ce navigateur (il fonctionne sur ordinateur).',
      _ => 'La connexion au salon a échoué. Vérifiez votre réseau puis réessayez.',
    };
