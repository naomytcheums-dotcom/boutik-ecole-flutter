import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import 'catalog_demo.dart';

/// Talent étudiant de l'annuaire (70).
class HTalent {
  const HTalent(this.name, this.field, this.skills, this.category, this.avatar, {this.available = true});

  final String name;
  final String field;
  final String skills;
  final String category;
  final String avatar;
  final bool available;
}

/// État de vérification d'un document (73).
enum HDocStatus { verified, pending }

/// Document du dossier étudiant (73).
class HDocument {
  const HDocument(this.name, this.detail, this.icon, this.type, this.status);

  final String name;
  final String detail;
  final String icon;
  final String type;
  final HDocStatus status;
}

/// Offre de stage, d'emploi, de défi ou de mission (75).
class HOffer {
  const HOffer(this.title, this.company, this.city, this.duration, this.type, {this.applied = false});

  final String title;
  final String company;
  final String city;
  final String duration;
  final String type;
  final bool applied;
}

/// Étape du suivi de candidature (76) : faite, en cours ou à venir.
enum HStepState { done, current, todo }

class HTrackStep {
  const HTrackStep(this.title, this.state, {this.detail});

  final String title;
  final String? detail;
  final HStepState state;
}

/// Données fictives de la section H · Talents et parcours (70–77).
class SectionHData {
  const SectionHData();

  // 70 · Talents étudiants
  final talentFilters = const ['Tous', 'Développement', 'Design', 'Audiovisuel', 'Électronique', 'Génie civil'];
  final talentsAvailable = 32;
  final talents = const [
    HTalent('Mariam Essono', 'Génie informatique', 'Python, React, Flutter', 'Développement', Photos.studentHijab),
    HTalent('Yannick Mouanga', 'Génie civil', 'Conception 3D', 'Génie civil', 'assets/images/d_avis_aminata.jpg'),
    HTalent('Aminata Bello', 'MMI', 'UI/UX, Branding', 'Design', Photos.portraitWoman, available: false),
    HTalent('Kouassi Tagne', 'Audiovisuel', 'Montage', 'Audiovisuel', 'assets/images/d_avis_kouassi.jpg'),
    HTalent('Brice Ndoumbe', 'Électronique', 'IoT, Drones', 'Électronique', 'assets/images/f_avatar_mariam.jpg'),
  ];

  // 72 · Ajouter à mon profil
  final profileTabs = const ['Compétence', 'Expérience', 'Réalisation'];
  final achievementTitle = 'Application mobile Boutik';
  final achievementCategories = const ['Développement', 'Design', 'Audiovisuel', 'Électronique', 'Génie civil'];
  final achievementDate = 'Octobre 2026';
  final maxMedias = 5;

  // 73 · Mes documents
  final documentTabs = const ['Tous', 'CV', 'Diplômes', 'Attestations', 'Certifications'];
  final documents = const [
    HDocument('CV_Mariam_Essono.pdf', 'Mis à jour le 12 oct. 2026', AppIcons.file, 'CV', HDocStatus.verified),
    HDocument('Diplôme DUT – Informatique', 'Session 2025', AppIcons.award, 'Diplômes', HDocStatus.verified),
    HDocument('Attestation de stage', 'Orange Cameroun · 2026', AppIcons.file, 'Attestations', HDocStatus.pending),
    HDocument('Certification React', 'Meta · 2026', AppIcons.badgeCheck, 'Certifications', HDocStatus.verified),
  ];

  // 75 · Opportunités
  final offerTabs = const ['Stages', 'Emplois', 'Défis', 'Missions'];
  final offersAvailable = 12;
  final offers = const [
    HOffer('Stage développeur web', 'Orange Cameroun', 'Douala', '3 mois', 'Stages'),
    HOffer('Assistant graphiste', 'Studio Kreatif', 'Douala', '2 mois', 'Stages'),
    HOffer('Technicien électronique', 'Camlight', 'Douala', '6 mois', 'Stages', applied: true),
    HOffer('Chargé de communication', 'Mairie de Douala', 'Douala', '3 mois', 'Stages'),
    HOffer('Développeur Flutter junior', 'Afriland Digital', 'Douala', 'CDI', 'Emplois'),
    HOffer('Défi Smart Campus', 'IUT de Douala', 'Douala', '4 semaines', 'Défis'),
    HOffer('Refonte de logo', 'Boulangerie Akwa', 'Douala', '1 semaine', 'Missions'),
  ];
  final profileBannerImage = 'assets/images/g_laptop_bureau.jpg';

  // 76 · Ma candidature
  final application = const HOffer('Technicien électronique', 'Camlight', 'Douala', '6 mois', 'Stages', applied: true);
  final applicationStatus = 'En cours';
  final applicationSteps = const ['Envoyée', 'Examinée', 'Entretien', 'Décision'];
  final applicationStep = 1;
  final applicationTrack = const [
    HTrackStep('Candidature envoyée', HStepState.done, detail: '12 oct. 2026'),
    HTrackStep('Dossier examiné', HStepState.done, detail: '14 oct. 2026'),
    HTrackStep('Entretien à planifier', HStepState.current, detail: 'En attente de l’entreprise'),
    HTrackStep('Décision finale', HStepState.todo),
  ];
  final applicationInfos = const [
    ('Contrat', 'Stage de 6 mois'),
    ('Début', 'Janvier 2027'),
    ('Documents joints', 'CV, lettre'),
  ];

  // 77 · Profil de mentor
  final mentorName = 'Dr Mbarga';
  final mentorRole = 'Responsable · Génie informatique';
  final mentorTags = '#Mentorat  #IA  #Recherche';
  final mentorBio = 'J’accompagne les étudiants dans leurs projets, de l’idée au prototype.';
  final mentorAvatar = 'assets/images/h_mentor_portrait.jpg';
  final mentorCounters = const ['32 Équipes', '4,9 Note', '12 Années'];
  final mentorGallery = const [Photos.coder, 'assets/images/h_mentor_atelier.jpg', Photos.solar];
}

final sectionHDataProvider = Provider<SectionHData>((_) => const SectionHData());
