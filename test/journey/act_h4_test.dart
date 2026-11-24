import 'package:boutik_ecole/features/screens.dart' show allScreens;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/account_menu.dart' show accountMenuEntries;
import 'package:boutik_ecole/figma/live/admin_access.dart';
import 'package:boutik_ecole/figma/live/admin_centre.dart';
import 'package:boutik_ecole/figma/live/admin_equipes.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/espace.dart' show rubriqueDe, rubriquesPour;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Lot H4 (centre d'administration et équipes internes) : modèle de permissions, hub, tableaux de bord des équipes, gestion des équipes et comptes suspects,
/// à 390 px de large (une erreur de mise en page fait échouer le test) ; lectures serveur simulées par surcharge des fournisseurs.

Account _staff(String staff) => seedAccounts.firstWhere((a) => a.staff == staff);

const _client = Account(name: 'Cli Ent', phone: '690000000', email: 'client@t.cm', password: 'Boutik2026', role: 0);

AdminAccess _agent(Map<String, Set<String>> teams, {String role = 'support'}) => AdminAccess(role: role, teams: teams);

AdminAccess get _admin => AdminAccess.fromAccount(_staff('Admin global'));

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  group('modèle de permissions', () {
    test('AdminAccess lit la réponse du serveur : équipes, permissions, administrateur', () {
      final a = AdminAccess.fromJson({
        'role': 'support',
        'is_admin': false,
        'teams': {'support': ['support.tickets', 'support.claims'], 'security': ['security.moderation']},
      });
      expect(a.isAdmin, isFalse);
      expect(a.myTeams, ['support', 'security']);
      expect(a.has('support.claims'), isTrue);
      expect(a.has('finance.read'), isFalse);
      expect(a.hasAny({'finance.read', 'security.moderation'}), isTrue);
      expect(a.inTeam('finance'), isFalse);
      expect(AdminAccess.none.myTeams, isEmpty);
      final adm = AdminAccess.fromJson({'role': 'admin', 'is_admin': true, 'teams': {}});
      expect(adm.has('finance.split'), isTrue, reason: 'l’administrateur global a tout');
      expect(adm.inTeam('tech'), isTrue);
      expect(adm.myTeams, kTeamOrder);
    });

    test('hors connexion : droits de base de l’équipe du compte (comme après la migration)', () {
      final f = AdminAccess.fromAccount(_staff('Finance'));
      expect(f.myTeams, ['finance']);
      expect(f.has('finance.payments'), isTrue);
      expect(f.has('finance.split'), isFalse, reason: 'la répartition n’est jamais attribuée par défaut');
      expect(f.has('support.tickets'), isFalse);
      final s = AdminAccess.fromAccount(_staff('Support'));
      expect(s.myTeams, ['support', 'security']);
      expect(s.has('support.refunds'), isTrue);
      expect(s.has('finance.read'), isFalse, reason: 'le support ne fait pas d’opération financière');
      expect(s.has('tech.config'), isFalse);
      expect(AdminAccess.fromAccount(_client).myTeams, isEmpty);
      expect(AdminAccess.fromAccount(null).isAdmin, isFalse);
      expect(AdminAccess.fromAccount(_staff('Admin global')).isAdmin, isTrue);
    });

    test('un écran réservé par permission : seul l’agent concerné l’ouvre ; administrateur et autres rôles non concernés', () {
      final finRead = _agent({'finance': {'finance.read'}}, role: 'finance');
      final sup = _agent({'support': {'support.tickets', 'support.claims'}});
      final fin = _staff('Finance'), support = _staff('Support');
      expect(screenAllowedByAccess(fin, '139', finRead), isTrue);
      expect(screenAllowedByAccess(fin, '140', finRead), isFalse, reason: 'valider les paiements exige finance.payments');
      expect(screenAllowedByAccess(support, '139', sup), isFalse, reason: 'un agent support n’ouvre pas les écrans financiers');
      expect(screenAllowedByAccess(support, '133', sup), isTrue);
      expect(screenAllowedByAccess(support, '138', sup), isFalse, reason: 'configuration : équipe Technique');
      expect(screenAllowedByAccess(support, '146_1', sup), isFalse, reason: 'les variantes à tiret bas sont reconnues');
      expect(screenAllowedByAccess(_staff('Admin global'), '140', AdminAccess.none), isTrue);
      expect(screenAllowedByAccess(_staff('Direction'), '139', AdminAccess.none), isTrue, reason: 'la direction garde sa lecture consolidée');
      expect(screenAllowedByAccess(_staff('Resp. département'), '131', AdminAccess.none), isTrue);
      expect(screenAllowedByAccess(fin, '140', null), isTrue, reason: 'lecture des droits en cours : le serveur reste l’autorité');
      expect(screenAllowedByAccess(_client, '140', AdminAccess.none), isTrue);
    });

    test('cohérence : chaque permission citée existe au catalogue, chaque écran cité existe au registre', () {
      expect(kPermissionLabels.length, 21); // 20 permissions initiales + tech.assessments (validation humaine des évaluations, migration 20261125096000)
      final ids = {for (final s in allScreens) s.id.replaceAll('_', '-')};
      for (final e in kScreenPermissions.entries) {
        expect(ids.contains(e.key), isTrue, reason: 'écran ${e.key}');
        for (final p in e.value) {
          expect(kPermissionLabels.containsKey(p), isTrue, reason: '${e.key} : $p');
        }
      }
      for (final team in kTeamOrder) {
        for (final t in kTeamTools[team]!) {
          expect(t.perms, isNotEmpty);
          for (final p in t.perms) {
            expect(kPermissionLabels.containsKey(p), isTrue, reason: '${t.label} : $p');
            expect(p.startsWith('$team.') || {'support.refunds', 'finance.split', 'tech.maintenance', 'tech.config', 'support.orders'}.contains(p), isTrue, reason: '${t.label} : $p');
          }
          if (t.screen != null) expect(ids.contains(t.screen), isTrue, reason: '${t.label} -> ${t.screen}');
        }
        for (final p in kTeamDefaults[team]!) {
          expect(p.startsWith('$team.'), isTrue);
          expect(kPermissionLabels.containsKey(p), isTrue);
        }
      }
      for (final t in kGlobalTools) {
        if (t.screen != null) expect(ids.contains(t.screen), isTrue, reason: t.label);
      }
    });

    test('un agent d’une équipe n’a aucun outil des autres : les droits de base ne se recoupent pas', () {
      final tools = {for (final t in kTeamOrder) t: {for (final x in kTeamTools[t]!) if (x.perms.any((p) => kTeamDefaults[t]!.contains(p))) x.label}};
      final finance = AdminAccess(role: 'finance', teams: {'finance': {...kTeamDefaults['finance']!}});
      for (final t in kTeamOrder.where((x) => x != 'finance')) {
        for (final tool in kTeamTools[t]!) {
          if (tool.perms.every((p) => p.startsWith('finance.'))) continue;
          expect(finance.hasAny(tool.perms), isFalse, reason: 'un agent Finance voit « ${tool.label} » de l’équipe $t');
        }
      }
      expect(tools['finance'], isNotEmpty);
    });

    test('écrans 300 à 306 : agents (finance, support) et administrateur ; la gestion des équipes (305) est réservée à l’administrateur', () {
      for (final id in ['300', '301', '302', '303', '304', '306']) {
        expect(canOpen(_staff('Finance'), id), isTrue, reason: id);
        expect(canOpen(_staff('Support'), id), isTrue, reason: id);
        expect(canOpen(_staff('Admin global'), id), isTrue, reason: id);
        for (final other in [_client, demoAccount, _staff('Resp. département'), _staff('Direction'), null]) {
          expect(canOpen(other, id), isFalse, reason: '$id pour ${other?.staff}');
        }
      }
      expect(allowedRoles('305'), {'admin'});
      expect(canOpen(_staff('Support'), '305'), isFalse);
      expect(canOpen(_staff('Support'), '128'), isFalse, reason: 'comptes, rôles et permissions : administrateur seul');
      expect(canOpen(_staff('Support'), '180'), isFalse);
      expect(canOpen(_staff('Finance'), '264'), isTrue, reason: 'outils techniques ouverts aux agents, filtrés par permission');
      expect(canOpen(_staff('Direction'), '138'), isFalse, reason: 'la direction n’a aucun pouvoir technique');
    });

    test('rubrique « Centre d’administration » et menu du compte', () {
      for (final id in ['300', '301', '302', '303', '304', '305', '306']) {
        expect(allScreens.any((s) => s.id == id), isTrue, reason: id);
        expect(rubriqueDe(id).code, 'AC', reason: id);
      }
      final admin = rubriquesPour(_staff('Admin global')).values.expand((l) => l).map((e) => e.$1).toSet();
      expect(admin.containsAll(['300', '305', '306']), isTrue);
      final supportDefault = AdminAccess(role: 'support', teams: {'support': {'support.tickets'}});
      final ids = rubriquesPour(_staff('Support'), access: supportDefault).values.expand((l) => l).map((e) => e.$1).toSet();
      expect(ids.contains('300'), isTrue);
      expect(ids.contains('305'), isFalse);
      expect(ids.contains('139'), isFalse, reason: 'écran financier non proposé à un agent support');
      expect(ids.contains('147-1'), isTrue);
      expect(rubriquesPour(_client).values.expand((l) => l).map((e) => e.$1).toSet().intersection({'300', '305'}), isEmpty);
      expect(accountMenuEntries('admin').map((x) => x.$1), containsAll(['Centre d’administration', 'Équipes et permissions']));
      for (final r in ['finance', 'support']) {
        expect(accountMenuEntries(r).map((x) => x.$1), contains('Centre d’administration'), reason: r);
        expect(accountMenuEntries(r).map((x) => x.$1), isNot(contains('Équipes et permissions')), reason: r);
      }
      for (final r in ['client', 'student', 'dept', 'direction', 'company']) {
        expect(accountMenuEntries(r).map((x) => x.$1), isNot(contains('Centre d’administration')), reason: r);
      }
      expect(roleNames['finance'], 'Équipe Finance');
      expect(roleNames['support'], 'Équipe Support');
    });
  });

  Future<void> monter(WidgetTester t, Widget page, {Account? compte, List<Override> overrides = const [], double h = 1700}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = Size(390, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget stub(String text) => Scaffold(body: Center(child: Text(text)));
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(path: '/s/:id', builder: (_, s) => stub('écran ${s.pathParameters['id']}')),
      GoRoute(path: '/support/boite', builder: (_, _) => stub('boîte du support')),
      GoRoute(path: '/admin/sequestre', builder: (_, _) => stub('séquestre')),
      GoRoute(path: '/moderation/reseau', builder: (_, _) => stub('modération réseau')),
      GoRoute(path: '/marche/moderation', builder: (_, _) => stub('modération marketplace')),
      GoRoute(path: '/admin/entreprises', builder: (_, _) => stub('organisations à vérifier')),
      GoRoute(path: '/admin/forfaits', builder: (_, _) => stub('forfaits')),
      GoRoute(path: '/marche/promotions', builder: (_, _) => stub('promotions')),
    ]);
    await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: overrides, child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    if (compte != null) {
      ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(authProvider.notifier).login(compte);
      await t.pumpAndSettle();
    }
  }

  Override access(AdminAccess a) => adminAccessProvider.overrideWith((ref) async => a);

  Override dashboard(List<AdminCounter> c) => adminTeamDashboardProvider.overrideWith((ref, team) async => c);

  group('centre d’administration (300)', () {
    testWidgets('administrateur : les quatre équipes et l’administration globale, sans débordement', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Admin global'), overrides: [access(_admin)]);
      expect(find.text('Centre d’administration'), findsOneWidget);
      for (final n in ['Finance', 'Support', 'Sécurité et modération', 'Technique', 'Administration globale', 'Équipes et permissions', 'Comptes, rôles et permissions']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.textContaining('Vous êtes administrateur global'), findsOneWidget);
    });

    testWidgets('agent Finance : seule son équipe et ses permissions, aucune administration globale', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Finance'), overrides: [
        access(_agent({'finance': {'finance.read', 'finance.payments'}}, role: 'finance')),
      ]);
      expect(find.text('Finance'), findsWidgets);
      expect(find.text('Technique'), findsNothing);
      expect(find.text('Support'), findsNothing);
      expect(find.text('Sécurité et modération'), findsNothing);
      expect(find.text('Administration globale'), findsNothing);
      expect(find.text('Équipes et permissions'), findsNothing);
      expect(find.text('Vos permissions'), findsOneWidget);
      expect(find.text('Valider les paiements'), findsOneWidget);
      expect(find.text('Rembourser'), findsNothing);
    });

    testWidgets('agent à deux équipes (support + sécurité) : les deux, pas la finance ni la technique', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Support'), overrides: [access(AdminAccess.fromAccount(_staff('Support')))]);
      expect(find.text('Support'), findsWidgets);
      expect(find.text('Sécurité et modération'), findsWidgets);
      expect(find.text('Finance'), findsNothing);
      expect(find.text('Technique'), findsNothing);
    });

    testWidgets('agent sans permission : état vide explicite', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Support'), overrides: [access(_agent({}))]);
      expect(find.text('Aucune équipe'), findsOneWidget);
      expect(find.textContaining('ne vous a encore attribué aucune permission'), findsOneWidget);
    });

    testWidgets('erreur de lecture des droits : message et « Réessayer »', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Support'), overrides: [adminAccessProvider.overrideWith((ref) async => throw Exception('hors ligne'))]);
      expect(find.textContaining('n’ont pas pu être chargés'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('toucher une équipe ouvre son tableau de bord (301 à 304)', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Admin global'), overrides: [access(_admin)]);
      await t.tap(find.text('Sécurité et modération'));
      await t.pumpAndSettle();
      expect(find.text('écran 303'), findsOneWidget);
    });
  });

  group('tableau de bord d’une équipe', () {
    const counters = [
      AdminCounter('payments_pending', 'Paiements à vérifier', 3, '', 'finance.payments'),
      AdminCounter('escrow_held', 'Montants en séquestre (FCFA)', 1250000, 'FCFA', 'finance.read'),
    ];

    testWidgets('Finance (lecture seule) : indicateurs du serveur, outils de lecture seulement', (t) async {
      await monter(t, const AdminTeamScreen(team: 'finance'), compte: _staff('Finance'), overrides: [
        access(_agent({'finance': {'finance.read'}}, role: 'finance')),
        dashboard(counters),
      ]);
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1 250 000 FCFA'), findsOneWidget);
      expect(find.text('Tableau de bord financier'), findsOneWidget);
      expect(find.text('Séquestre et répartition'), findsOneWidget);
      expect(find.text('Paiements déclarés'), findsNothing, reason: 'valider les paiements exige finance.payments');
      expect(find.text('Versements et retraits'), findsOneWidget);
      expect(find.text('Agents et permissions de l’équipe'), findsNothing, reason: 'gestion réservée à l’administrateur');
    });

    testWidgets('administrateur : tous les outils de l’équipe et la gestion des agents', (t) async {
      await monter(t, const AdminTeamScreen(team: 'support'), compte: _staff('Admin global'), overrides: [access(_admin), dashboard(const [])], h: 2400);
      for (final n in ['Boîte du support', 'Commandes et incidents', 'Litiges et remboursements', 'Pièces justificatives à examiner', 'Agents et permissions de l’équipe']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      await t.tap(find.text('Agents et permissions de l’équipe'));
      await t.pumpAndSettle();
      expect(find.text('écran 305'), findsOneWidget);
    });

    testWidgets('un outil ouvre l’écran existant (boîte du support)', (t) async {
      await monter(t, const AdminTeamScreen(team: 'support'), compte: _staff('Support'), overrides: [
        access(_agent({'support': {'support.tickets'}})),
        dashboard(const [AdminCounter('tickets_open', 'Demandes d’aide ouvertes', 2, '', 'support.tickets')]),
      ]);
      expect(find.text('Litiges et remboursements'), findsNothing);
      await t.tap(find.text('Boîte du support'));
      await t.pumpAndSettle();
      expect(find.text('boîte du support'), findsOneWidget);
    });

    testWidgets('équipe qui n’est pas la sienne : accès réservé', (t) async {
      await monter(t, const AdminTeamScreen(team: 'finance'), compte: _staff('Support'), overrides: [access(_agent({'support': {'support.tickets'}})), dashboard(const [])]);
      expect(find.text('Accès réservé'), findsOneWidget);
      expect(find.text('Tableau de bord financier'), findsNothing);
    });

    testWidgets('états vide et erreur des indicateurs', (t) async {
      await monter(t, const AdminTeamScreen(team: 'tech'), compte: _staff('Support'), overrides: [access(_agent({'tech': {'tech.logs'}})), dashboard(const [])]);
      expect(find.textContaining('Aucun indicateur'), findsOneWidget);
      await monter(t, const AdminTeamScreen(team: 'tech'), compte: _staff('Support'), overrides: [
        access(_agent({'tech': {'tech.logs'}})),
        adminTeamDashboardProvider.overrideWith((ref, team) async => throw Exception('Réservé aux agents de cette équipe')),
      ]);
      expect(find.textContaining('Réservé aux agents'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('équipe inconnue : page introuvable', (t) async {
      await monter(t, const AdminTeamScreen(team: 'compta'), compte: _staff('Admin global'), overrides: [access(_admin)]);
      expect(find.text('Page introuvable'), findsOneWidget);
    });
  });

  group('gardes d’écran', () {
    testWidgets('AccessGuard : un agent Finance n’ouvre pas l’équipe Support (302), un agent Support oui', (t) async {
      await monter(t, const AccessGuard(id: '302', child: Text('CONTENU')), compte: _staff('Finance'), overrides: [access(_agent({'finance': {'finance.read'}}, role: 'finance'))]);
      expect(find.text('CONTENU'), findsNothing);
      expect(find.text('Page introuvable'), findsOneWidget);
      await monter(t, const AccessGuard(id: '302', child: Text('CONTENU')), compte: _staff('Support'), overrides: [access(_agent({'support': {'support.tickets'}}))]);
      expect(find.text('CONTENU'), findsOneWidget);
    });

    testWidgets('AccessGuard : écran financier 140 refusé à un agent finance sans finance.payments, ouvert avec', (t) async {
      await monter(t, const AccessGuard(id: '140', child: Text('CONTENU')), compte: _staff('Finance'), overrides: [access(_agent({'finance': {'finance.read'}}, role: 'finance'))]);
      expect(find.text('CONTENU'), findsNothing);
      await monter(t, const AccessGuard(id: '140', child: Text('CONTENU')), compte: _staff('Finance'), overrides: [access(_agent({'finance': {'finance.payments'}}, role: 'finance'))]);
      expect(find.text('CONTENU'), findsOneWidget);
    });

    testWidgets('AccessGuard : l’administrateur ouvre tout ; le département et la direction ne sont pas soumis aux permissions d’équipe', (t) async {
      await monter(t, const AccessGuard(id: '140', child: Text('CONTENU')), compte: _staff('Admin global'), overrides: [access(AdminAccess.none)]);
      expect(find.text('CONTENU'), findsOneWidget);
      await monter(t, const AccessGuard(id: '139', child: Text('CONTENU')), compte: _staff('Direction'), overrides: [access(AdminAccess.none)]);
      expect(find.text('CONTENU'), findsOneWidget, reason: 'lecture consolidée de la direction (lot H3)');
      await monter(t, const AccessGuard(id: '140', child: Text('CONTENU')), compte: _staff('Direction'), overrides: [access(AdminAccess.none)]);
      expect(find.text('Page introuvable'), findsOneWidget);
    });

    testWidgets('RouteGuard avec permissions : séquestre ouvert seulement avec finance.read', (t) async {
      const garde = RouteGuard(name: '/admin/sequestre', roles: {'admin', 'finance', 'support'}, perms: {'finance.read'}, child: Text('CONTENU'));
      await monter(t, garde, compte: _staff('Support'), overrides: [access(_agent({'support': {'support.tickets'}}))]);
      expect(find.text('CONTENU'), findsNothing);
      await monter(t, garde, compte: _staff('Finance'), overrides: [access(_agent({'finance': {'finance.read'}}, role: 'finance'))]);
      expect(find.text('CONTENU'), findsOneWidget);
      await monter(t, garde, compte: _staff('Admin global'), overrides: [access(AdminAccess.none)]);
      expect(find.text('CONTENU'), findsOneWidget);
      await monter(t, garde, compte: demoAccount, overrides: [access(AdminAccess.none)]);
      expect(find.text('CONTENU'), findsNothing);
    });

    testWidgets('droits illisibles : message et « Réessayer » (jamais un écran ouvert par défaut)', (t) async {
      await monter(t, const AccessGuard(id: '140', child: Text('CONTENU')), compte: _staff('Finance'), overrides: [adminAccessProvider.overrideWith((ref) async => throw Exception('hors ligne'))]);
      expect(find.text('CONTENU'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  Map<String, dynamic> team(String code, String name, {List<String> defaults = const []}) => {
        'code': code,
        'name': name,
        'description': 'Description de l’équipe $name.',
        'members': 1,
        'defaults': defaults,
        'permissions': [
          {'code': '$code.a', 'label': 'Permission A', 'description': 'Première permission.', 'sensitive': false},
          {'code': '$code.b', 'label': 'Permission B sensible', 'description': 'Seconde permission.', 'sensitive': true},
        ],
      };

  group('gestion des équipes (305)', () {
    final overview = [team('finance', 'Finance', defaults: ['finance.a']), team('support', 'Support'), team('security', 'Sécurité et modération'), team('tech', 'Technique')];
    final members = [
      {'user_id': 'u1', 'name': 'Fina Finance', 'email': 'fina@t.cm', 'role': 'finance', 'suspended': false, 'permissions': ['finance.read', 'finance.payments'], 'granted_by': 'Ada Admin', 'updated_at': '2026-11-17T10:00:00Z'},
      {'user_id': 'u2', 'name': 'Sus Pendu', 'email': 'sus@t.cm', 'role': 'support', 'suspended': true, 'permissions': ['finance.read'], 'granted_by': null, 'updated_at': '2026-11-17T10:00:00Z'},
    ];

    testWidgets('équipe, agents, permissions, actions : tout tient à 390 px', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2000, overrides: [
        adminTeamsOverviewProvider.overrideWith((ref) async => overview),
        adminTeamMembersProvider.overrideWith((ref, team) async => members),
      ]);
      expect(find.text('Équipes et permissions'), findsOneWidget);
      expect(find.text('Fina Finance'), findsOneWidget);
      expect(find.text('Lecture financière'), findsWidgets);
      expect(find.text('Valider les paiements'), findsOneWidget);
      expect(find.text('Suspendu'), findsOneWidget);
      expect(find.text('Modifier'), findsNWidgets(2));
      expect(find.text('Retirer'), findsNWidgets(2));
      expect(find.text('Ajouter un agent'), findsOneWidget);
      expect(find.text('Comptes, rôles et permissions'), findsOneWidget);
    });

    testWidgets('changer d’équipe relit les agents de l’équipe choisie', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2000, overrides: [
        adminTeamsOverviewProvider.overrideWith((ref) async => overview),
        adminTeamMembersProvider.overrideWith((ref, team) async => team == 'support' ? const [] : members),
      ]);
      await t.tap(find.text('Support'));
      await t.pumpAndSettle();
      expect(find.text('Aucun agent'), findsOneWidget);
      expect(find.text('Fina Finance'), findsNothing);
    });

    testWidgets('« Retirer » demande confirmation avant tout appel au serveur ; « Modifier » ouvre les cases à cocher avec les permissions sensibles signalées', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2000, overrides: [
        adminTeamsOverviewProvider.overrideWith((ref) async => overview),
        adminTeamMembersProvider.overrideWith((ref, team) async => members),
      ]);
      await t.tap(find.text('Retirer').first);
      await t.pumpAndSettle();
      expect(find.text('Retirer Fina Finance ?'), findsOneWidget);
      await t.tap(find.text('Annuler'));
      await t.pumpAndSettle();
      expect(find.text('Retirer Fina Finance ?'), findsNothing);
      await t.tap(find.text('Modifier').first);
      await t.pumpAndSettle();
      expect(find.text('Permissions de Fina Finance'), findsOneWidget);
      expect(find.text('Sensible'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      await t.tap(find.text('Annuler').last);
      await t.pumpAndSettle();
      expect(find.text('Permissions de Fina Finance'), findsNothing);
    });

    testWidgets('erreur du serveur : message et « Réessayer » ; sans équipe : état vide', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), overrides: [adminTeamsOverviewProvider.overrideWith((ref) async => throw Exception('Réservé à l’administrateur global'))]);
      expect(find.textContaining('Réservé à l’administrateur global'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), overrides: [adminTeamsOverviewProvider.overrideWith((ref) async => const [])]);
      expect(find.text('Aucune donnée'), findsOneWidget);
    });

    testWidgets('l’écran 305 est refusé à un agent (garde d’écran)', (t) async {
      await monter(t, const AccessGuard(id: '305', child: AdminTeamsScreen()), compte: _staff('Support'), overrides: [access(AdminAccess.fromAccount(_staff('Support')))]);
      expect(find.text('Page introuvable'), findsOneWidget);
      expect(find.text('Équipes et permissions'), findsNothing);
    });
  });

  group('comptes suspects (306)', () {
    final flags = [
      {'id': 'f1', 'user_id': 'u9', 'name': 'Cora Cliente', 'email': 'cora@t.cm', 'role': 'client', 'suspended': false, 'reason': 'Plusieurs paiements refusés avec des numéros différents', 'status': 'open', 'created_at': '2026-11-17T10:00:00Z', 'flagged_by': 'Sec Sécurité', 'decided_at': null, 'decision_note': null},
    ];

    testWidgets('liste des signalements, actions et signalement d’un compte', (t) async {
      await monter(t, const SecurityFlagsScreen(), compte: _staff('Support'), h: 1400, overrides: [securityFlagsProvider.overrideWith((ref, status) async => flags)]);
      expect(find.text('Comptes suspects'), findsOneWidget);
      expect(find.text('Cora Cliente'), findsOneWidget);
      expect(find.textContaining('Plusieurs paiements refusés'), findsOneWidget);
      expect(find.text('Hors de cause'), findsWidgets);
      expect(find.text('Transmettre'), findsOneWidget);
      expect(find.text('Signaler un compte'), findsOneWidget);
      await t.tap(find.text('Signaler un compte'));
      await t.pumpAndSettle();
      expect(find.text('Trouver le compte'), findsOneWidget);
    });

    testWidgets('états vide et erreur', (t) async {
      await monter(t, const SecurityFlagsScreen(), compte: _staff('Support'), overrides: [securityFlagsProvider.overrideWith((ref, status) async => const [])]);
      expect(find.text('Aucun signalement'), findsOneWidget);
      await monter(t, const SecurityFlagsScreen(), compte: _staff('Support'), overrides: [securityFlagsProvider.overrideWith((ref, status) async => throw Exception('Réservé à l’équipe Sécurité et modération'))]);
      expect(find.textContaining('Réservé à l’équipe Sécurité'), findsOneWidget);
    });

    testWidgets('l’écran 306 est refusé à un agent Finance sans security.accounts', (t) async {
      await monter(t, const AccessGuard(id: '306', child: SecurityFlagsScreen()), compte: _staff('Finance'), overrides: [access(_agent({'finance': {'finance.read'}}, role: 'finance'))]);
      expect(find.text('Page introuvable'), findsOneWidget);
    });
  });
}
