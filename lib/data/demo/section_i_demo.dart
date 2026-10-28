import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Projet de la liste « Projets à découvrir » (78).
class IProject {
  const IProject(this.title, this.department, this.progress, this.status, this.tone, this.image);

  final String title;
  final String department;
  final int progress;
  final String status;
  final Tone tone;
  final String image;
}

/// Membre d'équipe (79, 81).
class IMember {
  const IMember(this.name, this.detail, this.avatar, {this.role, this.tone = Tone.neutral});

  final String name;
  final String detail;
  final String avatar;
  final String? role;
  final Tone tone;
}

/// Étape datée d'un journal ou d'un jalon (82, 85).
class IMilestone {
  const IMilestone(this.title, this.detail, this.state);

  final String title;
  final String detail;

  /// 0 = fait, 1 = en cours, 2 = à venir.
  final int state;
}

/// Document de preuve (83).
class IDocument {
  const IDocument(this.name, this.detail, this.status, this.tone, {this.video = false});

  final String name;
  final String detail;
  final String status;
  final Tone tone;
  final bool video;
}

/// Innovation du registre (87).
class IInnovation {
  const IInnovation(this.title, this.detail, this.status, this.tone, this.icon);

  final String title;
  final String detail;
  final String status;
  final Tone tone;
  final String icon;
}

/// Données de démonstration de la section I (78–87). Chiffres fictifs repris des maquettes.
class SectionIData {
  const SectionIData();

  // 78 · Projets innovants
  final projectFilters = const ['Tous', 'Prototypes', 'Recherche', 'Financement', 'Terminés'];
  final featuredTitle = 'Drone éducatif connecté';
  final featuredDetail = 'Team Innov’ · Génie électrique';
  final featuredImage = 'assets/images/i_drone_equipe.jpg';
  final projects = const [
    IProject('Système de filtration d’eau', 'Génie chimique', 72, 'En cours', Tone.accent, 'assets/images/e_masques.jpg'),
    IProject('Serre intelligente', 'Agronomie', 45, 'Financement', Tone.warning, 'assets/images/e_marche_artisanal.jpg'),
    IProject('Application covoiturage', 'Informatique', 100, 'Terminé', Tone.success, Photos.lamp),
    IProject('Panneaux solaires mobiles', 'Génie électrique', 30, 'Prototype', Tone.neutral, Photos.bulb),
  ];

  /// Rubrique de chaque projet pour les filtres de 78.
  final projectRubrics = const ['Recherche', 'Financement', 'Terminés', 'Prototypes'];

  // 79 · Projet
  final projectTitle = 'Système de filtration d’eau';
  final projectDepartment = 'Département Génie chimique';
  final projectImage = 'assets/images/i_filtration.jpg';
  final projectCounters = const [('4', 'Contributeurs'), ('72 %', 'Avancement'), ('3', 'Jalons')];
  final projectProgress = const [('Avancement global', '72%', .72, 0xFF6A4DF0), ('Prototype', 'Terminé', 1.0, 0xFF1F9D6B), ('Tests terrain', '40%', .40, 0xFF1E4A80)];
  final projectPitch = 'Un système de filtration à faible coût pour rendre l’eau de puits potable dans les quartiers de Douala.';
  final projectTeam = const [
    IMember('Brice Ndoumbe', 'Chef de projet', 'assets/images/i_av_brice.jpg'),
    IMember('Aminata Bello', 'Conception', 'assets/images/i_av_aminata.jpg'),
  ];

  // 80 · Soumettre un projet
  final submitSteps = const ['Idée', 'Équipe', 'Médias', 'Envoi'];
  final departments = const ['Génie électrique', 'Génie informatique', 'Génie civil', 'Génie chimique', 'Agronomie', 'MMI'];
  final stages = const ['Idée / Prototype / Réalisé', 'Idée', 'Prototype', 'Réalisé'];

  // 81 · Équipe du projet
  final team = const [
    IMember('Brice Ndoumbe', 'Électronique · Chef de projet', 'assets/images/i_av_brice_2.jpg', role: 'Chef', tone: Tone.neutral),
    IMember('Aminata Bello', 'MMI · Conception', 'assets/images/i_av_aminata_2.jpg', role: 'Design', tone: Tone.accent),
    IMember('Yannick Mouanga', 'Génie civil · Structure', 'assets/images/i_av_yannick.jpg', role: 'Technique', tone: Tone.warning),
    IMember('Kouassi Tagne', 'Audiovisuel · Communication', 'assets/images/i_av_kouassi.jpg', role: 'Média', tone: Tone.success),
  ];
  final responsibilities = const [('Conception', 80, 0xFF6A4DF0), ('Réalisation', 55, 0xFF1E4A80), ('Communication', 35, 0xFF1F9D6B)];

