import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/evenements_gestion.dart';
import 'package:boutik_ecole/figma/live/ranking_h13.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · classement : page publique « Comment est calculé le classement » (lue sans compte), cohérence du score de l'étudiant (lecture seule) et pointage aux événements
/// (organisateur : code et liste ; étudiant : saisie du code). Faux serveur local : serveur muet / refus (400) / panne (500) = message honnête, jamais de confirmation ni de zéro.
String _textes(WidgetTester t) => [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? ''].join('\n');

Map<String, dynamic> _explain({bool published = true, int fraud = 3, bool decided = true}) => {
      'published': published,
      'period': '2026-10',
      'status': published ? 'published' : null,
      'published_at': published ? '2026-11-01T08:00:00Z' : null,
      'scope': 'national',
      'rules': [
        {'code': 'sale_confirmed', 'label': 'Vente confirmée', 'description': 'Une vente livrée', 'points': 10, 'cap_per_day': 30, 'cap_per_period': null, 'quality_weight': 0.5},
      ],
      'settings': decided ? {'min_score': 20, 'min_activities': null, 'entries_limit': 100, 'min_cohort': 5} : null,
      'formula': {'points': 'Formule des points du banc', 'caps': 'Plafonds du banc', 'not_counted': 'Les vues ne rapportent rien'},
      'eligibility': ['Compte étudiant vérifié', 'Consentement explicite'],
      'exclusions': [
        {'motif': 'non_verifies', 'label': 'Compte étudiant non vérifié', 'count': 7},
        {'motif': 'controle_integrite', 'label': 'Contrôle d’intégrité en cours ou confirmé', 'count': fraud >= 5 ? fraud : null, 'masked': fraud > 0 && fraud < 5},
      ],
      'eligible_now': 12,
      'entries_in_scope': published ? 12 : 0,
      'note': published ? null : 'Aucun classement n’est publié pour cette période.',
    };

Map<String, dynamic> _coherence({bool consistent = false}) => {
      'applicable': true,
      'consistent': consistent,
      'summary': {'errors': consistent ? 0 : 1, 'warnings': 0, 'infos': consistent ? 0 : 1},
      'issues': consistent
          ? <Object>[]
          : [
              {'code': 'badge_without_completion', 'severity': 'error', 'family': 'badges', 'message': 'Badge de replay sans complétion réelle du replay correspondant.', 'count': 2, 'refs': ['b1', 'b2']},
              {'code': 'skill_without_proof', 'severity': 'info', 'family': 'skills', 'message': 'Compétence déclarée sans justificatif.', 'count': 1, 'refs': ['s1']},
            ],
      'score': {'total': 40, 'ledger_sum': 40},
      'auto_correction': false,
    };

Map<String, dynamic> _presence({bool open = true, bool attended = false, String event = 'e1'}) => {
      'event': event,
      'title': 'Atelier du banc',
      'kind': 'atelier',
      'starts_at': '2026-11-25T09:00:00Z',
      'ends_at': '2026-11-25T11:00:00Z',
      'place': 'Douala',
      'opens_at': open ? '2020-01-01T08:45:00Z' : '2999-01-01T08:45:00Z',
      'closes_at': open ? '2999-01-01T11:15:00Z' : '2999-02-01T11:15:00Z',
      'window_open': open,
      'attended': attended,
      'checked_in_at': attended ? '2026-11-25T09:05:00Z' : null,
    };

Account _compte({int role = 1}) => Account(name: 'Test', phone: '690000001', email: 'test@example.com', password: '', bio: '', serverId: FakeSupabase.userId, role: role);

