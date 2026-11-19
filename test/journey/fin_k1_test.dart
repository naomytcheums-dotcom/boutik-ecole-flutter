import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/admin_access.dart';
import 'package:boutik_ecole/figma/live/admin_centre.dart';
import 'package:boutik_ecole/figma/live/admin_equipes.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/tp_ui.dart' show TpButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Lot K1 (sécurité administrateur) côté Flutter, à 390 px : droits MINIMAUX d'un compte Finance / Support (membre de son équipe, aucune permission,
/// aucun outil), liste « à réviser » de l'administrateur global, attribution explicite, isolement équipe x outil (matrice).
/// Les preuves serveur (2FA, notifications par permission, rattrapage, isolation) sont dans supabase/tests/marketplace_pglite/fin_k1.mjs.

Account _staff(String staff) => seedAccounts.firstWhere((a) => a.staff == staff);

AdminAccess _agent(Map<String, Set<String>> teams, {String role = 'support'}) => AdminAccess(role: role, teams: teams);

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  group('droits minimaux (modèle)', () {
    test('un compte inscrit sans permission reste membre de son équipe mais n’a aucune permission', () {
      final a = AdminAccess.fromJson({'role': 'finance', 'is_admin': false, 'teams': {'finance': <String>[]}});
      expect(a.inTeam('finance'), isTrue);
      expect(a.myTeams, ['finance']);
      expect(a.isMinimal, isTrue);
      expect(a.permissions, isEmpty);
      expect(a.has('finance.read'), isFalse);
      expect(a.inTeam('support'), isFalse);
      expect(AdminAccess.fromJson({'role': 'admin', 'is_admin': true, 'teams': <String, dynamic>{}}).isMinimal, isFalse);
      expect(AdminAccess.none.isMinimal, isFalse);
      expect(_agent({'support': {'support.tickets'}}).isMinimal, isFalse);
    });

    test('matrice : un agent sans permission n’ouvre AUCUN outil ni AUCUN écran réservé, quelle que soit l’équipe', () {
      for (final role in ['finance', 'support']) {
        final minimal = AdminAccess(role: role, teams: {role: <String>{}});
        final account = _staff(role == 'finance' ? 'Finance' : 'Support');
        for (final team in kTeamOrder) {
          for (final tool in kTeamTools[team]!) {
            expect(minimal.hasAny(tool.perms), isFalse, reason: '$role minimal voit « ${tool.label} »');
          }
        }
        for (final id in kScreenPermissions.keys) {
          expect(screenAllowedByAccess(account, id, minimal), isFalse, reason: '$role minimal ouvre l’écran $id');
        }
      }
    });

    test('matrice équipe x outil : chaque agent (toutes les permissions de SON équipe) ne voit que les outils de son équipe', () {
      const perms = {
        'finance': {'finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers', 'finance.split'},
        'support': {'support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds'},
        'security': {'security.moderation', 'security.reports', 'security.accounts', 'security.audit'},
        'tech': {'tech.config', 'tech.integrations', 'tech.logs', 'tech.maintenance'},
      };
      // outils partagés par conception (H4) : une permission d'une autre équipe est citée dans leurs permissions
      for (final own in kTeamOrder) {
        final agent = AdminAccess(role: own == 'finance' ? 'finance' : 'support', teams: {own: perms[own]!});
        for (final other in kTeamOrder.where((t) => t != own)) {
          for (final tool in kTeamTools[other]!) {
            final shared = tool.perms.any((p) => p.startsWith('$own.'));
            expect(agent.hasAny(tool.perms), shared, reason: 'agent $own x outil « ${tool.label} » (équipe $other)');
          }
        }
        for (final tool in kTeamTools[own]!) {
          expect(agent.hasAny(tool.perms), isTrue, reason: 'agent $own ne voit pas son outil « ${tool.label} »');
        }
      }
      final admin = AdminAccess(role: 'admin', isAdmin: true, teams: const {});
      for (final team in kTeamOrder) {
        for (final tool in kTeamTools[team]!) {
          expect(admin.hasAny(tool.perms), isTrue);
        }
      }
    });

    test('révocation : retirer une permission retire immédiatement l’accès (le modèle suit la réponse serveur)', () {
      final avant = _agent({'finance': {'finance.read', 'finance.payments'}}, role: 'finance');
      final apres = _agent({'finance': {'finance.read'}}, role: 'finance');
      final account = _staff('Finance');
      expect(screenAllowedByAccess(account, '140', avant), isTrue);
      expect(screenAllowedByAccess(account, '140', apres), isFalse);
    });
  });

  Future<void> monter(WidgetTester t, Widget page, {Account? compte, List<Override> overrides = const [], double h = 1900}) async {
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

  group('agent à droits minimaux : centre et tableau de bord', () {
    final minimal = AdminAccess(role: 'finance', teams: {'finance': <String>{}});

    testWidgets('centre : équipe visible, note « droits minimaux », aucune administration globale', (t) async {
      await monter(t, const AdminCentreScreen(), compte: _staff('Finance'), overrides: [access(minimal)]);
      expect(find.text('Finance'), findsWidgets);
      expect(find.textContaining('Droits minimaux'), findsOneWidget);
      expect(find.text('Administration globale'), findsNothing);
      expect(find.text('Support'), findsNothing);
      expect(find.text('Technique'), findsNothing);
    });

    testWidgets('tableau de bord : aucun outil, aucun indicateur, message explicite, pas de gestion des agents', (t) async {
      await monter(t, const AdminTeamScreen(team: 'finance'), compte: _staff('Finance'), overrides: [access(minimal), dashboard(const [])]);
      expect(find.text('Tableau de bord financier'), findsNothing);
      expect(find.text('Paiements déclarés'), findsNothing);
      expect(find.textContaining('Aucun outil'), findsOneWidget);
      expect(find.textContaining('Aucun indicateur'), findsOneWidget);
      expect(find.textContaining('Aucune permission attribuée dans cette équipe'), findsOneWidget);
      expect(find.text('Agents et permissions de l’équipe'), findsNothing);
    });

    testWidgets('l’agent minimal n’ouvre pas l’équipe d’à côté (Support) ni un écran réservé', (t) async {
      await monter(t, const AdminTeamScreen(team: 'support'), compte: _staff('Finance'), overrides: [access(minimal), dashboard(const [])]);
      expect(find.text('Accès réservé'), findsOneWidget);
      await monter(t, const AccessGuard(id: '140', child: Text('CONTENU')), compte: _staff('Finance'), overrides: [access(minimal)]);
      expect(find.text('CONTENU'), findsNothing);
    });

    testWidgets('après attribution explicite (réponse serveur), les outils attribués apparaissent, pas les autres', (t) async {
      final attribue = AdminAccess(role: 'finance', teams: {'finance': {'finance.payments'}});
      await monter(t, const AdminTeamScreen(team: 'finance'), compte: _staff('Finance'), overrides: [
        access(attribue),
        dashboard(const [AdminCounter('payments_pending', 'Paiements à vérifier', 2, '', 'finance.payments')]),
      ]);
      expect(find.text('Paiements déclarés'), findsOneWidget);
      expect(find.text('Versements et retraits'), findsNothing);
      expect(find.text('Séquestre et répartition'), findsNothing);
      expect(find.text('Paiements à vérifier'), findsOneWidget);
    });
  });

  Map<String, dynamic> team(String code, String name) => {
        'code': code,
        'name': name,
        'description': 'Description de l’équipe $name.',
        'members': 1,
        'defaults': <String>[],
        'permissions': [
          {'code': '$code.a', 'label': 'Permission A', 'description': 'Première permission.', 'sensitive': false},
          {'code': '$code.b', 'label': 'Permission B sensible', 'description': 'Seconde permission.', 'sensitive': true},
        ],
      };

  group('comptes à réviser (305, administrateur global)', () {
    final overview = [team('finance', 'Finance'), team('support', 'Support'), team('security', 'Sécurité et modération'), team('tech', 'Technique')];
    final review = [
      {
        'user_id': 'u1', 'name': 'Legs Finance', 'email': 'legs@t.cm', 'role': 'finance', 'suspended': false, 'needs_review': true,
        'teams': [{'team': 'finance', 'permissions': <String>[], 'explicit': false}],
        'previous': [{'team': 'finance', 'permissions': ['finance.a', 'finance.read', 'finance.payments', 'finance.payouts'], 'at': '2026-11-21T08:00:00Z'}],
      },
      {
        'user_id': 'u2', 'name': 'Sam Support', 'email': 'sam@t.cm', 'role': 'support', 'suspended': true, 'needs_review': true,
        'teams': [{'team': 'support', 'permissions': <String>[], 'explicit': false}],
        'previous': <Map<String, dynamic>>[],
      },
      {
        'user_id': 'u3', 'name': 'Attribué Explicite', 'email': 'ok@t.cm', 'role': 'finance', 'suspended': false, 'needs_review': false,
        'teams': [{'team': 'finance', 'permissions': ['finance.payments'], 'explicit': true}],
        'previous': <Map<String, dynamic>>[],
      },
    ];
    final members = [
      {'user_id': 'u1', 'name': 'Legs Finance', 'email': 'legs@t.cm', 'role': 'finance', 'suspended': false, 'permissions': <String>[], 'granted_by': null, 'updated_at': '2026-11-21T08:00:00Z'},
    ];

    List<Override> base(List<Map<String, dynamic>> rows) => [
          adminTeamsOverviewProvider.overrideWith((ref) async => overview),
          adminTeamMembersProvider.overrideWith((ref, team) async => members),
          adminTeamsReviewProvider.overrideWith((ref) async => rows),
        ];

    testWidgets('comptes hérités listés avec leurs droits d’avant, compte attribué explicitement absent, 390 px sans débordement', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2600, overrides: base(review));
      expect(find.text('Comptes à réviser'), findsOneWidget);
      expect(find.text('Legs Finance'), findsWidgets);
      expect(find.text('Sam Support'), findsOneWidget);
      expect(find.text('Attribué Explicite'), findsNothing);
      expect(find.textContaining('Droits hérités avant la réduction'), findsOneWidget);
      expect(find.text('Valider les paiements'), findsOneWidget);
      expect(find.text('Retraits et versements'), findsOneWidget);
      expect(find.text('Attribuer des permissions'), findsNWidgets(2));
      expect(find.textContaining('Aucune permission : droits minimaux'), findsOneWidget);
    });

    testWidgets('« Attribuer des permissions » ouvre le choix, rien n’est retenu par défaut (aucun privilège conservé automatiquement)', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2600, overrides: base(review));
      await t.tap(find.text('Attribuer des permissions').first);
      await t.pumpAndSettle();
      expect(find.text('Permissions de Legs Finance'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      final cases = t.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(cases.every((c) => c.value == false), isTrue, reason: 'les droits d’avant sont affichés pour information, jamais recochés d’office');
      await t.tap(find.text('Annuler').last);
      await t.pumpAndSettle();
      expect(find.text('Permissions de Legs Finance'), findsNothing);
    });

    testWidgets('compte suspendu : attribution désactivée', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2600, overrides: base(review));
      final boutons = find.widgetWithText(TpButton, 'Attribuer des permissions');
      expect(boutons, findsNWidgets(2));
      expect(t.widget<TpButton>(boutons.last).onTap, isNull);
      expect(t.widget<TpButton>(boutons.first).onTap, isNotNull);
    });

    testWidgets('aucun compte à réviser : état vide explicite', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2200, overrides: base([review[2]]));
      expect(find.textContaining('Aucun compte à réviser'), findsOneWidget);
      expect(find.text('Attribuer des permissions'), findsNothing);
    });

    testWidgets('erreur de lecture de la liste : message et « Réessayer » (jamais un faux « aucun compte »)', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2200, overrides: [
        adminTeamsOverviewProvider.overrideWith((ref) async => overview),
        adminTeamMembersProvider.overrideWith((ref, team) async => members),
        adminTeamsReviewProvider.overrideWith((ref) async => throw Exception('Réservé à l’administrateur global')),
      ]);
      expect(find.textContaining('Réservé à l’administrateur global'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucun compte à réviser'), findsNothing);
    });

    testWidgets('agent minimal dans la liste des membres : mention explicite des droits minimaux', (t) async {
      await monter(t, const AdminTeamsScreen(), compte: _staff('Admin global'), h: 2600, overrides: base(review));
      expect(find.textContaining('Aucune permission : droits minimaux (tableau de bord seulement)'), findsOneWidget);
    });

    testWidgets('l’écran 305 reste refusé à un agent, même minimal', (t) async {
      await monter(t, const AccessGuard(id: '305', child: AdminTeamsScreen()), compte: _staff('Finance'), overrides: [access(AdminAccess(role: 'finance', teams: {'finance': <String>{}}))]);
      expect(find.text('Page introuvable'), findsOneWidget);
      expect(find.text('Comptes à réviser'), findsNothing);
    });
  });
}
