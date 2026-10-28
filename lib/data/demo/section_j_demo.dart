import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';
import 'section_g_demo.dart';

/// Ligne de liste générique de la section J : pictogramme, titre, détail, pastille.
class JItem {
  const JItem(this.icon, this.title, this.detail, this.badge, this.tone, {this.category = '', this.target = ''});

  final String icon;
  final String title;
  final String detail;
  final String badge;
  final Tone tone;

  /// Onglet / filtre auquel appartient la ligne.
  final String category;

  /// Écran ouvert au toucher.
  final String target;
}

/// Talent ou équipe trouvé par l'entreprise (91).
class JTalent {
  const JTalent(this.name, this.detail, this.avatar, this.status, this.tone, this.category);

  final String name;
  final String detail;
  final String avatar;
  final String status;
  final Tone tone;
  final String category;
}

/// Proposition reçue sur un besoin (93, 94).
class JProposal {
  const JProposal(
    this.name,
    this.shortName,
    this.avatar,
    this.price,
    this.days,
    this.rating,
    this.revisions,
    this.portfolio, {
    this.shortlisted = false,
    this.refused = false,
  });

  final String name;
  final String shortName;
  final String avatar;
  final int price;
  final int days;
  final String rating;
  final int revisions;
  final int portfolio;
  final bool shortlisted;
  final bool refused;
}

/// Défi d'innovation (96).
class JChallenge {
  const JChallenge(this.icon, this.title, this.sponsor, this.teams, this.prize, this.status);

  final String icon;
  final String title;
  final String sponsor;
  final int teams;
  final int prize;
  final String status;
}

/// Message de négociation (95).
class JMessage {
  const JMessage(this.text, this.time, {this.mine = false});

  final String text;
  final String time;
  final bool mine;
}

class SectionJData {
  const SectionJData();

  // 88 · Espace entreprise
  final companyName = 'Orange Cameroun';
  final companyStatus = 'Partenaire vérifié';
  final dashboardKpis = const [
    GKpi('Besoins publiés', '6', AppIcons.file),
    GKpi('Propositions reçues', '23', AppIcons.inbox, delta: '+8 cette semaine'),
    GKpi('Devis en cours', '4', AppIcons.receipt, delta: '2 à valider', deltaTone: Tone.warning),
    GKpi('Collaborations', '3', AppIcons.users, delta: '1 nouvelle'),
  ];
  final proposalsPeriod = '6 mois';
  final proposalsByMonth = const [
    GBar('Mai', 3),
    GBar('Juin', 6),
    GBar('Juil', 5),
    GBar('Août', 9),
    GBar('Sept', 12),
    GBar('Oct', 18),
  ];
  final opportunities = const [
    JItem(AppIcons.lightbulb, 'Défi : application de paiement mobile', '12 équipes inscrites', 'Ouvert', Tone.success, target: '96'),
    JItem(AppIcons.briefcase, 'Stage développeur web', '8 candidatures', 'Actif', Tone.accent, target: '97'),
  ];

  // 89 · Profil de l'entreprise
  final companyAvatar = 'assets/images/j_avatar_orange.jpg';
  final companySector = 'Télécommunications · Douala';
  final companyTags = '#Stages #Hackathons #Innovation';
  final companyBio = 'Partenaire de l’IUT : stages, défis d’innovation et recrutement de talents.';
  final companyCounters = const ['6 Besoins', '23 Propositions', '4 Collaborations'];
  final companyGallery = const [Photos.coder, 'assets/images/j_galerie_telephone.jpg', Photos.solar];
  final companyThumbs = const [Photos.coder, 'assets/images/j_galerie_telephone_2.jpg', Photos.solar];

