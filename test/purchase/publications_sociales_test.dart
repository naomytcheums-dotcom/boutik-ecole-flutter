import 'package:boutik_ecole/figma/g/g_245.dart';
import 'package:boutik_ecole/figma/g/g_252.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Publications : compteurs, commentaires, enregistrements, ordre du fil (écrans 245 et 252).
/// Ces tests prouvent le comportement de l'application avec un serveur simulé ; la migration
/// 20261103000000_commentaires_publications.sql n'a PAS été exécutée contre une base.

final _now = DateTime(2026, 11, 3, 12);

Reel _reel(String id, {String author = 'Brice N.', int likes = 0, int comments = 0, int saves = 0, int hours = 1, bool boosted = false, String authorId = 'a1', String caption = 'Pose d’un kit solaire sur le toit de l’atelier', List<String> tags = const ['energie']}) => Reel(
      id: id, author: author, caption: caption, mediaUrl: '', video: true, likes: likes, comments: comments, saves: saves,
      boosted: boosted, authorId: authorId, tags: tags, publishedAt: _now.subtract(Duration(hours: hours)));

class _Fil extends ReelsNotifier {
  _Fil(this.items);
  final List<Reel> items;
  @override
  List<Reel>? build() => items;
}

class _Commentaires extends ReelCommentsNotifier {
  _Commentaires(this.items);
  final List<ReelComment>? items;
  @override
  List<ReelComment>? build() => items;
  @override
  Future<void> load() async {}
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  group('modèle et ordre du fil', () {
    test('les compteurs du serveur sont lus ; un serveur non migré donne 0, jamais un chiffre inventé', () {
      final neuf = Reel.fromRow({'id': 'p1', 'author': 'A', 'media_path': 'x', 'media_kind': 'video', 'likes': 3, 'comments': 12, 'saves': 4, 'shares': 2, 'saved': true, 'author_id': 'u1', 'published_at': '2026-11-03T10:00:00Z'}, (p) => p);
      expect([neuf.likes, neuf.comments, neuf.saves, neuf.shares, neuf.saved, neuf.authorId], [3, 12, 4, 2, true, 'u1']);
      final ancien = Reel.fromRow({'id': 'p2', 'author': 'B', 'media_path': 'y', 'media_kind': 'image', 'likes': 1}, (p) => p);
      expect([ancien.comments, ancien.saves, ancien.shares, ancien.saved], [0, 0, 0, false]);
    });

    test('le fil ne se réduit pas à la popularité : un reel récent et bien renseigné passe devant un reel ancien très aimé', () {
      final viral = _reel('viral', likes: 90000, comments: 4000, hours: 300, authorId: 'v', caption: '', tags: const []);
      final recent = _reel('recent', likes: 2, hours: 2, authorId: 'r');
      expect(rankReels([viral, recent], _now).first.id, 'recent');
    });

    test('la visibilité gagnée (boost) passe en premier, puis le classement', () {
      final a = _reel('a', hours: 1, authorId: 'a');
      final b = _reel('b', hours: 40, boosted: true, authorId: 'b');
      expect(rankReels([a, b], _now).map((r) => r.id), ['b', 'a']);
    });

    test('au plus 2 reels du même auteur parmi les premiers, les autres auteurs apparaissent', () {
      final memes = [for (var i = 0; i < 5; i++) _reel('m$i', hours: i + 1, authorId: 'meme')];
      final r = rankReels([...memes, _reel('autre', hours: 30, authorId: 'autre')], _now);
      expect(r.where((x) => x.authorId == 'meme').length, 2);
      expect(r.map((x) => x.id), contains('autre'));
    });

    test('temps écoulé', () {
      expect(relativeTime(_now.subtract(const Duration(seconds: 20)), _now), 'à l’instant');
      expect(relativeTime(_now.subtract(const Duration(minutes: 5)), _now), '5 min');
      expect(relativeTime(_now.subtract(const Duration(hours: 3)), _now), '3 h');
      expect(relativeTime(_now.subtract(const Duration(days: 2)), _now), '2 j');
    });
  });

