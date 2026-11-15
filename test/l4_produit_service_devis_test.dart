import 'package:flutter_test/flutter_test.dart';
import 'package:boutik_ecole/data/demo/section_a_demo.dart';
import 'package:boutik_ecole/figma/live/produit_fiche.dart' show productShareLink, shortPersonName;
import 'package:boutik_ecole/figma/live/services.dart' show kMaxQuoteBudget, parseFcfa, quoteAmountError;

void main() {
  group('montants de devis (parseFcfa)', () {
    test('lit les écritures courantes', () {
      expect(parseFcfa('2500'), 2500);
      expect(parseFcfa('2 500'), 2500);
      expect(parseFcfa('2.500'), 2500);
      expect(parseFcfa('25 000 FCFA'), 25000);
      expect(parseFcfa('1.234.567'), 1234567);
      expect(parseFcfa('2 500,50'), 2501);
    });

    test('refuse ce qui n’est pas un montant', () {
      expect(parseFcfa(''), isNull);
      expect(parseFcfa('abc'), isNull);
      expect(parseFcfa('12-5'), isNull);
    });

    test('borne le budget', () {
      expect(quoteAmountError('25 000'), isNull);
      expect(quoteAmountError('0'), isNotNull);
      expect(quoteAmountError('${kMaxQuoteBudget + 1}'), isNotNull);
      expect(quoteAmountError('beaucoup'), isNotNull);
    });
  });

  group('fiche produit unifiée', () {
    test('le lien partagé pointe vers la fiche réelle', () {
      expect(productShareLink('abc-123'), endsWith('/#/marche/produit/abc-123'));
    });

    test('le nom du prestataire est abrégé', () {
      expect(shortPersonName('Mouanga Yannick'), 'Mouanga Y.');
      expect(shortPersonName('Prince'), 'Prince');
      expect(shortPersonName('   '), '');
    });
  });

  group('variante du panier', () {
    test('la variante survit à la sérialisation et à la quantité', () {
      const line = CartLine('Lampe', 'Boutique : Atelier', 25000, 'img', variant: 'Couleur : Noyer');
      final back = CartLine.fromJson(line.toJson())!;
      expect(back.variant, 'Couleur : Noyer');
      expect(back.withQty(3).variant, 'Couleur : Noyer');
    });

    test('une ligne sans variante garde les anciens constructeurs', () {
      const line = CartLine('Lampe', 'Dept', 25000, 'img');
      expect(line.variant, isNull);
      expect(line.toJson().containsKey('variant'), isFalse);
      expect(CartLine.fromJson(line.toJson())!.variant, isNull);
    });
  });
}