  // 90 · Publier un besoin
  final needSteps = const ['Besoin', 'Budget', 'Livrables', 'Publication'];
  final needCategories = const ['Développement', 'Design', 'Audiovisuel', 'Électronique', 'Marketing'];
  final needBudgets = const ['100 000 – 300 000 FCFA', '300 000 – 500 000 FCFA', '500 000 – 1 000 000 FCFA'];
  final needDeadline = '30 nov. 2026';

  // 91 · Rechercher des talents
  final talentsFound = 48;
  final talentFilters = const ['Tous', 'Développement', 'Design', 'Audiovisuel'];
  final talents = const [
    JTalent('Mariam Essono', 'Génie informatique · 4.9 ★', 'assets/images/c_avatar_atelier.jpg', 'Disponible', Tone.success, 'Développement'),
    JTalent('Aminata Bello', 'MMI · UI/UX · 4.8 ★', 'assets/images/c_avatar_aminata_2.jpg', 'Disponible', Tone.success, 'Design'),
    JTalent('Équipe Team Innov’', 'Génie électrique · 4 membres', 'assets/images/c_avatar_aminata.jpg', 'Équipe', Tone.accent, 'Développement'),
    JTalent('Kouassi Tagne', 'Audiovisuel · 4.7 ★', Photos.avatarWoman, 'Occupé', Tone.warning, 'Audiovisuel'),
  ];

  // 93 · 93b · 94 · Propositions
  final proposalTabs = const ['Toutes', 'Présélection', 'Refusées'];
  final proposalCounts = const [23, 4, 0];
  final proposals = const [
    JProposal('Mariam Essono', 'Mariam E.', Photos.avatarCreator, 80000, 7, '4.9', 2, 18, shortlisted: true),
    JProposal('Équipe Team Innov’', 'Team Innov’', 'assets/images/c_avatar_atelier.jpg', 120000, 10, '4.8', 3, 9, shortlisted: true),
    JProposal('Aminata Bello', 'Aminata B.', 'assets/images/c_avatar_aminata_2.jpg', 65000, 6, '4.8', 1, 12),
  ];
  final proposalAvatar = 'assets/images/c_avatar_kouassi.jpg';
  final proposalField = 'Génie informatique';
  final proposalStart = 'Lundi 26 oct.';
  final proposalText =
      'Je propose de concevoir et développer votre application de suivi clients avec une interface mobile, '
      'un tableau de bord et un export des données.';
  final proposalDeliverables = const [
    ('Maquettes validées', 'Jour 2', 0),
    ('Développement', 'Jours 3 à 6', 1),
    ('Tests et livraison', 'Jour 7', 2),
  ];
  final compareCriteria = const ['Prix', 'Délai', 'Note', 'Portfolio'];

  // 95 · Devis et négociations
  final quoteTabs = const ['En cours', 'Acceptés', 'Refusés'];
  final quotes = const [
    JItem(AppIcons.receipt, 'DEV-2026-014 · Borne solaire', 'Team Innov’ · 450 000 FCFA', 'Négociation', Tone.warning, category: 'En cours'),
    JItem(AppIcons.receipt, 'DEV-2026-012 · Application CRM', 'Mariam E. · 80 000 FCFA', 'À valider', Tone.accent, category: 'En cours'),
    JItem(AppIcons.receipt, 'DEV-2026-009 · Logo et charte', 'Aminata B. · 65 000 FCFA', 'Accepté', Tone.success, category: 'En cours'),
  ];
  final lastExchange = const [
    JMessage('Pouvez-vous livrer sous 10 jours pour 420 000 FCFA ?', '09:30'),
    JMessage('Oui, à condition de démarrer lundi.', '09:42', mine: true),
  ];

  // 95b · Demande de devis
  final quoteTeam = 'Équipe Team Innov’';
  final quoteTeamDetail = 'Génie électrique · 4 membres';
  final quoteTeamAvatar = Photos.avatarWoman;
  final quoteObject = 'Prototype de borne de recharge solaire';
  final quoteQuantity = '5 unités';
  final quoteBudget = 500000;
  final quoteDate = '15 déc. 2026';

