import 'package:boutik_ecole/figma/live/review.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une annonce soumise passe par la validation du département', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(pendingReviewsProvider).length, 5);

    c.read(listingsProvider.notifier).add(const Listing(title: 'Établi pliant', category: 'Maison', price: 40000, stock: 3, published: false, inReview: true));
    expect(c.read(pendingReviewsProvider).first.title, 'Établi pliant');
    expect(c.read(listingsProvider).first.label, 'En validation');
    c.read(searchQueryProvider.notifier).set('établi');
    expect(c.read(filteredProductsProvider), isEmpty); // pas encore visible des acheteurs

    // le valideur accepte : l'annonce est publiée
    c.read(reviewDecisionsProvider.notifier).decide('Établi pliant', 1, '');
    c.read(listingsProvider.notifier).review('Établi pliant', true);
    expect(c.read(pendingReviewsProvider).length, 5);
    expect(c.read(listingsProvider).first.label, 'Stock bas');
    expect(c.read(filteredProductsProvider).map((p) => p.title), ['Établi pliant']);

    // un refus renvoie en brouillon
    c.read(listingsProvider.notifier).add(const Listing(title: 'Table basse', category: 'Maison', price: 30000, stock: 9, published: false, inReview: true));
    c.read(reviewDecisionsProvider.notifier).decide('Table basse', 2, 'Photos manquantes');
    c.read(listingsProvider.notifier).review('Table basse', false);
    expect(c.read(listingsProvider).firstWhere((l) => l.title == 'Table basse').label, 'Brouillon');
    expect(reviewCount(c.read(reviewDecisionsProvider), 2), 1);
    c.read(reviewTabProvider.notifier).set(2);
    expect(c.read(visibleReviewsProvider).map((r) => r.title), ['Table basse']);
  });

  test('les paiements des commandes alimentent les flux financiers', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(flowRowsProvider).length, 5);
    final o = c.read(ordersProvider.notifier).place();
    final rows = c.read(flowRowsProvider);
    expect(rows.length, 6);
    expect(rows.first.orderId, o.id);
    expect(rows.first.status, 'À vérifier');
    c.read(ordersProvider.notifier).markPaid(o.id);
    expect(c.read(flowRowsProvider).first.status, 'Vérifié');
  });
}
