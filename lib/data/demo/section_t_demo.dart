import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';

/// Données de démonstration de la section T (hackathons et concours, 160–169).
class SectionTData {
  const SectionTData();

  // 160 · Hackathons et concours
  final filters = const ['Tous', 'En ligne', 'Douala', 'Yaoundé', 'Gratuits'];
  final featured = const (
    'Hackathon Orange Digital Center',
    'Inscriptions ouvertes · 48 h · Douala',
    'assets/images/t_hackathon.jpg',
  );

  /// (pictogramme, titre, détail, badge, tonalité, lieu).
  final contests = const [
    (AppIcons.trophy, 'Orange Digital Challenge', '14–16 nov. · Douala · 5 000 000 FCFA', 'Ouvert', Tone.success, 'Douala'),
    (AppIcons.code, 'Hackathon IoT et énergie', '28–29 nov. · Yaoundé', 'J-12', Tone.accent, 'Yaoundé'),
    (AppIcons.lightbulb, 'Concours d’innovation étudiante', 'En ligne · Prix de 1 000 000 FCFA', 'Ouvert', Tone.success, 'En ligne'),
  ];

  // 161 · Hackathon
  final challenge = const ('Orange Digital Challenge', 'Du 14 au 16 novembre 2026 · Douala', 'assets/images/t_salle.jpg');
  final challengeCounters = const [('48 h', 'Durée'), ('5 M', 'FCFA de prix'), ('120', 'Places')];
  final challengeTabs = const ['À propos', 'Programme', 'Prix', 'Règlement'];
  final challengeAbout =
      'Concevez en équipe une solution numérique à fort impact pour l’inclusion financière et l’éducation. Mentors et jury d’experts sur place.';
  final calendar = const [
    ('Clôture des inscriptions', '05 nov. 2026', 0),
    ('Lancement et mentorat', '14 nov. · 09 h', 1),
    ('Pitch final et jury', '16 nov. · 15 h', 2),
  ];

  // 162 · Inscription
  final registrationSteps = const ['Profil', 'Équipe', 'Projet', 'Validation'];
  final teamName = 'Team Innov’';

  /// (nom, rôle, avatar, statut, tonalité).
  final teamMembers = const [
    ('Mariam Essono', 'Capitaine · Développement', 'assets/images/t_av_mariam.jpg', 'Vous', Tone.neutral),
    ('Brice Ndoumbe', 'IoT · Invitation acceptée', 'assets/images/t_av_brice.jpg', 'Confirmé', Tone.success),
    ('Aminata Bello', 'UI/UX · Invitation envoyée', 'assets/images/t_av_aminata.jpg', 'En attente', Tone.warning),
  ];
  final themes = const ['Inclusion financière', 'Éducation', 'Santé', 'Agriculture'];

  // 163 · Trouver des coéquipiers
  final skillFilters = const ['Développeurs', 'Designers', 'Business', 'IA et data'];
  final teammatesCount = 12;

  /// (nom, détail, avatar, déjà invité).
  final teammates = const [
    ('Kouassi Tagne', 'Audiovisuel · Montage, vidéo', 'assets/images/t_av_kouassi.jpg', false),
    ('Carine Mbarga', 'Informatique · Python, IA', 'assets/images/t_av_carine.jpg', false),
    ('Landry Essomba', 'Gestion · Business plan', 'assets/images/t_av_landry.jpg', true),
    ('Yannick Mouanga', 'Génie civil · Prototypage', 'assets/images/t_av_yannick.jpg', false),
  ];

  // 164 · Espace équipe
  final teamSubtitle = 'Orange Digital Challenge · J-2';
  final teamSteps = const ['Idée', 'Prototype', 'Pitch', 'Dépôt'];
  final teamProgress = const [
    ('Avancement du prototype', 65, 0xFF6A4DF0),
    ('Présentation (pitch)', 30, 0xFF1E4A80),
    ('Documentation', 45, 0xFF1F9D6B),
  ];
  final tasks = const [
    ('Maquettes validées', 'Aminata · Terminé', 0),
    ('API de paiement', 'Mariam · En cours', 1),
    ('Capteurs IoT', 'Brice · À démarrer', 2),
  ];
  final mentor = const ('Dr Paul Tchoupo', 'Mentor · Génie logiciel', 'assets/images/t_av_paul.jpg');

  // 165 · Dépôt du projet
  final projectTitle = 'Paiement mobile hors connexion';
  final submissionDeadline = 'Dépôt possible jusqu’au 16 nov. à 12 h.';

  // 166 · Résultats
  final winner = const ('Team Innov’ · 1er prix', 'Orange Digital Challenge 2026', 'assets/images/t_resultats.jpg');

  /// (rang · équipe, projet, points).
  final ranking = const [
    ('1. Team Innov’', 'Paiement mobile hors connexion', '94 pts'),
    ('2. Équipe Kreatif', 'Marketplace artisans', '89 pts'),
    ('3. Équipe Solaire+', 'Énergie hors réseau', '86 pts'),
  ];
  final rewards = const [('Prix', '2 000 000 FCFA'), ('Mentorat', '3 mois'), ('Visibilité', 'Passeport des talents')];

  // 167 · Noter un projet (jury)
  final evaluated = const ('Serre intelligente', 'Équipe Agronomie · Pitch 5 min', 'assets/images/t_serre.jpg');

  /// (critère, note initiale sur 10, couleur).
  final criteria = const [
    ('Innovation', 8, 0xFF1F9D6B),
    ('Faisabilité', 7, 0xFF1E4A80),
    ('Impact social', 9, 0xFF1F9D6B),
    ('Qualité du pitch', 6, 0xFF6A4DF0),
  ];
  final provisionalRank = '2e';

  // 168 · Publier un concours (web)
  final organizer = 'Orange Digital Center';
  final organizerRole = 'Organisateur partenaire';
  final draft = const (
    title: 'Orange Digital Challenge 2026',
    deadline: '05 nov. 2026',
    place: 'Douala · Orange Digital Center',
    prize: '5 000 000',
  );
  final jury = const [
    ('Dr Paul Tchoupo', 'Jury · Génie logiciel', 'assets/images/t_jury_paul.jpg', 'Invité', Tone.accent),
    ('Mme Etoga', 'Jury · Communication', 'assets/images/t_jury_etoga.jpg', 'Confirmé', Tone.success),
  ];

  // 169 · Modération des concours et des offres (web)
  final moderationTabs = const ['Concours (4)', 'Offres de stage (9)', 'Défis (3)', 'Signalés (2)'];

  /// (élément, organisateur, type, soumis, décision, tonalité).
  final moderation = const [
    ('Orange Digital Challenge 2026', 'Orange Digital Center', 'Hackathon', 'Hier', 'À valider', Tone.accent),
    ('Stage développeur web', 'Orange Cameroun', 'Stage', 'Hier', 'À valider', Tone.accent),
    ('Défi paiement inclusif', 'Orange Cameroun', 'Défi', 'Il y a 2 j', 'Validé', Tone.success),
    ('Offre sans description', 'Entreprise X', 'Stage', 'Il y a 3 j', 'À corriger', Tone.error),
  ];
  final moderationIndicators = const [
    ('Délai moyen de validation', '1,2 jour'),
    ('Taux de validation', '91 %'),
    ('Offres signalées (30 j)', '2'),
  ];
}

final sectionTDataProvider = Provider<SectionTData>((_) => const SectionTData());
