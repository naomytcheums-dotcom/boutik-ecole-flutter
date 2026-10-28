import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import 'catalog_demo.dart';

/// État de stock d'une variante (écran 35).
enum DStock { ok, low, out }

/// Statut d'une étape de fabrication (écran 33).
enum DStepState { done, current, todo }

/// Données fictives de la section D · Fiches produits, services, prestataires (32–40).
class SectionDData {
  const SectionDData();

  // ----- Produit commun (32, 33, 34, 35, 39) -----
  final productTitle = 'Lampe en bois recyclé';
  final productPrice = 25000;
  final productStock = 'En stock';
  final productTotalUnits = 15;
  final productHero = 'assets/images/d_lampe_atelier.jpg';
  final productThumb = Photos.branding;
  final creatorName = 'Mouanga Yannick';
  final creatorShort = 'Yannick M.';
  final creatorAvatar = Photos.avatarCreator;
  final creatorDepartment = 'Génie civil';

  // ----- 32 · Détail du produit -----
  final productTabs = const ['Description', 'Détails', 'Avis', 'Livraison'];
  final productTabTexts = const [
    'Lampe décorative fabriquée à partir de bois recyclé. Écologique, design et idéale pour un intérieur moderne.',
    'Structure en lamelles de 3 mm assemblées à la main, câble textile de 1,5 m et interrupteur intégré.',
    '4,9 / 5 sur 38 avis : finition soignée, lumière chaleureuse et livraison rapide sur le campus.',
    'Retrait gratuit au kiosque IUT – Bloc A sous 24 à 48 h, ou livraison sur Douala dès 1 000 FCFA.',
  ];
  final productVariants = const ['Chêne naturel', 'Noyer', 'Bambou'];
  final productSpecs = const [
    ('Matériau', 'Bois recyclé'),
    ('Dimensions', '28 × 22 cm'),
    ('Éclairage', 'LED E27 incluse'),
    ('Garantie', '6 mois'),
  ];
  final sellerSubtitle = 'Génie civil · Vendeur vérifié';

  // ----- 33 · Histoire du produit -----
  final storyHeadline = 'De la chute de bois à la lumière';
  final storyTagline = 'Une lampe née d’un atelier de génie civil';
  final storyCreatorMeta = 'Génie civil · IUT de Douala';
  final storyText =
      'Yannick récupère les chutes de bois des chantiers-écoles pour en faire des luminaires uniques. '
      'Chaque pièce est dessinée, découpée et assemblée à la main.';
  final storySteps = const [
    ('Récupération des chutes', 'Ateliers du département Génie civil', DStepState.done),
    ('Découpe et ponçage', 'Lamelles de 3 mm', DStepState.done),
    ('Assemblage', 'Structure en cage', DStepState.current),
    ('Finition et test', 'Contrôle électrique', DStepState.todo),
  ];

  // ----- 34 · Galerie -----
  final galleryHero = 'assets/images/d_galerie_equipe.jpg';
  // (photo, cadrage horizontal -1…1)
  final galleryStrip = const [
    (Photos.phoneStand, 0.4),
    (Photos.drone, 0.0),
    (Photos.bagDesign, 0.0),
    (Photos.droneLogo, 0.0),
  ];
  final galleryPhotoCount = 12;
  final galleryPhotos = const [
    (Photos.drone, 0.0),
    (Photos.backpacks, 0.0),
    ('assets/images/d_galerie_clavier.jpg', 0.0),
    (Photos.laptopMeeting, 0.0),
    (Photos.plants, 0.0),
    (Photos.plantPot, 1.0),
  ];
  final videoTitle = 'Fabrication de la lampe';
  final videoMeta = 'Vidéo · 1 min 24';
  final videoCover = 'assets/images/d_galerie_video.jpg';

  // ----- 35 · Disponibilité -----
  final stockVariants = const [
    ('Chêne naturel', 'SKU LB-001', 12, DStock.ok),
    ('Noyer', 'SKU LB-002', 3, DStock.low),
    ('Bambou', 'SKU LB-003', 0, DStock.out),
  ];
  final stockInfo = const [
    ('Disponibilité', 'En stock'),
    ('Préparation', '24 à 48 h'),
    ('Retrait', 'Kiosque IUT – Bloc A'),
    ('Réassort prévu', '03 nov. 2026'),
  ];
  final stockAlert = 'Stock bas sur la variante « Noyer » : commandez vite ou activez l’alerte.';

  // ----- 36 · Détail du service -----
  final serviceTitle = 'Développement web sur mesure';
  final serviceProvider = 'Mariam Essono';
  final serviceDepartment = 'Génie informatique';
  final serviceCover = 'assets/images/d_service_remise.jpg';
  final serviceStats = const [('4.9', 'Note'), ('38', 'Missions'), ('48 h', 'Délai moyen')];
  final serviceFormulas = const [
    ('Essentiel', '1 page · 3 jours', 30000, AppIcons.zap),
    ('Standard', '5 pages · 7 jours', 80000, AppIcons.layers),
    ('Premium', 'Site complet · 14 jours', 150000, AppIcons.award),
  ];
  final serviceTerms = const [
    ('Mode', 'À distance ou sur campus'),
    ('Délai', '3 à 14 jours'),
    ('Révisions', '2 incluses'),
    ('Paiement', 'Mobile Money'),
  ];
  final providerAvatar = Photos.avatarCreator;

  // ----- 38 · Réputation -----
  final repName = 'Yannick Mouanga';
  final repMeta = 'Génie civil · Vendeur depuis 2025';
  final repBadge = 'Top vendeur';
  final repScorePercent = 96;
  final repRating = '4,9 / 5';
  final repSummary = '38 avis · 98 % de recommandations';
  final repDistribution = const [('5 étoiles', 88), ('4 étoiles', 9), ('3 étoiles', 3)];
  final repTrustBadges = const ['Livraison rapide', 'Produit conforme', 'Bon échange', 'Vérifié IUT'];
  final repReviews = const [
    ('Aminata B.', 'Produit de très bonne qualité !', '5.0', 'assets/images/d_avis_aminata.jpg'),
    (
      'Kouassi T.',
      'Très beau produit, livraison un peu longue mais vendeur réactif.',
      '4.0',
      'assets/images/d_avis_kouassi.jpg',
    ),
  ];

  // ----- 39 · Demande de renseignements -----
  final inquiryThumb = Photos.paintRed;
  final inquiryTopics = const [
    ('Disponibilité', 'Bonjour, la lampe est-elle disponible en bambou ?'),
    ('Délai', 'Bonjour, sous quel délai puis-je récupérer la lampe ?'),
    ('Personnalisation', 'Bonjour, est-il possible de graver un prénom sur la lampe ?'),
    ('Livraison', 'Bonjour, livrez-vous à Bonamoussadi ?'),
  ];
  final inquiryPhoneHint = '+237 6 XX XX XX XX';
  final inquiryNote = 'Le vendeur répond généralement sous 24 h dans la messagerie.';

  // ----- 40 · Demande de devis -----
  final quoteSubject = 'Site vitrine pour mon association';
  final quoteBudgets = const [(30000, 50000), (50000, 80000), (80000, 150000)];
  final quoteBudgetIndex = 1;
  final quoteDelays = const ['Dans 1 semaine', 'Dans 2 semaines', 'Dans 1 mois'];
  final quoteDelayIndex = 1;
  final quoteAttachmentHint = 'PDF, DOC · 5 Mo max';
}

final sectionDDataProvider = Provider<SectionDData>((_) => const SectionDData());
