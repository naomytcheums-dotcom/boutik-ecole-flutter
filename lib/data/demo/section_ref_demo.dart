import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';

/// Données de démonstration des échantillons de référence (A1–A3, P1–P5, V1, L1, S1, D1).
class SectionREFData {
  const SectionREFData();

  // A1 · Assistante vocale Kéla
  final kelaQuestionAsked = 'Peux-tu m’aider à créer un logo et une affiche';
  final kelaQuestionLive = 'pour mon parfum, avant fin novembre ?';
  final kelaWave = const [12.0, 22.0, 30.0, 40.0, 28.0, 36.0, 22.0, 14.0];

  // A2 · Accueil Kéla
  final userFirstName = 'Mariam';
  final userAvatar = 'assets/images/ref_av_mariam.jpg';
  final themes = const ['Missions', 'Design', 'Vidéo', 'Commerce', 'Prototypes'];
  final matchCount = 2;
  final matchDepartment = 'MMI';
  final matchBrief = 'brief parfum';

  // A3 · Voix en texte
  final voiceDuration = '1:33';
  final voiceWave = const [12.0, 20.0, 14.0, 24.0, 18.0, 26.0, 12.0, 22.0, 16.0, 24.0, 14.0, 20.0, 10.0, 18.0, 12.0];

  final voiceTime = '16:43';
  final kelaBudget = 200000;

  /// (message de Kéla ?, texte, heure, photo jointe).
  List<(bool, String, String?, String?)> get chat => [
    (
      true,
      'Décris-moi ton parfum : cible, style et budget. Je prépare le brief et je contacte les étudiants de MMI et de TCO.',
      '16:43',
      null,
    ),
    (false, '', '16:44', 'assets/images/ref_bissap.jpg'),
    (false, 'Crée la mission pour moi', null, null),
    (
      true,
      'Compris ! Je lance ton brief : logo + affiche, budget d’environ ${fcfa(kelaBudget)}. Veux-tu aussi une vidéo teaser ?',
      null,
      null,
    ),
  ];

  // P1–P3 · Profil talent (Aminata Bello)
  final talentName = 'Aminata Bello';
  final talentTags = const ['#Vidéaste', '#Directrice', '#Designer'];
  final talentBio =
      'Étudiante en MMI. Je crée des identités visuelles et des vidéos pour des marques locales, du logo à la campagne.';
  final talentPhoto = 'assets/images/student_hijab.jpg';
  final followers = 2695;
  final following = 369;
  final missions = 38;
  final stories = const [
    'assets/images/ref_story_atelier.jpg',
    'assets/images/ref_story_mobile.jpg',
    'assets/images/ref_story_code.jpg',
  ];
  final friendAvatars = const [
    'assets/images/c_avatar_aminata.jpg',
    'assets/images/t_av_kouassi.jpg',
    'assets/images/t_av_brice.jpg',
  ];

  /// Galerie du profil (rangée 1 : grande + petite, rangée 2 : trois vignettes).
  final galleryTop = const ['assets/images/ref_atelier_maquette.jpg', 'assets/images/ref_mobile_portfolio.jpg'];
  final galleryBottom = const ['assets/images/ref_bissap.jpg', 'assets/images/coder.jpg', 'assets/images/solar.jpg'];

  // P2 · Profil (abonnement)
  final storyDurations = const ['15 min', '20 min', '1 h'];
  final rating = '4,9';
  final reviewCount = 28;

  /// Réseaux connectés : (nom, logo).
  final networks = const [
    ('Facebook', 'assets/images/am_net_facebook.jpg'),
    ('Instagram', 'assets/images/am_net_instagram.jpg'),
    ('YouTube', 'assets/images/am_net_youtube.jpg'),
    ('TikTok', 'assets/images/am_net_tiktok.jpg'),
    ('LinkedIn', 'assets/images/am_net_linkedin.jpg'),
  ];

  // P3 · Avis et outils
  final ratingBars = const [('5★', 0.9), ('4★', 0.07), ('3★', 0.02)];
  final recommendedClients = 9;
  final recommendedCompanies = 3;

  /// Avis : (auteur, texte, avatar, étoiles).
  final reviews = const [
    ('Mbella SARL', 'Logo livré en 4 jours, très pro.', 'assets/images/ref_av_mbella.jpg', 5),
    ('Mairie de Douala', 'Affiche claire, suivi impeccable.', 'assets/images/ref_av_mairie.jpg', 5),
  ];

