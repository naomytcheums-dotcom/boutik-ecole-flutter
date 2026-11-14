import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'community_exchanges.dart' show communityGate;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'room_transport.dart';

/// Salons vocaux d'une communauté (« Live Étude ») : micro, écoute, partage d'écran et tableau blanc.
/// Le son et l'écran passent directement entre les appareils (WebRTC) ; la négociation et le tableau blanc passent par Supabase Realtime.
/// L'existence et l'accès des salons sont gérés par le serveur (migration 20261114002100) : membres de la communauté seulement.

// ------------------------------------------------------------------ tableau blanc

class Stroke {
  const Stroke({required this.id, required this.color, required this.width, required this.points});
  final String id;
  final int color;
  final double width;

  /// Points en proportion de la zone de dessin (0 à 1), pour que le trait s'affiche pareil sur tous les écrans.
  final List<Offset> points;

  Map<String, dynamic> toJson() => {
        'id': id,
        'c': color,
        'w': width,
        'p': [for (final o in points) [double.parse(o.dx.toStringAsFixed(4)), double.parse(o.dy.toStringAsFixed(4))]],
      };

  static Stroke? fromJson(Object? j) {
    if (j is! Map) return null;
    final pts = j['p'];
    if (j['id'] is! String || pts is! List) return null;
    final points = <Offset>[];
    for (final p in pts.take(2000)) {
      if (p is List && p.length == 2 && p[0] is num && p[1] is num) points.add(Offset((p[0] as num).toDouble().clamp(0.0, 1.0), (p[1] as num).toDouble().clamp(0.0, 1.0)));
    }
    if (points.isEmpty) return null;
    return Stroke(id: j['id'] as String, color: (j['c'] as num?)?.toInt() ?? 0xFF111015, width: ((j['w'] as num?)?.toDouble() ?? 3).clamp(1.0, 16.0), points: points);
  }
}

const boardColors = [0xFF111015, 0xFFE5484D, 0xFF2563EB, 0xFF0F7A52];

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.strokes, this.current);
  final List<Stroke> strokes;
  final Stroke? current;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in [...strokes, if (current != null) current!]) {
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(Offset(s.points[0].dx * size.width, s.points[0].dy * size.height), s.width / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.points[0].dx * size.width, s.points[0].dy * size.height);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

/// Zone de dessin partagée : on trace au doigt ou à la souris, le trait est envoyé aux autres à la fin du geste.
class RoomWhiteboard extends StatefulWidget {
  const RoomWhiteboard({super.key, required this.strokes, required this.onStroke, required this.onClear, this.height = 280});
  final List<Stroke> strokes;
  final ValueChanged<Stroke> onStroke;
  final VoidCallback onClear;
  final double height;

  @override
  State<RoomWhiteboard> createState() => _RoomWhiteboardState();
}

class _RoomWhiteboardState extends State<RoomWhiteboard> {
  int _color = boardColors[0];
  Stroke? _current;
  final _rng = math.Random();

  Offset _norm(Offset local, Size size) => Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (final c in boardColors)
          Semantics(
            button: true,
            label: 'Couleur du trait',
            child: GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(width: 30, height: 30, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: _color == c ? kViolet : Colors.white, width: 3))),
            ),
          ),
        const Spacer(),
        TextButton.icon(onPressed: widget.onClear, icon: const Icon(Icons.delete_outline, size: 18), label: Text('Tout effacer', style: mst(12.5, w: FontWeight.w700))),
      ]),
      const SizedBox(height: 6),
      LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, widget.height);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onPanStart: (d) => setState(() => _current = Stroke(id: '${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 20)}', color: _color, width: 3.5, points: [_norm(d.localPosition, size)])),
            onPanUpdate: (d) {
              final c = _current;
              if (c == null) return;
              setState(() => _current = Stroke(id: c.id, color: c.color, width: c.width, points: [...c.points, _norm(d.localPosition, size)]));
            },
            onPanEnd: (_) {
              final c = _current;
              setState(() => _current = null);
              if (c != null) widget.onStroke(c);
            },
            child: Container(
              key: const Key('room-board'),
              width: size.width,
              height: size.height,
              color: Colors.white,
              child: CustomPaint(painter: _BoardPainter(widget.strokes, _current)),
            ),
          ),
        );
      }),
    ]);
  }
}

