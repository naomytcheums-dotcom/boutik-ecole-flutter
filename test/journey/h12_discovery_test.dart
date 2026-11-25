import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_team.dart' show CompanyGuard;
import 'package:boutik_ecole/figma/live/top100_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H12 · Talent Discovery (entreprise) : droits par rôle, recherche et critères envoyés au serveur, « pourquoi ce talent vous est proposé », comparaison de 2 à 4 profils,
/// favoris, vivier, demandes de contact, serveur muet / en panne / refus sans faux succès. Faux serveur local, aucun talent d'exemple hors du test.
const _a = '22222222-2222-4222-8222-222222222222';
const _b = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> _talent(String id, String name, {int rank = 1, bool favorite = false, bool inPool = false}) => {
      'rank': rank,
      'user_id': id,
      'name': name,
      'photo': null,
      'institution': 'IUT de Douala',
      'program': 'Génie informatique',
      'promotion': '2026',
      'score': 120 - rank,
      'month_points': 30,
      'delta_rank': 2,
      'is_new': false,
      'skills': [
        {'skill': 'Flutter', 'domain': 'Mobile', 'level': 'avance'},
      ],
      'badges': [
        {'code': 'B1', 'count': 2},
      ],
      'projects': 3,
      'availability': {
        'kinds': ['internship'],
        'available_from': '2026-12-01',
      },
      'in_pool': inPool,
      'favorite': favorite,
      'stage': null,
      'why': [
        {'criterion': 'published_ranking', 'label': 'Figure au dernier classement publié', 'satisfied': true},
        {'criterion': 'skill', 'label': 'Compétence Flutter (niveau avancé)', 'satisfied': true},
      ],
    };

Map<String, dynamic> _search(List<Map<String, dynamic>> items, {int? total}) =>
    {'published': true, 'period': '2026-11', 'scope': 'national', 'items': items, 'total': total ?? items.length, 'automatic_decision': false, 'notice': 'Aucune décision de recrutement automatique.'};

