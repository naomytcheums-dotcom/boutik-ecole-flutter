import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Indicateur chiffré d'une carte KPI (57, 62, 66, 67).
class GKpi {
  const GKpi(this.label, this.value, this.icon, {this.delta, this.deltaTone = Tone.success});

  final String label;
  final String value;
  final String icon;
  final String? delta;
  final Tone deltaTone;
}

/// Barre d'un histogramme : libellé de l'axe et valeur en FCFA.
class GBar {
  const GBar(this.label, this.value);

  final String label;
  final int value;
}

/// Statut d'une commande reçue par le vendeur.
enum GOrderStatus { toPrepare, newOrder, inProgress, ready, delivered }

/// Commande reçue (57, 63, 64, 65).
class GOrder {
  const GOrder({
    required this.ref,
    required this.product,
    required this.buyer,
    required this.amount,
    required this.status,
    required this.image,
    this.mode = 'Retrait demain',
  });

  final String ref;
  final String product;
  final String buyer;
  final int amount;
  final GOrderStatus status;
  final String image;

  /// Mode de remise affiché sur le tableau de bord (« Retrait demain », « Livraison »).
  final String mode;
}

/// Statut d'une annonce du catalogue (61).
enum GListingStatus { published, lowStock, outOfStock, draft }

/// Annonce du catalogue vendeur (61).
class GListing {
  const GListing(this.title, this.price, this.stock, this.status, this.image);

  final String title;
  final int price;
  final int stock;
  final GListingStatus status;
  final String image;
}

/// Article à surveiller (62).
class GStockItem {
  const GStockItem(this.title, this.threshold, this.remaining, this.image);

  final String title;
  final int threshold;
  final int remaining;
  final String image;
}

/// Étape d'un historique (65) : titre et détail.
class GStep {
  const GStep(this.title, [this.detail]);

  final String title;
  final String? detail;
}

/// Relevé mensuel téléchargeable (66).
class GStatement {
  const GStatement(this.title, this.transactions);

  final String title;
  final int transactions;
}

/// Annonce la plus performante (67) : part en pourcentage et couleur de la jauge (ARGB).
class GPerformer {
  const GPerformer(this.title, this.percent, this.color);

  final String title;
  final int percent;
  final int color;
}

/// Statistiques d'une période (67).
class GStatsPeriod {
  const GStatsPeriod({required this.label, required this.kpis, required this.bars});

  final String label;
  final List<GKpi> kpis;
  final List<GBar> bars;
}

/// Justificatif du dossier vendeur (69).
class GDocument {
  const GDocument(this.title, this.detail, this.icon, this.status, this.tone, {this.target});

  final String title;
  final String detail;
  final String icon;
  final String status;
  final Tone tone;

  /// Écran ouvert pour compléter ou corriger le justificatif.
  final String? target;
}

/// Données de démonstration de la section G (57–69). Chiffres fictifs repris des maquettes.
class SectionGData {
  const SectionGData();

  final sellerName = 'Mariam';

  // 57 · Tableau de bord
  final dashboardKpis = const [
    GKpi('Ventes du mois', '1 245 000', AppIcons.trendingUp, delta: '+12 % vs sept.'),
    GKpi('Commandes', '38', AppIcons.receipt, delta: '+5 cette semaine'),
    GKpi('Revenu attendu', '320 000', AppIcons.wallet, delta: '4 paiements en attente', deltaTone: Tone.warning),
    GKpi('Annonces actives', '14', AppIcons.tag, delta: '2 en validation', deltaTone: Tone.warning),
  ];
  final monthlySalesPeriod = '7 mois';
  final monthlySales = const [
    GBar('Avr', 420000),
    GBar('Mai', 510000),
    GBar('Juin', 480000),
    GBar('Juil', 700000),
    GBar('Août', 830000),
    GBar('Sept', 1010000),
    GBar('Oct', 1245000),
  ];

  /// Commandes à préparer du tableau de bord (vignettes de la maquette 57).
  final dashboardOrders = const [
    GOrder(
      ref: '#BE-2026-0142',
      product: 'Lampe recyclée',
      buyer: 'Yannick M.',
      amount: 25000,
      status: GOrderStatus.toPrepare,
      image: Photos.lamp,
    ),
    GOrder(
      ref: '#BE-2026-0141',
      product: 'Sac à dos design',
      buyer: 'Aminata B.',
      amount: 25000,
      status: GOrderStatus.newOrder,
      image: Photos.bulb,
      mode: 'Livraison',
    ),
  ];

  // 58 · Nouveau produit
  final productSteps = const ['Infos', 'Photos', 'Prix', 'Publication'];
  final productCategories = const [
    'Maison et déco',
    'Mode et accessoires',
    'Électronique',
    'Art et artisanat',
    'Alimentation',
    'Fournitures',
  ];
  final productCategory = 'Maison et déco';
  final productPrice = '25 000';
  final productStock = '15';
  final maxPhotos = 6;

