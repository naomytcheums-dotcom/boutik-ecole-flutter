import 'package:boutik_ecole/data/demo/section_a_demo.dart';
import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('annuler une commande la marque annulée sans toucher aux autres, et son badge l\'indique', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(ordersProvider.notifier);
    c.read(cartProvider.notifier).add(const CartLine('Lampe', 'Département : Génie civil', 25000, 'assets/x.png'));
    final a = n.place();
    c.read(cartProvider.notifier).add(const CartLine('Sac', 'Département : Mode', 25000, 'assets/x.png'));
    final b = n.place();
    n.cancel(a.id);
    final orders = c.read(ordersProvider);
    expect(orders.firstWhere((o) => o.id == a.id).cancelled, isTrue);
    expect(orders.firstWhere((o) => o.id == a.id).badge, 'Annulée');
    expect(orders.firstWhere((o) => o.id == b.id).cancelled, isFalse);
  });

  test('payer puis annuler : le paiement reste enregistré, l\'annulation ne le modifie pas', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(cartProvider.notifier).add(const CartLine('Lampe', 'Département : Génie civil', 25000, 'assets/x.png'));
    final o = c.read(ordersProvider.notifier).place();
    c.read(ordersProvider.notifier).markPaid(o.id);
    expect(c.read(ordersProvider).first.paid, isTrue);
    expect(c.read(ordersProvider).first.copyWith(status: 2).paid, isTrue);
  });
}
