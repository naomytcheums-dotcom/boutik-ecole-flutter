import 'package:boutik_ecole/figma/live/decouverte_screens.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la recherche avancée envoie disponibilité, vendeurs vérifiés, budget et tri au serveur', () {
    const f = MarcheFilters();
    expect(f.productParams.containsKey('p_in_stock'), isFalse);
    final a = f.copy(inStock: true, verified: true, min: 1000, max: 5000, sort: 'price_asc', offerType: 'product');
    expect(a.productParams['p_in_stock'], true);
    expect(a.productParams['p_verified'], true);
    expect(a.productParams['p_min'], 1000);
    expect(a.productParams['p_max'], 5000);
    expect(a.productParams['p_sort'], 'price_asc');
    expect(a.productParams['p_offer_type'], 'product');
    expect(a.active, isTrue);
    expect(a.activeCount, 5);
  });

  test('« Réinitialiser » remet tous les filtres à zéro', () {
    final a = const MarcheFilters().copy(q: 'lampe', inStock: true, min: 10);
    expect(a.active, isTrue);
    expect(const MarcheFilters().active, isFalse);
    expect(const MarcheFilters().activeCount, 0);
  });

  test('les pastilles Tous · Produits · Services · Talents · Projets suivent l’état partagé', () {
    expect(kExploreKinds.length, kExploreLabels.length);
    expect(exploreKindIndex(const MarcheFilters(), false), 0);
    expect(exploreKindIndex(const MarcheFilters(offerType: 'service'), false), 2);
    expect(exploreKindIndex(const MarcheFilters(offerType: 'project'), false), 4);
    expect(exploreKindIndex(const MarcheFilters(offerType: 'product'), true), 3, reason: 'les talents priment sur le type');
    expect(exploreKindIndex(const MarcheFilters(offerType: 'inconnu'), false), 0);
  });

  test('le compteur dit ce qui est chargé et s’il en reste', () {
    expect(resultCountLabel(0, false), '0 résultat');
    expect(resultCountLabel(1, false), '1 résultat');
    expect(resultCountLabel(3, false), '3 résultats');
    expect(resultCountLabel(24, true), '24+ résultats');
  });
}
