import 'package:boutik_ecole/figma/live/order_summary.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les trois moyens de paiement ont un libellé', () {
    expect(payMethodLabel(0), 'Orange Money');
    expect(payMethodLabel(1), 'Mobile Money');
    expect(payMethodLabel(2), 'Paiement à la livraison');
  });

  test('la commande créée en paiement à la livraison porte ce moyen et reste non payée', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(payMethodProvider.notifier).set(2);
    final o = c.read(ordersProvider.notifier).place();
    expect(o.method, 'Paiement à la livraison');
    expect(o.paid, isFalse);
    expect(c.read(payMethodProvider), 2);
  });
}
