import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouter;

import '../../data/demo/section_a_demo.dart' show CartLine;
import '../../data/repositories/repositories.dart' show cartProvider;
import '../gen.dart';
import '../nav.dart';
import 'backend.dart' show Backend;
import 'client_space.dart' show clientSpaceProvider;
import 'store.dart';

/// Liste de « Mes commandes » (écrans 45 et 28) : toutes les commandes dans une zone défilante, avec recherche, filtre par état et tri réels.

final ordersQueryProvider = NotifierProvider<StrV, String>(StrV.new);

/// 0 toutes · 1 en cours · 2 livrées · 3 annulées.
final ordersFilterProvider = NotifierProvider<IntV, int>(IntV.new);

/// 0 récentes d'abord · 1 anciennes d'abord · 2 montant décroissant.
final ordersSortProvider = NotifierProvider<IntV, int>(IntV.new);

const ordersSortLabels = ['Récentes', 'Anciennes', 'Montant'];

/// Commandes retenues par la recherche (numéro, date, article), le filtre d'état et le tri.
List<Order> filterOrders(List<Order> all, {String query = '', int filter = 0, int sort = 0}) {
  final q = normText(query.trim());
  final out = [
    for (final o in all)
      if ((switch (filter) {
            1 => !o.cancelled && o.status < 3,
            2 => !o.cancelled && o.status >= 3,
            3 => o.cancelled,
            _ => true,
          }) &&
          (q.isEmpty || normText('${o.id} ${o.date} ${o.method} ${o.lines.map((l) => l.title).join(' ')}').contains(q)))
        o,
  ];
  if (sort == 1) return out.reversed.toList();
  if (sort == 2) out.sort((a, b) => b.total.compareTo(a.total));
  return out;
}