Account _compte(int role) => Account(name: 'Compte Test', phone: '690000001', email: 'c@example.com', password: '', role: role, serverId: FakeSupabase.userId);

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
    srv.rpc['ranking_institutions_public'] = (_) => {'published': false, 'items': <Object?>[]};
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, {int role = 2, Widget child = const TalentDiscoveryScreen(), bool guarded = true}) async {
    t.view.physicalSize = const Size(420, 4200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/discovery', routes: [
      GoRoute(path: '/discovery', builder: (_, _) => guarded ? CompanyGuard(useContext: true, child: child) : child),
      GoRoute(path: '/discovery/favoris', builder: (_, _) => const TalentFavoritesScreen()),
      GoRoute(path: '/top100/talent/:id', builder: (_, s) => Scaffold(body: Text('PROFIL ${s.pathParameters['id']}'))),
      GoRoute(path: '/entreprise/vivier', builder: (_, _) => const Scaffold(body: Text('PAGE VIVIER'))),
    ]);
    await t.pumpWidget(ProviderScope(overrides: [initialAccountProvider.overrideWithValue(_compte(role))], child: MaterialApp.router(routerConfig: router)));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
    await t.pump(const Duration(milliseconds: 500)); // laisse finir l'ouverture d'une fenêtre
  }

  Future<void> calme(WidgetTester t) => settleReal(t, rounds: 5, ms: 80);

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('droits par rôle', () {
    testWidgets('étudiant : « Réservé aux organisations », aucune recherche envoyée', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t, role: 1);
      await calme(t);
      expect(find.text('Réservé aux organisations'), findsOneWidget);
      expect(find.text('Alice N.'), findsNothing);
      expect(srv.callsOf('discovery_search'), isEmpty);
      await fin(t);
    });

    testWidgets('client : même refus honnête, aucune recherche', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t, role: 0);
      await calme(t);
      expect(find.text('Réservé aux organisations'), findsOneWidget);
      expect(srv.callsOf('discovery_search'), isEmpty);
      await fin(t);
    });

    testWidgets('organisation : la recherche s’ouvre et interroge le serveur (portée nationale, tri par classement, 20 par page)', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      expect(find.text('Alice N.'), findsOneWidget);
      final c = srv.callsOf('discovery_search').first.args;
      expect(c['p_scope'], 'national');
      expect(c['p_sort'], 'rank');
      expect(c['p_limit'], 20);
      expect(c['p_offset'], 0);
      expect(c.containsKey('p_skill'), isFalse);
      await fin(t);
    });
  });

  group('états honnêtes', () {
    testWidgets('serveur muet (404) : erreur et « Réessayer », jamais « aucun talent »', (t) async {
      srv.unknownIsError = true;
      await host(t);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucun talent'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) : erreur lisible, aucune liste', (t) async {
      srv.failRpc.add('discovery_search');
      await host(t);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucun talent'), findsNothing);
      expect(find.textContaining('talents ·'), findsNothing);
      await fin(t);
    });

    testWidgets('refus du serveur (organisation non approuvée) : son message est affiché', (t) async {
      srv.rpc['discovery_search'] = (_) => throw const FakeRpcError('Organisation non approuvée : la découverte de talents est réservée aux organisations vérifiées');
      await host(t);
      await attendre(t, find.textContaining('réservée aux organisations vérifiées'));
      expect(find.textContaining('réservée aux organisations vérifiées'), findsOneWidget);
      await fin(t);
    });

    testWidgets('aucun classement publié : le dit, sans talent ni chiffre inventé', (t) async {
      srv.rpc['discovery_search'] = (_) => {'published': false, 'period': null, 'items': <Object?>[], 'total': 0, 'note': 'Aucun classement n’est publié pour le moment.'};
      await host(t);
      await attendre(t, find.textContaining('Aucun classement'));
      expect(find.textContaining('Aucun classement n’est publié pour le moment.'), findsOneWidget);
      expect(find.textContaining('Aucun talent'), findsNothing);
      await fin(t);
    });

    testWidgets('classement publié mais aucun talent visible : état vide dit clairement', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([]);
      await host(t);
      await attendre(t, find.textContaining('Aucun talent n’est proposé'));
      expect(find.textContaining('Aucun talent n’est proposé'), findsOneWidget);
      await fin(t);
    });
  });

  group('recherche et critères', () {
    testWidgets('carte : rang, score, preuves partagées et « pourquoi ce talent vous est proposé » (critères du serveur)', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      expect(find.text('#1'), findsOneWidget);
      expect(find.textContaining('Score 119'), findsOneWidget);
      expect(find.textContaining('IUT de Douala · Génie informatique · 2026'), findsOneWidget);
      expect(find.text('Pourquoi ce talent vous est proposé'), findsOneWidget);
      expect(find.text('Figure au dernier classement publié'), findsOneWidget);
      expect(find.text('Compétence Flutter (niveau avancé)'), findsOneWidget);
      expect(find.textContaining('Aucune décision de recrutement automatique.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('score masqué quand le talent ne le partage pas : aucun « 0 » affiché', (t) async {
      final masque = _talent(_a, 'Alice N.')..['score'] = null..['month_points'] = null;
      srv.rpc['discovery_search'] = (_) => _search([masque]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      expect(find.textContaining('Score'), findsNothing);
      await fin(t);
    });

    testWidgets('filtres : compétence, score minimal, disponibilité et tri sont envoyés au serveur', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Filtres'));
      await calme(t);
      await t.enterText(find.widgetWithText(TextField, 'Compétence (ex. Flutter)'), 'Flutter');
      await t.enterText(find.widgetWithText(TextField, 'Score minimal'), '50');
      await t.enterText(find.widgetWithText(TextField, 'Rang maximal'), '10');
      await t.tap(find.text('Disponibles uniquement'));
      await calme(t);
      await t.tap(find.text('Rechercher'));
      await calme(t);
      final c = srv.callsOf('discovery_search').last.args;
      expect(c['p_skill'], 'Flutter');
      expect(c['p_min_score'], 50);
      expect(c['p_max_rank'], 10);
      expect(c['p_available'], true);
      expect(c.containsKey('p_min_level'), isFalse, reason: 'le niveau n’est envoyé qu’avec un niveau choisi');
      await fin(t);
    });

    testWidgets('filtre chiffré invalide : message, aucune requête supplémentaire', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      final avant = srv.callsOf('discovery_search').length;
      await t.tap(find.text('Filtres'));
      await calme(t);
      await t.enterText(find.widgetWithText(TextField, 'Score minimal'), 'beaucoup');
      await t.tap(find.text('Rechercher'));
      await calme(t);
      expect(find.textContaining('nombre entier positif'), findsOneWidget);
      expect(srv.callsOf('discovery_search').length, avant);
      await fin(t);
    });

    testWidgets('« Voir plus » demande la page suivante (décalage 20) et ajoute les talents', (t) async {
      srv.rpc['discovery_search'] = (a) => (a['p_offset'] as int) == 0
          ? _search([for (var i = 1; i <= 20; i++) _talent('id-$i', 'Talent $i', rank: i)], total: 21)
          : _search([_talent('id-21', 'Talent 21', rank: 21)], total: 21);
      await host(t);
      await attendre(t, find.text('Talent 1'));
      await t.scrollUntilVisible(find.text('Voir plus de talents'), 400, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Voir plus de talents'));
      await attendre(t, find.text('Talent 21'));
      expect(srv.callsOf('discovery_search').last.args['p_offset'], 20);
      expect(find.text('Talent 21'), findsOneWidget);
      await fin(t);
    });

    testWidgets('« Profil » ouvre la page publique du talent par sa route', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Profil'));
      await calme(t);
      expect(find.text('PROFIL $_a'), findsOneWidget);
      await fin(t);
    });
  });

  group('favoris, vivier et contact', () {
    testWidgets('favori : l’écriture est envoyée et l’étoile suit la réponse du serveur', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.rpc['discovery_favorite_set'] = (a) => {'student': a['p_student'], 'favorite': a['p_on']};
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Ajouter aux favoris'));
      await calme(t);
      final c = srv.callsOf('discovery_favorite_set').single.args;
      expect(c['p_student'], _a);
      expect(c['p_on'], true);
      expect(find.text('Favori'), findsOneWidget);
      await fin(t);
    });

    testWidgets('favori : refus ou panne du serveur → message, l’étoile ne change pas', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.failRpc.add('discovery_favorite_set');
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Ajouter aux favoris'));
      await attendre(t, find.text('Favori non modifié'));
      expect(find.text('Favori non modifié'), findsOneWidget);
      expect(find.text('Favori'), findsNothing);
      await fin(t);
    });

    testWidgets('vivier : la liste choisie et la note partent au serveur, puis « Dans le vivier »', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.rpc['pool_lists_get'] = (_) => [
            {'id': 'l1', 'name': 'Stagiaires 2027', 'count': 0},
          ];
      srv.rpc['discovery_pool_add'] = (a) => {'student': a['p_student'], 'list': a['p_list'], 'added': true};
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Vivier'));
      await attendre(t, find.text('Choisir une liste'));
      await t.tap(find.text('Choisir une liste'));
      await calme(t);
      await t.tap(find.text('Stagiaires 2027').last);
      await calme(t);
      await t.enterText(find.widgetWithText(TextField, 'Note interne (facultative)'), 'À rappeler en janvier');
      await t.tap(find.text('Ajouter au vivier').last);
      await calme(t);
      final c = srv.callsOf('discovery_pool_add').single.args;
      expect(c['p_student'], _a);
      expect(c['p_list'], 'l1');
      expect(c['p_note'], 'À rappeler en janvier');
      expect(find.text('Dans le vivier'), findsOneWidget);
      await fin(t);
    });

    testWidgets('vivier : talent introuvable côté serveur → erreur dans la fenêtre, pas de faux succès', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.rpc['pool_lists_get'] = (_) => [
            {'id': 'l1', 'name': 'Stagiaires 2027', 'count': 0},
          ];
      srv.rpc['discovery_pool_add'] = (_) => throw const FakeRpcError('Talent introuvable');
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Vivier'));
      await attendre(t, find.text('Choisir une liste'));
      await t.tap(find.text('Choisir une liste'));
      await calme(t);
      await t.tap(find.text('Stagiaires 2027').last);
      await calme(t);
      await t.tap(find.text('Ajouter au vivier').last);
      await attendre(t, find.text('Talent introuvable'));
      expect(find.text('Talent introuvable'), findsOneWidget);
      expect(find.text('Dans le vivier'), findsNothing);
      await fin(t);
    });

    testWidgets('vivier : aucune liste → renvoi vers le vivier de l’organisation (Talent Cloud)', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.rpc['pool_lists_get'] = (_) => <Object?>[];
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Vivier'));
      await attendre(t, find.textContaining('Aucune liste de vivier'));
      await t.tap(find.text('Ouvrir le vivier'));
      await calme(t);
      expect(find.text('PAGE VIVIER'), findsOneWidget);
      await fin(t);
    });

    testWidgets('contact : une simple demande de connexion est envoyée (type et talent), puis confirmée', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.rpc['discovery_contact_request'] = (a) => {'ok': true, 'id': 'c1', 'kind': a['p_kind'], 'student': a['p_student']};
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Contacter'));
      await attendre(t, find.text('Envoyer'));
      await t.tap(find.text('Envoyer'));
      await calme(t);
      final c = srv.callsOf('discovery_contact_request').single.args;
      expect(c['p_kind'], 'contact');
      expect(c['p_student'], _a);
      await attendre(t, find.text('Demande envoyée : Demande de connexion'));
      expect(find.text('Demande envoyée : Demande de connexion'), findsOneWidget);
      await fin(t);
    });

    testWidgets('contact : un entretien exige un message d’au moins 10 caractères (rien n’est envoyé sinon)', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Contacter'));
      await attendre(t, find.text('Envoyer'));
      await t.tap(find.text('Demande de connexion'));
      await calme(t);
      await t.tap(find.text('Invitation à un entretien').last);
      await calme(t);
      await t.enterText(find.widgetWithText(TextField, 'Message (10 caractères au moins)'), 'Bonjour');
      await t.tap(find.text('Envoyer'));
      await calme(t);
      expect(find.textContaining('au moins 10 caractères'), findsOneWidget);
      expect(srv.callsOf('discovery_contact_request'), isEmpty);
      await fin(t);
    });

    testWidgets('contact : limite journalière refusée par le serveur → message du serveur, aucune confirmation', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.')]);
      srv.rpc['discovery_contact_request'] = (_) => throw const FakeRpcError('Limite atteinte : 10 demandes par jour');
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Contacter'));
      await attendre(t, find.text('Envoyer'));
      await t.tap(find.text('Envoyer'));
      await attendre(t, find.textContaining('Limite atteinte'));
      expect(find.textContaining('Limite atteinte'), findsOneWidget);
      expect(find.textContaining('Demande envoyée'), findsNothing);
      await fin(t);
    });
  });

  group('comparaison', () {
    Map<String, dynamic> compare() => {
          'talents': [_talent(_a, 'Alice N.'), _talent(_b, 'Bob E.', rank: 2)],
          'matrix': [
            {'criterion': 'national_rank', 'values': [{'user_id': _a, 'value': 1}, {'user_id': _b, 'value': 2}]},
            {'criterion': 'score', 'values': [{'user_id': _a, 'value': 119}, {'user_id': _b, 'value': null}]},
          ],
          'automatic_decision': false,
          'notice': 'Comparaison à titre indicatif.',
        };

    testWidgets('2 profils cochés : la comparaison envoie les identifiants et affiche « Non partagé » (jamais 0)', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.'), _talent(_b, 'Bob E.', rank: 2)]);
      srv.rpc['discovery_compare'] = (_) => compare();
      await host(t);
      await attendre(t, find.text('Alice N.'));
      expect(find.text('Cochez au moins 2 profils pour comparer.'), findsNothing);
      await t.tap(find.text('Comparer').first);
      await calme(t);
      expect(find.textContaining('Cochez au moins 2 profils'), findsOneWidget);
      await t.tap(find.text('Comparer').last);
      await calme(t);
      await t.tap(find.text('Comparer (2)'));
      await attendre(t, find.text('Rang national'));
      expect((srv.callsOf('discovery_compare').single.args['p_students'] as List).toSet(), {_a, _b});
      expect(find.text('Rang national'), findsOneWidget);
      expect(find.text('Non partagé'), findsOneWidget);
      expect(find.text('Comparaison à titre indicatif.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('comparaison : panne du serveur → erreur et « Réessayer », aucune matrice', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([_talent(_a, 'Alice N.'), _talent(_b, 'Bob E.', rank: 2)]);
      srv.failRpc.add('discovery_compare');
      await host(t);
      await attendre(t, find.text('Alice N.'));
      await t.tap(find.text('Comparer').first);
      await calme(t);
      await t.tap(find.text('Comparer').last);
      await calme(t);
      await t.tap(find.text('Comparer (2)'));
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Rang national'), findsNothing);
      await fin(t);
    });

    testWidgets('au plus 4 profils : le 5e est refusé avec un message', (t) async {
      srv.rpc['discovery_search'] = (_) => _search([for (var i = 1; i <= 5; i++) _talent('id-$i', 'Talent $i', rank: i)]);
      await host(t);
      await attendre(t, find.text('Talent 1'));
      for (var i = 0; i < 5; i++) {
        await t.ensureVisible(find.text('Comparer').at(i));
        await t.tap(find.text('Comparer').at(i));
        await calme(t);
      }
      expect(find.text('Comparer (4)'), findsOneWidget);
      expect(find.textContaining('4 profils au plus'), findsWidgets);
      await fin(t);
    });
  });

  group('favoris de l’organisation', () {
    testWidgets('liste des favoris du serveur, retrait envoyé au serveur', (t) async {
      srv.rpc['discovery_favorites'] = (_) => [
            {'user_id': _a, 'name': 'Alice N.', 'photo': null, 'added_at': '2026-11-20T10:00:00Z', 'note': 'Excellent profil', 'stage': 'preselectionne'},
          ];
      srv.rpc['discovery_favorite_set'] = (a) => {'student': a['p_student'], 'favorite': a['p_on']};
      await host(t, child: const TalentFavoritesScreen(), guarded: false);
      await attendre(t, find.text('Alice N.'));
      expect(find.text('Note : Excellent profil'), findsOneWidget);
      expect(find.text('Étape : Présélectionné'), findsOneWidget);
      await t.tap(find.text('Retirer des favoris'));
      await calme(t);
      final c = srv.callsOf('discovery_favorite_set').single.args;
      expect(c['p_student'], _a);
      expect(c['p_on'], false);
      await fin(t);
    });

    testWidgets('favoris vides : dit clairement qu’il n’y en a aucun ; panne : erreur, pas « aucun favori »', (t) async {
      srv.rpc['discovery_favorites'] = (_) => <Object?>[];
      await host(t, child: const TalentFavoritesScreen(), guarded: false);
      await attendre(t, find.textContaining('Aucun favori'));
      expect(find.textContaining('Aucun favori'), findsOneWidget);
      await fin(t);
    });

    testWidgets('favoris : serveur en panne → « Réessayer »', (t) async {
      srv.failRpc.add('discovery_favorites');
      await host(t, child: const TalentFavoritesScreen(), guarded: false);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucun favori'), findsNothing);
      await fin(t);
    });
  });
}