// ------------------------------------------------------------------ signalisation

/// Canal de la salle : présence (qui est là), messages de négociation adressés à une personne, tableau blanc diffusé à tous.
abstract class RoomSignaling {
  Future<void> join({required String selfId, required Map<String, dynamic> me, required void Function(Map<String, Map<String, dynamic>> peers) onPeers, required void Function(String from, String data) onSignal, required void Function(Map<String, dynamic> msg) onBoard});
  Future<void> sendSignal(String from, String to, String data);
  Future<void> sendBoard(Map<String, dynamic> msg);
  Future<void> updateMe(Map<String, dynamic> me);
  Future<void> leave();
}

class SupabaseRoomSignaling implements RoomSignaling {
  SupabaseRoomSignaling(this.roomId);
  final String roomId;
  RealtimeChannel? _ch;
  String _self = '';

  @override
  Future<void> join({required String selfId, required Map<String, dynamic> me, required void Function(Map<String, Map<String, dynamic>> peers) onPeers, required void Function(String from, String data) onSignal, required void Function(Map<String, dynamic> msg) onBoard}) async {
    _self = selfId;
    final ch = Supabase.instance.client.channel('study-room:$roomId', opts: RealtimeChannelConfig(key: selfId));
    _ch = ch;
    Map<String, dynamic> body(Map<String, dynamic> p) => Map<String, dynamic>.from((p['payload'] as Map?) ?? p);
    ch
      ..onPresenceSync((_) {
        final peers = <String, Map<String, dynamic>>{};
        for (final s in ch.presenceState()) {
          if (s.presences.isNotEmpty) peers[s.key] = Map<String, dynamic>.from(s.presences.last.payload);
        }
        onPeers(peers);
      })
      ..onBroadcast(event: 'signal', callback: (p) {
        final d = body(p);
        if (d['to'] == selfId && d['from'] is String && d['data'] is String) onSignal(d['from'] as String, d['data'] as String);
      })
      ..onBroadcast(event: 'board', callback: (p) {
        final d = body(p);
        if (d['by'] != selfId) onBoard(d);
      });
    final done = Future<void>.delayed(const Duration(seconds: 12), () => throw TimeoutException('subscribe'));
    final subscribed = Completer<void>();
    ch.subscribe((status, err) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track(me);
        if (!subscribed.isCompleted) subscribed.complete();
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        if (!subscribed.isCompleted) subscribed.completeError(err ?? 'channel');
      }
    });
    await Future.any([subscribed.future, done]);
  }

  @override
  Future<void> sendSignal(String from, String to, String data) async {
    await _ch?.sendBroadcastMessage(event: 'signal', payload: {'from': from, 'to': to, 'data': data});
  }

  @override
  Future<void> sendBoard(Map<String, dynamic> msg) async {
    await _ch?.sendBroadcastMessage(event: 'board', payload: {...msg, 'by': _self});
  }

  @override
  Future<void> updateMe(Map<String, dynamic> me) async {
    await _ch?.track(me);
  }

  @override
  Future<void> leave() async {
    final ch = _ch;
    _ch = null;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {}
      await Supabase.instance.client.removeChannel(ch);
    }
  }
}

// ------------------------------------------------------------------ session

class RoomPeer {
  const RoomPeer(this.id, this.name, this.mic);
  final String id, name;
  final bool mic;
}

/// État d'une salle pour la personne connectée : participants, micro, écran partagé, tableau blanc.
class RoomSession extends ChangeNotifier {
  RoomSession({required this.transport, required this.signaling, required this.selfId, required this.name});
  final RoomTransport transport;
  final RoomSignaling signaling;
  final String selfId, name;

