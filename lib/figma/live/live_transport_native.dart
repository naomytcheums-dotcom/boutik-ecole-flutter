import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import 'live_transport.dart';

LiveTransport createTransport() => _NativeTransport();

/// Transport LiveKit des applications Android et iOS (jamais importé sur le web : voir `live_transport.dart`).
class _NativeTransport implements LiveTransport {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _closed = false;
  bool _publish = false;
  final ValueNotifier<List<lk.VideoTrack>> _tracks = ValueNotifier(const []);

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  @override
  Widget videoView() => _TracksView(_tracks);

  /// Android : les autorisations sont demandées avant la connexion pour distinguer un refus d'un périphérique absent.
  /// iOS : la demande est faite par WebRTC à la première capture (textes dans Info.plist).
  Future<bool> _permissions(bool publish) async {
    if (!publish || !Platform.isAndroid) return true;
    final r = await [Permission.camera, Permission.microphone].request();
    final granted = r.values.every((s) => s.isGranted || s.isLimited);
    // Bluetooth (casques) : facultatif, un refus n'empêche pas de diffuser
    try {
      await Permission.bluetoothConnect.request();
    } catch (_) {}
    return granted;
  }

  static String _describe(Object e) {
    final t = '${e.runtimeType} $e';
    if (RegExp(r'NotAllowed|Permission|denied', caseSensitive: false).hasMatch(t)) return 'permission_denied';
    if (RegExp(r'NotFound|DevicesNotFound|no .*(camera|microphone|device)', caseSensitive: false).hasMatch(t)) return 'device_not_found';
    if (RegExp(r'NotReadable|TrackStart|in use|busy|could not start', caseSensitive: false).hasMatch(t)) return 'device_busy';
    return 'connect_failed';
  }

  void _refreshTracks() {
    final room = _room;
    if (_closed || room == null) return;
    final next = <lk.VideoTrack>[];
    void collect(lk.Participant p) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (t is lk.VideoTrack && !pub.muted && pub.source != lk.TrackSource.screenShareVideo) next.add(t);
      }
    }

    final local = room.localParticipant;
    if (local != null) collect(local);
    room.remoteParticipants.values.forEach(collect);
    final old = _tracks.value;
    if (old.length == next.length && [for (var i = 0; i < old.length; i++) old[i].sid == next[i].sid].every((x) => x)) return;
    _tracks.value = next;
  }

  @override
  Future<bool> connect({required String url, required String token, required bool publish, required void Function(String) onState, required void Function(int) onParticipants, required void Function(String) onError}) async {
    if (!supported) {
      onError('unsupported');
      return false;
    }
    _closed = false;
    _publish = publish;
    if (!await _permissions(publish)) {
      onError('permission_denied');
      return false;
    }
    final room = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
    _room = room;
    void count() {
      if (!_closed) onParticipants(room.remoteParticipants.length + 1);
    }

    _listener = room.createListener()
      ..on<lk.RoomReconnectingEvent>((_) {
        if (!_closed) onState('reconnecting');
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        if (!_closed) onState('connected');
      })
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (!_closed) onState('disconnected');
      })
      ..on<lk.ParticipantConnectedEvent>((_) => count())
      ..on<lk.ParticipantDisconnectedEvent>((_) => count());
    room.addListener(_refreshTracks);
    try {
      onState('connecting');
      await room.connect(url, token);
      if (_closed) return false;
      onState('connected');
      count();
      if (publish) {
        await room.localParticipant?.setCameraEnabled(true);
        try {
          await room.localParticipant?.setMicrophoneEnabled(true);
        } catch (e) {
          onError(_describe(e)); // le direct peut continuer sans micro ; l'écran affiche la cause
        }
      }
      _refreshTracks();
      return true;
    } catch (e) {
      if (!_closed) onError(_describe(e));
      await disconnect();
      return false;
    }
  }

  @override
  Future<void> setCamera(bool on) async {
    if (!_publish) return;
    try {
      await _room?.localParticipant?.setCameraEnabled(on);
    } catch (_) {}
  }

  @override
  Future<void> setMic(bool on) async {
    if (!_publish) return;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(on);
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    _closed = true;
    final room = _room, listener = _listener;
    _room = null;
    _listener = null;
    _tracks.value = const [];
    room?.removeListener(_refreshTracks);
    try {
      await listener?.dispose();
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {}
  }
}

/// Vidéos des diffuseurs (hôte + invités) : une seule plein écran, sinon une grille 2 colonnes comme sur le web.
class _TracksView extends StatelessWidget {
  const _TracksView(this.tracks);
  final ValueNotifier<List<lk.VideoTrack>> tracks;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF000000),
        child: ValueListenableBuilder<List<lk.VideoTrack>>(
          valueListenable: tracks,
          builder: (context, list, _) {
            if (list.isEmpty) return const SizedBox.expand();
            if (list.length == 1) return lk.VideoTrackRenderer(list.first, key: ValueKey(list.first.sid), fit: lk.VideoViewFit.contain);
            return LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth / 2, h = list.length > 2 ? c.maxHeight / 2 : c.maxHeight;
              return Wrap(children: [
                for (final t in list) SizedBox(width: w, height: h, child: lk.VideoTrackRenderer(t, key: ValueKey(t.sid), fit: lk.VideoViewFit.cover)),
              ]);
            });
          },
        ),
      );
}
