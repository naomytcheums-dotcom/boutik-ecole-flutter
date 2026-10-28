import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Article présenté sur la borne (206–210).
typedef KioskProduct = ({
  String id,
  String name,
  String category,
  String kind,
  int price,
  String image,
  bool boosted,
  String rating,
  int reviews,
  List<String> gallery,
  String seller,
  String sellerField,
  String sellerAvatar,
  String workshop,
});

/// Données de démonstration de la borne phygitale (section AA).
class SectionAAData {
  const SectionAAData();

  static const _lamp = 'assets/images/aa_betonniere.jpg';

  final products = const <KioskProduct>[
    (
      id: 'lampe-0142',
      name: 'Lampe en bois recyclé',
      category: 'Génie civil',
      kind: 'Produits',
      price: 25000,
      image: _lamp,
      boosted: true,
      rating: '4,8',
      reviews: 12,
      gallery: [_lamp, 'assets/images/technician.jpg', 'assets/images/maquette.jpg', 'assets/images/bissap.jpg'],
      seller: 'Yannick M.',
      sellerField: 'Génie civil',
      sellerAvatar: 'assets/images/student_hijab.jpg',
      workshop: 'Atelier Génie civil · IUT de Douala',
    ),
    (
      id: 'bissap-0087',
      name: 'Jus de bissap',
      category: 'BTA',
      kind: 'Produits',
      price: 1500,
      image: 'assets/images/bissap.jpg',
      boosted: false,
      rating: '4,9',
      reviews: 31,
      gallery: ['assets/images/bissap.jpg'],
      seller: 'Équipe BTA',
      sellerField: 'Agroalimentaire',
      sellerAvatar: 'assets/images/t_av_aminata.jpg',
      workshop: 'Atelier BTA · IUT de Douala',
    ),
    (
      id: 'kit-solaire-0031',
      name: 'Kit solaire portable',
      category: 'Énergies',
      kind: 'Produits',
      price: 18000,
      image: 'assets/images/solar.jpg',
      boosted: false,
      rating: '4,7',
      reviews: 9,
      gallery: ['assets/images/solar.jpg'],
      seller: 'Brice N.',
      sellerField: 'Énergies renouvelables',
      sellerAvatar: 'assets/images/t_av_brice.jpg',
      workshop: 'Atelier ENR · IUT de Douala',
    ),
    (
      id: 'support-tablette-0019',
      name: 'Support de tablette',
      category: 'Informatique',
      kind: 'Produits',
      price: 6000,
      image: 'assets/images/coder.jpg',
      boosted: false,
      rating: '4,6',
      reviews: 7,
      gallery: ['assets/images/coder.jpg'],
      seller: 'Kouassi T.',
      sellerField: 'Génie informatique',
      sellerAvatar: 'assets/images/t_av_kouassi.jpg',
      workshop: 'Atelier GI · IUT de Douala',
    ),
  ];

  // 209 · QR de session : 5 minutes de validité, jeton émis par le serveur (voir BACKEND_PLAN.md).
  final qrValiditySeconds = 300;
  final qrSecondsLeft = 299;
  final qrBaseUrl = 'HTTPS://BE.CM/K/';
  final kioskId = 'BORNE-GC-01';
  final sessionToken = 'GC01-7F3A';

  // 210 · Reçu.
  final receiptDate = '27 oct. 2026';
  final receiptTime = '10:42';
  final receiptPickup = 'Atelier GC';
  final trackingCode = 'BE-2210-7F3A';
  final returnSeconds = 15;
}

final sectionAADataProvider = Provider<SectionAAData>((_) => const SectionAAData());

/// Article choisi sur la borne (207 → 208 → 209 → 210).
class KioskSelection extends Notifier<String> {
  @override
  String build() => ref.read(sectionAADataProvider).products.first.id;

  void select(String id) => state = id;
}

final kioskSelectionProvider = NotifierProvider<KioskSelection, String>(KioskSelection.new);

final kioskProductProvider = Provider<KioskProduct>((ref) {
  final id = ref.watch(kioskSelectionProvider);
  final products = ref.watch(sectionAADataProvider).products;
  return products.firstWhere((p) => p.id == id, orElse: () => products.first);
});
