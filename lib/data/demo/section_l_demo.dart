import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Données de démonstration de la section L (département, 108–116, 214–215). Chiffres fictifs des maquettes.
class SectionLData {
  const SectionLData();

  final head = 'Dr Mbarga';
  final headDepartment = 'Dép. Génie informatique';

  // 108 · Tableau de bord du département
  final salesTitle = 'Ventes du département (k FCFA)';
  final salesTotal = 4820000;
  final salesDelta = '+ 9 %';
  final salesGain = 398000;
  final salesTooltip = ('4 820 k', 'Octobre 2026');
  final months = const ['Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.'];
  final salesBars = const [
    0.30, 0.28, 0.33, 0.30, 0.35, 0.32, 0.30, 0.36, 0.31, 0.34, 0.33, 0.31, 0.36, 0.38, 0.32, 0.33, 0.36, 0.38, 0.34, 0.33, //
    0.37, 0.30, 0.34, 0.31, 0.29, 0.28, 0.29, 0.31, 0.27, 0.29, 0.29, 0.26, 0.27, 0.24, 0.23, 0.24, 0.26, 0.25, 0.70, 0.55, //
    0.78, 0.62, 0.80, 0.76, 0.62, 0.82, 0.58, 0.90, 0.56, 0.80, 0.62, 0.72, 0.60, 0.82, 0.62, 0.70, 0.66, 0.66, 0.84, 0.56, //
    0.88, 0.48, 0.84, 0.58, 0.80, 0.62, 0.78, 0.46, 0.40, 0.42, 0.38, 0.44, 0.44, 0.46, 0.45, 0.40, 0.42, 0.45, 0.38, 0.42,
  ];
  final salesHighlight = (38, 66);
  final salesCurve = const [0.55, 0.70, 0.52, 0.38, 0.52, 0.76, 0.6, 0.46];

  /// (vignette, annonce, code, vendeur, statut, tonalité, prix).
  final pendingValidations = const [
    (Photos.lamp, 'Lampe en bois recyclé', 'LMP-001', 'Yannick Mouanga', 'En attente', Tone.success, 25000),
    (Photos.coder, 'Développement web', 'SRV-014', 'Mariam Essono', 'En attente', Tone.neutral, 30000),
    (Photos.bulb, 'Drone éducatif', 'DRN-022', 'Team Innov’', 'À corriger', Tone.success, 150000),
    (Photos.sketch, 'Support de tablette', 'SUP-031', 'Brice Ndoumbe', 'En attente', Tone.neutral, 6000),
    (Photos.solar, 'Kit solaire portable', 'SOL-007', 'Équipe Énergies', 'En attente', Tone.success, 18000),
  ];
  final yearGoal = 62;
  final yearProgress = const [(62, 'des ventes'), (80, 'des validations')];
  final kelaAvatar = Photos.portraitWoman;
  final kelaQuestion = 'Quels enseignements cherches-tu ?';
  final kelaAnswer =
      'Les ventes du département progressent de 9 %. 18 annonces attendent ta validation : veux-tu les traiter maintenant ?';

  // 109 · Étudiants et vendeurs
  final peopleTabs = const ['Tous (248)', 'Vendeurs (64)', 'Étudiants (184)', 'En attente (6)'];

  /// (nom, filière, rôle, annonces, ventes FCFA ou 0, statut, tonalité).
  final people = const [
    ('Mariam Essono', 'Génie informatique', 'Vendeur', 12, 1245000, 'Vérifié', Tone.success),
    ('Yannick Mouanga', 'Génie civil', 'Vendeur', 9, 860000, 'Vérifié', Tone.success),
    ('Aminata Bello', 'MMI', 'Vendeur', 7, 540000, 'Vérifié', Tone.success),
    ('Kouassi Tagne', 'Audiovisuel', 'Étudiant', 0, 0, 'En attente', Tone.accent),
    ('Brice Ndoumbe', 'Électronique', 'Vendeur', 5, 320000, 'Vérifié', Tone.success),
    ('Carine Mbarga', 'Génie informatique', 'Étudiant', 0, 0, 'Suspendu', Tone.error),
  ];

  // 110 · Validation des annonces
  final listingTabs = const ['À valider (18)', 'Validées', 'Refusées', 'À corriger'];

