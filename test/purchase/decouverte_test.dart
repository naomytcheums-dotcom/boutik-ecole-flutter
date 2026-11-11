import 'package:boutik_ecole/figma/live/marche/decouverte.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('« mon stock se perd » mène aux outils de gestion de stock', () {
    final t = problemTerms('mon stock se perd');
    expect(t, containsAll(['stock', 'perd', 'inventaire', 'gestion']));
    expect(t.contains('mon'), isFalse, reason: 'mots vides ignorés');
  });

  test('un seul mot : recherche simple, pas de recherche par problème', () {
    expect(problemTerms('lampe'), isEmpty);
    const f = MarcheFilters(q: 'lampe');
    expect(f.productParams['p_q'], 'lampe');
    expect(f.productParams.containsKey('p_terms'), isFalse);
  });

  test('une phrase part en mots-clés, sans doublon de p_q', () {
    const f = MarcheFilters(q: 'mon stock se perd');
    expect(f.productParams.containsKey('p_q'), isFalse);
    expect(f.productParams['p_terms'], isNotEmpty);
    expect((f.productParams['p_terms'] as List).length, lessThanOrEqualTo(12));
  });

  test('filière et besoin : paramètres envoyés et filtre actif', () {
    const f = MarcheFilters();
    expect(f.active, isFalse);
    final a = f.copy(department: 'civil');
    expect(a.productParams['p_department'], 'civil');
    expect(a.active, isTrue);
    final b = f.copy(need: 'coder');
    expect(b.productParams['p_terms'], containsAll(['code', 'développeur']));
    expect(b.active, isTrue);
    expect(marcheFilieres.values, containsAll(['Génie électrique', 'Génie informatique', 'Génie civil', 'Agroalimentaire']));
  });
}
