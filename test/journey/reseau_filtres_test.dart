import 'package:boutik_ecole/figma/g/g_03.dart';
import 'package:boutik_ecole/figma/g/g_244.dart';
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/circle_feed.dart';
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

  testWidgets('réseau social 244 connecté : aucune publication de maquette, état vide avec « Publier »', (t) async {
    Backend.ready = true;
    GAnim.enabled = false;
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: [reelsProvider.overrideWith(() => _Reels(const []))], child: MaterialApp(home: G_244())));
    await t.pumpAndSettle();
    expect(find.text('Yannick M.'), findsNothing);
    expect(find.text('Cercle'), findsNothing);
    expect(find.text('Publier'), findsOneWidget);
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

  testWidgets('accueil connecté sans profil réel : cartes d’exemple marquées « Exemple »', (t) async {
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
    expect(find.text('Exemple'), findsWidgets);
  });
}
