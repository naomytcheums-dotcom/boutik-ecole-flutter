import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/access.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/coequipiers_screens.dart';
import 'package:boutik_ecole/figma/live/console.dart' show RpcRows;
import 'package:boutik_ecole/figma/live/contests.dart';
import 'package:boutik_ecole/figma/live/hackathons.dart';
import 'package:boutik_ecole/figma/live/l10_hackathons.dart';
import 'package:boutik_ecole/figma/live/l10_voeux.dart';
import 'package:boutik_ecole/figma/live/modules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Lot S6 (profil étudiant) : liste des concours complète et triée, publication complète, concours de l'équipe, jury, annuaire sur consentement,
/// précommandeurs d'un vœu, duels (lien, participation, votes masqués), jumeau 3D absent de « Mes rubriques ».

class _Loaded extends ServerContests {
  @override
  List<Hackathon>? build() => const [];
}

class _FakeRows extends RpcRows {
  _FakeRows(this.rows) : super('duels_list');
  final List<Map<String, dynamic>> rows;
  @override
  List<Map<String, dynamic>>? build() => rows;
}

Hackathon _h(String id, String status, {String city = 'Douala', DateTime? close, bool free = true}) =>
    Hackathon(id, 'Concours $id', '', city, 0, 10, status, free: free, serverStatus: status == 'Ouvert' ? 'published' : status.toLowerCase(), regClose: close);

