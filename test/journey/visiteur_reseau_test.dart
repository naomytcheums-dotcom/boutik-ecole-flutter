import 'package:boutik_ecole/figma/g/g_244.dart';
import 'package:boutik_ecole/figma/g/g_244b.dart';
import 'package:boutik_ecole/figma/g/g_250b.dart';
import 'package:boutik_ecole/figma/g/g_P4.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart' show authProvider, demoAccount;
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/circle_feed.dart';
import 'package:boutik_ecole/figma/live/premium_pub.dart';
import 'package:boutik_ecole/figma/live/publish_page.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:boutik_ecole/figma/live/social_posts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Profil visiteur du réseau social : chargement distinct de l'erreur, onglet Boutiques, pagination, lien partagé,
/// dialogue « Un compte est nécessaire » partout, publication réservée aux comptes.

final _now = DateTime(2026, 11, 14, 12);

Reel _post(String id, {String listing = '', String caption = 'Texte'}) => Reel(id: id, author: 'Awa A.', caption: caption, mediaUrl: '', video: false, authorId: 'u1', listing: listing, publishedAt: _now.subtract(const Duration(hours: 1)));

class _Fil extends ReelsNotifier {
  _Fil(this.items);
  final List<Reel>? items;
  int retries = 0, more = 0;
  @override
  List<Reel>? build() => items;
  @override
  Future<bool> retry() async {
    retries++;
    return true;
  }

  @override
  Future<void> loadMore() async => more++;
}

class _Erreur extends ReelsLoadError {
  @override
  bool build() => true;
}