void main() {
  late FakeSupabase srv;
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
    srv.unknownIsError = false;
    srv.failWrites = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> monter(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(420, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [initialAccountProvider.overrideWithValue(_compte())], child: MaterialApp(home: w)));
    await settleReal(t, rounds: 20);
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 20));
  }

  group('page publique « Comment est calculé le classement »', () {
    testWidgets('classement publié : règles figées, seuils, formule, exclusions agrégées ; compte d’intégrité masqué sous 5', (t) async {
      srv.rpc['ranking_explain'] = (_) => _explain();
      await monter(t, const RankingExplainScreen());
      final txt = _textes(t);
      expect(txt, contains('Classement de octobre 2026'));
      expect(txt, contains('Vente confirmée'));
      expect(txt, contains('Formule des points du banc'));
      expect(txt, contains('moins de 5 (non affiché)'));
      expect(txt, contains('Étudiants éligibles aujourd’hui'));
      expect(srv.callsOf('ranking_explain'), hasLength(1));
      await fin(t);
    });

    testWidgets('rien de publié et seuils non décidés : message honnête, aucun classement ni étudiant inventé', (t) async {
      srv.rpc['ranking_explain'] = (_) => _explain(published: false, decided: false);
      await monter(t, const RankingExplainScreen());
      final txt = _textes(t);
      expect(txt, contains('Aucun classement publié'));
      expect(txt, contains('ne sont pas encore décidés'));
      expect(txt.contains('Classement de '), isFalse);
      await fin(t);
    });

    testWidgets('serveur en panne (500) : erreur lisible avec « Réessayer », jamais un état vide ni 0', (t) async {
      srv.rpc['ranking_explain'] = (_) => _explain();
      srv.failRpc.add('ranking_explain');
      await monter(t, const RankingExplainScreen());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(_textes(t).contains('Classement de'), isFalse);
      await fin(t);
    });
  });

  group('cohérence du score (étudiant)', () {
    testWidgets('écarts listés avec leur gravité ; lecture seule (aucune écriture)', (t) async {
      srv.rpc['my_talent_consistency'] = (_) => _coherence();
      await monter(t, const MyTalentConsistencyScreen());
      final txt = _textes(t);
      expect(txt, contains('Des écarts sont signalés'));
      expect(txt, contains('Badge de replay sans complétion réelle'));
      expect(txt, contains('À corriger'));
      expect(txt, contains('Information'));
      expect(srv.calls.where((c) => c.kind == 'write'), isEmpty);
      await fin(t);
    });

    testWidgets('score cohérent ; refus du serveur (compte non étudiant) : message du serveur', (t) async {
      srv.rpc['my_talent_consistency'] = (_) => _coherence(consistent: true);
      await monter(t, const MyTalentConsistencyScreen());
      expect(_textes(t), contains('Aucun écart à signaler'));
      await fin(t);

      srv.rpc['my_talent_consistency'] = (_) => throw const FakeRpcError('Réservé aux comptes étudiants');
      await monter(t, const MyTalentConsistencyScreen());
      expect(find.text('Réessayer'), findsOneWidget);
      expect(_textes(t).contains('Aucun écart à signaler'), isFalse);
      await fin(t);
    });
  });

  group('pointage aux événements', () {
    Map<String, dynamic> inscription() => {'event': 'e1', 'title': 'Atelier du banc', 'starts_at': '2999-01-01T09:00:00Z', 'place': 'Douala', 'price': 0, 'status': 'confirmed', 'event_status': 'published'};

    testWidgets('étudiant inscrit, fenêtre ouverte : code faux = message et essais restants ; bon code = présence confirmée par le serveur', (t) async {
      srv.rpc['my_event_registrations'] = (_) => [inscription()];
      var present = false;
      srv.rpc['my_event_attendance'] = (_) => [_presence(attended: present)];
      srv.rpc['event_attendance_check_in'] = (a) {
        if ('${a['p_code']}'.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '') != 'ABCD1234') return {'ok': false, 'reason': 'bad_code', 'message': 'Code incorrect', 'remaining_attempts': 4};
        present = true;
        return {'ok': true, 'event': 'e1', 'title': 'Atelier du banc', 'checked_in_at': '2026-11-25T09:05:00Z'};
      };
      await monter(t, const MyEventsScreen());
      expect(find.text('Pointer ma présence'), findsOneWidget);
      await t.tap(find.text('Pointer ma présence'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'ZZZZ0000');
      await t.tap(find.text('Valider'));
      await settleReal(t);
      expect(find.textContaining('Code incorrect · essais restants : 4'), findsOneWidget);
      expect(find.text('Pointer ma présence'), findsOneWidget, reason: 'aucune confirmation sur un code refusé');
      await t.enterText(find.byType(TextField), 'abcd-1234');
      await t.tap(find.text('Valider'));
      await settleReal(t, rounds: 20);
      expect(srv.callsOf('event_attendance_check_in'), hasLength(2));
      expect(srv.callsOf('event_attendance_check_in').last.args['p_code'], 'abcd-1234');
      expect(find.textContaining('Présence enregistrée le'), findsOneWidget);
      expect(find.text('Pointer ma présence'), findsNothing);
      await fin(t);
    });

    testWidgets('refus serveur (hors fenêtre, non inscrit) : message du serveur dans la fenêtre, aucune présence affichée', (t) async {
      srv.rpc['my_event_registrations'] = (_) => [inscription()];
      srv.rpc['my_event_attendance'] = (_) => [_presence()];
      srv.rpc['event_attendance_check_in'] = (_) => throw const FakeRpcError('Le pointage n’est possible que pendant l’événement');
      await monter(t, const MyEventsScreen());
      await t.tap(find.text('Pointer ma présence'));
      await settleReal(t);
      await t.enterText(find.byType(TextField), 'ABCD1234');
      await t.tap(find.text('Valider'));
      await settleReal(t);
      expect(find.textContaining('Le pointage n’est possible que pendant l’événement'), findsOneWidget);
      expect(find.textContaining('Présence enregistrée le'), findsNothing);
      await fin(t);
    });

    testWidgets('fenêtre pas encore ouverte : aucun bouton, heure d’ouverture indiquée ; serveur muet : aucun bloc de pointage', (t) async {
      srv.rpc['my_event_registrations'] = (_) => [inscription()];
      srv.rpc['my_event_attendance'] = (_) => [_presence(open: false)];
      await monter(t, const MyEventsScreen());
      expect(find.text('Pointer ma présence'), findsNothing);
      expect(find.textContaining('Le pointage ouvre le'), findsOneWidget);
      await fin(t);

      srv.failRpc.add('my_event_attendance');
      await monter(t, const MyEventsScreen());
      expect(find.text('Pointer ma présence'), findsNothing);
      expect(find.textContaining('Présence enregistrée'), findsNothing);
      await fin(t);
    });

    testWidgets('organisateur : code affiché seulement après la réponse du serveur, renouvellement confirmé, liste des présents', (t) async {
      var version = 1;
      srv.rpc['event_attendance_code_generate'] = (a) {
        if (a['p_renew'] == true) version++;
        return {'event': 'e1', 'code': version == 1 ? 'ABCD1234' : 'WXYZ9876', 'code_display': version == 1 ? 'ABCD-1234' : 'WXYZ-9876', 'version': version, 'opens_at': '2026-11-25T08:45:00Z', 'closes_at': '2026-11-25T11:15:00Z', 'window_open': true};
      };
      srv.rpc['event_attendance_list'] = (_) => {
            'event': {'id': 'e1', 'title': 'Atelier du banc'},
            'window_open': true,
            'registered': 5,
            'present': 1,
            'items': [
              {'user_id': 'u1', 'name': 'Awa N.', 'checked_in_at': '2026-11-25T09:05:00Z', 'status': 'confirmed'},
              {'user_id': 'u2', 'name': 'Paul K.', 'checked_in_at': '2026-11-25T09:06:00Z', 'status': 'cancelled', 'cancel_reason': 'Inscription annulée'},
            ],
          };
      await monter(t, const Scaffold(body: SizedBox.expand(child: EventAttendanceSheet(event: {'id': 'e1', 'title': 'Atelier du banc'}))));
      expect(find.textContaining('ABCD-1234'), findsNothing);
      expect(find.textContaining('Awa N.'), findsOneWidget);
      expect(find.textContaining('Paul K.'), findsOneWidget);
      await t.tap(find.text('Afficher le code'));
      await settleReal(t, rounds: 20);
      expect(find.text('ABCD-1234'), findsOneWidget);
      expect(srv.callsOf('event_attendance_code_generate').first.args['p_renew'], false);
      await t.tap(find.text('Renouveler le code'));
      await settleReal(t);
      expect(srv.callsOf('event_attendance_code_generate'), hasLength(1), reason: 'rien n’est renouvelé sans confirmation');
      await t.tap(find.text('Renouveler').last);
      await settleReal(t, rounds: 20);
      expect(find.text('WXYZ-9876'), findsOneWidget);
      expect(srv.callsOf('event_attendance_code_generate').last.args['p_renew'], true);
      await fin(t);
    });

    testWidgets('organisateur : refus du serveur (fenêtre terminée) affiché, aucun code', (t) async {
      srv.rpc['event_attendance_list'] = (_) => {'event': {'id': 'e1', 'title': 'Atelier du banc'}, 'window_open': false, 'registered': 0, 'present': 0, 'items': <Object>[]};
      srv.rpc['event_attendance_code_generate'] = (_) => throw const FakeRpcError('La fenêtre de pointage de cet événement est terminée');
      await monter(t, const Scaffold(body: SizedBox.expand(child: EventAttendanceSheet(event: {'id': 'e1', 'title': 'Atelier du banc'}))));
      await t.tap(find.text('Afficher le code'));
      await settleReal(t, rounds: 20);
      expect(find.textContaining('La fenêtre de pointage de cet événement est terminée'), findsOneWidget);
      expect(find.text('Renouveler le code'), findsNothing, reason: 'aucun code affiché');
      await fin(t);
    });
  });
}
