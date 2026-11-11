import 'package:boutik_ecole/figma/live/marche/marche_data.dart';
import 'package:boutik_ecole/figma/live/offer_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le type d’offre se déduit de la catégorie', () {
    expect(offerTypeOfCategory('Maison et déco'), 'product');
    expect(offerTypeOfCategory('Solutions numériques'), 'tech');
    expect(offerTypeOfCategory('Services'), 'service');
    expect(offerTypeOfCategory('Projets et licences'), 'project');
    expect(offerTypeLabels.keys, ['product', 'tech', 'service', 'project']);
    for (final c in publishCategories) {
      expect(offerTypeLabels.containsKey(offerTypeOfCategory(c)), isTrue);
    }
  });

  test('le filtre de type part vers le serveur et compte comme filtre actif', () {
    const f = MarcheFilters();
    expect(f.productParams.containsKey('p_offer_type'), isFalse);
    final t = f.copy(offerType: 'service');
    expect(t.productParams['p_offer_type'], 'service');
    expect(t.active, isTrue);
    expect(t.copy(offerType: '').active, isFalse);
  });
}
