import '../models/models.dart';

/// Photos extraites des maquettes (assets/images).
abstract final class Photos {
  static const coder = 'assets/images/coder.jpg';
  static const solar = 'assets/images/solar.jpg';
  static const builder = 'assets/images/builder.jpg';
  static const studentHijab = 'assets/images/student_hijab.jpg';
  static const lamp = 'assets/images/lamp.jpg';
  static const bulb = 'assets/images/bulb.jpg';
  static const bissap = 'assets/images/bissap.jpg';
  static const phone = 'assets/images/phone.jpg';
  static const maquette = 'assets/images/maquette.jpg';
  static const technician = 'assets/images/technician.jpg';
  static const office = 'assets/images/office.jpg';
  static const mapCameroon = 'assets/images/map_cameroon.png';
  static const avatarWoman = 'assets/images/avatar_woman.jpg';
}

/// Catalogue de démonstration (chiffres fictifs des maquettes).
const demoProducts = <Product>[
  Product(id: 'p1', title: 'Lampe en bois recyclé', price: 25000, seller: 'Ngoné M.', department: 'Génie civil', image: Photos.coder),
  Product(id: 'p2', title: 'Tote bag sérigraphié', price: 8000, seller: 'Yannick M.', department: 'MMI', image: Photos.solar, type: ListingType.service),
  Product(id: 'p3', title: 'Site vitrine boulangerie', price: 150000, seller: 'Carine M.', department: 'MMI', image: Photos.builder, status: ListingStatus.inReview),
  Product(id: 'p4', title: 'Chaise ergonomique', price: 45000, seller: 'Mariam E.', department: 'MMI', image: Photos.studentHijab, status: ListingStatus.draft),
  Product(id: 'p5', title: 'Pack identité visuelle', price: 90000, seller: 'Aminata B.', department: 'MMI', image: Photos.coder, type: ListingType.service),
  Product(id: 'p6', title: 'Panneau solaire V1', price: 120000, seller: 'Brice N.', department: 'MMI', image: Photos.solar, status: ListingStatus.inReview),
  Product(id: 'p7', title: 'Lampe de bureau LED', price: 35000, seller: 'Brice N.', department: 'MMI', image: Photos.coder),
  Product(id: 'p8', title: 'Maquette immeuble R+2', price: 60000, seller: 'Yannick M.', department: 'MMI', image: Photos.solar, status: ListingStatus.draft, type: ListingType.service),
  Product(id: 'p9', title: 'Application de gestion de stock', price: 200000, seller: 'Mariam E.', department: 'MMI', image: Photos.builder, status: ListingStatus.inReview),
];

const demoTalents = <Talent>[
  Talent('Mariam Essono', 'GI · Développement web', Photos.coder, 96),
  Talent('Aminata Bello', 'MMI · Identité visuelle', Photos.phone, 96),
  Talent('Brice Ndoumbe', 'GEII · IoT et énergie', Photos.solar, 96),
];
