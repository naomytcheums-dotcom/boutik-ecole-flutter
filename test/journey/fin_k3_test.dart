import 'package:boutik_ecole/figma/g/g_108.dart';
import 'package:boutik_ecole/figma/g/g_112.dart';
import 'package:boutik_ecole/figma/g/g_113.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/dept_space.dart';
import 'package:boutik_ecole/figma/live/review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot K3 (Département, point 4) : écran d'attente d'un compte non rattaché, traitement administratif des rattachements (compteur, raisons, états vide / erreur),
/// et écrans de console 108 à 115 : écran d'attente, page mobile réelle sous 700 px, toile à partir de 700 px alimentée par les mêmes lectures serveur.
/// Les lectures serveur sont simulées par surcharge de `deptCallProvider` ; aucune donnée de maquette ne doit apparaître.

typedef _Handler = Object? Function(DeptCall c);

Override _calls(Map<String, _Handler> m) => deptCallProvider.overrideWith((ref, c) async {
      final f = m[c.fn];
      if (f == null) throw 'Fonction inattendue : ${c.fn}';
      return f(c);
    });

Map<String, dynamic> _me({bool attached = true, String role = 'dept', String reason = ''}) => {
      'role': role,
      'attached': attached,
      'waiting': role == 'dept' && !attached,
      'state': attached ? 'ok' : 'none',
      'reason': reason,
      'department_id': 'd1',
      'department': 'Génie logiciel',
      'institution': 'IUT test',
      'title': 'Chef de département',
      'name': 'Dr Mbarga',
    };

final _overview = {
  'department_id': 'd1',
  'department': 'Génie logiciel',
  'institution': 'IUT test',
  'students': 42,
  'students_verified': 30,
  'sellers': 5,
  'projects': {'total': 9},
  'innovations': {'total': 3},
  'skills': {'total': 77},
  'opportunities': {'published': 6, 'applications': 14},
  'partnerships': {'actif': 2},
  'sales': {'revenue': 1250000, 'orders': 18},
  'validations': {'total': 3},
};

