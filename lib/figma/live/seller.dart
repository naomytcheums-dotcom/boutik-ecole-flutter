import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'backend.dart';
import 'auth.dart';
import 'store.dart';

/// Espace étudiant-vendeur : annonces, stocks, commandes reçues, préparation (écrans 57 à 67).

// ------------------------------------------------------------------ annonces

class Listing {
  const Listing({required this.title, required this.category, required this.price, required this.stock, this.published = true, this.inReview = false, this.description = '', this.id = '', this.status = '', this.note = '', this.images = const []});
  final String title, category, description;
  final int price, stock;
  final bool published, inReview;

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
    );
  }

  static const lowStock = 30;

  /// Libellé d'état : Brouillon, Rupture, Stock bas ou Publié.
  String get label => !published ? (inReview ? 'En validation' : (rejected ? 'Refusée' : 'Brouillon')) : (stock == 0 ? 'Rupture' : (stock <= lowStock ? 'Stock bas' : 'Publié'));

  Listing copyWith({int? stock, bool? published, bool? inReview, String? status}) => Listing(
        id: id,
        images: images,
        status: status ?? this.status,
        note: note,
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
  List<Listing> build() {
    if (!Backend.ready) return _demoListings;
    // connecté au serveur : le vendeur retrouve ses propres annonces (RLS), jamais celles d'un autre ni des exemples
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(refresh);
      final t = Timer.periodic(const Duration(seconds: 30), (_) => refresh()); // décisions du département, ventes
      ref.onDispose(t.cancel);
    }
    return const [];
  }

  Future<void> refresh() async {
    final l = await Backend.myListings();
    if (ref.mounted) state = l;
  }

  /// Création réelle : retourne un message d'erreur, ou null si l'annonce est enregistrée.
  Future<String?> create(Listing l, {required bool submit}) async {
    final r = await Backend.createListing(l, submit: submit);
    if (r.error != null) return r.error;
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
  void setStock(String title, int stock) {
    final before = state;
    final s = stock < 0 ? 0 : stock;
    state = [for (final l in state) l.title == title ? l.copyWith(stock: s) : l];
    if (!Backend.ready) return;
    final id = before.firstWhere((l) => l.title == title, orElse: () => const Listing(title: '', category: '', price: 0, stock: 0)).id;
    if (id.isEmpty) return;
    Backend.updateListingStock(id, s).then((err) {
      if (err != null && ref.mounted) state = before; // l'écriture a échoué : on n'affiche pas un stock faux
    });
  }

  Listing? _find(String title) {
    for (final l in state) {
      if (l.title == title) return l;
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
  Future<String?> edit(String title, {required String title2, required int price, required int stock, required String description}) async {
    final l = _find(title);
    if (l == null || l.id.isEmpty) return 'Annonce introuvable.';
    final err = await Backend.updateListing(l.id, {'title': title2, 'price': price, 'stock': stock, 'description': description.isEmpty ? null : description});
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
  Future<String?> remove(String title) async {
    final l = state.firstWhere((x) => x.title == title, orElse: () => const Listing(title: '', category: '', price: 0, stock: 0));
    if (Backend.ready && l.id.isNotEmpty) {
      final err = await Backend.setListingStatus(l.id, 'removed');
      if (err != null) return err;
    }
    if (ref.mounted) state = [for (final x in state) if (x.title != title) x];
    return null;
  }
  /// Décision du valideur : publie l'annonce (approve) ou la renvoie en brouillon.
  void review(String title, bool approve) =>
      state = [for (final l in state) l.title == title ? l.copyWith(published: approve, inReview: false) : l];
  void publish(String title) => state = [for (final l in state) l.title == title ? l.copyWith(published: true) : l];
}

final listingsProvider = NotifierProvider<Listings, List<Listing>>(Listings.new);


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

final allProductsProvider = Provider<List<LiveProduct>>((ref) {
  final own = ref.watch(listingsProvider);
  final ownIds = {for (final l in own) l.id};
  final mine = [...own, ...ref.watch(publicListingsProvider)];
  final base = liveCatalog;
  final seen = <String>{};
  final extra = [
    for (final l in mine)
      if (l.published && l.stock > 0 && l.category != 'Services' && !base.any((p) => p.title == l.title) && seen.add(l.title))
        LiveProduct(l.title, 'Étudiant-vendeur', l.price, (l.id.isNotEmpty && ownIds.contains(l.id)) || (l.id.isEmpty && own.contains(l)) ? ref.watch(profileAccountProvider).name : 'Étudiant-vendeur',
            l.description.isEmpty ? 'Annonce publiée par un étudiant de l’IUT de Douala.' : l.description, _photoOf(l), category: liveCategories.contains(l.category) ? l.category : 'Maison'),
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
  const SellerOrder(this.id, this.title, this.client, this.total, this.qty, {this.status = 1});
  final String id, title, client;
  final int total, qty;

  /// État de préparation côté serveur : 0 nouvelle · 1 acceptée · 2 en préparation · 3 prête · 4 livrée.
  final int status;
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

Future<void> submitListing(WidgetRef ref, BuildContext context, {required bool publish}) async {
  final f = ref.read(formProvider);
  final title = (f['np_title'] ?? '').trim();
  final cat = (f['np_cat'] ?? 'Maison et déco').trim();
  final errs = <String, String?>{
    'np_title': title.length < 3 ? 'Le titre est obligatoire (3 à 80 caractères).' : (title.length > 80 ? 'Titre trop long (80 caractères maximum).' : null),
    'np_price': _intError(f['np_price'] ?? '25 000', 'Prix', min: 500),
    'np_stock': _intError(f['np_stock'] ?? '30', 'Stock'),
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
  final nouvelle = Listing(
    title: title,
    category: catShort,
    price: int.parse((f['np_price'] ?? '25 000').replaceAll(RegExp(r'[\s ]'), '')),
    stock: int.parse(f['np_stock'] ?? '30'),
    published: false,
    inReview: publish,
    description: f['np_desc'] ?? '',
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
  ref.read(sellerFilterProvider.notifier).set(0);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, publish ? 'Annonce soumise' : 'Brouillon créé', title, 'Validations');
  if (!context.mounted) return;
  gToast(context, publish ? 'Annonce envoyée en validation au département' : 'Brouillon enregistré');
  gOpen(context, '61');
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
    _ => 'Commande ${o.id} livrée : le client est averti',
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
