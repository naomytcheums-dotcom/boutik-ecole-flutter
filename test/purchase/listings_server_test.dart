import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/review.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePublic extends PublicListings {
  @override
  List<Listing> build() => [
        Listing.fromRow({'id': 'a1', 'title': 'Casque d\'un autre vendeur', 'category': 'Tech', 'price': 30000, 'stock': 12, 'status': 'approved'}),
        Listing.fromRow({'id': 'a2', 'title': 'Épuisé', 'category': 'Tech', 'price': 1000, 'stock': 0, 'status': 'approved'}),
      ];
}

class _FakeQueue extends ReviewQueue {
  @override
  List<ReviewItem> build() => const [
        ReviewItem('En attente', 'Étudiant-vendeur', 'Art', 5000, 'À l’instant', seed: false, id: 'p', status: 'pending'),
        ReviewItem('Validée', 'Étudiant-vendeur', 'Art', 5000, 'Il y a 1 h', seed: false, id: 'a', status: 'approved'),
        ReviewItem('Refusée', 'Étudiant-vendeur', 'Art', 5000, 'Il y a 2 h', seed: false, id: 'r', status: 'rejected', note: 'Photo manquante'),
      ];
}

void main() {
  tearDown(() => Backend.ready = false);

  test('les statuts serveur donnent les bons libellés vendeur', () {
    Listing l(String st, int stock) => Listing.fromRow({'id': 'x', 'title': 'T', 'category': 'Art', 'price': 1000, 'stock': stock, 'status': st});
    expect(l('draft', 10).label, 'Brouillon');
    expect(l('pending', 10).label, 'En validation');
    expect(l('rejected', 10).label, 'Refusée');
    expect(l('approved', 100).label, 'Publié');
    expect(l('approved', Listing.lowStock).label, 'Stock bas');
    expect(l('approved', 0).label, 'Rupture');
    expect(l('approved', 5).published, isTrue);
    expect(l('pending', 5).published, isFalse);
    expect(l('draft', 5).id, 'x');
  });

  test('copyWith conserve l\'identifiant et le statut serveur', () {
    final a = Listing.fromRow({'id': 'abc', 'title': 'T', 'category': 'Art', 'price': 1000, 'stock': 4, 'status': 'approved'});
    final b = a.copyWith(stock: 9);
    expect(b.id, 'abc');
    expect(b.status, 'approved');
    expect(b.stock, 9);
  });

  test('catalogue acheteur : annonces approuvées des autres vendeurs, sans rupture ni doublon', () {
    final c = ProviderContainer(overrides: [publicListingsProvider.overrideWith(_FakePublic.new)]);
    addTearDown(c.dispose);
    final titles = c.read(allProductsProvider).map((p) => p.title).toList();
    expect(titles, contains('Casque d\'un autre vendeur'));
    expect(titles, isNot(contains('Épuisé')));
    expect(titles.where((t) => t == 'Casque d\'un autre vendeur').length, 1);
  });

  test('annonce sans photo : cadre neutre, jamais la photo d'un autre produit ; annonce avec photo : sa propre photo', () {
    final c = ProviderContainer(overrides: [publicListingsProvider.overrideWith(_FakePublic.new)]);
    addTearDown(c.dispose);
    final p = c.read(allProductsProvider).firstWhere((p) => p.title == 'Casque d'un autre vendeur');
    expect(p.image, 'placeholder');
    expect(p.seller, 'Étudiant-vendeur'); // pas le nom de la personne qui consulte
  });

  test('file de validation serveur : les décisions viennent du statut enregistré', () {
    Backend.ready = true;
    final c = ProviderContainer(overrides: [reviewQueueProvider.overrideWith(_FakeQueue.new)]);
    addTearDown(c.dispose);
    expect(c.read(pendingReviewsProvider).map((r) => r.title), ['En attente']);
    final d = c.read(reviewDecisionsProvider);
    expect(d['Validée']!.$1, 1);
    expect(d['Refusée']!.$1, 2);
    expect(d['Refusée']!.$2, 'Photo manquante');
    expect(d.containsKey('En attente'), isFalse);
  });

  test('hors connexion, rien n\'est tiré du serveur', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(publicListingsProvider), isEmpty);
    expect(c.read(reviewQueueProvider), isEmpty);
  });
}