class _Queue extends ReviewQueue {
  _Queue(this.items);
  final List<ReviewItem> items;
  @override
  List<ReviewItem> build() => items;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget screen, List<Override> overrides, {String staff = 'Resp. département', Size size = const Size(390, 844), bool connected = true}) async {
    Backend.ready = connected;
    GAnim.enabled = false;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [initialAccountProvider.overrideWithValue(demoAccount.copyWith(staff: staff)), ...overrides],
      child: MaterialApp(home: screen),
    ));
    await t.pumpAndSettle();
  }

  final base = <String, _Handler>{
    'my_department': (_) => _me(),
    'dept_overview': (_) => _overview,
    'dept_activity': (_) => [],
    'dept_stats': (_) => {'revenue': 100000, 'orders': 4, 'avg_basket': 25000, 'services_revenue': 20000, 'weeks': [{'week': '2026-11-02', 'revenue': 60000}, {'week': '2026-11-09', 'revenue': 40000}]},
    'staff_productions': (_) => [
          {'id': 'p1', 'title': 'Lot de lampes', 'team': 'Équipe A', 'mentor': 'Dr Test', 'progress': 40, 'status': 'en_retard'},
        ],
    'staff_mentors': (_) => [
          {'id': 'm1', 'name': 'Dr Test', 'role': 'Mentor', 'specialty': 'Java', 'active': true, 'productions': 1},
        ],
    'admin_departments': (_) => [
          {'id': 'd1', 'name': 'Génie logiciel', 'institution': 'IUT test'},
        ],
  };

  testWidgets('compte non rattaché : écran d’attente avec la raison, action « Actualiser », aucune donnée ni erreur technique (390 px)', (t) async {
    await monter(t, const DepartmentHubScreen(), [
      _calls({...base, 'my_department': (_) => _me(attached: false, reason: 'Aucun département ne vous a encore été attribué.')}),
    ]);
    expect(find.text('En attente de rattachement'), findsOneWidget);
    expect(find.textContaining('Aucun département ne vous a encore été attribué'), findsOneWidget);
    expect(find.text('Actualiser'), findsOneWidget);
    expect(find.text('Contacter l’aide'), findsOneWidget);
    expect(find.text('Lecture impossible'), findsNothing);
    expect(find.text('42'), findsNothing);
  });

  testWidgets('chaque page de l’espace affiche l’attente, jamais de donnée, quand le compte n’est pas rattaché', (t) async {
    for (final screen in const <Widget>[DepartmentStudentsScreen(), DepartmentProjectsScreen(), DepartmentStatsScreen(), DepartmentProductionsScreen(), DepartmentMentorsScreen(), DepartmentListingsScreen()]) {
      await monter(t, screen, [_calls({...base, 'my_department': (_) => _me(attached: false)})]);
      expect(find.text('En attente de rattachement'), findsOneWidget, reason: '${screen.runtimeType}');
      expect(find.text('Lot de lampes'), findsNothing);
      expect(find.text('Dr Test'), findsNothing);
    }
  });

  group('rattachement des comptes (administrateur)', () {
    final accounts = [
      {'id': 'c1', 'name': 'Dr Mbarga', 'attached': true, 'state': 'ok', 'department_id': 'd1', 'department': 'Génie logiciel', 'institution': 'IUT test', 'suspended': false, 'to_review': false},
      {'id': 'c2', 'name': 'Mme Ndongo', 'attached': false, 'state': 'none', 'suspended': false, 'to_review': false},
      {'id': 'c3', 'name': 'M. Essomba', 'attached': false, 'state': 'unverified', 'department': 'Département proposé', 'institution': 'IUT test', 'suspended': false, 'to_review': false},
      {'id': 'c4', 'name': 'Mme Fotso', 'attached': false, 'state': 'ambiguous', 'suspended': false, 'to_review': false},
      {'id': 'c5', 'name': 'Dr Abega', 'attached': true, 'state': 'ok', 'department_id': 'd1', 'department': 'Génie logiciel', 'institution': 'IUT test', 'suspended': false, 'to_review': true},
    ];

    testWidgets('compteur, raisons, suggestion non appliquée, rattachements à confirmer (390 px)', (t) async {
      await monter(t, const DepartmentAttachScreen(), [
        _calls({
          ...base,
          'admin_dept_accounts': (_) => accounts,
          'admin_dept_unassigned_accounts': (_) => [
                {'id': 'c2', 'candidates': [{'id': 'd1', 'name': 'Génie logiciel', 'institution': 'IUT test'}]},
              ],
        }),
      ], staff: 'Admin global');
      expect(find.textContaining('3 comptes en attente de rattachement'), findsOneWidget);
      expect(find.text('Non rattaché'), findsOneWidget);
      expect(find.text('Département non vérifié'), findsOneWidget);
      expect(find.text('Nom ambigu'), findsOneWidget);
      expect(find.text('À confirmer'), findsOneWidget);
      expect(find.text('Confirmer'), findsOneWidget);
      expect(find.textContaining('Suggestion (à valider par vous) : Génie logiciel'), findsOneWidget);
      expect(find.text('Rattacher'), findsNWidgets(3));
    });

    testWidgets('tout est rattaché : message de confirmation', (t) async {
      await monter(t, const DepartmentAttachScreen(), [
        _calls({...base, 'admin_dept_accounts': (_) => [accounts.first], 'admin_dept_unassigned_accounts': (_) => []}),
      ], staff: 'Admin global');
      expect(find.textContaining('Tous les comptes Département actifs sont rattachés'), findsOneWidget);
    });

    testWidgets('aucun compte Département : état vide', (t) async {
      await monter(t, const DepartmentAttachScreen(), [_calls({...base, 'admin_dept_accounts': (_) => [], 'admin_dept_unassigned_accounts': (_) => []})], staff: 'Admin global');
      expect(find.text('Aucun compte Département'), findsOneWidget);
    });

    testWidgets('lecture en échec : message et « Réessayer »', (t) async {
      await monter(t, const DepartmentAttachScreen(), [
        _calls({...base, 'admin_dept_accounts': (_) => throw 'Réservé à l’administrateur', 'admin_dept_unassigned_accounts': (_) => []}),
      ], staff: 'Admin global');
      expect(find.text('Lecture impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('tableau de bord administrateur : badge du nombre de comptes en attente', (t) async {
      await monter(t, const DepartmentHubScreen(), [
        _calls({...base, 'my_department': (_) => _me(role: 'admin'), 'admin_dept_unassigned_count': (_) => 3}),
      ], staff: 'Admin global');
      await t.scrollUntilVisible(find.text('Rattachement des comptes'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Rattachement des comptes'), findsOneWidget);
      expect(find.text('3 comptes en attente de rattachement'), findsOneWidget);
    });
  });

  group('pages mobiles des écrans 110 à 115 (390 px)', () {
    testWidgets('112 statistiques : chiffres réels', (t) async {
      await monter(t, const DepartmentStatsScreen(), [_calls(base)]);
      expect(find.text('Statistiques'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('113 productions : ligne réelle, état « en retard »', (t) async {
      await monter(t, const DepartmentProductionsScreen(), [_calls(base)]);
      expect(find.text('Lot de lampes'), findsOneWidget);
      expect(find.text('En retard'), findsOneWidget);
    });

    testWidgets('113 vide : état vide', (t) async {
      await monter(t, const DepartmentProductionsScreen(), [_calls({...base, 'staff_productions': (_) => []})]);
      expect(find.text('Aucune production'), findsOneWidget);
    });

    testWidgets('114 mentors : liste réelle et bouton d’ajout pour le département', (t) async {
      await monter(t, const DepartmentMentorsScreen(), [_calls(base)]);
      expect(find.text('Dr Test'), findsOneWidget);
      expect(find.text('Ajouter un mentor'), findsOneWidget);
    });

    testWidgets('114 en erreur : message et « Réessayer »', (t) async {
      await monter(t, const DepartmentMentorsScreen(), [_calls({...base, 'staff_mentors': (_) => throw 'Service indisponible'})]);
      expect(find.text('Lecture impossible'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('110 annonces à valider : file réelle du département, vide sinon', (t) async {
      await monter(t, const DepartmentListingsScreen(), [
        _calls(base),
        reviewQueueProvider.overrideWith(() => _Queue(const [ReviewItem('Sac solaire', 'Awa Mballa', 'Mode', 15000, 'Hier', seed: false, id: 'l1', status: 'pending', department: 'Génie logiciel')])),
      ]);
      expect(find.text('Sac solaire'), findsOneWidget);
      await monter(t, const DepartmentListingsScreen(), [_calls(base), reviewQueueProvider.overrideWith(() => _Queue(const []))]);
      expect(find.text('Rien à valider'), findsOneWidget);
    });
  });

  group('écrans de console 108 à 115 : passerelle', () {
    const canvas = SizedBox(key: Key('toile'), width: 10, height: 10);

    testWidgets('hors connexion : la toile de démonstration reste affichée', (t) async {
      await monter(t, const DeptDesktopGate(id: '109', canvas: canvas), [_calls(base)], connected: false);
      expect(find.byKey(const Key('toile')), findsOneWidget);
    });

    testWidgets('chef non rattaché : attente, même sur grand écran (aucune toile)', (t) async {
      await monter(t, const DeptDesktopGate(id: '109', canvas: canvas), [_calls({...base, 'my_department': (_) => _me(attached: false)})], size: const Size(1280, 900));
      expect(find.text('En attente de rattachement'), findsOneWidget);
      expect(find.byKey(const Key('toile')), findsNothing);
    });

    testWidgets('chef rattaché à moins de 700 px : vraie page mobile, pas de toile', (t) async {
      await monter(t, const DeptDesktopGate(id: '113', canvas: canvas), [_calls(base)]);
      expect(find.byKey(const Key('toile')), findsNothing);
      expect(find.text('Suivi des productions'), findsOneWidget);
      expect(find.text('Lot de lampes'), findsOneWidget);
    });

    testWidgets('chef rattaché à partir de 700 px : la toile', (t) async {
      await monter(t, const DeptDesktopGate(id: '113', canvas: canvas), [_calls(base)], size: const Size(1280, 900));
      expect(find.byKey(const Key('toile')), findsOneWidget);
    });

    testWidgets('administrateur à moins de 700 px : page mobile de l’écran (115 = événements)', (t) async {
      await monter(t, const DeptDesktopGate(id: '112', canvas: canvas), [_calls({...base, 'my_department': (_) => _me(role: 'admin')})], staff: 'Admin global');
      expect(find.byKey(const Key('toile')), findsNothing);
      expect(find.text('Statistiques'), findsOneWidget);
    });

    testWidgets('108 connecté (1280 px) : la toile affiche les chiffres réels du département', (t) async {
      await monter(t, const G_108(), [_calls(base)], size: const Size(1280, 900));
      expect(find.text('Tableau de bord du département'), findsWidgets);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Génie logiciel'), findsWidgets);
      expect(find.text('Rapports et exports'), findsOneWidget);
    });

    testWidgets('113 et 112 connectés (1280 px) : la page réelle remplace les tableaux de maquette, sans flèche retour', (t) async {
      await monter(t, const G_113(), [_calls(base)], size: const Size(1280, 900));
      expect(find.text('Lot de lampes'), findsOneWidget);
      expect(find.textContaining('Équipe A'), findsWidgets);
      expect(find.byTooltip('Retour'), findsNothing);
      await monter(t, const G_112(), [_calls(base)], size: const Size(1280, 900));
      expect(find.text('Chiffre d’affaires'), findsWidgets);
      expect(find.text('4'), findsWidgets);
      expect(find.text('4 820 000 FCFA'), findsNothing);
    });
  });
}
