import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart' show NotFoundView, RouteGuard;
import 'package:boutik_ecole/figma/live/admin_access.dart';
import 'package:boutik_ecole/figma/live/admin_centre.dart' show kPermissionLabels;
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/top100_admin.dart';
import 'package:boutik_ecole/figma/live/top100_admin_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H12 · Console « Classement et talents » : droits par rôle et par permission (onglets), règles de score, publication avec confirmation explicite puis refus du serveur
/// sans faux succès, correction et archivage avec motif, rattachements, établissements, fraude, contestations, périmètre d'un responsable, serveur muet ou en panne.
/// Faux serveur local, aucune donnée d'exemple hors du test.

Account _compte(String staff, {int role = 1}) => Account(name: 'Compte Test', phone: '690000001', email: 'c@example.com', password: '', role: role, staff: staff, serverId: FakeSupabase.userId);

const _rules = [
  {'code': 'live_hosted', 'label': 'Live animé', 'description': '', 'points': 0, 'cap_per_day': null, 'cap_per_period': null, 'quality_weight': 0, 'active': false, 'version': 1},
  {'code': 'sale_confirmed', 'label': 'Vente confirmée', 'description': '', 'points': 5, 'cap_per_day': 3, 'cap_per_period': null, 'quality_weight': 0.5, 'active': true, 'version': 2},
];

Map<String, dynamic> _settingsUndecided() => {'min_score': null, 'min_activities': null, 'entries_limit': null, 'scopes': <Object?>[], 'min_cohort': 5, 'undecided': ['min_score', 'entries_limit', 'scopes'], 'decided': false};