  Future<void> monter(WidgetTester t, Widget w, List<Override> overrides) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: w))));
    await t.pumpAndSettle();
  }

  testWidgets('252 connecté : les commentaires affichés sont ceux du serveur, aucun commentaire de maquette', (t) async {
    final comms = [
      ReelComment(id: 'c1', author: 'Awa T.', body: 'Superbe réalisation, bravo !', mine: false, createdAt: DateTime.now().subtract(const Duration(minutes: 5))),
      ReelComment(id: 'c2', author: 'Moi M.', body: 'Merci à tous', mine: true, createdAt: DateTime.now()),
    ];
    await monter(t, const G_252(), [reelsProvider.overrideWith(() => _Fil([_reel('p1')])), reelCommentsProvider.overrideWith(() => _Commentaires(comms))]);
    expect(find.text('Superbe réalisation, bravo !'), findsOneWidget);
    expect(find.text('Awa T.'), findsOneWidget);
    expect(find.text('Merci à tous'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget, reason: 'seul son propre commentaire peut être supprimé');
    for (final faux in ['Mbella SARL', 'Carine Mbarga', 'Kouassi Tagne', '4,8', '12 avis vérifiés', 'Donner mon avis']) {
      expect(find.text(faux), findsNothing, reason: faux);
    }
    expect(find.text('par Brice N.'), findsOneWidget);
  });

  testWidgets('252 connecté : état vide lisible quand il n\'y a aucun commentaire', (t) async {
    await monter(t, const G_252(), [reelsProvider.overrideWith(() => _Fil([_reel('p1')])), reelCommentsProvider.overrideWith(() => _Commentaires(const []))]);
    expect(find.textContaining('Aucun commentaire pour le moment'), findsOneWidget);
    expect(find.text('Mbella SARL'), findsNothing);
  });

  testWidgets('252 connecté : un échec de chargement montre un message lisible, jamais un texte technique', (t) async {
    await monter(t, const G_252(), [
      reelsProvider.overrideWith(() => _Fil([_reel('p1')])),
      reelCommentsProvider.overrideWith(() => _Commentaires(const [])),
      commentsErrorProvider.overrideWith(_Erreur.new),
    ]);
    expect(find.text('Les commentaires ne peuvent pas être chargés pour le moment.'), findsOneWidget);
    expect(find.textContaining('permission'), findsNothing);
  });

  testWidgets('245 connecté : compteurs de commentaires et d\'enregistrements du serveur, pas 312 ni 4,9', (t) async {
    await monter(t, const G_245(), [reelsProvider.overrideWith(() => _Fil([_reel('p1', comments: 7, saves: 3, likes: 12)]))]);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('312'), findsNothing);
    expect(find.text('4,9'), findsNothing);
  });

  testWidgets('245 : le balayage vertical passe au reel suivant, puis revient', (t) async {
    await monter(t, const G_245(), [reelsProvider.overrideWith(() => _Fil([_reel('p1', author: 'Premier A.'), _reel('p2', author: 'Second B.', authorId: 'b2', hours: 3)]))]);
    expect(find.text('Premier A.'), findsOneWidget);
    final zone = find.byWidgetPredicate((w) => w is GestureDetector && w.onVerticalDragEnd != null);
    expect(zone, findsOneWidget);
    await t.fling(zone, const Offset(0, -300), 1500);
    await t.pumpAndSettle();
    expect(find.text('Second B.'), findsOneWidget);
    await t.fling(zone, const Offset(0, 300), 1500);
    await t.pumpAndSettle();
    expect(find.text('Premier A.'), findsOneWidget);
  });
}

class _Erreur extends ReelsMessage {
  @override
  String build() => 'Les commentaires ne peuvent pas être chargés pour le moment.';
}
