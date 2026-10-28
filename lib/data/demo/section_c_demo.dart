import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_demo.dart';

/// Carte produit de grille (22, 22c, 22d, 24) : la pastille de département est sous la photo.
class CTile {
  const CTile(this.title, this.price, this.department, this.image, {this.rating, this.reviews});

  final String title;
  final int price;
  final String department;
  final String image;
  final String? rating;
  final int? reviews;
}

/// Ligne de liste générique : vignette, titre, détail.
class CRow {
  const CRow(this.title, this.detail, this.image, {this.badge});

  final String title;
  final String detail;
  final String image;
  final String? badge;
}

/// Commande de l'historique client (28).
class COrder {
  const COrder(this.ref, this.date, this.amount, this.status, this.image);

  final String ref;
  final String date;
  final int amount;

  /// livree, en_cours, annulee
  final String status;
  final String image;
}

/// Avis client (31).
class CReview {
  const CReview(this.author, this.date, this.score, this.text, this.avatar, {this.photos = const []});

  final String author;
  final String date;
  final String score;
  final String text;
  final String avatar;
  final List<String> photos;
}

/// Données de démonstration de la section C (21–31). Chiffres fictifs repris des maquettes.
class SectionCData {
  const SectionCData();

  // 21 · Recherche avancée
  final searchTabs = const ['Produits', 'Services', 'Talents', 'Projets'];
  final departments = const ['Tous les départements', 'Génie informatique', 'Génie civil', 'Génie électrique', 'MMI', 'Agronomie'];
  final budgets = const ['0 – 500 000 FCFA', '0 – 25 000 FCFA', '25 000 – 100 000 FCFA', '100 000 FCFA et plus'];
  final categories = const ['Toutes les catégories', 'Maison et déco', 'Mode', 'Tech', 'Art', 'Alimentation'];
  final recentSearches = const ['lampe recyclée', 'développeur web', 'drone éducatif'];

  // 22 · Catalogue de produits
  final catalogFilters = const ['Tous', 'Maison', 'Mode', 'Tech', 'Art', 'Alimentation'];
  final catalogCount = 128;
  final catalog = const [
    CTile('Lampe en bois recyclé', 25000, 'Génie civil', Photos.lamp),
    CTile('Drone éducatif', 150000, 'Génie électrique', Photos.bulb),
    CTile('Sac à dos design', 25000, 'Design – MMI', Photos.paint),
    CTile('Pots connectés', 15000, 'Agronomie', Photos.paintRed),
    CTile('Support téléphone', 8000, 'Génie industriel', Photos.branding),
    CTile('Tableau décoratif', 18000, 'Arts – Génie civil', Photos.sketch),
  ];

  /// Rubrique de chaque produit du catalogue (filtres de 22).
  final catalogRubrics = const ['Maison', 'Tech', 'Mode', 'Maison', 'Tech', 'Art'];

  // 22b · Services et prestations
  final serviceFilters = const ['Tous', 'Design', 'Développement', 'Tutorat', 'Photo et vidéo'];
  final serviceCount = 46;
  final services = const [
    CRow('Développement web sur mesure', 'À partir de 30 000 FCFA · 4.9 ★', Photos.lamp, badge: 'Développement'),
    CRow('Logo et identité visuelle', 'À partir de 15 000 FCFA · 4.8 ★', Photos.bulb, badge: 'Design'),
    CRow('Montage vidéo et création', 'À partir de 10 000 FCFA · 4.7 ★', Photos.paint, badge: 'Photo et vidéo'),
    CRow('Cours de soutien en maths', 'À partir de 5 000 FCFA · 5.0 ★', Photos.paintRed, badge: 'Tutorat'),
    CRow('Application mobile', 'À partir de 50 000 FCFA · 4.8 ★', Photos.branding, badge: 'Développement'),
  ];
  final customServiceImage = 'assets/images/c_ordinateur.jpg';

  // 22c · Tendances et nouveautés
  final trendTabs = const ['Tendances', 'Nouveautés', 'Sélection IUT'];
  final trendHero = 'assets/images/c_bibliotheque.jpg';
  final trending = const [
    CTile('Lampe en bois recyclé', 25000, 'Génie civil', 'assets/images/e_masques.jpg'),
    CTile('Drone éducatif', 150000, 'Génie électrique', 'assets/images/e_marche_artisanal.jpg'),
    CTile('Sac à dos design', 25000, 'Design – MMI', Photos.lamp),
    CTile('Tableau décoratif', 18000, 'Arts', Photos.bulb),
  ];
  final newArrivals = const [
    CRow('Support téléphone en bois', 'Ajouté aujourd’hui · 8 000 FCFA', Photos.bagDesign),
    CRow('Pots connectés', 'Ajouté hier · 15 000 FCFA', Photos.droneLogo),
  ];

  // 22d · Pour vous
  final recommended = const [
    CTile('Lampe de bureau recyclée', 22000, 'Génie civil', 'assets/images/c_drone.jpg'),
    CTile('Sac à dos design', 25000, 'Design – MMI', 'assets/images/c_sacs.jpg'),
    CTile('Drone éducatif', 150000, 'Génie électrique', 'assets/images/c_portable.jpg'),
    CTile('Support ordinateur', 12000, 'Génie industriel', 'assets/images/c_portable_2.jpg'),
  ];
  final suggestedTalents = const [
    CRow('Aminata Bello', 'MMI · UI/UX, Branding', 'assets/images/c_avatar_aminata.jpg'),
    CRow('Brice Ndoumbe', 'Électronique · IoT', 'assets/images/c_avatar_brice.jpg'),
  ];

