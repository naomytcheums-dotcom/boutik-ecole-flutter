import 'package:boutik_ecole/figma/g/g_285.dart';
import 'package:boutik_ecole/figma/g/g_88.dart';
import 'package:boutik_ecole/figma/g/g_93.dart';
import 'package:boutik_ecole/figma/g/g_93b.dart';
import 'package:boutik_ecole/figma/g/g_94.dart';
import 'package:boutik_ecole/figma/g/g_96.dart';
import 'package:boutik_ecole/figma/g/g_97.dart';
import 'package:boutik_ecole/figma/g/g_98.dart';
import 'package:boutik_ecole/figma/g/g_99.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_screens.dart' show companyProvider;
import 'package:boutik_ecole/figma/live/console.dart';
import 'package:boutik_ecole/figma/live/ent_f3b.dart';
import 'package:boutik_ecole/figma/live/entreprise.dart';
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:boutik_ecole/figma/live/need_pages.dart';
import 'package:boutik_ecole/figma/live/opportunites_screens.dart' show oppMyPostedProvider;
import 'package:boutik_ecole/figma/live/store.dart' show fcfa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Lot F3b : écrans entreprise 88, 93, 93b, 94, 96, 97, 98, 99, 285 et formulaire de besoin, à 390 px de large (aucun débordement : une erreur de
/// mise en page fait échouer le test), avec des lectures serveur simulées par surcharge des fournisseurs.

class _Rows extends RpcRows {
  _Rows(super.fn, this.v);
  final List<Map<String, dynamic>>? v;
  @override
  List<Map<String, dynamic>>? build() => v;
}

/// Lecture qui compte ses relectures et réussit (ou échoue) à la demande.
class _Counting extends RpcRows {
  _Counting(super.fn, this.ok, this.calls);
  final bool ok;
  final List<String> calls;
  @override
  List<Map<String, dynamic>>? build() => const [];
  @override
  Future<void> refresh() async {
    calls.add(fn);
    error = !ok;
    state = const [];
  }
}

class _Sel extends ProposalSelection {
  _Sel(this.ids);
  final Set<String> ids;
  @override
  Set<String> build() => ids;
}

class _Opened extends OpenedProposal {
  _Opened(this.id);
  final String id;
  @override
  String build() => id;
}

class _Mission extends MissionNotifier {
  _Mission(this.m);
  final Mission m;
  @override
  Mission build() => m;
}

Map<String, dynamic> _p(String id, String author, int amount, int delay, String status, {bool certified = false, int projects = 0, String missionStatus = 'published', String message = ''}) => {
      'id': id, 'mission_id': 'm1', 'mission': 'Site vitrine', 'mission_status': missionStatus, 'author_id': 'u-$id', 'author': author, 'amount': amount, 'delay_days': delay,
      'status': status, 'message': message, 'attempts': 1, 'created_at': '2026-10-02T10:00:00Z', 'author_certified': certified, 'author_projects': projects,
    };

String _day(int plus) => DateTime.now().add(Duration(days: plus)).toIso8601String().substring(0, 10);

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  final props = [
    _p('p1', 'Alice T.', 80000, 7, 'submitted', certified: true, projects: 3, message: 'Je propose un site vitrine en 7 jours.'),
    _p('p2', 'Bruno K.', 120000, 10, 'submitted'),
    _p('p3', 'Carine N.', 65000, 6, 'declined'),
  ];

  Future<void> monter(WidgetTester t, String start, {List<Override> overrides = const []}) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget page(String text) => Scaffold(body: Center(child: Text(text)));
    final router = GoRouter(initialLocation: '/s/$start', routes: [
      GoRoute(path: '/s/93', builder: (_, _) => const G_93()),
      GoRoute(path: '/s/93b', builder: (_, _) => const G_93b()),
      GoRoute(path: '/s/94', builder: (_, _) => const G_94()),
      GoRoute(path: '/s/285', builder: (_, _) => const G_285()),
      GoRoute(path: '/s/88', builder: (_, _) => const G_88()),
      GoRoute(path: '/s/96', builder: (_, _) => const G_96()),
      GoRoute(path: '/s/97', builder: (_, _) => const G_97()),
      GoRoute(path: '/s/98', builder: (_, _) => const G_98()),
      GoRoute(path: '/s/99', builder: (_, _) => const G_99()),
      GoRoute(path: '/concours/:id', builder: (_, s) => page('fiche concours ${s.pathParameters['id']}')),
      GoRoute(path: '/opportunites/publier', builder: (_, _) => page('formulaire offre')),
      GoRoute(path: '/opportunites/mes', builder: (_, _) => page('mes offres')),
      GoRoute(path: '/opportunites/:id/candidatures', builder: (_, s) => page('candidatures ${s.pathParameters['id']}')),
    ]);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(authProvider.notifier).login(demoAccount.copyWith(role: 2));
    await t.pumpAndSettle();
  }

  test('échéances : dates JJ/MM/AAAA, texte français et ISO ; compteurs sans brouillon, annulé ni mission sur mesure', () {
    expect(parseDate('30/11/2030'), DateTime(2030, 11, 30));
    expect(parseDate('30 nov. 2030'), DateTime(2030, 11, 30));
    expect(parseDate('1er févr. 2031'), DateTime(2031, 2, 1));
    expect(parseDate('2030-12-05'), DateTime(2030, 12, 5));
    expect(parseDate('31/02/2030'), isNull);
    expect(parseDate('bientôt'), isNull);
    expect(daysLabel(1), '1 jour');
    expect(daysLabel(7), '7 jours');
    expect(missionStatus('cancelled'), 'Annulé');
    expect(quoteStatus('expired'), 'Expiré');
    expect(quoteStatus('rejected'), 'Refusé');
    final c = companyCounters([
      {'status': 'published', 'kind': 'besoin', 'is_need': true, 'deadline_date': _day(3)},
      {'status': 'draft', 'kind': 'besoin', 'is_need': false, 'deadline_date': _day(2)},
      {'status': 'cancelled', 'kind': 'besoin', 'is_need': false, 'deadline_date': _day(2)},
      {'status': 'published', 'kind': 'mission', 'is_need': false},
      {'status': 'assigned', 'kind': 'besoin', 'is_need': true, 'deadline': '15/01/2099'},
      {'status': 'in_progress', 'kind': 'besoin', 'is_need': true, 'deadline': '01/01/2000'},
    ], props, DateTime.now());
    expect(c.needs, 3);
    expect(c.deadlines, 1);
    expect(c.collaborations, 2);
    expect(c.proposals, 2);
    expect(c.toReview, 2);
  });

  test('refreshCompanyData relit réellement les quatre listes et dit la vérité sur l’échec', () async {
    final calls = <String>[];
    ProviderContainer build(bool ok) => ProviderContainer(overrides: [
          companyProposalsProvider.overrideWith(() => _Counting('company_proposals', ok, calls)),
          companyMissionsProvider.overrideWith(() => _Counting('company_missions', ok, calls)),
          quotesListProvider.overrideWith(() => _Counting('table:quote_requests', ok, calls)),
          defisListProvider.overrideWith(() => _Counting('defis_list', ok, calls)),
        ]);
    final good = build(true);
    addTearDown(good.dispose);
    expect(await refreshCompanyData(good), isTrue);
    expect(calls, containsAll(['company_proposals', 'company_missions', 'table:quote_requests', 'defis_list']));
    final bad = build(false);
    addTearDown(bad.dispose);
    expect(await refreshCompanyData(bad), isFalse);
  });

  testWidgets('93 : pastilles filtrantes, cases à cocher, comparaison réelle (94) puis fiche (93b) avec confirmation', (t) async {
    await monter(t, '93', overrides: [companyProposalsProvider.overrideWith(() => _Rows('company_proposals', props))]);
    expect(find.text('Toutes (3)'), findsOneWidget);
    expect(find.text('Reçues (2)'), findsOneWidget);
    expect(find.text('Refusées (1)'), findsOneWidget);
    expect(find.text('Carine N.'), findsOneWidget);
    await t.tap(find.text('Reçues (2)'));
    await t.pumpAndSettle();
    expect(find.text('Carine N.'), findsNothing);
    expect(find.text('Alice T.'), findsOneWidget);
    await t.ensureVisible(find.text('Refusées (1)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Refusées (1)'));
    await t.pumpAndSettle();
    expect(find.text('Carine N.'), findsOneWidget);
    expect(find.text('Alice T.'), findsNothing);
    await t.ensureVisible(find.text('Toutes (3)'));
    await t.pumpAndSettle();
    await t.tap(find.text('Toutes (3)'));
    await t.pumpAndSettle();

    // aucune sélection : pas de comparaison, un message clair
    await t.tap(find.text('Comparer la sélection'), warnIfMissed: false);
    await t.pump();
    expect(find.text('Cochez au moins deux propositions pour les comparer.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 4));
    expect(find.text('Moins cher'), findsNothing);

    // deux propositions cochées : la comparaison s'ouvre sur leurs vraies données
    final boxes = find.byType(Checkbox);
    expect(boxes, findsNWidgets(3));
    await t.tap(boxes.at(0));
    await t.tap(boxes.at(1));
    await t.pumpAndSettle();
    expect(find.text('2 propositions cochées'), findsOneWidget);
    await t.tap(find.text('Comparer la sélection'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Compte certifié'), findsOneWidget);
    expect(find.text('Non certifié'), findsOneWidget);
    expect(find.text('Le moins cher'), findsOneWidget);
    expect(find.text('Le plus rapide'), findsOneWidget);
    expect(find.text('Carine N.'), findsNothing);
    double y(String s) => t.getTopLeft(find.text(s).first).dy;
    expect(y('Alice T.') < y('Bruno K.'), isTrue); // tri par prix croissant
    await t.tap(find.text('Portfolio'));
    await t.pumpAndSettle();
    expect(find.textContaining('projets publics'), findsOneWidget);
    expect(y('Alice T.') < y('Bruno K.'), isTrue); // 3 projets publics contre 0

    // ouverture de la fiche : offre, message, jalons prévus ; décision confirmée
    await t.tap(find.text('Ouvrir la proposition').first);
    await t.pumpAndSettle();
    expect(find.text('Je propose un site vitrine en 7 jours.'), findsOneWidget);
    expect(find.text('Jalons prévus si vous acceptez'), findsOneWidget);
    expect(find.text(fcfa(24000)), findsNWidgets(2)); // jalons 1 et 3 (30 % chacun)
    expect(find.text(fcfa(32000)), findsOneWidget); // jalon 2 (40 %)
    expect(find.text('Refuser'), findsOneWidget);
    await t.tap(find.text('Refuser'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Refuser la proposition de Alice T. ?'), findsOneWidget);
    expect(find.text('Motif (facultatif, transmis au talent)'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(find.textContaining('Proposition refusée'), findsNothing);
    await t.tap(find.text('Accepter'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.textContaining('Cette décision est définitive'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(find.textContaining('Proposition acceptée'), findsNothing);
  });

  testWidgets('93b : une proposition déjà refusée n’a ni bouton Accepter ni bouton Refuser', (t) async {
    await monter(t, '93b', overrides: [
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', props)),
      openedProposalProvider.overrideWith(() => _Opened('p3')),
    ]);
    expect(find.text('Carine N.'), findsOneWidget);
    expect(find.text('Refusée'), findsOneWidget);
    expect(find.text('Accepter'), findsNothing);
    expect(find.text('Refuser'), findsNothing);
  });

  testWidgets('94 sans sélection : message explicite et retour aux propositions, aucune comparaison inventée', (t) async {
    await monter(t, '94', overrides: [companyProposalsProvider.overrideWith(() => _Rows('company_proposals', props))]);
    expect(find.textContaining('Cochez au moins deux propositions'), findsOneWidget);
    expect(find.text('Voir les propositions'), findsOneWidget);
    expect(find.text('Note'), findsNothing);
    expect(find.textContaining('IA'), findsNothing);
  });

  testWidgets('94 : pastille Délai trie réellement du plus rapide au plus long', (t) async {
    final rows = [_p('a', 'Alice T.', 80000, 5, 'submitted'), _p('b', 'Bruno K.', 120000, 2, 'submitted'), _p('c', 'Carine N.', 65000, 9, 'submitted')];
    await monter(t, '94', overrides: [
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', rows)),
      proposalSelectionProvider.overrideWith(() => _Sel({'a', 'b', 'c'})),
    ]);
    double y(String s) => t.getTopLeft(find.text(s).first).dy;
    expect(y('Carine N.') < y('Alice T.') && y('Alice T.') < y('Bruno K.'), isTrue); // prix : 65 000, 80 000, 120 000
    await t.tap(find.descendant(of: find.byType(EntChips), matching: find.text('Délai')));
    await t.pumpAndSettle();
    expect(find.text('Du plus rapide au plus long.'), findsOneWidget);
    expect(y('Bruno K.') < y('Alice T.') && y('Alice T.') < y('Carine N.'), isTrue); // délai : 2, 5, 9 jours
    await t.tap(find.text('Prix'));
    await t.pumpAndSettle();
    expect(find.text('Du moins cher au plus cher.'), findsOneWidget);
    expect(y('Carine N.') < y('Bruno K.'), isTrue);
  });

  testWidgets('96 : défis filtrés par statut et par type, prix en FCFA, ligne cliquable vers la fiche', (t) async {
    await monter(t, '96', overrides: [
      defisListProvider.overrideWith(() => _Rows('defis_list', [
            {'id': 'd1', 'title': 'Défi ouvert', 'organizer': 'Orga', 'kind': 'contest', 'phase': 'open', 'deadline': _day(10), 'prize_amount': 500000, 'reward': ''},
            {'id': 'd2', 'title': 'Hackathon à venir', 'organizer': 'Orga', 'kind': 'hackathon', 'phase': 'upcoming', 'opens_on': _day(5), 'deadline': _day(20), 'prize_amount': 0, 'reward': 'Voyage'},
            {'id': 'd3', 'title': 'Défi terminé', 'organizer': 'Orga', 'kind': 'contest', 'phase': 'ended', 'deadline': '2025-01-10', 'prize_amount': 0, 'reward': ''},
          ]))
    ]);
    expect(find.text('Concours et hackathons'), findsOneWidget);
    expect(find.text('1 ouvert · 1 à venir'), findsOneWidget);
    expect(find.text('Défi ouvert'), findsOneWidget);
    expect(find.text(fcfa(500000)), findsOneWidget);
    expect(find.text('Hackathon à venir'), findsNothing);
    await t.tap(find.text('À venir'));
    await t.pumpAndSettle();
    expect(find.text('Hackathon à venir'), findsOneWidget);
    expect(find.text('Voyage'), findsOneWidget);
    expect(find.text('Défi ouvert'), findsNothing);
    await t.tap(find.text('Terminés'));
    await t.pumpAndSettle();
    expect(find.text('Défi terminé'), findsOneWidget);
    expect(find.text('Prix : 0'), findsNothing);
    await t.tap(find.text('Hackathons'));
    await t.pumpAndSettle();
    expect(find.text('Aucun défi terminé pour le moment.'), findsOneWidget);
    await t.tap(find.text('Ouverts'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tous'));
    await t.pumpAndSettle();
    await t.tap(find.text('Défi ouvert'));
    await t.pumpAndSettle();
    expect(find.text('fiche concours d1'), findsOneWidget);
  });

  testWidgets('97 : offres publiées par l’entreprise et candidatures réelles, publication et suivi branchés', (t) async {
    await monter(t, '97', overrides: [
      oppMyPostedProvider.overrideWith((ref) async => [
            {'id': 'o1', 'title': 'Stage développeur', 'kind': 'stage', 'status': 'published', 'applications': 8},
            {'id': 'o2', 'title': 'Emploi comptable', 'kind': 'emploi', 'status': 'pending', 'applications': 0},
          ]),
    ]);
    expect(find.text('2 offres · 8 candidatures reçues'), findsOneWidget);
    expect(find.text('Stage développeur'), findsOneWidget);
    expect(find.text('8 candidatures · Stage'), findsOneWidget);
    expect(find.text('Publiée'), findsOneWidget);
    await t.tap(find.text('Emplois'));
    await t.pumpAndSettle();
    expect(find.text('Stage développeur'), findsNothing);
    expect(find.text('Emploi comptable'), findsOneWidget);
    await t.tap(find.text('Emploi comptable'));
    await t.pumpAndSettle();
    expect(find.text('candidatures o2'), findsOneWidget);
    Navigator.of(t.element(find.text('candidatures o2'))).pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Publier une offre'));
    await t.pumpAndSettle();
    expect(find.text('formulaire offre'), findsOneWidget);
  });

  testWidgets('98 : collaborations filtrées par état, la ligne ouvre l’espace projet', (t) async {
    await monter(t, '98', overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'id': 'm1', 'title': 'Application CRM', 'status': 'in_progress', 'team': 'Alice T.', 'deadline': '30/11/2030', 'proposals': 1, 'kind': 'besoin'},
            {'id': 'm2', 'title': 'Charte graphique', 'status': 'delivered', 'team': 'Bruno K.', 'proposals': 1, 'kind': 'besoin'},
            {'id': 'm3', 'title': 'Besoin ouvert', 'status': 'published', 'team': '', 'proposals': 0, 'kind': 'besoin'},
          ]))
    ]);
    expect(find.text('En cours (1)'), findsOneWidget);
    expect(find.text('Livrées (1)'), findsOneWidget);
    expect(find.text('Application CRM'), findsOneWidget);
    expect(find.textContaining('pour le 30 nov. 2030'), findsOneWidget);
    expect(find.text('Charte graphique'), findsNothing);
    expect(find.text('Besoin ouvert'), findsNothing);
    await t.tap(find.text('Livrées (1)'));
    await t.pumpAndSettle();
    expect(find.text('Charte graphique'), findsOneWidget);
    await t.tap(find.text('Charte graphique'));
    await t.pumpAndSettle();
    expect(find.text('Espace projet'), findsOneWidget);
  });

  testWidgets('99 : historique réel, besoins annulés traduits, compteurs exacts, pastille Devis active', (t) async {
    await monter(t, '99', overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'id': 'm1', 'title': 'Besoin publié', 'status': 'published', 'created_at': '2026-10-02T10:00:00Z', 'proposals': 1, 'kind': 'besoin', 'is_need': true, 'deadline_date': _day(3)},
            {'id': 'm2', 'title': 'Besoin annulé', 'status': 'cancelled', 'created_at': '2026-10-01T10:00:00Z', 'proposals': 0, 'kind': 'besoin', 'is_need': false},
            {'id': 'm3', 'title': 'Brouillon', 'status': 'draft', 'created_at': '2026-10-01T10:00:00Z', 'proposals': 0, 'kind': 'besoin', 'is_need': false},
          ])),
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', props)),
      quotesListProvider.overrideWith(() => _Rows('table:quote_requests', [
            {'id': 'q1', 'brief': 'Objet : logo', 'status': 'expired'},
          ])),
    ]);
    expect(find.text('1 besoin publié · 0 mission · 1 échéance sous 7 jours'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
    expect(find.text('cancelled'), findsNothing);
    expect(find.text('Publié le 2 oct. 2026 · 1 proposition'), findsOneWidget);
    expect(find.text('Brouillon créé le 1 oct. 2026 · 0 proposition'), findsOneWidget);
    await t.tap(find.text('Devis'));
    await t.pumpAndSettle();
    expect(find.text('Objet : logo'), findsOneWidget);
    expect(find.text('Expiré'), findsOneWidget);
  });

  testWidgets('88 : tuiles cliquables et compteurs exacts, état vide avec « Publier un besoin »', (t) async {
    final handle = t.ensureSemantics();
    await monter(t, '88', overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', [
            {'id': 'm1', 'title': 'Publié', 'status': 'published', 'kind': 'besoin', 'is_need': true, 'deadline_date': _day(3)},
            {'id': 'm2', 'title': 'Brouillon', 'status': 'draft', 'kind': 'besoin', 'is_need': false, 'deadline_date': _day(2)},
            {'id': 'm3', 'title': 'Annulé', 'status': 'cancelled', 'kind': 'besoin', 'is_need': false},
            {'id': 'm4', 'title': 'Sur mesure', 'status': 'published', 'kind': 'mission', 'is_need': false},
          ])),
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', props)),
      companyProvider.overrideWith((ref) async => null),
    ]);
    expect(find.bySemanticsLabel('Besoins publiés : 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Échéances sous 7 jours : 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Propositions reçues : 2'), findsOneWidget);
    expect(find.bySemanticsLabel('À examiner : 2'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Propositions reçues : 2'));
    await t.pumpAndSettle();
    expect(find.text('Toutes (3)'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('88 sans besoin ni proposition : bouton « Publier un besoin » dans l’état vide', (t) async {
    await monter(t, '88', overrides: [
      companyMissionsProvider.overrideWith(() => _Rows('company_missions', const [])),
      companyProposalsProvider.overrideWith(() => _Rows('company_proposals', const [])),
      companyProvider.overrideWith((ref) async => null),
    ]);
    expect(find.textContaining('Vous n’avez encore publié aucun besoin'), findsOneWidget);
    expect(find.text('Publier un besoin'), findsOneWidget);
  });

  testWidgets('285 : contrat, jalons et messagerie réels ; le bouton du bas porte le libellé de l’action', (t) async {
    const m = Mission(
      id: '#BR-1', kind: 'Site vitrine', desc: '', total: 240000, date: '', real: true, uuid: 'm1', role: 'client', counterpart: 'Alice T.', invoice: 'MI-2026-00001', team: 'Alice T.',
      status: 'in_progress', deadline: '30/11/2030', milestoneAmounts: [72000, 96000, 72000],
      steps: [('Brief validé', 'Validé'), ('Propositions', 'Livré, à valider'), ('Livraison finale', 'À venir')], pays: ['confirmed', 'unpaid', 'unpaid'],
    );
    await monter(t, '285', overrides: [missionProvider.overrideWith(() => _Mission(m))]);
    expect(find.text('Contrat de mission'), findsOneWidget);
    expect(find.text('N° MI-2026-00001'), findsOneWidget);
    expect(find.text(fcfa(240000)), findsOneWidget);
    expect(find.text('1 · Brief validé'), findsOneWidget);
    expect(find.text('Livré, à valider'), findsOneWidget);
    expect(find.text('Messagerie du projet'), findsOneWidget);
    expect(find.text('Valider le jalon 2'), findsOneWidget);
  });

  testWidgets('285 sans projet : libellé honnête, aucun contrat inventé', (t) async {
    await monter(t, '285', overrides: [missionProvider.overrideWith(() => _Mission(Mission.none))]);
    expect(find.text('Contrat de mission'), findsNothing);
    expect(find.text('Chargement…'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Voir les propositions reçues'), findsOneWidget);
  });

  testWidgets('90 : repasser un besoin publié en brouillon est confirmé, date passée refusée, sortie avec saisie confirmée', (t) async {
    final handle = t.ensureSemantics();
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const NeedFormPage(existing: {'id': 'm1', 'title': 'Application mobile', 'description': 'Une application avec tableau de bord et export.', 'status': 'published', 'deadline': '01/01/2020'}),
                )),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    expect(find.text('Repasser en brouillon'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    // date limite passée : refusée avant tout envoi
    await t.tap(find.text('Enregistrer'));
    await t.pump();
    expect(find.text('La date limite est déjà passée : choisissez une date à venir.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 4));
    // retrait de la date puis brouillon : avertissement explicite
    await t.tap(find.bySemanticsLabel('Retirer la date'));
    await t.pumpAndSettle();
    await t.tap(find.text('Repasser en brouillon'));
    await t.pumpAndSettle();
    expect(find.text('Repasser ce besoin en brouillon ?'), findsOneWidget);
    expect(find.textContaining('leurs auteurs sont prévenus'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    // la saisie modifiée : quitter demande confirmation
    await t.enterText(find.byType(TextField).first, 'Application mobile v2');
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Retour'));
    await t.pumpAndSettle();
    expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(find.text('Modifier le besoin'), findsOneWidget);
    handle.dispose();
  });
}
