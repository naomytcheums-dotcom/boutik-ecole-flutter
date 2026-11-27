import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_team.dart' show MyCompaniesScreen;
import 'package:boutik_ecole/figma/live/org_contacts.dart';
import 'package:boutik_ecole/figma/live/org_suivi.dart';
import 'package:boutik_ecole/figma/live/org_vivier_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · Organisations : suivi des demandes aux talents (statut, réponse, délai) et réponse du talent, suivi des missions de l'équipe (droits par rôle, avis),
/// export et renommage du vivier, sélecteur « Mes organisations » avec pastilles. Faux serveur local ; erreur dite erreur, jamais de faux succès.
const _org = '44444444-4444-4444-8444-444444444444';
const _org2 = '55555555-5555-4555-8555-555555555555';

Account _compte() => Account(name: 'Compte Test', phone: '690000001', email: 'c@example.com', password: '', role: 2, serverId: FakeSupabase.userId);

Map<String, dynamic> _suivi() => {
      'items': [
        {'id': 'c1', 'student': 's1', 'name': 'Alice N.', 'kind': 'interview', 'message': 'Entretien jeudi 10h', 'created_at': '2026-11-20T08:00:00Z', 'status': 'accepted', 'expires_at': '2026-12-04T08:00:00Z',
          'responded_at': '2026-11-20T11:00:00Z', 'response': 'Disponible jeudi', 'delay_hours': 3.0, 'author': 'Admin E.', 'in_pool': true},
        {'id': 'c2', 'student': 's2', 'name': 'Bob T.', 'kind': 'job_offer', 'message': 'Poste junior', 'created_at': '2026-11-10T08:00:00Z', 'status': 'expired', 'expires_at': '2026-11-24T08:00:00Z', 'response': '', 'author': 'Admin E.', 'in_pool': false},
      ],
      'stats': {'total': 2, 'pending': 0, 'seen': 0, 'accepted': 1, 'declined': 0, 'expired': 1, 'avg_delay_hours': 3.0},
    };