  /// (annonce, vendeur, catégorie, prix, soumise).
  final listingsToValidate = const [
    ('Lampe en bois recyclé', 'Yannick Mouanga', 'Maison', 25000, 'Hier'),
    ('Développement web', 'Mariam Essono', 'Service', 30000, 'Hier'),
    ('Sac à dos design', 'Aminata Bello', 'Mode', 25000, 'Il y a 2 j'),
    ('Pots connectés', 'Brice Ndoumbe', 'Maison', 15000, 'Il y a 2 j'),
    ('Logo et identité', 'Aminata Bello', 'Service', 15000, 'Il y a 3 j'),
  ];
  final validationIndicators = const [('Délai moyen de validation', '1,4 jour'), ('Taux d’acceptation', '92 %'), ('Annonces refusées (30 j)', '7')];

  // 111 · Validation des projets
  final projectKpis = const [
    ('Projets soumis', '21', AppIcons.lightbulb),
    ('À valider', '5', AppIcons.circleCheck),
    ('Validés', '13', AppIcons.check),
    ('Refusés', '3', AppIcons.x),
  ];

  /// (projet, équipe, stade, avancement, décision, tonalité).
  final projects = const [
    ('Système de filtration d’eau', 'Génie chimique', 'Prototype', 72, 'À valider', Tone.warning),
    ('Serre intelligente', 'Agronomie', 'Idée', 45, 'À valider', Tone.warning),
    ('Drone éducatif', 'Team Innov’', 'Réalisé', 100, 'Validé', Tone.success),
    ('Panneaux solaires mobiles', 'Génie électrique', 'Idée', 30, 'À corriger', Tone.error),
  ];

  // 112 · Statistiques
  final statsPeriods = const ['7 jours', '30 jours', '12 mois'];
  final statsKpis = const [
    ('Chiffre d’affaires', '4 820 000 FCFA', AppIcons.wallet, '+9 %'),
    ('Commandes', '312', AppIcons.receipt, '+14 %'),
    ('Panier moyen', '15 450 FCFA', AppIcons.shoppingCart, '+3 %'),
    ('Taux de satisfaction', '4,7 / 5', AppIcons.star, '+0,1'),
  ];
  final weeklySales = const [('S1', 520), ('S2', 610), ('S3', 560), ('S4', 700), ('S5', 840), ('S6', 960)];
  final ordersCurve = const [18, 26, 31, 46, 66, 92];
  final salesMix = const [('Produits', 58, 0xFF6A4DF0), ('Services', 27, 0xFF1E4A80), ('Projets financés', 15, 0xFF1F9D6B)];

  // 113 · Suivi des productions
  final productionKpis = const [
    ('Équipes actives', '14', AppIcons.users),
    ('Productions en cours', '37', AppIcons.layers),
    ('Terminées ce mois', '9', AppIcons.check),
    ('En retard', '4', AppIcons.triangleAlert),
  ];

  /// (production, équipe, encadreur, avancement, état, tonalité).
  final productions = const [
    ('Lot de 50 lampes recyclées', 'Génie civil', 'Dr Tchoupo', 80, 'En cours', Tone.accent),
    ('Application mobile Boutik', 'Génie informatique', 'Dr Mbarga', 65, 'En cours', Tone.accent),
    ('Drone éducatif v2', 'Team Innov’', 'Pr Ngassa', 100, 'Terminé', Tone.success),
    ('Charte graphique IUT', 'MMI', 'Mme Etoga', 35, 'En retard', Tone.error),
  ];

  // 114 · Mentors et encadreurs
  /// (nom, rôle, spécialité, étudiants suivis, statut, tonalité).
  final mentors = const [
    ('Dr Paul Tchoupo', 'Mentor', 'Génie logiciel', 24, 'Actif', Tone.success),
    ('Pr Jean Ngassa', 'Encadreur', 'Électronique', 18, 'Actif', Tone.success),
    ('Mme Rose Etoga', 'Encadreur', 'Communication', 12, 'Actif', Tone.success),
    ('M. Alain Kamga', 'Mentor', 'Entrepreneuriat', 9, 'En pause', Tone.error),
  ];

  // 115 · Événements et initiatives
  final events = const [
    ('Exposition des innovations', 'Sam. 24 oct. · Hall principal', AppIcons.calendar, 'Confirmé', Tone.success),
    ('Conférence innovation et emploi', 'Jeu. 29 oct. · Amphi 1', AppIcons.mic, 'Confirmé', Tone.success),
    ('Atelier micro-entreprise', 'Mar. 27 oct. · Salle B2', AppIcons.users, '12 places', Tone.accent),
  ];
  final eventKpis = const [
    ('Inscrits', '186', AppIcons.users, ''),
    ('Stands réservés', '24', AppIcons.layoutGrid, 'sur 30'),
    ('Partenaires', '7', AppIcons.briefcase, ''),
    ('Budget utilisé', '62 %', AppIcons.wallet, ''),
  ];

