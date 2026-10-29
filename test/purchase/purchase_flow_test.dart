import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parcours d'achat : fiche produit → panier → livraison → commande → paiement.
void main() {
  test('le panier, les totaux et la commande restent cohérents', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // Panier de départ = celui de la maquette (3 articles, 325 000 FCFA).
    expect(c.read(cartProvider).length, 3);
    expect(c.read(totalsProvider).subtotal, 325000);
    expect(c.read(totalsProvider).fee, 0); // retrait sur campus par défaut

    // Ajout d'un produit depuis la fiche (05)
    c.read(selectedProductProvider.notifier).select('Drone éducatif');
    c.read(cartProvider.notifier).add(c.read(selectedProductProvider).toLine());
    expect(c.read(cartProvider).length, 4);
    expect(c.read(totalsProvider).count, 4);
    expect(c.read(totalsProvider).subtotal, 475000);

    // Quantité + : 2 × Drone
    c.read(cartProvider.notifier).setQty(3, 2);
    expect(c.read(totalsProvider).subtotal, 625000);

    // Livraison à domicile : +5 000 FCFA
    c.read(homeDeliveryProvider.notifier).set(true);
    expect(c.read(totalsProvider).total, 630000);
    expect(fcfa(c.read(totalsProvider).total), '630 000 FCFA');

    // Suppression d'une ligne
    c.read(cartProvider.notifier).remove(0);
    expect(c.read(totalsProvider).subtotal, 375000);

    // Commande + paiement
    final o = c.read(ordersProvider.notifier).place();
    expect(o.total, 380000);
    expect(o.id, startsWith('#BE-'));
    expect(c.read(lastOrderProvider).id, o.id);
    expect(c.read(ordersProvider).first.paid, isFalse);
    c.read(ordersProvider.notifier).markPaid(o.id);
    expect(c.read(lastOrderProvider).paid, isTrue);

    // Suivi : la commande avance jusqu'à « Livrée »
    for (var i = 0; i < 5; i++) {
      c.read(ordersProvider.notifier).advance(o.id);
    }
    expect(statusLabel(c.read(lastOrderProvider).status), 'Livrée');
  });
}