  final Map<String, RoomPeer> peers = {};
  final List<Stroke> strokes = [];
  bool mic = true, sharing = false, connected = false, _left = false;
  String? error, remoteScreenFrom;

  Map<String, dynamic> get _me => {'name': name, 'mic': mic};

  Future<bool> join() async {
    final ok = await transport.start(
      selfId: selfId,
      sendSignal: (to, data) => signaling.sendSignal(selfId, to, data),
      onError: (code) {
        error = code;
        notifyListeners();
      },
      onRemoteScreen: (from) {
        remoteScreenFrom = from.isEmpty ? null : from;
        notifyListeners();
      },
      onScreenEnded: () {
        sharing = false;
        notifyListeners();
      },
    );
    if (!ok) {
      error ??= 'connect_failed';
      notifyListeners();
      return false;
    }
    try {
      await signaling.join(selfId: selfId, me: _me, onPeers: _onPeers, onSignal: transport.signal, onBoard: _onBoard);
    } catch (_) {
      error = 'connect_failed';
      transport.leave();
      notifyListeners();
      return false;
    }
    connected = true;
    notifyListeners();
    return true;
  }

  void _onPeers(Map<String, Map<String, dynamic>> now) {
    if (_left) return;
    final others = {for (final e in now.entries) if (e.key != selfId) e.key: e.value};
    for (final id in others.keys) {
      if (!peers.containsKey(id)) {
        transport.peerJoined(id);
        if (strokes.isNotEmpty) signaling.sendBoard({'k': 'history', 'to': id, 's': [for (final s in strokes.take(300)) s.toJson()]});
      }
    }
    for (final id in peers.keys.toList()) {
      if (!others.containsKey(id)) {
        transport.peerLeft(id);
        if (remoteScreenFrom == id) remoteScreenFrom = null;
      }
    }
    peers
      ..clear()
      ..addEntries([for (final e in others.entries) MapEntry(e.key, RoomPeer(e.key, '${e.value['name'] ?? 'Membre'}', e.value['mic'] != false))]);
    notifyListeners();
  }

  void _onBoard(Map<String, dynamic> m) {
    switch (m['k']) {
      case 'stroke':
        _add(Stroke.fromJson(m['s']));
      case 'history':
        if (m['to'] == selfId && m['s'] is List) {
          for (final j in (m['s'] as List).take(300)) {
            _add(Stroke.fromJson(j));
          }
        }
      case 'clear':
        strokes.clear();
    }
    notifyListeners();
  }

  void _add(Stroke? s) {
    if (s == null || strokes.any((x) => x.id == s.id) || strokes.length >= 600) return;
    strokes.add(s);
  }

  void toggleMic() {
    mic = !mic;
    transport.setMic(mic);
    signaling.updateMe(_me);
    notifyListeners();
  }

  Future<void> toggleScreen() async {
    if (sharing) {
      transport.stopScreen();
      sharing = false;
    } else {
      sharing = await transport.startScreen();
      if (!sharing) error = transport.canShareScreen ? null : 'screen_unsupported';
    }
    notifyListeners();
  }

  void draw(Stroke s) {
    _add(s);
    signaling.sendBoard({'k': 'stroke', 's': s.toJson()});
    notifyListeners();
  }

  void clearBoard() {
    strokes.clear();
    signaling.sendBoard({'k': 'clear'});
    notifyListeners();
  }

  Future<void> leave() async {
    if (_left) return;
    _left = true;
    transport.leave();
    await signaling.leave();
  }
}

// ------------------------------------------------------------------ écrans

final studyRoomsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, communityId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('study_rooms_list', {'p_community': communityId});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

