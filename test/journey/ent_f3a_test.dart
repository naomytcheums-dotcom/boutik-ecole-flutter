import 'package:boutik_ecole/core/router/paths.dart';
import 'package:boutik_ecole/figma/g/g_187.dart';
import 'package:boutik_ecole/figma/g/g_188.dart';
import 'package:boutik_ecole/figma/g/g_189.dart';
import 'package:boutik_ecole/figma/g/g_190.dart';
import 'package:boutik_ecole/figma/g/g_262.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/b2b_screens.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_home.dart';
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/store.dart' show fcfa;
import 'package:boutik_ecole/figma/live/talent_search_panel.dart';
import 'package:boutik_ecole/figma/live/tp_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

typedef _Rows = List<Map<String, dynamic>>;

/// Liste serveur simulée : compte les relectures demandées et peut simuler un échec ou une lecture en cours.
class _Fake extends RpcRows {
  _Fake(super.fn, this.v, {this.fail = false});
  final _Rows? v;
  final bool fail;
  static final calls = <String, int>{};

  @override
  _Rows? build() {
    error = fail;
    return fail ? const [] : v;
  }

  @override
  Future<void> refresh() async => calls[fn] = (calls[fn] ?? 0) + 1;
}

class _Api extends B2bApi {
  final decisions = <(String, bool)>[];
  final saved = <(String, String)>[];
  @override
  Future<String?> decide(String id, bool accept) async {
    decisions.add((id, accept));
    return null;
  }

  @override
  Future<Map<String, dynamic>?> proposalDetail(String id) async => {'author_id': 'stu-1', 'message': 'Je peux livrer le logo en une journée.', 'budget_min': 50000, 'budget_max': 100000};

  @override
  Future<bool> saveText(String name, String content, String mime) async {
    saved.add((name, content));
    return true;
  }
}

