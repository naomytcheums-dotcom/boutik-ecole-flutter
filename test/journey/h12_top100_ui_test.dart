import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/account_menu.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/top100_data.dart';
import 'package:boutik_ecole/figma/live/top100_public.dart';
import 'package:boutik_ecole/figma/live/top100_student.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H12 · TOP 100 national des talents (lot UI1) : pages publiques lues SANS compte (classements, filtres, établissements, profil, règles, empreinte),
/// états honnêtes (rien de publié, serveur muet, panne 500 : jamais « vide » ni zéro) et espace étudiant (score expliqué, visibilité, rattachement,
/// contestation). Faux serveur local : aucune donnée d'exemple n'existe dans l'application.
const _nothing = 'Aucun classement n\'est publié pour le moment.';

Map<String, dynamic> _item(int rank, String name, {Object? score = 120, String photo = '', List<Map<String, dynamic>>? skills, List<Map<String, dynamic>>? badges, Object? projects = 2, String id = 'u1', bool isNew = false, Object? delta}) => {
      'rank': rank, 'user_id': '$id-$rank', 'name': name, 'photo': photo.isEmpty ? null : photo, 'institution': 'IUT de Douala', 'program': 'Génie informatique', 'department': 'Informatique',
      'promotion': '2026', 'scope': 'national', 'score': score, 'month_points': score == null ? null : 30, 'delta_rank': delta, 'delta_score': null, 'is_new': isNew,
      'skills': skills ?? [{'skill': 'Flutter', 'domain': 'Informatique', 'level': 'avance'}], 'badges': badges ?? [{'code': 'replay_100', 'count': 2}], 'projects': projects,
    };

Map<String, dynamic> _published(List<Map<String, dynamic>> items, {String period = '2026-10'}) => {'published': true, 'period': period, 'status': 'published', 'published_at': '2026-11-01T08:00:00Z', 'scope': 'national', 'items': items, 'total': items.length};

