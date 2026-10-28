import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';
import 'section_c_demo.dart';

/// Ligne d'agenda (100) ou de liste avec pictogramme (103, 104).
class KItem {
  const KItem(this.title, this.detail, this.icon, this.badge, this.tone, {this.target});

  final String title;
  final String detail;
  final String icon;
  final String badge;
  final Tone tone;
  final String? target;
}

/// Données de démonstration de la section K (100–107, 237–239). Chiffres fictifs repris des maquettes.
class SectionKData {
  const SectionKData();

  // 100 · Événements
  final week = const [('L', 20), ('M', 21), ('M', 22), ('J', 23), ('V', 24), ('S', 25), ('D', 26)];
  final today = 3;
  final eventFilters = const ['Tous', 'Expositions', 'Ateliers', 'Conférences'];
  final events = const [
    KItem('Exposition des innovations', 'Sam. 24 oct. · 10 h · Hall principal', AppIcons.calendar, 'Gratuit', Tone.success, target: 'Expositions'),
    KItem('Atelier : lancer sa micro-entreprise', 'Mar. 27 oct. · 15 h · Salle B2', AppIcons.users, '12 places', Tone.accent, target: 'Ateliers'),
    KItem('Conférence : innovation et emploi', 'Jeu. 29 oct. · 09 h · Amphi 1', AppIcons.mic, 'Inscription', Tone.accent, target: 'Conférences'),
  ];
  final salonImage = 'assets/images/c_ordinateur.jpg';

  // 101 · Événement
  final eventTitle = 'Exposition des innovations';
  final eventDetail = 'Samedi 24 octobre 2026 · Hall principal';
  final eventImage = 'assets/images/i_drone_equipe.jpg';
  final eventDate = '24 oct. · 10 h';
  final seatsLeft = 86;
  final seatsTotal = 150;
  final eventPitch =
      'Découvrez les produits, services et prototypes réalisés par les étudiants de l’IUT de Douala. Démonstrations, ventes et rencontres avec les entreprises partenaires.';
  final programme = const [
    ('10 h · Ouverture officielle', 'Mot du directeur', 0),
    ('11 h · Démonstrations', 'Prototypes et innovations', 1),
    ('14 h · Rencontres entreprises', 'Espaces B2B', 2),
  ];

  // 102 · Vitrine
  final showcaseTitle = 'Collection « Recyclé & Design »';
  final showcaseDetail = 'Lancement officiel le 24 octobre';
  final showcaseImage = 'assets/images/i_filtration.jpg';
  final showcaseCounters = const [('24', 'Pièces'), ('9', 'Créateurs'), ('3', 'Départements')];
  final showcase = const [
    CTile('Lampe en bois recyclé', 25000, 'Génie civil', Photos.lamp),
    CTile('Sac à dos design', 25000, 'Design – MMI', Photos.bulb),
    CTile('Tableau décoratif', 18000, 'Arts', Photos.paint),
    CTile('Pots connectés', 15000, 'Agronomie', Photos.paintRed),
  ];

  // 103 · Communauté
  final communityTabs = const ['Anciens', 'Mentors', 'Groupes'];
  final alumni = const [
    ('Rodrigue Fotso', 'Promo 2021 · Orange Cameroun', 'assets/images/k_av_rodrigue.jpg', false),
    ('Carine Mbarga', 'Promo 2022 · Studio Kreatif', 'assets/images/k_av_carine.jpg', false),
    ('Landry Essomba', 'Promo 2020 · Camlight', 'assets/images/k_av_landry.jpg', true),
  ];
  final groupImage = 'assets/images/k_groupe_laptop.jpg';
  final groups = const [
    KItem('Entrepreneurs de l’IUT', '124 membres', AppIcons.users, '', Tone.neutral),
    KItem('Innovation et prototypes', '86 membres', AppIcons.lightbulb, '', Tone.neutral),
  ];

  // 104 · Carte de l'innovation
  final mapImage = 'assets/images/k_carte_mobile.png';
  final mapFilters = const ['Tous', 'Ateliers', 'Entreprises', 'Kiosques'];
  final places = const [
    KItem('Atelier Génie civil', 'IUT Douala · Bloc B · 120 m', AppIcons.mapPin, 'Ouvert', Tone.success, target: 'Ateliers'),
    KItem('Kiosque de retrait – Bloc A', 'IUT Douala · 80 m', AppIcons.mapPin, 'Ouvert', Tone.success, target: 'Kiosques'),
  ];

