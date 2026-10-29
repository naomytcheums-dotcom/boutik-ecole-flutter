import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'store.dart';

/// Espace étudiant-vendeur : annonces, stocks, commandes reçues, préparation (écrans 57 à 67).

// ------------------------------------------------------------------ annonces

class Listing {
  const Listing({required this.title, required this.category, required this.price, required this.stock, this.published = true, this.inReview = false, this.description = ''});
  final String title, category, description;
  final int price, stock;
  final bool published, inReview;

  static const lowStock = 5;

  /// Libellé d'état : Brouillon, Rupture, Stock bas ou Publié.
  String get label => !published ? (inReview ? 'En validation' : 'Brouillon') : (stock == 0 ? 'Rupture' : (stock <= lowStock ? 'Stock bas' : 'Publié'));

  Listing copyWith({int? stock, bool? published, bool? inReview}) => Listing(
        title: title,
        category: category,
        price: price,
        stock: stock ?? this.stock,
        published: published ?? this.published,
        inReview: inReview ?? this.inReview,
        description: description);
}

class Listings extends Notifier<List<Listing>> {
  @override
  List<Listing> build() => const [
        Listing(title: 'Lampe en bois recyclé', category: 'Maison', price: 25000, stock: 12),
        Listing(title: 'Sac à dos design', category: 'Mode', price: 25000, stock: 8),
        Listing(title: 'Support téléphone', category: 'Tech', price: 8000, stock: 3),
        Listing(title: 'Tableau décoratif', category: 'Art', price: 18000, stock: 0),
        Listing(title: 'Pots connectés', category: 'Maison', price: 15000, stock: 10, published: false),
      ];

  void add(Listing l) => state = [l, ...state];
  void setStock(String title, int stock) => state = [for (final l in state) l.title == title ? l.copyWith(stock: stock < 0 ? 0 : stock) : l];
  /// Décision du valideur : publie l'annonce (approve) ou la renvoie en brouillon.
  void review(String title, bool approve) =>
      state = [for (final l in state) l.title == title ? l.copyWith(published: approve, inReview: false) : l];
  void publish(String title) => state = [for (final l in state) l.title == title ? l.copyWith(published: true) : l];
}

final listingsProvider = NotifierProvider<Listings, List<Listing>>(Listings.new);

class IntV extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

class StrV extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final sellerFilterProvider = NotifierProvider<IntV, int>(IntV.new);
final sellerQueryProvider = NotifierProvider<StrV, String>(StrV.new);

/// Annonces visibles selon l'onglet (Tous, Publiés, Brouillons, Rupture) et la recherche.
final visibleListingsProvider = Provider<List<Listing>>((ref) {
  final all = ref.watch(listingsProvider);
  final f = ref.watch(sellerFilterProvider);
  final q = ref.watch(sellerQueryProvider).trim().toLowerCase();
  return [
    for (final l in all)
      if ((f == 0 || (f == 1 && l.published) || (f == 2 && !l.published) || (f == 3 && l.published && l.stock == 0)) && (q.isEmpty || l.title.toLowerCase().contains(q))) l,
  ];
});

/// Produits du catalogue acheteur : catalogue de base + annonces publiées par le vendeur.
final allProductsProvider = Provider<List<LiveProduct>>((ref) {
  final mine = ref.watch(listingsProvider);
  final base = liveCatalog;
  final extra = [
    for (final l in mine)
      if (l.published && l.stock > 0 && !base.any((p) => p.title == l.title))
        LiveProduct(l.title, 'Étudiant-vendeur', l.price, ref.watch(profileAccountProvider).name,
            l.description.isEmpty ? 'Annonce publiée par un étudiant de l’IUT de Douala.' : l.description, base[3].image, category: liveCategories.contains(l.category) ? l.category : 'Maison'),
  ];
  extraProducts = extra;
  return [...extra, ...base];
});

/// Produits correspondant à la recherche et à la catégorie choisies (catalogue + annonces des vendeurs).
final filteredProductsProvider = Provider<List<LiveProduct>>((ref) {
  final q = normText(ref.watch(searchQueryProvider).trim());
  final cat = liveCategories[ref.watch(categoryProvider).clamp(0, liveCategories.length - 1)];
  return [
    for (final p in ref.watch(allProductsProvider))
      if ((cat == 'Tous' || p.category == cat) && (q.isEmpty || normText('${p.title} ${p.department} ${p.category} ${p.seller}').contains(q))) p,
  ];
});

// ------------------------------------------------------------------ commandes reçues

class SellerOrder {
  const SellerOrder(this.id, this.title, this.client, this.total, this.qty);
  final String id, title, client;
  final int total, qty;
}

const _seedOrders = [
  SellerOrder('#BE-2026-0142', 'Lampe en bois recyclé', 'Yannick M.', 25000, 1),
  SellerOrder('#BE-2026-0141', 'Sac à dos design', 'Amina T.', 25000, 1),
  SellerOrder('#BE-2026-0139', 'Support téléphone', 'Brice N.', 8000, 1),
  SellerOrder('#BE-2026-0137', 'Pots connectés', 'Kouassi T.', 15000, 1),
];

/// État de chaque commande reçue : 0 Nouvelle · 1 À préparer · 2 En cours · 3 Prête · 4 Livrée.
class SellerStatus extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {'#BE-2026-0142': 1, '#BE-2026-0141': 0, '#BE-2026-0139': 1, '#BE-2026-0137': 2};
  void set(String id, int s) => state = {...state, id: s};
}

final sellerStatusProvider = NotifierProvider<SellerStatus, Map<String, int>>(SellerStatus.new);

