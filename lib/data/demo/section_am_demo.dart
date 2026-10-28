import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contact proposé à l'invitation (241). `state` : 0 = à cocher, 1 = coché, 2 = déjà inscrit.
typedef AmContact = ({String name, String detail, String avatar, int state});

/// Filleul et gain associé (243). `tone` : 0 = vert, 1 = violet, 2 = orange.
typedef AmReferral = ({String name, String status, int tone, int? gain});

/// Story du fil (244). `badge` : null, 'LIVE' ou 'BOOST'.
typedef AmStory = ({String name, String? avatar, String? badge});

/// Publication du fil (244).
typedef AmPost = ({
  String author,
  String avatar,
  String meta,
  String text,
  List<String> images,
  String category,
  String type,
  int likes,
  int comments,
  int shares,
  int price,
});

/// Live programmé (246).
typedef AmLive = ({String day, String date, String month, String title, String author, String image});

/// Article de boutique (248).
typedef AmShopItem = ({String title, String tag, int price, bool from, String image, String rating});

/// Commentaire (252).
typedef AmComment = ({String author, String avatar, String time, String? mention, String text, int likes});

/// Défi de la semaine (253). `icon` : nom d'icône (voir AppIcons).
typedef AmChallenge = ({String title, String icon, int done, int total, int points});

/// Notification d'activité (254). `icon` : nom d'icône du badge, `action` : bouton.
typedef AmActivity = ({String avatar, String text, String time, String icon, String action, String target});

/// Données de démonstration de la section AM · Cercle, parrainage, publication (240–254).
class SectionAMData {
  const SectionAMData();

  // Avatars (photos réutilisées des autres sections).
  static const avBrice = 'assets/images/f_avatar_brice.jpg';
  static const avCarine = 'assets/images/t_av_landry.jpg';
  static const avKouassi = 'assets/images/t_av_yannick.jpg';
  static const avMbella = 'assets/images/c_avatar_kouassi.jpg';
  static const avYannick = 'assets/images/t_av_kouassi.jpg';
  static const avAminata = 'assets/images/avatar_creator.jpg';
  static const avHijab = 'assets/images/avatar_woman.jpg';
  static const avMbellaSarl = 'assets/images/i_av_brice_3.jpg';

  // 240 · Parrainer et gagner
  final referralGains = 12500;
  final inviteLink = 'boutik-ecole.cm/r/mariam24';
  final shareChannels = const [
    ('WhatsApp', 'assets/images/am_logo_whatsapp.jpg'),
    ('Facebook', 'assets/images/am_logo_facebook.jpg'),
    ('Instagram', 'assets/images/am_logo_instagram.jpg'),
    ('TikTok', 'assets/images/am_logo_tiktok.jpg'),
  ];
  final level = 'Argent';
  final referralsCount = 7;
  final nextLevelHint = 'Plus que 13 filleuls pour passer Or';
  final levelProgress = 0.35;
  final tiers = const [
    ('Bronze', '1 à 4 amis', '500 F', 'par inscrit'),
    ('Argent', '5 à 19 amis', '750 F + 2 %', 'des ventes'),
    ('Or', '20 et + amis', '1 000 F + 3 %', 'des ventes'),
  ];

  // 241 · Mes contacts
  final contactFilters = const ['WhatsApp', 'Téléphone', 'Tous'];
  final List<AmContact> contacts = const [
    (name: 'Brice Ndoumbe', detail: 'Sur WhatsApp · pas encore inscrit', avatar: avBrice, state: 1),
    (name: 'Carine Mbarga', detail: 'Sur WhatsApp · pas encore inscrite', avatar: avCarine, state: 1),
    (name: 'Kouassi Tagne', detail: 'Sur WhatsApp · pas encore inscrit', avatar: avKouassi, state: 1),
    (name: 'Mme Mbella', detail: 'Sur WhatsApp · déjà inscrite', avatar: avMbella, state: 2),
    (name: 'Yannick Mouanga', detail: 'Sur WhatsApp · pas encore inscrit', avatar: avYannick, state: 0),
  ];
  final inviteMessage =
      'Salut ! Rejoins Boutik-École, la marketplace des talents de l’IUT de Douala : boutik-ecole.cm/r/mariam24';