Map<String, dynamic> _readiness({bool ready = false}) => {
      'period': '2026-11',
      'ready': ready,
      'blockers': ready ? <Object?>[] : ['Réglages non décidés', 'Aucune règle de score active'],
      'students': {'eligibles': 0, 'non_verifies': 3, 'suspendus': 0, 'sans_rattachement_verifie': 2, 'non_consentants': 5, 'fraude': 1, 'sous_le_seuil': 0},
      'min_cohort': 5,
    };

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.failWrites = false;
    srv.unknownIsError = false;
    srv.rpc['my_admin_access'] = (_) => {'role': 'admin', 'is_admin': true, 'teams': <String, Object?>{}};
    srv.rpc['my_ranking_scopes'] = (_) => {'admin': true, 'institutions': <Object?>[], 'department': null};
    srv.rpc['admin_ranking_national_indicators'] = (_) => {
          'period': '2026-11',
          'students': {'total': 12, 'verified': 9, 'affiliated_verified': 7, 'consenting': 4, 'active_this_month': 3, 'avg_score_per_affiliated_student': 41.5},
          'institutions': {'verified': 2, 'proposed': 1, 'with_students': 2, 'programs_active': 5},
          'queue': {'pending_affiliations': 6, 'open_fraud_flags': 1, 'open_disputes': 2},
          'rankings': {'published_periods': 0, 'archived_periods': 0, 'latest': null, 'rules_active': 0, 'settings_decided': false},
          'by_institution': <Object?>[],
        };
    srv.rpc['admin_data_quality'] = (_) => {'pending_affiliations': {'total': 6, 'oldest_days': 9}, 'students_without_program': {'verified_without_affiliation': 2, 'with_pending_request': 1}, 'programs': {}, 'institutions': {}, 'matricule_duplicates': 0, 'profile_affiliation_mismatch': 0};
    srv.rpc['admin_ranking_anomalies'] = (_) => {'flags_open_by_signal': {'burst': 1}, 'flags_open': 1, 'disputes_open': 2, 'repeat_students': <Object?>[], 'published_needing_correction': <Object?>[], 'integrity': <Object?>[]};
    srv.rpc['admin_talent_rules_list'] = (_) => {'rules': _rules, 'settings': <String, Object?>{}};
    srv.rpc['admin_ranking_settings_get'] = (_) => _settingsUndecided();
    srv.rpc['admin_ranking_periods_list'] = (_) => <Object?>[];
    srv.rpc['admin_ranking_readiness'] = (_) => _readiness();
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, {Account? account, bool guard = true}) async {
    t.view.physicalSize = const Size(420, 5000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const screen = Top100AdminScreen();
    final child = guard ? const RouteGuard(name: '/admin/classement', roles: {'admin', 'finance', 'support', 'direction', 'dept'}, perms: kRankingPerms, child: screen) : screen;
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(account ?? _compte('Admin global'))], child: MaterialApp(home: child)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
    await t.pump(const Duration(milliseconds: 500)); // laisse finir l'ouverture d'une fenêtre
  }

  Future<void> calme(WidgetTester t) => settleReal(t, rounds: 5, ms: 80);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Future<void> onglet(WidgetTester t, String label) async {
    await attendre(t, find.text(label));
    await t.tap(find.text(label));
    await calme(t);
  }

  Finder dialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

  Future<void> saisir(WidgetTester t, List<String> values) async {
    final fields = dialog(find.byType(TextField));
    for (var i = 0; i < values.length; i++) {
      await t.enterText(fields.at(i), values[i]);
    }
  }

  Future<void> valider(WidgetTester t, String label) async {
    await t.tap(dialog(find.text(label)));
    await calme(t);
  }

  group('droits par rôle et par permission', () {
    testWidgets('étudiant et client : page neutre, aucune lecture du classement', (t) async {
      await host(t, account: _compte('', role: 1));
      await calme(t);
      expect(find.byType(NotFoundView), findsOneWidget);
      await fin(t);
      await host(t, account: _compte('', role: 0));
      await calme(t);
      expect(find.byType(NotFoundView), findsOneWidget);
      expect(srv.callsOf('admin_ranking_national_indicators'), isEmpty);
      expect(srv.callsOf('admin_talent_rules_list'), isEmpty);
      await fin(t);
    });

    testWidgets('agent Finance sans permission du classement : page neutre', (t) async {
      srv.rpc['my_admin_access'] = (_) => {'role': 'finance', 'is_admin': false, 'teams': {'finance': ['finance.read']}};
      await host(t, account: _compte('Finance'));
      await attendre(t, find.byType(NotFoundView));
      expect(find.byType(NotFoundView), findsOneWidget);
      expect(srv.callsOf('admin_ranking_national_indicators'), isEmpty);
      await fin(t);
    });

    testWidgets('administrateur : les 8 sections', (t) async {
      await host(t);
      for (final l in ['Vue d’ensemble', 'Règles de score', 'Publication', 'Établissements et filières', 'Rattachements', 'Fraude', 'Contestations', 'Mon périmètre']) {
        await attendre(t, find.text(l));
        expect(find.text(l), findsOneWidget, reason: l);
      }
      await fin(t);
    });

    testWidgets('membre de l’équipe ranking avec ranking.rules seul : vue d’ensemble et règles, ni publication ni fraude', (t) async {
      srv.rpc['my_admin_access'] = (_) => {'role': 'support', 'is_admin': false, 'teams': {'ranking': ['ranking.rules']}};
      srv.rpc['my_ranking_scopes'] = (_) => {'admin': false, 'institutions': <Object?>[], 'department': null};
      await host(t, account: _compte('Support'));
      await attendre(t, find.text('Règles de score'));
      expect(find.text('Vue d’ensemble'), findsOneWidget);
      expect(find.text('Règles de score'), findsOneWidget);
      expect(find.text('Publication'), findsNothing);
      expect(find.text('Fraude'), findsNothing);
      expect(find.text('Contestations'), findsNothing);
      expect(find.text('Établissements et filières'), findsNothing);
      await fin(t);
    });

    testWidgets('responsable d’établissement : seulement rattachements et périmètre, jamais les outils d’administration', (t) async {
      srv.rpc['my_admin_access'] = (_) => {'role': 'direction', 'is_admin': false, 'teams': <String, Object?>{}};
      srv.rpc['my_ranking_scopes'] = (_) => {
            'admin': false,
            'institutions': [{'id': 'inst-1', 'name': 'IUT de Douala'}],
            'department': null,
          };
      srv.rpc['student_affiliation_queue'] = (_) => <Object?>[];
      srv.rpc['scope_dashboard'] = (_) => {
            'scope': {'kind': 'institution', 'id': 'inst-1', 'name': 'IUT de Douala'},
            'period': '2026-11',
            'min_cohort': 5,
            'verified_students': 12,
            'active_this_month': 4,
            'ranked_talents': 0,
            'pending_affiliations': 3,
            'avg_score_per_verified_student': 33.5,
            'avg_hidden_reason': null,
            'programs': [{'program_id': 'p1', 'name': 'Génie informatique', 'verified_students': 8}],
            'other_programs_students': 4,
            'institution_ranking': null,
            'note': '',
          };
      await host(t, account: _compte('Direction'));
      await attendre(t, find.text('Mon périmètre'));
      expect(find.text('Rattachements'), findsOneWidget);
      expect(find.text('Règles de score'), findsNothing);
      expect(find.text('Publication'), findsNothing);
      await t.tap(find.text('Mon périmètre'));
      await attendre(t, find.text('Génie informatique'));
      expect(srv.callsOf('scope_dashboard').single.args['p_institution'], 'inst-1');
      expect(find.text('12'), findsOneWidget);
      await fin(t);
    });

    testWidgets('droits illisibles (500) : erreur et « Réessayer », jamais « Accès réservé » à tort', (t) async {
      srv.failRpc.add('my_admin_access');
      await host(t);
      await attendre(t, find.textContaining('droits d’équipe n’ont pas pu être lus'));
      expect(find.textContaining('droits d’équipe n’ont pas pu être lus'), findsOneWidget);
      expect(find.text('Accès réservé'), findsNothing);
      await fin(t);
    });

    test('les 4 permissions du classement ont un libellé et sont sensibles à part de kTeamOrder', () {
      for (final p in kRankingPerms) {
        expect(kPermissionLabels.containsKey(p), isTrue, reason: p);
      }
      expect(kRankingPerms, {'institutions.manage', 'ranking.rules', 'ranking.publish', 'ranking.moderate'});
      expect(top100Tabs(const AdminAccess(role: 'support', teams: {'ranking': {'ranking.publish'}}), null), ['overview', 'publication']);
      expect(top100Tabs(AdminAccess.none, null), isEmpty);
      expect(top100Tabs(AdminAccess.none, {'admin': false, 'institutions': [], 'department': {'id': 'd', 'name': 'Informatique', 'institution_id': 'i'}}), ['affiliations', 'perimeter']);
    });
  });

  group('vue d’ensemble', () {
    testWidgets('indicateurs agrégés du serveur (aucun nom, aucun score individuel)', (t) async {
      await host(t);
      await attendre(t, find.text('Étudiants vérifiés'));
      expect(find.text('Étudiants vérifiés'), findsOneWidget);
      expect(find.text('41.5'), findsOneWidget);
      expect(find.text('Aucun classement publié'), findsOneWidget);
      await fin(t);
    });

    testWidgets('une lecture en panne n’empêche pas les autres et n’affiche aucun 0 à sa place', (t) async {
      srv.failRpc.add('admin_data_quality');
      await host(t);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Étudiants vérifiés'), findsOneWidget);
      expect(find.text('Matricules en double'), findsNothing);
      await fin(t);
    });
  });

  group('règles de score', () {
    testWidgets('liste : brouillon et règle active, réglages « non décidé » dits tels quels', (t) async {
      await host(t);
      await onglet(t, 'Règles de score');
      await attendre(t, find.text('Live animé'));
      expect(find.text('Brouillon'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.textContaining('À décider : min_score, entries_limit, scopes'), findsOneWidget);
      expect(find.text('Non décidé'), findsWidgets);
      await fin(t);
    });

    testWidgets('serveur muet : erreur, pas de règle affichée', (t) async {
      srv.unknownIsError = true;
      srv.rpc.remove('admin_talent_rules_list');
      srv.rpc.remove('admin_ranking_settings_get');
      await host(t);
      await onglet(t, 'Règles de score');
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsWidgets);
      expect(find.text('Live animé'), findsNothing);
      await fin(t);
    });

    testWidgets('règle modifiée : points, plafond, poids, activation et motif partent au serveur', (t) async {
      srv.rpc['admin_talent_rule_set'] = (a) => {'ok': true, 'code': a['p_code'], 'version': 2, 'points': a['p_points'], 'active': a['p_active']};
      await host(t);
      await onglet(t, 'Règles de score');
      await attendre(t, find.text('Live animé'));
      await t.tap(find.text('Modifier').first);
      await calme(t);
      await saisir(t, ['10', '', '50', '0.3', 'Décision du comité du 24 novembre']);
      await t.tap(dialog(find.byType(Switch)));
      await valider(t, 'Enregistrer');
      final c = srv.callsOf('admin_talent_rule_set').single.args;
      expect(c['p_code'], 'live_hosted');
      expect(c['p_points'], 10);
      expect(c['p_cap_day'], isNull);
      expect(c['p_cap_period'], 50);
      expect(c['p_quality_weight'], 0.3);
      expect(c['p_active'], true);
      expect(c['p_reason'], 'Décision du comité du 24 novembre');
      expect(find.text('Règle enregistrée.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('règle active à 0 point ou motif court : refusé avant envoi', (t) async {
      await host(t);
      await onglet(t, 'Règles de score');
      await attendre(t, find.text('Live animé'));
      await t.tap(find.text('Modifier').first);
      await calme(t);
      await t.tap(dialog(find.byType(Switch)));
      await saisir(t, ['0', '', '', '0', 'Un motif suffisant']);
      await valider(t, 'Enregistrer');
      expect(find.text('Une règle active exige au moins 1 point.'), findsOneWidget);
      await saisir(t, ['3', '', '', '0', 'court']);
      await valider(t, 'Enregistrer');
      expect(find.textContaining('au moins 10 caractères'), findsOneWidget);
      expect(srv.callsOf('admin_talent_rule_set'), isEmpty);
      await fin(t);
    });

    testWidgets('2FA exigée par le serveur : son message reste dans la fenêtre, aucune règle enregistrée', (t) async {
      srv.rpc['admin_talent_rule_set'] = (_) => throw const FakeRpcError('Double authentification requise : vérifiez votre second facteur');
      await host(t);
      await onglet(t, 'Règles de score');
      await attendre(t, find.text('Live animé'));
      await t.tap(find.text('Modifier').first);
      await calme(t);
      await saisir(t, ['10', '', '', '0', 'Motif de la modification']);
      await valider(t, 'Enregistrer');
      expect(find.textContaining('Double authentification requise'), findsOneWidget);
      expect(find.text('Règle enregistrée.'), findsNothing);
      await fin(t);
    });

    testWidgets('réglages de publication : valeurs et portées envoyées au serveur', (t) async {
      srv.rpc['admin_ranking_settings_set'] = (_) => {'ok': true};
      await host(t);
      await onglet(t, 'Règles de score');
      await attendre(t, find.text('Modifier les réglages'));
      await t.tap(find.text('Modifier les réglages'));
      await calme(t);
      await saisir(t, ['20', '', '100', 'Arbitrage du 24 novembre']);
      await t.tap(dialog(find.byType(Switch)).first);
      await valider(t, 'Enregistrer');
      final c = srv.callsOf('admin_ranking_settings_set').single.args;
      expect(c['p_min_score'], 20);
      expect(c['p_min_activities'], isNull);
      expect(c['p_entries_limit'], 100);
      expect(c['p_scopes'], ['national']);
      expect(c['p_reason'], 'Arbitrage du 24 novembre');
      await fin(t);
    });
  });

  group('publication, correction, archivage', () {
    testWidgets('disponibilité : blocages et exclusions du serveur, « pas prêt » dit clairement', (t) async {
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('Pas prêt à publier'));
      expect(find.textContaining('Aucune règle de score active'), findsOneWidget);
      expect(find.text('Sans rattachement vérifié'), findsOneWidget);
      expect(find.text('Aucun classement publié'), findsOneWidget);
      await fin(t);
    });

    testWidgets('publier : confirmation explicite d’abord (rien n’est envoyé), puis envoi et résultat du serveur', (t) async {
      srv.rpc['admin_ranking_readiness'] = (_) => _readiness(ready: true);
      srv.rpc['ranking_publish'] = (a) => {'ok': true, 'period': a['p_period'], 'entries': 12, 'groups': 4, 'notified': 12, 'content_hash': 'abc123'};
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('Prêt à publier'));
      await t.tap(find.text('Publier'));
      await calme(t);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('fige les rangs'), findsOneWidget);
      expect(srv.callsOf('ranking_publish'), isEmpty);
      await valider(t, 'Publier');
      expect(srv.callsOf('ranking_publish').single.args['p_period'], matches(RegExp(r'^\d{4}-\d{2}$')));
      expect(find.text('Classement publié'), findsOneWidget);
      expect(find.textContaining('12 entrée(s) dans 4 groupe(s)'), findsOneWidget);
      await fin(t);
    });

    testWidgets('publier : refus du serveur (réglages non décidés) → message dans la fenêtre, aucun succès annoncé', (t) async {
      srv.rpc['ranking_publish'] = (_) => throw const FakeRpcError('Publication impossible : les réglages du classement ne sont pas décidés');
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('Pas prêt à publier'));
      await t.tap(find.text('Publier'));
      await calme(t);
      await valider(t, 'Publier');
      expect(find.textContaining('réglages du classement ne sont pas décidés'), findsOneWidget);
      expect(find.text('Classement publié'), findsNothing);
      await fin(t);
    });

    testWidgets('publier : panne 500 → erreur, aucun succès', (t) async {
      srv.failRpc.add('ranking_publish');
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('Pas prêt à publier'));
      await t.tap(find.text('Publier'));
      await calme(t);
      await valider(t, 'Publier');
      expect(find.text('Classement publié'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      await fin(t);
    });

    testWidgets('mois déjà publié : le refus « une publication ne change plus » est affiché tel quel', (t) async {
      srv.rpc['ranking_publish'] = (_) => throw const FakeRpcError('Ce mois est déjà publié : une publication ne change plus');
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('Pas prêt à publier'));
      await t.tap(find.text('Publier'));
      await calme(t);
      await valider(t, 'Publier');
      expect(find.textContaining('une publication ne change plus'), findsOneWidget);
      await fin(t);
    });

    testWidgets('mois invalide : « Publier » inactif, aucune lecture ni écriture', (t) async {
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('Pas prêt à publier'));
      await t.enterText(find.byType(TextField).first, '2026-13');
      await calme(t);
      expect(find.text('Saisissez le mois au format AAAA-MM.'), findsOneWidget);
      await t.tap(find.text('Publier'));
      await calme(t);
      expect(find.byType(AlertDialog), findsNothing);
      expect(srv.callsOf('ranking_publish'), isEmpty);
      await fin(t);
    });

    testWidgets('périodes publiées : statut, entrées retirées et empreinte du serveur ; correction avec motif', (t) async {
      srv.rpc['admin_ranking_periods_list'] = (_) => [
            {'period': '2026-10', 'status': 'published', 'published_at': '2026-11-02T08:00:00Z', 'entries_count': 12, 'voided': 1, 'corrections': 1, 'last_corrected_at': null, 'archived_at': null, 'content_hash': 'abcdef0123456789abcdef'},
          ];
      srv.rpc['ranking_correct'] = (_) => {'ok': true, 'voided': 1, 'rank_changes': 2};
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('2026-10'));
      expect(find.text('Publié'), findsOneWidget);
      expect(find.textContaining('abcdef0123456789…'), findsOneWidget);
      await t.tap(find.text('Corriger'));
      await calme(t);
      await saisir(t, ['', 'court']);
      await valider(t, 'Corriger');
      expect(find.textContaining('au moins 10 caractères'), findsOneWidget);
      expect(srv.callsOf('ranking_correct'), isEmpty);
      await saisir(t, ['', 'Étudiant suspendu depuis la publication']);
      await valider(t, 'Corriger');
      final c = srv.callsOf('ranking_correct').single.args;
      expect(c['p_period'], '2026-10');
      expect(c.containsKey('p_user'), isFalse);
      expect(c['p_reason'], 'Étudiant suspendu depuis la publication');
      expect(find.textContaining('1 entrée(s) retirée(s)'), findsOneWidget);
      await fin(t);
    });

    testWidgets('archiver : motif obligatoire, refus du serveur affiché sans faux succès', (t) async {
      srv.rpc['admin_ranking_periods_list'] = (_) => [
            {'period': '2026-10', 'status': 'published', 'published_at': '2026-11-02T08:00:00Z', 'entries_count': 12, 'voided': 0, 'corrections': 0, 'content_hash': 'abcdef0123456789abcdef'},
          ];
      srv.rpc['ranking_archive'] = (_) => throw const FakeRpcError('Double authentification requise');
      await host(t);
      await onglet(t, 'Publication');
      await attendre(t, find.text('2026-10'));
      await t.tap(find.text('Archiver'));
      await calme(t);
      await saisir(t, ['Clôture de la période après contrôle']);
      await valider(t, 'Archiver');
      expect(srv.callsOf('ranking_archive').single.args['p_period'], '2026-10');
      expect(find.textContaining('Double authentification requise'), findsOneWidget);
      expect(find.textContaining('archivé.'), findsNothing);
      await fin(t);
    });
  });

  group('rattachements et établissements', () {
    testWidgets('file des rattachements du périmètre : validation envoyée avec la décision', (t) async {
      srv.rpc['student_affiliation_queue'] = (_) => [
            {'id': 'aff-1', 'student': 'Alice N.', 'promotion': '2026', 'program': 'Génie informatique', 'institution': 'IUT de Douala', 'requested_at': '2026-11-20T10:00:00Z'},
          ];
      srv.rpc['student_affiliation_decide'] = (a) => {'ok': true, 'id': a['p_id'], 'status': a['p_decision']};
      await host(t);
      await onglet(t, 'Rattachements');
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Valider'));
      await calme(t);
      expect(srv.callsOf('student_affiliation_decide'), isEmpty);
      await valider(t, 'Valider');
      final c = srv.callsOf('student_affiliation_decide').single.args;
      expect(c['p_id'], 'aff-1');
      expect(c['p_decision'], 'verified');
      expect(find.text('Rattachement validé.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('refus d’un rattachement : motif obligatoire ; décision déjà traitée → message du serveur', (t) async {
      srv.rpc['student_affiliation_queue'] = (_) => [
            {'id': 'aff-1', 'student': 'Alice N.', 'promotion': '2026', 'program': 'Génie informatique', 'institution': 'IUT de Douala', 'requested_at': '2026-11-20T10:00:00Z'},
          ];
      srv.rpc['student_affiliation_decide'] = (_) => throw const FakeRpcError('Cette demande a déjà été traitée');
      await host(t);
      await onglet(t, 'Rattachements');
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Refuser'));
      await calme(t);
      await valider(t, 'Refuser');
      expect(find.textContaining('Renseignez'), findsOneWidget);
      expect(srv.callsOf('student_affiliation_decide'), isEmpty);
      await saisir(t, ['Matricule introuvable dans nos registres']);
      await valider(t, 'Refuser');
      expect(srv.callsOf('student_affiliation_decide').single.args['p_decision'], 'rejected');
      expect(find.textContaining('déjà été traitée'), findsOneWidget);
      await fin(t);
    });

    testWidgets('file vide ou en panne : dit clairement, jamais « 0 demande » trompeur', (t) async {
      srv.failRpc.add('student_affiliation_queue');
      await host(t);
      await onglet(t, 'Rattachements');
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Aucune demande en attente'), findsNothing);
      await fin(t);
    });

    testWidgets('filière créée dans un établissement vérifié : nom, établissement et activation envoyés au serveur', (t) async {
      srv.rpc['institutions_search'] = (_) => [
            {'id': 'inst-1', 'name': 'IUT de Douala', 'city': 'Douala', 'kind': 'institut', 'status': 'verified'},
          ];
      srv.rpc['programs_list'] = (_) => <Object?>[];
      srv.rpc['departments_list'] = (_) => <Object?>[];
      srv.rpc['admin_program_upsert'] = (_) => {'ok': true, 'id': 'prog-1'};
      await host(t);
      await onglet(t, 'Établissements et filières');
      await attendre(t, find.text('IUT de Douala'));
      await t.tap(find.text('IUT de Douala'));
      await attendre(t, find.text('Ajouter une filière'));
      await t.tap(find.text('Ajouter une filière'));
      await attendre(t, find.byType(AlertDialog));
      await saisir(t, ['Génie logiciel']);
      await valider(t, 'Enregistrer');
      final c = srv.callsOf('admin_program_upsert').single.args;
      expect(c['p_id'], isNull);
      expect(c['p_institution'], 'inst-1');
      expect(c['p_name'], 'Génie logiciel');
      expect(c['p_active'], true);
      expect(find.text('Filière enregistrée.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('filière en double : refus du serveur affiché, aucune confirmation', (t) async {
      srv.rpc['institutions_search'] = (_) => [
            {'id': 'inst-1', 'name': 'IUT de Douala', 'status': 'verified'},
          ];
      srv.rpc['programs_list'] = (_) => <Object?>[];
      srv.rpc['departments_list'] = (_) => <Object?>[];
      srv.rpc['admin_program_upsert'] = (_) => throw const FakeRpcError('Cette filière existe déjà dans cet établissement');
      await host(t);
      await onglet(t, 'Établissements et filières');
      await attendre(t, find.text('IUT de Douala'));
      await t.tap(find.text('IUT de Douala'));
      await attendre(t, find.text('Ajouter une filière'));
      await t.tap(find.text('Ajouter une filière'));
      await attendre(t, find.byType(AlertDialog));
      await saisir(t, ['Génie logiciel']);
      await valider(t, 'Enregistrer');
      expect(find.textContaining('existe déjà'), findsOneWidget);
      expect(find.text('Filière enregistrée.'), findsNothing);
      await fin(t);
    });
  });

  group('fraude et contestations', () {
    testWidgets('alertes : signal, détection automatique et activités de l’étudiant ; neutralisation avec motif', (t) async {
      srv.rpc['admin_talent_flags_list'] = (_) => [
            {'id': 'f1', 'event_id': 7, 'user_id': _uid, 'student': 'Alice N.', 'signal': 'burst', 'detail': '12 activités en 10 minutes', 'detected_by': 'auto', 'status': 'open', 'rule': 'sale_confirmed', 'created_at': '2026-11-21T10:00:00Z'},
          ];
      srv.rpc['admin_talent_events_list'] = (_) => {
            'total': 20,
            'events': [
              {'id': 7, 'rule': 'sale_confirmed', 'occurred_at': '2026-11-21T09:00:00Z', 'status': 'confirmed', 'status_reason': null, 'points': 5},
            ],
          };
      srv.rpc['admin_talent_event_neutralize'] = (_) => {'ok': true, 'event': 7, 'points_removed': 5, 'status': 'neutralized'};
      await host(t);
      await onglet(t, 'Fraude');
      await attendre(t, find.text('Alice N.'));
      expect(find.text('Rafale d’activités'), findsOneWidget);
      expect(find.text('Détection automatique'), findsOneWidget);
      await t.tap(find.text('Voir les activités de l’étudiant'));
      await attendre(t, find.text('Neutraliser'));
      await t.tap(find.text('Neutraliser'));
      await calme(t);
      await saisir(t, ['Ventes croisées entre comptes liés']);
      await valider(t, 'Neutraliser');
      final c = srv.callsOf('admin_talent_event_neutralize').single.args;
      expect(c['p_event'], 7);
      expect(c['p_reason'], 'Ventes croisées entre comptes liés');
      // la liste est relue après la neutralisation (invalidation voulue) : on vérifie que la demande vise bien l'étudiant, sans compter les relectures
      expect(srv.callsOf('admin_talent_events_list'), isNotEmpty);
      expect(srv.callsOf('admin_talent_events_list').every((c) => c.args['p_user'] == _uid), isTrue);
      await fin(t);
    });

    testWidgets('neutralisation refusée (2FA) : message du serveur, activité inchangée', (t) async {
      srv.rpc['admin_talent_flags_list'] = (_) => [
            {'id': 'f1', 'event_id': 7, 'user_id': _uid, 'student': 'Alice N.', 'signal': 'burst', 'detected_by': 'auto', 'status': 'open', 'rule': 'sale_confirmed', 'created_at': '2026-11-21T10:00:00Z'},
          ];
      srv.rpc['admin_talent_events_list'] = (_) => {
            'total': 20,
            'events': [
              {'id': 7, 'rule': 'sale_confirmed', 'occurred_at': '2026-11-21T09:00:00Z', 'status': 'confirmed', 'points': 5},
            ],
          };
      srv.rpc['admin_talent_event_neutralize'] = (_) => throw const FakeRpcError('Double authentification requise');
      await host(t);
      await onglet(t, 'Fraude');
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Voir les activités de l’étudiant'));
      await attendre(t, find.text('Neutraliser'));
      await t.tap(find.text('Neutraliser'));
      await calme(t);
      await saisir(t, ['Ventes croisées entre comptes liés']);
      await valider(t, 'Neutraliser');
      expect(find.textContaining('Double authentification requise'), findsOneWidget);
      expect(find.text('Activité neutralisée.'), findsNothing);
      await fin(t);
    });

    testWidgets('alertes : serveur muet → erreur (jamais « aucune alerte »)', (t) async {
      srv.failRpc.add('admin_talent_flags_list');
      await host(t);
      await onglet(t, 'Fraude');
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Aucune alerte'), findsNothing);
      await fin(t);
    });

    testWidgets('contestation acceptée : réponse (10 caractères) envoyée ; rejet déjà décidé → message du serveur', (t) async {
      srv.rpc['admin_talent_disputes_list'] = (_) => [
            {'id': 'd1', 'event_id': 7, 'user_id': _uid, 'student': 'Alice N.', 'rule': 'sale_confirmed', 'event_status': 'neutralized', 'event_reason': 'Rafale', 'message': 'Ces ventes sont réelles, voici les factures', 'status': 'open', 'created_at': '2026-11-22T10:00:00Z'},
          ];
      srv.rpc['admin_talent_dispute_decide'] = (a) => a['p_decision'] == 'accepted' ? {'ok': true, 'status': 'accepted', 'event_restored': true, 'points_added': 5} : throw const FakeRpcError('Cette contestation a déjà été décidée');
      await host(t);
      await onglet(t, 'Contestations');
      await attendre(t, find.text('Alice N.'));
      expect(find.textContaining('Ces ventes sont réelles'), findsOneWidget);
      await t.tap(find.text('Accepter'));
      await calme(t);
      await saisir(t, ['court']);
      await valider(t, 'Accepter');
      expect(find.textContaining('au moins 10 caractères'), findsOneWidget);
      expect(srv.callsOf('admin_talent_dispute_decide'), isEmpty);
      await saisir(t, ['Factures vérifiées : activité rétablie']);
      await valider(t, 'Accepter');
      final c = srv.callsOf('admin_talent_dispute_decide').single.args;
      expect(c['p_id'], 'd1');
      expect(c['p_decision'], 'accepted');
      expect(c['p_note'], 'Factures vérifiées : activité rétablie');
      expect(find.text('Contestation acceptée.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('contestation rejetée par un autre agent entre-temps : refus du serveur affiché', (t) async {
      srv.rpc['admin_talent_disputes_list'] = (_) => [
            {'id': 'd1', 'event_id': 7, 'user_id': _uid, 'student': 'Alice N.', 'rule': 'sale_confirmed', 'event_status': 'neutralized', 'message': 'Ces ventes sont réelles', 'status': 'open', 'created_at': '2026-11-22T10:00:00Z'},
          ];
      srv.rpc['admin_talent_dispute_decide'] = (_) => throw const FakeRpcError('Cette contestation a déjà été décidée');
      await host(t);
      await onglet(t, 'Contestations');
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Rejeter'));
      await calme(t);
      await saisir(t, ['Les factures ne correspondent pas']);
      await valider(t, 'Rejeter');
      expect(find.textContaining('déjà été décidée'), findsOneWidget);
      expect(find.text('Contestation rejetée.'), findsNothing);
      await fin(t);
    });
  });

  group('périmètre', () {
    testWidgets('administration : choisit un établissement ; moyenne masquée sous l’effectif minimal (pas de 0 trompeur)', (t) async {
      srv.rpc['institutions_search'] = (_) => [
            {'id': 'inst-1', 'name': 'IUT de Douala', 'status': 'verified'},
          ];
      srv.rpc['scope_dashboard'] = (_) => {
            'scope': {'kind': 'institution', 'id': 'inst-1', 'name': 'IUT de Douala'},
            'period': '2026-11',
            'min_cohort': 5,
            'verified_students': 3,
            'active_this_month': 1,
            'ranked_talents': 0,
            'pending_affiliations': 0,
            'avg_score_per_verified_student': null,
            'avg_hidden_reason': 'cohorte_insuffisante',
            'programs': <Object?>[],
            'other_programs_students': 3,
            'institution_ranking': null,
            'note': '',
          };
      await host(t);
      await onglet(t, 'Mon périmètre');
      await attendre(t, find.textContaining('Moyenne masquée'));
      expect(find.textContaining('Moyenne masquée'), findsOneWidget);
      expect(srv.callsOf('scope_dashboard').single.args['p_institution'], 'inst-1');
      await fin(t);
    });

    testWidgets('hors périmètre : « Accès refusé » du serveur affiché, aucun chiffre', (t) async {
      srv.rpc['my_admin_access'] = (_) => {'role': 'dept', 'is_admin': false, 'teams': <String, Object?>{}};
      srv.rpc['my_ranking_scopes'] = (_) => {'admin': false, 'institutions': <Object?>[], 'department': {'id': 'dep-1', 'name': 'Informatique', 'institution_id': 'inst-1'}};
      srv.rpc['student_affiliation_queue'] = (_) => <Object?>[];
      srv.rpc['scope_dashboard'] = (_) => throw const FakeRpcError('Accès refusé : hors de votre périmètre');
      await host(t, account: _compte('Resp. département'));
      await onglet(t, 'Mon périmètre');
      await attendre(t, find.textContaining('hors de votre périmètre'));
      expect(find.textContaining('hors de votre périmètre'), findsOneWidget);
      expect(srv.callsOf('scope_dashboard').single.args['p_department'], 'dep-1');
      expect(find.text('Étudiants vérifiés'), findsNothing);
      await fin(t);
    });
  });
}

const _uid = '44444444-4444-4444-8444-444444444444';