class _Onglet extends CircleTab {
  _Onglet(this.v);
  final int v;
  @override
  int build() => v;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    Backend.ready = true;
    GAnim.enabled = false;
  });
  tearDown(() => Backend.ready = false);

  Future<void> monter(WidgetTester t, Widget w, List<Override> overrides) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 360, child: w))))));
    await t.pumpAndSettle();
  }

  group('fil du Cercle', () {
    testWidgets('lecture en cours : chargement ; lecture échouée : message, bouton Réessayer qui relance, jamais un chargement sans fin', (t) async {
      await monter(t, const CircleFeed(width: 350), [reelsProvider.overrideWith(() => _Fil(null))]);
      expect(find.text('Chargement des publications…'), findsOneWidget);
      late _Fil fil;
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          reelsProvider.overrideWith(() => fil = _Fil(null)),
          reelsLoadErrorProvider.overrideWith(_Erreur.new),
        ],
        child: const MaterialApp(home: Scaffold(body: CircleFeed(width: 350))),
      ));
      await t.pumpAndSettle();
      expect(find.text('Chargement des publications…'), findsNothing);
      expect(find.text('Les publications ne peuvent pas être chargées pour le moment.'), findsOneWidget);
      await t.tap(find.text('Réessayer'));
      await t.pump();
      expect(fil.retries, 1);
    });

    test('un échec des deux lectures du fil est signalé (liste nulle + erreur), puis « Réessayer » relit', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(reelsProvider), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(reelsProvider), isNull);
      expect(c.read(reelsLoadErrorProvider), isTrue);
      expect(await c.read(reelsProvider.notifier).retry(), isFalse);
      expect(c.read(reelsLoadErrorProvider), isTrue);
    });

    testWidgets('onglet Boutiques : seules les publications liées à une boutique, message clair quand il n’y en a aucune', (t) async {
      await monter(t, const CircleFeed(width: 350), [
        reelsProvider.overrideWith(() => _Fil([_post('a'), _post('b')])),
        circleTabProvider.overrideWith(() => _Onglet(3)),
      ]);
      expect(find.text('Aucune publication liée à une boutique pour le moment.'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await monter(t, const CircleFeed(width: 350), [
        reelsProvider.overrideWith(() => _Fil([_post('a', caption: 'Sans boutique'), _post('b', listing: 'Lampe', caption: 'Avec boutique')])),
        circleTabProvider.overrideWith(() => _Onglet(3)),
      ]);
      expect(find.text('Avec boutique'), findsOneWidget);
      expect(find.text('Sans boutique'), findsNothing);
    });

    testWidgets('lien partagé ?post=<id> : la publication visée remonte en tête ; un identifiant inconnu est ignoré', (t) async {
      final fil = [_post('a', caption: 'Première'), _post('b', caption: 'Deuxième'), _post('c', caption: 'Troisième')];
      await monter(t, const CircleFeed(width: 350, focusPostId: 'c'), [reelsProvider.overrideWith(() => _Fil(fil))]);
      expect(t.widgetList<PostCard>(find.byType(PostCard)).first.post.id, 'c');
      await monter(t, const CircleFeed(width: 350, focusPostId: 'inconnu'), [reelsProvider.overrideWith(() => _Fil(fil))]);
      expect(t.widgetList<PostCard>(find.byType(PostCard)).first.post.id, 'a');
    });

    testWidgets('première page pleine : « Voir plus » relit le fil avec la limite supérieure', (t) async {
      late _Fil fil;
      final trente = [for (var i = 0; i < 30; i++) _post('p$i', caption: 'Pub $i')];
      await monter(t, const CircleFeed(width: 350, height: 600), [reelsProvider.overrideWith(() => fil = _Fil(trente))]);
      await t.scrollUntilVisible(find.text('Voir plus'), 600, scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Voir plus'));
      await t.pump();
      expect(fil.more, 1);
    });
  });

  group('un visiteur ne réagit jamais en silence : dialogue « Un compte est nécessaire »', () {
    testWidgets('cœur et enregistrement d’une publication', (t) async {
      final p = _post('p1');
      await monter(t, PostCard(post: p, index: 0), [reelsProvider.overrideWith(() => _Fil([p]))]);
      await t.tap(find.byType(LikeHeart));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      await t.tap(find.text('Plus tard'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.bookmark_border));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(find.textContaining('enregistrer une publication'), findsOneWidget);
    });

    testWidgets('répondre à un commentaire, cœur de commentaire et saisie', (t) async {
      final comms = [PostComment(id: 'c1', parentId: '', author: 'Awa T.', authorId: 'u1', avatar: '', verified: false, mine: false, body: 'Superbe', createdAt: DateTime.now(), likes: 0, liked: false, attachment: '')];
      late BuildContext ctx;
      await monter(t, Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      }), [postCommentsProvider('p1').overrideWith((ref) async => comms)]);
      showCommentsSheet(ctx, 'p1');
      await t.pumpAndSettle();
      await t.tap(find.text('Répondre'));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(find.textContaining('répondre à un commentaire'), findsOneWidget);
      await t.tap(find.text('Plus tard'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.favorite_border));
      await t.pumpAndSettle();
      expect(find.textContaining('réagir à un commentaire'), findsOneWidget);
      await t.tap(find.text('Plus tard'));
      await t.pumpAndSettle();
      await t.tap(find.text('Connectez-vous pour commenter.'));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
    });
  });

  group('publication', () {
    testWidgets('visiteur : écran 250 sans formulaire, dialogue « Un compte est nécessaire » dès l’ouverture', (t) async {
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const ProviderScope(child: MaterialApp(home: PublishPage())));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(find.textContaining('publier'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Publier aussi sur mes réseaux'), findsNothing);
    });

    testWidgets('compte connecté : formulaire, puce Reel avec texte d’aide (sans toast)', (t) async {
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(authProvider.notifier).login(demoAccount);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: PublishPage())));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsNothing);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Une vidéo publiée apparaît aussi dans Reels.'), findsNothing);
      await t.tap(find.text('Reel'));
      await t.pumpAndSettle();
      expect(find.text('Une vidéo publiée apparaît aussi dans Reels.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('250b, P4 et 244b en service réel : plus de maquette, formulaire ou fil réel', (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final w in <Widget>[const G_250b(), const G_P4()]) {
        await t.pumpWidget(ProviderScope(key: UniqueKey(), child: MaterialApp(home: w)));
        await t.pump();
        expect(find.byType(PublishPage), findsOneWidget);
        expect(find.text('Planifier'), findsNothing);
        expect(find.text('Comptes suggérés'), findsNothing);
        await t.pumpAndSettle();
      }
      await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [reelsProvider.overrideWith(() => _Fil(const []))], child: const MaterialApp(home: G_244b())));
      await t.pumpAndSettle();
      expect(find.byType(G_244), findsOneWidget);
      expect(find.text('Yannick'), findsNothing);
    });
  });

  testWidgets('publicité sans annonce mais avec publication : le clic ouvre la publication sur l’écran 244 (?post=)', (t) async {
    String? ouvert;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SponsoredCard(ad: {'id': 'a1', 'title': 'Promo', 'body': 'Texte', 'owner': 'Alice', 'post_id': 'p42', 'listing_id': null}))),
      GoRoute(
        path: '/s/244',
        builder: (_, s) {
          ouvert = s.uri.queryParameters['post'];
          return const Scaffold(body: Text('fil'));
        },
      ),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    await t.tap(find.text('Promo'));
    await t.pumpAndSettle();
    expect(ouvert, 'p42');
  });
}
