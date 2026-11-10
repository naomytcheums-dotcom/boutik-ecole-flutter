import 'package:flutter/widgets.dart';

import 'live_transport_stub.dart' if (dart.library.js_interop) 'live_transport_web.dart' as impl;

/// Transport vidéo temps réel d'un live (LiveKit). Sur navigateur : SDK LiveKit chargé par `web/live_bridge.js`.
/// Ailleurs (application native) : indisponible tant que le SDK natif n'est pas ajouté ; l'écran l'indique clairement.
abstract class LiveTransport {
  /// Vrai si cet appareil peut diffuser / regarder en temps réel.
  bool get supported;

  /// Surface vidéo à afficher (une seule par transport).
  Widget videoView();

  /// Se connecte à la salle. `publish` : diffuser caméra et micro (hôte). Les rappels ne sont jamais appelés après [disconnect].
  /// États : connecting · connected · reconnecting · disconnected. Erreurs : permission_denied · device_not_found · device_busy · sdk_unavailable · connect_failed.
  Future<bool> connect({required String url, required String token, required bool publish, required void Function(String) onState, required void Function(int) onParticipants, required void Function(String) onError});

  Future<void> setCamera(bool on);
  Future<void> setMic(bool on);
  Future<void> disconnect();
}

LiveTransport createLiveTransport() => impl.createTransport();

/// Message lisible pour un code d'erreur du transport.
String liveErrorMessage(String code) => switch (code) {
      'permission_denied' => 'Autorisez la caméra et le micro dans votre navigateur ou les réglages de l’appareil, puis réessayez.',
      'device_not_found' => 'Aucune caméra ou aucun micro n’a été trouvé sur cet appareil.',
      'device_busy' => 'La caméra ou le micro est utilisé par une autre application. Fermez-la puis réessayez.',
      'sdk_unavailable' => 'Le module de diffusion n’a pas pu être chargé. Vérifiez votre connexion puis réessayez.',
      'unsupported' => 'La diffusion en direct est disponible dans le navigateur (Chrome, Safari, Firefox). Elle n’est pas encore activée dans l’application installée.',
      _ => 'La connexion au direct a échoué. Vérifiez votre réseau puis réessayez.',
    };