  /// Outils connectés du profil : (nom, détail, logo).
  final profileTools = const [
    ('YouTube', 'Aminata Studio · 18,4 k abonnés', 'assets/images/am_net_youtube.jpg'),
    ('TikTok', '@aminata.vid · 52 k j’aime', 'assets/images/am_net_tiktok.jpg'),
    ('Instagram', '@aminata.creates · 6,2 k abonnés', 'assets/images/am_net_instagram.jpg'),
    ('Facebook', 'Aminata Bello Studio · 2,1 k abonnés', 'assets/images/am_net_facebook.jpg'),
    ('LinkedIn', 'Aminata Bello · Disponible pour missions', 'assets/images/am_net_linkedin.jpg'),
    ('Google Drive', 'Portfolio vidéo · Dossier partagé', 'assets/images/ref_logo_gdrive.jpg'),
  ];
  final profileLink = 'boutik-ecole.cm/aminata-bello';

  // P4 · Nouvelle publication
  final postMedia = const [
    'assets/images/ref_pub_mobile.jpg',
    'assets/images/ref_pub_atelier.jpg',
    'assets/images/ref_pub_code.jpg',
  ];
  final postCaption = 'Spot promo pour le parfum Mbella : tournage, montage et étalonnage.';
  final postHashtags = '#vidéo #MMI #Douala';

  /// Réseaux de diffusion : (nom, logo, activé par défaut).
  final postNetworks = const [
    ('YouTube', 'assets/images/am_net_youtube.jpg', true),
    ('TikTok', 'assets/images/am_net_tiktok.jpg', true),
    ('Instagram', 'assets/images/am_net_instagram.jpg', false),
    ('Facebook', 'assets/images/am_net_facebook.jpg', true),
    ('Google Drive', 'assets/images/ref_logo_gdrive.jpg', false),
  ];

  // V1 · Vitrine
  /// Directs : (nom, photo, étiquette « LIVE »/« BOOST »/null).
  final lives = const [
    ('Yannick', 'assets/images/ref_live_yannick.jpg', 'LIVE'),
    ('Atelier GI', 'assets/images/ref_live_atelier_gi.jpg', 'LIVE'),
    ('Kamga', 'assets/images/ref_live_kamga.jpg', 'BOOST'),
    ('Aminata', 'assets/images/ref_live_aminata.jpg', null),
    ('Équipe', 'assets/images/ref_live_equipe.jpg', null),
  ];
  final vitrineFilters = const ['Tout', 'Vidéos', 'Produits', 'Prototypes'];
  final heroImage = 'assets/images/ref_hero_betonniere.jpg';
  final sellerName = 'Yannick M.';
  final sellerAvatar = 'assets/images/ref_av_yannick.jpg';
  final sellerDept = 'Génie civil · Atelier GI';
  final productName = 'Lampe en bois recyclé';
  final productPrice = 25000;
  final productRating = '4,8';
  final productReviews = 12;
  final likes = 248;
  final comments = 31;

  /// Collage « Dans le même métier » (gauche, centre, principal, droite haut, droite bas).
  final sameTrade = const [
    'assets/images/technician.jpg',
    'assets/images/ref_atelier_maquette.jpg',
    'assets/images/ref_hero_betonniere.jpg',
    'assets/images/ref_bissap.jpg',
    'assets/images/solar.jpg',
  ];

  /// Recommandés : (nom, vendeur, prix, photo).
  final recommended = const [
    ('Jus de bissap', 'Équipe BTA', 1500, 'assets/images/ref_reco_bissap.jpg'),
    ('Kit solaire', 'Brice N.', 18000, 'assets/images/ref_reco_solaire.jpg'),
  ];

  // P5 · Connecter mes outils
  final toolFilters = const ['Tout', 'Réseaux', 'Portfolio', 'Gestion', 'Paiement'];

  /// Groupes d'outils : (titre, filtre, outils masqués, outils).
  /// Outil : (nom, détail, logo, repère (initiales ou icône), teinte ARGB, connecté).
  final toolGroups = const [
    (
      'Réseaux sociaux',
      'Réseaux',
      4,
      [
        ('Facebook', 'Aminata Bello Studio', 'assets/images/am_net_facebook.jpg', null, 0xFF1877F2, true),
        ('Instagram', 'Non connecté', 'assets/images/am_net_instagram.jpg', null, 0xFFE1306C, false),
        ('TikTok', '@aminata.vid', 'assets/images/am_net_tiktok.jpg', null, 0xFF111015, true),
        ('YouTube', 'Aminata Studio', 'assets/images/am_net_youtube.jpg', null, 0xFFFF0000, true),
        ('LinkedIn', 'Non connecté', 'assets/images/am_net_linkedin.jpg', null, 0xFF0A66C2, false),
      ],
    ),
    (
      'Portfolio et stockage',
      'Portfolio',
      5,
      [
        ('Google Drive', 'Portfolio vidéo', 'assets/images/ref_logo_gdrive.jpg', null, 0xFF1FA463, true),
        ('Behance', 'Non connecté', null, 'Bē', 0xFF1769FF, false),
        ('GitHub', 'Non connecté', null, 'assets/icons/code.svg', 0xFF3A3940, false),
      ],
    ),
    (
      'Gestion et équipe',
      'Gestion',
      6,
      [
        ('Trello', 'Non connecté', null, 'Tr', 0xFF1F6FC5, false),
        ('Notion', 'Non connecté', null, 'N', 0xFF55535C, false),
        ('Slack', 'Non connecté', null, 'Sl', 0xFF611F69, false),
      ],
    ),
    (
      'Paiement',
      'Paiement',
      0,
      [
        ('Orange Money', 'Reçois tes paiements', null, 'OM', 0xFFE8730C, false),
        ('MTN MoMo', 'Reçois tes paiements', null, 'MM', 0xFFB08A00, false),
      ],
    ),
  ];

