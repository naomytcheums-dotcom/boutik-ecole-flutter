import '../../common/common.dart';

/// Libellé et teinte d'un statut de fiche.
(String, Color) listingStatus(ListingStatus s) => switch (s) {
  ListingStatus.published => ('Publié', AppColors.success),
  ListingStatus.inReview => ('En validation', AppColors.warning),
  ListingStatus.draft => ('Brouillon', AppColors.textSecondary),
};

String listingType(ListingType t) => switch (t) {
  ListingType.product => 'Produit',
  ListingType.service => 'Service',
  ListingType.project => 'Projet',
};

/// Filtre du catalogue départemental (287 tablette, 288 web).
class CatalogFilter extends Notifier<int> {
  @override
  int build() => 0;

  void select(int i) => state = i;
}

final catalogFilterProvider = NotifierProvider<CatalogFilter, int>(CatalogFilter.new);

const catalogFilters = ['Toutes', 'Produits', 'Services', 'Projets'];

List<Product> filterCatalog(List<Product> all, int filter) => switch (filter) {
  1 => all.where((p) => p.type == ListingType.product).toList(),
  2 => all.where((p) => p.type == ListingType.service).toList(),
  3 => all.where((p) => p.type == ListingType.project).toList(),
  _ => all,
};