/// Commandes passées par les acheteurs (dans cette appli) + commandes de démonstration.
final sellerOrdersProvider = Provider<List<SellerOrder>>((ref) {
  final real = ref.watch(ordersProvider);
  return [
    for (final o in real) SellerOrder(o.id, o.lines.isEmpty ? 'Commande' : o.lines.first.title, 'Mariam E.', o.total, o.lines.fold(0, (a, l) => a + l.qty)),
    ..._seedOrders,
  ];
});

int statusOf(Map<String, int> m, String id) => m[id] ?? 1;

String sellerStatusLabel(int s) => const ['Nouvelle', 'À préparer', 'En cours', 'Prête', 'Livrée'][s.clamp(0, 4)];

Color sellerPillFill(String l) => switch (l) {
      'À préparer' => const Color(0xFFEEE9FF),
      'Prête' || 'Livrée' => const Color(0xFFDDF5EC),
      _ => const Color(0xFFEFEBFA),
    };

Color sellerPillInk(String l) => switch (l) {
      'À préparer' => const Color(0xFF8F5400),
      'Prête' || 'Livrée' => const Color(0xFF0F7A52),
      _ => const Color(0xFF5A3FE0),
    };

Color listingPillFill(String l) => switch (l) {
      'Publié' => const Color(0xFFDDF5EC),
      'Rupture' => const Color(0xFFFDE6E7),
      'Stock bas' || 'En validation' => const Color(0xFFEEE9FF),
      _ => const Color(0xFFF2EFF6),
    };

Color listingPillInk(String l) => switch (l) {
      'Publié' => const Color(0xFF0F7A52),
      'Rupture' => const Color(0xFFE5484D),
      'Stock bas' || 'En validation' => const Color(0xFF8F5400),
      _ => const Color(0xFF66636E),
    };

/// Commande de la liste filtrée par onglet : 0 À préparer (nouvelles + à préparer) · 1 En cours · 2 Prêtes · 3 Livrées.
final sellerOrderTabProvider = NotifierProvider<IntV, int>(IntV.new);
final selectedSellerOrderProvider = NotifierProvider<StrV, String>(StrV.new);

final visibleSellerOrdersProvider = Provider<List<SellerOrder>>((ref) {
  final all = ref.watch(sellerOrdersProvider);
  final st = ref.watch(sellerStatusProvider);
  final tab = ref.watch(sellerOrderTabProvider);
  bool inTab(int s) => switch (tab) { 0 => s <= 1, 1 => s == 2, 2 => s == 3, _ => s == 4 };
  return [for (final o in all) if (inTab(statusOf(st, o.id))) o];
});

final currentSellerOrderProvider = Provider<SellerOrder>((ref) {
  final all = ref.watch(sellerOrdersProvider);
  final id = ref.watch(selectedSellerOrderProvider);
  return all.firstWhere((o) => o.id == id, orElse: () => all.first);
});

// ------------------------------------------------------------------ formulaire « Nouveau produit »

String? _intError(String v, String what, {int min = 0}) {
  final n = int.tryParse(v.replaceAll(RegExp(r'[\s ]'), ''));
  if (n == null) return '$what : entrez un nombre entier.';
  if (n < min) return '$what : minimum $min.';
  return null;
}

void submitListing(WidgetRef ref, BuildContext context, {required bool publish}) {
  final f = ref.read(formProvider);
  final title = (f['np_title'] ?? '').trim();
  final cat = (f['np_cat'] ?? 'Maison et déco').trim();
  final errs = <String, String?>{
    'np_title': title.length < 3 ? 'Le titre est obligatoire (3 à 80 caractères).' : (title.length > 80 ? 'Titre trop long (80 caractères maximum).' : null),
    'np_price': _intError(f['np_price'] ?? '25 000', 'Prix', min: 500),
    'np_stock': _intError(f['np_stock'] ?? '15', 'Stock'),
  };
  if (cat.isEmpty) errs['np_cat'] = 'Choisissez une catégorie.';
  final bad = {for (final e in errs.entries) if (e.value != null) e.key: e.value!};
  if (bad.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(bad);
    return;
  }
  if (ref.read(listingsProvider).any((l) => l.title.toLowerCase() == title.toLowerCase())) {
    ref.read(errorsProvider.notifier).setAll({'np_title': 'Une annonce porte déjà ce titre.'});
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final catShort = cat.toLowerCase().contains('maison') ? 'Maison' : (cat.toLowerCase().contains('mode') ? 'Mode' : (cat.toLowerCase().contains('tech') ? 'Tech' : (cat.toLowerCase().contains('art') ? 'Art' : (cat.toLowerCase().contains('alim') ? 'Alimentation' : cat))));
  ref.read(listingsProvider.notifier).add(Listing(
        title: title,
        category: catShort,
        price: int.parse((f['np_price'] ?? '25 000').replaceAll(RegExp(r'[\s ]'), '')),
        stock: int.parse(f['np_stock'] ?? '15'),
        published: false,
        inReview: publish,
        description: f['np_desc'] ?? '',
      ));
  ref.read(sellerFilterProvider.notifier).set(0);
  gToast(context, publish ? 'Annonce envoyée en validation au département' : 'Brouillon enregistré');
  gOpen(context, '61');
}

/// Marque la commande ouverte comme prête et revient à la liste.
void markOrderReady(WidgetRef ref, BuildContext context) {
  final o = ref.read(currentSellerOrderProvider);
  ref.read(sellerStatusProvider.notifier).set(o.id, 3);
  gToast(context, 'Commande ${o.id} prête : le client est averti');
  gOpen(context, '63');
}
