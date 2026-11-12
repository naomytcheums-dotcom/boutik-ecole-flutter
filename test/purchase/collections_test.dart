import 'package:boutik_ecole/figma/live/collections_screens.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: w))));
  await t.pumpAndSettle();
}

class _Favs extends Favorites {
  @override
  List<String> build() => ['Lampe de bureau', 'Tapis', 'Casque audio'];
}

void main() {
  test('sous-titre : nombre d’articles et visibilité', () {
    expect(collectionSubtitle(const ProductCollection(id: '1', name: 'A', visibility: 'private')), 'Vide · Privée');
    expect(collectionSubtitle(const ProductCollection(id: '1', name: 'A', visibility: 'shared', items: ['x'])), '1 article · Partagée');
    expect(collectionSubtitle(const ProductCollection(id: '1', name: 'A', visibility: 'public', items: ['x', 'y'])), '2 articles · Publique');
  });

  test('lecture depuis le serveur', () {
    final c = ProductCollection.fromJson({'id': 'c', 'name': 'Salon', 'visibility': 'public', 'items': ['Lampe']});
    expect(c.items, ['Lampe']);
    expect(c.visibility, 'public');
  });

  testWidgets('panneau : listes, création, favoris', (t) async {
    await _pump(t, const CollectionsPanel(height: 1500), overrides: [
      collectionsProvider.overrideWith((ref) async => [
            const ProductCollection(id: '1', name: 'Maison et déco', visibility: 'private', items: ['Lampe de bureau']),
            const ProductCollection(id: '2', name: 'Cadeaux', visibility: 'shared'),
          ]),
      favoritesProvider.overrideWith(_Favs.new),
    ]);
    expect(find.text('Maison et déco'), findsOneWidget);
    expect(find.text('1 article · Privée'), findsOneWidget);
    expect(find.text('Vide · Partagée'), findsOneWidget);
    expect(find.text('Créer une collection'), findsOneWidget);
    expect(find.text('Tous mes favoris'), findsOneWidget);
    expect(find.text('Casque audio'), findsOneWidget);
  });

  testWidgets('fiche d’une collection : retirer, ajouter depuis les favoris', (t) async {
    await _pump(t, const CollectionSheet(id: '1'), overrides: [
      collectionsProvider.overrideWith((ref) async => [const ProductCollection(id: '1', name: 'Maison et déco', visibility: 'private', items: ['Lampe de bureau'])]),
      favoritesProvider.overrideWith(_Favs.new),
    ]);
    expect(find.text('Maison et déco'), findsOneWidget);
    expect(find.byTooltip('Retirer'), findsOneWidget);
    expect(find.text('Ajouter depuis mes favoris'), findsOneWidget);
    expect(find.byTooltip('Ajouter'), findsNWidgets(2), reason: 'Tapis et Casque audio ; la lampe y est déjà');
    expect(find.byTooltip('Modifier'), findsOneWidget);
    expect(find.byTooltip('Supprimer'), findsOneWidget);
  });
}
