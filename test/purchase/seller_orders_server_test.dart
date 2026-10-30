import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends ServerSellerOrders {
  @override
  List<SellerOrder> build() => const [
        SellerOrder('#BE-1', 'Lampe', 'Bruno A.', 20000, 2, status: 0),
        SellerOrder('#BE-2', 'Sac', 'Chloé M.', 25000, 1, status: 3),
        SellerOrder('#BE-3', 'Logo', 'Dan K.', 50000, 1, status: 4),
      ];
}

void main() {
  tearDown(() => Backend.ready = false);

  test('avec le serveur : les commandes reçues et leurs statuts viennent du serveur, jamais des exemples', () {
    Backend.ready = true;
    final c = ProviderContainer(overrides: [serverSellerOrdersProvider.overrideWith(_Fake.new)]);
    addTearDown(c.dispose);
    final orders = c.read(sellerOrdersProvider);
    expect(orders.map((o) => o.id), ['#BE-1', '#BE-2', '#BE-3']);
    expect(orders.any((o) => o.client == 'Yannick M.'), isFalse);
    final st = c.read(sellerStatusProvider);
    expect(statusOf(st, '#BE-1'), 0);
    expect(statusOf(st, '#BE-2'), 3);
    expect(statusOf(st, '#inconnue'), 0);
  });

  test('onglets : à préparer (nouvelles et acceptées), prêtes, livrées', () {
    Backend.ready = true;
    final c = ProviderContainer(overrides: [serverSellerOrdersProvider.overrideWith(_Fake.new)]);
    addTearDown(c.dispose);
    c.read(sellerOrderTabProvider.notifier).set(0);
    expect(c.read(visibleSellerOrdersProvider).map((o) => o.id), ['#BE-1']);
    c.read(sellerOrderTabProvider.notifier).set(2);
    expect(c.read(visibleSellerOrdersProvider).map((o) => o.id), ['#BE-2']);
    c.read(sellerOrderTabProvider.notifier).set(3);
    expect(c.read(visibleSellerOrdersProvider).map((o) => o.id), ['#BE-3']);
  });

  test('hors connexion : les exemples de la maquette et le statut local', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(sellerOrdersProvider), isNotEmpty);
    expect(await c.read(sellerStatusProvider.notifier).advance('#BE-2026-0141', 3), isNull);
    expect(statusOf(c.read(sellerStatusProvider), '#BE-2026-0141'), 3);
  });
}
