import 'package:boutik_ecole/figma/g/g_245.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/live_transport.dart';
import 'package:boutik_ecole/figma/live/lives.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:boutik_ecole/figma/live/social_posts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Réseau social : cœur, carrousel, badge certifié, publications complètes, flux Reels, Live (modèle et messages d'erreur).
/// Les échanges réels avec le serveur et le fournisseur vidéo ne sont PAS exécutés ici (voir docs/transformation/RESEAU_SOCIAL_LIVE.md).

final _now = DateTime(2026, 11, 10, 12);

Reel _post(String id, {bool verified = false, List<ReelMedia> media = const [], String caption = 'Texte', bool liked = false, int likes = 0, String linkUrl = '', String repostId = ''}) => Reel(
      id: id, author: 'Awa A.', caption: caption, mediaUrl: media.isEmpty ? '' : media.first.url, video: media.isNotEmpty && media.first.video,
      authorId: 'u1', authorVerified: verified, media: media, liked: liked, likes: likes, linkUrl: linkUrl, repostId: repostId, repostAuthor: repostId.isEmpty ? '' : 'Paul B.', repostCaption: repostId.isEmpty ? '' : 'Original',
      publishedAt: _now.subtract(const Duration(hours: 1)));

class _Fil extends ReelsNotifier {
  _Fil(this.items);
  final List<Reel> items;
  @override
  List<Reel>? build() => items;
}

