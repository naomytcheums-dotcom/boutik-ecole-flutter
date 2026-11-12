import 'package:boutik_ecole/figma/live/room_transport.dart';
import 'package:boutik_ecole/figma/live/study_rooms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class FakeTransport implements RoomTransport {
  final log = <String>[];
  void Function(String to, String payload)? send;
  void Function(String code)? onErr;
  bool startOk = true, screenOk = true;
  @override
  bool get supported => true;
  @override
  bool get canShareScreen => true;
  @override
  Future<bool> start({required String selfId, required void Function(String to, String payload) sendSignal, required void Function(String code) onError, required void Function(String from) onRemoteScreen, required void Function() onScreenEnded}) async {
    send = sendSignal;
    onErr = onError;
    if (!startOk) onError('permission_denied');
    return startOk;
  }

  @override
  void peerJoined(String id) => log.add('join:$id');
  @override
  void peerLeft(String id) => log.add('left:$id');
  @override
  void signal(String from, String payload) => log.add('signal:$from:$payload');
  @override
  void setMic(bool on) => log.add('mic:$on');
  @override
  Future<bool> startScreen() async {
    log.add('screen:on');
    return screenOk;
  }

  @override
  void stopScreen() => log.add('screen:off');
  @override
  void leave() => log.add('leave');
}

class FakeSignaling implements RoomSignaling {
  final sent = <String>[];
  final board = <Map<String, dynamic>>[];
  void Function(Map<String, Map<String, dynamic>>)? peers;
  void Function(String, String)? signal;
  void Function(Map<String, dynamic>)? onBoard;
  Map<String, dynamic> me = {};
  bool left = false, fail = false;
  @override
  Future<void> join({required String selfId, required Map<String, dynamic> me, required void Function(Map<String, Map<String, dynamic>> peers) onPeers, required void Function(String from, String data) onSignal, required void Function(Map<String, dynamic> msg) onBoard}) async {
    if (fail) throw Exception('canal');
    this.me = me;
    peers = onPeers;
    signal = onSignal;
    this.onBoard = onBoard;
  }

  @override
  Future<void> sendSignal(String from, String to, String data) async => sent.add('$from>$to:$data');
  @override
  Future<void> sendBoard(Map<String, dynamic> msg) async => board.add(msg);
  @override
  Future<void> updateMe(Map<String, dynamic> me) async => this.me = me;
  @override
  Future<void> leave() async => left = true;
}

RoomSession _session(FakeTransport t, FakeSignaling s) => RoomSession(transport: t, signaling: s, selfId: 'me', name: 'Awa E.');