/// Onglet « Salons » d'une communauté : salons ouverts, ouvrir un salon, rejoindre, fermer.
class StudyRoomsTab extends ConsumerWidget {
  const StudyRoomsTab({super.key, required this.communityId, required this.isMember});
  final String communityId;
  final bool isMember;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (!await requireLogin(context, ref, 'ouvrir un salon vocal') || !context.mounted) return;
    final title = TextEditingController(), topic = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ouvrir un salon vocal', style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Tous les membres de la communauté sont prévenus et peuvent vous rejoindre.', style: mst(12.5, c: kGrey)),
          const SizedBox(height: 12),
          TextField(controller: title, maxLength: 80, decoration: InputDecoration(labelText: 'Titre', hintText: 'Révision réseaux', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 10),
          TextField(controller: topic, maxLength: 200, decoration: InputDecoration(labelText: 'Sujet (facultatif)', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Ouvrir', () => Navigator.pop(c, true))),
          ]),
        ]),
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('study_room_create', {'p_community': communityId, 'p_title': title.text, 'p_topic': topic.text});
    if (!context.mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(studyRoomsProvider(communityId));
    await openStudyRoom(context, '${r.data}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isMember) return communityGate(context, ref, 'Les salons vocaux sont réservés aux membres de la communauté.\nRejoignez-la pour y participer.', 'accéder aux salons vocaux de cette communauté');
    return mAsync<List<Map<String, dynamic>>>(
      ref.watch(studyRoomsProvider(communityId)),
      (rooms) => ListView(padding: const EdgeInsets.all(16), children: [
        mButton('Ouvrir un salon vocal', () => _create(context, ref), icon: Icons.mic_none),
        const SizedBox(height: 12),
        if (rooms.isEmpty) mNote('Aucun salon ouvert pour le moment.\nOuvrez-en un pour réviser ensemble : micro, partage d’écran et tableau blanc.'),
        for (final r in rooms)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.graphic_eq, color: kViolet),
                const SizedBox(width: 8),
                Expanded(child: Text('${r['title']}', style: mst(15, w: FontWeight.w800))),
              ]),
              if ('${r['topic'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['topic']}', style: mst(12.5, c: kGrey))),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Organisé par ${r['host']}', style: mst(12, c: kGrey))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: mButton('Rejoindre', () async {
                  if (!await requireLogin(context, ref, 'rejoindre un salon vocal') || !context.mounted) return;
                  await openStudyRoom(context, '${r['id']}');
                }, icon: Icons.headset_mic_outlined)),
                if (r['can_close'] == true) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: mButton('Fermer', () async {
                      if (!await requireLogin(context, ref, 'fermer ce salon') || !context.mounted) return;
                      final x = await marcheCall('study_room_close', {'p_room': r['id']});
                      if (!context.mounted) return;
                      if (x.error != null) gToast(context, Backend.userMessage('${x.error}'));
                      ref.invalidate(studyRoomsProvider(communityId));
                    }, dark: false),
                  ),
                ],
              ]),
            ]),
          ),
      ]),
    );
  }
}

Future<void> openStudyRoom(BuildContext context, String roomId) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StudyRoomScreen(roomId: roomId)));

class StudyRoomScreen extends ConsumerStatefulWidget {
  const StudyRoomScreen({super.key, required this.roomId, this.sessionFactory});
  final String roomId;

  /// Pour les tests : fournit la session au lieu de se connecter au serveur.
  final RoomSession Function(Map<String, dynamic> info)? sessionFactory;

  @override
  ConsumerState<StudyRoomScreen> createState() => _RoomState();
}

class _RoomState extends ConsumerState<StudyRoomScreen> {
  RoomSession? _s;
  Map<String, dynamic>? _info;
  String? _failure;
  bool _board = false, _joining = true;

  @override
  void initState() {
    super.initState();
    _enter();
  }

