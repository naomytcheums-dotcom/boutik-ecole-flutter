import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/widgets.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'backend.dart';
import 'auth.dart';
import 'store.dart';
import 'offer_types.dart' show offerTypeOfCategory;
import 'seller_new_product.dart';

/// Espace étudiant-vendeur : annonces, stocks, commandes reçues, préparation (écrans 57 à 67).

// ------------------------------------------------------------------ annonces

class Listing {
  const Listing({required this.title, required this.category, required this.price, required this.stock, this.published = true, this.inReview = false, this.description = '', this.id = '', this.status = '', this.note = '', this.images = const [], this.department = '', this.platform = false, this.showcase = false, this.supervisor = '', this.sellerId, this.recycled = false, this.recycledKg});
  final String title, category, description, department;

  /// Identifiant du vendeur (colonne `seller_id`) ; nul pour un produit de la plateforme ou hors connexion.
  final String? sellerId;

  /// Enseignant qui encadre le projet (facultatif), affiché sur la fiche de l'offre.
  final String supervisor;

  /// Déclaration « matériaux récupérés » (colonnes `recycled` et `recycled_kg`, poids par article) : alimente l'économie circulaire et les déchets valorisés.
  final bool recycled;
  final double? recycledKg;
  final int price, stock;
  final bool published, inReview;

  /// Produit de la plateforme (annonce sans vendeur), géré par le département ou l'administrateur.
  final bool platform;

  /// Produit d'exemple : affiché, jamais vendu (20261101000800).
  final bool showcase;

  /// Identifiant serveur (vide hors connexion), statut serveur (draft · pending · approved · rejected) et motif de refus.
  final String id, status, note;

  /// Chemins des photos dans le stockage public `listing-images` (<vendeur>/<annonce>/<fichier>).
  final List<String> images;

  bool get rejected => status == 'rejected';

  /// Construit l'annonce à partir d'une ligne de la table `listings`.
  factory Listing.fromRow(Map<String, dynamic> r) {
    final st = (r['status'] ?? 'draft').toString();
    return Listing(
      id: (r['id'] ?? '').toString(),
      title: (r['title'] ?? '').toString(),
      category: (r['category'] ?? 'Maison').toString(),
      price: (r['price'] as num?)?.toInt() ?? 0,
      stock: (r['stock'] as num?)?.toInt() ?? 0,
      description: (r['description'] ?? '').toString(),
      status: st,
      note: (r['review_note'] ?? '').toString(),
      published: st == 'approved',
      inReview: st == 'pending',
      images: [for (final i in (r['images'] as List? ?? const [])) i.toString()],
      department: (r['department'] ?? '').toString(),
      platform: r.containsKey('seller_id') && r['seller_id'] == null,
      showcase: r['showcase'] == true,
      supervisor: (r['supervisor'] ?? '').toString(),
      sellerId: r['seller_id']?.toString(),
      recycled: r['recycled'] == true,
      recycledKg: (r['recycled_kg'] as num?)?.toDouble(),
    );
  }

  /// Seuil de « Stock bas » : réglage du vendeur (seller_settings), 30 par défaut.
  static int lowStock = 30;

  /// Clé stable d'une annonce : son identifiant serveur, à défaut (hors connexion) son titre.
  String get key => id.isNotEmpty ? id : title;

  /// Libellé d'état : Brouillon, Rupture, Stock bas ou Publié.
  String get label => !published ? (inReview ? 'En validation' : (rejected ? 'Refusée' : (status == 'draft' && note.isNotEmpty ? 'Masquée' : 'Brouillon'))) : (stock == 0 ? 'Rupture' : (stock <= lowStock ? 'Stock bas' : 'Publié'));

  Listing copyWith({int? stock, bool? published, bool? inReview, String? status}) => Listing(
        id: id,
        images: images,
        department: department,
        platform: platform,
        showcase: showcase,
        status: status ?? this.status,
        note: note,
        title: title,
        category: category,
        price: price,
        stock: stock ?? this.stock,
        published: published ?? this.published,
        inReview: inReview ?? this.inReview,
        description: description,
        sellerId: sellerId,
        supervisor: supervisor,
        recycled: recycled,
        recycledKg: recycledKg);
}

