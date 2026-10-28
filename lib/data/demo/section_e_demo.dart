import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_demo.dart';

/// Statut d'une commande client (écrans 45 à 48).
enum EOrderStatus { delivered, inProgress, preparing, inTransit, cancelled }

/// Commande de la liste « Mes commandes » (45).
class EOrder {
  const EOrder(this.ref, this.date, this.amount, this.status, this.image, {this.dateOrder = 0});

  final String ref;
  final String date;
  final int amount;
  final EOrderStatus status;
  final String image;

  /// Clé de tri chronologique (plus grand = plus récent).
  final int dateOrder;
}

/// Article du récapitulatif (42).
class ESummaryLine {
  const ESummaryLine(this.title, this.price, this.image, {this.qty = 1});

  final String title;
  final int price;
  final String image;
  final int qty;
}

/// Étape d'un suivi (43, 46) : titre et détail.
class ETrackStep {
  const ETrackStep(this.title, this.detail);

  final String title;
  final String detail;
}

/// Données de démonstration de la section E (41–49). Chiffres fictifs repris des maquettes.
class SectionEData {
  const SectionEData();

  // Parcours d'achat (41, 42)
  final checkoutSteps = const ['Panier', 'Livraison', 'Paiement', 'Confirmation'];

  // 41 · Adresse de livraison
  final recipient = 'Mariam Essono';
  final phoneMask = '+237 6 XX XX XX XX';
  final cities = const [
    'Douala · Ndokoti',
    'Douala · Akwa',
    'Douala · Bonamoussadi',
    'Douala · Logbessou',
    'Douala · PK 17',
    'Yaoundé · Centre',
  ];
  final city = 'Douala · Ndokoti';
  final address = 'Rue de l’IUT, face au Bloc A';
  final landmark = 'Près de la bibliothèque';

  // 42 · Récapitulatif
  final summaryLines = const [
    ESummaryLine('Ordinateur portable prototype', 250000, Photos.branding),
    ESummaryLine('Lampe en bois recyclé', 25000, Photos.sketch),
    ESummaryLine('Logo et identité visuelle', 50000, 'assets/images/e_masques.jpg'),
  ];
  final pickupTitle = 'Retrait sur campus';
  final pickupDetail = 'IUT de Douala – Bâtiment principal';
  final paymentTitle = 'Orange Money';
  final paymentDetail = 'Compte IUT DFI';
  final deliveryFee = 5000;

  // 43 · Instructions de paiement
  final paymentMethod = 'Orange Money';
  final merchantNumber = '6 9X XX XX XX';
  final reference = 'BE-2026-0142';
  final paymentSteps = const [
    ETrackStep('Ouvrez Orange Money', 'Menu « Paiement marchand »'),
    ETrackStep('Saisissez le numéro marchand', 'Puis le montant exact'),
    ETrackStep('Indiquez la référence', 'BE-2026-0142 dans le motif'),
  ];
  final paymentCurrentStep = 1;
  final paymentCheckDelay =
      'Après le paiement, déclarez-le ici. Il est vérifié sous 24 h et votre commande est confirmée.';

  // 44 · Commande confirmée
  final orderDate = '22 oct. 2026';
  final pickupPoint = 'Kiosque IUT – Bloc A';

  // 45 · Mes commandes
  final ordersCount = 12;
  final orderFilters = const ['Toutes', 'En cours', 'Livrées', 'Annulées'];
  final orders = const [
    EOrder('#BE-2026-0142', '22 oct. 2026', 32500, EOrderStatus.delivered, Photos.bagDesign, dateOrder: 1022),
    EOrder(
      '#BE-2026-0138',
      '18 oct. 2026',
      17000,
      EOrderStatus.inProgress,
      'assets/images/e_marche_artisanal.jpg',
      dateOrder: 1018,
    ),
    EOrder('#BE-2026-0127', '12 oct. 2026', 45000, EOrderStatus.delivered, Photos.lamp, dateOrder: 1012),
    EOrder('#BE-2026-0119', '05 oct. 2026', 28000, EOrderStatus.cancelled, Photos.backpacks, dateOrder: 1005),
  ];

  // 46 · Suivi de livraison
  final trackingRef = '#BE-2026-0142';
  final trackingEta = 'Arrivée prévue demain · 14 h';
  final trackingMap = 'assets/images/e_carte_trajet.png';
  final departure = 'Douala · Littoral';
  final arrival = 'Yaoundé · Centre';
  final distanceLeft = '235 km · 4 h 30 restantes';
  final trackingSteps = const [
    ETrackStep('Commande confirmée', '22 oct. · 08:12'),
    ETrackStep('Remise au transporteur', '23 oct. · 10:24'),
    ETrackStep('En route vers le kiosque', 'En cours'),
    ETrackStep('Prête au retrait · Bloc A', 'Demain · 14 h'),
  ];
  final trackingCurrentStep = 2;
  final pickupCode = '482 915';

  // 47 · Annuler la commande
  final cancelRef = '#BE-2026-0141';
  final cancelProduct = 'Sac à dos design';
  final cancelAmount = 25000;
  final cancelImage = Photos.lamp;
  final cancelReasons = const [
    'Je me suis trompé de produit',
    'Délai de livraison trop long',
    'J’ai trouvé une meilleure offre',
    'Autre raison',
  ];
  final refundDelay = '3 à 5 jours ouvrés';
  final refundMode = 'Mobile Money';

  // 48 · Réclamation
  final claimRef = '#BE-2026-0138';
  final claimDate = '18 oct. 2026';
  final claimAmount = 17000;
  final claimImage = 'assets/images/e_marche_artisanal.jpg';
  final claimReasons = const [
    'Article non reçu',
    'Article endommagé ou non conforme',
    'Annulation avant préparation',
    'Demande de remboursement',
  ];
  final claimMaxPhotos = 3;
  final claimDelay = 'Notre équipe vous répond sous 48 h ouvrées.';

  // 49 · Aide et support
  final helpTopics = const [
    ('Commandes et livraisons', 'assets/icons/package-2.svg'),
    ('Paiements et remboursements', 'assets/icons/wallet.svg'),
    ('Compte et sécurité', 'assets/icons/user.svg'),
  ];
  final faqs = const [
    (
      'Comment suivre ma commande ?',
      'Ouvrez « Mes commandes » puis touchez la commande : chaque étape s’affiche avec sa date.',
    ),
    (
      'Comment devenir vendeur ?',
      'Depuis votre profil, demandez le statut d’étudiant vendeur. Votre carte étudiante est vérifiée sous 48 h.',
    ),
    (
      'Quels sont les délais de retrait ?',
      'Votre commande reste disponible 7 jours au kiosque IUT après la notification « Prête au retrait ».',
    ),
  ];
  final supportDelay = 'Notre équipe répond sous 24 h.';
  final supportImage = 'assets/images/e_sacs_support.jpg';
}

final sectionEDataProvider = Provider<SectionEData>((_) => const SectionEData());
