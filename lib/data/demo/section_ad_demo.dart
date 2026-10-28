import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/utils/money.dart';
import '../models/models.dart';

/// Vœu de fabrication (216, 217).
typedef AdWish = ({String title, String author, String image, int count, int target, int price, String tag});

/// Participant classé (220, 221).
typedef AdRanked = ({String name, String avatar, String detail, String badge, Tone tone});

/// Données de démonstration de la section AD (innovations, 216–229).
class SectionADData {
  const SectionADData();

  // 216 · Marché des vœux
  final wishIntro =
      'Voici les produits que les étudiants veulent fabriquer. Précommandez : la production démarre quand le seuil est atteint.';
  final wishFilters = const ['Tous', 'Presque atteints', 'Nouveaux', 'Mes précommandes'];
  final List<AdWish> wishes = const [
    (
      title: 'Lampe en bois recyclé',
      author: 'Mouanga Yannick',
      image: 'assets/images/builder.jpg',
      count: 156,
      target: 200,
      price: 25000,
      tag: 'presque',
    ),
    (
      title: 'Jus de bissap bio',
      author: 'Équipe BTA',
      image: 'assets/images/food_spread.jpg',
      count: 64,
      target: 150,
      price: 1500,
      tag: 'nouveau',
    ),
    (
      title: 'Kit solaire de poche',
      author: 'Brice Ndoumbe',
      image: 'assets/images/solar.jpg',
      count: 28,
      target: 100,
      price: 18000,
      tag: 'nouveau',
    ),
  ];

  /// Titres des vœux déjà précommandés par l'étudiant connecté.
  final myPreorders = const ['Jus de bissap bio'];

  // 217 · Fiche d'un vœu
  final wishHeadline = 'Si 200 personnes la veulent, on la fabrique';
  final wishByline = 'Vœu de Mouanga Yannick · Génie civil';
  final wishDelivery = '6 semaines après le seuil';
  final wishRefund = 'Automatique si seuil non atteint';

  /// (titre, détail, état 0 = fait, 1 = en cours, 2 = à venir).
  final wishSteps = const [
    ('Vœu publié', '02 oct.', 0),
    ('Précommandes ouvertes', '156 / 200', 1),
    ('Production', 'Dès 200 précommandes', 2),
    ('Retrait au kiosque', '', 2),
  ];
  final escrowNote = 'Votre argent reste bloqué en séquestre jusqu’au lancement de la production.';

  // 218 · Publier un vœu
  final wishSteps218 = const ['Idée', 'Prix', 'Seuil', 'Envoi'];
  final draftWish = 'Lampe en bois recyclé';
  final draftPrice = 25000;
  final draftThreshold = '200';
  final campaignDurations = const ['15 jours', '30 jours', '45 jours', '60 jours'];
  final validationNote = 'Votre département valide le vœu avant sa mise en ligne.';

  // 219 · Nouveau duel
  final duelSteps = const ['Besoin', 'Duel', 'Prix', 'Lancement'];
  final duelNeed = 'Logo pour ma marque de parfums';
  final duelSizes = const ['3 étudiants', '5 étudiants', '8 étudiants'];
  final duelPrize = 60000;
  final duelBonus = 5000;
  final duelDurations = const ['24 h', '48 h', '72 h', '1 semaine'];
  final duelNote =
      'Le duel est modéré par l’administrateur ; seuls des étudiants qualifiés de la filière peuvent participer.';

  // 220 · Duel de talents
  final duelRemaining = 'Reste 02:14:09';

  /// (titre, auteur, avatar, photo, votes, libellé du vote).
  final duelists = const [
    (
      'Lampe recyclée',
      'Yannick M. · Génie civil',
      'assets/images/p_av_yannick.jpg',
      'assets/images/builder.jpg',
      1240,
      'Voter pour la lampe',
    ),
    (
      'Jus de bissap',
      'Équipe BTA · Agro',
      'assets/images/i_av_yannick.jpg',
      'assets/images/food_spread.jpg',
      904,
      'Voter pour le jus',
    ),
  ];

  /// (prénom, avatar, points).
  final weeklyRanking = const [
    ('Yannick', 'assets/images/p_av_yannick.jpg', '1 240 pts'),
    ('Aminata', 'assets/images/i_av_brice.jpg', '1 105 pts'),
    ('Brice', 'assets/images/t_av_carine.jpg', '980 pts'),
  ];

