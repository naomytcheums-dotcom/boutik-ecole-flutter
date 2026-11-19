import 'package:boutik_ecole/figma/g/g_117.dart';
import 'package:boutik_ecole/figma/g/g_122.dart';
import 'package:boutik_ecole/figma/g/g_123.dart';
import 'package:boutik_ecole/figma/g/g_125.dart';
import 'package:boutik_ecole/figma/g/g_126.dart';
import 'package:boutik_ecole/figma/g/g_239.dart';
import 'package:boutik_ecole/figma/g/g_284.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/direction.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart' show MobileList;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Lot H3 (Direction) : droits d'accès aux écrans (aucun pouvoir technique, finance en lecture consolidée) et écrans de la direction à 390 px
/// (aucun débordement : une erreur de mise en page fait échouer le test), avec des réponses serveur simulées.

Account _by(String staff) => seedAccounts.firstWhere((a) => a.staff == staff);

const _dash = {
  'students': 120, 'students_verified': 87, 'students_new_30d': 9, 'students_new_prev_30d': 4, 'departments': 5, 'dept_heads': 4, 'projects': 31, 'innovations': 12,
  'projects_pending': 3, 'projects_30d': 8, 'projects_prev_30d': 5, 'productions_active': 6, 'productions_done': 2, 'mentors': 7, 'events_upcoming': 2, 'events_30d': 1,
  'opportunities': 14, 'applications_30d': 40, 'partnerships_active': 4, 'partnerships_proposed': 2, 'dept_partnerships_active': 3, 'validations_pending': 5,
  'listings_approved': 52, 'orders_paid': 33, 'paid_revenue': 1250000,
  'months': [{'month': '2026-10', 'projects': 4, 'orders_paid': 9, 'students_new': 3}, {'month': '2026-11', 'projects': 5, 'orders_paid': 11, 'students_new': 6}],
};

Map<String, dynamic> _partner(String status, {bool mine = false}) => {
      'id': 'p-$status', 'name': 'Orange Cameroun $status', 'kind': 'entreprise', 'status': status, 'department_id': 'd1', 'department': 'Génie informatique',
      'company_owner_id': null, 'company': '', 'contact_name': 'M. Contact', 'contact_email': 'contact@orange.cm', 'contact_phone': '', 'objective': 'Stages et recrutement',
      'domains': ['stages'], 'starts_on': '2026-12-01', 'ends_on': '2027-12-01', 'decision_note': null, 'decided_at': null, 'proposer': 'Doua', 'mine': mine, 'created_at': '2026-11-01T10:00:00Z',
    };

