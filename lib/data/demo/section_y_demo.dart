import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Données de démonstration de la section Y (missions sur mesure, 191–205).
class SectionYData {
  const SectionYData();

  // 191 · Votre besoin
  final needSteps = const ['Besoin', 'Budget', 'Garantie', 'Envoi'];

  /// (titre, détail, photo).
  final needCategories = const [
    ('Identité visuelle', 'Logo, charte', Photos.maquette),
    ('Savons et parfums', 'Fabrication, emballage', Photos.foodSpread),
    ('Vidéo et photo', 'Spot, shooting', Photos.phone),
    ('Site ou application', 'Web, mobile', Photos.coder),
    ('Prototype', 'Objet, mécanique', Photos.technician),
    ('Étude ou audit', 'Marché, finance', 'assets/images/l_dep_cfi.jpg'),
  ];

  /// Fourchettes de budget (min, max) en FCFA.
  final budgets = const [(50000, 150000), (150000, 300000), (300000, 500000), (500000, 1000000)];
  final defaultBudget = 1;
  final wishedDate = '30 novembre 2026';
  final dateOptions = const ['15 novembre 2026', '30 novembre 2026', '15 décembre 2026', '31 janvier 2027'];

  // 192 · Votre devis
  final brief = const ('Identité visuelle · Parfums Mbella', 'Brief #BR-0412 · reçu le 12 oct.', 'Devis prêt');

  /// (titre, détail, état 0 fait / 1 en cours / 2 à venir).
  final validationSteps = const [
    ('Brief reçu', '12 oct. · 09:14', 0),
    ('Analysé par l’administrateur', '12 oct. · 16:40', 0),
    ('Équipe qualifiée sélectionnée', '13 oct. · MMI · TCO', 0),
    ('Devis envoyé', '14 oct. · à valider', 1),
  ];
  final quoteDeliverables = 'Logo, charte, déclinaisons';
  final quoteDelay = '6 semaines';
  final quoteTeam = '3 étudiants + 1 encadreur';
  final quoteTotal = 180000;
  final quotePhotos = const [Photos.maquette, Photos.phone, Photos.coder];

  // 193 · Paiement sécurisé
  final missionLabel = 'Identité visuelle';
  final platformFees = 18000;

  /// (titre, pourcentage) : les montants sont calculés sur le total du devis.
  final milestones = const [
    ('Jalon 1 · Brief validé', 30),
    ('Jalon 2 · Propositions', 40),
    ('Jalon 3 · Livraison finale', 30),
  ];

  /// (nom, détail).
  final paymentMethods = const [('Orange Money', 'Paiement marchand'), ('MTN MoMo', 'Paiement marchand')];

  // 194 · Ma mission
  final missionHero = const ('Identité visuelle · Parfums Mbella', 'Équipe MMI · TCO · livraison le 28 nov.');
  final missionPercent = 60;
  final missionStage = const ('Étape 3 sur 5', 'Propositions de logo en cours de réalisation.');

  /// (titre, détail, état, preuve disponible).
  final missionSteps = const [
    ('Brief validé', '12 oct.', 0, false),
    ('Moodboard', '16 oct.', 0, true),
    ('Propositions de logo', 'Aujourd’hui · en cours', 1, true),
    ('Déclinaisons', 'À venir', 2, false),
    ('Livraison finale', '28 nov.', 2, false),
  ];
  final missionPayment = 'Libéré 60 % · Bloqué 40 %';
  final nextMeeting = 'Jeudi 14 h';

  // 195 · Ajouter une preuve
  final proofStage = const ('Propositions de logo', 'Jalon 2 · Identité visuelle Mbella', 'En cours');
  final proofText = 'Trois pistes de logo, déclinées en couleur et noir et blanc.';

  // 196 · Dossier
  final fileNumber = 'BR-0412';
  final fileTabs = const ['Fil', 'Fichiers', 'Paiements', 'Équipe'];

  /// (texte, heure, envoyé par le client).
  final messages = const [
    ('Bonjour, voici les trois pistes de logo. Qu’en pensez-vous ?', '10:12', false),
    ('La piste 2 me plaît. Pouvez-vous essayer une version plus sobre ?', '10:20', true),
    ('Bien sûr, nouvelle version sous 48 h.', '10:24', false),
  ];
  final sharedFile = const ('Moodboard_Mbella.pdf', 'Ajouté par Aminata B. · 16 oct.');
  final paidMilestone = const (1, 54000, 'Libéré le 14 oct.');