class Listings extends Notifier<List<Listing>> {
  @override
  List<Listing> build() {
    if (!Backend.ready) return _demoListings;
    // connecté au serveur : le vendeur retrouve ses propres annonces (RLS), jamais celles d'un autre ni des exemples
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(() {
        if (!ref.mounted) return;
        ref.read(listingsLoadProvider.notifier).set('');
        refresh();
      });
      final t = Timer.periodic(const Duration(seconds: 30), (_) => refresh()); // décisions du département, ventes
      ref.onDispose(t.cancel);
    }
    return const [];
  }

  Future<void> refresh() async {
    final staff = ref.read(authProvider).current?.staff ?? '';
    List<Listing> l;
    try {
      l = await Backend.myListings(platform: platformManagers.contains(staff), strict: true);
    } catch (_) {
      // lecture impossible : on garde la dernière liste connue et on le dit (jamais « aucune annonce » à tort)
      if (ref.mounted) ref.read(listingsLoadProvider.notifier).set('error');
      return;
    }
    final s = await Backend.rpc('seller_settings_get', const {});
    if (s.error == null && s.data is Map) Listing.lowStock = ((s.data as Map)['stock_threshold'] as num?)?.toInt() ?? Listing.lowStock;
    if (!ref.mounted) return;
    state = l;
    ref.read(listingsLoadProvider.notifier).set('ok');
  }

  /// Dernière annonce créée par ce compte (sert à lui rattacher les photos choisies dans le formulaire).
  Listing? lastCreated;

  /// Création réelle : retourne un message d'erreur, ou null si l'annonce est enregistrée.
  Future<String?> create(Listing l, {required bool submit}) async {
    final r = await Backend.createListing(l, submit: submit);
    if (r.error != null) return r.error;
    lastCreated = r.listing;
    if (ref.mounted) state = [r.listing!, ...state];
    return null;
  }

  static const _demoListings = [
        Listing(title: 'Lampe en bois recyclé', category: 'Maison', price: 25000, stock: 12),
        Listing(title: 'Sac à dos design', category: 'Mode', price: 25000, stock: 8),
        Listing(title: 'Support téléphone', category: 'Tech', price: 8000, stock: 3),
        Listing(title: 'Tableau décoratif', category: 'Art', price: 18000, stock: 0),
        Listing(title: 'Pots connectés', category: 'Maison', price: 15000, stock: 10, published: false),
      ];

  void add(Listing l) => state = [l, ...state];
  void setStock(String key, int stock) {
    final before = state;
    final s = stock < 0 ? 0 : stock;
    bool hit(Listing l) => l.id == key || l.title == key;
    state = [for (final l in state) hit(l) ? l.copyWith(stock: s) : l];
    if (!Backend.ready) return;
    final id = before.firstWhere(hit, orElse: () => const Listing(title: '', category: '', price: 0, stock: 0)).id;
    if (id.isEmpty) return;
    Backend.updateListingStock(id, s).then((err) {
      if (err != null && ref.mounted) state = before; // l'écriture a échoué : on n'affiche pas un stock faux
    });
  }

  /// Retrouve une annonce par identifiant (ou titre hors connexion).
  Listing? _find(String key) {
    for (final l in state) {
      if (l.id == key || l.title == key) return l;
    }
    return null;
  }

  /// Soumission au département (brouillon ou refusée → en validation).
  Future<String?> submit(String title) async {
    final l = _find(title);
    if (l == null || l.id.isEmpty) return 'Annonce introuvable.';
    final err = await Backend.setListingStatus(l.id, 'pending');
    if (err == null) await refresh();
    return err;
  }

  /// Modification des champs (titre, prix, stock, description) ; le serveur valide et historise.
  Future<String?> edit(String title, {required String title2, required int price, required int stock, required String description, bool? recycled, double? recycledKg}) async {
    final l = _find(title);
    if (l == null || l.id.isEmpty) return 'Annonce introuvable.';
    final err = await Backend.updateListing(l.id, {'title': title2, 'price': price, 'stock': stock, 'description': description.isEmpty ? null : description, if (recycled != null) 'recycled': recycled, if (recycled != null) 'recycled_kg': recycled ? recycledKg : null});
    if (err == null) await refresh();
    return err;
  }

  Future<({String? error, List<String> images})> addImage(String title, Uint8List bytes, String name, String mime) async {
    final l = _find(title);
    if (l == null || l.id.isEmpty) return (error: 'Annonce introuvable.', images: const <String>[]);
    final r = await Backend.addListingImage(l.id, l.images, bytes, name, mime);
    if (r.error == null) await refresh();
    return r;
  }

  Future<({String? error, List<String> images})> removeImage(String title, String path) async {
    final l = _find(title);
    if (l == null || l.id.isEmpty) return (error: 'Annonce introuvable.', images: const <String>[]);
    final r = await Backend.removeListingImage(l.id, l.images, path);
    if (r.error == null) await refresh();
    return r;
  }

  /// Suppression (archivage) par le vendeur.
  Future<String?> remove(String key) async {
    final l = state.firstWhere((x) => x.id == key || x.title == key, orElse: () => const Listing(title: '', category: '', price: 0, stock: 0));
    if (Backend.ready && l.id.isNotEmpty) {
      final err = await Backend.setListingStatus(l.id, 'removed');
      if (err != null) return err;
    }
    if (ref.mounted) state = [for (final x in state) if (!(x.id == key || x.title == key)) x];
    return null;
  }
  /// Décision du valideur : publie l'annonce (approve) ou la renvoie en brouillon.
  void review(String title, bool approve) =>
      state = [for (final l in state) l.title == title ? l.copyWith(published: approve, inReview: false) : l];
  void publish(String title) => state = [for (final l in state) l.title == title ? l.copyWith(published: true) : l];
}