Map<String, dynamic> _mission({bool canDecide = true, bool canPay = true, String status = 'delivered', String jalon = 'submitted'}) => {
      'id': 'm1',
      'title': 'Site web vitrine',
      'status': status,
      'counterpart': 'Alice T.',
      'total': 100000,
      'can_decide': canDecide,
      'can_pay': canPay,
      'milestones': [
        {'position': 1, 'title': 'Maquette', 'amount': 30000, 'status': jalon, 'proof_note': 'Maquette livrée', 'pay_status': 'none', 'proof_files': <Object?>[]},
      ],
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
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 4200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/x', routes: [GoRoute(path: '/x', builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child)))]);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(_compte())], child: MaterialApp.router(routerConfig: router)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> hostPage(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 4200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/x', routes: [GoRoute(path: '/x', builder: (_, _) => child)]);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(_compte())], child: MaterialApp.router(routerConfig: router)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> calme(WidgetTester t) => settleReal(t, rounds: 5, ms: 80);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('demandes aux talents (organisation)', () {
    testWidgets('statut, réponse et délai viennent du serveur ; le filtre est envoyé au serveur', (t) async {
      srv.rpc['pool_contact_requests_get'] = (_) => _suivi();
      await hostPage(t, const OrgContactRequestsScreen());
      await attendre(t, find.text('Alice N.'));
      expect(find.text('Alice N.'), findsOneWidget);
      expect(find.text('Acceptée'), findsOneWidget);
      expect(find.textContaining('Disponible jeudi'), findsOneWidget);
      expect(find.textContaining('en 3 h'), findsOneWidget);
      expect(find.text('Sans réponse (expirée)'), findsOneWidget);
      expect(srv.callsOf('pool_contact_requests_get').first.args.containsKey('p_status'), isFalse);
      await fin(t);
    });

    testWidgets('aucune demande : état vide dit clairement, sans chiffre inventé', (t) async {
      srv.rpc['pool_contact_requests_get'] = (_) => {'items': <Object?>[], 'stats': {'total': 0, 'pending': 0, 'accepted': 0, 'declined': 0, 'expired': 0, 'avg_delay_hours': null}};
      await hostPage(t, const OrgContactRequestsScreen());
      await attendre(t, find.textContaining('Aucune demande envoyée'));
      expect(find.textContaining('Aucune demande envoyée'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      await fin(t);
    });

    testWidgets('refus du serveur (finance, autre organisation) : son message, jamais « 0 demande »', (t) async {
      srv.rpc['pool_contact_requests_get'] = (_) => throw const FakeRpcError('Accès refusé à cette organisation');
      await hostPage(t, const OrgContactRequestsScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucune demande'), findsNothing);
      await fin(t);
    });
  });

  group('réponse du talent', () {
    Map<String, dynamic> demande({bool canRespond = true, String status = 'sent'}) =>
        {'id': 'c1', 'kind': 'interview', 'message': 'Entretien jeudi', 'sender': 'Orange Cameroun', 'created_at': '2026-11-20T08:00:00Z', 'status': status, 'expires_at': '2026-12-04T08:00:00Z', 'can_respond': canRespond, 'response': ''};

    testWidgets('accepter : appel serveur avec la décision et le message, puis liste relue', (t) async {
      var changed = 0;
      srv.rpc['talent_contact_respond'] = (_) => 'accepted';
      await host(t, TalentContactCard(request: demande(), onChanged: () => changed++));
      await calme(t);
      await t.tap(find.text('Accepter'));
      await calme(t);
      await t.enterText(find.byType(TextField).last, 'Avec plaisir');
      await t.tap(find.text('Accepter').last);
      await calme(t);
      final c = srv.callsOf('talent_contact_respond').single.args;
      expect(c['p_decision'], 'accepted');
      expect(c['p_id'], 'c1');
      expect(c['p_message'], 'Avec plaisir');
      expect(changed, 1);
      await fin(t);
    });

    testWidgets('refus du serveur : aucune confirmation de succès', (t) async {
      srv.rpc['talent_contact_respond'] = (_) => throw const FakeRpcError('Cette demande a expiré');
      await host(t, TalentContactCard(request: demande(), onChanged: () {}));
      await calme(t);
      await t.tap(find.text('Décliner'));
      await calme(t);
      await t.tap(find.text('Décliner').last);
      await calme(t);
      expect(find.text('Réponse non enregistrée'), findsOneWidget);
      expect(find.textContaining('Demande déclinée'), findsNothing);
      await fin(t);
    });

    testWidgets('demande expirée ou déjà traitée : aucun bouton de réponse', (t) async {
      await host(t, TalentContactCard(request: demande(canRespond: false, status: 'expired'), onChanged: () {}));
      await calme(t);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Décliner'), findsNothing);
      expect(find.textContaining('a expiré'), findsOneWidget);
      await fin(t);
    });
  });

  group('suivi des missions de l’équipe', () {
    testWidgets('propriétaire ou administrateur : valide un jalon livré (décision envoyée au serveur)', (t) async {
      srv.rpc['org_missions'] = (_) => [_mission(status: 'in_progress')];
      srv.rpc['decide_milestone'] = (_) => 'validated';
      await hostPage(t, const OrgMissionsTrackingScreen());
      await attendre(t, find.text('Site web vitrine'));
      expect(find.text('Livré, à examiner'), findsOneWidget);
      await t.tap(find.text('Valider'));
      await calme(t);
      final c = srv.callsOf('decide_milestone').single.args;
      expect(c['p_validate'], isTrue);
      expect(c['p_position'], 1);
      await fin(t);
    });

    testWidgets('lecteur : consulte sans bouton de décision ni de clôture', (t) async {
      srv.rpc['org_missions'] = (_) => [_mission(canDecide: false, canPay: false)];
      await hostPage(t, const OrgMissionsTrackingScreen());
      await attendre(t, find.text('Site web vitrine'));
      expect(find.text('Valider'), findsNothing);
      expect(find.text('Clôturer la mission'), findsNothing);
      expect(find.textContaining('En attente de la clôture'), findsOneWidget);
      await fin(t);
    });

    testWidgets('finance : déclare un paiement mais ne valide pas', (t) async {
      srv.rpc['org_missions'] = (_) => [_mission(canDecide: false, status: 'in_progress', jalon: 'validated')];
      await hostPage(t, const OrgMissionsTrackingScreen());
      await attendre(t, find.text('Site web vitrine'));
      expect(find.text('Valider'), findsNothing);
      expect(find.text('Déclarer le paiement'), findsOneWidget);
      await fin(t);
    });

    testWidgets('mission clôturée : avis du client enregistré une seule fois', (t) async {
      var saved = false;
      srv.rpc['org_missions'] = (_) => [_mission(status: 'closed', jalon: 'validated')];
      srv.rpc['mission_reviews_get'] = (_) => saved ? [{'direction': 'client_to_provider', 'rating': 4, 'comment': 'Très bien', 'mine': true}] : <Object?>[];
      srv.rpc['mission_review_save'] = (a) {
        saved = true;
        return 'client_to_provider';
      };
      await hostPage(t, const OrgMissionsTrackingScreen());
      await attendre(t, find.text('Publier mon avis'));
      await t.tap(find.byTooltip('4 sur 5'));
      await t.pump();
      await t.tap(find.text('Publier mon avis'));
      await calme(t);
      expect(srv.callsOf('mission_review_save').single.args['p_rating'], 4);
      await attendre(t, find.textContaining('Votre avis'));
      expect(find.text('Publier mon avis'), findsNothing);
      await fin(t);
    });

    testWidgets('aucune mission : le dit ; serveur en panne : erreur et « Réessayer »', (t) async {
      srv.rpc['org_missions'] = (_) => <Object?>[];
      await hostPage(t, const OrgMissionsTrackingScreen());
      await attendre(t, find.textContaining('Aucune mission en cours'));
      expect(find.textContaining('Aucune mission en cours'), findsOneWidget);
      await fin(t);
      srv.failRpc.add('org_missions');
      await hostPage(t, const OrgMissionsTrackingScreen());
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucune mission en cours'), findsNothing);
      await fin(t);
    });
  });

  group('vivier : renommer et exporter', () {
    testWidgets('propriétaire : renomme une liste et exporte en CSV (fichier copié avec BOM, serveur interrogé)', (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      srv.rpc['pool_lists_get'] = (_) => [
            {'id': 'l0', 'name': 'Favoris', 'count': 1},
            {'id': 'l1', 'name': 'Développeurs', 'count': 2},
          ];
      srv.rpc['pool_list_rename'] = (_) => 'Devs web';
      srv.rpc['pool_export'] = (_) => {'filename': 'vivier-talents-20261126.csv', 'count': 2, 'csv': '"Nom";"Filière"\r\n"Alice T.";"Informatique"\r\n'};
      await host(t, const PoolListsManager(canWrite: true));
      await attendre(t, find.text('Développeurs'));
      expect(find.byTooltip('Renommer la liste'), findsOneWidget);
      await t.tap(find.byTooltip('Renommer la liste'));
      await calme(t);
      await t.enterText(find.byType(TextField).last, 'Devs web');
      await t.tap(find.text('Renommer').last);
      await calme(t);
      final r = srv.callsOf('pool_list_rename').single.args;
      expect(r['p_list'], 'l1');
      expect(r['p_name'], 'Devs web');
      await t.tap(find.byTooltip('Exporter cette liste (CSV)').last);
      await calme(t);
      expect(srv.callsOf('pool_export').single.args['p_list'], 'l1');
      expect(copied, isNotNull);
      expect(copied!.startsWith('\uFEFF"Nom"'), isTrue);
      await fin(t);
    });

    testWidgets('lecteur : consulte les listes sans renommer ni exporter', (t) async {
      srv.rpc['pool_lists_get'] = (_) => [
            {'id': 'l1', 'name': 'Développeurs', 'count': 2},
          ];
      await host(t, const PoolListsManager(canWrite: false));
      await attendre(t, find.text('Développeurs'));
      expect(find.byTooltip('Renommer la liste'), findsNothing);
      expect(find.textContaining('Exporter'), findsNothing);
      await fin(t);
    });

    testWidgets('export refusé par le serveur : message d’erreur, aucun fichier ni confirmation', (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      srv.rpc['pool_lists_get'] = (_) => <Object?>[];
      srv.rpc['pool_export'] = (_) => throw const FakeRpcError('Réservé au propriétaire et aux administrateurs de l’entreprise');
      await host(t, const PoolListsManager(canWrite: true));
      await attendre(t, find.text('Exporter tout le vivier (CSV)'));
      await t.tap(find.text('Exporter tout le vivier (CSV)'));
      await calme(t);
      expect(find.text('Export impossible'), findsOneWidget);
      expect(copied, isNull);
      await fin(t);
    });
  });

  group('Mes organisations', () {
    testWidgets('chaque organisation affiche mon rôle et ses pastilles ; une pastille non autorisée (null) n’affiche rien', (t) async {
      srv.rpc['my_organizations'] = (_) => [
            {'owner_id': _org, 'company_name': 'Orange Cameroun', 'role': 'viewer', 'status': 'active', 'verified': true, 'is_own': false, 'can_pool_read': true, 'pending_proposals': 2, 'due_reminders': 0, 'pending_contacts': 1},
            {'owner_id': _org2, 'company_name': 'Xena Corp', 'role': 'finance', 'status': 'active', 'verified': true, 'is_own': false, 'can_pool_read': false, 'pending_proposals': null, 'due_reminders': null, 'pending_contacts': null},
          ];
      await hostPage(t, const MyCompaniesScreen());
      await attendre(t, find.text('Orange Cameroun'));
      expect(find.text('Rôle : Lecteur'), findsOneWidget);
      expect(find.text('Rôle : Finance'), findsOneWidget);
      expect(find.textContaining('2 proposition(s) à examiner'), findsOneWidget);
      expect(find.textContaining('1 demande(s) sans réponse'), findsOneWidget);
      expect(find.textContaining('rappel(s) échu(s)'), findsNothing);
      expect(find.text('Vivier'), findsOneWidget);
      await fin(t);
    });

    testWidgets('invitation en attente : Rejoindre envoie la réponse au serveur', (t) async {
      srv.rpc['my_organizations'] = (_) => [
            {'owner_id': _org, 'company_name': 'Orange Cameroun', 'role': 'admin', 'status': 'invited', 'verified': true, 'is_own': false},
          ];
      srv.rpc['company_member_respond'] = (_) => 'active';
      await hostPage(t, const MyCompaniesScreen());
      await attendre(t, find.text('Rejoindre'));
      await t.tap(find.text('Rejoindre'));
      await calme(t);
      final c = srv.callsOf('company_member_respond').single.args;
      expect(c['p_owner'], _org);
      expect(c['p_accept'], isTrue);
      await fin(t);
    });

    testWidgets('serveur sans my_organizations : repli sur les appartenances, sans pastilles', (t) async {
      srv.unknownIsError = true;
      srv.rpc['my_company_memberships'] = (_) => [
            {'owner_id': _org, 'company_name': 'Orange Cameroun', 'role': 'admin', 'status': 'active', 'verified': true},
          ];
      await hostPage(t, const MyCompaniesScreen());
      await attendre(t, find.text('Orange Cameroun'));
      expect(find.text('Rôle : Administrateur'), findsOneWidget);
      expect(find.textContaining('proposition(s)'), findsNothing);
      await fin(t);
    });
  });
}
