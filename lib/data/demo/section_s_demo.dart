import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Opportunité ou alerte : pictogramme, titre, détail, badge, tonalité, rubrique.
class SItem {
  const SItem(this.icon, this.title, this.detail, this.badge, this.tone, {this.rubric = '', this.target});

  final String icon;
  final String title;
  final String detail;
  final String badge;
  final Tone tone;
  final String rubric;
  final String? target;
}

/// Données de démonstration de la section S (opportunités et alertes IA, 151–159).
class SectionSData {
  const SectionSData();

  final kelaAvatar = Photos.portraitWoman;

  // 151 · Opportunités
  final assistantText = 'L’IA analyse votre profil et vous alerte quand un dossier est incomplet.';
  final assistantBullets = const ['3 offres très compatibles', '2 dossiers à compléter'];
  final opportunityFilters = const ['Tout', 'Stages', 'Emplois', 'Projets', 'Défis'];
  final forYou = const [
    SItem(AppIcons.briefcase, 'Stage développeur web', 'Orange Cameroun · Douala · 3 mois', '92 %', Tone.success, rubric: 'Stages', target: '153'),
    SItem(AppIcons.trophy, 'Hackathon Orange Digital Center', 'Inscriptions jusqu’au 05 nov.', 'Nouveau', Tone.accent, rubric: 'Défis', target: '160'),
    SItem(AppIcons.lightbulb, 'Défi : paiement mobile inclusif', 'Prix de 500 000 FCFA', 'Défi', Tone.warning, rubric: 'Défis', target: '161'),
  ];
  final deadlines = const [
    SItem(AppIcons.clock, 'Stage marketing digital', 'Clôture dans 2 jours', 'J-2', Tone.error, target: '153'),
    SItem(AppIcons.clock, 'Concours d’innovation étudiante', 'Clôture dans 5 jours', 'J-5', Tone.accent, target: '160'),
  ];

  // 152 · Kéla te recommande
  final kelaIntro = 'Kéla a choisi ces offres selon vos compétences, votre filière et votre activité. Vous gardez la main.';
  final recoFilters = const ['Tout', 'Stages', 'Projets', 'Défis'];
  final recommendations = const [
    SItem(AppIcons.briefcase, 'Stage développeur web', 'Orange Cameroun · React, Python', '92 %', Tone.success, rubric: 'Stages', target: '153'),
    SItem(AppIcons.layers, 'Projet : application de covoiturage', 'Équipe de 5 · Recherche développeur', '88 %', Tone.success, rubric: 'Projets', target: '79'),
    SItem(AppIcons.lightbulb, 'Défi : application de paiement', '12 équipes inscrites', '81 %', Tone.success, rubric: 'Défis', target: '161'),
    SItem(AppIcons.briefcase, 'Assistant graphiste', 'Studio Kreatif · Douala', '64 %', Tone.warning, rubric: 'Stages', target: '153'),
    SItem(AppIcons.trophy, 'Hackathon IoT et énergie', 'Yaoundé · 48 h', '58 %', Tone.warning, rubric: 'Défis', target: '160'),
  ];

  // 153 · Pourquoi cette offre ?
  final offerTitle = 'Stage développeur web';
  final offerDetail = 'Orange Cameroun · Douala · 3 mois';
  final offerMatch = 92;
  final matchCriteria = const [
    ('Compétences (React, Python)', 95, 0xFF1F9D6B),
    ('Filière et niveau', 90, 0xFF1F9D6B),
    ('Disponibilité', 85, 0xFF6A4DF0),
    ('Localisation', 100, 0xFF1F9D6B),
  ];
  final improvements = const [
    SItem(AppIcons.file, 'Ajouter un certificat de scolarité', '+4 points de compatibilité', 'Conseil', Tone.warning, target: '18c'),
    SItem(AppIcons.layers, 'Ajouter une réalisation web', '+3 points de compatibilité', 'Conseil', Tone.warning, target: '72'),
  ];

  // 154 · Mon dossier
  final dossierPercent = 78;
  final checklist = const [
    SItem(AppIcons.file, 'CV importé', 'CV_Mariam_Essono.pdf', 'Fait', Tone.success, target: '73'),
    SItem(AppIcons.layers, 'Portfolio (3 réalisations min.)', '18 réalisations', 'Fait', Tone.success, target: '72'),
    SItem(AppIcons.graduationCap, 'Certificat de scolarité', 'Document manquant', 'À fournir', Tone.error, target: '18c'),
    SItem(AppIcons.pencil, 'Lettre de motivation type', 'Recommandé par l’IA', 'À rédiger', Tone.warning, target: '73'),
    SItem(AppIcons.wallet, 'Numéro Mobile Money', 'À vérifier par SMS', 'À vérifier', Tone.warning, target: '14'),
  ];
  final dossierAdvice = 'Ajoutez 2 réalisations récentes pour augmenter vos chances de 30 %.';