  // 242 · Kit à partager : (titre, prime, image, vidéo ?)
  final shareKit = const [
    ('Story en 30 s', 500, 'assets/images/hero_student.jpg', true),
    ('Vidéo témoignage', 800, 'assets/images/team.jpg', true),
    ('Affiche du concours', 300, 'assets/images/branding.jpg', false),
    ('Avant / après', 400, 'assets/images/c_fav_peinture.jpg', false),
  ];

  // 243 · Mes gains
  final balance = 12500;
  final monthGain = 2500;
  final gainBars = const [0.28, 0.42, 0.38, 0.6, 0.52, 0.78, 1.0];
  final gainStats = const [('7', 'Filleuls'), ('4', 'Actifs'), ('3', 'En attente')];
  final List<AmReferral> referrals = const [
    (name: 'Brice Ndoumbe', status: '1re commande', tone: 0, gain: 750),
    (name: 'Carine Mbarga', status: 'Inscrite', tone: 1, gain: 750),
    (name: 'Kouassi Tagne', status: 'Actif · 3 achats', tone: 0, gain: 1150),
    (name: 'Mme Mbella', status: 'Mission payée', tone: 0, gain: 2400),
    (name: 'Yannick M.', status: 'En attente', tone: 2, gain: null),
  ];
  final referralAvatars = const [avBrice, avCarine, avKouassi, avMbella, avYannick];

  // 244 · Cercle
  final List<AmStory> stories = const [
    (name: 'Toi', avatar: 'assets/images/q_av_mariam.jpg', badge: null),
    (name: 'Yannick', avatar: avHijab, badge: 'LIVE'),
    (name: 'Atelier GI', avatar: 'assets/images/c_avatar_atelier.jpg', badge: 'LIVE'),
    (name: 'Kamga', avatar: 'assets/images/i_av_brice.jpg', badge: 'BOOST'),
    (name: 'Aminata', avatar: avAminata, badge: null),
    (name: 'Équipe', avatar: 'assets/images/team.jpg', badge: null),
  ];
  final feedFilters = const ['Pour toi', 'Abonnements', 'Vidéos', 'Boutiques'];
  final AmPost post = const (
    author: 'Yannick M.',
    avatar: avHijab,
    meta: 'Génie civil · il y a 1 h',
    text: 'Lampe en bois recyclé : fabrication terminée, disponible dans ma boutique.',
    images: ['assets/images/lamp.jpg', 'assets/images/d_lampe_atelier.jpg', 'assets/images/bulb.jpg'],
    category: 'Génie civil',
    type: 'Boutique',
    likes: 248,
    comments: 31,
    shares: 12,
    price: 25000,
  );

  // 245 · Reels
  final reelImage = 'assets/images/solar.jpg';
  final reelAuthor = 'Brice N.';
  final reelAvatar = avBrice;
  final reelText =
      'Pose d’un kit solaire sur le toit de l’atelier. Tout est fait par les étudiants d’Énergies renouvelables !';
  final reelSound = 'Son original · Brice N.';
  final reelStats = const ['2,6 k', '312', 'Partager', '4,9', 'Boutique'];
  final reelProgress = 0.35;

  // 246 · Lives
  final liveNowTitle = 'Atelier : la lampe en bois recyclé';
  final liveNowAuthor = 'Yannick M. · Génie civil';
  final liveNowViewers = '1,2 k';
  final liveNowImage = 'assets/images/d_lampe_atelier.jpg';
  final liveNowAvatar = avHijab;
  final List<AmLive> upcomingLives = const [
    (
      day: 'Ven.',
      date: '24',
      month: 'oct.',
      title: 'Jus de bissap : de la cuisine au kiosque',
      author: 'Équipe BTA',
      image: 'assets/images/bissap.jpg',
    ),
    (
      day: 'Sam.',
      date: '25',
      month: 'oct.',
      title: 'Montage d’un kit solaire en direct',
      author: 'Brice N.',
      image: 'assets/images/solar.jpg',
    ),
    (
      day: 'Lun.',
      date: '27',
      month: 'oct.',
      title: 'Pitch : applis de suivi clients',
      author: 'Mariam E.',
      image: 'assets/images/coder.jpg',
    ),
  ];