Map<String, dynamic> _profile({String contact = 'login_required', bool full = true}) => {
      'found': true, 'user_id': 'u9', 'name': 'Awa N.', 'photo': null, 'institution': 'IUT de Douala', 'program': 'Génie informatique', 'department': 'Informatique', 'promotion': '2026',
      'affiliation_verified': true, 'shared_sections': full ? ['rank', 'score', 'skills'] : [], 'contact': contact,
      'ranking': full ? [{'scope': 'national', 'scope_ref': null, 'scope_label': 'National', 'rank': 3, 'cohort_size': 40, 'period': '2026-10'}] : null,
      'score': full ? 210 : null,
      'evolution': full ? [{'period': '2026-10', 'rank': 3, 'delta_rank': 2, 'month_points': 30}] : null,
      'skills': full ? [{'domain': 'Informatique', 'skill': 'Flutter', 'level': 'expert', 'years': 2, 'has_proof': true, 'proof_verified': true}] : null,
      'badges': full ? [{'code': 'certificat_verifie', 'count': 1}] : null,
      'projects': full ? [{'id': 'p1', 'title': 'Application de gestion', 'summary': 'Suivi des stocks', 'department': 'Informatique'}] : null,
      'passport': full ? {'headline': 'Développeuse mobile', 'summary': 'Passionnée', 'certificates': [{'code': 'c1', 'title': 'Certificat Flutter', 'issued_at': '2026-09-01'}], 'missions': []} : null,
      'availability': full ? {'kinds': ['internship'], 'available_from': '2027-01-10'} : null,
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
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
    srv.failWrites = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget child, {Account? account}) async {
    t.view.physicalSize = const Size(420, 3600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [if (account != null) initialAccountProvider.overrideWithValue(account)], child: MaterialApp(home: child)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> settle(WidgetTester t) => settleReal(t, rounds: 6, ms: 40);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Future<void> choisir(WidgetTester t, String closedLabel, String option) async {
    await t.tap(find.text(closedLabel));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(option).last);
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
  }

  void referentiel() {
    srv.rpc['ranking_history'] = (_) => [
          {'period': '2026-10', 'status': 'published'},
          {'period': '2026-09', 'status': 'archived'},
        ];
    srv.tables['institutions'] = [
      {'id': 'i1', 'name': 'IUT de Douala'},
    ];
    srv.tables['departments'] = [
      {'id': 'd1', 'name': 'Génie civil'},
    ];
    srv.rpc['programs_list'] = (_) => [
          {'id': 'p1', 'name': 'Génie informatique', 'institution_id': 'i1', 'department_id': 'd1', 'active': true},
        ];
  }

  group('classements publics (visiteur sans compte)', () {
    testWidgets('un visiteur voit le classement publié : rang, nom public, établissement, filière, compétences, badges, projets, score', (t) async {
      srv.rpc['top100_national'] = (_) => _published([_item(1, 'Awa N.'), _item(2, 'Paul M.', score: 90)]);
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Awa N.'));
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Paul M.'), findsOneWidget);
      expect(find.text('IUT de Douala · Génie informatique'), findsNWidgets(2));
      expect(find.text('Flutter'), findsNWidgets(2));
      expect(find.text('replay_100 ×2'), findsNWidgets(2));
      expect(find.text('2 projets'), findsNWidgets(2));
      expect(find.text('120 pts'), findsOneWidget);
      expect(find.textContaining('Classement de octobre 2026'), findsOneWidget);
      expect(srv.callsOf('top100_national').single.args, {'p_limit': 100, 'p_offset': 0});
      await fin(t);
    });

    testWidgets('rien n\'est publié : état honnête avec la note du serveur, aucune ligne', (t) async {
      srv.rpc['top100_national'] = (_) => {'published': false, 'items': [], 'total': 0, 'note': _nothing};
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text(_nothing));
      expect(find.text(_nothing), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
      await fin(t);
    });

    testWidgets('note absente de la réponse : le texte honnête par défaut est affiché', (t) async {
      srv.rpc['top100_national'] = (_) => {'published': false, 'items': [], 'total': 0};
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text(top100NothingPublished));
      expect(find.text(top100NothingPublished), findsOneWidget);
      await fin(t);
    });

    testWidgets('serveur muet (404) : message d\'indisponibilité, jamais « aucun classement publié »', (t) async {
      srv.unknownIsError = true;
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Réessayer'));
      expect(find.textContaining('n’est pas disponible pour le moment'), findsOneWidget);
      expect(find.textContaining('Aucun classement'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) : message d\'erreur et « Réessayer », jamais « vide »', (t) async {
      srv.failRpc.add('top100_national');
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucun classement'), findsNothing);
      expect(find.textContaining('Aucun talent'), findsNothing);
      await fin(t);
    });

    testWidgets('rubriques non partagées : « Score non partagé », ni compétences ni badges ni projets inventés', (t) async {
      srv.rpc['top100_national'] = (_) => _published([
            {..._item(1, 'Awa N.', score: null), 'skills': null, 'badges': null, 'projects': null}
          ]);
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Awa N.'));
      expect(find.text('Score non partagé'), findsOneWidget);
      expect(find.textContaining('projet'), findsNothing);
      expect(find.textContaining('pts'), findsNothing);
      await fin(t);
    });

    testWidgets('progression et nouveauté affichées depuis le serveur', (t) async {
      srv.rpc['top100_national'] = (_) => _published([_item(1, 'Awa N.', delta: 3), _item(2, 'Paul M.', isNew: true)]);
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Awa N.'));
      expect(find.text('▲ 3'), findsOneWidget);
      expect(find.text('Nouveau'), findsOneWidget);
      await fin(t);
    });

    testWidgets('filtres mois, établissement, filière, département, domaine : les bons paramètres partent au serveur', (t) async {
      referentiel();
      srv.rpc['top100_national'] = (_) => _published([_item(1, 'Awa N.')]);
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Awa N.'));
      await choisir(t, 'Dernier mois publié', 'octobre 2026');
      expect(srv.callsOf('top100_national').last.args['p_period'], '2026-10');
      await choisir(t, 'Tous les établissements', 'IUT de Douala');
      expect(srv.callsOf('top100_national').last.args['p_institution'], 'i1');
      await attendre(t, find.text('Toutes les filières'));
      await choisir(t, 'Toutes les filières', 'Génie informatique');
      expect(srv.callsOf('top100_national').last.args['p_program'], 'p1');
      await choisir(t, 'Tous les départements', 'Génie civil');
      expect(srv.callsOf('top100_national').last.args['p_department'], 'd1');
      await t.enterText(find.widgetWithText(TextField, 'Domaine de compétence'), 'Informatique');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await settle(t);
      await t.enterText(find.widgetWithText(TextField, 'Promotion vérifiée'), '2026');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await settle(t);
      final last = srv.callsOf('top100_national').last.args;
      expect(last, {'p_period': '2026-10', 'p_institution': 'i1', 'p_program': 'p1', 'p_department': 'd1', 'p_domain': 'Informatique', 'p_level': '2026', 'p_limit': 100, 'p_offset': 0});
      await fin(t);
    });

    testWidgets('changer d\'établissement remet la filière à zéro (aucun mélange de filtres)', (t) async {
      referentiel();
      srv.tables['institutions'] = [
        {'id': 'i1', 'name': 'IUT de Douala'},
        {'id': 'i2', 'name': 'Université de Ngaoundéré'},
      ];
      srv.rpc['top100_national'] = (_) => _published([_item(1, 'Awa N.')]);
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.text('Awa N.'));
      await choisir(t, 'Tous les établissements', 'IUT de Douala');
      await attendre(t, find.text('Toutes les filières'));
      await choisir(t, 'Toutes les filières', 'Génie informatique');
      expect(srv.callsOf('top100_national').last.args['p_program'], 'p1');
      await choisir(t, 'IUT de Douala', 'Université de Ngaoundéré');
      final a = srv.callsOf('top100_national').last.args;
      expect(a['p_institution'], 'i2');
      expect(a.containsKey('p_program'), isFalse);
      await fin(t);
    });

    testWidgets('par établissement : aucun appel tant qu\'aucun établissement n\'est choisi, puis le bon paramètre', (t) async {
      referentiel();
      srv.rpc['top100_by_institution'] = (_) => _published([_item(1, 'Awa N.')]);
      await host(t, const Top100ListScreen(kind: 'institution'));
      await attendre(t, find.text('Tous les établissements'));
      expect(find.textContaining('Choisissez un établissement'), findsOneWidget);
      expect(srv.callsOf('top100_by_institution'), isEmpty);
      await choisir(t, 'Tous les établissements', 'IUT de Douala');
      await attendre(t, find.text('Awa N.'));
      expect(srv.callsOf('top100_by_institution').last.args, {'p_institution': 'i1', 'p_limit': 100});
      await fin(t);
    });

    testWidgets('par filière : appel seulement avec une filière choisie', (t) async {
      referentiel();
      srv.rpc['top100_by_program'] = (_) => _published([_item(1, 'Awa N.')]);
      await host(t, const Top100ListScreen(kind: 'program'));
      await attendre(t, find.text('Tous les établissements'));
      expect(srv.callsOf('top100_by_program'), isEmpty);
      await choisir(t, 'Tous les établissements', 'IUT de Douala');
      await attendre(t, find.text('Toutes les filières'));
      expect(srv.callsOf('top100_by_program'), isEmpty);
      await choisir(t, 'Toutes les filières', 'Génie informatique');
      await attendre(t, find.text('Awa N.'));
      expect(srv.callsOf('top100_by_program').last.args, {'p_program': 'p1', 'p_limit': 100});
      await fin(t);
    });

    testWidgets('talents en progression et nouveaux talents : fonctions dédiées', (t) async {
      srv.rpc['talents_rising'] = (_) => _published([_item(4, 'Awa N.', delta: 5)]);
      await host(t, const Top100ListScreen(kind: 'rising'));
      await attendre(t, find.text('Awa N.'));
      expect(srv.callsOf('talents_rising').single.args, {'p_limit': 50});
      await fin(t);
      srv.rpc['talents_new'] = (_) => _published([_item(9, 'Paul M.', isNew: true)]);
      await host(t, const Top100ListScreen(kind: 'new'));
      await attendre(t, find.text('Paul M.'));
      expect(srv.callsOf('talents_new').single.args, {'p_limit': 50});
      await fin(t);
    });

    testWidgets('filtres sans résultat : message distinct de « rien de publié »', (t) async {
      srv.rpc['top100_national'] = (_) => _published([]);
      await host(t, const Top100ListScreen(kind: 'national'));
      await attendre(t, find.textContaining('Aucun talent ne correspond'));
      expect(find.textContaining('Aucun talent ne correspond'), findsOneWidget);
      expect(find.text(_nothing), findsNothing);
      await fin(t);
    });
  });

  group('établissements, plus consultés, historique, règles, empreinte', () {
    testWidgets('classement des établissements : indicateurs normalisés par étudiant vérifié', (t) async {
      srv.rpc['ranking_institutions_public'] = (_) => {
            'published': true, 'period': '2026-10', 'status': 'published', 'method': 'Classement par points moyens par étudiant vérifié (jamais par effectif seul).',
            'items': [
              {
                'rank': 1, 'institution_id': 'i1', 'name': 'IUT de Douala', 'short_name': 'IUT', 'city': 'Douala', 'verified_students': 40, 'active_students': 20, 'active_rate': 50.0, 'ranked_talents': 12, 'projects': 15, 'badges': 30,
                'challenges': 8, 'missions': 5, 'avg_score': 88.5, 'avg_month_points': 12.0, 'per_student': {'projects': 0.4, 'badges': 0.8, 'challenges': 0.2, 'missions': 0.1}, 'delta_rank': 1, 'delta_avg_score': 4.5, 'is_new': false,
                'programs': [{'program_id': 'p1', 'name': 'Génie informatique', 'verified_students': 25, 'avg_score': 95}], 'other_programs_students': 3,
              },
            ],
          };
      await host(t, const Top100InstitutionsScreen());
      await attendre(t, find.text('IUT de Douala'));
      expect(find.text('Les établissements les plus performants du Cameroun'), findsOneWidget);
      expect(find.text('88,5'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('20 (50 %)'), findsOneWidget);
      expect(find.textContaining('Génie informatique'), findsOneWidget);
      expect(find.text('3 étudiants'), findsOneWidget);
      await fin(t);
    });

    testWidgets('classement des établissements : rien de publié, puis panne 500', (t) async {
      srv.rpc['ranking_institutions_public'] = (_) => {'published': false, 'items': [], 'note': _nothing};
      await host(t, const Top100InstitutionsScreen());
      await attendre(t, find.text(_nothing));
      expect(find.text(_nothing), findsOneWidget);
      await fin(t);
      srv.failRpc.add('ranking_institutions_public');
      await host(t, const Top100InstitutionsScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text(_nothing), findsNothing);
      await fin(t);
    });

    testWidgets('talents les plus consultés : chiffres agrégés, jamais le nom d\'une entreprise', (t) async {
      srv.rpc['talents_most_viewed_by_companies'] = (_) => {
            'period': '2026-11',
            'items': [
              {'user_id': 'u1', 'name': 'Awa N.', 'photo': null, 'companies': 3, 'views': 7, 'institution': 'IUT de Douala', 'program': 'Génie informatique'},
            ],
          };
      await host(t, const Top100MostViewedScreen());
      await attendre(t, find.text('Awa N.'));
      expect(find.text('3 entreprises'), findsOneWidget);
      expect(find.text('7 vues'), findsOneWidget);
      expect(find.textContaining('jamais nommées'), findsOneWidget);
      await fin(t);
    });

    testWidgets('talents les plus consultés : aucun résultat = message honnête (pas de chiffre inventé)', (t) async {
      srv.rpc['talents_most_viewed_by_companies'] = (_) => {'period': '2026-11', 'items': []};
      await host(t, const Top100MostViewedScreen());
      await attendre(t, find.textContaining('Aucun talent n’a encore été consulté'));
      expect(find.textContaining('entreprise'), findsWidgets);
      expect(find.text('0 vue'), findsNothing);
      await fin(t);
    });

    testWidgets('historique mensuel : publications, empreinte et corrections ; vide = rien de publié', (t) async {
      srv.rpc['ranking_history'] = (_) => [
            {'period': '2026-10', 'status': 'published', 'published_at': '2026-11-01T08:00:00Z', 'entries_count': 48, 'corrections': 1, 'content_hash': 'abcdef0123456789abcdef', 'top': [_item(1, 'Awa N.')]},
          ];
      await host(t, const Top100HistoryScreen());
      await attendre(t, find.text('octobre 2026'));
      expect(find.text('48'), findsOneWidget);
      expect(find.text('abcdef0123456789'), findsOneWidget);
      expect(find.text('Awa N.'), findsOneWidget);
      expect(find.text('Vérifier l’empreinte'), findsOneWidget);
      await fin(t);
      srv.rpc['ranking_history'] = (_) => [];
      await host(t, const Top100HistoryScreen());
      await attendre(t, find.text(top100NothingPublished));
      expect(find.text(top100NothingPublished), findsOneWidget);
      await fin(t);
    });

    testWidgets('règles du score : règles actives et plafonds ; aucune règle active = aucun point annoncé', (t) async {
      srv.rpc['talent_rules_public'] = (_) => [
            {'code': 'sale_confirmed', 'label': 'Vente confirmée', 'description': 'Commande payée', 'points': 10, 'cap_per_day': 50, 'cap_per_period': null, 'quality_weight': 0.5, 'version': 2},
          ];
      await host(t, const Top100RulesScreen());
      await attendre(t, find.text('Vente confirmée'));
      expect(find.text('10'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Aucun'), findsOneWidget);
      await fin(t);
      srv.rpc['talent_rules_public'] = (_) => [];
      await host(t, const Top100RulesScreen());
      await attendre(t, find.textContaining('Aucune règle de score n’est active'));
      expect(find.textContaining('Aucune règle de score n’est active'), findsOneWidget);
      await fin(t);
    });

    testWidgets('vérification d\'empreinte : format refusé sans appel ; intacte ; non concordante ; introuvable ; panne', (t) async {
      await host(t, const Top100VerifyScreen());
      await t.enterText(find.byType(TextField), 'octobre');
      await t.tap(find.text('Vérifier'));
      await settle(t);
      expect(find.textContaining('AAAA-MM'), findsWidgets);
      expect(srv.callsOf('ranking_verify_hash'), isEmpty);
      srv.rpc['ranking_verify_hash'] = (a) => a['p_period'] == '2026-10'
          ? {'found': true, 'period': '2026-10', 'status': 'published', 'content_hash': 'abc123', 'intact': true, 'corrections': 0}
          : (a['p_period'] == '2026-09' ? {'found': true, 'period': '2026-09', 'status': 'archived', 'content_hash': 'def456', 'intact': false, 'corrections': 2} : {'found': false});
      await t.enterText(find.byType(TextField), '2026-10');
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.textContaining('Empreintes concordantes'));
      expect(find.textContaining('Empreintes concordantes'), findsOneWidget);
      expect(srv.callsOf('ranking_verify_hash').single.args, {'p_period': '2026-10'});
      await t.enterText(find.byType(TextField), '2026-09');
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.textContaining('ne correspondent pas'));
      expect(find.textContaining('ne correspondent pas'), findsOneWidget);
      await t.enterText(find.byType(TextField), '2025-01');
      await t.tap(find.text('Vérifier'));
      await attendre(t, find.textContaining('Aucune publication'));
      expect(find.textContaining('Aucune publication n’existe'), findsOneWidget);
      srv.failRpc.add('ranking_verify_hash');
      await t.enterText(find.byType(TextField), '2026-10');
      await t.tap(find.text('Vérifier'));
      await settle(t);
      expect(find.textContaining('Empreintes concordantes'), findsNothing);
      await fin(t);
    });
  });

  group('page publique d\'un talent', () {
    testWidgets('profil complet : rangs, score, évolution, compétences, projets, badges, passeport, disponibilité', (t) async {
      srv.rpc['talent_public_profile'] = (a) => _profile();
      await host(t, const TalentPublicProfileScreen(userId: 'u9'));
      await attendre(t, find.text('Awa N.'));
      expect(srv.callsOf('talent_public_profile').single.args, {'p_user': 'u9'});
      expect(find.text('210 pts'), findsOneWidget);
      expect(find.text('rang 3 sur 40'), findsOneWidget);
      expect(find.text('Évolution mensuelle'), findsOneWidget);
      expect(find.textContaining('Flutter'), findsWidgets);
      expect(find.text('Application de gestion'), findsOneWidget);
      expect(find.text('certificat_verifie'), findsOneWidget);
      expect(find.text('Développeuse mobile'), findsOneWidget);
      expect(find.text('Stage'), findsOneWidget);
      await fin(t);
    });

    testWidgets('sans consentement : nom abrégé et aucune rubrique privée affichée', (t) async {
      srv.rpc['talent_public_profile'] = (a) => _profile(full: false);
      await host(t, const TalentPublicProfileScreen(userId: 'u9'));
      await attendre(t, find.text('Awa N.'));
      expect(find.text('Awa N.'), findsOneWidget);
      for (final titre in ['Rangs', 'Compétences', 'Projets', 'Badges', 'Passeport talent', 'Disponibilité', 'Évolution mensuelle']) {
        expect(find.text(titre), findsNothing, reason: titre);
      }
      expect(find.textContaining('pts'), findsNothing);
      await fin(t);
    });

    testWidgets('profil non public : aucune fuite, simple « profil non public »', (t) async {
      srv.rpc['talent_public_profile'] = (a) => {'found': false};
      await host(t, const TalentPublicProfileScreen(userId: 'u9'));
      await attendre(t, find.textContaining('n’est pas public'));
      expect(find.textContaining('n’est pas public'), findsOneWidget);
      await fin(t);
    });

    testWidgets('visiteur : bouton de connexion pour contacter ; aucune vue enregistrée ; l\'appui invite à se connecter', (t) async {
      srv.rpc['talent_public_profile'] = (a) => _profile();
      await host(t, const TalentPublicProfileScreen(userId: 'u9'));
      await attendre(t, find.text('Se connecter pour contacter'));
      await settle(t);
      expect(srv.callsOf('talent_profile_view_record'), isEmpty);
      expect(find.text('Contacter'), findsNothing);
      await t.tap(find.text('Se connecter pour contacter'));
      await settle(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(srv.callsOf('discovery_contact_request'), isEmpty);
      await fin(t);
    });

    testWidgets('entreprise connectée : la vue est enregistrée une fois, « Contacter » envoie la demande au serveur', (t) async {
      srv.rpc['talent_public_profile'] = (a) => _profile(contact: 'allowed');
      srv.rpc['talent_profile_view_record'] = (a) => {'recorded': true, 'reason': null};
      srv.rpc['discovery_contact_request'] = (a) => {'ok': true, 'id': 'c1', 'kind': 'contact', 'student': 'u9'};
      await host(t, const TalentPublicProfileScreen(userId: 'u9'), account: _compte(role: 2));
      await attendre(t, find.text('Contacter'));
      await settle(t);
      expect(srv.callsOf('talent_profile_view_record').single.args, {'p_user': 'u9'});
      await t.tap(find.text('Contacter'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Bonjour, un stage est ouvert');
      await t.tap(find.text('Envoyer la demande'));
      await settle(t);
      expect(srv.callsOf('discovery_contact_request').single.args, {'p_student': 'u9', 'p_kind': 'contact', 'p_message': 'Bonjour, un stage est ouvert'});
      expect(find.text('Demande envoyée.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('contact refusé par le serveur : message du serveur, aucune confirmation', (t) async {
      srv.rpc['talent_public_profile'] = (a) => _profile(contact: 'allowed');
      srv.rpc['talent_profile_view_record'] = (a) => {'recorded': false, 'reason': 'already_counted_today'};
      srv.rpc['discovery_contact_request'] = (a) => throw const FakeRpcError('Limite de 10 demandes par jour atteinte');
      await host(t, const TalentPublicProfileScreen(userId: 'u9'), account: _compte(role: 2));
      await attendre(t, find.text('Contacter'));
      await t.tap(find.text('Contacter'));
      await settle(t);
      await t.tap(find.text('Envoyer la demande'));
      await settle(t);
      expect(find.textContaining('Limite de 10 demandes'), findsOneWidget);
      expect(find.text('Demande envoyée.'), findsNothing);
      await fin(t);
    });

    testWidgets('contact non autorisé (compte non entreprise) : aucune vue enregistrée, aucun bouton Contacter', (t) async {
      srv.rpc['talent_public_profile'] = (a) => _profile(contact: 'not_allowed');
      await host(t, const TalentPublicProfileScreen(userId: 'u9'), account: _compte());
      await attendre(t, find.textContaining('réservé aux entreprises vérifiées'));
      await settle(t);
      expect(find.text('Contacter'), findsNothing);
      expect(srv.callsOf('talent_profile_view_record'), isEmpty);
      await fin(t);
    });
  });

  group('hub public', () {
    testWidgets('le hub propose toutes les pages ; « Mon score de talent » invite un visiteur à se connecter', (t) async {
      await host(t, const Top100HubScreen());
      for (final titre in ['TOP 100 National', 'TOP 100 par établissement', 'TOP 100 par filière', 'Les établissements les plus performants du Cameroun', 'Talents en progression', 'Nouveaux talents du mois', 'Les plus consultés par les entreprises', 'Historique des classements mensuels', 'Règles du score, en toute transparence', 'Vérifier une publication']) {
        expect(find.text(titre), findsOneWidget, reason: titre);
      }
      await t.tap(find.text('Mon score de talent'));
      await settle(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      await fin(t);
    });

    test('menu du compte : entrée publique pour tous, « Mon score de talent » réservé aux étudiants', () {
      for (final r in ['visitor', 'client', 'student', 'company', 'admin']) {
        expect(accountMenuEntries(r).map((e) => e.$1), contains('TOP 100 national des talents'), reason: r);
      }
      expect(accountMenuEntries('student').map((e) => e.$1), contains('Mon score de talent'));
      for (final r in ['visitor', 'client', 'company', 'dept', 'admin']) {
        expect(accountMenuEntries(r).map((e) => e.$1), isNot(contains('Mon score de talent')), reason: r);
      }
    });
  });

  group('espace étudiant', () {
    Map<String, dynamic> dashboard({Object? rulesActive = 3, Map<String, dynamic>? norm}) => {
          'total': 210, 'period': '2026-11', 'month_points': 30, 'previous_month_points': 20, 'progression': 10, 'activities': {'confirmed': 7, 'cancelled': 1, 'not_counted': 2}, 'rules_active': rulesActive,
          'affiliation': {'status': 'verified', 'program': 'Génie informatique', 'institution': 'IUT de Douala', 'promotion': '2026'},
          'normalization': norm ?? {'affiliated': true, 'min_cohort': 5, 'program': {'cohort_size': 3, 'percentile_total': null, 'percentile_month': null, 'reason': 'cohorte_insuffisante'}, 'institution': {'cohort_size': 40, 'percentile_total': 85, 'percentile_month': 70}, 'national': {'cohort_size': 400, 'percentile_total': 90, 'percentile_month': 80}},
          'rank': null, 'rank_note': 'Aucun classement n\'est publié pour le moment.',
        };

    testWidgets('tableau de bord : score, points du mois, activités, comparaison avec cohorte minimale, rang non publié', (t) async {
      srv.rpc['my_talent_dashboard'] = (_) => dashboard();
      await host(t, const MyTalentScreen(), account: _compte());
      await attendre(t, find.text('210 pts'));
      expect(find.text('7'), findsOneWidget);
      expect(find.textContaining('cohorte insuffisante (3 étudiants, minimum 5)'), findsOneWidget);
      expect(find.textContaining('centile 85 sur 40 étudiants'), findsOneWidget);
      expect(find.text(_nothing), findsOneWidget);
      await fin(t);
    });

    testWidgets('aucune règle active : le tableau de bord le dit au lieu de laisser croire à un zéro mérité', (t) async {
      srv.rpc['my_talent_dashboard'] = (_) => dashboard(rulesActive: 0, norm: {'affiliated': false, 'min_cohort': 5});
      await host(t, const MyTalentScreen(), account: _compte());
      await attendre(t, find.textContaining('Aucune règle de score n’est encore active'));
      expect(find.textContaining('Sans rattachement vérifié'), findsOneWidget);
      await fin(t);
    });

    testWidgets('erreur serveur ou compte non étudiant : message du serveur, jamais un score à 0', (t) async {
      srv.rpc['my_talent_dashboard'] = (_) => throw const FakeRpcError('Réservé aux comptes étudiants');
      await host(t, const MyTalentScreen(), account: _compte(role: 2));
      await attendre(t, find.text('Réessayer'));
      expect(find.textContaining('Réservé aux comptes étudiants'), findsOneWidget);
      expect(find.textContaining('0 pts'), findsNothing);
      await fin(t);
    });

    testWidgets('score expliqué : points par règle, historique avec retrait, activités sans point, non comptées', (t) async {
      srv.rpc['my_talent_score_explain'] = (_) => {
            'total': 90, 'period': '2026-11', 'month_points': 10, 'previous_month_points': 80,
            'by_rule': [{'code': 'sale_confirmed', 'label': 'Vente confirmée', 'active': true, 'points_per_activity': 10, 'cap_per_day': null, 'cap_per_period': 100, 'quality_weight': 0.5, 'activities': 9, 'points': 90}],
            'entries': [
              {'at': '2026-11-03T10:00:00Z', 'rule': 'sale_confirmed', 'label': 'Vente confirmée', 'kind': 'award', 'points': 10, 'balance_after': 100, 'source_kind': 'order', 'reason': null},
              {'at': '2026-11-04T10:00:00Z', 'rule': 'sale_confirmed', 'label': 'Vente confirmée', 'kind': 'reversal', 'points': -10, 'balance_after': 90, 'source_kind': 'order', 'reason': 'Commande remboursée'},
            ],
            'without_points': [{'at': '2026-11-05T10:00:00Z', 'rule': 'review_verified', 'label': 'Avis vérifié', 'cause': 'rule_inactive'}],
            'not_counted': [{'at': '2026-11-06T10:00:00Z', 'rule': 'sale_confirmed', 'label': 'Vente confirmée', 'status': 'neutralized', 'reason': 'Activité neutralisée : vous pouvez contester'}],
            'normalization': {'affiliated': false},
          };
      await host(t, const MyTalentExplainScreen(), account: _compte());
      await attendre(t, find.text('Points par règle'));
      expect(find.text('90 pts'), findsOneWidget);
      expect(find.text('+10 pts'), findsOneWidget);
      expect(find.text('-10 pts'), findsOneWidget);
      expect(find.textContaining('retrait'), findsOneWidget);
      expect(find.text('Règle non active'), findsOneWidget);
      expect(find.textContaining('Neutralisée'), findsOneWidget);
      expect(find.textContaining('vous pouvez contester'), findsOneWidget);
      await fin(t);
    });

    testWidgets('positions : rien de publié (note), puis rangs publiés avec effectif', (t) async {
      srv.rpc['my_ranking_positions'] = (_) => {'published': false, 'positions': [], 'public': false, 'note': _nothing};
      await host(t, const MyRankingPositionsScreen(), account: _compte());
      await attendre(t, find.text(_nothing));
      expect(find.textContaining('n’est pas visible publiquement'), findsOneWidget);
      await fin(t);
      srv.rpc['my_ranking_positions'] = (_) => {
            'published': true, 'period': '2026-10', 'public': true,
            'positions': [{'scope': 'national', 'scope_ref': null, 'rank': 12, 'score': 210, 'month_points': 30, 'delta_rank': 2, 'is_new': false, 'cohort_size': 100}],
          };
      await host(t, const MyRankingPositionsScreen(), account: _compte());
      await attendre(t, find.text('12 sur 100'));
      expect(find.text('▲ 2'), findsOneWidget);
      await fin(t);
    });

    Map<String, dynamic> visibility({bool pub = false}) => {
          'public_ranking': pub, 'show_full_name': false, 'show_photo': false, 'shared_sections': ['rank', 'score'], 'availability_public': false,
          'allowed_sections': ['rank', 'score', 'evolution', 'skills', 'badges', 'projects', 'passport'],
        };

    testWidgets('visibilité : l\'état serveur est chargé, la bascule appelle la RPC avec tous les choix, puis confirme', (t) async {
      srv.rpc['my_top100_visibility_get'] = (_) => visibility();
      srv.rpc['my_top100_visibility_set'] = (a) => {...visibility(pub: a['p_public_ranking'] == true), 'public_ranking': a['p_public_ranking']};
      await host(t, const MyTop100VisibilityScreen(), account: _compte());
      await attendre(t, find.text('Apparaître dans les classements publics'));
      expect(t.widget<Switch>(find.byType(Switch).first).value, isFalse);
      await t.tap(find.byType(Switch).first);
      await t.pump();
      await t.tap(find.text('Enregistrer'));
      await settle(t);
      expect(srv.callsOf('my_top100_visibility_set').single.args, {'p_public_ranking': true, 'p_full_name': false, 'p_photo': false, 'p_sections': ['rank', 'score'], 'p_availability': false});
      expect(find.textContaining('Enregistré : votre profil peut apparaître'), findsOneWidget);
      await fin(t);
    });

    testWidgets('visibilité : écriture refusée ou en panne = aucune confirmation, message d\'échec', (t) async {
      srv.rpc['my_top100_visibility_get'] = (_) => visibility();
      srv.rpc['my_top100_visibility_set'] = (a) => throw const FakeRpcError('Rubrique de partage inconnue');
      await host(t, const MyTop100VisibilityScreen(), account: _compte());
      await attendre(t, find.text('Apparaître dans les classements publics'));
      await t.tap(find.byType(Switch).first);
      await t.pump();
      await t.tap(find.text('Enregistrer'));
      await settle(t);
      expect(find.textContaining('Non enregistré'), findsOneWidget);
      expect(find.textContaining('Enregistré : '), findsNothing);
      await fin(t);
      srv.rpc.remove('my_top100_visibility_set');
      srv.failRpc.add('my_top100_visibility_set');
      await host(t, const MyTop100VisibilityScreen(), account: _compte());
      await attendre(t, find.text('Apparaître dans les classements publics'));
      await t.tap(find.text('Enregistrer'));
      await settle(t);
      expect(find.textContaining('Non enregistré'), findsOneWidget);
      expect(find.textContaining('Enregistré : '), findsNothing);
      await fin(t);
    });

    testWidgets('rattachement : demande envoyée avec la filière et la promotion ; promotion invalide sans appel ; refus du serveur affiché', (t) async {
      referentiel();
      srv.rpc['my_student_affiliation'] = (_) => {'current': null, 'history': []};
      srv.rpc['student_affiliation_request'] = (a) => {'ok': true, 'id': 'a1', 'status': 'pending'};
      await host(t, const MyAffiliationScreen(), account: _compte());
      await attendre(t, find.text('Choisir un établissement'));
      await choisir(t, 'Choisir un établissement', 'IUT de Douala');
      await attendre(t, find.text('Choisir une filière'));
      await choisir(t, 'Choisir une filière', 'Génie informatique');
      await t.enterText(find.widgetWithText(TextField, 'Promotion (ex. 2026)'), '2');
      await t.tap(find.text('Envoyer la demande'));
      await settle(t);
      expect(srv.callsOf('student_affiliation_request'), isEmpty);
      expect(find.textContaining('Écrivez votre promotion'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.enterText(find.widgetWithText(TextField, 'Promotion (ex. 2026)'), '2026');
      await t.tap(find.text('Envoyer la demande'));
      await settle(t);
      expect(srv.callsOf('student_affiliation_request').single.args, {'p_program': 'p1', 'p_promotion': '2026'});
      await attendre(t, find.textContaining('Demande envoyée : elle sera examinée'));
      expect(find.textContaining('Demande envoyée : elle sera examinée'), findsOneWidget);
      await fin(t);
      srv.rpc['student_affiliation_request'] = (a) => throw const FakeRpcError('Une demande est déjà en attente');
      await host(t, const MyAffiliationScreen(), account: _compte());
      await attendre(t, find.text('Choisir un établissement'));
      await choisir(t, 'Choisir un établissement', 'IUT de Douala');
      await attendre(t, find.text('Choisir une filière'));
      await choisir(t, 'Choisir une filière', 'Génie informatique');
      await t.enterText(find.widgetWithText(TextField, 'Promotion (ex. 2026)'), '2026');
      await t.tap(find.text('Envoyer la demande'));
      await settle(t);
      await attendre(t, find.textContaining('Une demande est déjà en attente'));
      expect(find.textContaining('Une demande est déjà en attente'), findsOneWidget);
      expect(find.textContaining('Demande envoyée : elle sera examinée'), findsNothing);
      await fin(t);
    });

    testWidgets('rattachement en attente : état affiché, aucun formulaire de nouvelle demande', (t) async {
      srv.rpc['my_student_affiliation'] = (_) => {
            'current': {'id': 'a1', 'status': 'pending', 'promotion': '2026', 'program_id': 'p1', 'program': 'Génie informatique', 'institution_id': 'i1', 'institution': 'IUT de Douala', 'department_id': null, 'requested_at': '2026-11-01T08:00:00Z', 'decided_at': null, 'decision_note': null},
            'history': [{'action': 'requested', 'at': '2026-11-01T08:00:00Z', 'note': null}],
          };
      await host(t, const MyAffiliationScreen(), account: _compte());
      await attendre(t, find.text('Demande en attente de validation'));
      expect(find.text('Envoyer la demande'), findsNothing);
      expect(find.textContaining('Demande envoyée'), findsOneWidget);
      await fin(t);
    });

    Map<String, dynamic> event(int id, {String status = 'neutralized', bool open = false}) => {'id': id, 'at': '2026-11-03T10:00:00Z', 'rule': 'sale_confirmed', 'label': 'Vente confirmée', 'status': status, 'points': 0, 'reason': 'Activité neutralisée : vous pouvez contester', 'open_dispute': open};

    testWidgets('contestation : message trop court sans appel ; message valide = RPC avec l\'identifiant ; échec serveur = aucune confirmation', (t) async {
      srv.rpc['my_talent_events'] = (_) => [event(42), event(43, open: true)];
      srv.rpc['my_talent_disputes'] = (_) => [
            {'id': 'd1', 'event_id': 43, 'rule': 'sale_confirmed', 'label': 'Vente confirmée', 'message': 'Ce client est un vrai client', 'status': 'rejected', 'created_at': '2026-11-04T10:00:00Z', 'decided_at': '2026-11-05T10:00:00Z', 'resolution': 'Liens avérés entre les comptes'},
          ];
      srv.rpc['talent_score_dispute_open'] = (a) => {'ok': true, 'id': 'd2', 'status': 'open'};
      await host(t, const MyTalentEventsScreen(), account: _compte());
      await attendre(t, find.text('Contester'));
      expect(find.text('Contestation en cours'), findsOneWidget);
      expect(find.textContaining('Réponse : Liens avérés'), findsOneWidget);
      expect(find.textContaining('Rejetée'), findsOneWidget);
      await t.tap(find.text('Contester'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'court');
      await t.tap(find.text('Envoyer la contestation'));
      await settle(t);
      expect(srv.callsOf('talent_score_dispute_open'), isEmpty);
      expect(find.textContaining('10 caractères au moins'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.tap(find.text('Contester'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Cette vente est réelle, voici la preuve de livraison');
      await t.tap(find.text('Envoyer la contestation'));
      await settle(t);
      expect(srv.callsOf('talent_score_dispute_open').single.args, {'p_event': 42, 'p_message': 'Cette vente est réelle, voici la preuve de livraison'});
      await attendre(t, find.text('Contestation envoyée.'));
      expect(find.text('Contestation envoyée.'), findsOneWidget);
      await fin(t);
      srv.rpc['talent_score_dispute_open'] = (a) => throw const FakeRpcError('Vous avez déjà 5 contestations ouvertes');
      await host(t, const MyTalentEventsScreen(), account: _compte());
      await attendre(t, find.text('Contester'));
      await t.tap(find.text('Contester'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Cette vente est réelle, voici la preuve de livraison');
      await t.tap(find.text('Envoyer la contestation'));
      await settle(t);
      await attendre(t, find.textContaining('5 contestations ouvertes'));
      expect(find.textContaining('5 contestations ouvertes'), findsOneWidget);
      expect(find.text('Contestation envoyée.'), findsNothing);
      await fin(t);
    });

    testWidgets('activités : le filtre de statut est transmis au serveur', (t) async {
      srv.rpc['my_talent_events'] = (_) => <Map<String, dynamic>>[];
      await host(t, const MyTalentEventsScreen(), account: _compte());
      await attendre(t, find.text('Aucune activité pour ce filtre.'));
      await t.tap(find.text('Neutralisées'));
      await settle(t);
      expect(srv.callsOf('my_talent_events').last.args, {'p_status': 'neutralized', 'p_limit': 50});
      await fin(t);
    });

    testWidgets('demandes de contact reçues : expéditeur vérifié et type ; liste vide honnête', (t) async {
      srv.rpc['my_talent_contact_requests'] = (_) => [
            {'id': 'c1', 'kind': 'internship_offer', 'message': 'Stage de 3 mois', 'sender': 'Entreprise Test', 'created_at': '2026-11-10T09:00:00Z'},
          ];
      await host(t, const MyTalentContactsScreen(), account: _compte());
      await attendre(t, find.text('Entreprise Test'));
      expect(find.textContaining('Offre de stage'), findsOneWidget);
      expect(find.text('Stage de 3 mois'), findsOneWidget);
      await fin(t);
      srv.rpc['my_talent_contact_requests'] = (_) => [];
      await host(t, const MyTalentContactsScreen(), account: _compte());
      await attendre(t, find.textContaining('Aucune entreprise ne vous a contacté'));
      expect(find.textContaining('Aucune entreprise ne vous a contacté'), findsOneWidget);
      await fin(t);
    });
  });
}