  // L1 · Aller en direct
  final livePreview = 'assets/images/ref_live_atelier.jpg';
  final liveTitle = 'Atelier : fabrication de la lampe en bois recyclé';

  /// Critères d'éligibilité : (libellé, rempli).
  final liveCriteria = const [
    ('Profil vérifié', true),
    ('1 mission livrée', true),
    ('Note 4,0 ou plus', true),
    ('Charte acceptée', false),
  ];
  final liveNote = 'Aucun seuil d’abonnés sur Boutik-École.';

  // S1 · Démarrage
  final splashImage = 'assets/images/ref_splash_campus.jpg';
  final splashLogo = 'assets/images/ref_logo_be.png';
  final splashTagline = 'La marketplace de l’expertise\net des productions de l’IUT de Douala';

  // D1 · Tableau de bord du studio
  final studioOwner = 'Aminata Bello';
  final studioEmail = 'aminata@boutik.cm';
  final revenueTotal = 1245000;
  final revenueDelta = '+ 6,25 %';
  final revenueGain = 72000;
  final revenueTooltip = ('1 245 k', 'Octobre 2026');
  final revenueMonths = const ['Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.'];
  final revenueBars = const [
    0.47, 0.43, 0.51, 0.39, 0.47, 0.43, 0.36, 0.44, 0.34, 0.4, 0.33, 0.33, 0.38, 0.44, 0.31, 0.32, 0.39, 0.44, //
    0.37, 0.33, 0.43, 0.26, 0.4, 0.29, 0.26, 0.26, 0.29, 0.38, 0.26, 0.33, 0.35, 0.3, 0.33, 0.25, 0.25, 0.28, //
    0.36, 0.32, 0.77, 0.82, 0.79, 0.76, 0.85, 0.84, 0.75, 0.81, 0.8, 0.87, 0.84, 0.76, 0.89, 0.73, 0.79, 0.85, //
    0.74, 0.8, 0.72, 0.83, 0.6, 0.56, 0.62, 0.52, 0.59, 0.57, 0.56, 0.54, 0.61, 0.63, 0.55, 0.58,
  ];
  final revenueHighlight = (38, 58);
  final revenueCurve = const [0.42, 0.58, 0.5, 0.3, 0.28, 0.45, 0.62, 0.48, 0.34];

  /// Produits : (vignette, nom, référence, commandes, statut, disponible, prix).
  final studioProducts = const [
    ('assets/images/lamp.jpg', 'Lampe en bois recyclé', 'LMP-001', 250, 'Disponible', true, 25000),
    ('assets/images/bissap.jpg', 'Jus de bissap', 'JUS-014', 75, 'En stock', false, 1500),
    ('assets/images/solar.jpg', 'Kit solaire portable', 'SOL-007', 120, 'Disponible', true, 18000),
    ('assets/images/builder.jpg', 'Casque de chantier connecté', 'CAS-022', 300, 'En stock', false, 12500),
    ('assets/images/phone_stand.jpg', 'Support de tablette', 'SUP-031', 90, 'Disponible', true, 6000),
  ];
  final studioGoal = 32;
  final studioGoalProgress = const [(32, 'de l’objectif'), (80, 'de l’objectif')];
  final kelaDashAvatar = 'assets/images/ref_av_mariam.jpg';
  final kelaDashQuestion = 'Quels enseignements cherches-tu ?';
  final kelaDashAnswer =
      'Tes revenus ont progressé de 6 % ce mois-ci, portés par tes meilleurs produits. Veux-tu un plan pour doubler les commandes de la lampe ?';
  final teamAvatars = const [
    'assets/images/t_av_aminata.jpg',
    'assets/images/t_av_brice.jpg',
    'assets/images/t_av_kouassi.jpg',
  ];
  final unreadMessages = 2;
}

final sectionREFDataProvider = Provider<SectionREFData>((_) => const SectionREFData());
