import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/replays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H12 · replays des lives : bibliothèque (recherche, tri, états honnêtes), progression en lecture active (calcul du suiveur), lecteur (accès, modes, chapitres, badge),
/// réactions / clips (service à configurer) et écran « Mes replays » de l'hôte (états d'enregistrement, Edge Function live-record). Faux serveur local, aucun replay d'exemple.
class FakeEngine extends ReplayEngine {
  double pos = 0, dur = 600, spd = 1;
  bool isPlaying = false;
  String? opened;
  final List<double> seeks = [];

  @override
  double get position => pos;
  @override
  double get duration => dur;
  @override
  bool get playing => isPlaying;
  @override
  double get speed => spd;
  @override
  String? get error => null;
  @override
  Future<void> open(String url, {double start = 0}) async {
    opened = url;
    pos = start;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seek(double sec) async {
    seeks.add(sec);
    pos = sec;
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double s) async {
    spd = s;
    notifyListeners();
  }

  @override
  Widget view({bool audioOnly = false}) => const SizedBox(key: Key('fake-video'));
  @override
  Future<void> shutdown() async {}
}

Map<String, dynamic> _card(String id, String title, {bool locked = false, Object? rate = 66.7, Object? avg = 4.5}) => {
      'id': id, 'live_id': 'l-$id', 'title': title, 'description': '', 'host_id': 'h1', 'host': 'Hugo H.', 'duration_sec': 600, 'access': locked ? 'billet_requis' : 'ok',
      'locked': locked, 'message': locked ? 'Ce replay est réservé aux personnes inscrites à l’événement lié (billet).' : '',
      'views': 3, 'viewers': 4, 'completions': 2, 'completion_rate': rate, 'rating_avg': avg, 'rating_count': 2, 'comments_count': 1, 'chapters_count': 2,
    };

Map<String, dynamic> _detail({bool locked = false, String access = 'ok', bool mine = false, List<Map<String, dynamic>>? modes, String modesMessage = 'Un seul enregistrement est disponible : les vues Animateur, Écran, Double et l’Audio seul ne sont pas proposés pour ce replay.', Map<String, dynamic>? meta}) => {
      'available': true, 'id': 'r1', 'live_id': 'l1', 'title': 'Atelier soudure', 'description': 'Les bases', 'host_id': 'h1', 'host': 'Hugo H.', 'duration_sec': 600,
      'access': access, 'locked': locked, 'message': locked ? 'Connexion requise pour regarder ce replay.' : '', 'mine': mine,
      'modes': modes ?? [
        {'kind': 'complete', 'label': 'Vidéo intégrale', 'available': !locked, 'reason': ''},
        {'kind': 'presenter', 'label': 'Vue Animateur', 'available': false, 'reason': 'Piste non enregistrée pour ce replay'},
        {'kind': 'screen', 'label': 'Vue Écran', 'available': false, 'reason': 'Piste non enregistrée pour ce replay'},
        {'kind': 'dual', 'label': 'Vue Double', 'available': false, 'reason': 'Piste non enregistrée pour ce replay'},
        {'kind': 'audio', 'label': 'Audio seul', 'available': false, 'reason': 'Piste non enregistrée pour ce replay'},
      ],
      'modes_message': modesMessage,
      'chapters': locked ? [] : [{'id': 'c1', 'start_sec': 0, 'title': 'Introduction'}, {'id': 'c2', 'start_sec': 120, 'title': 'Soudure à l’arc'}],
      'meta': meta ?? {'certificate_enabled': false, 'share_enabled': true, 'comments_enabled': true, 'clips_allowed': true, 'published': true},
      'transcript_available': false, 'rating_avg': 4.5, 'rating_count': 2, 'my_rating': null, 'comments_count': 1, 'reactions': [],
    };

Map<String, dynamic> _progress({double coverage = 0.4, bool completed = false}) => {
      'duration_sec': 600, 'threshold': 0.98, 'covered_sec': coverage * 600, 'coverage': coverage, 'position_sec': 0, 'watched_sec': coverage * 600, 'real_sec': 0,
      'completed': completed, 'completed_at': null, 'badge': completed, 'certificate_enabled': false, 'certificate': null, 'quiz_defined': false, 'quiz_passed': false,
    };

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  late FakeEngine engine;
  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.functions.clear();
    srv.unknownIsError = false;
    engine = FakeEngine();
    replayEngineFactory = () => engine;
    replaySigner = (bucket, path, seconds) async => 'http://127.0.0.1:1/signed/$bucket/$path';
    replayTickInterval = const Duration(seconds: 5);
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(420, 3600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: w)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('suiveur de progression (lecture active seulement)', () {
    late List<(String, Map<String, dynamic>)> calls;
    late ReplayProgressTracker tr;
    Map<String, dynamic> next = {'ok': true};
    setUp(() {
      calls = [];
      next = {'ok': true};
      tr = ReplayProgressTracker('r1', now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000), call: (fn, p) async {
        calls.add((fn, p));
        return (data: fn == 'replay_progress_report' ? {'accepted': true, 'coverage': 0.1} : (fn == 'replay_playback_stop' ? true : next), error: null);
      });
    });

    test('vidéo ouverte mais en pause : aucun appel, aucun crédit', () async {
      await tr.tick(position: 0, playing: false, speed: 1);
      await tr.tick(position: 0, playing: false, speed: 1);
      expect(calls, isEmpty);
    });

    test('lecture : ouverture de session puis segments contigus, avec horodatage client', () async {
      await tr.tick(position: 0, playing: true, speed: 1);
      final r = await tr.tick(position: 5, playing: true, speed: 1);
      expect(calls.map((c) => c.$1), ['replay_playback_start', 'replay_progress_report']);
      expect(calls[1].$2, {'p_recording': 'r1', 'p_from': 0.0, 'p_to': 5.0, 'p_client_ts': 1700000000000});
      expect(r?['accepted'], true);
      await tr.tick(position: 10.5, playing: true, speed: 2);
      expect(calls[2].$2['p_from'], 5.0);
    });

    test('curseur immobile (tampon, fin de média) : rien n’est rapporté', () async {
      await tr.tick(position: 0, playing: true, speed: 1);
      await tr.tick(position: 0.2, playing: true, speed: 1);
      expect(calls.length, 1);
    });

    test('saut du curseur : nouvelle session à la nouvelle position, jamais de segment pour le saut', () async {
      await tr.tick(position: 0, playing: true, speed: 1);
      await tr.tick(position: 5, playing: true, speed: 1);
      await tr.tick(position: 300, playing: true, speed: 1);
      await tr.tick(position: 100, playing: true, speed: 1);
      expect(calls.map((c) => c.$1), ['replay_playback_start', 'replay_progress_report', 'replay_playback_start', 'replay_playback_start']);
      expect(calls[2].$2['p_position'], 300.0);
      expect(calls[3].$2['p_position'], 100.0);
    });

    test('pause, arrière-plan ou vitesse supérieure à 2x : la session est fermée et plus rien n’est rapporté', () async {
      await tr.tick(position: 0, playing: true, speed: 1);
      await tr.tick(position: 5, playing: true, speed: 3);
      expect(calls.last.$1, 'replay_playback_stop');
      await tr.tick(position: 10, playing: true, speed: 3);
      await tr.tick(position: 12, playing: false, speed: 1);
      expect(calls.where((c) => c.$1 == 'replay_progress_report').length, 0);
      await tr.tick(position: 12, playing: true, speed: 1);
      await tr.close(15);
      expect(calls.last.$1, 'replay_playback_stop');
      expect(calls.last.$2['p_position'], 15.0);
    });

    test('segment refusé par le serveur : session fermée, reprise propre au tour suivant', () async {
      var accept = false;
      final t2 = ReplayProgressTracker('r1', now: () => DateTime.fromMillisecondsSinceEpoch(1), call: (fn, p) async {
        calls.add((fn, p));
        if (fn == 'replay_progress_report') return (data: {'accepted': accept, 'reason': 'vitesse'}, error: null);
        return (data: {'ok': true}, error: null);
      });
      await t2.tick(position: 0, playing: true, speed: 1);
      final r = await t2.tick(position: 5, playing: true, speed: 1);
      expect(r?['accepted'], false);
      expect(t2.isOpen, false);
      await t2.tick(position: 10, playing: true, speed: 1);
      expect(calls.last.$1, 'replay_playback_start');
    });

    test('ouverture refusée (rafale) : pas de session, nouvel essai plus tard', () async {
      next = {'ok': false, 'reason': 'rafale'};
      await tr.tick(position: 0, playing: true, speed: 1);
      expect(tr.isOpen, false);
      next = {'ok': true};
      await tr.tick(position: 1, playing: true, speed: 1);
      expect(tr.isOpen, true);
    });
  });

  group('bibliothèque', () {
    testWidgets('serveur muet : message honnête, aucune carte', (t) async {
      srv.unknownIsError = true;
      await host(t, const ReplaysScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('vue(s) qualifiée(s)'), findsNothing);
      await fin(t);
    });

    testWidgets('aucun replay : état vide, jamais d’exemple', (t) async {
      srv.rpc['replay_library'] = (_) => [];
      await host(t, const ReplaysScreen());
      await attendre(t, find.textContaining('Aucun replay publié'));
      expect(find.textContaining('Aucun replay publié pour le moment'), findsOneWidget);
      await fin(t);
    });

    testWidgets('cartes du serveur : vues qualifiées, complétion, note ; replay payant verrouillé ; tri et recherche rappellent le serveur', (t) async {
      srv.rpc['replay_library'] = (_) => [_card('r1', 'Atelier soudure'), _card('r2', 'Masterclass payante', locked: true, rate: null, avg: null)];
      srv.rpc['replay_search'] = (_) => {'transcription_configured': false, 'message': 'Transcription non configurée : la recherche porte sur les titres et les chapitres.', 'hits': [
        {'recording_id': 'r1', 'title': 'Atelier soudure', 'kind': 'chapter', 'at_sec': 120, 'snippet': 'Soudure à l’arc', 'locked': false},
      ]};
      await host(t, const ReplaysScreen());
      await attendre(t, find.text('Atelier soudure'));
      expect(find.text('3 vue(s) qualifiée(s)'), findsWidgets);
      expect(find.text('Complétion 66,7 %'), findsOneWidget);
      expect(find.text('Complétion non mesurée'), findsOneWidget);
      expect(find.text('Pas encore noté'), findsOneWidget);
      expect(find.textContaining('réservé aux personnes inscrites'), findsOneWidget);
      await t.tap(find.text('Populaires'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_library').map((c) => c.args['p_sort']), containsAllInOrder(['date', 'popularity']));
      await t.enterText(find.byType(TextField), 'soudure');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await settleReal(t, rounds: 8, ms: 60);
      expect(srv.callsOf('replay_library').last.args['p_query'], 'soudure');
      await attendre(t, find.text('Dans le contenu des replays'));
      expect(find.text('Dans le contenu des replays'), findsOneWidget);
      expect(find.textContaining('Transcription non configurée'), findsOneWidget);
      expect(find.textContaining('à 2:00'), findsOneWidget);
      await fin(t);
    });
  });

  group('lecteur', () {
    testWidgets('replay verrouillé : message du serveur, aucune vidéo, aucun appel de lecture', (t) async {
      srv.rpc['replay_detail'] = (_) => _detail(locked: true, access: 'billet_requis').map((k, v) => MapEntry(k, k == 'message' ? 'Ce replay est réservé aux personnes inscrites à l’événement lié (billet).' : v));
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.textContaining('réservé aux personnes inscrites'));
      expect(find.textContaining('réservé aux personnes inscrites'), findsOneWidget);
      expect(find.byTooltip('Lecture'), findsNothing);
      expect(srv.callsOf('replay_play_url'), isEmpty);
      await fin(t);
    });

    testWidgets('replay introuvable : message, rien d’autre', (t) async {
      srv.rpc['replay_detail'] = (_) => {'available': false, 'reason': 'introuvable', 'message': 'Replay introuvable ou inaccessible.'};
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.text('Replay introuvable ou inaccessible.'));
      expect(find.text('Replay introuvable ou inaccessible.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('lecture : ticket serveur puis URL signée, modes honnêtes, progression, chapitres cliquables', (t) async {
      srv.rpc['replay_detail'] = (_) => _detail();
      srv.rpc['replay_progress_get'] = (_) => _progress();
      srv.rpc['replay_comments_list'] = (_) => [
            {'id': 'k1', 'parent_id': null, 'at_sec': 42, 'body': 'Super explication', 'author': 'Vera U.', 'author_id': 'u', 'mine': false, 'by_host': false, 'hidden': false},
            {'id': 'k2', 'parent_id': 'k1', 'at_sec': null, 'body': 'Merci !', 'author': 'Hugo H.', 'author_id': 'h1', 'mine': false, 'by_host': true, 'hidden': false},
          ];
      srv.rpc['replay_play_url'] = (a) => {'bucket': 'live-replays', 'path': 'h1/r1.mp4', 'kind': a['p_kind'], 'expires_in': 900, 'duration_sec': 600};
      srv.rpc['replay_playback_start'] = (a) => {'ok': true, 'position': a['p_position'], 'covered_sec': 240, 'duration_sec': 600, 'coverage': 0.4, 'completed': false};
      srv.rpc['replay_progress_report'] = (a) => {'accepted': true, 'covered_sec': 245, 'coverage': 0.4083, 'position': a['p_to'], 'completed': false, 'newly_completed': false};
      srv.rpc['replay_playback_stop'] = (_) => true;
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.text('Atelier soudure'));
      await attendre(t, find.textContaining('réellement lu'));
      await attendre(t, find.textContaining('Super explication'));
      expect(find.textContaining('Un seul enregistrement est disponible'), findsOneWidget);
      expect(find.text('40 % réellement lu · seuil de complétion 98 %'), findsOneWidget);
      expect(find.textContaining('Replay terminé'), findsNothing);
      expect(find.text('Introduction'), findsOneWidget);
      expect(find.textContaining('Super explication'), findsOneWidget);
      expect(find.textContaining('Hôte'), findsOneWidget);
      // ouverture de la page : aucune session de lecture n'est ouverte
      expect(srv.callsOf('replay_playback_start'), isEmpty);
      expect(srv.callsOf('replay_progress_report'), isEmpty);
      await t.tap(find.byTooltip('Lecture'));
      await settleReal(t, rounds: 8, ms: 60);
      expect(srv.callsOf('replay_play_url').single.args['p_kind'], 'complete');
      expect(engine.opened, 'http://127.0.0.1:1/signed/live-replays/h1/r1.mp4');
      expect(engine.isPlaying, true);
      // la progression n'est envoyée qu'au rythme du lecteur, tant que la lecture est active
      engine.pos = 0;
      await t.pump(replayTickInterval);
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_playback_start').length, 1);
      engine.pos = 5;
      await t.pump(replayTickInterval);
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_progress_report').length, 1);
      expect(srv.callsOf('replay_progress_report').single.args['p_from'], 0);
      expect(srv.callsOf('replay_progress_report').single.args['p_to'], 5);
      // pause : session fermée, plus aucun rapport
      await t.tap(find.byTooltip('Pause'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_playback_stop').length, 1);
      engine.pos = 20;
      await t.pump(replayTickInterval);
      await settleReal(t, rounds: 4, ms: 60);
      expect(srv.callsOf('replay_progress_report').length, 1);
      // chapitre cliquable
      await t.tap(find.text('Soudure à l’arc'));
      await settleReal(t, rounds: 4, ms: 60);
      expect(engine.seeks.last, 120);
      await fin(t);
    });

    testWidgets('replay terminé : complétion, badge et certificat annoncés par le serveur', (t) async {
      srv.rpc['replay_detail'] = (_) => _detail();
      srv.rpc['replay_progress_get'] = (_) => {..._progress(coverage: 1, completed: true), 'certificate': 'BE-SUIVI-AB12CD34'};
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.textContaining('Replay terminé'));
      expect(find.textContaining('Replay terminé'), findsOneWidget);
      expect(find.textContaining('Badge « J’ai suivi » obtenu'), findsOneWidget);
      expect(find.textContaining('BE-SUIVI-AB12CD34'), findsOneWidget);
      expect(find.textContaining('non diplômant'), findsOneWidget);
      await fin(t);
    });

    testWidgets('piste inconnue / ticket refusé : message du serveur, aucune lecture', (t) async {
      srv.rpc['replay_detail'] = (_) => _detail();
      srv.rpc['replay_progress_get'] = (_) => _progress();
      srv.rpc['replay_play_url'] = (_) => throw const FakeRpcError('Ce replay est privé : l’accès se fait sur invitation de l’hôte.');
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.byTooltip('Lecture'));
      await t.tap(find.byTooltip('Lecture'));
      await settleReal(t, rounds: 8, ms: 60);
      expect(find.textContaining('privé'), findsOneWidget);
      expect(engine.opened, isNull);
      await fin(t);
    });

    testWidgets('réaction horodatée, note refusée, clip : service à configurer', (t) async {
      srv.rpc['replay_detail'] = (_) => _detail();
      srv.rpc['replay_progress_get'] = (_) => _progress(coverage: 0.05);
      srv.rpc['replay_react'] = (_) => true;
      srv.rpc['replay_rate'] = (_) => throw const FakeRpcError('Regardez au moins 20 % du replay avant de le noter');
      srv.rpc['replay_clip_request'] = (_) => {'id': 'c', 'status': 'service_a_configurer', 'message': 'Demande enregistrée. Le rendu des clips dépend d’un fournisseur vidéo qui n’est pas encore configuré : aucun fichier n’est créé pour le moment.'};
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.text('Réactions'));
      engine.pos = 42;
      await t.tap(find.text('🔥'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_react').single.args, {'p_recording': 'r1', 'p_at': 42, 'p_emoji': 'fire'});
      expect(find.text('Réaction envoyée à 0:42.'), findsOneWidget);
      await t.tap(find.byTooltip('Noter 4 sur 5'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(find.textContaining('Regardez au moins 20 %'), findsOneWidget);
      expect(find.text('Merci pour votre note.'), findsNothing);
      await t.tap(find.text('Clip 1 min'));
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_clip_request').single.args['p_len'], 60);
      expect(find.textContaining('aucun fichier n’est créé'), findsWidgets);
      await fin(t);
    });

    testWidgets('hôte : réglages du replay et chapitre ajoutés par le serveur', (t) async {
      srv.rpc['replay_detail'] = (_) => _detail(mine: true);
      srv.rpc['replay_progress_get'] = (_) => _progress();
      srv.rpc['replay_meta_set'] = (a) => {'published': true, 'certificate_enabled': a['p_certificate'] ?? false};
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.text('Réglages de l’hôte'));
      await t.tap(find.text('Certificat de suivi').last);
      await settleReal(t, rounds: 6, ms: 60);
      expect(srv.callsOf('replay_meta_set').single.args['p_certificate'], true);
      expect(find.text('Ajouter un chapitre à cet instant'), findsOneWidget);
      await fin(t);
    });
  });

  group('mes replays (hôte)', () {
    Map<String, dynamic> row(String live, String title, String state, {String status = 'ended', String message = '', Object? rec}) => {
          'live_id': live, 'title': title, 'status': status, 'created_at': '2026-11-25T08:00:00Z',
          'replay': {'state': state, 'message': message, 'configured': state != 'not_configured', 'recording_id': rec, 'duration_sec': rec == null ? null : 300},
        };

    testWidgets('états réels de l’enregistrement : non configuré, échec avec motif, prêt', (t) async {
      srv.rpc['my_replays'] = (_) => [
            row('l1', 'Live A', 'not_configured'),
            row('l2', 'Live B', 'failed', message: 'disque plein'),
            row('l3', 'Live C', 'ready', rec: 'r3'),
          ];
      await host(t, const MyReplaysScreen());
      await attendre(t, find.text('Live A'));
      expect(find.textContaining('Enregistrement non configuré sur ce serveur'), findsOneWidget);
      expect(find.text('disque plein'), findsOneWidget);
      expect(find.text('Ouvrir le replay'), findsOneWidget);
      expect(find.text('Démarrer l’enregistrement'), findsNothing);
      await fin(t);
    });

    testWidgets('aucun live : état vide honnête ; panne serveur : erreur, jamais « aucun live »', (t) async {
      srv.rpc['my_replays'] = (_) => [];
      await host(t, const MyReplaysScreen());
      await attendre(t, find.textContaining('pas encore lancé de live'));
      expect(find.textContaining('pas encore lancé de live'), findsOneWidget);
      await fin(t);
      srv.failRpc.add('my_replays');
      await host(t, const MyReplaysScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('pas encore lancé de live'), findsNothing);
      await fin(t);
    });

    testWidgets('démarrage : Edge Function live-record ; service non configuré : message du serveur, pas de faux « en cours »', (t) async {
      srv.rpc['my_replays'] = (_) => [row('l1', 'Live A', 'waiting', status: 'live')];
      srv.functions['live-record'] = (a) => (status: 503, body: {'error': 'not_configured', 'message': 'L’enregistrement des lives n’est pas encore configuré sur ce serveur : aucun replay ne sera créé.'});
      await host(t, const MyReplaysScreen());
      await attendre(t, find.text('Démarrer l’enregistrement'));
      await t.tap(find.text('Démarrer l’enregistrement'));
      await settleReal(t, rounds: 8, ms: 80);
      expect(srv.callsOf('live-record').single.args, {'live_id': 'l1', 'action': 'start'});
      expect(find.textContaining('pas encore configuré'), findsOneWidget);
      expect(find.text('Enregistrement démarré.'), findsNothing);
      await fin(t);
    });

    testWidgets('démarrage accepté par le serveur', (t) async {
      srv.rpc['my_replays'] = (_) => [row('l1', 'Live A', 'waiting', status: 'live')];
      srv.functions['live-record'] = (a) => (status: 200, body: {'ok': true, 'state': 'recording'});
      await host(t, const MyReplaysScreen());
      await attendre(t, find.text('Démarrer l’enregistrement'));
      await t.tap(find.text('Démarrer l’enregistrement'));
      await settleReal(t, rounds: 8, ms: 80);
      expect(find.text('Enregistrement démarré.'), findsOneWidget);
      await fin(t);
    });
  });
}
