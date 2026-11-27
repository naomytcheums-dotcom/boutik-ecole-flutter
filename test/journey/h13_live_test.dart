import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/atelier_action.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/mission_proposal_sheet.dart';
import 'package:boutik_ecole/figma/live/replays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · Lives : Action Unique « Postuler » sur un besoin (fiche + formulaire de proposition, refus du serveur sans fausse confirmation)
/// et lecteur de replay : reprise après interruption (position serveur introuvable, coupure en lecture). Faux serveur local, aucune donnée d'exemple.
class _Engine extends ReplayEngine {
  double pos = 0, dur = 600, spd = 1;
  bool isPlaying = false;
  String? err;
  final List<String> opened = [];
  final List<double> starts = [];

  @override
  double get position => pos;
  @override
  double get duration => dur;
  @override
  bool get playing => isPlaying;
  @override
  double get speed => spd;
  @override
  String? get error => err;
  @override
  Future<void> open(String url, {double start = 0}) async {
    err = null;
    opened.add(url);
    starts.add(start);
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
  Future<void> seek(double sec) async => pos = sec;
  @override
  Future<void> setSpeed(double s) async => spd = s;
  @override
  Widget view({bool audioOnly = false}) => const SizedBox(key: Key('fake-video'));
  @override
  Future<void> shutdown() async {}

  void breakNow(String message) {
    err = message;
    isPlaying = false;
    notifyListeners();
  }
}

Map<String, dynamic> _need({String role = 'student', bool open = true, bool own = false, String? mine, int attempts = 0, String? block, int proposals = 2}) => {
      'id': 'm1', 'number': 'B-1', 'title': 'Site vitrine', 'description': 'Un site de cinq pages pour notre atelier.', 'budget_min': 50000, 'budget_max': 80000, 'deadline': '2026-12-31',
      'company': 'Atelier Soleil', 'verified': true, 'status': open ? 'published' : 'draft', 'open': open, 'proposals': proposals, 'own': own, 'role': role,
      'my_status': mine, 'my_attempts': attempts, 'block_reason': block,
    };

Map<String, dynamic> _detail() => {
      'available': true, 'id': 'r1', 'live_id': 'l1', 'title': 'Atelier soudure', 'description': '', 'host_id': 'h1', 'host': 'Hugo H.', 'duration_sec': 600, 'access': 'ok', 'locked': false, 'message': '', 'mine': false,
      'modes': [{'kind': 'complete', 'label': 'Vidéo intégrale', 'available': true, 'reason': ''}], 'modes_message': '', 'chapters': [],
      'meta': {'certificate_enabled': false, 'share_enabled': true, 'comments_enabled': true, 'clips_allowed': true, 'published': true},
      'transcript_available': false, 'rating_avg': null, 'rating_count': 0, 'my_rating': null, 'comments_count': 0, 'reactions': [],
    };

Map<String, dynamic> _progress({double pos = 0}) => {
      'duration_sec': 600, 'threshold': 0.98, 'covered_sec': pos, 'coverage': pos / 600, 'position_sec': pos, 'watched_sec': pos, 'real_sec': 0,
      'completed': false, 'completed_at': null, 'badge': false, 'certificate_enabled': false, 'certificate': null, 'quiz_defined': false, 'quiz_passed': false,
    };

void main() {
  late FakeSupabase srv;
  late _Engine engine;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GAnim.enabled = false;
    GScreen.mockupFrame = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.functions.clear();
    srv.unknownIsError = false;
    engine = _Engine();
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

  group('Action Unique « Postuler » sur un besoin', () {
    test('parcours : opportunité et mission ouvrent chacune leur écran', () {
      expect(liveActionRoute('postuler', 'opportunity'), LiveActionRoute.opportunity);
      expect(liveActionRoute('postuler', 'mission'), LiveActionRoute.mission);
      expect(liveActionRoute('postuler', 'event'), isNull);
      expect(liveActionRoute('postuler', null), isNull);
    });

    test('états de la fiche : seul un étudiant éligible, sur un besoin ouvert, sans proposition en attente, voit le formulaire', () {
      expect(missionProposalState(_need()).form, isTrue);
      expect(missionProposalState(_need(mine: 'rejected', attempts: 1)).form, isTrue, reason: 'nouvel essai après refus');
      expect(missionProposalState(_need(mine: 'rejected', attempts: 3)).form, isFalse);
      expect(missionProposalState(_need(mine: 'submitted', attempts: 1)).form, isFalse);
      expect(missionProposalState(_need(mine: 'accepted', attempts: 1)).note, contains('acceptée'));
      expect(missionProposalState(_need(open: false)).note, contains('ne reçoit plus'));
      expect(missionProposalState(_need(own: true)).note, contains('propre besoin'));
      expect(missionProposalState(_need(role: 'client')).note, contains('étudiants'));
      expect(missionProposalState(_need(block: 'Activez votre capacité vendeur')).note, 'Activez votre capacité vendeur');
    });

    testWidgets('fiche du besoin, formulaire, envoi : appel propose_on_mission, puis fiche à jour', (t) async {
      var sent = false;
      srv.rpc['mission_public_card'] = (_) => sent ? _need(mine: 'submitted', attempts: 1, proposals: 3) : _need();
      srv.rpc['propose_on_mission'] = (_) {
        sent = true;
        return 'p1';
      };
      await host(t, const MissionProposalSheet(missionId: 'm1'));
      await attendre(t, find.text('Site vitrine'));
      expect(find.text('Atelier Soleil'), findsOneWidget);
      expect(find.textContaining('Un site de cinq pages'), findsOneWidget);
      expect(find.byKey(const Key('mission-send')), findsOneWidget);
      await t.tap(find.byKey(const Key('mission-send')));
      await t.pump();
      expect(find.byKey(const Key('mission-proposal-error')), findsOneWidget, reason: 'montant et délai exigés avant tout envoi');
      expect(srv.callsOf('propose_on_mission'), isEmpty);
      await t.enterText(find.byKey(const Key('mission-amount')), '65 000');
      await t.enterText(find.byKey(const Key('mission-days')), '10');
      await t.enterText(find.byKey(const Key('mission-message')), 'Je livre en dix jours.');
      await t.tap(find.byKey(const Key('mission-send')));
      await settleReal(t, rounds: 8, ms: 60);
      final c = srv.callsOf('propose_on_mission').single.args;
      expect([c['p_mission'], c['p_amount'], c['p_delay_days'], c['p_message']], ['m1', 65000, 10, 'Je livre en dix jours.']);
      await attendre(t, find.byKey(const Key('mission-proposal-note')));
      expect(find.textContaining('Votre proposition est envoyée'), findsOneWidget);
      expect(find.byKey(const Key('mission-send')), findsNothing, reason: 'une seule proposition en attente à la fois');
      await fin(t);
    });

    testWidgets('refus du serveur : message du serveur, formulaire conservé, aucune confirmation', (t) async {
      srv.rpc['mission_public_card'] = (_) => _need();
      srv.rpc['propose_on_mission'] = (_) => throw const FakeRpcError('Vous avez déjà fait trois propositions sur ce besoin');
      await host(t, const MissionProposalSheet(missionId: 'm1'));
      await attendre(t, find.byKey(const Key('mission-send')));
      await t.enterText(find.byKey(const Key('mission-amount')), '1000');
      await t.enterText(find.byKey(const Key('mission-days')), '5');
      await t.tap(find.byKey(const Key('mission-send')));
      await settleReal(t, rounds: 8, ms: 60);
      expect(find.textContaining('trois propositions'), findsOneWidget);
      expect(find.byKey(const Key('mission-send')), findsOneWidget);
      expect(find.textContaining('Proposition envoyée'), findsNothing);
      await fin(t);
    });

    testWidgets('compte client, besoin fermé : message honnête, aucun formulaire', (t) async {
      srv.rpc['mission_public_card'] = (_) => _need(role: 'client');
      await host(t, const MissionProposalSheet(missionId: 'm1'));
      await attendre(t, find.byKey(const Key('mission-proposal-note')));
      expect(find.textContaining('Seuls les comptes étudiants'), findsOneWidget);
      expect(find.byKey(const Key('mission-send')), findsNothing);
      await fin(t);
      srv.rpc['mission_public_card'] = (_) => _need(open: false);
      await host(t, const MissionProposalSheet(missionId: 'm2'));
      await attendre(t, find.byKey(const Key('mission-proposal-note')));
      expect(find.textContaining('ne reçoit plus de propositions'), findsOneWidget);
      expect(find.byKey(const Key('mission-send')), findsNothing);
      await fin(t);
    });

    testWidgets('besoin introuvable ou panne : erreur lisible puis nouvel essai qui aboutit', (t) async {
      srv.failRpc.add('mission_public_card');
      await host(t, const MissionProposalSheet(missionId: 'm1'));
      await attendre(t, find.byKey(const Key('mission-card-error')));
      expect(find.byKey(const Key('mission-send')), findsNothing);
      srv.failRpc.clear();
      srv.rpc['mission_public_card'] = (_) => _need();
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.byKey(const Key('mission-send')));
      expect(find.byKey(const Key('mission-send')), findsOneWidget);
      await fin(t);
    });
  });