  /// (nom, rôle) des membres de l'équipe du dossier.
  final fileTeam = const [
    ('Aminata Bello', 'MMI · cheffe de projet'),
    ('Kouassi Tagne', 'MMI · graphiste'),
    ('Rose Etoga', 'TCO · branding'),
    ('Dr Paul Tchoupo', 'Encadreur'),
  ];

  // 197 · Valider le jalon
  final reviewMilestone = 2;
  final reviewMilestoneCount = 3;
  final reviewTitle = const ('Propositions de logo', 'Envoyé par l’équipe aujourd’hui');
  final reviewHero = Photos.phone;
  final reviewAmount = 72000;

  // 198 · Briefs reçus
  /// (libellé, valeur, couleur de la barre).
  final briefKpis = const [
    ('Nouveaux', '6', 0xFFE5484D),
    ('À qualifier', '4', 0xFFE08A00),
    ('Attribués', '20', 0xFF1F9D6B),
    ('Clients actifs', '14', 0xFF2F5B8F),
  ];
  final briefTabs = const ['Tous', 'Nouveaux', 'À qualifier', 'Devis envoyé'];

  /// (client, besoin, budget min, budget max, filières, statut).
  final briefs = const [
    ('Parfums Mbella', 'Identité visuelle complète', 150, 300, 'MMI · TCO', 'Nouveau'),
    ('Savonnerie Kamga', 'Emballage et vidéo promo', 200, 260, 'BTA · TCO', 'Nouveau'),
    ('Mairie de Douala', 'Site web et application', 400, 500, 'GI · GRT', 'À qualifier'),
    ('Atelier Tchoupo', 'Prototype métal', 90, 110, 'GMP · GIM', 'Nouveau'),
  ];

  // 199 · Attribuer
  final assignBrief = const ('Parfums Mbella', 'Identité visuelle complète');
  final assignRows = const [
    ('Budget', '150–300 k FCFA'),
    ('Délai', '6 semaines'),
    ('Livrables', 'Logo, charte, déclinaisons'),
    ('Filières', 'MMI · TCO'),
  ];
  final assignSuggestion = 'Équipe de 3 étudiants avec un score moyen de 91 et une disponibilité immédiate.';

  /// (nom, filière · spécialité, note, réalisations, disponible, score).
  final candidates = const [
    ('Aminata Bello', 'MMI · Identité visuelle', '4,9', 18, true, 94),
    ('Kouassi Tagne', 'MMI · Vidéo et photo', '4,8', 12, true, 88),
    ('Rose Etoga', 'TCO · Branding', '4,7', 9, true, 86),
    ('Brice Ndoumbe', 'GEII · Électronique', '4,6', 7, false, 72),
    ('Carine Mbarga', 'GI · Web', '4,7', 8, true, 70),
  ];
  final preselected = const [0, 1, 2];

  // 200 · Missions et encaissement
  final escrowTotal = 12480000;
  final toReleaseThisWeek = 3120000;
  final activeMissions = 34;
  final lateMissions = 3;

  /// Colonnes : (titre, nombre, cartes (titre, filière · client, avatar, avancement, montant bloqué)).
  final board = const [
    (
      'Attribuées',
      4,
      [
        ('Logo Mbella', 'MMI · Mbella', 'assets/images/t_av_aminata.jpg', .6, 54000),
        ('Spot Kamga', 'BTA · Kamga', 'assets/images/t_av_kouassi.jpg', .35, 72000),
        ('Site Mairie', 'GI · Mairie', 'assets/images/t_av_carine.jpg', .85, 96000),
      ],
    ),
    (
      'En cours',
      9,
      [
        ('Spot Kamga', 'BTA · Kamga', 'assets/images/t_av_kouassi.jpg', .45, 72000),
        ('Site Mairie', 'GI · Mairie', 'assets/images/t_av_carine.jpg', .85, 96000),
        ('Borne Camlight', 'ENR · Camlight', 'assets/images/t_av_landry.jpg', .2, 130000),
      ],
    ),
    (
      'À valider',
      5,
      [
        ('Site Mairie', 'GI · Mairie', 'assets/images/t_av_carine.jpg', .83, 96000),
        ('Borne Camlight', 'ENR · Camlight', 'assets/images/t_av_landry.jpg', .2, 130000),
        ('Pack lancement', 'TCO · Nkoa', 'assets/images/t_av_paul.jpg', .5, 60000),
      ],
    ),
    (
      'Livrées',
      12,
      [
        ('Borne Camlight', 'ENR · Camlight', 'assets/images/t_av_landry.jpg', .2, 130000),
        ('Pack lancement', 'TCO · Nkoa', 'assets/images/t_av_paul.jpg', .49, 60000),
        ('Logo Mbella', 'MMI · Mbella', 'assets/images/t_av_paul.jpg', .6, 54000),
      ],
    ),
  ];