void main() {
  test('rejoindre : micro ouvert puis présence ; les autres sont connectés un par un', () async {
    final t = FakeTransport(), s = FakeSignaling();
    final r = _session(t, s);
    expect(await r.join(), isTrue);
    expect(r.connected, isTrue);
    expect(s.me, {'name': 'Awa E.', 'mic': true});
    s.peers!({'me': {'name': 'Awa E.', 'mic': true}, 'p1': {'name': 'Paul M.', 'mic': false}, 'p2': {'name': 'Cora D.'}});
    expect(t.log, ['join:p1', 'join:p2'], reason: 'on ne se connecte jamais à soi-même');
    expect(r.peers.length, 2);
    expect(r.peers['p1']!.mic, isFalse);
    expect(r.peers['p2']!.mic, isTrue, reason: 'micro supposé ouvert sans information');
    s.peers!({'me': {'name': 'Awa E.'}, 'p2': {'name': 'Cora D.', 'mic': true}});
    expect(t.log.last, 'left:p1');
    expect(r.peers.keys, ['p2']);
  });

  test('négociation : les messages vont à la bonne personne dans les deux sens', () async {
    final t = FakeTransport(), s = FakeSignaling();
    final r = _session(t, s);
    await r.join();
    t.send!('p1', '{"d":1}');
    expect(s.sent, ['me>p1:{"d":1}']);
    s.signal!('p1', '{"c":2}');
    expect(t.log, ['signal:p1:{"c":2}']);
  });

  test('micro : coupé, annoncé aux autres', () async {
    final t = FakeTransport(), s = FakeSignaling();
    final r = _session(t, s);
    await r.join();
    r.toggleMic();
    expect(r.mic, isFalse);
    expect(t.log.last, 'mic:false');
    expect(s.me['mic'], isFalse);
  });

  test('refus du micro : message clair, aucune connexion au canal', () async {
    final t = FakeTransport()..startOk = false, s = FakeSignaling();
    final r = _session(t, s);
    expect(await r.join(), isFalse);
    expect(r.error, 'permission_denied');
    expect(roomErrorMessage(r.error!), contains('Autorisez le micro'));
    expect(s.peers, isNull);
  });

  test('canal indisponible : échec propre et micro relâché', () async {
    final t = FakeTransport(), s = FakeSignaling()..fail = true;
    final r = _session(t, s);
    expect(await r.join(), isFalse);
    expect(r.error, 'connect_failed');
    expect(t.log.last, 'leave');
  });

  test('partage d’écran : démarré puis arrêté ; refusé par le navigateur', () async {
    final t = FakeTransport(), s = FakeSignaling();
    final r = _session(t, s);
    await r.join();
    await r.toggleScreen();
    expect(r.sharing, isTrue);
    await r.toggleScreen();
    expect(r.sharing, isFalse);
    expect(t.log, containsAllInOrder(['screen:on', 'screen:off']));
    t.screenOk = false;
    await r.toggleScreen();
    expect(r.sharing, isFalse);
  });

  test('tableau blanc : traits envoyés, reçus une seule fois, historique pour le nouvel arrivant, effacement', () async {
    final t = FakeTransport(), s = FakeSignaling();
    final r = _session(t, s);
    await r.join();
    const mine = Stroke(id: 'a', color: 0xFF111015, width: 3.5, points: [Offset(0.1, 0.1), Offset(0.5, 0.5)]);
    r.draw(mine);
    expect(r.strokes.length, 1);
    expect(s.board.single['k'], 'stroke');
    s.onBoard!({'k': 'stroke', 's': mine.toJson(), 'by': 'p1'});
    expect(r.strokes.length, 1, reason: 'un trait déjà reçu n’est pas doublé');
    s.onBoard!({'k': 'stroke', 's': const Stroke(id: 'b', color: 0xFFE5484D, width: 3, points: [Offset(0.2, 0.9)]).toJson(), 'by': 'p1'});
    expect(r.strokes.length, 2);
    s.peers!({'me': {}, 'p9': {'name': 'Nouveau'}});
    expect(s.board.last['k'], 'history');
    expect(s.board.last['to'], 'p9');
    expect((s.board.last['s'] as List).length, 2);
    s.onBoard!({'k': 'history', 'to': 'autre', 's': [mine.toJson()]});
    r.clearBoard();
    expect(r.strokes, isEmpty);
    expect(s.board.last['k'], 'clear');
    s.onBoard!({'k': 'stroke', 's': 'n importe quoi'});
    expect(r.strokes, isEmpty, reason: 'un message invalide est ignoré');
  });

  test('trait : coordonnées bornées et trait invalide refusé', () {
    final ok = Stroke.fromJson({'id': 'x', 'c': 0xFF2563EB, 'w': 99, 'p': [[2, -1], [0.5, 0.5]]})!;
    expect(ok.points.first, const Offset(1, 0));
    expect(ok.width, 16);
    expect(Stroke.fromJson({'id': 'x', 'p': []}), isNull);
    expect(Stroke.fromJson({'p': [[0, 0]]}), isNull);
    expect(Stroke.fromJson(null), isNull);
  });

  test('départ : transport libéré, canal quitté', () async {
    final t = FakeTransport(), s = FakeSignaling();
    final r = _session(t, s);
    await r.join();
    await r.leave();
    expect(t.log.last, 'leave');
    expect(s.left, isTrue);
  });

  test('messages d’erreur lisibles pour chaque code', () {
    for (final c in ['permission_denied', 'device_not_found', 'device_busy', 'unsupported', 'autoplay_blocked', 'screen_unsupported', 'connect_failed']) {
      expect(roomErrorMessage(c).length, greaterThan(20));
    }
  });

  Future<void> pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
    t.view.physicalSize = const Size(420, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
    await t.pumpAndSettle();
  }

  testWidgets('onglet : non membre → message ; membre → salons, rejoindre, fermer', (t) async {
    await pump(t, const Scaffold(body: StudyRoomsTab(communityId: 'c', isMember: false)));
    expect(find.textContaining('réservés aux membres'), findsOneWidget);
  });

  testWidgets('onglet : membre → salons, rejoindre, fermer', (t) async {
    await pump(t, const Scaffold(body: StudyRoomsTab(communityId: 'c', isMember: true)), overrides: [
      studyRoomsProvider('c').overrideWith((ref) async => [
            {'id': 'r1', 'title': 'Révision réseaux', 'topic': 'TP de jeudi', 'host': 'Paul M.', 'mine': false, 'can_close': true},
          ]),
    ]);
    expect(find.text('Ouvrir un salon vocal'), findsOneWidget);
    expect(find.text('Révision réseaux'), findsOneWidget);
    expect(find.text('Organisé par Paul M.'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('onglet : aucun salon ouvert', (t) async {
    await pump(t, const Scaffold(body: StudyRoomsTab(communityId: 'c', isMember: true)), overrides: [studyRoomsProvider('c').overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.textContaining('Aucun salon ouvert'), findsOneWidget);
  });

  testWidgets('tableau blanc : un geste produit un trait', (t) async {
    final got = <Stroke>[];
    await pump(t, Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: RoomWhiteboard(strokes: const [], onStroke: got.add, onClear: () {}))));
    await t.drag(find.byKey(const Key('room-board')), const Offset(120, 60));
    await t.pump();
    expect(got.length, 1);
    expect(got.first.points.length, greaterThan(1));
    expect(find.text('Tout effacer'), findsOneWidget);
  });
}