  // 59 · Nouveau service
  final serviceSteps = const ['Infos', 'Formules', 'Modalités', 'Publication'];
  final serviceCategories = const [
    'Développement',
    'Design graphique',
    'Cours et soutien',
    'Rédaction et traduction',
    'Maintenance informatique',
    'Photo et vidéo',
  ];
  final serviceCategory = 'Développement';
  final servicePrice = '30 000';
  final serviceDelays = const ['Moins de 48 h', '3 à 7 jours', '1 à 2 semaines', 'Plus de 2 semaines'];
  final serviceDelay = '3 à 7 jours';
  final serviceModes = const ['À distance ou sur campus', 'À distance uniquement', 'Sur campus uniquement'];
  final serviceMode = 'À distance ou sur campus';

  // 60 · Modifier l’annonce (aperçu)
  final previewTitle = 'Lampe en bois recyclé';
  final previewPrice = 25000;
  final previewImage = 'assets/images/g_atelier_code.jpg';
  final previewTags = const ['Écologique', 'Fait main', 'LED', 'Bois recyclé'];
  final previewDescription =
      'Lampe décorative fabriquée à partir de bois recyclé. Écologique, design et idéale pour un intérieur moderne.';
  final previewStock = 15;
  final pickupPoint = 'Kiosque IUT – Bloc A';
  final previewStatus = 'Brouillon';

  // 61 · Mon catalogue
  final catalogTotal = 14;
  final catalog = const [
    GListing('Lampe en bois recyclé', 25000, 12, GListingStatus.published, Photos.paintRed),
    GListing('Sac à dos design', 25000, 8, GListingStatus.published, Photos.branding),
    GListing('Support téléphone', 8000, 3, GListingStatus.lowStock, Photos.sketch),
    GListing('Tableau décoratif', 18000, 0, GListingStatus.outOfStock, 'assets/images/e_masques.jpg'),
    GListing('Pots connectés', 15000, 0, GListingStatus.draft, 'assets/images/e_marche_artisanal.jpg'),
  ];

  // 62 · Stocks
  final stockKpis = const [
    GKpi('En stock', '128 unités', AppIcons.package2),
    GKpi('Stock bas', '5 articles', AppIcons.triangleAlert),
    GKpi('Ruptures', '2 articles', AppIcons.x),
    GKpi('Réassort prévu', '3 articles', AppIcons.truck),
  ];
  final watchedStock = const [
    GStockItem('Support téléphone', 5, 3, Photos.lamp),
    GStockItem('Tableau décoratif', 2, 0, Photos.bulb),
    GStockItem('Lampe en bois recyclé', 5, 12, Photos.bagDesign),
  ];
  final defaultThreshold = 5;

  // 63 · Commandes reçues
  final receivedOrders = const [
    GOrder(
      ref: '#BE-2026-0142',
      product: 'Lampe recyclée',
      buyer: 'Yannick M.',
      amount: 25000,
      status: GOrderStatus.toPrepare,
      image: Photos.droneLogo,
    ),
    GOrder(
      ref: '#BE-2026-0141',
      product: 'Sac à dos design',
      buyer: 'Aminata B.',
      amount: 25000,
      status: GOrderStatus.newOrder,
      image: Photos.drone,
    ),
    GOrder(
      ref: '#BE-2026-0139',
      product: 'Support téléphone',
      buyer: 'Brice N.',
      amount: 8000,
      status: GOrderStatus.toPrepare,
      image: Photos.backpacks,
    ),
    GOrder(
      ref: '#BE-2026-0137',
      product: 'Pots connectés',
      buyer: 'Kouassi T.',
      amount: 15000,
      status: GOrderStatus.inProgress,
      image: 'assets/images/g_laptop_bureau.jpg',
    ),
    GOrder(
      ref: '#BE-2026-0133',
      product: 'Tableau décoratif',
      buyer: 'Clarisse E.',
      amount: 18000,
      status: GOrderStatus.ready,
      image: 'assets/images/e_masques.jpg',
    ),
    GOrder(
      ref: '#BE-2026-0128',
      product: 'Lampe en bois recyclé',
      buyer: 'Paul D.',
      amount: 25000,
      status: GOrderStatus.delivered,
      image: Photos.paintRed,
    ),
  ];
  final orderTabs = const ['À préparer', 'En cours', 'Prêtes', 'Livrées'];
  final prepareDeadline = 'demain 14 h';