class OrdersListView extends ConsumerWidget {
  const OrdersListView({super.key, this.width = 342, this.height = 470});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(ordersAllProvider);
    if (Backend.ready && all.isEmpty && !ref.watch(ordersLoadedProvider)) {
      final failed = ref.watch(ordersFailedProvider);
      return SizedBox(
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: failed ? () => ref.read(ordersProvider.notifier).refresh() : null,
          child: gText(failed ? 'Vos commandes ne peuvent pas être chargées pour le moment. Vérifiez votre connexion puis touchez ici pour réessayer.' : 'Chargement de vos commandes…', 13.5, const Color(0xFF57545F), lh: 20, wrap: true),
        ),
      );
    }
    final list = filterOrders(all, query: ref.watch(ordersQueryProvider), filter: ref.watch(ordersFilterProvider), sort: ref.watch(ordersSortProvider));
    if (list.isEmpty) {
      final none = all.isEmpty;
      return SizedBox(
        width: width,
        height: height,
        child: gText(none ? 'Vous n’avez pas encore de commande. Vos achats apparaîtront ici, avec leur suivi.' : 'Aucune commande ne correspond à votre recherche.', 13.5, const Color(0xFF57545F), lh: 20, wrap: true),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 18, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) => _OrderRow(list[i], onTap: () {
          ref.read(selectedOrderIdProvider.notifier).set(list[i].id);
          gOpen(context, '09');
        }),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow(this.o, {required this.onTap});
  final Order o;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CartLine? first = o.lines.isEmpty ? null : o.lines.first;
    final img = first != null && first.image.startsWith('assets/') ? first.image : neutralProductImage;
    return Semantics(
      button: true,
      label: 'Commande ${o.id}, ${o.badge}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(img, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: const Color(0xFFF1EEFB)))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                gText(o.id, 13.5, const Color(0xFF111015), weight: 600, wrap: true, maxLines: 1),
                const SizedBox(height: 4),
                gText('${o.date}  •  ${fcfa(o.total)}', 11.5, const Color(0xFF57545F), wrap: true, maxLines: 1),
                if (o.lines.length > 1) gText('${o.lines.length} articles', 11, const Color(0xFF57545F), wrap: true, maxLines: 1),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: badgeFill(o.badge), borderRadius: BorderRadius.circular(11)),
              child: SizedBox(width: o.badge.length > 9 ? 78 : null, child: gText(o.badge, 10.5, badgeInk(o.badge), weight: 600, align: TextAlign.center, wrap: true, maxLines: 2)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Libellé du tri choisi (« Récentes », « Anciennes », « Montant »).
String ordersSortLabel(int sort) => ordersSortLabels[sort.clamp(0, ordersSortLabels.length - 1)];

/// Résumé acheteur de « Mon espace client » (261) : commandes en cours, à payer, panier, commandes récentes et accès au carnet d'adresses.
class ClientSummary extends ConsumerWidget {
  const ClientSummary({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final cart = ref.watch(cartProvider);
    final unknown = Backend.ready && !ref.watch(ordersLoadedProvider);
    final active = orders.where((o) => !o.cancelled && !o.awaitingPayment && o.status < 3).length;
    final toPay = orders.where((o) => o.awaitingPayment).length;
    final recent = orders.take(3).toList();
    Widget tile(String value, String label, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 86,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                gText(value, 20, const Color(0xFF111015), weight: 700, wrap: true),
                const SizedBox(height: 4),
                gText(label, 10.5, const Color(0xFF57545F), wrap: true, maxLines: 2),
              ]),
            ),
          ),
        );
    Widget link(String label, VoidCallback onTap, {String? count}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Expanded(child: gText(label, 13, const Color(0xFF111015), weight: 600, wrap: true)),
              if (count != null) Padding(padding: const EdgeInsets.only(right: 4), child: gText(count, 12.5, const Color(0xFF57545F), weight: 600)),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF57545F)),
            ]),
          ),
        );
    final space = ref.watch(clientSpaceProvider).asData?.value;
    String? n(String k) => space == null || space[k] == null ? null : '${space[k]}';
    final openCases = space == null ? null : ((space['disputes_open'] as num? ?? 0) + (space['claims_open'] as num? ?? 0)).toInt();
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          tile(unknown ? '—' : '$active', 'Commandes en cours', () => gOpen(context, '45')),
          tile(unknown ? '—' : '$toPay', 'À payer', () => gOpen(context, '45')),
          tile('${cart.fold<int>(0, (a, l) => a + l.qty)}', 'Dans le panier', () => gOpen(context, '06')),
        ]),
        const SizedBox(height: 18),
        gText('Commandes récentes', 15, const Color(0xFF111015), weight: 600, wrap: true),
        const SizedBox(height: 8),
        if (unknown)
          gText(ref.watch(ordersFailedProvider) ? 'Vos commandes ne peuvent pas être chargées pour le moment.' : 'Chargement de vos commandes…', 12.5, const Color(0xFF57545F), wrap: true)
        else if (recent.isEmpty)
          gText('Aucune commande pour le moment. Vos achats apparaîtront ici avec leur suivi.', 12.5, const Color(0xFF57545F), wrap: true)
        else
          for (final o in recent)
            _OrderRow(o, onTap: () {
              ref.read(selectedOrderIdProvider.notifier).set(o.id);
              gOpen(context, '09');
            }),
        const SizedBox(height: 6),
        link('Mes commandes et leur suivi', () => gOpen(context, '45')),
        link('Mes favoris', () => gOpen(context, '25'), count: n('favorites')),
        link('Mes adresses de livraison', () => gOpen(context, '27'), count: n('addresses')),
        link('Mes avis', () => GoRouter.of(context).push('/mes-avis'), count: n('reviews')),
        link('Mes litiges et réclamations', () => GoRouter.of(context).push('/litiges'), count: openCases == null ? null : '$openCases en cours'),
        link('Mes informations personnelles', () => GoRouter.of(context).push('/parametres/informations')),
      ]),
    );
  }
}