  /// (pourcentage, bénéficiaire, couleur).
  final paymentSplit = const [
    (70, 'Étudiants et équipe', 0xFF111015),
    (20, 'Fonds d’innovation', 0xFF6C4CF1),
    (10, 'Plateforme', 0xFF8FB5E8),
  ];

  // 201 · Mes missions
  final myStats = const [('3', 'En cours'), ('245 k', 'Gagnés'), ('4,9', 'Note')];
  final myTabs = const ['En cours', 'À valider', 'Terminées'];

  /// (photo, titre, détail, badge, tonalité, onglet).
  final myMissions = const [
    (Photos.maquette, 'Identité visuelle Mbella', 'Jalon 2 · 60 %', 'Livrer', Tone.warning, 0),
    (Photos.foodSpread, 'Emballage savons Kamga', 'Jalon 1 · 25 %', 'En cours', Tone.accent, 0),
    (Photos.phone, 'Spot promo parfums', 'Attribuée aujourd’hui', 'Nouveau', Tone.success, 0),
    (Photos.coder, 'Site vitrine Mairie', 'Jalon 3 · envoyé hier', 'À valider', Tone.accent, 1),
    (Photos.technician, 'Prototype Atelier Tchoupo', 'Livrée le 2 oct.', 'Terminée', Tone.success, 2),
  ];
  final availableIncome = 50400;
  final pendingIncome = 72000;

  // 202 · Pack Lancement de marque
  final packHero = const ('Votre marque, de l’idée au produit', '4 filières, un seul interlocuteur');

  /// (pictogramme, titre, détail, filière).
  final packItems = const [
    (AppIcons.layers, 'Identité visuelle', 'MMI · logo et charte', 'MMI'),
    (AppIcons.package, 'Fabrication du produit', 'BTA · formulation et tests', 'BTA'),
    (AppIcons.camera, 'Photo et vidéo', 'TCO · spot de lancement', 'TCO'),
    (AppIcons.tag, 'Emballage', 'GMP · prototype et gabarit', 'GMP'),
  ];
  final packPrice = 420000;
  final packSaving = '−15 %';
  final packDelay = '8 semaines';

  // 203 · Mes compétences
  final skillStats = const [('82', 'Score global'), ('18', 'Réalisations'), ('4,9', 'Avis')];

  /// (domaine, score, couleur).
  final skills = const [
    ('Identité visuelle', 92, 0xFF1F9D6B),
    ('Community management', 78, 0xFF6C4CF1),
    ('Vidéo', 64, 0xFF2F5B8F),
    ('Rédaction', 55, 0xFF8FB5E8),
  ];

  /// (pictogramme, titre, détail, points).
  final scoreReasons = const [
    (AppIcons.award, 'Preuves vérifiées', '12 réalisations certifiées', '+30'),
    (AppIcons.starFilled, 'Avis des clients', '38 avis · 4,9 / 5', '+24'),
    (AppIcons.clock, 'Respect des délais', '96 % dans les temps', '+18'),
  ];

  // 204 · Coup de pouce startup
  final startupHero = const (
    'Lancez votre projet avec l’IUT',
    'Équipe, mentor, prototype, visibilité',
    'assets/images/y_startup_hero.jpg',
  );
  final startupStats = const [('12', 'Projets'), ('4', 'Financés'), ('6', 'Mentors')];
  final startupSteps = const ['Idée', 'Équipe', 'Prototype', 'Pitch'];

  /// (photo, titre, détail, badge).
  final startupProjects = const [
    (Photos.foodSpread, 'Serre intelligente', 'BTA · Agronomie · 62 % financé', 'En cours'),
    (Photos.solar, 'Borne solaire mobile', 'ENR · GEII · 45 % financé', 'Prototype'),
  ];

  // 205 · Soumettre mon projet
  final projectSteps = const ['Idée', 'Équipe', 'Besoins', 'Envoi'];
  final projectName = 'Serre intelligente pour maraîchers';
  final projectProblem = 'Les maraîchers perdent des récoltes à cause de la chaleur…';
  final helpOptions = const ['Mentor', 'Prototype', 'Financement', 'Juridique', 'Visibilité'];
  final fundingNeed = 1500000;
}

final sectionYDataProvider = Provider<SectionYData>((_) => const SectionYData());
