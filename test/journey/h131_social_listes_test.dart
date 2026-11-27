import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/social_h13.dart';
import 'package:boutik_ecole/figma/live/social_listes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13.1 · listes « Abonnés » / « Abonnements » et « Créateurs à suivre » : états vide / erreur / refus, pagination par curseur sans doublon,
/// tirer pour actualiser, bouton Suivre / Ne plus suivre idempotent, navigation vers le profil et retour. Faux serveur local ; aucune donnée d'exemple.
Map<String, dynamic> _p(String id, String name, {bool follow = false, bool me = false, String role = 'student', bool certified = false}) =>
    {'id': id, 'name': name, 'avatar_url': null, 'role': role, 'certified': certified, 'i_follow': follow, 'is_me': me};

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {Map<String, dynamic>? next, bool own = false, bool? lists}) =>
    {'allowed': true, 'reason': null, 'items': items, 'next': next, 'own': own, 'lists_public': lists};

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
    srv.unknownIsError = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  late GoRouter router;

  Future<ProviderContainer> host(WidgetTester t, String go, {bool signedIn = false}) async {
    t.view.physicalSize = const Size(420, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Center(child: Text('ACCUEIL TEST')))),
      GoRoute(path: '/abonnes/:id', builder: (_, s) => FollowListScreen(userId: s.pathParameters['id'] ?? '', kind: FollowListKind.followers)),
      GoRoute(path: '/abonnements/:id', builder: (_, s) => FollowListScreen(userId: s.pathParameters['id'] ?? '', kind: FollowListKind.following)),
      GoRoute(path: '/createurs-a-suivre', builder: (_, _) => const SuggestedCreatorsScreen()),
      GoRoute(path: '/profil-createur/:id', builder: (_, s) => CreatorProfileScreen(userId: s.pathParameters['id'] ?? '')),
    ]);
    await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    if (signedIn) {
      c.read(authProvider.notifier).login(demoAccount.copyWith(role: 1, serverId: 'u1'));
      await t.pump();
    }
    router.push(go);
    await t.pump(const Duration(milliseconds: 200));
    return c;
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> tirer(WidgetTester t) async {
    await t.fling(find.byType(ListView).first, const Offset(0, 600), 1000);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  testWidgets('serveur muet : message honnête avec Réessayer, jamais « aucun abonné »', (t) async {
    srv.unknownIsError = true;
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Réessayer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Aucun abonné pour le moment.'), findsNothing);
    await fin(t);
  });

  testWidgets('liste vide : le dit, pour les abonnés comme pour les abonnements', (t) async {
    srv.rpc['followers_list'] = (_) => _page([]);
    srv.rpc['following_list'] = (_) => _page([]);
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Aucun abonné pour le moment.'));
    expect(find.text('Aucun abonné pour le moment.'), findsOneWidget);
    router.pushReplacement('/abonnements/u2');
    await attendre(t, find.text('Cette personne ne suit encore personne.'));
    expect(find.text('Cette personne ne suit encore personne.'), findsOneWidget);
    await fin(t);
  });

  testWidgets('autorisations : profil privé et listes masquées refusés avec un message clair, aucune ligne', (t) async {
    srv.rpc['followers_list'] = (a) => a['p_user'] == 'priv'
        ? {'allowed': false, 'reason': 'unavailable', 'items': <Object>[], 'next': null, 'own': false}
        : {'allowed': false, 'reason': 'lists_hidden', 'items': <Object>[], 'next': null, 'own': false};
    await host(t, '/abonnes/priv');
    await attendre(t, find.byKey(const Key('follow-denied')));
    expect(find.textContaining('privé ou indisponible'), findsOneWidget);
    expect(find.text('Aucun abonné pour le moment.'), findsNothing);
    router.pushReplacement('/abonnes/cache');
    await attendre(t, find.textContaining('choisi de ne pas afficher'));
    expect(find.textContaining('choisi de ne pas afficher'), findsOneWidget);
    expect(find.byKey(const Key('follow-lists-switch')), findsNothing);
    await fin(t);
  });

  testWidgets('pagination par curseur : « Voir plus » envoie le curseur reçu et n\'ajoute aucun doublon', (t) async {
    srv.rpc['followers_list'] = (a) => a['p_cursor'] == null
        ? _page([_p('a', 'Awa A.'), _p('b', 'Boris B.')], next: {'at': '2026-11-19T10:00:00+00:00', 'id': 'b'})
        : _page([_p('b', 'Boris B.'), _p('c', 'Carine C.')]);
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Voir plus'));
    expect(find.text('Awa A.'), findsOneWidget);
    await t.tap(find.text('Voir plus'));
    await attendre(t, find.text('Carine C.'));
    expect(find.text('Boris B.'), findsOneWidget);
    expect(find.text('Carine C.'), findsOneWidget);
    expect(find.text('Voir plus'), findsNothing);
    expect(srv.callsOf('followers_list').last.args['p_cursor'], {'at': '2026-11-19T10:00:00+00:00', 'id': 'b'});
    await fin(t);
  });

  testWidgets('pagination : une erreur sur la page suivante garde la liste et propose de réessayer', (t) async {
    srv.rpc['followers_list'] = (a) {
      if (a['p_cursor'] != null) throw const FakeRpcError('Curseur invalide');
      return _page([_p('a', 'Awa A.')], next: {'at': '2026-11-19T10:00:00+00:00', 'id': 'a'});
    };
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Voir plus'));
    await t.tap(find.text('Voir plus'));
    await attendre(t, find.textContaining('Curseur invalide'));
    expect(find.text('Awa A.'), findsOneWidget);
    expect(find.text('Voir plus'), findsOneWidget);
    await fin(t);
  });

  testWidgets('tirer pour actualiser : recharge la première page', (t) async {
    var n = 0;
    srv.rpc['followers_list'] = (_) => ++n == 1 ? _page([_p('a', 'Awa A.')]) : _page([_p('z', 'Zoé Z.'), _p('a', 'Awa A.')]);
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Awa A.'));
    expect(find.text('Zoé Z.'), findsNothing);
    await tirer(t);
    await attendre(t, find.text('Zoé Z.'));
    expect(find.text('Zoé Z.'), findsOneWidget);
    expect(find.text('Awa A.'), findsOneWidget);
    expect(srv.callsOf('followers_list').length, 2);
    await fin(t);
  });

  testWidgets('Suivre / Ne plus suivre : l\'état affiché est celui du serveur, le rejeu ne change rien, un refus ne confirme rien', (t) async {
    var following = false;
    srv.rpc['followers_list'] = (_) => _page([_p('a', 'Awa A.', follow: following), _p('u1', 'Moi M.', me: true)]);
    srv.rpc['follow_set'] = (a) {
      if (a['p_user'] == 'a' && a['p_follow'] == true && following) return {'user': 'a', 'following': true, 'changed': false};
      following = a['p_follow'] == true;
      return {'user': a['p_user'], 'following': following, 'changed': true};
    };
    await host(t, '/abonnes/u2', signedIn: true);
    await attendre(t, find.text('Awa A.'));
    expect(find.byKey(const Key('follow-btn-u1')), findsNothing, reason: 'pas de bouton sur sa propre ligne');
    await t.tap(find.descendant(of: find.byKey(const Key('follow-btn-a')), matching: find.text('Suivre')));
    await attendre(t, find.text('Ne plus suivre'));
    expect(srv.callsOf('follow_set').last.args, {'p_user': 'a', 'p_follow': true});
    await t.tap(find.text('Ne plus suivre'));
    await attendre(t, find.descendant(of: find.byKey(const Key('follow-btn-a')), matching: find.text('Suivre')));
    expect(srv.callsOf('follow_set').last.args, {'p_user': 'a', 'p_follow': false});
    srv.rpc['follow_set'] = (_) => throw const FakeRpcError('Abonnement impossible avec ce compte');
    await t.tap(find.descendant(of: find.byKey(const Key('follow-btn-a')), matching: find.text('Suivre')));
    await attendre(t, find.textContaining('Abonnement impossible'));
    expect(find.textContaining('Abonnement impossible'), findsWidgets);
    expect(find.text('Ne plus suivre'), findsNothing);
    await fin(t);
  });

  testWidgets('non connecté : Suivre ne contacte pas le serveur', (t) async {
    srv.rpc['followers_list'] = (_) => _page([_p('a', 'Awa A.')]);
    srv.rpc['follow_set'] = (_) => {'following': true};
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Awa A.'));
    await t.tap(find.descendant(of: find.byKey(const Key('follow-btn-a')), matching: find.text('Suivre')));
    await t.pump(const Duration(milliseconds: 300));
    expect(srv.callsOf('follow_set'), isEmpty);
    await fin(t);
  });

  testWidgets('navigation : liste -> profil du créateur -> compteur -> retour sans impasse', (t) async {
    srv.rpc['followers_list'] = (_) => _page([_p('a', 'Awa A.')]);
    srv.rpc['public_profile'] = (a) => {'id': a['p_user'], 'name': 'Awa Test', 'role': 'student', 'followers_count': 4, 'following_count': 2};
    srv.rpc['creator_profile_tabs'] = (_) => {'user': 'a', 'tabs': {'publications': 0, 'lives': 0, 'projets': 0, 'produits': 0, 'reposts': 0, 'clips': 0}};
    srv.rpc['creator_tab_items'] = (_) => {'tab': 'publications', 'items': <Object>[], 'next': null};
    srv.rpc['following_list'] = (_) => _page([_p('b', 'Boris B.')]);
    await host(t, '/abonnes/u2');
    await attendre(t, find.text('Awa A.'));
    await t.tap(find.byKey(const Key('follow-open-a')));
    await attendre(t, find.byKey(const Key('creator-followers')));
    expect(find.text('4 abonnés'), findsOneWidget);
    await t.tap(find.byKey(const Key('creator-following')));
    await attendre(t, find.text('Boris B.'));
    expect(srv.callsOf('following_list').last.args['p_user'], 'a');
    router.pop();
    await attendre(t, find.byKey(const Key('creator-followers')));
    router.pop();
    await attendre(t, find.text('Awa A.'));
    expect(find.text('Awa A.'), findsOneWidget);
    router.pop();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ACCUEIL TEST'), findsOneWidget);
    await fin(t);
  });

  testWidgets('mes listes : réglage de visibilité enregistré par le serveur, un échec le laisse inchangé', (t) async {
    srv.rpc['followers_list'] = (_) => _page([_p('a', 'Awa A.')], own: true, lists: true);
    srv.rpc['follow_lists_privacy_set'] = (a) => {'public': a['p_public']};
    await host(t, '/abonnes/moi', signedIn: true);
    await attendre(t, find.byKey(const Key('follow-lists-switch')));
    expect(find.text('Mes abonnés'), findsOneWidget);
    await t.tap(find.byKey(const Key('follow-lists-switch')));
    await attendre(t, find.textContaining('Seul vous voyez'));
    expect(srv.callsOf('follow_lists_privacy_set').last.args, {'p_public': false});
    srv.rpc['follow_lists_privacy_set'] = (_) => throw const FakeRpcError('Réglage inconnu');
    await t.tap(find.byKey(const Key('follow-lists-switch')));
    await attendre(t, find.textContaining('Réglage inconnu'));
    expect(find.textContaining('Seul vous voyez'), findsOneWidget);
    await fin(t);
  });

  testWidgets('mes abonnements vides : renvoie vers les créateurs à suivre', (t) async {
    srv.rpc['following_list'] = (_) => _page([], own: true, lists: true);
    srv.rpc['creators_suggested'] = (_) => <Object>[];
    await host(t, '/abonnements/moi', signedIn: true);
    await attendre(t, find.text('Vous ne suivez encore personne.'));
    await t.tap(find.text('Découvrir des créateurs à suivre'));
    await attendre(t, find.text('Aucune suggestion pour le moment.'));
    expect(find.byKey(const Key('suggest-empty')), findsOneWidget);
    await fin(t);
  });

  testWidgets('mon profil non connecté : invitation à se connecter, aucun appel', (t) async {
    await host(t, '/abonnes/moi');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Connectez-vous pour voir vos abonnés'), findsOneWidget);
    expect(srv.callsOf('followers_list'), isEmpty);
    await fin(t);
  });

  testWidgets('créateurs à suivre : suggestions réelles avec leur raison, suivi, profil', (t) async {
    srv.rpc['creators_suggested'] = (_) => [
          {'id': 'c1', 'name': 'Camille D.', 'avatar_url': null, 'certified': true, 'posts_count': 3, 'followers_count': 5, 'mutual_count': 0, 'reason': 'meme_departement'},
          {'id': 'c2', 'name': 'Cédric E.', 'avatar_url': null, 'certified': false, 'posts_count': 1, 'followers_count': 0, 'mutual_count': 2, 'reason': 'abonnements_communs'},
        ];
    srv.rpc['follow_set'] = (a) => {'user': a['p_user'], 'following': a['p_follow'], 'changed': true};
    await host(t, '/createurs-a-suivre', signedIn: true);
    await attendre(t, find.text('Camille D.'));
    expect(find.textContaining('Même département que vous'), findsOneWidget);
    expect(find.textContaining('Suivi par 2 personnes que vous suivez'), findsOneWidget);
    await t.tap(find.descendant(of: find.byKey(const Key('follow-btn-c1')), matching: find.text('Suivre')));
    await attendre(t, find.text('Ne plus suivre'));
    expect(srv.callsOf('follow_set').last.args, {'p_user': 'c1', 'p_follow': true});
    expect(srv.callsOf('creators_suggested').last.args['p_limit'], 30);
    await fin(t);
  });

  testWidgets('créateurs à suivre : vide honnête, puis panne avec Réessayer', (t) async {
    srv.rpc['creators_suggested'] = (_) => <Object>[];
    await host(t, '/createurs-a-suivre');
    await attendre(t, find.text('Aucune suggestion pour le moment.'));
    expect(find.text('Aucune suggestion pour le moment.'), findsOneWidget);
    srv.rpc.remove('creators_suggested');
    srv.failRpc.add('creators_suggested');
    await tirer(t);
    await attendre(t, find.text('Réessayer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Aucune suggestion pour le moment.'), findsNothing);
    await fin(t);
  });
}