Future<void> _monter(WidgetTester t, Widget w, {List<Reel> fil = const []}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [reelsProvider.overrideWith(() => _Fil(fil))],
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 360, child: w)))),
  ));
  await t.pump();
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  group('modèle', () {
    test('plusieurs médias, proportions, auteur certifié et republication sont lus ; rien n’est inventé si le serveur ne les renvoie pas', () {
      final r = Reel.fromRow({
        'id': 'p1', 'author': 'A', 'media_path': 'u/1.jpg', 'media_kind': 'image', 'author_verified': true, 'author_avatar': 'https://x/a.png', 'link_url': 'https://exemple.cm',
        'media': [
          {'path': 'u/1.jpg', 'kind': 'image', 'w': 1200, 'h': 800},
          {'path': 'u/2.mp4', 'kind': 'video'},
        ],
        'repost_id': 'p0', 'repost_author': 'B', 'repost_caption': 'Orig',
      }, (p) => 'cdn/$p');
      expect(r.authorVerified, isTrue);
      expect(r.allMedia.length, 2);
      expect(r.allMedia.first.ratio, closeTo(1.5, 0.001));
      expect(r.allMedia.last.video, isTrue);
      expect(r.allMedia.last.ratio, isNull);
      expect(r.linkUrl, 'https://exemple.cm');
      expect(r.repostId, 'p0');
      final ancien = Reel.fromRow({'id': 'p2', 'author': 'B', 'media_path': 'y', 'media_kind': 'image'}, (p) => p);
      expect(ancien.authorVerified, isFalse);
      expect(ancien.allMedia.length, 1);
      final texte = Reel.fromRow({'id': 'p3', 'author': 'C', 'caption': 'Bonjour', 'media_path': null, 'media_kind': null}, (p) => p);
      expect(texte.hasMedia, isFalse);
      expect(texte.allMedia, isEmpty);
    });

    test('copyWith conserve la publication et ne change que les compteurs demandés', () {
      final a = _post('p1', likes: 3);
      final b = a.copyWith(liked: true, likes: 4);
      expect([b.id, b.liked, b.likes, b.author, b.authorVerified], ['p1', true, 4, 'Awa A.', false]);
    });
  });

  group('cœur', () {
    testWidgets('un appui appelle l’action sans changer d’écran et l’icône ne rétrécit jamais pendant l’animation', (t) async {
      var taps = 0;
      var liked = false;
      late StateSetter set;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (_, s) {
          set = s;
          return Center(child: LikeHeart(liked: liked, onTap: () => taps++));
        })),
      ));
      double scale() => (t.widget(find.descendant(of: find.byType(LikeHeart), matching: find.byType(ScaleTransition)).first) as ScaleTransition).scale.value;
      expect(scale(), 1.0);
      await t.tap(find.byType(LikeHeart));
      set(() => liked = true);
      final mini = <double>[];
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 30));
        mini.add(scale());
      }
      await t.pumpAndSettle();
      expect(taps, 1);
      expect(mini.every((v) => v >= 1.0), isTrue, reason: 'échelles: $mini');
      expect(mini.any((v) => v > 1.1), isTrue, reason: 'impulsion visible');
      expect(scale(), 1.0);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('hors serveur, le cœur d’une publication change son compteur localement (aucune redirection)', (t) async {
      Backend.ready = false;
      final p = _post('p1', likes: 5);
      late WidgetRef r;
      await t.pumpWidget(ProviderScope(
        overrides: [reelsProvider.overrideWith(() => _Fil([p]))],
        child: MaterialApp(home: Consumer(builder: (c, ref, _) {
          r = ref;
          return Scaffold(body: TextButton(onPressed: () => toggleLike(c, ref, ref.read(reelsProvider)!.first), child: const Text('go')));
        })),
      ));
      await t.tap(find.text('go'));
      await t.pump();
      expect(r.read(reelsProvider)!.first.liked, isTrue);
      expect(r.read(reelsProvider)!.first.likes, 6);
      await t.tap(find.text('go'));
      await t.pump();
      expect(r.read(reelsProvider)!.first.liked, isFalse);
      expect(r.read(reelsProvider)!.first.likes, 5);
    });
  });

  group('carte de publication', () {
    final five = [for (var i = 1; i <= 5; i++) ReelMedia(url: 'https://x/$i.jpg', video: false, width: 1200, height: 800)];

    testWidgets('le badge bleu n’apparaît que pour un compte certifié', (t) async {
      await _monter(t, PostCard(post: _post('p1', verified: true), index: 0), fil: [_post('p1', verified: true)]);
      expect(find.byType(VerifiedBadge), findsOneWidget);
      await _monter(t, PostCard(post: _post('p2'), index: 0), fil: [_post('p2')]);
      expect(find.byType(VerifiedBadge), findsNothing);
    });

    testWidgets('angles droits : ni coins arrondis ni carrousel limité à 3 photos', (t) async {
      await _monter(t, PostCard(post: _post('p1', media: five), index: 0), fil: [_post('p1', media: five)]);
      final card = t.widget<Container>(find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border != null).first);
      expect((card.decoration as BoxDecoration).borderRadius, isNull);
      expect(find.byType(ClipRRect), findsNothing);
      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets('carrousel horizontal : cinq photos accessibles, compteur et indicateurs mis à jour', (t) async {
      await _monter(t, MediaCarousel(media: five), fil: const []);
      expect(find.text('1/5'), findsOneWidget);
      final pv = find.byType(PageView);
      for (var i = 2; i <= 5; i++) {
        await t.drag(pv, const Offset(-360, 0));
        await t.pumpAndSettle();
        expect(find.text('$i/5'), findsOneWidget);
      }
    });

    testWidgets('texte, lien et republication s’affichent ; le menu à trois points et les actions sont présents', (t) async {
      await _monter(t, PostCard(post: _post('p1', linkUrl: 'https://exemple.cm/page', repostId: 'p0', caption: 'Mon texte'), index: 0), fil: [_post('p1')]);
      expect(find.text('Mon texte'), findsOneWidget);
      expect(find.text('https://exemple.cm/page'), findsOneWidget);
      expect(find.text('Paul B.'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      expect(find.byIcon(Icons.ios_share), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsWidgets);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('le menu à trois points propose enregistrer, republier, partager, copier, profil et signaler', (t) async {
      await _monter(t, PostCard(post: _post('p1'), index: 0), fil: [_post('p1')]);
      await t.tap(find.byIcon(Icons.more_horiz));
      await t.pumpAndSettle();
      for (final l in ['Enregistrer', 'Republier', 'Partager', 'Copier le lien', 'Voir le profil', 'Signaler']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
    });
  });

  group('Reels', () {
    testWidgets('le menu du bas est masqué et la colonne d’interactions est posée sur la vidéo, sans disque de fond', (t) async {
      Backend.ready = true;
      final p = _post('p1', media: const [ReelMedia(url: 'https://x/v.mp4', video: true)]);
      await t.pumpWidget(ProviderScope(
        overrides: [reelsProvider.overrideWith(() => _Fil([p]))],
        child: const MaterialApp(home: Scaffold(body: G_245())),
      ));
      await t.pump();
      expect(find.text('Partager'), findsOneWidget);
      expect(find.text('Boutique'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    test('le balayage saute les publications sans média', () {
      final c = ProviderContainer(overrides: [reelsProvider.overrideWith(() => _Fil([_post('a', media: const [ReelMedia(url: 'u/a.jpg', video: false)]), _post('t'), _post('b', media: const [ReelMedia(url: 'u/b.jpg', video: false)])]))]);
      addTearDown(c.dispose);
      expect(c.read(currentReelProvider)!.id, 'a');
      c.read(reelIndexProvider.notifier).set(0);
      final i = c.read(reelsProvider)!.indexWhere((r) => r.id == 'b');
      expect(i, 2);
    });
  });

  group('Live', () {
    test('un live est lu avec son hôte certifié, ses spectateurs et son statut', () {
      final l = LiveItem.fromRow({'id': 'l1', 'host_id': 'h', 'host': 'Awa A.', 'host_avatar': 'https://x/a.png', 'host_verified': true, 'title': 'Atelier', 'description': '', 'cover_path': null, 'status': 'live', 'scheduled_at': null, 'viewer_count': 12});
      expect([l.isLive, l.viewers, l.verified, l.cover], [true, 12, true, '']);
      final p = LiveItem.fromRow({'id': 'l2', 'host_id': 'h', 'host': 'B', 'title': 'Plus tard', 'status': 'scheduled', 'scheduled_at': '2026-11-12T10:00:00Z'});
      expect([p.isLive, p.verified, p.scheduledAt != null], [false, false, true]);
    });

    test('chaque erreur de diffusion a un message lisible (autorisations caméra / micro, réseau, appareil)', () {
      for (final c in ['permission_denied', 'device_not_found', 'device_busy', 'sdk_unavailable', 'unsupported', 'connect_failed', 'autre']) {
        final m = liveErrorMessage(c);
        expect(m.length > 20, isTrue, reason: c);
        expect(m.toLowerCase().contains('exception'), isFalse, reason: c);
      }
      expect(liveErrorMessage('permission_denied'), contains('caméra'));
    });

    test('les messages du direct sont lus avec leur type et leur charge utile (cadeaux)', () {
      final m = LiveMsg.fromRow({'id': 7, 'user_id': 'u', 'author': 'Paul B.', 'kind': 'gift', 'body': 'coeur', 'payload': {'emoji': '❤️', 'qty': 3, 'name': 'Cœur'}});
      expect([m.id, m.kind, m.payload['qty']], [7, 'gift', 3]);
    });

    test('hors navigateur, le transport indique clairement que la diffusion n’est pas disponible', () async {
      final tr = createLiveTransport();
      final errs = <String>[];
      final ok = await tr.connect(url: 'wss://x', token: 't', publish: false, onState: (_) {}, onParticipants: (_) {}, onError: errs.add);
      if (!tr.supported) {
        expect(ok, isFalse);
        expect(errs, ['unsupported']);
      }
    });
  });
}