final listingsProvider = NotifierProvider<Listings, List<Listing>>(Listings.new);

/// Lecture des annonces du vendeur : '' = en cours (première lecture), 'ok', 'error' (dernière lecture échouée).
final listingsLoadProvider = NotifierProvider<StrV, String>(StrV.new);


/// Annonces approuvées des vendeurs (visibles de tous les acheteurs), lues sur le serveur.
class PublicListings extends Notifier<List<Listing>> {
  @override
  List<Listing> build() {
    if (!Backend.ready) return const [];
    Future.microtask(refresh);
    final t = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    ref.onDispose(t.cancel);
    return const [];
  }

  Future<void> refresh() async {
    final l = await Backend.publicListings();
    if (ref.mounted) state = l;
  }
}

final publicListingsProvider = NotifierProvider<PublicListings, List<Listing>>(PublicListings.new);

/// Rôles internes qui gèrent les produits de la plateforme (stock, prix, préparation des commandes).
const platformManagers = {'Resp. département', 'Admin global'};

/// Vendeur affiché pour un produit de la plateforme (aucun étudiant n'en est le vendeur).
const platformSeller = 'Boutik-École';

/// Produits de la plateforme lus sur le serveur ; null tant que la première lecture n'a pas abouti.
class PlatformListings extends Notifier<List<Listing>?> {
  @override
  List<Listing>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    final t = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    ref.onDispose(t.cancel);
    return null;
  }

  Future<void> refresh() async {
    final l = await Backend.platformListings();
    if (l != null && ref.mounted) state = l; // en cas d'échec, la dernière lecture réussie reste affichée
  }
}

final platformListingsProvider = NotifierProvider<PlatformListings, List<Listing>?>(PlatformListings.new);

/// Fiche acheteur d'un produit de la plateforme : valeurs du serveur, photo du stockage ou visuel d'origine du catalogue.
LiveProduct platformProduct(Listing l) {
  final orig = liveCatalog.where((p) => p.title == l.title);
  final image = l.images.isNotEmpty ? _photoOf(l) : (orig.isEmpty ? 'placeholder' : orig.first.image);
  return LiveProduct(l.title, l.department.isEmpty ? 'IUT de Douala' : l.department, l.price, l.showcase ? '$platformSeller · exemple' : platformSeller,
      l.description.isEmpty ? (orig.isEmpty ? '' : orig.first.description) : l.description, image,
      category: liveCategories.contains(l.category) ? l.category : 'Maison', showcase: l.showcase, stock: l.stock, id: l.id.isEmpty ? null : l.id);
}