  // 247 · Profil créateur
  final creatorHandle = '@aminata.studio';
  final creatorName = 'Aminata Bello';
  final creatorRole = 'Vidéaste · MMI · IUT de Douala';
  final creatorAvatar = avAminata;
  final creatorBio = 'Je crée des identités visuelles et des vidéos pour des marques locales, du logo à la campagne.';
  final creatorStats = const [('124', 'Publications'), ('2,7 k', 'Abonnés'), ('369', 'Suivis'), ('4,9', 'Note')];
  final creatorNetworks = const [
    ('Instagram', 'assets/images/am_net_instagram.jpg'),
    ('YouTube', 'assets/images/am_net_youtube.jpg'),
    ('TikTok', 'assets/images/am_net_tiktok.jpg'),
    ('Facebook', 'assets/images/am_net_facebook.jpg'),
    ('LinkedIn', 'assets/images/am_net_linkedin.jpg'),
  ];

  /// Grille des publications : (image, vues ou null).
  final creatorGrid = const [
    ('assets/images/branding.jpg', '280 k'),
    ('assets/images/d_galerie_video.jpg', '1,2 M'),
    ('assets/images/bag_design.jpg', null),
    ('assets/images/sketch.jpg', null),
    ('assets/images/paint.jpg', '1,2 M'),
    ('assets/images/drone_logo.jpg', null),
    ('assets/images/scrabble.jpg', null),
    ('assets/images/laptop_meeting.jpg', '1,2 M'),
    ('assets/images/paint_red.jpg', null),
  ];

  // 248 · Boutique d'Aminata
  final shopName = 'Boutique d’Aminata';
  final shopMeta = '8 articles · 4,9 ★';
  final shopTabs = const ['Produits', 'Services', 'Offres de clients'];
  final List<AmShopItem> shopItems = const [
    (
      title: 'Logo sur mesure',
      tag: 'Service',
      price: 80000,
      from: true,
      image: 'assets/images/branding.jpg',
      rating: '★ 4,9 · 12 commandes',
    ),
    (
      title: 'Affiche A3',
      tag: 'Service',
      price: 45000,
      from: false,
      image: 'assets/images/sketch.jpg',
      rating: '★ 4,9 · 12 commandes',
    ),
    (
      title: 'Spot vidéo 30 s',
      tag: 'Service',
      price: 180000,
      from: false,
      image: 'assets/images/d_galerie_video.jpg',
      rating: '★ 4,9 · 12 commandes',
    ),
    (
      title: 'Identité visuelle',
      tag: 'Pack',
      price: 250000,
      from: false,
      image: 'assets/images/bag_design.jpg',
      rating: '★ 4,9 · 12 commandes',
    ),
  ];

  // 249 · Créer : (titre, description, icône, écran cible)
  final createOptions = const [
    ('Publication', 'Photo, vidéo ou carrousel pour ton fil', 'image', '250'),
    ('Reel', 'Vidéo verticale courte, plein écran', 'video', '245'),
    ('Live', 'Direct sans seuil d’abonnés', 'radio', '246'),
    ('Article de boutique', 'Produit, service ou offre', 'shoppingBag', '248'),
  ];
  final draftsCount = 2;

  // 250 · Nouvelle publication
  final newPostImage = 'assets/images/phone.jpg';
  final newPostCaption = 'Spot promo pour le parfum Mbella : tournage, montage et étalonnage. #vidéo #MMI';
  final postTypes = const ['Publication', 'Reel', 'Live', 'Boutique'];

  /// Réseaux de diffusion : (réseau, compte, logo, activé ; null = à connecter).
  final publishNetworks = const [
    ('Instagram', '@aminata.creates', 'assets/images/am_net_instagram.jpg', true),
    ('YouTube', 'Aminata Studio', 'assets/images/am_net_youtube.jpg', true),
    ('TikTok', '@aminata.vid', 'assets/images/am_net_tiktok.jpg', false),
    ('Facebook', 'Aminata Bello Studio', 'assets/images/am_net_facebook.jpg', true),
    ('LinkedIn', 'Connecter ce compte', 'assets/images/am_net_linkedin.jpg', null),
  ];

  // 251 · Découvrir
  final discoverFilters = const ['Tout', 'MMI', 'GI', 'GC', 'TCO', 'GEII'];