  // 221 · Résultat du duel
  final duelWinner = 'Aminata Bello remporte le duel';
  final duelWinnerDetail = 'Logo Parfums Mbella · 214 votes';
  final duelHero = 'assets/images/ad_duel_equipe.jpg';
  final duelPaidPrize = 60000;
  final duelPaidBonuses = 10000;
  final duelParticipants = '3 étudiants';
  final List<AdRanked> duelRanking = const [
    (
      name: '1. Aminata Bello',
      avatar: 'assets/images/p_av_yannick.jpg',
      detail: '45 % des votes',
      badge: 'Gagnante',
      tone: Tone.success,
    ),
    (
      name: '2. Kouassi Tagne',
      avatar: 'assets/images/i_av_kouassi.jpg',
      detail: '34 % des votes',
      badge: 'Prime',
      tone: Tone.accent,
    ),
    (
      name: '3. Rose Etoga',
      avatar: 'assets/images/t_av_carine.jpg',
      detail: '21 % des votes',
      badge: 'Prime',
      tone: Tone.accent,
    ),
  ];

  // 222 · Atelier en direct
  final liveViewers = '1,2 k';
  final liveElapsed = '00:24:18';
  final liveHost = ('Yannick M.', 'Génie civil · Atelier GI', 'assets/images/p_av_yannick.jpg');
  final liveProduct = (
    title: 'Lampe en bois recyclé',
    rating: '4,8',
    left: '12 restantes',
    price: 25000,
    image: 'assets/images/builder.jpg',
  );

  /// (auteur, avatar, message).
  final liveComments = const [
    ('Mariam', 'assets/images/i_av_kouassi.jpg', 'Magnifique, quelle finition !'),
    ('Brice N.', 'assets/images/i_av_brice.jpg', 'Livrable à Yaoundé ?'),
  ];

  // 223 · Ateliers en direct
  final liveNow = ('En direct maintenant · Atelier bois', 'Génie civil · 124 spectateurs', 'assets/images/builder.jpg');
  final liveFilters = const ['Aujourd’hui', 'Cette semaine', 'Mes rappels'];

  /// (titre, détail, photo, période : 0 = aujourd'hui, 1 = cette semaine).
  final upcomingLives = const [
    ('Fabrication du jus de bissap', 'BTA · Aujourd’hui 16 h', 'assets/images/food_spread.jpg', 0),
    ('Monter un kit solaire', 'ENR · Demain 10 h', 'assets/images/solar.jpg', 1),
    ('Créer un logo en direct', 'MMI · Jeudi 15 h', 'assets/images/phone.jpg', 1),
  ];

  // 224 · Validation des vœux (web, département)
  final wishKpis = const [
    ('Vœux soumis', '14', AppIcons.lightbulb),
    ('À valider', '5', AppIcons.clock),
    ('En campagne', '8', AppIcons.rocket),
    ('Précommandes', '1 248', AppIcons.shoppingBag),
  ];
  final wishReviewTabs = const ['À valider', 'En campagne', 'Refusés'];

  /// (vœu, porteur, prix, seuil, soumis le, statut, tonalité).
  final wishReviews = const [
    ('Lampe en bois recyclé', 'Mouanga Yannick', 25000, '200', '02 oct.', 'En campagne', Tone.success),
    ('Jus de bissap bio', 'Équipe BTA', 1500, '150', '05 oct.', 'En campagne', Tone.success),
    ('Kit solaire de poche', 'Brice Ndoumbe', 18000, '100', '08 oct.', 'En campagne', Tone.success),
    ('Sac en pagne recyclé', 'Carine Mballa', 12000, '80', '21 oct.', 'À valider', Tone.accent),
    ('Support de téléphone en bambou', 'Landry Essomba', 4500, '120', '23 oct.', 'À valider', Tone.accent),
    ('Savon artisanal au karité', 'Équipe OGA', 2000, '300', '24 oct.', 'À valider', Tone.accent),
    ('Station météo connectée', 'Club GEII', 45000, '50', '25 oct.', 'À valider', Tone.accent),
    ('Chargeur à manivelle', 'Kouassi Tagne', 9000, '200', '26 oct.', 'À valider', Tone.accent),
    ('Coque imprimée en 3D', 'Rose Etoga', 6000, '40', '12 oct.', 'Refusé', Tone.error),
  ];
  List<(String, String)> get wishRules => [
    ('Prix minimum', fcfa(1000)),
    ('Seuil minimum', '30 précommandes'),
    ('Durée maximale', '60 jours'),
    ('Délai de validation', '48 h ouvrées'),
  ];
  final wishRulesNote =
      'Un vœu doit décrire le produit, le prix, le seuil et le délai de fabrication. Les fonds restent en séquestre jusqu’au lancement.';