  // 155 · Alertes
  final alertFilters = const ['Toutes', 'Dossier', 'Offres', 'Dates limites'];
  final todayAlerts = const [
    SItem(AppIcons.triangleAlert, 'Dossier incomplet', 'Il manque votre certificat de scolarité', 'Action', Tone.error, rubric: 'Dossier', target: '154'),
    SItem(AppIcons.sparkles, 'Nouvelle offre compatible', 'Stage développeur web · 92 %', 'Voir', Tone.accent, rubric: 'Offres', target: '153'),
    SItem(AppIcons.clock, 'Date limite dans 2 jours', 'Hackathon Orange Digital Center', 'J-2', Tone.error, rubric: 'Dates limites', target: '160'),
  ];
  final weekAlerts = const [
    SItem(AppIcons.file, 'Candidature mise à jour', 'Camlight · Entretien à planifier', '', Tone.neutral, rubric: 'Dossier', target: '76'),
    SItem(AppIcons.users, 'Invitation d’équipe', 'Team Innov’ vous invite', 'Répondre', Tone.accent, rubric: 'Offres', target: '81'),
  ];

  // 156 · Préférences d'alertes
  final channels = const [
    ('Notifications dans l’application', 'Toujours actives', true),
    ('SMS', 'Alertes importantes uniquement', true),
    ('WhatsApp', 'Opportunités et dates limites', false),
    ('E-mail', 'Résumé hebdomadaire', true),
  ];
  final alertTypes = const [
    ('Dossier incomplet', 'Documents manquants ou refusés', true),
    ('Offres compatibles', 'Selon mon profil', true),
    ('Dates limites', '48 h avant la clôture', true),
    ('Résultats de candidature', 'À chaque changement de statut', true),
  ];
  final frequencies = const ['Quotidienne', 'Hebdomadaire', 'En temps réel'];

  // 157 · Résumé de Kéla (entreprise)
  final companyName = 'Orange Cameroun';
  final summaryText = '23 propositions reçues pour 3 besoins. 6 sont très adaptées.';
  final summaryBullets = const ['Meilleure proposition : Mariam E. (96 %)', '2 dossiers incomplets à relancer', '1 échéance dans 3 jours'];
  final summaryKpis = const [
    ('Propositions', '23', AppIcons.inbox, '+8', Tone.success),
    ('Très adaptées', '6', AppIcons.sparkles, '', Tone.success),
    ('Dossiers incomplets', '4', AppIcons.triangleAlert, 'À relancer', Tone.warning),
    ('Échéances', '1', AppIcons.clock, 'Dans 3 jours', Tone.warning),
  ];
  final priority = const [
    ('Mariam Essono', 'Application de suivi clients', 'assets/images/q_av_mariam.jpg', '96 %'),
    ('Équipe Team Innov’', 'Borne de recharge solaire', 'assets/images/i_av_brice.jpg', '91 %'),
  ];

  // 158 · Candidatures classées
  final rankTabs = const ['Toutes (23)', 'Très adaptées (6)', 'À relancer (4)'];

  /// (nom, détail, avatar, score, tonalité, très adaptée, à relancer).
  final ranked = const [
    ('Mariam Essono', 'React, Python · Portfolio vérifié', 'assets/images/q_av_mariam.jpg', '96 %', Tone.success, true, false),
    ('Aminata Bello', 'UI/UX · Dossier complet', 'assets/images/i_av_aminata.jpg', '93 %', Tone.success, true, false),
    ('Brice Ndoumbe', 'IoT · Certificat manquant', 'assets/images/i_av_brice_2.jpg', '85 %', Tone.success, false, true),
    ('Kouassi Tagne', 'Audiovisuel · Dossier incomplet', 'assets/images/i_av_kouassi.jpg', '72 %', Tone.accent, false, true),
  ];

  // 159 · Candidature envoyée
  final sentSummary = const [
    ('Offre', 'Technicien électronique'),
    ('Entreprise', 'Camlight · Douala'),
    ('Envoyée le', '22 oct. 2026'),
    ('Compatibilité', '88 %'),
  ];
  final sentAdvice = 'Complétez votre certificat de scolarité pour renforcer votre dossier.';
}

final sectionSDataProvider = Provider<SectionSData>((_) => const SectionSData());
