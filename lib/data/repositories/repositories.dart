import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../demo/catalog_demo.dart';
import '../demo/nouveaux_demo.dart';
import '../demo/section_a_demo.dart';
import '../demo/section_b_demo.dart';
import '../models/models.dart';

export '../demo/section_a_demo.dart' show CartLine, ExploreItem, SectionAData, Totals;
export '../demo/section_b_demo.dart' show SearchResult, SectionBData;

/// Dépôt du catalogue. Implémentation de démonstration : données locales fictives.
/// Pour brancher l'API, fournir une autre implémentation via `overrideWithValue`.
abstract interface class CatalogRepository {
  List<Product> products();
  List<Talent> talents();
}

class DemoCatalogRepository implements CatalogRepository {
  const DemoCatalogRepository();

  @override
  List<Product> products() => demoProducts;

  @override
  List<Talent> talents() => demoTalents;
}

final catalogRepositoryProvider = Provider<CatalogRepository>((_) => const DemoCatalogRepository());

/// Données des écrans de la section « Nouveaux écrans ».
final nouveauxDataProvider = Provider<NouveauxData>((_) => const NouveauxData());

/// Données de la section A (démarrage et parcours d'achat).
final sectionADataProvider = Provider<SectionAData>((_) => const SectionAData());

/// Données de la section B (authentification).
final sectionBDataProvider = Provider<SectionBData>((_) => const SectionBData());

/// Rôle choisi à l'inscription (13).
class RoleNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void set(int v) => state = v;
}

final roleProvider = NotifierProvider<RoleNotifier, int>(RoleNotifier.new);

/// Panier partagé entre la fiche produit (05), le panier (06) et le paiement (08).
class CartNotifier extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => ref.read(sectionADataProvider).cart;

  void setQty(int index, int qty) {
    if (qty < 1) return remove(index);
    state = [for (final (i, l) in state.indexed) i == index ? l.withQty(qty) : l];
  }

  void remove(int index) => state = [...state]..removeAt(index);

  void add(CartLine line) {
    final i = state.indexWhere((l) => l.title == line.title);
    state = i < 0 ? [...state, line] : [for (final (j, l) in state.indexed) j == i ? l.withQty(l.qty + 1) : l];
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartLine>>(CartNotifier.new);

/// Mode de livraison choisi (07) : true = retrait sur campus.
class PickupNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool v) => state = v;
}

final pickupProvider = NotifierProvider<PickupNotifier, bool>(PickupNotifier.new);

/// Indique que l'application tourne sur des données de démonstration (affiché dans les paramètres).
final demoModeProvider = Provider<bool>((_) => true);