/// Catalogue de la plateforme : hors connexion au serveur, le catalogue d'exemple ; sinon les produits publiés et en stock.
final platformProductsProvider = Provider<List<LiveProduct>>((ref) {
  if (!Backend.ready) return liveCatalog;
  final rows = ref.watch(platformListingsProvider) ?? const <Listing>[];
  int rank(Listing l) {
    final i = liveCatalog.indexWhere((p) => p.title == l.title);
    return i < 0 ? liveCatalog.length : i;
  }

  final sorted = [for (final l in rows) if (l.published && l.stock > 0 && !l.showcase) l]..sort((a, b) => rank(a).compareTo(rank(b)));
  return [for (final l in sorted) platformProduct(l)];
});

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
/// Photo principale d'une annonce : URL publique du stockage, sinon cadre neutre (jamais la photo d'un autre produit).
String _photoOf(Listing l) {
  if (l.images.isEmpty) return 'placeholder';
  final u = Backend.listingImageUrl(l.images.first);
  return u.isEmpty ? 'placeholder' : u;
}

/// Noms d'affichage (« Prénom N. ») des vendeurs d'annonces publiées, lus par la fonction publique `public_sellers` (visiteurs compris).
final sellerNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  if (!Backend.ready) return const {};
  final ids = {for (final l in ref.watch(publicListingsProvider)) if ((l.sellerId ?? '').isNotEmpty) l.sellerId!}.toList()..sort();
  if (ids.isEmpty) return const {};
  final r = await Backend.rpc('public_sellers', {'p_ids': ids});
  if (r.error != null || r.data is! Map) return const {};
  return {for (final e in (r.data as Map).entries) '${e.key}': '${e.value}'};
}, retry: (_, _) => null);

final allProductsProvider = Provider<List<LiveProduct>>((ref) {
  final own = ref.watch(listingsProvider);
  final ownIds = {for (final l in own) l.id};
  final mine = [...own, ...ref.watch(publicListingsProvider)];
  final names = ref.watch(sellerNamesProvider).value ?? const <String, String>{};
  final base = ref.watch(platformProductsProvider);
  platformProducts = base;
  final seen = <String>{};
  final extra = [
    for (final l in mine)
      if (!l.platform && l.published && l.stock > 0 && l.category != 'Services' && !base.any((p) => p.title == l.title) && seen.add(l.title))
        () {
          final isOwn = (l.id.isNotEmpty && ownIds.contains(l.id)) || (l.id.isEmpty && own.contains(l));
          final sid = (l.sellerId ?? '').isNotEmpty ? l.sellerId : (isOwn ? Backend.userId : null);
          return LiveProduct(l.title, l.department.isEmpty ? 'Non renseigné' : l.department, l.price, isOwn ? ref.watch(profileAccountProvider).name : (names[sid] ?? 'Vendeur'),
              l.description.isEmpty ? 'Annonce publiée par un étudiant.' : l.description, _photoOf(l),
              category: liveCategories.contains(l.category) ? l.category : 'Maison', sellerId: sid, stock: l.stock, id: l.id.isEmpty ? null : l.id);
        }(),
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
  const SellerOrder(this.id, this.title, this.client, this.total, this.qty, {this.status = 1, this.cod = false, this.home = false, this.city = '', this.confirmed = false, this.releaseAt = ''});
  final String id, title, client;
  final int total, qty;

  /// État de préparation côté serveur : 0 nouvelle · 1 acceptée · 2 en préparation · 3 prête · 4 livrée.
  final int status;

  /// Paiement à la livraison (le vendeur encaisse à la remise), remise à domicile et ville, confirmation de l'acheteur, date de libération prévue (ISO) de l'argent.
  final bool cod, home, confirmed;
  final String city, releaseAt;
}

/// Commandes payées contenant les annonces du vendeur connecté (serveur, isolées par RLS), actualisées toutes les 20 s.
class ServerSellerOrders extends Notifier<List<SellerOrder>> {
  @override
  List<SellerOrder> build() {
    if (!Backend.ready) return const [];
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(refresh);
      final t = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
      ref.onDispose(t.cancel);
    }
    return const [];
  }

  Future<void> refresh() async {
    final rows = await Backend.sellerOrders();
    if (!ref.mounted) return;
    state = [
      for (final r in rows)
        SellerOrder(
          (r['number'] ?? '').toString(),
          (r['title'] ?? 'Commande').toString() + ((r['nlines'] as num? ?? 1) > 1 ? ' + ${(r['nlines'] as num) - 1}' : ''),
          (r['buyer_name'] ?? 'Client').toString(),
          (r['total'] as num?)?.toInt() ?? 0,
          (r['qty'] as num?)?.toInt() ?? 0,
          status: (r['status'] as num?)?.toInt() ?? 0,
          cod: r['cod'] == true,
          home: r['home_delivery'] == true,
          city: (r['delivery_city'] ?? '').toString(),
          confirmed: r['confirmed'] == true,
          releaseAt: (r['release_at'] ?? '').toString(),
        ),
    ];
  }
}

final serverSellerOrdersProvider = NotifierProvider<ServerSellerOrders, List<SellerOrder>>(ServerSellerOrders.new);

const _seedOrders = [
  SellerOrder('#BE-2026-0142', 'Lampe en bois recyclé', 'Yannick M.', 25000, 1),
  SellerOrder('#BE-2026-0141', 'Sac à dos design', 'Amina T.', 25000, 1),
  SellerOrder('#BE-2026-0139', 'Support téléphone', 'Brice N.', 8000, 1),
  SellerOrder('#BE-2026-0137', 'Pots connectés', 'Kouassi T.', 15000, 1),
];

/// État de chaque commande reçue : 0 Nouvelle · 1 À préparer · 2 En cours · 3 Prête · 4 Livrée.
class SellerStatus extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    if (Backend.ready) return {for (final o in ref.watch(serverSellerOrdersProvider)) o.id: o.status};
    return const {'#BE-2026-0142': 1, '#BE-2026-0141': 0, '#BE-2026-0139': 1, '#BE-2026-0137': 2};
  }

  void set(String id, int s) => state = {...state, id: s};

  /// Avec le serveur : le statut n'est affiché qu'une fois enregistré ; sinon l'erreur est renvoyée.
  Future<String?> advance(String id, int s) async {
    if (!Backend.ready) {
      set(id, s);
      return null;
    }
    final err = await Backend.setSellerOrderStatus(id, s);
    if (err == null) await ref.read(serverSellerOrdersProvider.notifier).refresh();
    return err;
  }
}