  // 82 · Journal du projet
  final journal = const [
    IMilestone('Cahier des charges validé', '03 sept. 2026 · Équipe complète', 0),
    IMilestone('Premier prototype', '21 sept. 2026 · Filtre à sable', 0),
    IMilestone('Tests en laboratoire', '08 oct. 2026 · Résultats positifs', 0),
    IMilestone('Tests terrain', 'En cours · Quartier Ndokoti', 1),
    IMilestone('Présentation au jury', 'Prévu le 20 nov. 2026', 2),
  ];
  final journalPhotos = const [Photos.bagDesign, Photos.droneLogo, 'assets/images/c_drone.jpg'];

  // 83 · Médias et preuves
  final mediaGrid = const [Photos.lamp, Photos.bulb, Photos.paint, Photos.paintRed, Photos.branding, Photos.sketch];
  final documents = const [
    IDocument('Fiche technique.pdf', '2,4 Mo · Ajouté le 08 oct.', 'Ajouté', Tone.success),
    IDocument('Résultats des tests.xlsx', '860 Ko · Ajouté le 12 oct.', 'Ajouté', Tone.success),
    IDocument('Vidéo de démonstration', 'En attente de téléversement', 'À ajouter', Tone.accent, video: true),
  ];

  // 84 · Nouvelle campagne
  final campaignSteps = const ['Projet', 'Objectif', 'Contreparties', 'Publication'];
  final campaignTypes = const ['Financement participatif', 'Parrainage entreprise', 'Prix et concours'];
  final campaignProjects = const ['Serre intelligente', 'Système de filtration d’eau', 'Drone éducatif connecté'];
  final campaignGoal = '2 000 000';
  final campaignDurations = const ['30 jours', '45 jours', '60 jours'];

  // 84b · Financement
  final fundingTitle = 'Serre intelligente';
  final fundingDetail = 'Projet Agronomie · Équipe de 3';
  final fundingImage = 'assets/images/c_bibliotheque.jpg';
  final collected = 1250000;
  final goal = 2000000;
  final contributors = 48;
  final daysLeft = 21;
  final rewards = const [
    ('Précommande', 'Recevez la première série', 25000, AppIcons.info),
    ('Parrain du projet', 'Votre nom sur la serre', 50000, AppIcons.award),
  ];

  // 85 · Objectifs et jalons
  final fundingMilestones = const [
    IMilestone('500 000 FCFA · Prototype', 'Atteint le 02 oct.', 0),
    IMilestone('1 000 000 FCFA · Production', 'Atteint le 15 oct.', 0),
    IMilestone('1 500 000 FCFA · Tests terrain', 'En cours', 1),
    IMilestone('2 000 000 FCFA · Lancement', '', 2),
  ];
  final fundsUse = const [('Matériel', 40), ('Fabrication', 35), ('Communication', 15), ('Frais plateforme', 10)];

  // 86 · Résultats de campagne
  final averageContribution = 26000;
  final conversion = '4,2 %';
  final conversionDelta = '+0,8 pt';
  final shares = 312;
  final sharesDelta = '+64';
  final collectPeriod = '30 jours';
  final cumulative = const [60, 120, 230, 390, 610, 850, 1100, 1250];
  final lastContributors = const [
    IMember('Aminata Bello', 'Il y a 2 h', 'assets/images/i_av_aminata_3.jpg', role: '50000'),
    IMember('Brice Ndoumbe', 'Hier', 'assets/images/i_av_brice_3.jpg', role: '25000'),
  ];

  // 87 · Registre des innovations
  final innovations = const [
    IInnovation('Filtre à sable modulaire', 'Dépôt OAPI · N° 2026-0145', 'Déposé', Tone.accent, AppIcons.award),
    IInnovation('Serre intelligente', 'Certificat n° BE-CERT-0021', 'Certifié', Tone.success, AppIcons.badgeCheck),
    IInnovation('Drone éducatif connecté', 'Dossier en préparation', 'En cours', Tone.warning, AppIcons.fileText),
    IInnovation('Support de téléphone', 'Modèle déposé · 2025', 'Déposé', Tone.accent, AppIcons.shieldCheck),
  ];
}

final sectionIDataProvider = Provider<SectionIData>((_) => const SectionIData());
