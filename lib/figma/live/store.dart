import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart';
import 'dart:async' show Timer;
import 'auth.dart' show authProvider, demoContent;
import 'backend.dart';
import 'delivery.dart' show deliveryFee, deliverySettingsProvider;
import '../../data/repositories/repositories.dart' show cartProvider;

/// État partagé du parcours d'achat : fiche produit → panier → livraison → paiement → commande → suivi.

String fcfa(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b FCFA';
}

class LiveProduct {
  const LiveProduct(this.title, this.department, this.price, this.seller, this.description, this.image, {this.category = 'Maison', this.showcase = false});
  final String title, department, seller, description, image, category;
  final int price;

  /// Produit d'exemple (fictif) : visible pour montrer le rendu, jamais vendu (refus côté serveur, 20261101000800).
  final bool showcase;

  CartLine toLine() => CartLine(title, 'Département : $department', price, image);
}

const liveCatalog = <LiveProduct>[
  LiveProduct('Lampe en bois recyclé', 'Génie civil', 25000, 'Mouanga Yannick',
      'Lampe décorative fabriquée à partir de bois de récupération, avec éclairage LED économe.', 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', category: 'Maison'),
  LiveProduct('Drone éducatif', 'Génie électrique', 150000, 'Mbarga Carine',
      'Drone pédagogique programmable, idéal pour l’apprentissage de la robotique.', 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', category: 'Tech'),
  LiveProduct('Sac à dos design', 'Design – MMI', 25000, 'Fotso Brice',
      'Sac à dos en toile recyclée, dessiné et cousu par les étudiants.', 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', category: 'Mode'),
  LiveProduct('Pots connectés', 'Agronomie', 15000, 'Ngono Aminata',
      'Pots de plantes connectés avec capteur d’humidité.', 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', category: 'Maison'),
  LiveProduct('Support téléphone', 'Génie industriel', 8000, 'Biyick Éric',
      'Support de téléphone imprimé en 3D, plusieurs coloris.', 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', category: 'Tech'),
  LiveProduct('Tableau décoratif', 'Arts – Génie civil', 18000, 'Mouanga Yannick',
      'Tableau décoratif peint à la main.', 'assets/figma/img/34e8344812f71c763e7e4b52e1acffce9319e372.png', category: 'Art'),
  LiveProduct('Ordinateur portable prototype', 'Informatique', 250000, 'Essono Mariam',
      'Prototype d’ordinateur portable conçu et assemblé par les étudiants du département.', 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', category: 'Tech'),
  LiveProduct('Logo et identité visuelle', 'MMI', 50000, 'Tagne Kouassi',
      'Création d’un logo et d’une identité visuelle complète pour votre projet.', 'assets/figma/img/97b7907df36c390ae2383cc290f76358e22d2d7a.png', category: 'Art'),
  LiveProduct('Cours de soutien en maths', 'Informatique', 10000, 'Nkoa Paul',
      'Cours de soutien en mathématiques pour lycéens et étudiants de première année.', 'assets/figma/img/8397f0465c777ec9d53e7683ddc72818ff961acd.png', category: 'Tech'),
  LiveProduct('Confiture artisanale', 'Agronomie', 3000, 'Ngono Aminata',
      'Confiture de fruits locaux préparée au laboratoire de transformation.', 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', category: 'Alimentation'),
  LiveProduct('Jus de bissap', 'Agronomie', 1500, 'Ngono Aminata',
      'Jus de bissap frais, sans conservateur.', 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', category: 'Alimentation'),
];

/// Produits ajoutés par les vendeurs (mis à jour par allProductsProvider).
List<LiveProduct> extraProducts = const [];

/// Produits de la plateforme affichés (serveur une fois connecté, sinon catalogue d'exemple ; mis à jour par allProductsProvider).
List<LiveProduct> platformProducts = liveCatalog;

LiveProduct productByTitle(String t) => [...extraProducts, ...platformProducts, ...liveCatalog].firstWhere((p) => p.title == t, orElse: () => liveCatalog.first);

/// « 25 000 FCFA · Yannick M. » : prix et vendeur abrégé (nom enregistré « Nom Prénom »).
String productPriceAndSeller(LiveProduct p) {
  final parts = p.seller.trim().split(RegExp(r'\s+'));
  final who = parts.length >= 2 ? '${parts.last} ${parts.first[0]}.' : p.seller.trim();
  final price = fcfa(p.price).replaceAll('\u202f', ' '); // espace simple, comme sur la maquette
  return who.isEmpty ? price : '$price · $who';
}

class SelectedProduct extends Notifier<LiveProduct> {
  @override
  LiveProduct build() => liveCatalog.first;
  void select(String title) => state = productByTitle(title);
}

final selectedProductProvider = NotifierProvider<SelectedProduct, LiveProduct>(SelectedProduct.new);

/// Mode de livraison (07) : true = à domicile (frais 5 000 FCFA), false = retrait sur campus (gratuit).
class HomeDelivery extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final homeDeliveryProvider = NotifierProvider<HomeDelivery, bool>(HomeDelivery.new);

/// Moyen de paiement (08) : 0 = Orange Money, 1 = Mobile Money (autre).
class PayMethod extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final payMethodProvider = NotifierProvider<PayMethod, int>(PayMethod.new);

class Totals {
  const Totals(this.count, this.subtotal, this.fee);
  final int count, subtotal, fee;
  int get total => subtotal + fee;
}

final totalsProvider = Provider<Totals>((ref) {
  final lines = ref.watch(cartProvider);
  final home = ref.watch(homeDeliveryProvider);
  final sub = lines.fold<int>(0, (a, l) => a + l.price * l.qty);
  final n = lines.fold<int>(0, (a, l) => a + l.qty);
  return Totals(n, sub, lines.isEmpty ? 0 : deliveryFee(home, ref.watch(deliverySettingsProvider)));
});

class Order {
  const Order({required this.id, required this.date, required this.lines, required this.subtotal, required this.fee, required this.method, required this.reference, this.status = 0, this.paid = false, this.cancelled = false});
  final String id, date, method, reference;
  final List<CartLine> lines;
  final int subtotal, fee;
  final int status; // 0 confirmée · 1 en préparation · 2 expédiée · 3 livrée
  final bool paid, cancelled;
  int get total => subtotal + fee;
  String get badge => cancelled ? 'Annulée' : (status >= 3 ? 'Livrée' : 'En cours');

  /// Identité et montants imposés par le serveur.
  Order withServer(String id, int subtotal, int fee) => Order(
        id: id, date: date, lines: lines, subtotal: subtotal, fee: fee, method: method, reference: reference,
        status: status, paid: paid, cancelled: cancelled,
      );

  Order copyWith({int? status, bool? paid, bool? cancelled}) => Order(
        id: id, date: date, lines: lines, subtotal: subtotal, fee: fee, method: method, reference: reference,
        status: status ?? this.status, paid: paid ?? this.paid, cancelled: cancelled ?? this.cancelled,
      );
}

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

class Orders extends Notifier<List<Order>> {
  int _n = 143;
  @override
  List<Order> build() {
    if (Backend.ready) {
      final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
      if (uid.isNotEmpty) {
        Future.microtask(refresh);
        final t = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
        ref.onDispose(t.cancel);
      }
    }
    return const [];
  }

  /// Relit les commandes du compte connecté sur le serveur (état de préparation, paiement, annulation).
  Future<void> refresh() async {
    final rows = await Backend.myOrders();
    if (!ref.mounted || rows == null) return; // lecture échouée : la dernière liste connue reste affichée
    final server = [for (final r in rows) _fromServer(r)];
    final ids = {for (final o in server) o.id};
    state = [for (final o in state) if (!ids.contains(o.id) && !o.paid && !o.cancelled) o, ...server];
    ref.read(ordersLoadedProvider.notifier).set(true);
    ref.read(lastSyncProvider.notifier).set(DateTime.now());
  }

  static Order _fromServer(Map<String, dynamic> r) {
    final lines = [
      for (final l in (r['order_lines'] as List? ?? const []))
        () {
          final t = (l as Map)['title'] as String;
          final p = productByTitle(t);
          return CartLine(t, 'Département : ${p.department}', (l['unit_price'] as num).toInt(), p.image, qty: (l['qty'] as num).toInt());
        }(),
    ];
    final f = [for (final l in (r['order_lines'] as List? ?? const [])) ((l as Map)['fulfillment'] as num?)?.toInt() ?? 0];
    final step = f.isEmpty ? 0 : f.reduce((a, b) => a < b ? a : b);
    final d = DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now();
    return Order(
      id: r['number'] as String,
      date: '${d.day} ${_mois[d.month - 1]} ${d.year}',
      lines: lines,
      subtotal: (r['subtotal'] as num).toInt(),
      fee: (r['fee'] as num).toInt(),
      method: (r['method'] as String?) ?? '',
      reference: (r['reference'] as String?) ?? '',
      // préparation côté vendeur : 0 en attente · 1-2 en préparation · 3 prête · 4 livrée
      status: step <= 0 ? 0 : (step <= 2 ? 1 : (step == 3 ? 2 : 3)),
      paid: r['paid'] == true,
      // l'annulation serveur (cancel_order) renseigne cancelled_at ; le booléen n'est synchronisé qu'à partir de 20261031a
      cancelled: r['cancelled'] == true || r['cancelled_at'] != null,
    );
  }

  /// Crée la commande à partir du panier courant (en attente de paiement).
  Order place() {
    final now = DateTime.now();
    final t = ref.read(totalsProvider);
    final method = ref.read(payMethodProvider) == 0 ? 'Orange Money' : 'Mobile Money';
    final o = Order(
      id: '#BE-${now.year}-${(_n++).toString().padLeft(4, '0')}',
      date: '${now.day} ${_mois[now.month - 1]} ${now.year}',
      lines: List.of(ref.read(cartProvider)),
      subtotal: t.subtotal,
      fee: t.fee,
      method: method,
      reference: 'OM-${(now.millisecondsSinceEpoch % 0xFFFF).toRadixString(16).toUpperCase()}-${now.second.toString().padLeft(2, '0')}10',
    );
    state = [o, ...state];
    return o;
  }

  void adopt(String oldId, String id, int subtotal, int fee) => state = [for (final o in state) o.id == oldId ? o.withServer(id, subtotal, fee) : o];
  void discard(String id) => state = [for (final o in state) if (o.id != id) o];
  void cancel(String id) => state = [for (final o in state) o.id == id ? o.copyWith(cancelled: true) : o];
  void markPaid(String id) => state = [for (final o in state) o.id == id ? o.copyWith(paid: true) : o];
  void advance(String id) => state = [for (final o in state) o.id == id ? o.copyWith(status: (o.status + 1).clamp(0, 3)) : o];
}

final ordersProvider = NotifierProvider<Orders, List<Order>>(Orders.new);

class _OrdersLoaded extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? '')); // nouveau compte : rien n'est encore lu
    return false;
  }

  void set(bool v) => state = v;
}

/// Vrai dès qu'une lecture des commandes sur le serveur a réussi (une liste vide signifie alors « aucune commande »).
final ordersLoadedProvider = NotifierProvider<_OrdersLoaded, bool>(_OrdersLoaded.new);

class _When extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void set(DateTime v) => state = v;
}

/// Heure de la dernière lecture réussie des données du compte sur le serveur (écran 150-1).
final lastSyncProvider = NotifierProvider<_When, DateTime?>(_When.new);

/// « Mes commandes » d'un compte connecté sans aucune commande : l'écran d'état vide 150-4 remplace la liste 45.
bool showEmptyOrders({required bool ready, required bool loaded, required List<Order> orders}) => ready && loaded && orders.isEmpty;

/// Dernière commande passée (ou une commande d'exemple si aucune).
final lastOrderProvider = Provider<Order>((ref) {
  final l = ref.watch(ordersProvider);
  if (l.isNotEmpty) return l.first;
  final lines = ref.watch(cartProvider);
  final t = ref.watch(totalsProvider);
  return Order(id: '#BE-2026-0142', date: '22 oct. 2026', lines: lines, subtotal: t.subtotal, fee: t.fee, method: 'Orange Money', reference: 'OM-7F3A-2210');
});

String statusLabel(int s) => const ['Confirmée', 'En préparation', 'Expédiée', 'Livrée'][s.clamp(0, 3)];

/// Historique de démonstration (maquettes 28 et 45) : les nouvelles commandes passent devant.
final _history = <Order>[
  Order(id: '#BE-2026-0142', date: '22 oct. 2026', lines: [liveLine('Lampe en bois recyclé', 25000)], subtotal: 32500, fee: 0, method: 'Orange Money', reference: 'OM-7F3A-2210', status: 3, paid: true),
  Order(id: '#BE-2026-0138', date: '18 oct. 2026', lines: [liveLine('Support téléphone', 8000)], subtotal: 17000, fee: 0, method: 'Orange Money', reference: 'OM-5B21-1873', status: 1, paid: true),
  Order(id: '#BE-2026-0127', date: '12 oct. 2026', lines: [liveLine('Logo et identité visuelle', 45000)], subtotal: 45000, fee: 0, method: 'Mobile Money', reference: 'MM-9C40-0521', status: 3, paid: true),
  Order(id: '#BE-2026-0119', date: '05 oct. 2026', lines: [liveLine('Tableau décoratif', 28000)], subtotal: 28000, fee: 0, method: 'Mobile Money', reference: 'MM-1D77-9004', status: 0, paid: false, cancelled: true),
];

CartLine liveLine(String title, int price) {
  final p = productByTitle(title);
  return CartLine(p.title, 'Département : ${p.department}', price, p.image);
}

final ordersAllProvider = Provider<List<Order>>((ref) => demoContent ? [...ref.watch(ordersProvider), ..._history] : ref.watch(ordersProvider));

/// Commande ouverte depuis l'historique (sinon : la dernière).
class SelectedOrderId extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final selectedOrderIdProvider = NotifierProvider<SelectedOrderId, String?>(SelectedOrderId.new);

final viewedOrderProvider = Provider<Order>((ref) {
  final all = ref.watch(ordersAllProvider);
  final id = ref.watch(selectedOrderIdProvider);
  if (id != null) {
    for (final o in all) {
      if (o.id == id) return o;
    }
  }
  return ref.watch(lastOrderProvider);
});

Color badgeFill(String b) => switch (b) {
      'Livrée' => const Color(0xFFDDF5EC),
      'Annulée' => const Color(0xFFFDE6E7),
      _ => const Color(0xFFEFEBFA),
    };

Color badgeInk(String b) => switch (b) {
      'Livrée' => const Color(0xFF0F7A52),
      'Annulée' => const Color(0xFFE5484D),
      _ => const Color(0xFF5A3FE0),
    };

// ------------------------------------------------------------------ recherche et favoris

const liveCategories = ['Tous', 'Maison', 'Mode', 'Tech', 'Art', 'Alimentation'];

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);

class CategoryIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final categoryProvider = NotifierProvider<CategoryIndex, int>(CategoryIndex.new);

String normText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('î', 'i')
    .replaceAll('ç', 'c');

/// Favoris de l'utilisateur connecté (titres des produits), le plus récent en premier.
/// Avec le serveur : lus et écrits dans la table `favorites` (isolée par utilisateur) ; sans serveur (tests, aperçu) : liste d'exemple locale.
class Favorites extends Notifier<List<String>> {
  @override
  List<String> build() {
    if (!Backend.ready) return const ['Sac à dos design', 'Logo et identité visuelle', 'Cours de soutien en maths', 'Drone éducatif'];
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final l = await Backend.loadFavorites();
    if (ref.mounted) state = l;
  }

  bool has(String title) => state.contains(title);

  void toggle(String title) {
    final on = !state.contains(title);
    final before = state;
    state = on ? [title, ...state] : [for (final f in state) if (f != title) f];
    if (!Backend.ready) return;
    Backend.setFavorite(title, on).then((ok) {
      if (!ok && ref.mounted) state = before; // l'écriture a échoué : l'interface ne ment pas
    });
  }
}

final favoritesProvider = NotifierProvider<Favorites, List<String>>(Favorites.new);

final favoriteProductsProvider = Provider<List<LiveProduct>>((ref) => [for (final t in ref.watch(favoritesProvider)) productByTitle(t)]);

/// Petits états partagés (entier, texte).
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

/// Horloge de l'application (remplaçable dans les tests pour des rendus stables).
final nowProvider = Provider<DateTime>((_) => DateTime.now());
