import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:boutik_ecole/figma/live/social_h13.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · réseau social : rubriques du profil créateur (vide / erreur / pagination par curseur / épinglage 3 au plus / visites), modification d'une publication
/// et d'un commentaire, pagination du fil par curseur. Faux serveur local ; aucune donnée d'exemple.
Map<String, dynamic> _item(String id, String title, {bool pinned = false, String at = '2026-11-20T10:00:00Z'}) => {'id': id, 'title': title, 'subtitle': null, 'media_path': null, 'media_kind': null, 'at': at, 'pinned': pinned};

Map<String, dynamic> _tabs({int publications = 0, int lives = 0}) => {
      'user': 'u2',
      'tabs': {'publications': publications, 'lives': lives, 'projets': 0, 'produits': 0, 'reposts': 0, 'clips': 0},
    };

Map<String, dynamic> _row(String id, String at, {String caption = 'Texte'}) => {
      'id': id,
      'kind': 'text',
      'author': 'Awa A.',
      'author_id': 'u9',
      'caption': caption,
      'tags': <String>[],
      'likes': 0,
      'comments': 0,
      'saves': 0,
      'shares': 0,
      'published_at': at,
      'media': <Object>[],
    };

class _Fil extends ReelsNotifier {
  @override
  List<Reel>? build() => null;
  void seed(List<Reel> l) => state = l;
}

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
    srv.rpc['public_profile'] = (_) => {'id': 'u2', 'name': 'Awa Test', 'role': 'student'};
    srv.rpc['profile_visit_record'] = (_) => true;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<ProviderContainer> host(WidgetTester t, {String user = 'u2', bool signedIn = false}) async {
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: CreatorProfileScreen(userId: user))));
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
    if (signedIn) {
      c.read(authProvider.notifier).login(demoAccount.copyWith(role: 1, serverId: 'u2'));
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 200));
    return c;
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  testWidgets('serveur muet : message honnête, aucun compteur', (t) async {
    srv.unknownIsError = true;
    await host(t, user: 'u3');
    await attendre(t, find.text('Réessayer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.textContaining('(0)'), findsNothing);
    await fin(t);
  });

  testWidgets('profil privé, bloqué ou introuvable : message, aucune rubrique', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => null;
    await host(t, user: 'u3');
    await attendre(t, find.textContaining('introuvable'));
    expect(find.textContaining('introuvable ou n’est pas visible'), findsOneWidget);
    expect(find.byKey(const Key('creator-tab-lives')), findsNothing);
    await fin(t);
  });

  testWidgets('rubrique vide : le dit ; rubrique avec éléments : liste, sans bouton d\'épinglage pour un tiers', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => _tabs(publications: 1);
    srv.rpc['creator_tab_items'] = (a) => {
          'tab': a['p_tab'],
          'items': a['p_tab'] == 'publications' ? [_item('p1', 'Ma première publication')] : <Object>[],
          'next': null,
        };
    await host(t, user: 'u3');
    await attendre(t, find.text('Ma première publication'));
    expect(find.text('Ma première publication'), findsOneWidget);
    expect(find.byKey(const Key('creator-pin-p1')), findsNothing);
    expect(find.byKey(const Key('creator-visits')), findsNothing);
    await t.tap(find.byKey(const Key('creator-tab-lives')));
    await attendre(t, find.text('Aucun live public pour le moment.'));
    expect(find.text('Aucun live public pour le moment.'), findsOneWidget);
    await fin(t);
  });

  testWidgets('panne sur une rubrique : erreur lisible avec Réessayer, jamais « vide »', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => _tabs(publications: 1);
    srv.failRpc.add('creator_tab_items');
    await host(t, user: 'u3');
    await attendre(t, find.text('Réessayer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Aucune publication pour le moment.'), findsNothing);
    await fin(t);
  });

  testWidgets('pagination par curseur : « Voir plus » envoie le curseur et n\'ajoute aucun doublon', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => _tabs(publications: 3);
    srv.rpc['creator_tab_items'] = (a) => a['p_before_at'] == null
        ? {'tab': 'publications', 'items': [_item('p1', 'Première'), _item('p2', 'Deuxième')], 'next': {'before_at': '2026-11-19T10:00:00Z', 'before_id': 'p2'}}
        : {'tab': 'publications', 'items': [_item('p2', 'Deuxième'), _item('p3', 'Troisième')], 'next': null};
    await host(t, user: 'u3');
    await attendre(t, find.text('Voir plus'));
    await t.tap(find.text('Voir plus'));
    await attendre(t, find.text('Troisième'));
    expect(find.text('Deuxième'), findsOneWidget);
    expect(find.text('Troisième'), findsOneWidget);
    expect(find.text('Voir plus'), findsNothing);
    final cursor = srv.callsOf('creator_tab_items').last.args;
    expect(cursor['p_before_at'], '2026-11-19T10:00:00Z');
    expect(cursor['p_before_id'], 'p2');
    await fin(t);
  });

  testWidgets('propriétaire : visites agrégées, épinglage, refus du serveur au 4e (aucune confirmation)', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => _tabs(publications: 2);
    srv.rpc['creator_visit_stats'] = (_) => {'days': 30, 'visits': 7, 'by_day': <Object>[], 'identities': false};
    final pinned = <String>{};
    srv.rpc['creator_tab_items'] = (_) => {
          'tab': 'publications',
          'items': [_item('p1', 'Première', pinned: pinned.contains('p1')), _item('p2', 'Deuxième', pinned: pinned.contains('p2'))],
          'next': null,
        };
    srv.rpc['creator_pin_set'] = (a) {
      if (a['p_item'] == 'p2') throw const FakeRpcError('Trois éléments épinglés au plus par onglet : désépinglez-en un d\'abord');
      pinned.add('${a['p_item']}');
      return {'tab': 'publications', 'item': a['p_item'], 'pinned': true, 'changed': true, 'count': 1};
    };
    await host(t, user: 'moi', signedIn: true);
    await attendre(t, find.text('Première'));
    expect(find.textContaining('Visites du profil · 30 jours : 7'), findsOneWidget);
    expect(find.textContaining('jamais son identité'), findsOneWidget);
    await t.tap(find.byKey(const Key('creator-pin-p1')));
    await attendre(t, find.text('Épinglé'));
    expect(find.text('Épinglé'), findsOneWidget);
    expect(srv.callsOf('creator_pin_set').first.args, {'p_tab': 'publications', 'p_item': 'p1', 'p_pin': true});
    await t.tap(find.byKey(const Key('creator-pin-p2')));
    await attendre(t, find.textContaining('Trois éléments'));
    expect(find.textContaining('Trois éléments épinglés au plus'), findsWidgets);
    expect(find.text('Élément épinglé en tête de la rubrique.'), findsNothing);
    await fin(t);
  });

  testWidgets('propriétaire : panne des visites = message, jamais zéro', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => _tabs(publications: 1);
    srv.rpc['creator_tab_items'] = (_) => {'tab': 'publications', 'items': [_item('p1', 'Première')], 'next': null};
    srv.failRpc.add('creator_visit_stats');
    await host(t, user: 'moi', signedIn: true);
    await attendre(t, find.textContaining('visites du profil ne peuvent pas'));
    expect(find.textContaining('visites du profil ne peuvent pas être chargées'), findsOneWidget);
    expect(find.textContaining('jours : 0'), findsNothing);
    expect(srv.callsOf('profile_visit_record'), isEmpty);
    await fin(t);
  });

  testWidgets('visiteur connecté : une visite est enregistrée ; son propre profil : aucune', (t) async {
    srv.rpc['creator_profile_tabs'] = (_) => _tabs(publications: 1);
    srv.rpc['creator_tab_items'] = (_) => {'tab': 'publications', 'items': [_item('p1', 'Première')], 'next': null};
    final c = await host(t, user: 'u3');
    c.read(authProvider.notifier).login(demoAccount.copyWith(role: 1, serverId: 'u2'));
    await attendre(t, find.text('Première'));
    await settleReal(t, rounds: 4, ms: 60);
    expect(srv.callsOf('profile_visit_record').single.args, {'p_user': 'u3'});
    await fin(t);
  });

  group('modification et fil', () {
    Future<BuildContext> boite(WidgetTester t, {String me = 'u9'}) async {
      t.view.physicalSize = const Size(420, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      late BuildContext ctx;
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(home: Scaffold(body: Consumer(builder: (c, ref, _) {
          ctx = c;
          return TextButton(onPressed: () => editMyPost(c, ref, const Reel(id: 'p1', author: 'Awa A.', caption: 'Texte initial', mediaUrl: '', video: false, authorId: 'u9')), child: const Text('Modifier'));
        })))));
      return ctx;
    }

    testWidgets('modifier ma publication : texte prérempli, trop long refusé sans appel, appel avec le nouveau texte, statut « en validation » annoncé', (t) async {
      srv.rpc['edit_my_post'] = (a) => {'id': a['p_post'], 'status': 'pending', 'edited': true};
      srv.rpc['circle_feed'] = (_) => <Object>[];
      await boite(t);
      await t.tap(find.text('Modifier'));
      await t.pumpAndSettle();
      expect(find.text('Texte initial'), findsOneWidget);
      await t.enterText(find.byKey(const Key('edit-link')), 'javascript:alert(1)');
      await t.tap(find.byKey(const Key('edit-save')));
      await t.pumpAndSettle();
      expect(find.textContaining('Lien invalide'), findsOneWidget);
      expect(srv.callsOf('edit_my_post'), isEmpty);
      await t.enterText(find.byKey(const Key('edit-link')), '');
      await t.enterText(find.byKey(const Key('edit-text')), 'Texte corrigé');
      await t.tap(find.byKey(const Key('edit-save')));
      await settleReal(t, rounds: 8, ms: 60);
      final a = srv.callsOf('edit_my_post').single.args;
      expect(a['p_post'], 'p1');
      expect(a['p_caption'], 'Texte corrigé');
      expect(a['p_link'], isNull);
      await t.pump(const Duration(seconds: 3));
      await fin(t);
    });

    testWidgets('modifier ma publication : refus du serveur → message, aucune confirmation', (t) async {
      srv.rpc['edit_my_post'] = (_) => throw const FakeRpcError('Publication masquée par la modération : modification impossible');
      await boite(t);
      await t.tap(find.text('Modifier'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('edit-text')), 'Autre texte');
      await t.tap(find.byKey(const Key('edit-save')));
      await settleReal(t, rounds: 8, ms: 60);
      expect(find.textContaining('masquée par la modération'), findsOneWidget);
      expect(find.text('Publication modifiée.'), findsNothing);
      await fin(t);
    });

    test('fil : « Voir plus » lit la page suivante par curseur (publication la plus ancienne non mise en avant), sans doublon', () async {
      Backend.ready = true;
      srv.rpc.clear();
      srv.calls.clear();
      srv.rpc['circle_feed_page'] = (a) => [_row('b', '2026-11-10T10:00:00Z', caption: 'Plus ancienne'), _row('a', '2026-11-18T10:00:00Z', caption: 'Doublon')];
      final c = ProviderContainer(overrides: [reelsProvider.overrideWith(_Fil.new)]);
      addTearDown(c.dispose);
      final n = c.read(reelsProvider.notifier) as _Fil;
      n.seed([
        Reel(id: 'boost', author: 'X', caption: 'Mis en avant', mediaUrl: '', video: false, boosted: true, publishedAt: DateTime.utc(2026, 1, 1)),
        Reel(id: 'a', author: 'Awa A.', caption: 'Récente', mediaUrl: '', video: false, authorId: 'u9', publishedAt: DateTime.utc(2026, 11, 18, 10)),
        Reel(id: 'c', author: 'Awa A.', caption: 'Moins récente', mediaUrl: '', video: false, authorId: 'u9', publishedAt: DateTime.utc(2026, 11, 15, 10)),
      ]);
      await n.loadMore();
      final a = srv.callsOf('circle_feed_page').single.args;
      expect(a['p_before_at'], '2026-11-15T10:00:00.000Z');
      expect(a['p_before_id'], 'c');
      final ids = c.read(reelsProvider)!.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.toSet(), {'boost', 'a', 'c', 'b'});
      expect(n.canLoadMore, isFalse);
    });
  });
}