  // 23 · Filtres
  final offerTypes = const ['Tous', 'Produits', 'Services', 'Talents', 'Projets', 'Innovations'];
  final maxPrice = 500000;
  final defaultPriceMax = 250000;
  final availability = const ['En stock', 'Sur commande', 'Disponible bientôt'];

  // 24 · Profil vendeur
  final shopName = 'Atelier Krea’Tech';
  final shopSubtitle = 'Étudiant · Génie informatique · IUT Douala';
  final shopCover = 'assets/images/c_remise_diplomes.jpg';
  final shopAvatar = 'assets/images/c_avatar_atelier.jpg';
  final shopCounters = const [('12', 'Produits'), ('3', 'Services'), ('5', 'Projets')];
  final shopTabs = const ['Produits', 'Services', 'Projets', 'À propos'];
  final shopProducts = const [
    CTile('Lampe en bois recyclé', 25000, '', 'assets/images/c_portable.jpg', rating: '4.8', reviews: 24),
    CTile('Support téléphone', 8000, '', 'assets/images/c_portable_2.jpg', rating: '4.7', reviews: 18),
  ];

  // 25 · Mes favoris
  final favoriteTabs = const ['Tous', 'Produits', 'Services', 'Talents', 'Projets'];
  final favorites = const [
    CTile('Sac à dos design', 25000, 'Design – MMI', 'assets/images/c_fav_plantes.jpg'),
    CTile('Logo & identité visuelle', 15000, 'Graphisme – TCO', 'assets/images/c_fav_plante.jpg'),
    CTile('Cours de soutien en maths', 10000, 'Tutorat – Info', 'assets/images/c_fav_support.jpg'),
    CTile('Drone éducatif', 150000, 'Électronique – GE', 'assets/images/c_fav_peinture.jpg'),
  ];

  /// Rubrique de chaque favori (filtres de 25).
  final favoriteRubrics = const ['Produits', 'Services', 'Services', 'Produits'];

  // 25b · Mes collections
  final collections = const [
    CRow('Maison et déco', '12 articles · Privée', Photos.lamp),
    CRow('Cadeaux d’anniversaire', '5 articles · Partagée', Photos.bulb),
    CRow('Équipement informatique', '8 articles · Privée', Photos.bagDesign),
    CRow('Projets à suivre', '3 projets · Publique', Photos.droneLogo),
  ];

  // 26 · Comparer des offres
  final compareLeft = const CTile('Sac à dos design', 25000, 'Design – MMI', Photos.paintRed);
  final compareRight = const CTile('Sac urbain', 32000, 'Design – MMI', Photos.branding);
  final compareRows = const [
    ('Matériau', 'Tissu recyclé', 'Cuir synthétique'),
    ('Capacité', '20 L', '25 L'),
    ('Garantie', '6 mois', '1 an'),
    ('Livraison', '2–5 jours', '2–5 jours'),
  ];
  final compareColorsLeft = const [0xFF2E8B6E, 0xFF15141A, 0xFFE8553F];
  final compareColorsRight = const [0xFFB044C9, 0xFF3D7BE0];

  // 27 · Mes adresses
  final defaultAddress = const ('IUT de Douala, Quartier Ndokoti', 'Douala, Cameroun');
  final addresses = const [('Maison', 'Bonapriso, Douala', 'Cameroun', true), ('Bureau', 'Akwa, Douala', 'Cameroun', false)];

  // 28 · Mes commandes
  final orderTabs = const ['Toutes', 'En cours', 'Livrées', 'Annulées'];
  final orders = const [
    COrder('#BE-2026-0142', '22 oct. 2026', 32500, 'livree', Photos.sketch),
    COrder('#BE-2026-0138', '18 oct. 2026', 17000, 'en_cours', 'assets/images/e_masques.jpg'),
    COrder('#BE-2026-0127', '12 oct. 2026', 45000, 'livree', 'assets/images/e_marche_artisanal.jpg'),
    COrder('#BE-2026-0119', '05 oct. 2026', 28000, 'annulee', Photos.lamp),
  ];

  // 29 · Détail de la commande
  final detailRef = '#BE-2026-0142';
  final detailDate = '22 oct. 2026';
  final detailSteps = const ['Confirmée', 'Préparée', 'Expédiée', 'Livrée'];
  final detailItem = const CTile('Sac à dos design', 25000, '', Photos.bulb);
  final detailQty = 1;
  final detailShipping = 7500;
  final detailAddress = const ('IUT de Douala, Quartier Ndokoti', 'Douala, Cameroun');

  // 31 · Avis et évaluations
  final ratingAverage = '4.8';
  final ratingCount = 24;
  final ratingDistribution = const [(5, 75), (4, 15), (3, 7), (2, 3), (1, 0)];
  final reviews = const [
    CReview(
      'Aminata B.',
      '20 oct. 2026',
      '5.0',
      'Produit de très bonne qualité ! Le design est vraiment original et bien fini.',
      'assets/images/c_avatar_aminata_2.jpg',
      photos: [Photos.bagDesign, Photos.droneLogo],
    ),
    CReview(
      'Kouassi T.',
      '15 oct. 2026',
      '4.0',
      'Très beau produit, mais la livraison a pris un peu plus de temps que prévu.',
      'assets/images/c_avatar_kouassi.jpg',
    ),
  ];
}

final sectionCDataProvider = Provider<SectionCData>((_) => const SectionCData());