  group('lecteur : reprise après interruption', () {
    void serveur({Object? progress}) {
      srv.rpc['replay_detail'] = (_) => _detail();
      srv.rpc['replay_comments_list'] = (_) => [];
      if (progress != null) srv.rpc['replay_progress_get'] = (_) => progress;
      srv.rpc['replay_play_url'] = (a) => {'bucket': 'live-replays', 'path': 'h1/r1.mp4', 'kind': a['p_kind'], 'expires_in': 900, 'duration_sec': 600};
      srv.rpc['replay_playback_start'] = (a) => {'ok': true, 'position': a['p_position'], 'covered_sec': 0, 'duration_sec': 600, 'coverage': 0, 'completed': false};
      srv.rpc['replay_playback_stop'] = (_) => true;
    }

    testWidgets('position serveur connue : « Reprendre à » ouvre la lecture à cette position', (t) async {
      serveur(progress: _progress(pos: 245));
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.byKey(const Key('replay-resume-hint')));
      expect(find.text('Vous en étiez à 4:05.'), findsOneWidget);
      await t.tap(find.text('Reprendre à 4:05'));
      await settleReal(t, rounds: 8, ms: 60);
      expect(engine.starts.single, 245);
      await fin(t);
    });

    testWidgets('lecture de la position en panne : message et nouvel essai ; lecture depuis le début annoncée, jamais une fausse reprise', (t) async {
      serveur();
      srv.failRpc.add('replay_progress_get');
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.byKey(const Key('replay-progress-error')));
      expect(find.textContaining('Votre progression n’a pas pu être chargée'), findsOneWidget);
      expect(find.byKey(const Key('replay-resume-hint')), findsNothing);
      await t.tap(find.byTooltip('Lecture'));
      await settleReal(t, rounds: 8, ms: 60);
      expect(engine.starts.single, 0);
      expect(find.textContaining('lecture depuis le début'), findsOneWidget);
      srv.failRpc.clear();
      srv.rpc['replay_progress_get'] = (_) => _progress(pos: 100);
      await t.tap(find.byKey(const Key('replay-progress-retry')));
      await attendre(t, find.textContaining('réellement lu'));
      expect(find.byKey(const Key('replay-progress-error')), findsNothing);
      await fin(t);
    });

    testWidgets('coupure en cours de lecture : message, « Réessayer » rouvre un nouveau lien à la même position', (t) async {
      serveur(progress: _progress());
      await host(t, const ReplayPlayerScreen(id: 'r1'));
      await attendre(t, find.byTooltip('Lecture'));
      await t.tap(find.byTooltip('Lecture'));
      await settleReal(t, rounds: 8, ms: 60);
      expect(engine.opened.length, 1);
      engine.pos = 130;
      engine.breakNow('La lecture a été interrompue (connexion perdue ou lien expiré).');
      await settleReal(t, rounds: 4, ms: 60);
      expect(find.textContaining('La lecture a été interrompue'), findsOneWidget);
      await t.tap(find.byKey(const Key('replay-retry-media')));
      await settleReal(t, rounds: 8, ms: 60);
      expect(engine.opened.length, 2);
      expect(engine.starts.last, 130, reason: 'reprise à la position où la coupure est survenue');
      expect(srv.callsOf('replay_play_url').length, 2, reason: 'nouveau ticket serveur, jamais l’ancien lien');
      expect(find.textContaining('La lecture a été interrompue'), findsNothing);
      await fin(t);
    });
  });
}