void main() {
  setUpAll(loadAppFonts);
  final original = directionRpc;
  final calls = <(String, Map<String, dynamic>)>[];
  var responses = <String, Object?>{};
  var errors = <String, String>{};

  setUp(() {
    calls.clear();
    responses = {};
    errors = {};
    directionRpc = (fn, args) async {
      calls.add((fn, args));
      return (data: responses[fn], error: errors[fn]);
    };
  });
  tearDown(() {
    directionRpc = original;
    Backend.ready = false;
  });

  test('accès : la direction n’a aucun écran technique ; finance consolidée en lecture seulement', () {
    final direction = _by('Direction'), finance = _by('Finance'), admin = _by('Admin global'), dept = _by('Resp. département'), support = _by('Support');
    for (final id in ['117', '118', '119', '120', '121', '122', '123', '124', '125', '126', '139', '142', '284', '239']) {
      expect(canOpen(direction, id), isTrue, reason: 'direction : $id');
    }
    // écrans financiers détaillés, consoles techniques et d'administration : refusés à la direction
    for (final id in ['140', '141', '143', '144', '127', '128', '129', '130', '136', '137', '138', '180', '181', '264', '265', '280', '281', '131', '145', '277']) {
      expect(canOpen(direction, id), isFalse, reason: 'direction : $id');
    }
    // validations et encadreurs : ressort du département
    for (final id in ['110', '111', '114']) {
      expect(canOpen(direction, id), isFalse, reason: 'direction : $id');
      expect(canOpen(dept, id), isTrue, reason: 'département : $id');
    }
    for (final id in ['108', '109', '112', '113', '115', '116']) {
      expect(canOpen(direction, id), isTrue, reason: 'direction (lecture) : $id');
    }
    for (final id in ['140', '141', '143', '144']) {
      expect(canOpen(finance, id), isTrue, reason: 'finance : $id');
      expect(canOpen(admin, id), isTrue, reason: 'admin : $id');
    }
    for (final id in ['117', '125', '126']) {
      expect(canOpen(admin, id), isTrue);
      expect(canOpen(dept, id), isFalse);
      expect(canOpen(finance, id), isFalse);
      expect(canOpen(support, id), isFalse);
      expect(canOpen(null, id), isFalse);
    }
  });

  Future<void> monter(WidgetTester t, Widget panel, {Account? compte, bool ready = true, double hauteur = 844}) async {
    Backend.ready = ready;
    GAnim.enabled = false;
    t.view.physicalSize = Size(390, hauteur);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const SizedBox());
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: panel)))),
      GoRoute(path: '/direction/partenariats', builder: (_, _) => const Scaffold(body: Text('page partenariats'))),
      GoRoute(path: '/direction/validations', builder: (_, _) => const Scaffold(body: Text('page validations'))),
      GoRoute(path: '/s/:id', builder: (_, s) => Scaffold(body: Text('écran ${s.pathParameters['id']}'))),
    ]);
    await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    if (compte != null) {
      ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(authProvider.notifier).login(compte);
      await t.pumpAndSettle();
    }
  }

  testWidgets('tableau de bord : chiffres réels consolidés, accès aux partenariats et validations, sans débordement', (t) async {
    responses['direction_dashboard'] = _dash;
    await monter(t, const DirectionDashboardPanel(width: 358, height: 1700), compte: _by('Direction'), hauteur: 1800);
    expect(find.text('87'), findsOneWidget);
    expect(find.text('Étudiants vérifiés'), findsOneWidget);
    expect(find.text('Validations en attente'), findsOneWidget);
    expect(find.text('2026-11'), findsOneWidget);
    expect(find.textContaining('ni donnée personnelle'), findsOneWidget);
    await t.tap(find.text('Validations').first);
    await t.pumpAndSettle();
    expect(find.text('page validations'), findsOneWidget);
  });

  testWidgets('états : hors serveur, non connecté, accès refusé, erreur avec « Réessayer »', (t) async {
    await monter(t, const DirectionDashboardPanel(width: 358, height: 500), compte: _by('Direction'), ready: false);
    expect(find.textContaining('Aucun serveur connecté'), findsOneWidget);
    await monter(t, const DirectionDashboardPanel(width: 358, height: 500));
    expect(find.textContaining('Connectez-vous avec un compte de la direction'), findsOneWidget);
    errors['direction_dashboard'] = 'Réservé à la direction';
    await monter(t, const DirectionDashboardPanel(width: 358, height: 500), compte: _by('Resp. département'));
    expect(find.textContaining('Accès réservé à la direction'), findsOneWidget);
    errors['direction_dashboard'] = 'timeout';
    await monter(t, const DirectionDashboardPanel(width: 358, height: 500), compte: _by('Direction'));
    expect(find.text('Réessayer'), findsOneWidget);
    errors.clear();
    responses['direction_dashboard'] = _dash;
    await t.tap(find.text('Réessayer'));
    await t.pumpAndSettle();
    expect(find.text('87'), findsOneWidget);
  });

  testWidgets('départements : fiche en lecture seule avec projets et partenariats', (t) async {
    responses['direction_departments'] = [
      {'id': 'd1', 'name': 'Génie informatique', 'institution': 'IUT', 'status': 'verified', 'head': 'Doua Dept', 'students': 40, 'students_verified': 31, 'projects': 9, 'innovations': 4, 'projects_pending': 2, 'listings': 12, 'sales': 250000, 'partnerships': 2, 'dept_partnerships': 1},
    ];
    responses['direction_department_detail'] = {
      'id': 'd1', 'name': 'Génie informatique', 'institution': 'IUT', 'status': 'verified', 'heads': ['Doua Dept'], 'students': 40, 'students_verified': 31,
      'recent_projects': [{'id': 'x', 'title': 'Capteur solaire', 'kind': 'innovation', 'owner': 'Awa', 'status': 'approved', 'created_at': '2026-11-01T10:00:00Z'}],
      'partnerships': [{'id': 'p', 'name': 'Camtel', 'kind': 'entreprise', 'status': 'active'}],
    };
    await monter(t, const DirectionDepartmentsPanel(width: 358, height: 700), compte: _by('Direction'));
    expect(find.text('Génie informatique'), findsOneWidget);
    expect(find.text('Responsable : Doua Dept'), findsOneWidget);
    await t.tap(find.text('Génie informatique'));
    await t.pumpAndSettle();
    expect(find.text('Capteur solaire'), findsOneWidget);
    expect(find.textContaining('Camtel'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
    expect(calls.any((c) => c.$1 == 'direction_department_detail' && c.$2['p_id'] == 'd1'), isTrue);
  });

  testWidgets('personnes : lecture seule, recherche, aucune action de compte', (t) async {
    responses['direction_people'] = [
      {'id': 'u1', 'name': 'Awa Ndiaye', 'department': 'Génie informatique', 'level': 'L2', 'verified': true, 'projects': 2},
      {'id': 'u2', 'name': 'Boris Eto', 'department': '', 'level': '', 'verified': false, 'projects': 0},
    ];
    await monter(t, const DirectionPeoplePanel(kinds: ['students', 'responsables', 'mentors'], width: 358, height: 700), compte: _by('Direction'));
    expect(find.text('Awa Ndiaye'), findsOneWidget);
    expect(find.text('Département non renseigné · 0 projet validé'), findsOneWidget);
    expect(find.text('Non vérifié'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'boris');
    await t.pumpAndSettle();
    expect(find.text('Awa Ndiaye'), findsNothing);
    expect(find.textContaining('Suspendre'), findsNothing);
    await t.tap(find.text('Responsables'));
    await t.pumpAndSettle();
    expect(calls.last.$2['p_kind'], 'responsables');
  });

  testWidgets('activités : projets, innovations, productions, événements, offres, ventes', (t) async {
    responses['direction_activity'] = [
      {'id': 'a', 'title': 'Capteur solaire', 'owner': 'Awa', 'department': 'Génie informatique', 'status': 'submitted', 'created_at': '2026-11-01T10:00:00Z'},
    ];
    responses['direction_finance_summary'] = {
      'months': [{'month': '2026-11', 'orders_paid': 3, 'collected': 150000, 'fees': 3000}],
      'totals': {'orders_paid': 3, 'collected': 150000, 'fees': 3000, 'paid_out_30d': 0},
    };
    await monter(t, const DirectionActivityPanel(width: 358, height: 700), compte: _by('Direction'));
    expect(find.text('Capteur solaire'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    await t.tap(find.text('Ventes'));
    await t.pumpAndSettle();
    expect(find.text('2026-11'), findsOneWidget);
    expect(find.textContaining('3 commandes'), findsWidgets);
  });

  testWidgets('partenariats : la direction valide avec confirmation ; le motif d’un refus est obligatoire', (t) async {
    responses['partnerships_list'] = [_partner('proposed'), _partner('active')];
    responses['partnership_decide'] = 'active';
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Direction'));
    expect(find.text('Nouveau partenariat'), findsOneWidget);
    expect(find.text('À valider'), findsWidgets);
    await t.tap(find.text('Orange Cameroun proposed'));
    await t.pumpAndSettle();
    expect(find.text('Valider'), findsOneWidget);
    await t.tap(find.text('Refuser'));
    await t.pumpAndSettle();
    final confirmer = find.widgetWithText(FilledButton, 'Confirmer');
    expect(t.widget<FilledButton>(confirmer).onPressed, isNull, reason: 'refus sans motif impossible');
    await t.enterText(find.byType(TextField), 'Périmètre à préciser');
    await t.pumpAndSettle();
    await t.tap(confirmer);
    await t.pumpAndSettle();
    final c = calls.lastWhere((x) => x.$1 == 'partnership_decide');
    expect(c.$2['p_action'], 'reject');
    expect(c.$2['p_note'], 'Périmètre à préciser');
    expect(c.$2['p_id'], 'p-proposed');
  });

  testWidgets('partenariats : un département propose mais ne décide pas', (t) async {
    responses['partnerships_list'] = [_partner('proposed', mine: true), _partner('active')];
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Resp. département'));
    expect(find.text('Proposer un partenariat'), findsOneWidget);
    expect(find.text('Suivi des départements'), findsNothing);
    await t.tap(find.text('Orange Cameroun active'));
    await t.pumpAndSettle();
    expect(find.text('Valider'), findsNothing);
    expect(find.text('Suspendre'), findsNothing);
    expect(find.text('Modifier'), findsNothing, reason: 'un partenariat actif ne se modifie pas par le département');
    await t.tap(find.text('Fermer'));
    await t.pumpAndSettle();
    await t.tap(find.text('Orange Cameroun proposed'));
    await t.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Valider'), findsNothing);
  });

  testWidgets('partenariats : formulaire contrôlé (nom, dates) puis enregistrement réel', (t) async {
    responses['partnerships_list'] = <Object>[];
    responses['direction_departments'] = [{'id': 'd1', 'name': 'Génie informatique'}];
    responses['partnership_save'] = 'new-id';
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Direction'));
    expect(find.text('Aucun partenariat pour le moment.'), findsOneWidget);
    await t.tap(find.text('Nouveau partenariat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Organisation non inscrite'));
    await t.pumpAndSettle();
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(find.text('Indiquez le nom du partenaire.'), findsOneWidget);
    expect(calls.any((c) => c.$1 == 'partnership_save'), isFalse);
    await t.enterText(find.widgetWithText(TextField, 'Nom du partenaire'), 'ONG Eau Propre');
    await t.enterText(find.widgetWithText(TextField, 'Début (AAAA-MM-JJ)'), '01/12/2026');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(find.text('Les dates doivent être au format AAAA-MM-JJ.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Début (AAAA-MM-JJ)'), '2026-12-01');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    final c = calls.lastWhere((x) => x.$1 == 'partnership_save');
    expect(c.$2['p_name'], 'ONG Eau Propre');
    expect(c.$2['p_starts'], '2026-12-01');
    expect(c.$2['p_id'], isNull);
  });

  testWidgets('validations : accorder ou refuser (motif obligatoire) ; un département ne décide pas', (t) async {
    responses['institutional_validations_list'] = [
      {'id': 'v1', 'kind': 'report', 'subject_id': null, 'department_id': 'd1', 'department': 'Génie informatique', 'title': 'Rapport semestriel', 'details': 'Résultats du semestre', 'requester': 'Doua', 'status': 'pending', 'decision_note': null, 'mine': false, 'created_at': '2026-11-01T10:00:00Z'},
    ];
    responses['institutional_validation_decide'] = 'approved';
    await monter(t, const InstitutionalValidationsPanel(width: 358, height: 760), compte: _by('Direction'));
    expect(find.text('Rapport semestriel'), findsOneWidget);
    await t.tap(find.text('Refuser'));
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Refuser')).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'Dossier incomplet');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Refuser'));
    await t.pumpAndSettle();
    final c = calls.lastWhere((x) => x.$1 == 'institutional_validation_decide');
    expect(c.$2, {'p_id': 'v1', 'p_approve': false, 'p_note': 'Dossier incomplet'});

    await monter(t, const InstitutionalValidationsPanel(width: 358, height: 760), compte: _by('Resp. département'));
    expect(find.text('Accorder'), findsNothing);
    expect(find.text('Nouvelle demande'), findsOneWidget);
  });

  testWidgets('rapport consolidé : indicateurs, départements, performances et export', (t) async {
    responses['direction_consolidated_report'] = {
      'from': '2026-01-01', 'to': '2026-11-17', 'generated_by': 'Directrice', 'generated_at': '2026-11-17T10:00:00Z',
      'lines': [
        {'section': 'Étudiants', 'indicator': 'Étudiants vérifiés (total)', 'department': '', 'value': 87},
        {'section': 'Commerce', 'indicator': 'Montant encaissé sur la période (FCFA)', 'department': '', 'value': 1250000},
        {'section': 'Départements', 'indicator': 'Étudiants vérifiés', 'department': 'Génie informatique', 'value': 31},
      ],
    };
    responses['direction_performance'] = {
      'periods': {'projects': {'current': 8, 'previous': 5}, 'orders': {'current': 3, 'previous': 3}, 'students': {'current': 9, 'previous': 4}, 'applications': {'current': 20, 'previous': 10}},
      'validation_rate': 80,
      'departments': [{'id': 'd1', 'name': 'Génie informatique', 'approval_rate': 75, 'projects_per_100_students': 40, 'active_sellers': 6, 'sales': 250000, 'partnerships': 2}],
    };
    await monter(t, const DirectionReportPanel(width: 358, height: 760), compte: _by('Direction'));
    expect(find.text('Étudiants vérifiés (total)'), findsOneWidget);
    expect(find.text('Exporter (CSV)'), findsOneWidget);
    expect(find.text('Par département'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Taux de validation des projets : 80 %'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Taux de validation des projets : 80 %'), findsOneWidget);
    await t.tap(find.text('30 derniers jours'));
    await t.pumpAndSettle();
    final c = calls.lastWhere((x) => x.$1 == 'direction_consolidated_report');
    expect(c.$2['p_from'], isNot(startsWith('${DateTime.now().year}-01-01')));
  });

  testWidgets('journal des décisions et registre consolidé : lecture seule', (t) async {
    responses['direction_decisions_journal'] = [
      {'id': 1, 'kind': 'partnership', 'title': 'Orange', 'action': 'Partenariat validé', 'note': 'Convention signée', 'department': 'Génie informatique', 'actor': 'Directrice', 'created_at': '2026-11-01T10:00:00Z'},
    ];
    await monter(t, const DirectionDecisionsPanel(width: 358, height: 600), compte: _by('Direction'));
    expect(find.text('Partenariat validé · Orange'), findsOneWidget);
    expect(find.text('Motif : Convention signée'), findsOneWidget);

    responses['direction_finance_summary'] = {
      'months': [{'month': '2026-11', 'orders_paid': 2, 'collected': 150000, 'fees': 3000}],
      'totals': {'orders_paid': 2, 'collected': 150000, 'fees': 3000, 'paid_out_30d': 0},
    };
    await monter(t, const DirectionRegisterPanel(width: 358, height: 700), compte: _by('Direction'));
    expect(find.textContaining('Lecture seule'), findsOneWidget);
    expect(find.text('2026-11'), findsOneWidget);
  });

  testWidgets('écran 284 : registre consolidé pour la direction, journal détaillé pour la finance', (t) async {
    responses['direction_finance_summary'] = {'months': <Object>[], 'totals': {'orders_paid': 0, 'collected': 0, 'fees': 0, 'paid_out_30d': 0}};
    Widget vue() => Consumer(builder: (context, ref, _) => financialRegisterView(ref, width: 358, height: 600));
    await monter(t, vue(), compte: _by('Direction'));
    expect(find.byType(DirectionRegisterPanel), findsOneWidget);
    expect(find.byType(MobileList), findsNothing);
    await monter(t, vue(), compte: _by('Finance'));
    expect(find.byType(DirectionRegisterPanel), findsNothing);
    expect(find.byType(MobileList), findsOneWidget);
  });

  testWidgets('sponsoring : consolidé pour la direction', (t) async {
    responses['direction_sponsors_report'] = {
      'total': 900000, 'students': 4, 'sponsors': 1,
      'rows': [{'sponsor': 'Orange Cameroun', 'title': 'Serre intelligente', 'department': 'Informatique', 'amount': 900000, 'students': 4, 'outcome': 'Prototype livré', 'status': 'termine', 'year': 2026}],
    };
    await monter(t, const SponsorReportByRole(width: 358, height: 700), compte: _by('Direction'));
    expect(find.text('Serre intelligente'), findsOneWidget);
    expect(find.text('Résultat : Prototype livré'), findsOneWidget);
    expect(calls.any((c) => c.$1 == 'direction_sponsors_report'), isTrue);
  });
  testWidgets('écrans web 117, 122, 123, 125, 126, 239 et 284 : contenu réel de la direction, jamais la maquette', (t) async {
    responses['direction_dashboard'] = _dash;
    responses['institutional_validations_list'] = <Object>[];
    responses['direction_activity'] = <Object>[];
    responses['direction_consolidated_report'] = {'from': '2026-01-01', 'to': '2026-11-17', 'generated_by': 'Directrice', 'lines': [{'section': 'Étudiants', 'indicator': 'Étudiants vérifiés (total)', 'department': '', 'value': 87}]};
    responses['direction_performance'] = {'periods': {}, 'validation_rate': null, 'departments': <Object>[]};
    responses['direction_decisions_journal'] = <Object>[];
    responses['direction_sponsors_report'] = {'total': 0, 'students': 0, 'sponsors': 0, 'rows': <Object>[]};
    responses['direction_finance_summary'] = {'months': <Object>[], 'totals': {'orders_paid': 0, 'collected': 0, 'fees': 0, 'paid_out_30d': 0}};
    responses['finance_overview'] = {'collected': 0, 'orders_paid': 0, 'to_verify': 0, 'due': 0, 'paid_out_30d': 0, 'months': <Object>[]};
    Future<void> voir(Widget ecran, Size taille, List<String> textes) async {
      Backend.ready = true;
      GAnim.enabled = false;
      GScreen.mockupFrame = false;
      t.view.physicalSize = taille;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(ProviderScope(child: MaterialApp(home: ecran)));
      await t.pumpAndSettle();
      ProviderScope.containerOf(t.element(find.byWidget(ecran))).read(authProvider.notifier).login(_by('Direction'));
      await t.pumpAndSettle();
      for (final s in textes) {
        expect(find.textContaining(s), findsWidgets, reason: s);
      }
    }

    addTearDown(t.view.reset);
    addTearDown(() => GScreen.mockupFrame = true);
    await voir(const G_117(), const Size(1280, 890), ['Étudiants vérifiés', 'Partenariats actifs']);
    await voir(const G_122(), const Size(1280, 890), ['Aucune validation en attente']);
    await voir(const G_123(), const Size(1280, 890), ['Aucune activité à afficher']);
    await voir(const G_125(), const Size(1280, 890), ['Étudiants vérifiés (total)', 'Exporter (CSV)']);
    await voir(const G_126(), const Size(1280, 890), ['Aucune décision institutionnelle']);
    await voir(const G_239(), const Size(1280, 866), ['Aucun sponsoring enregistré']);
    await voir(const G_284(), const Size(390, 844), ['Lecture seule']);
  });}