  // 116 · Rapports et exports
  final exports = const [('Rapport mensuel', 'PDF · Octobre 2026'), ('Ventes par vendeur', 'Excel · 30 jours'), ('Validations', 'CSV · 12 mois')];

  /// (date, décision, élément, par, résultat, tonalité).
  final decisions = const [
    ('22 oct. 2026', 'Annonce validée', 'Lampe en bois recyclé', 'Dr Mbarga', 'Validé', Tone.success),
    ('21 oct. 2026', 'Projet à corriger', 'Panneaux solaires', 'Dr Mbarga', 'À corriger', Tone.error),
    ('20 oct. 2026', 'Vendeur vérifié', 'Aminata Bello', 'Dr Mbarga', 'Validé', Tone.success),
    ('19 oct. 2026', 'Annonce refusée', 'Pots non conformes', 'Dr Mbarga', 'Refusé', Tone.error),
  ];

  // 214 · Départements
  final familyFilters = const ['Tous', 'Tertiaire', 'Industrie', 'Numérique'];

  /// (famille, filtre, [(sigle · nom, spécialités, photo)]).
  final families = const [
    (
      'Technologies du Tertiaire · MTT',
      'Tertiaire',
      [
        ('GLT · Logistique et transport', 'Plans, stock, tournées', 'assets/images/l_dep_glt.jpg'),
        ('GRH · Ressources humaines', 'Postes, recrutement, formation', 'assets/images/l_dep_grh.jpg'),
        ('OGA · Gestion administrative', 'Événements, archivage', 'assets/images/l_dep_oga.jpg'),
        ('GAPMO · Gestion des PME', 'Business plan, faisabilité', 'assets/images/l_dep_gapmo.jpg'),
        ('TCO · Commercialisation', 'Community management, marketing', 'assets/images/l_dep_tco.jpg'),
        ('CFI · Comptabilité et finance', 'Budgets, audits, tableaux', 'assets/images/l_dep_cfi.jpg'),
      ],
    ),
    (
      'Technologies Industrielles · MTI',
      'Industrie',
      [
        ('GIM · Industriel et maintenance', 'Plans de maintenance', 'assets/images/l_dep_gim.jpg'),
        ('GTE · Thermique et énergie', 'Audits énergétiques', 'assets/images/l_dep_gte.jpg'),
        ('GC · Génie civil', 'Plans, métrés, briques', 'assets/images/l_dep_gc.jpg'),
        ('BTA · Biotechnologie alimentaire', 'Jus, confitures, farines', 'assets/images/l_dep_bta.jpg'),
      ],
    ),
    (
      'Information et Numérique · MTIN',
      'Numérique',
      [
        ('GEII · Électrique et informatique', 'Cartes, domotique', 'assets/images/l_dep_geii.jpg'),
        ('GI · Génie informatique', 'Sites, apps, logiciels', 'assets/images/l_dep_gi.jpg'),
        ('GRT · Réseaux et télécoms', 'Installation, audit', 'assets/images/l_dep_grt.jpg'),
        ('GBM · Génie biomédical', 'Maintenance, prototypes', 'assets/images/l_dep_gbm.jpg'),
      ],
    ),
  ];

  // 215 · Fiche département
  final gi = (
    title: 'Génie Informatique · GI',
    banner: 'Sites, applications et logiciels',
    detail: 'MTIN · 248 étudiants · 137 offres',
    image: 'assets/images/l_gi_banniere.jpg',
  );
  final giCounters = const [('137', 'Offres'), ('4,8', 'Note'), ('32', 'Missions')];
  final giOffers = const [
    ('Site web et application sur mesure', 'Dès 80 000 FCFA · 7 à 21 jours', AppIcons.layers),
    ('MVP pour startup', 'Dès 150 000 FCFA · mentor inclus', AppIcons.lightbulb),
    ('Logiciel de gestion', 'Dès 120 000 FCFA · formation incluse', AppIcons.file),
  ];
  final giStudents = const [
    ('Mariam Essono', 'React, Python · score 88', 'assets/images/l_gi_mariam.jpg'),
    ('Carine Mbarga', 'IA, data · score 81', 'assets/images/l_gi_carine.jpg'),
  ];
}

final sectionLDataProvider = Provider<SectionLData>((_) => const SectionLData());