final _missions = <Map<String, dynamic>>[
  {'number': 'M1', 'title': 'Logo de la boutique', 'status': 'published', 'created_at': '2026-11-10T10:00:00Z', 'deadline': null, 'proposals': 1},
  {'number': 'M2', 'title': 'Site vitrine', 'status': 'assigned', 'created_at': '2026-11-01T10:00:00Z', 'deadline': '2099-01-31', 'proposals': 3},
  {'number': 'M3', 'title': 'Ancien besoin retiré', 'status': 'cancelled', 'created_at': '2026-10-01T10:00:00Z', 'deadline': null, 'proposals': 0},
];
final _proposals = <Map<String, dynamic>>[
  {'id': 'p1', 'mission': 'Logo de la boutique', 'author': 'Alice Test', 'amount': 80000, 'delay_days': 1, 'status': 'submitted', 'created_at': '2026-11-12T10:00:00Z'},
  {'id': 'p2', 'mission': 'Site vitrine', 'author': 'Brice Ndoumbe', 'amount': 120000, 'delay_days': 10, 'status': 'accepted', 'created_at': '2026-11-02T10:00:00Z'},
  {'id': 'p3', 'mission': 'Site vitrine', 'author': 'Carine Eto', 'amount': 90000, 'delay_days': 7, 'status': 'declined', 'created_at': '2026-11-03T10:00:00Z'},
];
final _quotes = <Map<String, dynamic>>[
  {'id': 'q1', 'brief': 'Borne solaire', 'status': 'requested', 'quote_amount': null, 'created_at': '2026-11-11T10:00:00Z', 'provider_name': 'Atelier Solaire', 'listings': {'title': 'Installation de borne'}},
  {'id': 'q2', 'brief': 'Affiches', 'status': 'quoted', 'quote_amount': 45000, 'quote_delay_days': 1, 'valid_until': '2099-01-01T00:00:00Z', 'created_at': '2026-11-09T10:00:00Z', 'provider_name': 'Studio Print'},
  {'id': 'q3', 'brief': 'Vidéo', 'status': 'rejected', 'decline_reason': 'Agenda complet', 'created_at': '2026-11-08T10:00:00Z', 'provider_name': 'Ciné IUT'},
  {'id': 'q4', 'brief': 'Flyers', 'status': 'cancelled', 'created_at': '2026-11-07T10:00:00Z'},
  {'id': 'q5', 'brief': 'Maquette', 'status': 'expired', 'created_at': '2026-10-07T10:00:00Z'},
];

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    GScreen.mockupFrame = false;
    _Fake.calls.clear();
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  List<Override> data({_Rows? missions, _Rows? proposals, _Rows? quotes, bool fail = false, _Api? api}) => [
        companyMissionsProvider.overrideWith(() => _Fake('company_missions', missions, fail: fail)),
        companyProposalsProvider.overrideWith(() => _Fake('company_proposals', proposals, fail: fail)),
        b2bQuotesProvider.overrideWith(() => _Fake('my_quotes', quotes, fail: fail)),
        quotesListProvider.overrideWith(() => _Fake('table:quote_requests', const [])),
        companyDashboardProvider.overrideWith((ref) async => {'company_name': 'Orange Cameroun'}),
        if (api != null) b2bApiProvider.overrideWithValue(api),
      ];

  final visited = <String>[];
  Future<ProviderContainer> monter(WidgetTester t, String id, {List<Override> overrides = const [], Size size = const Size(390, 844)}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    visited.clear();
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: screenPath(id), routes: [
      GoRoute(
        path: '/s/:id',
        builder: (_, s) {
          final n = s.pathParameters['id']!;
          visited.add(n);
          return switch (n) {
            '187' => const G_187(),
            '188' => const G_188(),
            '189' => const G_189(),
            '190' => const G_190(),
            '262' => const G_262(),
            _ => Scaffold(body: Text('écran $n')),
          };
        },
      ),
      GoRoute(path: '/etudiant/:id', builder: (_, s) => Scaffold(body: Text('profil ${s.pathParameters['id']}'))),
    ]);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    c.read(authProvider.notifier).login(demoAccount);
    await t.pumpAndSettle();
    return c;
  }

  void conforme(WidgetTester t, {bool horizontal = true}) {
    expect(t.takeException(), isNull, reason: 'aucun overflow ni erreur');
    if (horizontal) {
      final h = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal);
      final inFields = find.descendant(of: find.byType(EditableText), matching: h);
      expect(h.evaluate().length - inFields.evaluate().length, 0, reason: 'aucun défilement horizontal');
    }
    for (final r in t.widgetList<RichText>(find.byType(RichText))) {
      final size = r.text.style?.fontSize;
      if (size != null && r.text.toPlainText().trim().isNotEmpty) expect(size, greaterThanOrEqualTo(12), reason: 'texte « ${r.text.toPlainText()} » trop petit');
    }
    for (final w in t.widgetList<B2bTap>(find.byType(B2bTap))) {
      final s = t.getSize(find.byWidget(w));
      expect(s.height, greaterThanOrEqualTo(47.99), reason: 'cible tactile ${w.label}');
      expect(s.width, greaterThanOrEqualTo(47.99), reason: 'cible tactile ${w.label}');
    }
    for (final b in find.byType(TpButton).evaluate()) {
      expect(t.getSize(find.byWidget(b.widget)).height, greaterThanOrEqualTo(47.99));
    }
  }

  group('mobile 390 px : pas de toile réduite, mise en page native conforme', () {
    for (final id in ['187', '188', '189', '190', '262']) {
      // 188 héberge TalentSearchPanel (lot F4) : ses propres pastilles de filtre ne dépendent pas de cet écran.
      final strict = id != '188';
      testWidgets('$id : conforme avec des données réelles', (t) async {
        await monter(t, id, overrides: data(missions: _missions, proposals: _proposals, quotes: _quotes));
        conforme(t, horizontal: strict);
        expect(find.byType(GScreen), findsNothing);
        expect(find.textContaining('Analytique'), findsNothing);
        expect(find.text('+3'), findsNothing);
      });
      testWidgets('$id : état de chargement', (t) async {
        await monter(t, id, overrides: data(missions: null, proposals: null, quotes: null));
        if (strict) expect(find.text('Chargement…'), findsOneWidget);
        conforme(t, horizontal: strict);
      });
      testWidgets('$id : état vide', (t) async {
        await monter(t, id, overrides: data(missions: const [], proposals: const [], quotes: const []));
        conforme(t, horizontal: strict);
      });
      testWidgets('$id : état d’erreur', (t) async {
        await monter(t, id, overrides: data(fail: true));
        if (strict) expect(find.text('Cette liste ne peut pas être chargée pour le moment.'), findsOneWidget);
        conforme(t, horizontal: strict);
      });
    }
  });

  testWidgets('187 : indicateurs réels, sans chiffre de maquette ni nom du compte en double', (t) async {
    await monter(t, '187', overrides: data(missions: _missions, proposals: _proposals, quotes: _quotes));
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Propositions à examiner'), findsOneWidget);
    expect(find.text('Besoins ouverts'), findsOneWidget);
    expect(find.text('Besoins pourvus'), findsOneWidget);
    expect(find.text('Devis en attente'), findsOneWidget);
    expect(find.text('23'), findsNothing);
    expect(find.textContaining('Ancien besoin retiré'), findsNothing, reason: 'un besoin annulé ne compte pas');
    expect(find.text('Logo de la boutique'), findsWidgets);
  });

  test('B2bStats : décomptes par statut, devis et échéances', () {
    final s = B2bStats.from(missions: _missions, proposals: _proposals, quotes: _quotes, now: DateTime(2099, 1, 28));
    expect((s.needsOpen, s.needsFilled, s.needsDraft), (1, 1, 0));
    expect((s.proposalsTotal, s.proposalsPending, s.proposalsAccepted, s.proposalsDeclined), (3, 1, 1, 1));
    expect((s.quotesWaiting, s.quotesReceived), (1, 1));
    expect(s.deadlinesSoon, 1);
    expect(B2bStats.from(missions: _missions, proposals: _proposals, now: DateTime(2026, 11, 17)).quotesWaiting, isNull);
  });

  test('formats : montants, pluriel, statuts traduits', () {
    expect(b2bMoney(80000), fcfa(80000));
    expect(b2bMoney(null), '—');
    expect(b2bDays(1), '1 jour');
    expect(b2bDays(7), '7 jours');
    expect(['rejected', 'cancelled', 'expired'].map(b2bQuoteStatus), ['Décliné par le prestataire', 'Annulé', 'Expiré']);
    expect(b2bMissionStatus('cancelled'), 'Annulé');
    expect(b2bCsv(['A'], [['=2+2', 'x"y']]), '"A"\r\n"\'=2+2";"x""y"');
  });

  testWidgets('189 : montants formatés, pluriel, onglets qui filtrent réellement', (t) async {
    await monter(t, '189', overrides: data(proposals: _proposals));
    expect(find.text('${fcfa(80000)} · 1 jour'), findsOneWidget);
    expect(find.text('${fcfa(120000)} · 10 jours'), findsOneWidget);
    await t.tap(find.text('Acceptées (1)'));
    await t.pumpAndSettle();
    expect(find.text('Brice Ndoumbe'), findsOneWidget);
    expect(find.text('Alice Test'), findsNothing);
    await t.tap(find.text('À examiner (1)'));
    await t.pumpAndSettle();
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Brice Ndoumbe'), findsNothing);
    await t.tap(find.text('Refusées (1)'));
    await t.pumpAndSettle();
    expect(find.text('Carine Eto'), findsOneWidget);
    conforme(t);
  });

  testWidgets('189 : fiche de proposition, Accepter avec confirmation appelle decide_proposal puis relit', (t) async {
    final api = _Api();
    await monter(t, '189', overrides: data(proposals: _proposals, missions: _missions, api: api));
    await t.tap(find.text('Alice Test'));
    await t.pumpAndSettle();
    expect(find.text('Je peux livrer le logo en une journée.'), findsOneWidget);
    expect(find.text('Voir le profil'), findsOneWidget);
    expect(find.textContaining('${fcfa(50000)} – ${fcfa(100000)}'), findsOneWidget);
    conforme(t);
    await t.tap(find.text('Accepter la proposition'));
    await t.pumpAndSettle();
    expect(find.text('Accepter cette proposition ?'), findsOneWidget);
    expect(api.decisions, isEmpty, reason: 'rien n’est envoyé avant la confirmation');
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(api.decisions, isEmpty);
    await t.tap(find.text('Accepter la proposition'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Accepter'));
    await t.pumpAndSettle();
    expect(api.decisions, [('p1', true)]);
    expect(_Fake.calls['company_proposals'], isNotNull, reason: 'la liste est relue après la décision');
    expect(find.text('Accepter la proposition'), findsNothing, reason: 'fiche fermée');
  });

  testWidgets('189 : Refuser demande confirmation ; proposition déjà traitée sans décision', (t) async {
    final api = _Api();
    await monter(t, '189', overrides: data(proposals: _proposals, api: api));
    await t.tap(find.text('Alice Test'));
    await t.pumpAndSettle();
    await t.tap(find.text('Refuser'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Refuser'));
    await t.pumpAndSettle();
    expect(api.decisions, [('p1', false)]);
    await t.tap(find.text('Brice Ndoumbe'));
    await t.pumpAndSettle();
    expect(find.text('Accepter la proposition'), findsNothing);
    expect(find.textContaining('déjà traitée'), findsOneWidget);
  });

  testWidgets('189 : un échec du serveur n’annonce aucun succès', (t) async {
    final api = _Failing();
    await monter(t, '189', overrides: data(proposals: _proposals, api: api));
    await t.tap(find.text('Alice Test'));
    await t.pumpAndSettle();
    await t.tap(find.text('Accepter la proposition'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Accepter'));
    await t.pumpAndSettle();
    expect(find.text('Ce besoin est déjà attribué'), findsOneWidget);
    expect(find.text('Accepter la proposition'), findsOneWidget, reason: 'la fiche reste ouverte');
    expect(find.textContaining('Proposition acceptée'), findsNothing);
  });

  testWidgets('190 : onglets par statut réel et statuts traduits en français', (t) async {
    await monter(t, '190', overrides: data(quotes: _quotes));
    expect(find.text('Installation de borne'), findsOneWidget);
    expect(find.text('${fcfa(45000)} · 1 jour'), findsOneWidget);
    await t.tap(find.text('Clos (3)'));
    await t.pumpAndSettle();
    expect(find.text('Décliné par le prestataire'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
    expect(find.text('Expiré'), findsOneWidget);
    expect(find.text('rejected'), findsNothing);
    expect(find.text('Installation de borne'), findsNothing);
    await t.tap(find.text('Devis reçus (1)'));
    await t.pumpAndSettle();
    expect(find.text('Affiches'), findsOneWidget);
    conforme(t);
  });

  testWidgets('navigation : onglets et menu « Plus » mènent aux écrans 187, 189, 190, 188, 90, 262', (t) async {
    await monter(t, '187', overrides: data(missions: _missions, proposals: _proposals, quotes: _quotes));
    await t.tap(find.text('Propositions').last);
    await t.pumpAndSettle();
    expect(visited.last, '189');
    await t.tap(find.text('Devis').last);
    await t.pumpAndSettle();
    expect(visited.last, '190');
    await t.tap(find.text('Talents').last);
    await t.pumpAndSettle();
    expect(visited.last, '188');
    await t.tap(find.text('Tableau').last);
    await t.pumpAndSettle();
    expect(visited.last, '187');
    await t.tap(find.text('Plus'));
    await t.pumpAndSettle();
    await t.tap(find.text('Publier un besoin').last);
    await t.pumpAndSettle();
    expect(find.text('écran 90'), findsOneWidget);
  });

  testWidgets('187 : les tuiles et « Voir tout » ouvrent les vrais écrans', (t) async {
    await monter(t, '187', overrides: data(missions: _missions, proposals: _proposals, quotes: _quotes));
    await t.tap(find.text('Devis reçus'));
    await t.pumpAndSettle();
    expect(visited.last, '190');
  });

  Finder tap(String label) => find.byWidgetPredicate((w) => w is B2bTap && w.label == label);

  testWidgets('Actualiser relit réellement les données avant d’annoncer un succès', (t) async {
    await monter(t, '189', overrides: data(proposals: _proposals, missions: _missions));
    _Fake.calls.clear();
    await t.tap(tap('Actualiser'));
    await t.pumpAndSettle();
    expect(_Fake.calls['company_proposals'], 1);
    expect(_Fake.calls['company_missions'], 1);
    expect(_Fake.calls['my_quotes'], 1);
    expect(find.textContaining('Données relues sur le serveur'), findsOneWidget);
  });

  testWidgets('Exporter : le CSV contient les données réelles de la liste', (t) async {
    final api = _Api();
    await monter(t, '189', overrides: data(proposals: _proposals, api: api));
    await t.tap(tap('Exporter en CSV'));
    await t.pumpAndSettle();
    expect(api.saved.single.$1, 'propositions-recues.csv');
    expect(api.saved.single.$2, contains('"Alice Test";"Logo de la boutique";"80000";"1";"À examiner"'));
    expect(find.textContaining('téléchargé'), findsOneWidget);
  });

  testWidgets('188 : héberge la recherche réelle, sans talent inventé ni cœur local', (t) async {
    await monter(t, '188', overrides: data());
    expect(find.byType(TalentSearchPanel), findsOneWidget);
    expect(find.byType(TextField), findsWidgets, reason: 'le champ de recherche est actif');
    expect(find.text('Génie informatique'), findsNothing);
    expect(find.text('Enregistrer la recherche'), findsNothing);
    expect(find.byType(GHeart), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('262 : résumé réel et vrais boutons d’action', (t) async {
    await monter(t, '262', overrides: data(missions: _missions, proposals: _proposals, quotes: _quotes));
    expect(find.text('Publier un besoin'), findsOneWidget);
    expect(find.text('Lancer un défi'), findsOneWidget);
    expect(find.text('Publier une offre'), findsOneWidget);
    expect(find.text('Rechercher des talents'), findsOneWidget);
    await t.tap(find.text('Publier un besoin'));
    await t.pumpAndSettle();
    expect(find.text('écran 90'), findsOneWidget);
  });

  group('rendu large (1280 px) en production : toile nettoyée', () {
    const big = Size(1280, 900);
    for (final id in ['187', '188', '189', '190', '262']) {
      testWidgets('$id : plus d’élément de maquette trompeur, contenu réel', (t) async {
        await monter(t, id, size: big, overrides: data(missions: _missions, proposals: _proposals, quotes: _quotes));
        expect(find.text('Analytique · données en direct'), findsNothing);
        expect(find.text('+3'), findsNothing);
        expect(find.text('Exporter'), findsNothing);
        expect(find.text('Personnaliser la vue'), findsNothing);
        expect(find.text('Génie informatique'), findsNothing);
        expect(find.text('Mme Nguimfack'), findsNothing);
        expect(find.text('Orange Cameroun'), findsWidgets, reason: 'nom réel de l’entreprise dans la carte utilisateur');
        expect(t.takeException(), isNull);
      });
    }
    testWidgets('189 : liste réelle visible', (t) async {
      await monter(t, '189', size: big, overrides: data(proposals: _proposals));
      expect(find.text('Alice Test'), findsOneWidget);
      expect(find.text('${fcfa(80000)} · 1 jour'), findsOneWidget);
    });
  });
}

class _Failing extends _Api {
  @override
  Future<String?> decide(String id, bool accept) async => 'Ce besoin est déjà attribué';
}
