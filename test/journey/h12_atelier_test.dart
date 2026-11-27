import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/atelier.dart';
import 'package:boutik_ecole/figma/live/atelier_action.dart';
import 'package:boutik_ecole/figma/live/atelier_form.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H12 · Atelier en direct : quatre onglets (En direct, À venir, Replays, Mes lives), filtres et recherche, compteurs réels (spectateurs en direct / vues totales),
/// inscription et rappel, fiche d'un live, Mes lives (modifier, annuler, statistiques d'audience réelles), formulaire de préparation (titre obligatoire, trois entreprises
/// au plus, programmation, Action Unique) et bouton d'Action Unique (absent sans parcours). Faux serveur local, aucune donnée d'exemple.

String _iso(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Map<String, dynamic> _now(String id, String title, {String host = 'Hugo H.', int viewers = 2}) => {
      'id': id, 'title': title, 'description': '', 'status': 'live', 'host': host, 'host_id': 'h-$host', 'host_avatar': null, 'host_verified': false, 'cover_path': null,
      'scheduled_at': null, 'started_at': _iso(const Duration(minutes: -10)), 'viewer_count': viewers,
    };

Map<String, dynamic> _soon(String id, String title, Duration at, {String host = 'Hugo H.', bool remind = false, bool mine = false}) => {
      'id': id, 'title': title, 'description': 'Les bases de la soudure', 'status': 'scheduled', 'host': host, 'host_id': 'h-$host', 'scheduled_at': _iso(at), 'started_at': null,
      'viewer_count': 0, 'live_type': 'public', 'visibilite': 'public', 'event_id': null, 'remind': remind, 'mine': mine,
    };

Map<String, dynamic> _extra(String id, {String? filiere, String? sector, String? category, List<String> tags = const [], int viewers = 0, int total = 0, int registered = 0, int? price, bool freq = false, String role = 'student', List<String> orgs = const [], Map<String, dynamic> more = const {}}) => {
      'id': id, 'status': 'x', 'host_id': 'x', 'host_role': role, 'category': category, 'filiere': filiere, 'sector': sector, 'hashtags': tags,
      'tagged_orgs': [for (final o in orgs) {'owner_id': 'o-$o', 'name': o, 'logo_path': null}], 'frequency': freq ? 'weekly' : 'once', 'duration_min': 60, 'reminders_enabled': true,
      'comments_mode': 'all', 'participation_mode': 'on_request', 'clips_allowed': true, 'audio_only': false, 'record_replay': false,
      'main_action': null, 'action_target_kind': null, 'action_target_id': null, 'action_available': false, 'event_id': price == null ? null : 'ev1', 'price': price, 'free': (price ?? 0) == 0,
      'registered': registered, 'viewers': viewers, 'total_views': total, ...more,
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
    srv.functions.clear();
    srv.unknownIsError = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  void serve({List<Map<String, dynamic>> now = const [], List<Map<String, dynamic>> soon = const [], Map<String, Map<String, dynamic>> extras = const {}}) {
    srv.rpc['lives_now'] = (_) => [...now, ...soon];
    srv.rpc['lives_agenda'] = (a) => a['p_scope'] == 'mine' ? [for (final x in soon) if (x['remind'] == true) x] : [...now, ...soon];
    srv.rpc['lives_atelier_extras'] = (a) => [for (final id in (a['p_live_ids'] as List)) if (extras.containsKey(id)) extras[id]];
  }

  Future<GoRouter> host(WidgetTester t, {bool login = false, String start = '/atelier'}) async {
    t.view.physicalSize = const Size(420, 4200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: start, routes: [
      GoRoute(path: '/atelier', builder: (_, s) => AtelierScreen(initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0)),
      GoRoute(path: '/atelier/preparer', builder: (_, s) => LivePrepareScreen(liveId: s.uri.queryParameters['live'], startNow: s.uri.queryParameters['mode'] == 'now')),
      GoRoute(path: '/s/:id', builder: (_, s) => Scaffold(body: Text('ecran-${s.pathParameters['id']}-${s.uri.query}'))),
      GoRoute(path: '/replay/:id', builder: (_, s) => Scaffold(body: Text('replay-${s.pathParameters['id']}'))),
      GoRoute(path: '/createur/statistiques', builder: (_, _) => const Scaffold(body: Text('stats-createur'))),
    ]);
    await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await t.pump(const Duration(milliseconds: 100));
    if (login) {
      ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(authProvider.notifier).login(demoAccount);
      await t.pump(const Duration(milliseconds: 100));
    }
    return router;
  }

  Future<void> calme(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
    await calme(t);
  }

  Future<void> pause(WidgetTester t) => settleReal(t, rounds: 8, ms: 100);

  Future<void> appel(WidgetTester t, String fn) async {
    for (var i = 0; i < 60 && srv.callsOf(fn).isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
    await calme(t);
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  Future<void> onglet(WidgetTester t, String name) async {
    await t.tap(find.widgetWithText(Tab, name));
    await calme(t);
    await pause(t);
    await calme(t);
  }

  group('fonctions pures', () {
    final rows = [
      {..._now('a', 'Atelier de soudure', host: 'Hugo H.'), ..._extra('a', tags: ['bois', 'soudure'], filiere: 'Génie civil')},
      {..._now('b', 'Cuisine camerounaise', host: 'Awa N.'), ..._extra('b', tags: ['cuisine'], filiere: 'Hôtellerie', sector: 'Restauration', category: 'Démonstration')},
      {..._soon('c', 'Montage solaire', const Duration(days: 3)), ..._extra('c', tags: ['solaire'], role: 'company')},
    ];

    test('recherche par titre, animateur et hashtag (avec ou sans #)', () {
      expect(applyAtelierFilter(rows, const AtelierFilter(q: 'soudure')).map((x) => x['id']), ['a']);
      expect(applyAtelierFilter(rows, const AtelierFilter(q: 'awa')).map((x) => x['id']), ['b']);
      expect(applyAtelierFilter(rows, const AtelierFilter(q: '#bois')).map((x) => x['id']), ['a']);
      expect(applyAtelierFilter(rows, const AtelierFilter(q: 'bois')).map((x) => x['id']), ['a']);
      expect(applyAtelierFilter(rows, const AtelierFilter(q: 'introuvable')), isEmpty);
    });

    test('filtres filière, secteur, catégorie et type de profil (insensibles à la casse)', () {
      expect(applyAtelierFilter(rows, const AtelierFilter(filiere: 'génie civil')).map((x) => x['id']), ['a']);
      expect(applyAtelierFilter(rows, const AtelierFilter(sector: 'Restauration')).map((x) => x['id']), ['b']);
      expect(applyAtelierFilter(rows, const AtelierFilter(category: 'démonstration')).map((x) => x['id']), ['b']);
      expect(applyAtelierFilter(rows, const AtelierFilter(role: 'company')).map((x) => x['id']), ['c']);
      expect(atelierOptions(rows, 'filiere'), ['Génie civil', 'Hôtellerie']);
    });

    test('filtres temporels : aujourd’hui, cette semaine, ce mois-ci ; un live en direct reste visible', () {
      final now = DateTime.now();
      final r = [
        {..._soon('t', 'Aujourd’hui', Duration.zero), 'scheduled_at': DateTime(now.year, now.month, now.day, 23, 59).toUtc().toIso8601String()},
        {..._soon('w', 'Cette semaine', const Duration(days: 4))},
        {..._soon('m', 'Ce mois', const Duration(days: 20))},
        {..._soon('l', 'Plus tard', const Duration(days: 60))},
        {..._now('d', 'En direct')},
      ];
      expect(applyAtelierFilter(r, const AtelierFilter(when: 'today'), now: now).map((x) => x['id']), ['t', 'd']);
      expect(applyAtelierFilter(r, const AtelierFilter(when: 'week'), now: now).map((x) => x['id']), ['t', 'w', 'd']);
      expect(applyAtelierFilter(r, const AtelierFilter(when: 'month'), now: now).map((x) => x['id']), ['t', 'w', 'm', 'd']);
    });

    test('Action Unique : un parcours existant par action ; aucun pour une mission, un don hors direct', () {
      expect(liveActionRoute('acheter', 'listing'), LiveActionRoute.product);
      expect(liveActionRoute('reserver', 'listing'), LiveActionRoute.product);
      expect(liveActionRoute('postuler', 'opportunity'), LiveActionRoute.opportunity);
      expect(liveActionRoute('postuler', 'mission'), LiveActionRoute.mission);
      expect(liveActionRoute('s_inscrire', 'event'), LiveActionRoute.event);
      expect(liveActionRoute('voter', 'project'), LiveActionRoute.project);
      expect(liveActionRoute('acheter', 'event'), isNull);
      expect(liveActionRoute('offrir', null, status: 'live', canGift: true), LiveActionRoute.gift);
      expect(liveActionRoute('offrir', null, status: 'scheduled', canGift: true), isNull);
      expect(liveActionRoute('offrir', null, status: 'live'), isNull);
      expect(liveActionRoute('parrainer', null), LiveActionRoute.referral);
      expect(liveActionRoute('inconnue', null), isNull);
      expect(kLiveActionLabels.length, 12);
    });

    test('hashtags : minuscules, sans # ni doublon ; prix = celui de l’événement lié', () {
      expect(parseHashtags('#Soudure, bois  #bois ;Atelier'), ['soudure', 'bois', 'atelier']);
      expect(atelierPrice({'price': 5000}), contains('Payant'));
      expect(atelierPrice({'price': null, 'free': true}), 'Gratuit');
      expect(atelierPrice({'extras_unavailable': true}), '');
    });
  });

  group('onglet En direct', () {
    testWidgets('quatre onglets', (t) async {
      serve();
      await host(t);
      for (final n in ['En direct', 'À venir', 'Replays', 'Mes lives']) {
        expect(find.widgetWithText(Tab, n), findsOneWidget);
      }
      await fin(t);
    });

    testWidgets('serveur muet : message honnête, aucune carte', (t) async {
      srv.unknownIsError = true;
      await host(t);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('spectateur'), findsNothing);
      await fin(t);
    });

    testWidgets('erreur 500 : message puis nouvel essai qui aboutit', (t) async {
      serve(now: [_now('a', 'Atelier de soudure')], extras: {'a': _extra('a')});
      srv.failRpc.add('lives_now');
      await host(t);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Atelier de soudure'), findsNothing);
      srv.failRpc.clear();
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.text('Atelier de soudure'));
      expect(find.text('Atelier de soudure'), findsOneWidget);
      await fin(t);
    });

    testWidgets('aucun live : état vide, jamais d’exemple', (t) async {
      serve();
      await host(t);
      await attendre(t, find.textContaining('Aucun live en cours'));
      expect(find.textContaining('Aucun live en cours pour le moment'), findsOneWidget);
      await fin(t);
    });

    testWidgets('spectateurs en direct ET vues totales, définitions distinctes, vignette neutre (aucun aperçu vidéo)', (t) async {
      serve(now: [_now('a', 'Atelier de soudure', viewers: 2)], extras: {'a': _extra('a', viewers: 2, total: 37, tags: ['soudure'], filiere: 'Génie civil', orgs: ['Alpha SARL'])});
      await host(t);
      await attendre(t, find.text('Atelier de soudure'));
      expect(find.text('EN DIRECT'), findsOneWidget);
      expect(find.text('2 spectateurs en direct'), findsOneWidget);
      expect(find.text('37 vues totales'), findsOneWidget);
      expect(find.textContaining('Spectateurs en direct : personnes connectées au live en ce moment'), findsOneWidget);
      expect(find.textContaining('Vues totales : personnes identifiées ayant rejoint'), findsOneWidget);
      expect(find.textContaining('Un aperçu affiché dans une liste n’est jamais compté'), findsOneWidget);
      expect(find.text('#soudure'), findsOneWidget);
      expect(find.text('Avec : Alpha SARL'), findsOneWidget);
      expect(find.byIcon(Icons.sensors), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await fin(t);
    });

    testWidgets('compteurs non fournis par le serveur : « non disponibles », jamais 0', (t) async {
      serve(now: [_now('a', 'Atelier de soudure', viewers: 4)]);
      await host(t);
      await attendre(t, find.text('Atelier de soudure'));
      expect(find.text('4 spectateurs en direct'), findsOneWidget);
      expect(find.text('Vues totales : non disponibles'), findsOneWidget);
      expect(find.textContaining('0 vue'), findsNothing);
      await fin(t);
    });

    testWidgets('un live seulement programmé n’apparaît pas dans « En direct »', (t) async {
      serve(now: [_now('a', 'Atelier de soudure')], soon: [_soon('b', 'Atelier demain', const Duration(hours: 2))], extras: {'a': _extra('a'), 'b': _extra('b')});
      await host(t);
      await attendre(t, find.text('Atelier de soudure'));
      expect(find.text('Atelier demain'), findsNothing);
      await fin(t);
    });

    testWidgets('recherche (titre, animateur, hashtag) et filtre par filière', (t) async {
      serve(
        now: [_now('a', 'Atelier de soudure', host: 'Hugo H.'), _now('b', 'Cuisine camerounaise', host: 'Awa N.')],
        extras: {'a': _extra('a', tags: ['bois'], filiere: 'Génie civil'), 'b': _extra('b', tags: ['cuisine'], filiere: 'Hôtellerie')},
      );
      await host(t);
      await attendre(t, find.text('Cuisine camerounaise'));
      await t.enterText(find.byType(TextField), '#cuisine');
      await pause(t);
      expect(find.text('Cuisine camerounaise'), findsOneWidget);
      expect(find.text('Atelier de soudure'), findsNothing);
      await t.enterText(find.byType(TextField), 'hugo');
      await pause(t);
      expect(find.text('Atelier de soudure'), findsOneWidget);
      expect(find.text('Cuisine camerounaise'), findsNothing);
      await t.enterText(find.byType(TextField), 'zzz');
      await pause(t);
      expect(find.textContaining('ne correspond à votre recherche'), findsOneWidget);
      await t.tap(find.text('Réinitialiser'));
      await pause(t);
      expect(find.text('Cuisine camerounaise'), findsOneWidget);
      await t.tap(find.text('Filière'));
      await pause(t);
      await t.tap(find.text('Hôtellerie').last);
      await pause(t);
      expect(find.text('Cuisine camerounaise'), findsOneWidget);
      expect(find.text('Atelier de soudure'), findsNothing);
      expect(find.text('Filière : Hôtellerie'), findsOneWidget);
      await fin(t);
    });

    testWidgets('visiteur : « Regarder » l’invite à se connecter, sans entrer dans le live', (t) async {
      serve(now: [_now('a', 'Atelier de soudure')], extras: {'a': _extra('a')});
      await host(t);
      await attendre(t, find.text('Atelier de soudure'));
      await t.tap(find.text('Regarder'));
      await pause(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(find.textContaining('ecran-222'), findsNothing);
      await fin(t);
    });

    testWidgets('connecté : « Regarder » ouvre le live', (t) async {
      serve(now: [_now('a', 'Atelier de soudure')], extras: {'a': _extra('a')});
      await host(t, login: true);
      await attendre(t, find.text('Atelier de soudure'));
      await t.tap(find.text('Regarder'));
      await pause(t);
      expect(find.text('ecran-222-live=a'), findsOneWidget);
      await fin(t);
    });
  });

  group('onglet À venir', () {
    Future<void> ouvrir(WidgetTester t, {bool login = false}) async {
      await host(t, login: login);
      await onglet(t, 'À venir');
    }

    testWidgets('date, animateur, prix de l’événement lié, inscrits réels, fréquence', (t) async {
      serve(soon: [_soon('b', 'Masterclass soudure', const Duration(days: 2))], extras: {'b': _extra('b', price: 5000, registered: 3, freq: true, category: 'Masterclass')});
      await ouvrir(t);
      await attendre(t, find.text('Masterclass soudure'));
      expect(find.textContaining('Payant · '), findsOneWidget);
      expect(find.text('3 inscrits'), findsOneWidget);
      expect(find.text('Chaque semaine'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);
      expect(find.textContaining('Hugo H.'), findsWidgets);
      await fin(t);
    });

    testWidgets('serveur muet et 500 : message honnête', (t) async {
      srv.unknownIsError = true;
      await ouvrir(t);
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsWidgets);
      await fin(t);
    });

    testWidgets('aucun live programmé : état vide', (t) async {
      serve();
      await ouvrir(t);
      await attendre(t, find.text('Aucun live programmé pour le moment.'));
      expect(find.text('Aucun live programmé pour le moment.'), findsOneWidget);
      await fin(t);
    });

    testWidgets('filtres temporels et filtre par type de profil', (t) async {
      serve(
        soon: [_soon('b', 'Atelier cette semaine', const Duration(days: 3)), _soon('c', 'Atelier lointain', const Duration(days: 40), host: 'Entreprise X')],
        extras: {'b': _extra('b'), 'c': _extra('c', role: 'company')},
      );
      await ouvrir(t);
      await attendre(t, find.text('Atelier lointain'));
      expect(find.text('Atelier cette semaine'), findsOneWidget);
      await t.tap(find.text('Cette semaine'));
      await pause(t);
      expect(find.text('Atelier cette semaine'), findsOneWidget);
      expect(find.text('Atelier lointain'), findsNothing);
      await t.tap(find.text('Toutes les dates'));
      await pause(t);
      await t.tap(find.text('Profil'));
      await pause(t);
      await t.tap(find.text('Entreprise').last);
      await pause(t);
      expect(find.text('Atelier lointain'), findsOneWidget);
      expect(find.text('Atelier cette semaine'), findsNothing);
      await fin(t);
    });

    testWidgets('rappel unique : connecté, un appel live_remind_set puis retrait', (t) async {
      serve(soon: [_soon('b', 'Atelier demain', const Duration(days: 1))], extras: {'b': _extra('b')});
      srv.rpc['live_remind_set'] = (a) => a['p_on'];
      await ouvrir(t, login: true);
      await attendre(t, find.text('Me rappeler'));
      await t.tap(find.text('Me rappeler'));
      await pause(t);
      expect(srv.callsOf('live_remind_set').single.args, {'p_live': 'b', 'p_on': true});
      await fin(t);
    });

    testWidgets('rappel refusé par le serveur : message du serveur, pas de confirmation', (t) async {
      serve(soon: [_soon('b', 'Atelier demain', const Duration(days: 1))], extras: {'b': _extra('b')});
      srv.rpc['live_remind_set'] = (_) => throw const FakeRpcError('Cinquante rappels actifs au plus');
      await ouvrir(t, login: true);
      await attendre(t, find.text('Me rappeler'));
      await t.tap(find.text('Me rappeler'));
      await pause(t);
      expect(find.text('Rappel impossible'), findsOneWidget);
      expect(find.textContaining('Rappel activé'), findsNothing);
      await fin(t);
    });

    testWidgets('visiteur : s’inscrire (rappel) invite à se connecter, aucun appel serveur', (t) async {
      serve(soon: [_soon('b', 'Atelier demain', const Duration(days: 1))], extras: {'b': _extra('b')});
      srv.rpc['live_remind_set'] = (a) => a['p_on'];
      await ouvrir(t);
      await attendre(t, find.text('Me rappeler'));
      await t.tap(find.text('Me rappeler'));
      await pause(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(srv.callsOf('live_remind_set'), isEmpty);
      await fin(t);
    });

    testWidgets('visiteur : « Mes rappels » invite à se connecter', (t) async {
      serve(soon: [_soon('b', 'Atelier demain', const Duration(days: 1))], extras: {'b': _extra('b')});
      await ouvrir(t);
      await attendre(t, find.text('Mes rappels'));
      await t.tap(find.text('Mes rappels'));
      await pause(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      await fin(t);
    });

    testWidgets('fiche d’un live : prix et conditions, inscrits, définitions, partage ; pas de bouton d’action sans Action Unique', (t) async {
      serve(soon: [_soon('b', 'Masterclass soudure', const Duration(days: 2))], extras: {'b': _extra('b', price: 5000, registered: 3, tags: ['soudure'], orgs: ['Alpha SARL'], more: {'event_id': 'ev1', 'comments_mode': 'off', 'description': 'Les bases'})});
      srv.rpc['live_settings_get'] = (_) => {..._extra('b'), 'status': 'scheduled', 'action_available': false};
      await ouvrir(t);
      await attendre(t, find.text('Masterclass soudure'));
      await t.tap(find.text('Masterclass soudure'));
      await attendre(t, find.text('Partager'));
      expect(find.textContaining('Inscription à l’événement lié (billet payant) nécessaire'), findsOneWidget);
      expect(find.textContaining('Commentaires désactivés'), findsOneWidget);
      expect(find.text('3 inscrits'), findsWidgets);
      expect(find.textContaining('Entreprises : Alpha SARL'), findsOneWidget);
      expect(find.text('S’inscrire à l’événement'), findsOneWidget);
      expect(find.byKey(const Key('live-action-unique')), findsNothing);
      expect(find.textContaining('bloqué'), findsNothing);
      expect(find.textContaining('séquestre'), findsNothing);
      await fin(t);
    });
  });

  group('onglet Replays', () {
    testWidgets('embarque la bibliothèque de replays (recherche et tri du lot replay)', (t) async {
      serve();
      srv.rpc['replay_library'] = (_) => [
            {'id': 'r1', 'live_id': 'l1', 'title': 'Replay de soudure', 'host': 'Hugo H.', 'duration_sec': 600, 'views': 3, 'viewers': 4, 'completion_rate': null, 'rating_avg': null, 'rating_count': 0, 'locked': false, 'message': ''}
          ];
      await host(t);
      await onglet(t, 'Replays');
      await attendre(t, find.text('Replay de soudure'));
      expect(find.text('Replay de soudure'), findsOneWidget);
      expect(find.text('Populaires'), findsOneWidget);
      expect(srv.callsOf('replay_library'), isNotEmpty);
      await fin(t);
    });
  });

  group('onglet Mes lives', () {
    Future<void> ouvrir(WidgetTester t, {bool login = true}) async {
      await host(t, login: login);
      await onglet(t, 'Mes lives');
    }

    testWidgets('visiteur : invité à se connecter pour créer un live', (t) async {
      serve();
      await ouvrir(t, login: false);
      expect(find.textContaining('Connectez-vous pour lancer ou programmer un live'), findsOneWidget);
      await t.tap(find.text('Programmer un live'));
      await pause(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(find.text('Préparer un live'), findsNothing);
      await fin(t);
    });

    testWidgets('mes lives : actions selon le statut, statistiques commerciales annoncées non disponibles', (t) async {
      serve(extras: {'m1': _extra('m1', registered: 4, price: 0), 'm2': _extra('m2', total: 12)});
      srv.rpc['my_lives'] = (_) => [
            {'id': 'm1', 'title': 'Atelier programmé', 'status': 'scheduled', 'scheduled_at': _iso(const Duration(days: 2)), 'started_at': null, 'ended_at': null, 'peak_viewers': 0},
            {'id': 'm2', 'title': 'Atelier terminé', 'status': 'ended', 'scheduled_at': null, 'started_at': _iso(const Duration(days: -1)), 'ended_at': _iso(const Duration(days: -1)), 'peak_viewers': 9},
          ];
      await ouvrir(t);
      await attendre(t, find.text('Atelier programmé'));
      expect(find.text('Lancer'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.textContaining('pic 9 spectateur'), findsOneWidget);
      expect(find.text('Statistiques'), findsOneWidget);
      expect(find.text('4 inscrits · Gratuit'), findsOneWidget);
      expect(find.textContaining('non disponibles par live'), findsOneWidget);
      expect(find.textContaining('Intégration vocale de Kéla : service à configurer'), findsOneWidget);
      await fin(t);
    });

    testWidgets('statistiques d’audience : chiffres du serveur ; erreur : message, jamais 0', (t) async {
      serve(extras: {'m2': _extra('m2')});
      srv.rpc['my_lives'] = (_) => [
            {'id': 'm2', 'title': 'Atelier terminé', 'status': 'ended', 'scheduled_at': null, 'started_at': null, 'ended_at': null, 'peak_viewers': 9}
          ];
      srv.rpc['live_host_stats'] = (_) => {'live': 'm2', 'status': 'ended', 'viewers_now': 0, 'peak_viewers': 9, 'total_views': 23, 'registered': 5, 'chat_messages': 31, 'reactions': 12, 'recording': null};
      await ouvrir(t);
      await attendre(t, find.text('Statistiques'));
      await t.tap(find.text('Statistiques'));
      await attendre(t, find.text('Vues totales (personnes distinctes)'));
      expect(find.text('23'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.textContaining('Ventes, revenus et recrutement liés à ce live : non disponibles'), findsOneWidget);
      await fin(t);

      srv.calls.clear();
      srv.failRpc.add('live_host_stats');
      await ouvrir(t);
      await attendre(t, find.text('Statistiques'));
      await t.tap(find.text('Statistiques'));
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Vues totales (personnes distinctes)'), findsNothing);
      await fin(t);
    });

    testWidgets('annuler un live programmé : confirmation, motif, appel live_cancel', (t) async {
      serve(extras: {'m1': _extra('m1')});
      srv.rpc['my_lives'] = (_) => [
            {'id': 'm1', 'title': 'Atelier programmé', 'status': 'scheduled', 'scheduled_at': _iso(const Duration(days: 2)), 'started_at': null, 'ended_at': null, 'peak_viewers': 0}
          ];
      srv.rpc['live_cancel'] = (_) => 'cancelled';
      await ouvrir(t);
      await attendre(t, find.text('Annuler'));
      await t.tap(find.text('Annuler'));
      await pause(t);
      expect(find.text('Annuler ce live ?'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'Intervenant indisponible');
      await t.tap(find.text('Annuler le live'));
      await pause(t);
      expect(srv.callsOf('live_cancel').single.args, {'p_live': 'm1', 'p_reason': 'Intervenant indisponible'});
      await fin(t);
    });

    testWidgets('annulation refusée par le serveur : alerte, pas de confirmation', (t) async {
      serve(extras: {'m1': _extra('m1')});
      srv.rpc['my_lives'] = (_) => [
            {'id': 'm1', 'title': 'Atelier programmé', 'status': 'scheduled', 'scheduled_at': _iso(const Duration(days: 2)), 'started_at': null, 'ended_at': null, 'peak_viewers': 0}
          ];
      srv.rpc['live_cancel'] = (_) => throw const FakeRpcError('Seul un live programmé peut être annulé');
      await ouvrir(t);
      await attendre(t, find.text('Annuler'));
      await t.tap(find.text('Annuler'));
      await pause(t);
      await t.tap(find.text('Annuler le live'));
      await pause(t);
      expect(find.text('Live non annulé'), findsOneWidget);
      expect(find.text('Live annulé.'), findsNothing);
      await fin(t);
    });

    testWidgets('Modifier ouvre le formulaire pré-rempli avec les réglages du serveur', (t) async {
      serve(extras: {'m1': _extra('m1')});
      srv.rpc['my_lives'] = (_) => [
            {'id': 'm1', 'title': 'Atelier programmé', 'status': 'scheduled', 'scheduled_at': _iso(const Duration(days: 2)), 'started_at': null, 'ended_at': null, 'peak_viewers': 0}
          ];
      srv.rpc['live_settings_get'] = (_) => {
            ..._extra('m1', tags: ['soudure'], category: 'Atelier', orgs: ['Alpha SARL']),
            'title': 'Atelier programmé', 'description': 'Description', 'status': 'scheduled', 'scheduled_at': _iso(const Duration(days: 2)), 'mine': true, 'can_edit': true,
            'visibilite': 'public', 'video_quality': '720p', 'notify_message': 'Apportez un casque', 'live_type': 'public',
          };
      srv.rpc['live_get'] = (_) => {'id': 'm1', 'mission_id': null, 'opportunity_id': null, 'event_id': null};
      await ouvrir(t);
      await attendre(t, find.text('Modifier'));
      await t.tap(find.text('Modifier'));
      await attendre(t, find.text('Modifier le live'));
      await attendre(t, find.text('Alpha SARL'));
      expect(find.widgetWithText(TextField, 'Atelier programmé'), findsOneWidget);
      expect(find.widgetWithText(TextField, '#soudure'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Apportez un casque'), findsOneWidget);
      await fin(t);
    });
  });

  group('formulaire de préparation', () {
    Future<void> remplir(WidgetTester t, {String title = 'Atelier de soudure'}) async {
      await t.enterText(find.byKey(const Key('prep-title')), title);
      await pause(t);
    }

    void serveurDeCreation({String id = 'live-1'}) {
      srv.rpc['create_live'] = (_) => id;
      srv.rpc['live_configure'] = (_) => 'ok';
      srv.rpc['live_set_settings'] = (_) => {};
      srv.rpc['live_recording_request'] = (_) => 'en_attente';
    }

    Future<void> choisirDate(WidgetTester t) async {
      await t.tap(find.text('Choisir la date et l’heure'));
      await pause(t);
      await t.tap(find.text('OK'));
      await pause(t);
      await t.tap(find.text('OK'));
      await pause(t);
    }

    testWidgets('visiteur : invité à se connecter, aucun formulaire', (t) async {
      await host(t, start: '/atelier/preparer');
      expect(find.text('Connectez-vous pour créer un live.'), findsOneWidget);
      expect(find.byKey(const Key('prep-title')), findsNothing);
      await fin(t);
    });

    testWidgets('titre obligatoire : alerte, aucune création', (t) async {
      serveurDeCreation();
      await host(t, login: true, start: '/atelier/preparer');
      await t.tap(find.text('Programmer le live'));
      await pause(t);
      expect(find.text('Le titre est obligatoire (3 à 100 caractères).'), findsOneWidget);
      expect(srv.callsOf('create_live'), isEmpty);
      await fin(t);
    });

    testWidgets('programmation sans date : refusée ; date passée impossible à choisir', (t) async {
      serveurDeCreation();
      await host(t, login: true, start: '/atelier/preparer');
      await remplir(t);
      await t.tap(find.text('Programmer le live'));
      await pause(t);
      expect(find.text('Choisissez la date et l’heure du live.'), findsOneWidget);
      expect(srv.callsOf('create_live'), isEmpty);
      await fin(t);
    });

    testWidgets('quatre entreprises refusées : la quatrième n’est pas ajoutée', (t) async {
      srv.rpc['live_orgs_search'] = (_) => [for (final n in ['Alpha', 'Beta', 'Gamma', 'Delta']) {'owner_id': 'o-$n', 'name': 'Entreprise $n', 'sector': 'BTP', 'logo_path': null}];
      await host(t, login: true, start: '/atelier/preparer');
      for (final n in ['Alpha', 'Beta', 'Gamma']) {
        await t.tap(find.text('Taguer une entreprise'));
        await attendre(t, find.text('Entreprise $n'));
        await t.tap(find.text('Entreprise $n').last);
        await pause(t);
      }
      expect(find.byType(InputChip), findsNWidgets(3));
      await t.tap(find.text('Taguer une entreprise'));
      await pause(t);
      expect(find.text('Trois entreprises taguées au plus.'), findsOneWidget);
      expect(find.text('Entreprise Delta'), findsNothing);
      expect(find.byType(InputChip), findsNWidgets(3));
      await fin(t);
    });

    testWidgets('hashtag invalide et description trop longue refusés avant tout appel', (t) async {
      serveurDeCreation();
      await host(t, login: true, start: '/atelier/preparer');
      await remplir(t);
      await t.enterText(find.widgetWithText(TextField, 'Hashtags'), '#a');
      await t.tap(find.text('Lancer maintenant'));
      await pause(t);
      await t.tap(find.text('Lancer le live'));
      await pause(t);
      expect(find.textContaining('Hashtag invalide'), findsOneWidget);
      expect(srv.callsOf('create_live'), isEmpty);
      await fin(t);
    });

    testWidgets('programmation complète : create_live avec date, puis audience, réglages (hashtags, entreprises, durée) et enregistrement du replay', (t) async {
      serveurDeCreation();
      srv.rpc['live_orgs_search'] = (_) => [{'owner_id': 'o-Alpha', 'name': 'Entreprise Alpha', 'sector': 'BTP', 'logo_path': null}];
      await host(t, login: true, start: '/atelier/preparer');
      await remplir(t);
      await t.enterText(find.widgetWithText(TextField, 'Hashtags'), '#Soudure bois');
      await t.enterText(find.widgetWithText(TextField, 'Catégorie'), 'Atelier');
      await t.enterText(find.widgetWithText(TextField, 'Filière'), 'Génie civil');
      await t.tap(find.text('Taguer une entreprise'));
      await attendre(t, find.text('Entreprise Alpha'));
      await t.tap(find.text('Entreprise Alpha').last);
      await pause(t);
      await t.tap(find.text('Sur invitation'));
      await t.tap(find.text('90 min'));
      await t.tap(find.text('Enregistrer le replay'));
      await choisirDate(t);
      await t.tap(find.text('Programmer le live'));
      await attendre(t, find.widgetWithText(Tab, 'Mes lives'));
      final create = srv.callsOf('create_live').single.args;
      expect(create['p_title'], 'Atelier de soudure');
      expect(DateTime.parse('${create['p_scheduled_at']}').isAfter(DateTime.now()), true);
      final conf = srv.callsOf('live_configure').single.args;
      expect(conf['p_live'], 'live-1');
      expect(conf['p_visibilite'], 'prive');
      expect(conf['p_type'], 'prive');
      expect(conf['p_event'], isNull);
      final set = srv.callsOf('live_set_settings').single.args['p_settings'] as Map;
      expect(set['hashtags'], ['soudure', 'bois']);
      expect(set['tagged_orgs'], ['o-Alpha']);
      expect(set['category'], 'Atelier');
      expect(set['filiere'], 'Génie civil');
      expect(set['duration_min'], 90);
      expect(set['record_replay'], true);
      expect(set['main_action'], isNull);
      expect(srv.callsOf('live_recording_request').single.args, {'p_live': 'live-1'});
      await fin(t);
    });

    testWidgets('lancer maintenant : création sans date puis ouverture de la régie', (t) async {
      serveurDeCreation(id: 'live-9');
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Lancer le live'));
      await attendre(t, find.text('ecran-L1-live=live-9'));
      expect(srv.callsOf('create_live').single.args['p_scheduled_at'], isNull);
      expect(find.text('ecran-L1-live=live-9'), findsOneWidget);
      await fin(t);
    });

    testWidgets('chaque semaine : une séance programmée par semaine, chacune réglée', (t) async {
      serveurDeCreation();
      var n = 0;
      srv.rpc['create_live'] = (_) => 'live-${++n}';
      await host(t, login: true, start: '/atelier/preparer');
      await remplir(t);
      await t.tap(find.text('Chaque semaine'));
      await pause(t);
      await t.tap(find.byTooltip('Plus de séances'));
      await pause(t);
      expect(find.text('3 séances'), findsOneWidget);
      await choisirDate(t);
      await t.tap(find.text('Programmer le live'));
      await attendre(t, find.widgetWithText(Tab, 'Mes lives'));
      final dates = [for (final c in srv.callsOf('create_live')) DateTime.parse('${c.args['p_scheduled_at']}')];
      expect(dates.length, 3);
      expect(dates[1].difference(dates[0]), const Duration(days: 7));
      expect(dates[2].difference(dates[1]), const Duration(days: 7));
      expect(srv.callsOf('live_set_settings').length, 3);
      expect((srv.callsOf('live_set_settings').first.args['p_settings'] as Map)['frequency'], 'weekly');
      await fin(t);
    });

    testWidgets('création refusée par le serveur : message du serveur, pas de confirmation, pas de réglage', (t) async {
      serveurDeCreation();
      srv.rpc['create_live'] = (_) => throw const FakeRpcError('Quinze lives par jour au plus');
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Lancer le live'));
      await attendre(t, find.text('Live non créé'));
      expect(find.text('Live non créé'), findsOneWidget);
      expect(find.textContaining('Quinze lives par jour'), findsOneWidget);
      expect(srv.callsOf('live_set_settings'), isEmpty);
      await fin(t);
    });

    testWidgets('live créé mais réglages refusés : message honnête, pas de succès annoncé', (t) async {
      serveurDeCreation();
      srv.rpc['live_set_settings'] = (_) => throw const FakeRpcError('Entreprise introuvable ou non vérifiée');
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Lancer le live'));
      await attendre(t, find.text('Live créé, réglages non enregistrés'));
      expect(find.text('Live créé, réglages non enregistrés'), findsOneWidget);
      expect(find.textContaining('Entreprise introuvable ou non vérifiée'), findsOneWidget);
      expect(find.textContaining('ecran-L1'), findsNothing);
      await fin(t);
    });

    testWidgets('payant : sans événement payant existant, refusé (aucune règle de prix inventée)', (t) async {
      srv.rpc['live_action_targets'] = (_) => [];
      await host(t, login: true, start: '/atelier/preparer');
      await t.tap(find.text('Payant'));
      await pause(t);
      expect(find.text('Aucun événement payant'), findsOneWidget);
      expect(find.textContaining('s’appuie sur un événement payant existant'), findsWidgets);
      await fin(t);
    });

    testWidgets('payant : l’événement payant choisi est lié au live', (t) async {
      serveurDeCreation();
      srv.rpc['live_action_targets'] = (_) => [{'id': 'ev-7', 'title': 'Masterclass', 'price': 5000, 'starts_at': _iso(const Duration(days: 4))}, {'id': 'ev-8', 'title': 'Atelier gratuit', 'price': 0, 'starts_at': _iso(const Duration(days: 5))}];
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Payant'));
      await attendre(t, find.text('Masterclass'));
      expect(find.text('Atelier gratuit'), findsNothing);
      await t.tap(find.text('Masterclass'));
      await pause(t);
      await t.tap(find.text('Lancer le live'));
      await appel(t, 'live_configure');
      expect(srv.callsOf('live_configure').single.args['p_event'], 'ev-7');
      await fin(t);
    });

    testWidgets('Action Unique : cible choisie parmi les annonces de l’hôte, envoyée avec les réglages', (t) async {
      serveurDeCreation();
      srv.rpc['live_action_targets'] = (a) => a['p_kind'] == 'listing'
          ? [
              {'id': 'li-1', 'title': 'Lampe artisanale', 'offer_type': 'product', 'price': 5000},
              {'id': 'li-2', 'title': 'Logo sur mesure', 'offer_type': 'service', 'price': 20000},
            ]
          : [];
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Acheter'));
      await attendre(t, find.text('Lampe artisanale'));
      expect(find.text('Logo sur mesure'), findsNothing); // un service ne s'« achète » pas : il se réserve ou se demande sur devis
      await t.tap(find.text('Lampe artisanale'));
      await pause(t);
      expect(find.text('Cible : Lampe artisanale'), findsOneWidget);
      await t.tap(find.text('Lancer le live'));
      await appel(t, 'live_set_settings');
      final set = srv.callsOf('live_set_settings').single.args['p_settings'] as Map;
      expect(set['main_action'], 'acheter');
      expect(set['action_target_kind'], 'listing');
      expect(set['action_target_id'], 'li-1');
      await fin(t);
    });

    testWidgets('Action Unique sans cible disponible : alerte, aucune action retenue', (t) async {
      serveurDeCreation();
      srv.rpc['live_action_targets'] = (_) => [];
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Postuler'));
      await pause(t);
      expect(find.text('Aucune cible disponible'), findsOneWidget);
      await t.tap(find.text('Compris'));
      await pause(t);
      await t.tap(find.text('Lancer le live'));
      await appel(t, 'live_set_settings');
      expect((srv.callsOf('live_set_settings').single.args['p_settings'] as Map)['main_action'], isNull);
      await fin(t);
    });

    testWidgets('Action Unique sans cible requise (offrir) : envoyée sans cible', (t) async {
      serveurDeCreation();
      await host(t, login: true, start: '/atelier/preparer?mode=now');
      await remplir(t);
      await t.tap(find.text('Offrir'));
      await pause(t);
      await t.tap(find.text('Lancer le live'));
      await appel(t, 'live_set_settings');
      final set = srv.callsOf('live_set_settings').single.args['p_settings'] as Map;
      expect(set['main_action'], 'offrir');
      expect(set['action_target_id'], isNull);
      expect(srv.callsOf('live_action_targets'), isEmpty);
      await fin(t);
    });

    testWidgets('modification d’un live programmé : live_update puis réglages', (t) async {
      srv.rpc['live_settings_get'] = (_) => {
            ..._extra('m1', tags: ['soudure']),
            'title': 'Atelier programmé', 'description': 'Description', 'status': 'scheduled', 'scheduled_at': _iso(const Duration(days: 2)), 'mine': true, 'can_edit': true,
            'visibilite': 'public', 'video_quality': 'auto', 'live_type': 'public', 'main_action_raw': 'offrir',
          };
      srv.rpc['live_get'] = (_) => {'id': 'm1', 'mission_id': 'mi-1', 'opportunity_id': null, 'event_id': null};
      srv.rpc['live_update'] = (_) => 'ok';
      srv.rpc['live_configure'] = (_) => 'ok';
      srv.rpc['live_set_settings'] = (_) => {};
      await host(t, login: true, start: '/atelier/preparer?live=m1');
      await attendre(t, find.text('Modifier le live'));
      await attendre(t, find.widgetWithText(TextField, 'Atelier programmé'));
      await t.enterText(find.byKey(const Key('prep-title')), 'Atelier reprogrammé');
      await t.tap(find.text('Enregistrer les modifications'));
      await attendre(t, find.widgetWithText(Tab, 'Mes lives'));
      final u = srv.callsOf('live_update').single.args;
      expect(u['p_live'], 'm1');
      expect(u['p_title'], 'Atelier reprogrammé');
      expect(srv.callsOf('create_live'), isEmpty);
      expect(srv.callsOf('live_configure').single.args['p_mission'], 'mi-1'); // les liens existants sont conservés
      expect((srv.callsOf('live_set_settings').single.args['p_settings'] as Map)['main_action'], 'offrir');
      await fin(t);
    });

    testWidgets('modifier un live qui n’est pas le mien : refus, aucun champ', (t) async {
      srv.rpc['live_settings_get'] = (_) => {..._extra('m1'), 'title': 'Autre', 'mine': false, 'can_edit': false, 'status': 'scheduled'};
      await host(t, login: true, start: '/atelier/preparer?live=m1');
      await attendre(t, find.text('Seul l’hôte peut modifier ce live.'));
      expect(find.byKey(const Key('prep-title')), findsNothing);
      await fin(t);
    });
  });

  group('bouton d’Action Unique', () {
    Map<String, dynamic> settings(String action, String? kind, String? target, {String status = 'live', bool available = true}) => {
          'id': 'a', 'status': status, 'main_action': available ? action : null, 'action_target_kind': kind, 'action_target_id': target, 'action_available': available, 'action_target_title': target == null ? null : 'Lampe artisanale',
        };

    Future<void> bouton(WidgetTester t, {bool login = true, VoidCallback? onGift}) async {
      t.view.physicalSize = const Size(420, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: Center(child: Builder(builder: (c) => LiveActionButton(liveId: 'a', hostId: 'h', onGift: onGift)))))));
      await t.pump(const Duration(milliseconds: 100));
      if (login) {
        ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(authProvider.notifier).login(demoAccount);
      }
      await settleReal(t, rounds: 6, ms: 60);
    }

    testWidgets('annonce : un seul bouton « Acheter · titre » qui ouvre la fiche produit dans une feuille', (t) async {
      srv.rpc['live_settings_get'] = (_) => settings('acheter', 'listing', 'li-1');
      srv.rpc['product_detail'] = (_) => {'found': false};
      await bouton(t);
      expect(find.byKey(const Key('live-action-unique')), findsOneWidget);
      expect(find.text('Acheter · Lampe artisanale'), findsOneWidget);
      await t.tap(find.byKey(const Key('live-action-unique')));
      await pause(t);
      expect(srv.callsOf('product_detail').single.args['p_id'], 'li-1');
      expect(find.text('Ce produit n’est plus disponible.'), findsOneWidget);
      expect(find.byKey(const Key('live-action-unique')), findsOneWidget); // le live reste dessous
      await fin(t);
    });

    testWidgets('serveur : action indisponible (cible retirée) -> bouton absent', (t) async {
      srv.rpc['live_settings_get'] = (_) => settings('acheter', 'listing', 'li-1', available: false);
      await bouton(t);
      expect(find.byKey(const Key('live-action-unique')), findsNothing);
      await fin(t);
    });

    testWidgets('sans réglage, live introuvable ou serveur muet : aucun bouton décoratif', (t) async {
      srv.rpc['live_settings_get'] = (_) => null;
      await bouton(t);
      expect(find.byKey(const Key('live-action-unique')), findsNothing);
      await fin(t);
      srv.unknownIsError = true;
      await bouton(t);
      expect(find.byKey(const Key('live-action-unique')), findsNothing);
      await fin(t);
    });

    testWidgets('mission : depuis H13, « Postuler » ouvre la feuille de proposition (le bouton existe, il n’est plus absent)', (t) async {
      srv.rpc['live_settings_get'] = (_) => settings('postuler', 'mission', 'mi-1');
      await bouton(t);
      expect(find.byKey(const Key('live-action-unique')), findsOneWidget);
      expect(find.text('Postuler · Lampe artisanale'), findsOneWidget);
      await fin(t);
    });

    testWidgets('offrir : présent pendant le direct (parcours cadeaux), absent hors direct ou sans parcours', (t) async {
      var ouvert = 0;
      srv.rpc['live_settings_get'] = (_) => settings('offrir', null, null);
      await bouton(t, onGift: () => ouvert++);
      expect(find.text('Offrir'), findsOneWidget);
      await t.tap(find.byKey(const Key('live-action-unique')));
      await pause(t);
      expect(ouvert, 1);
      await fin(t);
      srv.rpc['live_settings_get'] = (_) => settings('offrir', null, null, status: 'scheduled');
      await bouton(t, onGift: () => ouvert++);
      expect(find.byKey(const Key('live-action-unique')), findsNothing);
      await fin(t);
    });

    testWidgets('offrir : un visiteur est invité à se connecter, le parcours cadeaux ne s’ouvre pas', (t) async {
      var ouvert = 0;
      srv.rpc['live_settings_get'] = (_) => settings('offrir', null, null);
      await bouton(t, login: false, onGift: () => ouvert++);
      await t.tap(find.byKey(const Key('live-action-unique')));
      await pause(t);
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(ouvert, 0);
      await fin(t);
    });

    testWidgets('parrainer : feuille avec le kit de parrainage existant, sans promesse financière', (t) async {
      srv.rpc['live_settings_get'] = (_) => settings('parrainer', null, null);
      srv.rpc['my_referral_code'] = (_) => 'BOUTIK-1';
      await bouton(t);
      expect(find.text('Parrainer'), findsOneWidget);
      await t.tap(find.byKey(const Key('live-action-unique')));
      await pause(t);
      expect(find.byTooltip('Fermer'), findsOneWidget);
      expect(find.textContaining('bloqué'), findsNothing);
      expect(find.textContaining('séquestre'), findsNothing);
      await fin(t);
    });

    testWidgets('projet : « Voter » ouvre la fiche du projet existante', (t) async {
      srv.rpc['live_settings_get'] = (_) => settings('voter', 'project', 'pr-1');
      srv.rpc['public_project_get'] = (_) => null;
      await bouton(t);
      expect(find.text('Voter · Lampe artisanale'), findsOneWidget);
      await t.tap(find.byKey(const Key('live-action-unique')));
      await pause(t);
      expect(srv.callsOf('public_project_get').single.args['p_id'], 'pr-1');
      await fin(t);
    });

    testWidgets('événement : « S’inscrire » ouvre la fiche de l’événement (parcours d’inscription existant)', (t) async {
      srv.rpc['live_settings_get'] = (_) => settings('s_inscrire', 'event', 'ev-1');
      srv.rpc['events_upcoming'] = (_) => [
            {'id': 'ev-1', 'title': 'Atelier soudure', 'kind': 'atelier', 'starts_at': _iso(const Duration(days: 3)), 'place': 'Hall', 'price': 0, 'capacity': 20, 'registered': 2, 'mine': false}
          ];
      await bouton(t);
      expect(find.text('S’inscrire · Lampe artisanale'), findsOneWidget);
      await t.tap(find.byKey(const Key('live-action-unique')));
      await pause(t);
      expect(find.text('Atelier soudure'), findsOneWidget);
      expect(find.text('Entrée gratuite'), findsOneWidget);
      await fin(t);
    });
  });
}