  Future<void> _enter() async {
    final r = await marcheCall('study_room_enter', {'p_room': widget.roomId});
    if (!mounted) return;
    if (r.error != null || r.data is! Map) {
      setState(() {
        _failure = Backend.userMessage('${r.error ?? 'Salon indisponible'}');
        _joining = false;
      });
      return;
    }
    final info = Map<String, dynamic>.from(r.data as Map);
    final s = widget.sessionFactory?.call(info) ??
        RoomSession(transport: createRoomTransport(), signaling: SupabaseRoomSignaling(widget.roomId), selfId: '${info['self_id']}', name: '${info['name']}');
    s.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _info = info;
      _s = s;
    });
    final ok = await s.join();
    if (!mounted) return;
    setState(() {
      _joining = false;
      if (!ok) _failure = roomErrorMessage(s.error ?? 'connect_failed');
    });
  }

  @override
  void dispose() {
    _s?.leave();
    _s?.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final x = await marcheCall('study_room_close', {'p_room': widget.roomId});
    if (!mounted) return;
    if (x.error != null) return gToast(context, Backend.userMessage('${x.error}'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kInk,
        title: Text(_info == null ? 'Salon vocal' : '${_info!['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(17, w: FontWeight.w800)),
        actions: [if (_info?['can_close'] == true) TextButton(onPressed: _close, child: Text('Fermer le salon', style: mst(12.5, w: FontWeight.w700, c: kRed)))],
      ),
      body: SafeArea(
        child: _failure != null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [mNote(_failure!), mButton('Retour', () => Navigator.of(context).maybePop(), dark: false, width: 160)])
            : (_joining || s == null)
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                    if ('${_info!['topic'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${_info!['topic']}', style: mst(13, c: kGrey))),
                    if (s.error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(roomErrorMessage(s.error!), style: mst(12.5, w: FontWeight.w600, c: kRed))),
                    Text('Dans le salon · ${s.peers.length + 1}', style: mst(15, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _chip('Vous', s.mic),
                      for (final p in s.peers.values) _chip(p.name, p.mic, sharing: s.remoteScreenFrom == p.id),
                    ]),
                    if (s.peers.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Vous êtes seul pour l’instant. Les autres membres ont reçu une notification.', style: mst(12.5, c: kGrey))),
                    if (s.remoteScreenFrom != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${s.peers[s.remoteScreenFrom]?.name ?? 'Un membre'} partage son écran (affiché en haut de la page).', style: mst(12.5, w: FontWeight.w700, c: kViolet))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: mButton(s.mic ? 'Couper le micro' : 'Activer le micro', s.toggleMic, dark: s.mic, icon: s.mic ? Icons.mic : Icons.mic_off)),
                      const SizedBox(width: 10),
                      Expanded(child: mButton(s.sharing ? 'Arrêter le partage' : 'Partager l’écran', () => s.toggleScreen(), dark: false, icon: Icons.screen_share_outlined)),
                    ]),
                    const SizedBox(height: 10),
                    mButton(_board ? 'Masquer le tableau blanc' : 'Tableau blanc', () => setState(() => _board = !_board), dark: false, icon: Icons.draw_outlined),
                    if (_board) Padding(padding: const EdgeInsets.only(top: 12), child: RoomWhiteboard(strokes: s.strokes, onStroke: s.draw, onClear: s.clearBoard)),
                    const SizedBox(height: 16),
                    Text('Le son passe directement entre les appareils. Sur certains réseaux (entreprises, forfaits très restreints) la connexion peut échouer : essayez alors le Wi-Fi.', style: mst(11.5, c: kGrey).copyWith(height: 1.4)),
                    const SizedBox(height: 12),
                    mButton('Quitter le salon', () => Navigator.of(context).maybePop(), dark: false, icon: Icons.logout),
                  ]),
      ),
    );
  }

  Widget _chip(String name, bool mic, {bool sharing = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(mic ? Icons.mic : Icons.mic_off, size: 16, color: mic ? kGreen : kGrey),
          const SizedBox(width: 6),
          Text(name, style: mst(12.5, w: FontWeight.w700)),
          if (sharing) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.screen_share, size: 15, color: kViolet)),
        ]),
      );
}

/// Pour les tests de l'encodage des messages de négociation.
String encodeSignal(Map<String, dynamic> m) => jsonEncode(m);