void main() {
  setUp(() => Backend.ready = false);
  tearDown(() => Backend.ready = false);

  group('S6-1/S6-2 : liste des concours', () {
    test('les concours ouverts passent avant les clos, la clôture la plus proche en tête', () {
      final l = sortContestsForList([
        _h('clos-vieux', 'Clos', close: DateTime(2026, 1, 1)),
        _h('ouvert-loin', 'Ouvert', close: DateTime(2099, 6, 1)),
        _h('resultats', 'Résultats', close: DateTime(2026, 2, 1)),
        _h('clos-recent', 'Clos', close: DateTime(2026, 5, 1)),
        _h('ouvert-proche', 'Ouvert', close: DateTime(2099, 1, 1)),
        _h('jury', 'Jury', close: DateTime(2026, 3, 1)),
      ]);
      expect([for (final h in l) h.id], ['ouvert-proche', 'ouvert-loin', 'jury', 'resultats', 'clos-recent', 'clos-vieux']);
    });

    test('filtres : villes réelles sans tenir compte de la casse ni des accents, Gratuits seulement s’il y en a', () {
      final all = [_h('a', 'Ouvert', city: 'Douala'), _h('b', 'Ouvert', city: 'douala'), _h('c', 'Ouvert', city: 'Bafoussam', free: false), _h('d', 'Ouvert', city: 'Yaoundé')];
      final f = contestFilters(all);
      expect([for (final x in f) x.$2], ['Tous', 'Douala', 'Bafoussam', 'Yaoundé', 'Gratuits']);
      final city = f.firstWhere((x) => x.$2 == 'Douala').$1;
      expect([for (final h in all) if (contestMatchesFilter(h, city)) h.id], ['a', 'b']);
      expect(contestMatchesFilter(all[2], 'free'), isFalse);
      expect(contestFilters([_h('c', 'Ouvert', free: false)]).map((x) => x.$2), ['Tous', 'Douala']);
    });

    testWidgets('160 : tous les concours sont atteignables (pagination), jamais seulement trois', (t) async {
      GAnim.enabled = false;
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final all = [for (var i = 1; i <= 12; i++) _h(i.toString().padLeft(2, '0'), 'Ouvert', close: DateTime(2099, 1, i))];
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[contestsProvider.overrideWithValue(all), serverContestsProvider.overrideWith(_Loaded.new)],
        child: const MaterialApp(home: Scaffold(body: ContestsListScreen())),
      ));
      await t.pumpAndSettle();
      expect(find.text('Concours 01'), findsOneWidget);
      expect(find.text('Concours 12'), findsNothing);
      await t.scrollUntilVisible(find.text('Afficher plus (2)'), 300, scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Afficher plus (2)'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Concours 12'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Concours 12'), findsOneWidget);
    });

    testWidgets('160 : aucun concours ⇒ message explicite (et non une liste silencieuse)', (t) async {
      GAnim.enabled = false;
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[contestsProvider.overrideWithValue(const []), serverContestsProvider.overrideWith(_Loaded.new)],
        child: const MaterialApp(home: Scaffold(body: ContestsListScreen())),
      ));
      await t.pumpAndSettle();
      expect(find.text('Aucun concours publié pour le moment.'), findsOneWidget);
    });
  });

  group('S6-21 : concours de l’équipe', () {
    final a = _h('a', 'Ouvert');
    final b = _h('b', 'Ouvert');
    ({String teamId, String name, bool captain}) team(String n) => (teamId: 't-$n', name: n, captain: true);

    test('le concours sélectionné est gardé s’il compte une équipe de l’utilisateur', () {
      expect(contestOfMyTeam(a, {'a': team('A'), 'b': team('B')}, [a, b]).id, 'a');
    });
    test('sans sélection pertinente, l’unique équipe de l’utilisateur donne son concours', () {
      expect(contestOfMyTeam(a, {'b': team('B')}, [a, b]).id, 'b');
    });
    test('plusieurs équipes et aucune sur le concours choisi : le choix est conservé (le serveur répondra)', () {
      expect(contestOfMyTeam(a, {'b': team('B'), 'c': team('C')}, [a, b]).id, 'a');
    });
  });

  group('S6-65 : publication d’un concours', () {
    final base = {
      'titre': 'Hackathon Eau', 'description': 'Une description assez longue pour passer.', 'theme': 'Eau potable', 'reglement': 'Article 1',
      'lieu': 'Douala', 'frais': '5 000', 'debut': '2099-03-10', 'fin': '2099-03-12', 'inscriptions': '2099-02-01', 'depots': '2099-03-01', 'places': '40', 'dotation': '500 000',
    };
    test('thème, règlement, frais et dates partent au serveur', () {
      final p = contestPublishParams(base)!;
      expect(p['p_theme'], 'Eau potable');
      expect(p['p_rules'], 'Article 1');
      expect(p['p_entry_fee'], 5000);
      expect(p['p_starts'], '2099-03-10');
      expect(p['p_ends'], '2099-03-12');
      expect(p['p_prize'], 500000);
      expect(p['p_places'], 40);
      expect(p['p_publish'], true);
    });
    test('début et fin sont facultatifs ; une date illisible est refusée', () {
      final p = contestPublishParams({...base, 'debut': '', 'fin': ''})!;
      expect(p['p_starts'], isNull);
      expect(p['p_ends'], isNull);
      expect(contestPublishParams({...base, 'debut': 'bientôt'}), isNull);
      expect(contestPublishParams({...base, 'inscriptions': ''}), isNull);
    });
  });

  group('S6-64 : juré désigné', () {
    const client = Account(name: 'Jean Juge', phone: '690000000', email: 'jean@t.cm', password: 'Boutik2026', role: 0);

    Future<void> monter(WidgetTester t, List<Map<String, dynamic>> jury) async {
      Backend.ready = true;
      final c = ProviderContainer(overrides: <Override>[jurorContestsProvider.overrideWith((ref) async => jury)]);
      addTearDown(c.dispose);
      c.read(authProvider.notifier).login(client);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: AccessGuard(id: '167', child: Text('NOTATION')))));
      await t.pumpAndSettle();
    }

    testWidgets('un compte client désigné juré ouvre l’écran de notation', (t) async {
      await monter(t, [{'id': 'c1'}]);
      expect(find.text('NOTATION'), findsOneWidget);
    });

    testWidgets('un compte client qui n’est pas juré reste refusé', (t) async {
      await monter(t, const []);
      expect(find.text('NOTATION'), findsNothing);
      expect(find.text('Page introuvable'), findsOneWidget);
    });

    test('« Mes rubriques » propose la notation seulement aux jurés', () {
      expect(listedInEspace(client, '167'), isFalse);
      expect(listedInEspace(client, '167', juror: true), isTrue);
      expect(listedInEspace(null, '167', juror: true), isFalse);
    });
  });

  group('S6-62 : jumeau 3D', () {
    test('225 et 226 ne sont plus proposés dans « Mes rubriques » en production, mais restent joignables par adresse', () {
      expect(listedInEspace(demoAccount, '225'), isTrue); // aperçu hors connexion : maquette
      Backend.ready = true;
      expect(listedInEspace(demoAccount, '225'), isFalse);
      expect(listedInEspace(demoAccount, '226'), isFalse);
      expect(canOpen(demoAccount, '225'), isTrue);
    });
  });

  group('S6-15 : annuaire sur consentement', () {
    Future<void> monter(WidgetTester t, Map<String, dynamic> v) async {
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[mateVisibilityProvider.overrideWith((ref) async => v)],
        child: const MaterialApp(home: Scaffold(body: MateVisibilityCard())),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('par défaut : interrupteur éteint et explication claire', (t) async {
      await monter(t, {'eligible': true, 'visible': false, 'has_skills': true});
      expect(find.text('Apparaître dans l’annuaire'), findsOneWidget);
      expect(tester(t).value, isFalse);
      expect(tester(t).onChanged, isNotNull);
      expect(find.textContaining('vous restez invisible'), findsOneWidget);
    });

    testWidgets('sans compétences : activation impossible et la condition est expliquée', (t) async {
      await monter(t, {'eligible': true, 'visible': false, 'has_skills': false});
      expect(tester(t).onChanged, isNull);
      expect(find.textContaining('Renseignez vos compétences'), findsOneWidget);
    });

    testWidgets('visible : le retrait reste possible', (t) async {
      await monter(t, {'eligible': true, 'visible': true, 'has_skills': true});
      expect(tester(t).value, isTrue);
      expect(find.textContaining('Désactivez à tout moment'), findsOneWidget);
    });

    testWidgets('compte non étudiant : aucune carte', (t) async {
      await monter(t, {'eligible': false, 'visible': false, 'has_skills': false});
      expect(find.text('Apparaître dans l’annuaire'), findsNothing);
    });
  });

  group('S6-43 : précommandeurs d’un vœu', () {
    final wish = {'id': 'w1', 'title': 'Lampe en bois', 'description': '', 'price': 15000, 'threshold': 2, 'duration_days': 30, 'count': 2, 'open': true, 'mine': false, 'is_author': true, 'ends_at': '2099-01-01T00:00:00Z'};

    Future<void> monter(WidgetTester t, Map<String, dynamic> pre) async {
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[
          wishDetailProvider.overrideWith((ref, id) async => wish),
          wishPreorderersProvider.overrideWith((ref, id) async => pre),
        ],
        child: const MaterialApp(home: Scaffold(body: WishDetail(id: 'w1'))),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('seuil atteint : le créateur voit ses précommandeurs et peut leur écrire', (t) async {
      await monter(t, {
        'count': 2, 'threshold': 2, 'reached': true, 'ended': false, 'can_contact': true, 'sent_this_week': 0,
        'preorderers': [{'name': 'Paul P.'}, {'name': 'Awa E.'}],
      });
      expect(find.text('Vos précommandeurs (2)'), findsOneWidget);
      expect(find.text('Paul P., Awa E.'), findsOneWidget);
      expect(find.text('Écrire aux précommandeurs'), findsOneWidget);
    });

    testWidgets('seuil non atteint : pas de bouton, la règle est dite', (t) async {
      await monter(t, {'count': 1, 'threshold': 2, 'reached': false, 'ended': false, 'can_contact': false, 'sent_this_week': 0, 'preorderers': [{'name': 'Paul P.'}]});
      expect(find.text('Écrire aux précommandeurs'), findsNothing);
      expect(find.text('Vous pourrez écrire aux précommandeurs une fois le seuil atteint.'), findsOneWidget);
    });

    testWidgets('la promesse faite aux précommandeurs est exécutable et sans coordonnées', (t) async {
      await monter(t, {'count': 0, 'threshold': 2, 'reached': false, 'ended': false, 'can_contact': false, 'sent_this_week': 0, 'preorderers': <Object>[]});
      expect(find.textContaining('notification dans l’application'), findsOneWidget);
      expect(find.textContaining('jamais vos coordonnées'), findsOneWidget);
      expect(find.textContaining('vous contactera'), findsNothing);
    });
  });

  group('S6-48/49/50 : duels', () {
    Future<void> monter(WidgetTester t, List<Map<String, dynamic>> rows) async {
      Backend.ready = true;
      t.view.physicalSize = const Size(390, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        overrides: <Override>[duelsProvider.overrideWith(() => _FakeRows(rows))],
        child: const MaterialApp(home: Scaffold(body: DuelsOpenPanel())),
      ));
      await t.pumpAndSettle();
    }

    Map<String, dynamic> duel({required bool myEntry}) => {
          'id': 'd1', 'need': 'Logo Test', 'prize': '', 'ends_at': '2099-12-01T10:00:00Z', 'open': true, 'mine': false, 'my_entry': myEntry,
          'entries': [
            {'id': 'e1', 'title': 'Idée A', 'author': 'Alice T.', 'author_id': 'u-a', 'mine': myEntry, 'votes': null, 'my_vote': false, 'link': 'https://exemple.cm/logo.png'},
          ],
        };

    testWidgets('les votes restent masqués pendant le duel et le visuel joint est proposé', (t) async {
      await monter(t, [duel(myEntry: false)]);
      expect(find.textContaining('vote'), findsOneWidget); // seule la phrase d’explication, aucun compteur
      expect(find.textContaining('affichés à la fin du duel'), findsOneWidget);
      expect(find.text('Voir le visuel ou le dossier joint'), findsOneWidget);
      expect(find.text('Participer'), findsOneWidget);
      expect(find.text('Voter'), findsOneWidget);
    });

    testWidgets('un participant se reconnaît, ne revote pas et peut retirer sa proposition', (t) async {
      await monter(t, [duel(myEntry: true)]);
      expect(find.textContaining('(vous)'), findsOneWidget);
      expect(find.text('Participer'), findsNothing);
      expect(find.text('Voter'), findsNothing);
      expect(find.text('Retirer ma proposition'), findsOneWidget);
    });
  });
}

Switch tester(WidgetTester t) => t.widget<Switch>(find.byType(Switch));
