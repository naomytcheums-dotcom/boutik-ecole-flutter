import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recherche, catégories et favoris partagés.
void main() {
  test('la recherche et les catégories filtrent le catalogue', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(filteredProductsProvider).length, liveCatalog.length);

    c.read(searchQueryProvider.notifier).set('sac');
    expect(c.read(filteredProductsProvider).map((p) => p.title), ['Sac à dos design']);

    // recherche sans accent / en majuscules
    c.read(searchQueryProvider.notifier).set('ELECTRIQUE');
    expect(c.read(filteredProductsProvider).map((p) => p.title), ['Drone éducatif']);

    c.read(searchQueryProvider.notifier).set('');
    c.read(categoryProvider.notifier).set(liveCategories.indexOf('Alimentation'));
    expect(c.read(filteredProductsProvider).every((p) => p.category == 'Alimentation'), isTrue);
    expect(c.read(filteredProductsProvider), isNotEmpty);

    c.read(searchQueryProvider.notifier).set('zzzz');
    expect(c.read(filteredProductsProvider), isEmpty);
  });

  test('les favoris sont partagés et ajoutés en tête', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(favoritesProvider.notifier);
    expect(c.read(favoriteProductsProvider).length, 4);
    n.toggle('Sac à dos design'); // retire
    expect(c.read(favoritesProvider).contains('Sac à dos design'), isFalse);
    n.toggle('Lampe en bois recyclé'); // ajoute en tête
    expect(c.read(favoritesProvider).first, 'Lampe en bois recyclé');
    expect(c.read(favoriteProductsProvider).first.price, 25000);
  });
}