  // 96 · Défis d'innovation
  final featuredChallenge = 'Défi Orange : paiement mobile inclusif';
  final featuredPrize = 500000;
  final featuredClosing = 'Clôture le 30 nov.';
  final challengeFilters = const ['Ouverts', 'En cours', 'Terminés'];
  final challenges = const [
    JChallenge(AppIcons.lightbulb, 'Application de paiement', 'Orange Cameroun', 12, 500000, 'Ouverts'),
    JChallenge(AppIcons.leaf, 'Gestion des déchets', 'Hysacam', 7, 300000, 'Ouverts'),
    JChallenge(AppIcons.zap, 'Énergie solaire hors réseau', 'Camlight', 5, 400000, 'Ouverts'),
    JChallenge(AppIcons.sprout, 'Agriculture connectée', 'MTN Cameroun', 9, 350000, 'En cours'),
  ];

  // 97 · Recrutement
  final jobFilters = const ['Stages', 'Emplois', 'Alternance'];
  final jobs = const [
    JItem(AppIcons.briefcase, 'Stage développeur web', '8 candidatures · Publiée le 10 oct.', 'Actif', Tone.success, category: 'Stages'),
    JItem(AppIcons.briefcase, 'Stage marketing digital', '5 candidatures · Publiée le 02 oct.', 'Actif', Tone.success, category: 'Stages'),
    JItem(AppIcons.briefcase, 'Technicien réseau', '2 candidatures · Brouillon', 'Brouillon', Tone.neutral, category: 'Stages'),
  ];

  // 98 · Collaborations
  final contractKpis = const [
    GKpi('Contrats actifs', '3', AppIcons.file),
    GKpi('À signer', '1', AppIcons.pencil, delta: 'Avant le 30 oct.', deltaTone: Tone.warning),
  ];
  final contracts = const [
    JItem(AppIcons.users, 'Borne solaire · Team Innov’', 'Contrat signé · 450 000 FCFA', 'Actif', Tone.success),
    JItem(AppIcons.file, 'Application CRM · Mariam E.', 'Livraison le 02 nov.', 'En cours', Tone.accent),
    JItem(AppIcons.pencil, 'Charte graphique · Aminata B.', 'En attente de signature', 'À signer', Tone.accent),
  ];
  final contractProgress = const [('Avancement du projet', 65, 0xFF6A4DF0), ('Budget consommé', 48, 0xFF24477F)];

  // 99 · Historique
  final historyTabs = const ['Besoins', 'Devis', 'Projets', 'Stages'];
  final history = const [
    JItem(AppIcons.file, 'Application de suivi clients', 'Publié le 02 oct. · 23 propositions', 'Clôturé', Tone.neutral, category: 'Besoins'),
    JItem(AppIcons.file, 'Charte graphique', 'Publié le 18 sept. · 11 propositions', 'Attribué', Tone.success, category: 'Besoins'),
    JItem(AppIcons.file, 'Borne de recharge solaire', 'Publié le 05 sept. · 7 propositions', 'En cours', Tone.accent, category: 'Besoins'),
    JItem(AppIcons.file, 'Site vitrine partenaires', 'Publié le 20 août · 15 propositions', 'Terminé', Tone.success, category: 'Besoins'),
    JItem(AppIcons.receipt, 'DEV-2026-009 · Logo et charte', 'Accepté le 12 oct. · 65 000 FCFA', 'Accepté', Tone.success, category: 'Devis'),
    JItem(AppIcons.briefcase, 'Stage développeur web', 'Clôturé le 30 sept. · 2 stagiaires', 'Terminé', Tone.success, category: 'Stages'),
  ];
  final historyKpis = const [GKpi('Besoins publiés', '12', AppIcons.file), GKpi('Projets réalisés', '5', AppIcons.check)];
}

final sectionJDataProvider = Provider<SectionJData>((_) => const SectionJData());