  // 64 · Préparer une commande
  final prepareSteps = const ['Reçue', 'Préparation', 'Prête', 'Remise'];
  final prepareProduct = 'Lampe en bois recyclé';
  final prepareDetail = 'Qté : 1 · Chêne naturel';
  final prepareImage = Photos.bagDesign;
  final checklist = const [
    'Article conforme à l’annonce',
    'Emballage soigné et protégé',
    'Photo de l’article ajoutée',
    'Étiquette de retrait imprimée',
  ];
  final checklistDone = const [true, true, false, false];
  final handoverDeadline = 'Demain · 14 h';

  // 65 · Détail d’une vente
  final saleRef = '#BE-2026-0142';
  final saleProduct = 'Lampe en bois recyclé';
  final saleQty = 1;
  final saleAmount = 25000;
  final saleImage = Photos.laptopMeeting;
  final saleBuyer = 'Yannick Mouanga';
  final saleDate = '22 oct. 2026';
  final commissionPercent = 5;
  final saleHistory = const [
    GStep('Commande reçue', '22 oct. · 08:10'),
    GStep('Paiement confirmé', '22 oct. · 08:12'),
    GStep('Préparation', 'En cours'),
    GStep('Remise au point de retrait'),
  ];
  final saleCurrentStep = 2;

  // 66 · Revenus
  final availableRevenue = 845000;
  final pendingRevenue = 320000;
  final pendingPayments = 4;
  final revenuePeriod = '6 mois';

  /// Revenus cumulés (FCFA), un point par mois.
  final cumulativeRevenue = const [43000, 183000, 259000, 383000, 507000, 723000, 1165000];
  final statements = const [
    GStatement('Relevé octobre 2026', 12),
    GStatement('Relevé septembre 2026', 18),
    GStatement('Relevé août 2026', 9),
  ];

  // 67 · Statistiques
  final statsPeriods = const [
    GStatsPeriod(
      label: '7 jours',
      kpis: [
        GKpi('Vues des annonces', '1 120', AppIcons.eye, delta: '+9 %'),
        GKpi('Taux de conversion', '3,1 %', AppIcons.percent, delta: '+0,2 pt'),
      ],
      bars: [
        GBar('L', 32000),
        GBar('M', 48000),
        GBar('M', 25000),
        GBar('J', 57000),
        GBar('V', 66000),
        GBar('S', 81000),
        GBar('D', 40000),
      ],
    ),
    GStatsPeriod(
      label: '30 jours',
      kpis: [
        GKpi('Vues des annonces', '4 280', AppIcons.eye, delta: '+18 %'),
        GKpi('Taux de conversion', '3,4 %', AppIcons.percent, delta: '+0,6 pt'),
      ],
      bars: [
        GBar('S1', 148000),
        GBar('S2', 224000),
        GBar('S3', 166000),
        GBar('S4', 279000),
        GBar('S5', 334000),
        GBar('S6', 410000),
      ],
    ),
    GStatsPeriod(
      label: '12 mois',
      kpis: [
        GKpi('Vues des annonces', '38 950', AppIcons.eye, delta: '+42 %'),
        GKpi('Taux de conversion', '2,9 %', AppIcons.percent, delta: '+0,4 pt'),
      ],
      bars: [
        GBar('N', 210000),
        GBar('D', 340000),
        GBar('J', 180000),
        GBar('F', 260000),
        GBar('M', 300000),
        GBar('A', 420000),
        GBar('M', 510000),
        GBar('J', 480000),
        GBar('J', 700000),
        GBar('A', 830000),
        GBar('S', 1010000),
        GBar('O', 1245000),
      ],
    ),
  ];
  final statsDefaultPeriod = 1;
  final performers = const [
    GPerformer('Lampe en bois recyclé', 82, 0xFF6A4DFF),
    GPerformer('Sac à dos design', 64, 0xFF1E4A80),
    GPerformer('Support téléphone', 41, 0xFF1F9D6B),
  ];

  // 69 · Validations
  final compliancePercent = 85;

  /// Compteur affiché par la maquette (« 3 justificatifs sur 4 validés »), cf. docs/questions/G.md.
  final validatedDocuments = 3;
  final documents = const [
    GDocument('Identité', 'Validée le 12 oct. 2026', AppIcons.user, 'Validé', Tone.success),
    GDocument('Matricule étudiant', 'IUT-2023-0412', AppIcons.graduationCap, 'Validé', Tone.success),
    GDocument(
      'Certificat de scolarité',
      'En cours d’examen',
      AppIcons.file,
      'En attente',
      Tone.warning,
      target: '18c',
    ),
    GDocument(
      'Moyen de paiement',
      'Numéro Mobile Money à corriger',
      AppIcons.wallet,
      'À corriger',
      Tone.error,
      target: '18b',
    ),
  ];
}

final sectionGDataProvider = Provider<SectionGData>((_) => const SectionGData());
