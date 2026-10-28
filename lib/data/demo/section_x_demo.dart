import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'catalog_demo.dart';

/// Besoin publié par l'entreprise (187).
typedef XNeed = ({String image, String title, String code, int proposals, String status, Tone tone, int match});

/// Talent ou équipe de l'annuaire (188) ; [filter] = index de la pastille correspondante.
typedef XTalent = ({String name, String program, String skills, String image, int filter, bool available, bool team});

/// Proposition reçue (189) : prix en FCFA, délai en jours, compatibilité IA en %.
typedef XProposal = ({
  String talent,
  int price,
  int days,
  int match,
  String status,
  Tone tone,
  bool shortlisted,
  bool refused,
});

/// Devis en négociation (190) ; [tab] : 0 en cours, 1 acceptés, 2 refusés.
typedef XQuote = ({String reference, String provider, int amount, String updated, String status, Tone tone, int tab});

/// Données de démonstration de la section X (web entreprise, 187–190).
class SectionXData {
  const SectionXData();

  final contactName = 'Mme Nguimfack';
  final companyName = 'Orange Cameroun';

  // 187 · Tableau de bord entreprise
  final heroHeadline = 'Trouve les\nbons talents.';
  final proposalsTotal = 23;
  final proposalsDelta = 8;
  final publishedNeeds = 6;
  final proposalsTooltip = ('23', 'Octobre 2026');
  final months = const ['Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.'];
  final proposalBars = const [
    0.47,
    0.45,
    0.52,
    0.46,
    0.52,
    0.51,
    0.48,
    0.54,
    0.48,
    0.53,
    0.49,
    0.49,
    0.53,
    0.57,
    0.49,
    0.49,
    0.54,
    0.57,
    0.52,
    0.49, //
    0.55,
    0.43,
    0.51,
    0.44,
    0.41,
    0.39,
    0.4,
    0.45,
    0.37,
    0.4,
    0.4,
    0.36,
    0.37,
    0.3,
    0.29,
    0.3,
    0.35,
    0.31,
    0.84,
    0.68, //
    0.84,
    0.71,
    0.85,
    0.83,
    0.71,
    0.85,
    0.68,
    0.92,
    0.63,
    0.84,
    0.7,
    0.8,
    0.69,
    0.87,
    0.71,
    0.78,
    0.75,
    0.74,
    0.9,
    0.65, //
    0.6, 0.58, 0.55, 0.52, 0.56, 0.5, 0.47, 0.44, 0.42, 0.45, 0.4, 0.38, 0.41, 0.36, 0.39, 0.35, 0.33, 0.37, 0.34, 0.32,
  ];
  final proposalHighlight = (38, 66);
  final proposalCurve = const [0.59, 0.81, 0.62, 0.42, 0.58, 0.82, 0.66, 0.5];
  final List<XNeed> needs = const [
    (
      image: Photos.laptopMeeting,
      title: 'Application de suivi clients',
      code: 'BES-014',
      proposals: 23,
      status: 'Ouvert',
      tone: Tone.success,
      match: 96,
    ),
    (
      image: Photos.solar,
      title: 'Borne solaire',
      code: 'BES-011',
      proposals: 7,
      status: 'Ouvert',
      tone: Tone.neutral,
      match: 91,
    ),
    (
      image: Photos.branding,
      title: 'Charte graphique',
      code: 'BES-009',
      proposals: 11,
      status: 'Attribué',
      tone: Tone.success,
      match: 88,
    ),
    (
      image: Photos.coder,
      title: 'Site web vitrine',
      code: 'BES-007',
      proposals: 9,
      status: 'Ouvert',
      tone: Tone.neutral,
      match: 84,
    ),
    (
      image: Photos.team,
      title: 'Vidéo de présentation',
      code: 'BES-005',
      proposals: 5,
      status: 'Ouvert',
      tone: Tone.success,
      match: 81,
    ),
  ];
  final fulfilledPercent = 50;
  final fulfilledProgress = const [(50, 'des besoins'), (80, 'de compatibilité')];
  final kelaAvatar = Photos.portraitWoman;
  final kelaQuestion = 'Quels enseignements cherches-tu ?';
  final kelaAnswer = 'Meilleur profil : Mariam E. (96 %). 2 dossiers sont incomplets : veux-tu les relancer ?';

  // 188 · Recherche de talents et d'équipes
  final talentFilters = const ['Tous', 'Développement', 'Design', 'Audiovisuel', 'Équipes', 'Disponibles'];
  final List<XTalent> talents = const [
    (
      name: 'Mariam Essono',
      program: 'Génie informatique',
      skills: 'React, Python',
      image: Photos.coder,
      filter: 1,
      available: true,
      team: false,
    ),
    (
      name: 'Aminata Bello',
      program: 'MMI',
      skills: 'UI/UX, Branding',
      image: Photos.phone,
      filter: 2,
      available: true,
      team: false,
    ),
    (
      name: 'Brice Ndoumbe',
      program: 'Électronique',
      skills: 'IoT, Drones',
      image: Photos.solar,
      filter: 1,
      available: false,
      team: false,
    ),
    (
      name: 'Kouassi Tagne',
      program: 'Audiovisuel',
      skills: 'Montage, vidéo',
      image: Photos.technician,
      filter: 3,
      available: true,
      team: false,
    ),
  ];

  // 189 · Propositions reçues
  final proposalsAll = 23;
  final proposalsShortlisted = 4;
  final List<XProposal> proposals = const [
    (
      talent: 'Mariam Essono',
      price: 80000,
      days: 7,
      match: 96,
      status: 'Présélection',
      tone: Tone.success,
      shortlisted: true,
      refused: false,
    ),
    (
      talent: 'Team Innov’',
      price: 120000,
      days: 10,
      match: 91,
      status: 'Présélection',
      tone: Tone.success,
      shortlisted: true,
      refused: false,
    ),
    (
      talent: 'Aminata Bello',
      price: 65000,
      days: 6,
      match: 93,
      status: 'À examiner',
      tone: Tone.warning,
      shortlisted: false,
      refused: false,
    ),
    (
      talent: 'Brice Ndoumbe',
      price: 90000,
      days: 8,
      match: 85,
      status: 'À examiner',
      tone: Tone.warning,
      shortlisted: false,
      refused: false,
    ),
  ];
  final aiTitle = 'Analyse IA';
  final aiSummary = 'Mariam E. offre le meilleur équilibre prix, délai et compétences.';
  final aiChecks = const ['Dossier complet', 'Portfolio vérifié'];

  // 190 · Devis et négociations
  final List<XQuote> quotes = const [
    (
      reference: 'DEV-2026-014 · Borne solaire',
      provider: 'Team Innov’',
      amount: 450000,
      updated: 'Aujourd’hui',
      status: 'Négociation',
      tone: Tone.warning,
      tab: 0,
    ),
    (
      reference: 'DEV-2026-012 · Application CRM',
      provider: 'Mariam E.',
      amount: 80000,
      updated: 'Hier',
      status: 'À valider',
      tone: Tone.accent,
      tab: 0,
    ),
    (
      reference: 'DEV-2026-009 · Logo et charte',
      provider: 'Aminata B.',
      amount: 65000,
      updated: '20 oct.',
      status: 'Accepté',
      tone: Tone.success,
      tab: 0,
    ),
  ];
}

final sectionXDataProvider = Provider<SectionXData>((_) => const SectionXData());
