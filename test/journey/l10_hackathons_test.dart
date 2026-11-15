import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/hackathons.dart';
import 'package:boutik_ecole/figma/live/l10_hackathons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Lot L10 : écrans réels des hackathons (règlement lu sur le serveur, inscription individuelle, résultats honnêtes).
void main() {
  setUp(() => Backend.ready = false);
  tearDown(() => Backend.ready = false);

  final open = Hackathon('c1', 'Concours Test', '14–16 nov.', 'Douala', 500000, 40, 'Ouvert',
      desc: 'Une description réelle.', rules: 'Article 1 : équipes de 5 au plus.', serverStatus: 'published', regClose: DateTime(2099, 1, 1), submitClose: DateTime(2099, 2, 1));

  Future<void> pump(WidgetTester t, Widget screen, List<Override> overrides) async {
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: screen))));
    await t.pumpAndSettle();
  }

  testWidgets('161 : l’onglet Règlement affiche le règlement du concours', (t) async {
    await pump(t, const SizedBox(width: 342, height: 400, child: ContestInfoPanel()), [currentEventProvider.overrideWithValue(open)]);
    expect(find.text('Une description réelle.'), findsOneWidget);
    await t.tap(find.text('Règlement'));
    await t.pumpAndSettle();
    expect(find.text('Article 1 : équipes de 5 au plus.'), findsOneWidget);
  });

  testWidgets('161 : sans règlement publié, le texte le dit', (t) async {
    final noRules = Hackathon('c2', 'Sans règlement', '', 'En ligne', 0, 10, 'Ouvert', serverStatus: 'published');
    await pump(t, const SizedBox(width: 342, height: 400, child: ContestInfoPanel()), [currentEventProvider.overrideWithValue(noRules)]);
    await t.tap(find.text('Règlement'));
    await t.pumpAndSettle();
    expect(find.textContaining('pas encore publié de règlement'), findsOneWidget);
  });

  testWidgets('162 : aucune valeur de maquette ; l’inscription individuelle masque le nom d’équipe', (t) async {
    await pump(t, const ContestRegisterScreen(), [currentEventProvider.overrideWithValue(open)]);
    expect(find.text('Team Innov’'), findsNothing);
    expect(find.text('Inclusion financière'), findsNothing);
    expect(find.text('Nom de l’équipe'), findsOneWidget);
    await t.tap(find.text('Individuelle'));
    await t.pumpAndSettle();
    expect(find.text('Nom de l’équipe'), findsNothing);
    expect(find.text('Valider l’inscription'), findsOneWidget);
  });

  testWidgets('166 : avant la publication, aucun podium ni « 1er prix » inventé', (t) async {
    await pump(t, const ContestResultsScreen(), [currentEventProvider.overrideWithValue(open), rankingProvider.overrideWithValue(const [])]);
    expect(find.textContaining('1er prix'), findsNothing);
    expect(find.textContaining('seront publiés après le jury'), findsOneWidget);
  });

  testWidgets('166 : résultats publiés, classement réel', (t) async {
    final done = Hackathon('c1', 'Concours Test', '', 'Douala', 500000, 40, 'Résultats', serverStatus: 'results');
    await pump(t, const ContestResultsScreen(), [
      currentEventProvider.overrideWithValue(done),
      contestsProvider.overrideWithValue([done]),
      rankingProvider.overrideWithValue(const [Ranked('Équipe Alpha', 'Projet Alpha', 91)]),
    ]);
    expect(find.text('Équipe Alpha'), findsOneWidget);
    expect(find.text('91 pts'), findsOneWidget);
    expect(find.text('Voir mes certificats'), findsOneWidget);
  });
}
