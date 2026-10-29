import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('annonces : états, filtres et diffusion dans le catalogue acheteur', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final l = c.read(listingsProvider);
    expect(l.length, 5);
    expect(l.firstWhere((x) => x.title == 'Tableau décoratif').label, 'Rupture');
    expect(l.firstWhere((x) => x.title == 'Support téléphone').label, 'Stock bas');
    expect(l.firstWhere((x) => x.title == 'Pots connectés').label, 'Brouillon');

    c.read(sellerFilterProvider.notifier).set(2);
    expect(c.read(visibleListingsProvider).map((x) => x.title), ['Pots connectés']);
    c.read(sellerFilterProvider.notifier).set(3);
    expect(c.read(visibleListingsProvider).map((x) => x.title), ['Tableau décoratif']);
    c.read(sellerFilterProvider.notifier).set(0);

    // nouvelle annonce publiée : visible dans la recherche des acheteurs
    c.read(listingsProvider.notifier).add(const Listing(title: 'Boîte à outils bois', category: 'Maison', price: 12000, stock: 6));
    c.read(searchQueryProvider.notifier).set('outils');
    expect(c.read(filteredProductsProvider).map((p) => p.title), ['Boîte à outils bois']);
    expect(productByTitle('Boîte à outils bois').price, 12000);

    // brouillon ou rupture : absent du catalogue
    c.read(listingsProvider.notifier).add(const Listing(title: 'Chaise brouillon', category: 'Maison', price: 9000, stock: 4, published: false));
    c.read(searchQueryProvider.notifier).set('chaise');
    expect(c.read(filteredProductsProvider), isEmpty);

    // réassort
    c.read(listingsProvider.notifier).setStock('Tableau décoratif', 10);
    expect(c.read(listingsProvider).firstWhere((x) => x.title == 'Tableau décoratif').label, 'Publié');
  });

  test('commandes reçues : onglets et préparation', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(visibleSellerOrdersProvider).length, 3); // à préparer : 0142, 0141 (nouvelle), 0139
    c.read(sellerStatusProvider.notifier).set('#BE-2026-0142', 3);
    expect(c.read(visibleSellerOrdersProvider).length, 2);
    c.read(sellerOrderTabProvider.notifier).set(2);
    expect(c.read(visibleSellerOrdersProvider).map((o) => o.id), ['#BE-2026-0142']);

    // une commande passée par un acheteur arrive chez le vendeur
    c.read(ordersProvider.notifier).place();
    expect(c.read(sellerOrdersProvider).first.id, c.read(ordersProvider).first.id);
  });
}