  // 225 · Jumeau 3D
  final twinAngles = const ['Face', 'Profil', 'Dos', 'Détail'];
  final twinSpecs = const ['H 42 cm', 'Ø 24 cm', '1,2 kg'];
  final twinDescription = 'Bois de récupération, finition huile naturelle. Fabriquée par l’atelier Génie civil.';

  // 226 · Modération des duels (web, administration)
  List<(String, String, String)> get duelKpis => [
    ('Duels actifs', '6', AppIcons.zap),
    ('Votes (24 h)', '3 412', AppIcons.thumbsUp),
    ('Séquestre bloqué', fcfa(duelEscrowTotal), AppIcons.lock),
    ('Signalements', '2', AppIcons.flag),
  ];
  final duelTabs = const ['Tous', 'En cours', 'À valider', 'Terminés'];

  /// (duel, demandeur, participants, séquestre, échéance, statut, tonalité).
  final duelRows = const [
    ('Logo Parfums Mbella', 'Mbella SARL', '3 étudiants', 75000, 'Terminé', 'Terminé', Tone.neutral),
    ('Lampe recyclée vs Jus de bissap', 'Boutik-École', '2 projets', 0, '02:14:09', 'En cours', Tone.success),
    ('Affiche Festival IUT', 'BDE IUT Douala', '5 étudiants', 85000, '48 h', 'À valider', Tone.accent),
    ('Maquette d’application', 'Kmer Tech', '3 étudiants', 115000, '72 h', 'En cours', Tone.success),
    ('Charte graphique boulangerie', 'Pain d’Or', '8 étudiants', 140000, '1 semaine', 'À valider', Tone.accent),
  ];
  final duelEscrowPrizes = 310000;
  final duelEscrowBonuses = 105000;
  int get duelEscrowTotal => duelEscrowPrizes + duelEscrowBonuses;
  List<(String, String)> get duelEscrow => [
    ('Prix des gagnants', fcfa(duelEscrowPrizes)),
    ('Primes de participation', fcfa(duelEscrowBonuses)),
    ('Total bloqué en séquestre', fcfa(duelEscrowTotal)),
  ];
  final duelModerationNote =
      'Seuls les étudiants qualifiés de la filière concernée peuvent participer. Un duel signalé est suspendu jusqu’à décision.';

  // 227 · Régie des ateliers en direct (web)
  List<(String, String, String)> get liveKpis => [
    ('Ateliers ce mois', '18', AppIcons.video),
    ('Spectateurs cumulés', '9 640', AppIcons.eye),
    ('Ventes en direct', fcfa(1120000), AppIcons.shoppingBag),
    ('Rappels actifs', '312', AppIcons.bell),
  ];

  /// Spectateurs par jour (lundi → dimanche).
  final liveAudience = const [420.0, 610.0, 380.0, 940.0, 1200.0, 760.0, 530.0];
  final liveDays = const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  /// (atelier, animateur, créneau, rappels, statut, tonalité).
  final liveSchedule = const [
    ('Atelier bois · Lampe recyclée', 'Yannick M. · GC', 'En cours', '124 spectateurs', 'En direct', Tone.error),
    ('Fabrication du jus de bissap', 'Équipe BTA', 'Aujourd’hui 16 h', '86 rappels', 'Programmé', Tone.accent),
    ('Monter un kit solaire', 'Brice N. · ENR', 'Demain 10 h', '64 rappels', 'Programmé', Tone.accent),
    ('Créer un logo en direct', 'Aminata B. · MMI', 'Jeudi 15 h', '41 rappels', 'À valider', Tone.warning),
  ];

  // 228 · Partager mon CV
  final cvLink = 'boutik-ecole.cm/cv/mariam-essono';

  /// (titre, détail, visible).
  final cvVisibility = const [
    ('Missions et avis', 'Toujours visibles', true),
    ('Coordonnées', 'Téléphone et e-mail', false),
  ];

  // 229 · CV vivant
  final cvName = 'Mariam Essono';
  final cvHeadline = 'Développeuse web · Génie informatique';
  final cvSubline = '3e année · Licence · IUT de Douala';
  final cvHero = 'assets/images/coder.jpg';
  final cvStats = const [('18', 'Missions'), ('4,9', 'Avis'), ('12', 'Certificats')];

  /// (titre, détail, vignette).
  final cvAchievements = const [
    ('Site de la Mairie de Douala', 'Mission client · avis 5,0', 'assets/images/coder.jpg'),
    ('Application Boutik', 'Projet d’équipe · 2026', 'assets/images/phone.jpg'),
  ];
  final cvCertificates = const ['React · Meta', 'Python · IUT', 'UI/UX · Google'];
}

final sectionADDataProvider = Provider<SectionADData>((_) => const SectionADData());
