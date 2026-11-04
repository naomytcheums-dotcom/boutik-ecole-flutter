import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'store.dart' show fcfa;

/// Vue d'ensemble de la plateforme (écran 108, tableau de bord du département) : chiffres lus sur le serveur par la fonction
/// `platform_overview` (migration 20261104000000), réservée au personnel. Hors connexion, la maquette reste affichée comme démonstration.
class Overview {
  const Overview({required this.students, required this.sellers, required this.listingsApproved, required this.listingsPending, required this.orders, required this.ordersPaid, required this.paidRevenue});
  final int students, sellers, listingsApproved, listingsPending, orders, ordersPaid, paidRevenue;

  static Overview fromJson(Map x) => Overview(
        students: (x['students'] as num?)?.toInt() ?? 0,
        sellers: (x['sellers'] as num?)?.toInt() ?? 0,
        listingsApproved: (x['listings_approved'] as num?)?.toInt() ?? 0,
        listingsPending: (x['listings_pending'] as num?)?.toInt() ?? 0,
        orders: (x['orders'] as num?)?.toInt() ?? 0,
        ordersPaid: (x['orders_paid'] as num?)?.toInt() ?? 0,
        paidRevenue: (x['paid_revenue'] as num?)?.toInt() ?? 0,
      );
}

/// `null` : lecture en cours, serveur absent ou accès refusé (aucun chiffre n'est inventé).
class OverviewNotifier extends Notifier<Overview?> {
  @override
  Overview? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('platform_overview', const {});
    if (!ref.mounted) return;
    state = (r.error == null && r.data is Map) ? Overview.fromJson(r.data as Map) : null;
  }
}

final overviewProvider = NotifierProvider<OverviewNotifier, Overview?>(OverviewNotifier.new);

/// Chiffre d'affaires encaissé : « — » tant qu'il n'est pas lu.
String overviewRevenue(Overview? o) => o == null ? '—' : fcfa(o.paidRevenue);
String overviewRevenueK(Overview? o) => o == null ? '—' : '${(o.paidRevenue / 1000).round()} k';

/// Compteur entier lu sur le serveur : « — » tant qu'il n'est pas lu.
String overviewCount(Overview? o, int Function(Overview) pick) => o == null ? '—' : '${pick(o)}';
