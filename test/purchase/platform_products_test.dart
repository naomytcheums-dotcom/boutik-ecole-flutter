import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String title, int price, int stock, {String dept = 'Agronomie', String status = 'approved'}) =>
    {'id': 'id-$title', 'seller_id': null, 'title': title, 'department': dept, 'category': 'Alimentation', 'price': price, 'stock': stock, 'status': status, 'description': ''};

class _FakePlatform extends PlatformListings {
  _FakePlatform(this.rows);
  final List<Listing>? rows;
  @override
  List<Listing>? build() => rows;
}

class _NoPublic extends PublicListings {
  @override
  List<Listing> build() => const [];
}

class _Own extends Listings {
  _Own(this.rows);
  final List<Listing> rows;
  @override
  List<Listing> build() => rows;
}

ProviderContainer _container(List<Listing>? platform, {List<Listing> own = const []}) => ProviderContainer(overrides: [
      platformListingsProvider.overrideWith(() => _FakePlatform(platform)),
      publicListingsProvider.overrideWith(_NoPublic.new),
      listingsProvider.overrideWith(() => _Own(own)),
    ]);

void main() {
  tearDown(() {
    Backend.ready = false;
    platformProducts = liveCatalog;
  });

  test('ligne serveur sans vendeur : produit de la plateforme', () {
    expect(Listing.fromRow(_row('Jus de bissap', 1500, 4)).platform, isTrue);
    expect(Listing.fromRow({..._row('Jus de bissap', 1500, 4), 'seller_id': 'u1'}).platform, isFalse);
    // une ligne lue sans la colonne seller_id n'est jamais prise pour un produit de la plateforme
    expect(Listing.fromRow({'id': 'x', 'title': 'T', 'price': 1000, 'stock': 1, 'status': 'approved'}).platform, isFalse);
    expect(Listing.fromRow(_row('Jus de bissap', 1500, 4)).copyWith(stock: 2).platform, isTrue);
  });

  test('hors connexion au serveur : catalogue d\'exemple inchangé (maquettes et golden images)', () {
    final c = _container(null);
    addTearDown(c.dispose);
    expect(c.read(platformProductsProvider), same(liveCatalog));
  });

  test('connecté : prix, stock, département et description viennent du serveur ; vendeur = plateforme', () {
    Backend.ready = true;
    final c = _container([
      Listing.fromRow(_row('Jus de bissap', 1800, 7)),
      Listing.fromRow({..._row('Confiture artisanale', 3500, 2, dept: 'Laboratoire de transformation'), 'description': 'Pot de 250 g.'}),
    ]);
    addTearDown(c.dispose);
    final all = c.read(allProductsProvider);
    final conf = all.firstWhere((p) => p.title == 'Confiture artisanale');
    expect(conf.price, 3500);
    expect(conf.department, 'Laboratoire de transformation');
    expect(conf.description, 'Pot de 250 g.');
    expect(conf.seller, platformSeller);
    expect(conf.image, liveCatalog.firstWhere((p) => p.title == 'Confiture artisanale').image);
    // ordre du catalogue d'origine conservé (Confiture avant Jus de bissap), aucun vendeur fictif
    expect([for (final p in all) p.title], ['Confiture artisanale', 'Jus de bissap']);
    expect(all.any((p) => p.seller == 'Ngono Aminata'), isFalse);
    // la fiche produit et le panier lisent le prix du serveur
    expect(productByTitle('Jus de bissap').price, 1800);
    expect(productPriceAndSeller(productByTitle('Jus de bissap')), '1 800 FCFA · Boutik-École');
  });

  test('connecté : un produit épuisé ou retiré n\'est pas proposé à l\'achat', () {
    Backend.ready = true;
    final c = _container([
      Listing.fromRow(_row('Jus de bissap', 1500, 0)),
      Listing.fromRow(_row('Confiture artisanale', 3000, 5, status: 'removed')),
      Listing.fromRow(_row('Pots connectés', 15000, 3)),
    ]);
    addTearDown(c.dispose);
    expect([for (final p in c.read(allProductsProvider)) p.title], ['Pots connectés']);
  });

  test('connecté, première lecture pas encore aboutie : aucun produit d\'exemple présenté comme réel', () {
    Backend.ready = true;
    final c = _container(null);
    addTearDown(c.dispose);
    expect(c.read(platformProductsProvider), isEmpty);
    expect(c.read(allProductsProvider), isEmpty);
  });

  test('département : un produit de la plateforme géré n\'apparaît pas en double comme annonce d\'étudiant', () {
    Backend.ready = true;
    final p = Listing.fromRow(_row('Jus de bissap', 1500, 6));
    final c = _container([p], own: [p]);
    addTearDown(c.dispose);
    final all = c.read(allProductsProvider);
    expect(all.where((x) => x.title == 'Jus de bissap').length, 1);
    expect(all.single.seller, platformSeller);
  });

  test('gestionnaires du catalogue de la plateforme : département et administrateur uniquement', () {
    expect(platformManagers, {'Resp. département', 'Admin global'});
  });
}