  // 105 · Inter-établissements
  final campusFilters = const ['Tous', 'IUT Douala', 'IUT Bandjoun', 'IUT Ngaoundéré'];
  final otherCampuses = const [
    CTile('Tablette solaire', 45000, 'IUT Bandjoun', Photos.branding),
    CTile('Séchoir à fruits', 30000, 'IUT Ngaoundéré', Photos.sketch),
    CTile('Pagne connecté', 18000, 'IUT Bandjoun', 'assets/images/e_masques.jpg'),
    CTile('Radio à manivelle', 12000, 'IUT Douala', 'assets/images/e_marche_artisanal.jpg'),
  ];
  final interDelay = 'La livraison inter-établissements prend de 3 à 7 jours.';

  // 106 · Économie circulaire
  final circularTabs = const ['Recyclés', 'Réparables', 'Réutilisables'];
  final circularImage = 'assets/images/i_filtration.jpg';
  final circular = const [
    CTile('Lampe en bois recyclé', 25000, 'Génie civil', Photos.lamp),
    CTile('Sac en bâche recyclée', 12000, 'Design', Photos.bulb),
    CTile('Table en palettes', 45000, 'Génie civil', Photos.bagDesign),
    CTile('Pots en plastique', 6000, 'Agronomie', Photos.droneLogo),
  ];

  // 107 · Mon impact
  final impactKpis = const [
    ('CO₂ évité', '48 kg', AppIcons.leaf, '+6 kg ce mois'),
    ('Achats locaux', '12 commandes', AppIcons.house, ''),
    ('Étudiants soutenus', '9', AppIcons.users, ''),
    ('Déchets valorisés', '23 kg', AppIcons.trendingUp, ''),
  ];
  final impactBars = const [('Mai', 32), ('Juin', 48), ('Juil', 62), ('Août', 52), ('Sept', 72), ('Oct', 92)];
  final yearGoal = const (64, 100);
  final studentSupport = 45;

  // 238 · Impact de Boutik-École
  final globalImage = 'assets/images/k_impact_cuisine.jpg';
  final globalCounters = const [('48 M', 'FCFA injectés'), ('312', 'Étudiants payés'), ('86', 'Emplois créés')];
  final regions = const [('Littoral · Douala', 48, 0xFF6A4DF0), ('Centre · Yaoundé', 22, 0xFF6A4DF0), ('Ouest · Bafoussam', 14, 0xFF9BB4E8), ('Nord · Garoua', 8, 0xFF1F9D6B)];

  // 237 · Impact par territoire (web)
  final territoryTabs = const ['Missions livrées', 'Étudiants actifs', 'Revenus versés'];
  final territoryMonth = 'Octobre 2026';
  final territoryMap = 'assets/images/k_carte_web.png';
  final territoryKpis = const [('1 240', 'Étudiants actifs', AppIcons.users), ('386', 'Missions livrées', AppIcons.layers), ('48,2 M F', 'Revenus versés', AppIcons.wallet)];
  final activeRegions = const [('Littoral', 386), ('Centre', 357), ('Ouest', 269), ('Nord-Ouest', 160), ('Sud-Ouest', 126), ('Adamaoua', 92)];
  final focusCity = const ('Douala', 'Littoral · 1re ville', '142 missions', '318 étudiants', '19,4 M FCFA');
  final focusImage = 'assets/images/k_technicien_solaire.jpg';

  // 239 · Rapport sponsors (web)
  final sponsorName = 'Orange Cameroun';
  final sponsorAmount = 2400000;
  final sponsorKpis = const [('14', 'étudiants soutenus'), ('3', 'emplois créés'), ('2', 'prototypes financés')];
  final sponsored = const [
    ('Serre intelligente', 'BTA', 900000, '4', 'Prototype livré', 'Terminé'),
    ('Borne solaire mobile', 'ENR', 700000, '3', '2 emplois créés', 'Terminé'),
    ('Hackathon Orange 2026', 'Tous', 500000, '48', '5 équipes primées', 'Terminé'),
    ('Application paiement hors ligne', 'GI', 300000, '5', 'En cours', 'En cours'),
  ];
}

final sectionKDataProvider = Provider<SectionKData>((_) => const SectionKData());