final sellerStatusProvider = NotifierProvider<SellerStatus, Map<String, int>>(SellerStatus.new);

/// Commandes passées par les acheteurs (dans cette appli) + commandes de démonstration.
final sellerOrdersProvider = Provider<List<SellerOrder>>((ref) {
  if (Backend.ready) return ref.watch(serverSellerOrdersProvider);
  final real = ref.watch(ordersProvider);
  return [
    for (final o in real) SellerOrder(o.id, o.lines.isEmpty ? 'Commande' : o.lines.first.title, 'Mariam E.', o.total, o.lines.fold(0, (a, l) => a + l.qty)),
    ..._seedOrders,
  ];
});

/// Identifiant de la commande vendeur n° i, ou vide s'il n'y en a pas (évite une erreur d'index sur un compte sans commande).
String orderIdAt(WidgetRef ref, int i) {
  final l = ref.watch(sellerOrdersProvider);
  return i < l.length ? l[i].id : '';
}

int statusOf(Map<String, int> m, String id) => m[id] ?? (Backend.ready ? 0 : 1);

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
      _ => const Color(0xFF57545F),
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
  // aucune commande (compte réel sans vente) : fiche vide plutôt qu'une erreur d'affichage
  if (all.isEmpty) return const SellerOrder('', 'Aucune commande à préparer', '', 0, 0, status: 0);
  return all.firstWhere((o) => o.id == id, orElse: () => all.first);
});

// ------------------------------------------------------------------ formulaire « Nouveau produit »

String? _intError(String v, String what, {int min = 0, int? max}) {
  final n = int.tryParse(v.replaceAll(RegExp(r'[\s ]'), ''));
  if (n == null) return '$what : entrez un nombre entier.';
  if (n < min) return '$what : minimum $min.';
  if (max != null && n > max) return '$what : maximum $max.';
  return null;
}

/// Champs du formulaire « Nouveau produit » (58) dont les erreurs sont récapitulées par l'écran 275.
const newProductErrorKeys = ['np_title', 'np_price', 'np_cat', 'np_stock'];

/// « 2 champs à corriger… » : nombre réel d'erreurs ; rien n'est enregistré tant qu'elles subsistent.
String newProductErrorsSummary(Map<String, String> errs) {
  final n = newProductErrorKeys.where(errs.containsKey).length;
  return '$n champ${n > 1 ? 's' : ''} à corriger avant de continuer. Rien n’a été enregistré.';
}

