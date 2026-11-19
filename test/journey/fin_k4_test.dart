import 'dart:io';

import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/direction.dart';
import 'package:boutik_ecole/figma/live/org_partnerships.dart';
import 'package:boutik_ecole/figma/live/partnership_org_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Lot K4 : rattachement d'une organisation aux partenariats (formulaire de la direction, choix inscrite / non inscrite, espace de l'organisation)
/// et libellés (plus d'acteur « Entreprise » dans l'interface). 390 px : une erreur de mise en page fait échouer le test.

Account _by(String staff) => seedAccounts.firstWhere((a) => a.staff == staff);

const _orgs = [
  {'id': 'o-rival', 'name': 'Rival SA', 'org_type': 'entreprise_commerciale', 'type_label': 'Entreprise commerciale', 'city': 'Douala'},
  {'id': 'o-amis', 'name': 'Association Les Amis', 'org_type': 'association', 'type_label': 'Association', 'city': 'Bafoussam'},
];

Map<String, dynamic> _org(String name, {String source = 'institution', String status = 'active', String response = 'pending', bool can = true, String? note}) => {
      'source': source, 'id': 'id-$name', 'name': name, 'kind': 'entreprise', 'status': status, 'department': 'Génie informatique', 'objective': 'Stages et recrutement',
      'domains': ['stages'], 'starts_on': '2026-12-01', 'ends_on': '2027-12-01', 'students': 0, 'org_response': response, 'org_response_note': note, 'org_responded_at': null,
      'decision_note': null, 'updated_at': '2026-11-20T10:00:00Z', 'can_respond': can,
    };

void main() {
  setUpAll(loadAppFonts);
  final original = directionRpc;
  final calls = <(String, Map<String, dynamic>)>[];
  var responses = <String, Object?>{};

  setUp(() {
    calls.clear();
    responses = {'partnership_org_search': _orgs, 'direction_departments': [{'id': 'd1', 'name': 'Génie informatique'}], 'partnership_save': 'new-id'};
    directionRpc = (fn, args) async {
      calls.add((fn, args));
      return (data: responses[fn], error: null);
    };
  });
  tearDown(() {
    directionRpc = original;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget page, {Account? compte, List<Override> overrides = const [], double h = 844}) async {
    GAnim.enabled = false;
    t.view.physicalSize = Size(390, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const SizedBox());
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: page))))]);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    if (compte != null) {
      ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(authProvider.notifier).login(compte);
      await t.pumpAndSettle();
    }
  }

  testWidgets('formulaire direction : organisation inscrite par défaut, recherche serveur, nom public seulement', (t) async {
    Backend.ready = true;
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Direction'));
    await t.tap(find.text('Nouveau partenariat'));
    await t.pumpAndSettle();
    expect(find.text('Organisation inscrite'), findsOneWidget);
    expect(find.text('Organisation non inscrite'), findsOneWidget);
    expect(find.text('Rival SA'), findsOneWidget);
    expect(find.text('Entreprise commerciale · Douala'), findsOneWidget);
    expect(find.textContaining('Le nom et le type du partenaire sont repris'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nom du partenaire'), findsNothing, reason: 'le nom vient de la fiche');
    expect(calls.where((c) => c.$1 == 'partnership_org_search').length, 1);
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(find.textContaining('Choisissez une organisation inscrite'), findsOneWidget);
    expect(calls.any((c) => c.$1 == 'partnership_save'), isFalse);
  });

  testWidgets('formulaire direction : le choix d\'une organisation inscrite envoie son identifiant, jamais un nom libre', (t) async {
    Backend.ready = true;
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Direction'));
    await t.tap(find.text('Nouveau partenariat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Association Les Amis'));
    await t.pumpAndSettle();
    expect(find.text('Changer'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    final c = calls.lastWhere((x) => x.$1 == 'partnership_save');
    expect(c.$2['p_company_owner'], 'o-amis');
    expect(c.$2['p_name'], 'Association Les Amis');
  });

  testWidgets('formulaire direction : organisation non inscrite = nom et type libres, aucun lien', (t) async {
    Backend.ready = true;
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Direction'));
    await t.tap(find.text('Nouveau partenariat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Organisation non inscrite'));
    await t.pumpAndSettle();
    expect(find.textContaining('n’est pas notifiée'), findsOneWidget);
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    expect(find.text('Indiquez le nom du partenaire.'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Nom du partenaire'), 'Cabinet Externe');
    await t.tap(find.text('Enregistrer'));
    await t.pumpAndSettle();
    final c = calls.lastWhere((x) => x.$1 == 'partnership_save');
    expect(c.$2['p_company_owner'], isNull);
    expect(c.$2['p_name'], 'Cabinet Externe');
  });

  testWidgets('sélecteur : recherche vide et erreur lisibles (réessayer), sans débordement', (t) async {
    var fail = true;
    await monter(
      t,
      PartnershipOrgPicker(
        registered: true,
        selected: null,
        onMode: (_) {},
        onSelect: (_) {},
        search: (q) async => fail ? (data: null, error: 'Réseau indisponible') : (data: <Object>[], error: null),
      ),
    );
    expect(find.textContaining('Réseau indisponible'), findsOneWidget);
    fail = false;
    await t.tap(find.text('Réessayer'));
    await t.pumpAndSettle();
    expect(find.textContaining('Aucune organisation approuvée ne correspond'), findsOneWidget);
  });

  testWidgets('liste de la direction : organisation inscrite distinguée et réponse de l\'organisation visible', (t) async {
    responses['partnerships_list'] = [
      {
        'id': 'p1', 'name': 'Orange Cameroun', 'kind': 'entreprise', 'status': 'active', 'department_id': 'd1', 'department': 'Génie informatique', 'organization_id': 'o7', 'organization_name': 'Orange Cameroun',
        'organization_registered': true, 'company': 'Orange Cameroun', 'org_response': 'contested', 'org_response_note': 'Dates à revoir', 'contact_name': '', 'contact_email': '', 'contact_phone': '',
        'objective': '', 'domains': [], 'starts_on': null, 'ends_on': null, 'decision_note': null, 'decided_at': null, 'proposer': 'Doua', 'mine': false, 'created_at': '2026-11-01T10:00:00Z',
      },
      {
        'id': 'p2', 'name': 'Cabinet Externe', 'kind': 'autre', 'status': 'active', 'department_id': null, 'department': null, 'organization_id': null, 'organization_name': 'Cabinet Externe',
        'organization_registered': false, 'company': 'Cabinet Externe', 'org_response': 'none', 'org_response_note': null, 'contact_name': '', 'contact_email': '', 'contact_phone': '',
        'objective': '', 'domains': [], 'starts_on': null, 'ends_on': null, 'decision_note': null, 'decided_at': null, 'proposer': 'Doua', 'mine': false, 'created_at': '2026-11-01T10:00:00Z',
      },
    ];
    Backend.ready = true;
    await monter(t, const PartnershipsPanel(width: 358, height: 760), compte: _by('Direction'));
    expect(find.textContaining('Organisation inscrite · Contesté par l’organisation'), findsOneWidget);
    await t.tap(find.text('Orange Cameroun'));
    await t.pumpAndSettle();
    expect(find.textContaining('Contesté par l’organisation : Dates à revoir'), findsOneWidget);
    await t.tap(find.text('Fermer'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cabinet Externe'));
    await t.pumpAndSettle();
    expect(find.textContaining('Organisation non inscrite sur Boutik-École : Cabinet Externe'), findsOneWidget);
  });

  group('espace de l\'organisation', () {
    Override rows(List<Map<String, dynamic>> l) => orgPartnershipsProvider.overrideWith((ref) async => l);

    testWidgets('liste : partenariat à confirmer avec Accepter / Contester, motif obligatoire pour contester', (t) async {
      await monter(t, const OrgPartnershipsScreen(), overrides: [rows([_org('Convention stages')])]);
      expect(find.text('Convention stages'), findsOneWidget);
      expect(find.text('À confirmer par vous'), findsOneWidget);
      expect(find.text('Accepter'), findsOneWidget);
      await t.tap(find.text('Contester'));
      await t.pumpAndSettle();
      final confirmer = find.widgetWithText(FilledButton, 'Contester');
      expect(t.widget<FilledButton>(confirmer).onPressed, isNull, reason: 'contestation sans motif impossible');
      await t.enterText(find.byType(TextField), 'abc');
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(confirmer).onPressed, isNull);
      await t.enterText(find.byType(TextField), 'Les dates sont fausses');
      await t.pumpAndSettle();
      expect(t.widget<FilledButton>(confirmer).onPressed, isNotNull);
    });

    testWidgets('un lecteur consulte sans pouvoir répondre ; un partenariat suspendu ne se confirme plus', (t) async {
      await monter(t, const OrgPartnershipsScreen(), overrides: [
        rows([_org('Partenariat A', can: false), _org('Partenariat B', status: 'suspended', response: 'accepted', can: false)]),
      ]);
      expect(find.text('Partenariat A'), findsOneWidget);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Contester'), findsNothing);
      expect(find.text('Suspendu'), findsOneWidget);
    });

    testWidgets('état vide et erreur de chargement : messages clairs, rien d\'inventé', (t) async {
      await monter(t, const OrgPartnershipsScreen(), overrides: [rows(const [])]);
      expect(find.textContaining('Aucun partenariat pour le moment'), findsOneWidget);
      await monter(t, const OrgPartnershipsScreen(), overrides: [orgPartnershipsProvider.overrideWith((ref) async => throw MarcheFailure())]);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  test('libellés : plus d\'acteur « Entreprise » dans les écrans modifiés par le lot K4', () {
    const banned = ['Appel à entreprises', 'Espace entreprise', 'Profil de l’entreprise', 'Bienvenue, entreprise', 'Vous suivez cette entreprise'];
    final root = Directory('lib/figma');
    final hits = <String>[];
    for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      for (final b in banned) {
        if (s.contains("'$b") && !s.contains('legacyTitle')) hits.add('${f.path}: $b');
      }
    }
    expect(hits, isEmpty);
  });
}

class MarcheFailure implements Exception {
  @override
  String toString() => 'offline';
}