  /// Tendances : (image, libellé du badge).
  final trends = const [
    ('assets/images/solar.jpg', '3,2 M'),
    ('assets/images/food_spread.jpg', 'Live'),
    ('assets/images/builder.jpg', null),
    ('assets/images/maquette.jpg', null),
    ('assets/images/coder.jpg', null),
    ('assets/images/phone.jpg', null),
  ];
  final talents = const [
    ('Aminata B.', avAminata),
    ('Brice N.', avBrice),
    ('Carine M.', avCarine),
    ('Kouassi T.', avKouassi),
  ];

  // 252 · Commentaires et avis
  final articleTitle = 'Lampe en bois recyclé';
  final articleAuthor = 'par Yannick M.';
  final articlePrice = 25000;
  final articleImage = 'assets/images/builder.jpg';
  final commentsCount = 31;
  final reviewsCount = 12;
  final rating = '4,8';
  final verifiedReviews = '12 avis vérifiés';
  final List<AmComment> comments = const [
    (
      author: 'Mbella SARL',
      avatar: avMbellaSarl,
      time: '2 h',
      mention: null,
      text: 'Très belle finition, livrée à temps. Je recommande !',
      likes: 12,
    ),
    (
      author: 'Carine Mbarga',
      avatar: avCarine,
      time: '1 h',
      mention: null,
      text: 'Magnifique. Tu fais aussi sur mesure ?',
      likes: 4,
    ),
    (
      author: 'Yannick M.',
      avatar: avHijab,
      time: '45 min',
      mention: '@Carine',
      text: ' Oui ! Écris-moi en message privé pour un devis.',
      likes: 2,
    ),
    (
      author: 'Kouassi Tagne',
      avatar: avKouassi,
      time: '20 min',
      mention: null,
      text: 'Bravo l’équipe Génie civil 👏',
      likes: 1,
    ),
  ];

  // 253 · Défis et récompenses
  final streakDays = 5;
  final rewardImage = 'assets/images/builder.jpg';
  final List<AmChallenge> challenges = const [
    (title: 'Publier 3 posts', icon: 'pencil', done: 2, total: 3, points: 200),
    (title: 'Lancer un live', icon: 'radio', done: 0, total: 1, points: 500),
    (title: 'Répondre à 5 commentaires', icon: 'messageCircle', done: 4, total: 5, points: 100),
  ];

  /// Badges : (libellé, débloqué, couleur rose ?).
  final badges = const [
    ('Première vente', true, false),
    ('100 abonnés', true, false),
    ('Live star', true, true),
    ('Top 10', false, false),
  ];

  // 254 · Activité
  final activityFilters = const ['Tout', 'Abonnés', 'Commandes', 'Lives'];
  final kelaAvatar = avAminata;
  final kelaTip = 'Poste avant 18 h : ton audience est la plus active.';
  final List<AmActivity> today = const [
    (
      avatar: avMbellaSarl,
      text: 'Mme Mbella a vu ta boutique',
      time: 'Il y a 5 min',
      icon: 'eye',
      action: 'Répondre',
      target: '53',
    ),
    (
      avatar: avBrice,
      text: 'Brice N. lance un live dans 10 min',
      time: 'Il y a 12 min',
      icon: 'radio',
      action: 'Me rappeler',
      target: '246',
    ),
    (
      avatar: avCarine,
      text: 'Carine M. s’est abonnée',
      time: 'Il y a 1 h',
      icon: 'userPlus',
      action: 'Suivre en retour',
      target: '247',
    ),
    (
      avatar: avKouassi,
      text: 'Ta publication dépasse 1 000 vues',
      time: 'Il y a 2 h',
      icon: 'zap',
      action: 'Propulser',
      target: '250',
    ),
  ];
  final List<AmActivity> yesterday = const [
    (
      avatar: avHijab,
      text: 'Ta série de 5 jours t’attend',
      time: 'Hier · 19:00',
      icon: 'flame',
      action: 'Récupérer',
      target: '253',
    ),
    (
      avatar: avMbella,
      text: 'Kouassi T. a commenté ta lampe',
      time: 'Hier · 14:20',
      icon: 'messageCircle',
      action: 'Voir',
      target: '252',
    ),
  ];
}

final sectionAMDataProvider = Provider<SectionAMData>((_) => const SectionAMData());