bool _submittingListing = false;

/// Valeurs de départ du formulaire hors connexion : celles que la maquette affiche (prix « 25 000 », stock « 15 »).
/// Connecté, les champs démarrent vides : ce qui est enregistré est exactement ce que le vendeur a saisi.
String _priceOf(Map<String, String> f) => f['np_price'] ?? (demoContent ? '25 000' : '');
String _stockOf(Map<String, String> f) => f['np_stock'] ?? (demoContent ? '15' : '');

Future<void> submitListing(WidgetRef ref, BuildContext context, {required bool publish}) async {
  if (_submittingListing) return; // un double toucher ne crée pas deux annonces
  _submittingListing = true;
  try {
    await _submitListing(ref, context, publish: publish);
  } finally {
    _submittingListing = false;
  }
}

Future<void> _submitListing(WidgetRef ref, BuildContext context, {required bool publish}) async {
  final f0 = ref.read(formProvider);
  if (offerTypeOfCategory((f0['np_cat'] ?? '').trim()) == 'service') {
    // un service n'a ni stock ni tarif ferme : il se crée avec le formulaire dédié (tarif « Sur devis » possible)
    await gAlert(context, 'Utilisez « Nouveau service »', 'Un service se publie avec le formulaire « Nouveau service » : tarif « à partir de » ou « Sur devis », délai et mode de prestation. Ce formulaire est réservé aux produits, solutions et projets.');
    if (context.mounted) gOpen(context, '59');
    return;
  }
  if (publish && !await requireCertified(context, ref, 'publier une annonce') || !context.mounted) return;
  final f = ref.read(formProvider);
  final title = (f['np_title'] ?? '').trim();
  final cat = (f['np_cat'] ?? 'Maison et déco').trim();
  final errs = <String, String?>{
    'np_title': title.length < 3 ? 'Le titre est obligatoire (3 à 80 caractères).' : (title.length > 80 ? 'Titre trop long (80 caractères maximum).' : null),
    'np_price': _intError(_priceOf(f), 'Prix', min: 500),
    'np_stock': _intError(_stockOf(f), 'Stock'),
  };
  if (cat.isEmpty) errs['np_cat'] = 'Choisissez une catégorie.';
  final bad = {for (final e in errs.entries) if (e.value != null) e.key: e.value!};
  if (bad.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(bad);
    if (bad.length >= 2 && context.mounted) gOpen(context, '275'); // plusieurs erreurs : récapitulatif de la maquette
    return;
  }
  if (ref.read(listingsProvider).any((l) => l.title.toLowerCase() == title.toLowerCase())) {
    ref.read(errorsProvider.notifier).setAll({'np_title': 'Une annonce porte déjà ce titre.'});
    return;
  }
  final photos = ref.read(newProductPhotosProvider);
  if (publish && Backend.ready && photos.isEmpty) {
    await gAlert(context, 'Ajoutez une photo', 'Une annonce sans photo ne peut pas être envoyée en validation. Touchez « Ajouter des photos », ou enregistrez un brouillon pour continuer plus tard.');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final catShort = cat.toLowerCase().contains('maison') ? 'Maison' : (cat.toLowerCase().contains('mode') ? 'Mode' : (cat.toLowerCase().contains('tech') ? 'Tech' : (cat.toLowerCase().contains('art') ? 'Art' : (cat.toLowerCase().contains('alim') ? 'Alimentation' : cat))));
  final nouvelle = Listing(
    title: title,
    category: catShort,
    price: int.parse(_priceOf(f).replaceAll(RegExp(r'[\s\u00A0\u202F]'), '')),
    stock: int.parse(_stockOf(f).replaceAll(RegExp(r'[\s\u00A0\u202F]'), '')),
    published: false,
    inReview: publish,
    description: f['np_desc'] ?? '',
    supervisor: (f['np_sup'] ?? '').trim(),
  );
  if (Backend.ready) {
    final err = await ref.read(listingsProvider.notifier).create(nouvelle, submit: publish);
    if (err != null) {
      if (context.mounted) await gAlert(context, 'Annonce non enregistrée', err);
      return;
    }
  } else {
    ref.read(listingsProvider.notifier).add(nouvelle);
  }
  var photosFailed = 0;
  final created = ref.read(listingsProvider.notifier).lastCreated;
  if (Backend.ready && photos.isNotEmpty && created != null && created.id.isNotEmpty) {
    photosFailed = await uploadPickedPhotos(created.id, photos);
    await ref.read(listingsProvider.notifier).refresh();
  }
  resetNewProduct(ref);
  ref.read(sellerFilterProvider.notifier).set(0);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, publish ? 'Annonce soumise' : 'Brouillon créé', title, 'Validations');
  if (!context.mounted) return;
  gToast(context, photosFailed > 0
      ? 'Annonce enregistrée, mais $photosFailed photo${photosFailed > 1 ? 's' : ''} n’a pas pu être envoyée : ajoutez-la depuis « Modifier ».'
      : (publish ? 'Annonce envoyée en validation au département' : 'Brouillon enregistré'));
  gOpen(context, '61');
}

