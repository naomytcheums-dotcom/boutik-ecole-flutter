import 'package:boutik_ecole/figma/g/g_03.dart';
import 'package:boutik_ecole/figma/g/g_10.dart';
import 'package:boutik_ecole/figma/g/g_244.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/home_live.dart';
import 'package:boutik_ecole/figma/live/reels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

class _Reels extends ReelsNotifier {
  _Reels(this.v);
  final List<Reel>? v;
  @override
  List<Reel>? build() => v;
}

class _Following extends FollowingIdsNotifier {
  _Following(this.v);
  final Set<String>? v;
  @override
  Set<String>? build() => v;
}

class _NoTalents extends TalentsNotifier {
  @override
  List<LiveTalent>? build() => const [];
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => GScreen.mockupFrame = false);
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  testWidgets('filtres : la dernière pastille hors écran est atteignable en faisant défiler, puis sélectionnable', (t) async {
    int? choisi;
    t.view.physicalSize = const Size(390, 300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: GChoiceGroup(
              chips: const [GChip(20, 40, 80, 34, 'Tous', 12, 500), GChip(108, 40, 80, 34, 'Maison', 12, 500), GChip(196, 40, 80, 34, 'Mode', 12, 500), GChip(284, 40, 80, 34, 'Tech', 12, 500), GChip(372, 40, 140, 34, 'Alimentation', 12, 500)],
              selected: 0,
              selFill: Colors.black,
              unselFill: Colors.white,
              selText: Colors.white,
              unselText: Colors.black,
              radius: 16,
              onChanged: (i) => choisi = i,
            ),
          ),
        ]),
      ),
    ));
    expect(t.getRect(find.text('Alimentation')).right, greaterThan(390), reason: 'la dernière pastille dépasse l’écran avant défilement');
    await t.drag(find.byType(SingleChildScrollView), const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Alimentation')).right, lessThanOrEqualTo(390));
    await t.tap(find.text('Alimentation'));
    expect(choisi, 4);
  });

  testWidgets('réseau social 244 connecté sans publication réelle : état vide, jamais de publication de maquette', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [reelsProvider.overrideWith(() => _Reels(const []))], child: MaterialApp(home: G_244())));
    await t.pumpAndSettle();
    expect(find.text('Yannick M.'), findsNothing);
    expect(find.textContaining('Aucune publication'), findsWidgets);
  });

  testWidgets('profil 10 connecté : trois emplacements de vidéos phares, jamais de photo de maquette', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [reelsProvider.overrideWith(() => _Reels(const []))], child: MaterialApp(home: G_10())));
    await t.pumpAndSettle();
    expect(find.text('Vidéo phare'), findsNWidgets(3));
  });

  testWidgets('réseau social 244 connecté : les publications réelles s’affichent avec leurs compteurs', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const p = Reel(id: '1', author: 'Alice Test', caption: 'Mon premier projet', mediaUrl: '', video: false, likes: 3, comments: 2, saves: 1);
    await t.pumpWidget(ProviderScope(overrides: [reelsProvider.overrideWith(() => _Reels(const [p]))], child: MaterialApp(home: G_244())));
    await t.pumpAndSettle();
    expect(find.text('Alice Test'), findsOneWidget);
    expect(find.text('Mon premier projet'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Publier une photo ou une vidéo'), findsOneWidget);
  });

  testWidgets('onglet Abonnements : ne montre que les publications des créateurs suivis', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const a = Reel(id: '1', author: 'Alice Suivie', caption: 'Projet suivi', mediaUrl: '', video: false, authorId: 'alice');
    const b = Reel(id: '2', author: 'Bob NonSuivi', caption: 'Projet non suivi', mediaUrl: '', video: false, authorId: 'bob');
    await t.pumpWidget(ProviderScope(overrides: [
      reelsProvider.overrideWith(() => _Reels(const [a, b])),
      followingIdsProvider.overrideWith(() => _Following(const {'alice'})),
    ], child: const MaterialApp(home: G_244())));
    await t.pumpAndSettle();
    await t.tap(find.text('Abonnements'));
    await t.pumpAndSettle();
    expect(find.text('Alice Suivie'), findsOneWidget);
    expect(find.text('Bob NonSuivi'), findsNothing);
    expect(find.text('Yannick M.'), findsNothing);
  });

  testWidgets('onglet Abonnements sans abonnement : état vide explicite, pas de maquette', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const a = Reel(id: '1', author: 'Alice', caption: 'Projet', mediaUrl: '', video: false, authorId: 'alice');
    await t.pumpWidget(ProviderScope(overrides: [
      reelsProvider.overrideWith(() => _Reels(const [a])),
      followingIdsProvider.overrideWith(() => _Following(const {})),
    ], child: const MaterialApp(home: G_244())));
    await t.pumpAndSettle();
    await t.tap(find.text('Abonnements'));
    await t.pumpAndSettle();
    expect(find.textContaining('Vous ne suivez personne'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('accueil connecté sans profil réel : état vide, jamais de carte d’exemple', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [liveTalentsProvider.overrideWith(_NoTalents.new)], child: const MaterialApp(home: G_03())));
    await t.pumpAndSettle();
    final scroll = t.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView).first, matching: find.byType(Scrollable)).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await t.pumpAndSettle();
    expect(find.text('Exemple'), findsNothing);
    expect(find.textContaining('Aucun talent à présenter'), findsOneWidget);
  });
}
