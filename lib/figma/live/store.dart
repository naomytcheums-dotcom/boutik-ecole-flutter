import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart';
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
  const LiveProduct(this.title, this.department, this.price, this.seller, this.description, this.image);
  final String title, department, seller, description, image;
  final int price;

  CartLine toLine() => CartLine(title, 'Département : $department', price, image);
}

const liveCatalog = <LiveProduct>[
  LiveProduct('Lampe en bois recyclé', 'Génie civil', 25000, 'Mouanga Yannick',
      'Lampe décorative fabriquée à partir de bois de récupération, avec éclairage LED économe.', 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png'),
  LiveProduct('Ordinateur portable prototype', 'Informatique', 250000, 'Essono Mariam',
      'Prototype d’ordinateur portable conçu et assemblé par les étudiants du département.', 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png'),
  LiveProduct('Logo et identité visuelle', 'MMI', 50000, 'Tagne Kouassi',
      'Création d’un logo et d’une identité visuelle complète pour votre projet.', 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png'),
  LiveProduct('Drone éducatif', 'Génie électrique', 150000, 'Mbarga Carine',
      'Drone pédagogique programmable, idéal pour l’apprentissage de la robotique.', 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png'),
  LiveProduct('Sac à dos design', 'Design – MMI', 25000, 'Fotso Brice',
      'Sac à dos en toile recyclée, dessiné et cousu par les étudiants.', 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png'),
  LiveProduct('Pots connectés', 'Agronomie', 15000, 'Ngono Aminata',
      'Pots de plantes connectés avec capteur d’humidité.', 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png'),
  LiveProduct('Support téléphone', 'Génie industriel', 8000, 'Biyick Éric',
      'Support de téléphone imprimé en 3D, plusieurs coloris.', 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png'),
  LiveProduct('Tableau décoratif', 'Arts – Génie civil', 18000, 'Mouanga Yannick',
      'Tableau décoratif peint à la main.', 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png'),
];

LiveProduct productByTitle(String t) => liveCatalog.firstWhere((p) => p.title == t, orElse: () => liveCatalog.first);

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
  return Totals(n, sub, lines.isEmpty ? 0 : (home ? 5000 : 0));
});

class Order {
  const Order({required this.id, required this.date, required this.lines, required this.subtotal, required this.fee, required this.method, required this.reference, this.status = 0, this.paid = false});
  final String id, date, method, reference;
  final List<CartLine> lines;
  final int subtotal, fee;
  final int status; // 0 confirmée · 1 en préparation · 2 expédiée · 3 livrée
  final bool paid;
  int get total => subtotal + fee;

  Order copyWith({int? status, bool? paid}) => Order(
        id: id, date: date, lines: lines, subtotal: subtotal, fee: fee, method: method, reference: reference,
        status: status ?? this.status, paid: paid ?? this.paid,
      );
}

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

class Orders extends Notifier<List<Order>> {
  int _n = 142;
  @override
  List<Order> build() => const [];

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

  void markPaid(String id) => state = [for (final o in state) o.id == id ? o.copyWith(paid: true) : o];
  void advance(String id) => state = [for (final o in state) o.id == id ? o.copyWith(status: (o.status + 1).clamp(0, 3)) : o];
}

final ordersProvider = NotifierProvider<Orders, List<Order>>(Orders.new);

/// Dernière commande passée (ou une commande d'exemple si aucune).
final lastOrderProvider = Provider<Order>((ref) {
  final l = ref.watch(ordersProvider);
  if (l.isNotEmpty) return l.first;
  final lines = ref.watch(cartProvider);
  final t = ref.watch(totalsProvider);
  return Order(id: '#BE-2026-0142', date: '22 oct. 2026', lines: lines, subtotal: t.subtotal, fee: t.fee, method: 'Orange Money', reference: 'OM-7F3A-2210');
});

String statusLabel(int s) => const ['Confirmée', 'En préparation', 'Expédiée', 'Livrée'][s.clamp(0, 3)];