/// Mode de remise de la commande (sans adresse personnelle de l'acheteur) : retrait sur campus ou livraison dans sa ville.
String sellerOrderModeText(SellerOrder o) => !Backend.ready ? '' : (o.home ? 'Livraison à domicile${o.city.isEmpty ? '' : ' · ${o.city}'}' : 'Retrait sur campus');

/// Ce que le vendeur doit savoir de l'argent : montant à encaisser (paiement à la livraison) ou moment de libération de sa part.
String sellerOrderMoneyText(SellerOrder o) {
  if (!Backend.ready) return '';
  if (o.cod) return '${fcfa(o.total)} à encaisser à la remise';
  if (o.status < 4) return 'Libérée après la livraison confirmée';
  if (o.confirmed) return 'Libérée : réception confirmée';
  final d = DateTime.tryParse(o.releaseAt)?.toLocal();
  return d == null ? 'À la confirmation du client' : 'Le ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à ${d.hour.toString().padLeft(2, '0')} h sans réclamation';
}
/// Libellé du bouton principal selon l'état de préparation : accepter → préparer → prête → livrée.
String orderActionLabel(int status) => switch (status) {
      0 => 'Accepter',
      1 => 'Préparer',
      2 => 'Marquer prête',
      3 => 'Marquer livrée',
      _ => 'Livrée',
    };

/// Étape suivante de la commande ouverte (le serveur impose l'ordre et notifie l'acheteur).
Future<void> advanceCurrentOrder(WidgetRef ref, BuildContext context) async {
  final o = ref.read(currentSellerOrderProvider);
  final st = statusOf(ref.read(sellerStatusProvider), o.id);
  if (st >= 4) return gToast(context, 'Cette commande est déjà livrée.');
  final next = st + 1;
  final err = await ref.read(sellerStatusProvider.notifier).advance(o.id, next);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Statut non enregistré', err);
  gToast(context, switch (next) {
    1 => 'Commande ${o.id} acceptée : le client est averti',
    2 => 'Préparation de ${o.id} démarrée : le client est averti',
    3 => 'Commande ${o.id} prête : le client est averti',
    _ => o.cod
        ? 'Commande ${o.id} livrée : le client est averti et le montant est encaissé à la remise.'
        : 'Commande ${o.id} livrée : le client est averti et doit confirmer la réception ; sans réclamation de sa part, votre part est libérée après le délai de garde.',
  });
  if (next >= 3) gOpen(context, '63');
}

/// Texte du bouton principal, mis à jour avec l'état réel de la commande ouverte (écrans 64 et 65).
Widget orderActionText(double x, double y, double w) => gP(
      x, y, w, 18,
      Consumer(builder: (context, ref, _) {
        final o = ref.watch(currentSellerOrderProvider);
        final st = statusOf(ref.watch(sellerStatusProvider), o.id);
        return Center(child: Text(orderActionLabel(st), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), textBaseline: TextBaseline.alphabetic)));
      }),
    );

/// Marque la commande ouverte comme prête et revient à la liste.
Future<void> markOrderReady(WidgetRef ref, BuildContext context) async {
  final o = ref.read(currentSellerOrderProvider);
  final err = await ref.read(sellerStatusProvider.notifier).advance(o.id, 3);
  if (!context.mounted) return;
  if (err != null) return gAlert(context, 'Statut non enregistré', err);
  gToast(context, 'Commande ${o.id} prête : le client est averti');
  gOpen(context, '63');
}
